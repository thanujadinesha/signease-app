import 'package:flutter/foundation.dart';
import '../models/sign_state.dart';

class SignProvider extends ChangeNotifier {
  // Step 1 — Signature
  SignatureData? _signature;
  SignatureData? get signature => _signature;

  void setSignature(SignatureData sig) {
    _signature = sig;
    notifyListeners();
  }

  void clearSignature() {
    _signature = null;
    notifyListeners();
  }

  // Step 2 — Document
  DocumentData? _document;
  DocumentData? get document => _document;

  // Rendered page images (pdfx gives us images per page)
  Uint8List? _currentPageImage;
  Uint8List? get currentPageImage => _currentPageImage;

  void setDocument(DocumentData doc) {
    _document = doc;
    notifyListeners();
  }

  void setCurrentPageImage(Uint8List bytes) {
    _currentPageImage = bytes;
    notifyListeners();
  }

  void clearDocument() {
    _document = null;
    _currentPageImage = null;
    notifyListeners();
  }

  // Step 3 — Placement
  int _currentPage = 1;
  int get currentPage => _currentPage;

  // Container = the box the doc is rendered into on screen (CSS/display pixels)
  double _containerWidth = 0;
  double _containerHeight = 0;
  double get containerWidth => _containerWidth;
  double get containerHeight => _containerHeight;

  // Natural = the actual pixel dimensions of the document image/rendered PDF page
  double _docNaturalWidth = 0;
  double _docNaturalHeight = 0;
  double get docNaturalWidth => _docNaturalWidth;
  double get docNaturalHeight => _docNaturalHeight;

  /// Scale to convert display coords → natural image coords.
  /// naturalX = displayX * displayToNaturalScale
  double get displayToNaturalScale =>
      (_containerWidth > 0 && _docNaturalWidth > 0)
          ? _docNaturalWidth / _containerWidth
          : 1.0;

  double _displayScale = 1.0;
  double get displayScale => _displayScale;

  // Per-page signature placements
  final Map<int, SignaturePlacement> _placements = {};
  Map<int, SignaturePlacement> get placements => Map.unmodifiable(_placements);

  SignaturePlacement getPlacement(int page) =>
      _placements[page] ?? const SignaturePlacement();

  void setPlacement(int page, SignaturePlacement placement) {
    _placements[page] = placement;
    notifyListeners();
  }

  void setCurrentPage(int page) {
    _currentPage = page;
    // Initialise placement for this page if not set
    _placements.putIfAbsent(page, () => const SignaturePlacement());
    notifyListeners();
  }

  void setContainerSize(double w, double h) {
    _containerWidth = w;
    _containerHeight = h;
    notifyListeners();
  }

  void setDocNaturalSize(double w, double h) {
    _docNaturalWidth = w;
    _docNaturalHeight = h;
    notifyListeners();
  }

  void setDisplayScale(double scale) {
    _displayScale = scale;
    notifyListeners();
  }

  // Which pages have signatures applied
  final Set<int> _signedPages = {1};
  Set<int> get signedPages => Set.unmodifiable(_signedPages);

  void togglePageSigned(int page) {
    if (_signedPages.contains(page)) {
      _signedPages.remove(page);
    } else {
      _signedPages.add(page);
      _placements.putIfAbsent(page, () => const SignaturePlacement());
    }
    notifyListeners();
  }

  // Reset everything
  void reset() {
    _signature = null;
    _document = null;
    _currentPageImage = null;
    _currentPage = 1;
    _displayScale = 1.0;
    _placements.clear();
    _signedPages
      ..clear()
      ..add(1);
    notifyListeners();
  }
}
