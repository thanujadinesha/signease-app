import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../models/sign_state.dart';
import '../providers/sign_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/progress_bar.dart';
import 'download_screen.dart';

enum _ActiveTool { move, resize, rotate }

enum _ControlTab { transform, appearance, pages }

class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key});

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  _ActiveTool _tool = _ActiveTool.move;
  _ControlTab _tab = _ControlTab.transform;

  // Rendered document page as image
  Uint8List? _pageImageBytes;
  double _docImageWidth = 0;
  double _docImageHeight = 0;

  int _currentPage = 1;
  int _totalPages = 1;

  // Dragging state
  Offset? _dragOffset;
  // Resize state
  Offset? _resizeStart;
  double _resizeInitW = 0;
  double _resizeInitH = 0;
  double _resizeInitX = 0;
  double _resizeInitY = 0;
  String _resizeCorner = '';

  // Displayed doc container size (measured via LayoutBuilder)
  double _containerWidth = 0;
  double _containerHeight = 0;

  bool _loadingDoc = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentPage());
  }

  // ---------------------------------------------------------------------------
  // PDF / Image loading
  // ---------------------------------------------------------------------------
  Future<void> _loadCurrentPage() async {
    if (!mounted) return;
    final provider = context.read<SignProvider>();
    final doc = provider.document;
    if (doc == null || doc.fileBytes == null) return;

    setState(() { _loadingDoc = true; _loadError = null; });
    try {
      if (doc.type == DocumentType.pdf) {
        await _loadPdfPage(doc.fileBytes!, _currentPage);
      } else {
        setState(() { _pageImageBytes = doc.fileBytes; });
        await _decodeDimensions(doc.fileBytes!);
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Failed to load document: $e');
    } finally {
      if (mounted) setState(() => _loadingDoc = false);
    }
  }

  Future<void> _loadPdfPage(Uint8List bytes, int pageNum) async {
    final pdfDoc = await PdfDocument.openData(bytes);
    if (!mounted) return;
    setState(() => _totalPages = pdfDoc.pagesCount);
    context.read<SignProvider>().setCurrentPage(pageNum);

    final page = await pdfDoc.getPage(pageNum);
    final pageImage = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.png,
    );
    await page.close();
    await pdfDoc.close();

    if (pageImage == null) throw Exception('Page rendered as null');

    final imgBytes = pageImage.bytes;
    final imgW = pageImage.width?.toDouble() ?? 0;
    final imgH = pageImage.height?.toDouble() ?? 0;
    setState(() {
      _pageImageBytes = imgBytes;
      _docImageWidth = imgW;
      _docImageHeight = imgH;
    });
    if (!mounted) return;
    final p = context.read<SignProvider>();
    p.setCurrentPageImage(imgBytes);
    p.setDocNaturalSize(imgW, imgH);
  }

  Future<void> _decodeDimensions(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width.toDouble();
    final h = frame.image.height.toDouble();
    setState(() {
      _docImageWidth = w;
      _docImageHeight = h;
    });
    if (!mounted) return;
    context.read<SignProvider>().setDocNaturalSize(w, h);
  }

  void _changePage(int delta) {
    final next = (_currentPage + delta).clamp(1, _totalPages);
    if (next == _currentPage) return;
    setState(() {
      _currentPage = next;
      _pageImageBytes = null;
      _loadError = null;
    });
    _loadCurrentPage();
  }

  // ---------------------------------------------------------------------------
  // Overlay drag / resize helpers
  // ---------------------------------------------------------------------------
  SignaturePlacement _clampPlacement(SignaturePlacement p) {
    if (_containerWidth == 0 || _containerHeight == 0) return p;
    return p.copyWith(
      x: p.x.clamp(0, (_containerWidth - p.w).clamp(0, _containerWidth)),
      y: p.y.clamp(0, (_containerHeight - p.h).clamp(0, _containerHeight)),
      w: p.w.clamp(40, _containerWidth),
      h: p.h.clamp(20, _containerHeight),
    );
  }

  void _onDragStart(DragStartDetails d, SignaturePlacement p) {
    _dragOffset = Offset(d.localPosition.dx - p.x, d.localPosition.dy - p.y);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragOffset == null) return;
    final provider = context.read<SignProvider>();
    final p = provider.getPlacement(_currentPage);
    final newP = _clampPlacement(p.copyWith(
      x: d.localPosition.dx - _dragOffset!.dx,
      y: d.localPosition.dy - _dragOffset!.dy,
    ));
    provider.setPlacement(_currentPage, newP);
  }

  void _startResize(String corner, Offset pos, SignaturePlacement p) {
    _resizeCorner = corner;
    _resizeStart = pos;
    _resizeInitW = p.w;
    _resizeInitH = p.h;
    _resizeInitX = p.x;
    _resizeInitY = p.y;
  }

  void _onResizeUpdate(Offset pos) {
    if (_resizeStart == null) return;
    final dx = pos.dx - _resizeStart!.dx;
    final dy = pos.dy - _resizeStart!.dy;
    final provider = context.read<SignProvider>();
    final p = provider.getPlacement(_currentPage);

    double nx = p.x, ny = p.y, nw = p.w, nh = p.h;

    switch (_resizeCorner) {
      case 'br':
        nw = (_resizeInitW + dx).clamp(40, double.infinity);
        nh = (_resizeInitH + dy).clamp(20, double.infinity);
      case 'bl':
        nw = (_resizeInitW - dx).clamp(40, double.infinity);
        nx = _resizeInitX + dx;
        nh = (_resizeInitH + dy).clamp(20, double.infinity);
      case 'tr':
        nw = (_resizeInitW + dx).clamp(40, double.infinity);
        nh = (_resizeInitH - dy).clamp(20, double.infinity);
        ny = _resizeInitY + dy;
      case 'tl':
        nw = (_resizeInitW - dx).clamp(40, double.infinity);
        nx = _resizeInitX + dx;
        nh = (_resizeInitH - dy).clamp(20, double.infinity);
        ny = _resizeInitY + dy;
    }

    provider.setPlacement(
      _currentPage,
      _clampPlacement(p.copyWith(x: nx, y: ny, w: nw, h: nh)),
    );
  }

  // ---------------------------------------------------------------------------
  // Finalize (limit check)
  // ---------------------------------------------------------------------------
  Future<void> _onFinalize() async {
    bool allowed;
    try {
      allowed = await ApiService.instance.canSign();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not check signing limit: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (!mounted) return;

    if (!allowed) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Limit reached',
              style: TextStyle(color: AppColors.text, fontSize: 18)),
          content: const Text(
            'You have used all your free signatures. Upgrade your plan to continue signing documents.',
            style: TextStyle(color: AppColors.text2, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.text2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Upgrade',
                  style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DownloadScreen()),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SignProvider>();
    final placement = provider.getPlacement(_currentPage);
    final sig = provider.signature;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppHeader(tagline: 'Place your signature'),
      body: Column(
        children: [
          const ProgressBar(currentStep: 3),
          _Toolbar(
            activeTool: _tool,
            onToolChanged: (t) => setState(() => _tool = t),
            currentPage: _currentPage,
            totalPages: _totalPages,
            onPageChanged: _changePage,
          ),
          // Document viewport
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: AppColors.docViewport,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          return _buildDocContainer(
                              constraints, placement, sig, provider);
                        },
                      ),
                    ),
                  ),
                ),
                if (_loadingDoc)
                  const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                if (_loadError != null)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _loadError!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Controls panel
          _ControlsPanel(
            tab: _tab,
            onTabChanged: (t) => setState(() => _tab = t),
            placement: placement,
            currentPage: _currentPage,
            totalPages: _totalPages,
            signedPages: provider.signedPages,
            onPlacementChanged: (p) =>
                provider.setPlacement(_currentPage, p),
            onTogglePage: provider.togglePageSigned,
          ),
          BottomBar(
            primaryLabel: 'Finalize',
            onBack: () => Navigator.of(context).pop(),
            onPrimary: _onFinalize,
          ),
        ],
      ),
    );
  }

  Widget _buildDocContainer(
    BoxConstraints constraints,
    SignaturePlacement placement,
    SignatureData? sig,
    SignProvider provider,
  ) {
    final availW = constraints.maxWidth;

    // Aspect ratio from doc image
    double docH;
    if (_docImageWidth > 0 && _docImageHeight > 0) {
      docH = availW * (_docImageHeight / _docImageWidth);
    } else {
      docH = availW * 1.414; // A4 ratio fallback
    }

    // Update container size for clamping and compositing scale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_containerWidth != availW || _containerHeight != docH) {
        setState(() {
          _containerWidth = availW;
          _containerHeight = docH;
        });
        context.read<SignProvider>().setContainerSize(availW, docH);
      }
    });

    return Container(
      width: availW,
      height: docH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 40, offset: Offset(0, 8))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Document page
          if (_pageImageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                _pageImageBytes!,
                width: availW,
                height: docH,
                fit: BoxFit.fill,
              ),
            )
          else
            _MockDocument(width: availW, height: docH),

          // Signature overlay (only if page is signed)
          if (sig?.imageBytes != null &&
              provider.signedPages.contains(_currentPage))
            _SignatureOverlay(
              placement: placement,
              imageBytes: sig!.imageBytes!,
              activeTool: _tool,
              onDragStart: (d) => _onDragStart(d, placement),
              onDragUpdate: _onDragUpdate,
              onDragEnd: (_) => _dragOffset = null,
              onResizeStart: (corner, pos) =>
                  _startResize(corner, pos, placement),
              onResizeUpdate: _onResizeUpdate,
              onResizeEnd: () => _resizeStart = null,
              onQuickRotate: () {
                final p = context.read<SignProvider>().getPlacement(_currentPage);
                context.read<SignProvider>().setPlacement(
                    _currentPage,
                    p.copyWith(rotation: (p.rotation + 15) % 360));
              },
            ),

          // Tip bubble
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: _TipBubble(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------
class _Toolbar extends StatelessWidget {
  final _ActiveTool activeTool;
  final ValueChanged<_ActiveTool> onToolChanged;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _Toolbar({
    required this.activeTool,
    required this.onToolChanged,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _ToolBtn(
            icon: Icons.open_with,
            label: 'Move',
            active: activeTool == _ActiveTool.move,
            onTap: () => onToolChanged(_ActiveTool.move),
          ),
          const SizedBox(width: 8),
          _ToolBtn(
            icon: Icons.zoom_out_map,
            label: 'Resize',
            active: activeTool == _ActiveTool.resize,
            onTap: () => onToolChanged(_ActiveTool.resize),
          ),
          const SizedBox(width: 8),
          _ToolBtn(
            icon: Icons.rotate_right,
            label: 'Rotate',
            active: activeTool == _ActiveTool.rotate,
            onTap: () => onToolChanged(_ActiveTool.rotate),
          ),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: AppColors.border,
          ),
          const Spacer(),
          // Page nav
          GestureDetector(
            onTap: () => onPageChanged(-1),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.chevron_left,
                color: currentPage <= 1 ? AppColors.text3 : AppColors.text2,
                size: 18,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 50),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$currentPage / $totalPages',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2),
            ),
          ),
          GestureDetector(
            onTap: () => onPageChanged(1),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.chevron_right,
                color: currentPage >= totalPages
                    ? AppColors.text3
                    : AppColors.text2,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: active ? AppColors.accent2 : AppColors.text2),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.accent2 : AppColors.text2,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Signature overlay
// ---------------------------------------------------------------------------
class _SignatureOverlay extends StatelessWidget {
  final SignaturePlacement placement;
  final Uint8List imageBytes;
  final _ActiveTool activeTool;
  final Function(DragStartDetails) onDragStart;
  final Function(DragUpdateDetails) onDragUpdate;
  final Function(DragEndDetails) onDragEnd;
  final Function(String, Offset) onResizeStart;
  final Function(Offset) onResizeUpdate;
  final VoidCallback onResizeEnd;
  final VoidCallback onQuickRotate;

  const _SignatureOverlay({
    required this.placement,
    required this.imageBytes,
    required this.activeTool,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onQuickRotate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: placement.x,
      top: placement.y,
      child: GestureDetector(
        onPanStart: activeTool == _ActiveTool.move ? onDragStart : null,
        onPanUpdate: activeTool == _ActiveTool.move ? onDragUpdate : null,
        onPanEnd: activeTool == _ActiveTool.move ? onDragEnd : null,
        child: Transform.rotate(
          angle: placement.rotation * math.pi / 180,
          child: SizedBox(
            width: placement.w,
            height: placement.h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Signature image
                Opacity(
                  opacity: placement.opacity,
                  child: Image.memory(
                    imageBytes,
                    width: placement.w,
                    height: placement.h,
                    fit: BoxFit.contain,
                  ),
                ),
                // Selection ring
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accent, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Rotate button (top-center)
                Positioned(
                  top: -32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: onQuickRotate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.accentGlow, blurRadius: 12)
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rotate_right,
                                size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Rotate',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Corner handles
                ..._corners.map((c) => _CornerHandle(
                      corner: c,
                      onStart: (pos) => onResizeStart(c, pos),
                      onUpdate: onResizeUpdate,
                      onEnd: onResizeEnd,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _corners = ['tl', 'tr', 'bl', 'br'];
}

class _CornerHandle extends StatelessWidget {
  final String corner;
  final Function(Offset) onStart;
  final Function(Offset) onUpdate;
  final VoidCallback onEnd;

  const _CornerHandle({
    required this.corner,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = corner.startsWith('t');
    final isLeft = corner.endsWith('l');

    return Positioned(
      top: isTop ? -9 : null,
      bottom: isTop ? null : -9,
      left: isLeft ? -9 : null,
      right: isLeft ? null : -9,
      child: GestureDetector(
        onPanStart: (d) => onStart(d.globalPosition),
        onPanUpdate: (d) => onUpdate(d.globalPosition),
        onPanEnd: (_) => onEnd(),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 8)
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controls panel
// ---------------------------------------------------------------------------
class _ControlsPanel extends StatelessWidget {
  final _ControlTab tab;
  final ValueChanged<_ControlTab> onTabChanged;
  final SignaturePlacement placement;
  final int currentPage;
  final int totalPages;
  final Set<int> signedPages;
  final ValueChanged<SignaturePlacement> onPlacementChanged;
  final ValueChanged<int> onTogglePage;

  const _ControlsPanel({
    required this.tab,
    required this.onTabChanged,
    required this.placement,
    required this.currentPage,
    required this.totalPages,
    required this.signedPages,
    required this.onPlacementChanged,
    required this.onTogglePage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _CtrlTab(
                  label: 'Transform',
                  active: tab == _ControlTab.transform,
                  onTap: () => onTabChanged(_ControlTab.transform),
                ),
                const SizedBox(width: 6),
                _CtrlTab(
                  label: 'Appearance',
                  active: tab == _ControlTab.appearance,
                  onTap: () => onTabChanged(_ControlTab.appearance),
                ),
                const SizedBox(width: 6),
                _CtrlTab(
                  label: 'Pages',
                  active: tab == _ControlTab.pages,
                  onTap: () => onTabChanged(_ControlTab.pages),
                ),
              ],
            ),
          ),
          // Panel content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildTabContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    switch (tab) {
      case _ControlTab.transform:
        return Column(
          children: [
            _Slider(
              label: 'W',
              value: placement.w,
              min: 40,
              max: 300,
              unit: '',
              onChanged: (v) =>
                  onPlacementChanged(placement.copyWith(w: v)),
            ),
            _Slider(
              label: 'H',
              value: placement.h,
              min: 20,
              max: 180,
              unit: '',
              onChanged: (v) =>
                  onPlacementChanged(placement.copyWith(h: v)),
            ),
            _Slider(
              label: '°',
              value: placement.rotation,
              min: -180,
              max: 180,
              unit: '°',
              onChanged: (v) =>
                  onPlacementChanged(placement.copyWith(rotation: v)),
            ),
          ],
        );
      case _ControlTab.appearance:
        return Column(
          children: [
            _Slider(
              label: 'Opacity',
              value: placement.opacity * 100,
              min: 20,
              max: 100,
              unit: '%',
              onChanged: (v) =>
                  onPlacementChanged(placement.copyWith(opacity: v / 100)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [100, 80, 60, 40].map((v) {
                final isActive =
                    (placement.opacity * 100).round() == v;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onPlacementChanged(
                        placement.copyWith(opacity: v / 100)),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.accent.withValues(alpha: 0.1)
                            : AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? AppColors.accent
                              : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$v%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppColors.accent2
                                : AppColors.text2,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      case _ControlTab.pages:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apply signature to which pages?',
              style: TextStyle(
                  fontSize: 11, color: AppColors.text3, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: totalPages,
                itemBuilder: (_, i) {
                  final page = i + 1;
                  final isSigned = signedPages.contains(page);
                  final isCurrent = page == currentPage;
                  return GestureDetector(
                    onTap: () => onTogglePage(page),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSigned,
                            onChanged: (_) => onTogglePage(page),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Page $page',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.text2,
                                fontWeight: FontWeight.w500),
                          ),
                          if (isCurrent) ...[
                            const Spacer(),
                            const Text(
                              'CURRENT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent2,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
    }
  }
}

class _CtrlTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CtrlTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.accent2 : AppColors.text3,
            ),
          ),
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;

  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.text3,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${value.round()}$unit',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mock document (shown while loading)
// ---------------------------------------------------------------------------
class _MockDocument extends StatelessWidget {
  final double width;
  final double height;

  const _MockDocument({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _MockDocPainter(),
    );
  }
}

class _MockDocPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // White background
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = Colors.white);

    // Header bar
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, 80),
      Paint()..color = const Color(0xFFF3F4F6),
    );

    // Title
    _drawText(canvas, 'SERVICE AGREEMENT', const Offset(40, 32),
        const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF374151)));
    _drawText(canvas, 'Contract No: SE-2024-0891', const Offset(40, 52),
        const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)));

    // Body lines
    final linePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.fill;

    final lineYs = [100.0, 120.0, 140.0, 160.0, 180.0, 200.0, 220.0, 240.0];
    for (final y in lineYs) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(40, y, w * 0.7 + (y % 50 < 25 ? -20.0 : 0.0), 8),
          const Radius.circular(2),
        ),
        linePaint,
      );
    }

    // Signature line
    final sigLineY = h - 100.0;
    canvas.drawLine(
      Offset(40, sigLineY),
      Offset(w / 2 - 20, sigLineY),
      Paint()
        ..color = const Color(0xFFD1D5DB)
        ..strokeWidth = 1,
    );
    _drawText(
        canvas,
        'Client Signature',
        Offset(40, sigLineY + 14),
        const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)));

    canvas.drawLine(
      Offset(w / 2 + 20, sigLineY),
      Offset(w - 40, sigLineY),
      Paint()
        ..color = const Color(0xFFD1D5DB)
        ..strokeWidth = 1,
    );
    _drawText(
        canvas,
        'Service Provider',
        Offset(w / 2 + 20, sigLineY + 14),
        const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)));
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_MockDocPainter old) => false;
}

// ---------------------------------------------------------------------------
// Tip bubble
// ---------------------------------------------------------------------------
class _TipBubble extends StatefulWidget {
  @override
  State<_TipBubble> createState() => _TipBubbleState();
}

class _TipBubbleState extends State<_TipBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    Future.delayed(const Duration(seconds: 2),
        () => mounted ? _ctrl.forward() : null);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          '💡 Drag to position · Corners to resize',
          style: TextStyle(fontSize: 11, color: AppColors.text2),
        ),
      ),
    );
  }
}
