import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/sign_state.dart';
import '../providers/sign_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/progress_bar.dart';
import 'document_screen.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  SignatureMode _mode = SignatureMode.draw;

  // Draw mode state
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _hasDrawing = false;

  // Text mode state
  final _textController = TextEditingController();
  String _selectedFont = 'DancingScript';
  static const _fonts = [
    ('DancingScript', 'Classic', 'Dancing Script'),
    ('Caveat', 'Casual', 'Caveat'),
    ('Pacifico', 'Bold', 'Pacifico'),
    ('Sacramento', 'Elegant', 'Sacramento'),
  ];

  // Upload mode state
  Uint8List? _uploadedImageBytes;

  // Preview image (shown in preview strip)
  Uint8List? _previewBytes;

  bool get _hasSig {
    switch (_mode) {
      case SignatureMode.draw:
        return _hasDrawing;
      case SignatureMode.text:
        return _textController.text.trim().isNotEmpty;
      case SignatureMode.upload:
        return _uploadedImageBytes != null;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Canvas export
  // ---------------------------------------------------------------------------
  Future<Uint8List> _exportCanvas(Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = _SignaturePainter(strokes: _strokes);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _exportText(String text, String fontKey) async {
    const w = 400.0;
    const h = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final style = _textStyleForFont(fontKey, 52);
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);

    tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  TextStyle _textStyleForFont(String fontKey, double size) {
    switch (fontKey) {
      case 'DancingScript':
        return GoogleFonts.dancingScript(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        );
      case 'Caveat':
        return GoogleFonts.caveat(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        );
      case 'Pacifico':
        return GoogleFonts.pacifico(
          fontSize: size,
          color: AppColors.ink,
        );
      case 'Sacramento':
        return GoogleFonts.sacramento(
          fontSize: size,
          color: AppColors.ink,
        );
      default:
        return GoogleFonts.dancingScript(fontSize: size, color: AppColors.ink);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  void _clearDraw() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _hasDrawing = false;
      _previewBytes = null;
    });
  }

  Future<void> _pickUploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.first.bytes != null) {
      setState(() {
        _uploadedImageBytes = result.files.first.bytes;
        _previewBytes = _uploadedImageBytes;
      });
    }
  }

  Future<void> _onContinue() async {
    Uint8List? sigBytes;

    switch (_mode) {
      case SignatureMode.draw:
        // Exported from canvas – we need a GlobalKey'd canvas size
        sigBytes = _previewBytes ?? await _exportCanvas(const Size(400, 180));
      case SignatureMode.text:
        sigBytes = await _exportText(_textController.text, _selectedFont);
      case SignatureMode.upload:
        sigBytes = _uploadedImageBytes;
    }

    if (!mounted) return;
    if (sigBytes == null) return;

    context.read<SignProvider>().setSignature(SignatureData(
          mode: _mode,
          imageBytes: sigBytes,
          font: _selectedFont,
          text: _textController.text,
        ));

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DocumentScreen()),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppHeader(
        showProfile: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text(
            'Save Draft',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.text2,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const ProgressBar(currentStep: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STEP 1 · CREATE YOUR SIGNATURE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text3,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ModeTabs(
                    selected: _mode,
                    onChanged: (m) => setState(() {
                      _mode = m;
                      _previewBytes = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  if (_mode == SignatureMode.draw) _buildDrawCard(),
                  if (_mode == SignatureMode.text) _buildTextCard(),
                  if (_mode == SignatureMode.upload) _buildUploadCard(),
                  if (_hasSig) ...[
                    const SizedBox(height: 14),
                    _PreviewStrip(
                      imageBytes: _mode == SignatureMode.text
                          ? null
                          : _mode == SignatureMode.upload
                              ? _uploadedImageBytes
                              : _previewBytes,
                      text: _mode == SignatureMode.text
                          ? _textController.text
                          : null,
                      fontKey: _selectedFont,
                      onRedo: () {
                        setState(() {
                          _clearDraw();
                          _textController.clear();
                          _uploadedImageBytes = null;
                          _previewBytes = null;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        primaryLabel: 'Continue',
        primaryEnabled: _hasSig,
        onPrimary: _hasSig ? _onContinue : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Draw card
  // ---------------------------------------------------------------------------
  Widget _buildDrawCard() {
    return _SigCard(
      title: 'Draw your signature',
      hint: 'Use finger or stylus',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 1. White background + border (behind everything)
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.canvasBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasDrawing
                        ? AppColors.accent
                        : AppColors.accent.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
              // 2. Drawing canvas — transparent background so strokes are visible
              GestureDetector(
                onPanStart: (d) {
                  setState(() {
                    _currentStroke = [d.localPosition];
                  });
                },
                onPanUpdate: (d) {
                  setState(() {
                    _currentStroke.add(d.localPosition);
                  });
                },
                onPanEnd: (_) {
                  if (_currentStroke.isNotEmpty) {
                    setState(() {
                      _strokes.add(List.from(_currentStroke));
                      _currentStroke = [];
                      _hasDrawing = true;
                    });
                    _exportCanvas(Size(constraints.maxWidth, 180))
                        .then((bytes) {
                      if (mounted) setState(() => _previewBytes = bytes);
                    });
                  }
                },
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: [..._strokes, _currentStroke],
                  ),
                  child: const SizedBox(
                    width: double.infinity,
                    height: 180,
                  ),
                ),
              ),
              // 3. Placeholder hint (only when nothing drawn yet)
              if (!_hasDrawing && _currentStroke.isEmpty)
                const SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.draw_outlined,
                          size: 32, color: Color(0x478B8BA0)),
                      SizedBox(height: 6),
                      Text('Sign here',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8B8BA0),
                              fontWeight: FontWeight.w500)),
                      Text('Draw with your finger or stylus',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF6B6B80))),
                    ],
                  ),
                ),
              // 4. Clear button
              if (_hasDrawing)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _clearDraw,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: AppColors.danger),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Text card
  // ---------------------------------------------------------------------------
  Widget _buildTextCard() {
    return _SigCard(
      title: 'Type your name',
      hint: 'Choose a handwriting style',
      child: Column(
        children: [
          // Text field
          TextField(
            controller: _textController,
            onChanged: (_) => setState(() {}),
            style: _textStyleForFont(_selectedFont, 28),
            decoration: InputDecoration(
              hintText: 'Your full name...',
              hintStyle: const TextStyle(
                fontSize: 16,
                fontFamily: 'DM Sans',
                color: Color(0xFFAAAACC),
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: AppColors.canvasBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Font grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: _fonts.map((f) {
              final isActive = _selectedFont == f.$1;
              return GestureDetector(
                onTap: () => setState(() => _selectedFont = f.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive ? AppColors.accent : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Abc',
                          style: _textStyleForFont(f.$1, 18),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        f.$2.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color:
                              isActive ? AppColors.accent2 : AppColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Upload card
  // ---------------------------------------------------------------------------
  Widget _buildUploadCard() {
    return _SigCard(
      title: 'Upload signature image',
      hint: 'PNG with transparency works best',
      child: GestureDetector(
        onTap: _pickUploadImage,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.border,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: _uploadedImageBytes != null
              ? Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _uploadedImageBytes!,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to change image',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent2),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.accent2, size: 24),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tap to upload image',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'JPG, PNG, WEBP supported\nTransparent PNG recommended',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 11, color: AppColors.text3, height: 1.5),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable card wrapper
// ---------------------------------------------------------------------------
class _SigCard extends StatelessWidget {
  final String title;
  final String hint;
  final Widget child;

  const _SigCard({required this.title, required this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                Text(hint,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.text3)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode tabs
// ---------------------------------------------------------------------------
class _ModeTabs extends StatelessWidget {
  final SignatureMode selected;
  final ValueChanged<SignatureMode> onChanged;

  const _ModeTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Tab(
            icon: Icons.draw_outlined,
            label: 'Draw',
            active: selected == SignatureMode.draw,
            onTap: () => onChanged(SignatureMode.draw),
          ),
          _Tab(
            icon: Icons.text_fields,
            label: 'Type',
            active: selected == SignatureMode.text,
            onTap: () => onChanged(SignatureMode.text),
          ),
          _Tab(
            icon: Icons.upload_outlined,
            label: 'Upload',
            active: selected == SignatureMode.upload,
            onTap: () => onChanged(SignatureMode.upload),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [BoxShadow(color: AppColors.accentGlow, blurRadius: 12)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: active ? Colors.white : AppColors.text2,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.text2,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview strip
// ---------------------------------------------------------------------------
class _PreviewStrip extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? text;
  final String fontKey;
  final VoidCallback onRedo;

  const _PreviewStrip({
    this.imageBytes,
    this.text,
    required this.fontKey,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text(
            'PREVIEW',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.text3,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageBytes != null
                  ? Image.memory(imageBytes!, fit: BoxFit.contain)
                  : text != null
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            text!,
                            style: _sigTextStyle(fontKey),
                          ),
                        )
                      : const SizedBox(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onRedo,
            child: const Text(
              'Re-do',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _sigTextStyle(String fontKey) {
    switch (fontKey) {
      case 'DancingScript':
        return GoogleFonts.dancingScript(
            fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink);
      case 'Caveat':
        return GoogleFonts.caveat(
            fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink);
      case 'Pacifico':
        return GoogleFonts.pacifico(fontSize: 20, color: AppColors.ink);
      case 'Sacramento':
        return GoogleFonts.sacramento(fontSize: 24, color: AppColors.ink);
      default:
        return GoogleFonts.dancingScript(
            fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink);
    }
  }
}

// ---------------------------------------------------------------------------
// Canvas painter
// ---------------------------------------------------------------------------
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  const _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);

      for (int i = 1; i < stroke.length - 1; i++) {
        final mid = Offset(
          (stroke[i].dx + stroke[i + 1].dx) / 2,
          (stroke[i].dy + stroke[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
            stroke[i].dx, stroke[i].dy, mid.dx, mid.dy);
      }

      if (stroke.length > 1) {
        path.lineTo(stroke.last.dx, stroke.last.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => old.strokes != strokes;
}
