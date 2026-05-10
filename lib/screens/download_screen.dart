import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/sign_state.dart';
import '../providers/auth_provider.dart';
import '../providers/sign_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/progress_bar.dart';
import 'signature_screen.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen>
    with TickerProviderStateMixin {
  bool _generating = false;
  Uint8List? _generatedBytes;
  String? _genError;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _confettiCtrl;

  final List<_ConfettiDot> _confetti = [];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    Future.delayed(const Duration(milliseconds: 400), _spawnConfetti);
    Future.delayed(const Duration(milliseconds: 600), _generateDocument);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  void _spawnConfetti() {
    final rng = math.Random();
    final colors = [
      AppColors.accent,
      AppColors.success,
      const Color(0xFFFBBF24),
      AppColors.danger,
      const Color(0xFF60A5FA),
      AppColors.accent2,
    ];
    setState(() {
      _confetti.addAll(List.generate(20, (_) {
        return _ConfettiDot(
          x: rng.nextDouble(),
          color: colors[rng.nextInt(colors.length)],
          size: 4 + rng.nextDouble() * 6,
          speed: 1.5 + rng.nextDouble() * 2,
          delay: rng.nextDouble(),
        );
      }));
    });
    _confettiCtrl.forward();
  }

  // ---------------------------------------------------------------------------
  // Document generation
  // ---------------------------------------------------------------------------
  Future<void> _generateDocument() async {
    final provider = context.read<SignProvider>();
    final doc = provider.document;
    final sig = provider.signature;
    if (doc == null || sig?.imageBytes == null) return;
    final docName = doc.name;

    setState(() => _generating = true);

    Uint8List? output;
    String? error;
    try {
      if (doc.type == DocumentType.image) {
        output = await _compositeImage(doc, sig!);
      } else {
        output = await _generatePdf(doc, sig!, provider);
      }
    } catch (e) {
      debugPrint('Generation error: $e');
      error = 'Failed to generate document: $e';
    }

    if (output != null) {
      // Record the signature usage against the user's quota
      try {
        await ApiService.instance.recordSignature(docName);
        if (mounted) {
          await context.read<AuthProvider>().refreshProfile();
        }
      } catch (e) {
        debugPrint('Usage recording error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _generating = false;
        _generatedBytes = output;
        _genError = error;
      });
    }
  }

  Future<Uint8List> _compositeImage(
      DocumentData doc, SignatureData sig) async {
    final provider = context.read<SignProvider>();
    final placement = provider.getPlacement(1);

    // Decode the source document image
    final docCodec = await ui.instantiateImageCodec(doc.fileBytes!);
    final docFrame = await docCodec.getNextFrame();
    final docImg = docFrame.image;

    // Decode the signature image
    final sigCodec = await ui.instantiateImageCodec(sig.imageBytes!);
    final sigFrame = await sigCodec.getNextFrame();
    final sigImg = sigFrame.image;

    // Scale: placement coords are in display (container) pixel space.
    // We need to map them to the natural image pixel space.
    final containerW = provider.containerWidth > 0 ? provider.containerWidth : docImg.width.toDouble();
    final naturalW = docImg.width.toDouble();
    final naturalH = docImg.height.toDouble();
    final scaleX = naturalW / containerW;
    // Use same scale for both axes (doc fills container preserving aspect ratio)
    final scaleY = scaleX;

    final sx = placement.x * scaleX;
    final sy = placement.y * scaleY;
    final sw = placement.w * scaleX;
    final sh = placement.h * scaleY;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw document background
    canvas.drawImage(docImg, Offset.zero, Paint());

    // Draw signature with opacity and rotation
    canvas.save();
    canvas.translate(sx + sw / 2, sy + sh / 2);
    canvas.rotate(placement.rotation * math.pi / 180);
    canvas.drawImageRect(
      sigImg,
      Rect.fromLTWH(0, 0, sigImg.width.toDouble(), sigImg.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: sw, height: sh),
      Paint()
        ..color = Colors.white.withValues(alpha: placement.opacity)
        ..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final result = await picture.toImage(naturalW.toInt(), naturalH.toInt());
    final byteData = await result.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _generatePdf(
    DocumentData doc,
    SignatureData sig,
    SignProvider provider,
  ) async {
    // For PDFs we composite onto the rendered page image (stored in provider),
    // then embed that as an image in the output PDF.
    final pageBytes = provider.currentPageImage;
    if (pageBytes != null) {
      // Re-use image compositing: treat the rendered page image as a document image
      final fakeDoc = DocumentData(
        name: doc.name,
        sizeBytes: doc.sizeBytes,
        type: DocumentType.image,
        fileBytes: pageBytes,
        totalPages: 1,
      );
      final composited = await _compositeImage(fakeDoc, sig);

      // Wrap composited image in a PDF page
      final pdfDoc = pw.Document();
      final bgImage = pw.MemoryImage(composited);

      // Decode dimensions for page size
      final codec = await ui.instantiateImageCodec(pageBytes);
      final frame = await codec.getNextFrame();
      final natW = frame.image.width.toDouble();
      final natH = frame.image.height.toDouble();

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(natW, natH),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(bgImage, fit: pw.BoxFit.fill),
        ),
      );
      return pdfDoc.save();
    }

    // Fallback: PDF with signature only (no background)
    final pdfDoc = pw.Document();
    final sigImage = pw.MemoryImage(sig.imageBytes!);
    final placement = provider.getPlacement(1);
    final containerW = provider.containerWidth > 0 ? provider.containerWidth : 400.0;
    final scaleX = PdfPageFormat.a4.width / containerW;

    pdfDoc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Stack(children: [
          pw.Positioned(
            left: placement.x * scaleX,
            top: placement.y * scaleX,
            child: pw.Opacity(
              opacity: placement.opacity,
              child: pw.Image(sigImage,
                  width: placement.w * scaleX, height: placement.h * scaleX),
            ),
          ),
        ]),
      ),
    );
    return pdfDoc.save();
  }

  // ---------------------------------------------------------------------------
  // Download / Share
  // ---------------------------------------------------------------------------
  Future<void> _downloadPdf() async {
    if (_generatedBytes == null) return;
    setState(() => _generating = true);

    try {
      final provider = context.read<SignProvider>();
      final docName = provider.document?.name ?? 'document';
      final baseName = docName.replaceAll(RegExp(r'\.[^.]+$'), '');

      await Printing.sharePdf(
        bytes: _generatedBytes!,
        filename: 'signed-$baseName.pdf',
      );
    } catch (e) {
      debugPrint('Download error: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _shareFile() async {
    if (_generatedBytes == null) return;
    final provider = context.read<SignProvider>();
    final docName = provider.document?.name ?? 'document';
    final baseName = docName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final fileName = 'signed-$baseName.pdf';

    try {
      final xFile = XFile.fromData(
        _generatedBytes!,
        mimeType: 'application/pdf',
        name: fileName,
      );
      await Share.shareXFiles(
        [xFile],
        subject: 'Signed Document',
        text: '$fileName — signed via iSigner',
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  void _signAnother() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignatureScreen()),
      (_) => false,
    );
    context.read<SignProvider>().reset();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SignProvider>();
    final doc = provider.document;
    final sig = provider.signature;
    final docName = doc?.name ?? 'document.pdf';
    final sizeKb =
        doc != null ? (doc.sizeBytes / 1024).toStringAsFixed(1) : '—';
    final totalPages = doc?.totalPages ?? 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppHeader(tagline: 'Document signed successfully'),
      body: Stack(
        children: [
          Column(
            children: [
              const ProgressBar(currentStep: 4),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Generation error
                      if (_genError != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _genError!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13, height: 1.4),
                          ),
                        ),

                      // Success hero
                      _SuccessHero(
                        docName: docName,
                        pulseAnim: _pulseAnim,
                        confetti: _confetti,
                        confettiAnim: _confettiCtrl,
                      ),
                      const SizedBox(height: 16),

                      // Stats
                      _StatsRow(
                        pages: totalPages,
                        signatures: provider.signedPages.length,
                        sizeKb: sizeKb,
                      ),
                      const SizedBox(height: 16),

                      // Preview
                      _PreviewCard(
                        pageImageBytes: provider.currentPageImage,
                        sigImageBytes: sig?.imageBytes,
                        placement:
                            provider.getPlacement(provider.currentPage),
                        totalPages: totalPages,
                        containerWidth: provider.containerWidth,
                      ),
                      const SizedBox(height: 20),

                      // Download options header
                      const Text(
                        'DOWNLOAD OPTIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text3,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Download options
                      _DownloadOption(
                        icon: Icons.picture_as_pdf,
                        iconBg: AppColors.danger.withValues(alpha: 0.12),
                        iconColor: AppColors.danger,
                        title: 'Download as PDF',
                        subtitle:
                            'Signed PDF · ~$sizeKb KB · All $totalPages pages',
                        recommended: true,
                        onTap: _downloadPdf,
                      ),
                      const SizedBox(height: 10),
                      _DownloadOption(
                        icon: Icons.download_outlined,
                        iconBg: AppColors.accent.withValues(alpha: 0.12),
                        iconColor: AppColors.accent2,
                        title: 'Download with original format',
                        subtitle: 'Preserve original quality · As uploaded',
                        onTap: _downloadPdf,
                      ),
                      const SizedBox(height: 10),
                      _DownloadOption(
                        icon: Icons.share_outlined,
                        iconBg: const Color(0x1F60A5FA),
                        iconColor: const Color(0xFF60A5FA),
                        title: 'Share document',
                        subtitle: 'Send via WhatsApp, Email, AirDrop...',
                        onTap: _shareFile,
                      ),
                      const SizedBox(height: 16),

                      // Security note
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                  child: Text('🔒',
                                      style: TextStyle(fontSize: 14))),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Privacy first. Your document was processed entirely on-device. No data was uploaded to any server.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.text2,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Sign another
                      GestureDetector(
                        onTap: _signAnother,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_document,
                                  size: 14, color: AppColors.text2),
                              SizedBox(width: 8),
                              Text(
                                'Sign another document',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (_generating)
            Container(
              color: AppColors.bg.withValues(alpha: 0.92),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Generating your document...',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text2),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Embedding signature · Processing pages',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.text3),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        primaryLabel: 'Download PDF',
        primaryColor: const Color(0xFF059669),
        primaryIcon: Icons.download,
        onBack: () => Navigator.of(context).pop(),
        onPrimary: _downloadPdf,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success hero
// ---------------------------------------------------------------------------
class _SuccessHero extends StatelessWidget {
  final String docName;
  final Animation<double> pulseAnim;
  final List<_ConfettiDot> confetti;
  final AnimationController confettiAnim;

  const _SuccessHero({
    required this.docName,
    required this.pulseAnim,
    required this.confetti,
    required this.confettiAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.06),
            AppColors.success.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
      ),
      child: Stack(
        children: [
          // Confetti
          AnimatedBuilder(
            animation: confettiAnim,
            builder: (ctx, _) {
              return SizedBox(
                height: 160,
                child: Stack(
                  children: confetti.map((dot) {
                    final progress =
                        ((confettiAnim.value - dot.delay) / dot.speed)
                            .clamp(0.0, 1.0);
                    return Positioned(
                      left: dot.x *
                          (MediaQuery.of(ctx).size.width - 80),
                      top: -10 + progress * 200,
                      child: Opacity(
                        opacity: (1 - progress).clamp(0.0, 1.0),
                        child: Container(
                          width: dot.size,
                          height: dot.size,
                          decoration: BoxDecoration(
                            color: dot.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          Column(
            children: [
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (ctx, child) {
                  return Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success
                              .withValues(alpha: 0.15 * pulseAnim.value),
                          blurRadius: 30 * pulseAnim.value,
                        )
                      ],
                    ),
                    child: const Icon(Icons.check,
                        color: AppColors.success, size: 36),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Document Signed!',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 22,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your signature has been applied to',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.text2, height: 1.5),
              ),
              Text(
                docName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row
// ---------------------------------------------------------------------------
class _StatsRow extends StatelessWidget {
  final int pages;
  final int signatures;
  final String sizeKb;

  const _StatsRow({
    required this.pages,
    required this.signatures,
    required this.sizeKb,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(value: '$pages', label: 'PAGES', highlight: true),
        const SizedBox(width: 8),
        _StatCard(value: '$signatures', label: 'SIGNATURES'),
        const SizedBox(width: 8),
        _StatCard(value: '$sizeKb KB', label: 'FILE SIZE'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;

  const _StatCard({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.success.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color:
                    highlight ? AppColors.success : AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.text3,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview card
// ---------------------------------------------------------------------------
class _PreviewCard extends StatelessWidget {
  final Uint8List? pageImageBytes;
  final Uint8List? sigImageBytes;
  final SignaturePlacement placement;
  final int totalPages;
  final double containerWidth;

  const _PreviewCard({
    this.pageImageBytes,
    this.sigImageBytes,
    required this.placement,
    required this.totalPages,
    required this.containerWidth,
  });

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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PREVIEW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text2,
                      letterSpacing: 0.8,
                    )),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF1A1A26),
            padding: const EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 260,
                height: 368,
                child: Stack(
                  children: [
                    if (pageImageBytes != null)
                      Image.memory(pageImageBytes!,
                          width: 260, height: 368, fit: BoxFit.fill)
                    else
                      CustomPaint(
                        size: const Size(260, 368),
                        painter: _PreviewDocPainter(),
                      ),
                    if (sigImageBytes != null)
                      Builder(builder: (_) {
                        final srcW = containerWidth > 0 ? containerWidth : 400.0;
                        final previewScale = 260.0 / srcW;
                        return Positioned(
                          left: placement.x * previewScale,
                          top: placement.y * previewScale,
                          child: Transform.rotate(
                            angle: placement.rotation * math.pi / 180,
                            child: Opacity(
                              opacity: placement.opacity,
                              child: Image.memory(
                                sigImageBytes!,
                                width: placement.w * previewScale,
                                height: placement.h * previewScale,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
          // Page thumbnails
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(10),
              itemCount: totalPages,
              itemBuilder: (_, i) {
                final isActive = i == 0;
                return GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 52,
                    height: 68,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isActive ? AppColors.accent : AppColors.border,
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.3),
                                blurRadius: 12,
                              )
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 2,
                          left: 4,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280)),
                          ),
                        ),
                        if (isActive)
                          const Positioned(
                            bottom: 2,
                            right: 3,
                            child: Text(
                              '✓',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewDocPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 52),
        Paint()..color = const Color(0xFFF3F4F6));

    final tp = TextPainter(
      text: const TextSpan(
        text: 'SERVICE AGREEMENT',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(22, 18));

    final linePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(22, 72.0 + i * 14, size.width * 0.65, 5),
          const Radius.circular(2),
        ),
        linePaint,
      );
    }

    // Signature
    final sigPaint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final sigY = size.height - 80;
    canvas.drawLine(
        Offset(22, sigY), Offset(size.width / 2 - 10, sigY),
        Paint()
          ..color = const Color(0xFFD1D5DB)
          ..strokeWidth = 0.5);

    final path = Path()
      ..moveTo(22 + 8, sigY - 15)
      ..quadraticBezierTo(22 + 20, sigY - 35, 22 + 35, sigY - 22)
      ..quadraticBezierTo(22 + 50, sigY - 10, 22 + 65, sigY - 28)
      ..lineTo(22 + 78, sigY - 20);
    canvas.drawPath(path, sigPaint);
  }

  @override
  bool shouldRepaint(_PreviewDocPainter old) => false;
}

// ---------------------------------------------------------------------------
// Download option row
// ---------------------------------------------------------------------------
class _DownloadOption extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool recommended;
  final VoidCallback onTap;

  const _DownloadOption({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.recommended = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: recommended
              ? AppColors.accent.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: recommended
                ? AppColors.accent.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: iconColor.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.text3),
                  ),
                ],
              ),
            ),
            if (recommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confetti dot model
// ---------------------------------------------------------------------------
class _ConfettiDot {
  final double x;
  final Color color;
  final double size;
  final double speed;
  final double delay;

  const _ConfettiDot({
    required this.x,
    required this.color,
    required this.size,
    required this.speed,
    required this.delay,
  });
}
