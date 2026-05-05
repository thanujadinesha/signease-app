import 'dart:typed_data';

enum SignatureMode { draw, text, upload }

class SignatureData {
  final SignatureMode mode;
  final Uint8List? imageBytes; // PNG bytes of the signature
  final String font;
  final String text;

  const SignatureData({
    required this.mode,
    this.imageBytes,
    this.font = 'Dancing Script',
    this.text = '',
  });

  SignatureData copyWith({
    SignatureMode? mode,
    Uint8List? imageBytes,
    String? font,
    String? text,
  }) =>
      SignatureData(
        mode: mode ?? this.mode,
        imageBytes: imageBytes ?? this.imageBytes,
        font: font ?? this.font,
        text: text ?? this.text,
      );
}

enum DocumentType { pdf, image }

class DocumentData {
  final String name;
  final int sizeBytes;
  final DocumentType type;
  final Uint8List? fileBytes;
  final int totalPages;

  const DocumentData({
    required this.name,
    required this.sizeBytes,
    required this.type,
    this.fileBytes,
    this.totalPages = 1,
  });
}

class SignaturePlacement {
  final double x;
  final double y;
  final double w;
  final double h;
  final double rotation; // degrees
  final double opacity; // 0.0–1.0

  const SignaturePlacement({
    this.x = 40,
    this.y = 60,
    this.w = 160,
    this.h = 60,
    this.rotation = 0,
    this.opacity = 1.0,
  });

  SignaturePlacement copyWith({
    double? x,
    double? y,
    double? w,
    double? h,
    double? rotation,
    double? opacity,
  }) =>
      SignaturePlacement(
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
        rotation: rotation ?? this.rotation,
        opacity: opacity ?? this.opacity,
      );
}
