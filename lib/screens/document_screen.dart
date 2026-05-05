import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sign_state.dart';
import '../providers/sign_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/progress_bar.dart';
import 'place_screen.dart';

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  DocumentData? _doc;
  Uint8List? _thumbBytes; // For image docs only

  bool get _hasDoc => _doc != null;

  // ---------------------------------------------------------------------------
  // File picking
  // ---------------------------------------------------------------------------
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final isPdf = file.extension?.toLowerCase() == 'pdf';
    final type = isPdf ? DocumentType.pdf : DocumentType.image;

    int totalPages = 1;
    if (isPdf) {
      // We don't parse the PDF here – just count pages on the Place screen
      // For now, set a placeholder; pdfx will give us actual page count
      totalPages = 1;
    }

    final doc = DocumentData(
      name: file.name,
      sizeBytes: file.size,
      type: type,
      fileBytes: file.bytes,
      totalPages: totalPages,
    );

    if (!mounted) return;
    setState(() {
      _doc = doc;
      _thumbBytes = isPdf ? null : file.bytes;
    });

    if (!mounted) return;
    context.read<SignProvider>().setDocument(doc);
  }

  void _removeFile() {
    setState(() {
      _doc = null;
      _thumbBytes = null;
    });
    context.read<SignProvider>().clearDocument();
  }

  void _onContinue() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PlaceScreen()));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SignProvider>();
    final sig = provider.signature;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppHeader(),
      body: Column(
        children: [
          const ProgressBar(currentStep: 2),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STEP 2 · UPLOAD YOUR DOCUMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text3,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Signature confirmed strip
                  if (sig != null) _SigConfirmedBanner(sig: sig),
                  const SizedBox(height: 14),

                  // Upload card or confirmed card
                  if (_doc == null)
                    _UploadCard(onTap: _pickFile)
                  else
                    _FileConfirmedCard(
                      doc: _doc!,
                      thumbBytes: _thumbBytes,
                      onRemove: _removeFile,
                    ),

                  const SizedBox(height: 20),

                  // Recent files (mock UI)
                  const _RecentSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        primaryLabel: 'Place Signature',
        primaryEnabled: _hasDoc,
        onBack: () => Navigator.of(context).pop(),
        onPrimary: _hasDoc ? _onContinue : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Signature confirmed banner
// ---------------------------------------------------------------------------
class _SigConfirmedBanner extends StatelessWidget {
  final SignatureData sig;

  const _SigConfirmedBanner({required this.sig});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.08),
            AppColors.success.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('✅', style: TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Signature ready',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
              Text(
                '${sig.mode.name.substring(0, 1).toUpperCase()}${sig.mode.name.substring(1)} signature captured',
                style: const TextStyle(fontSize: 10, color: AppColors.text2),
              ),
            ],
          ),
          const Spacer(),
          if (sig.imageBytes != null)
            Container(
              height: 36,
              width: 80,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.memory(sig.imageBytes!, fit: BoxFit.contain),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upload card (empty state)
// ---------------------------------------------------------------------------
class _UploadCard extends StatelessWidget {
  final VoidCallback onTap;

  const _UploadCard({required this.onTap});

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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Choose document',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                Text('PDF or image file',
                    style: TextStyle(fontSize: 10, color: AppColors.text3)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Drop zone
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 36),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.upload_file_outlined,
                              color: AppColors.accent2, size: 28),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Upload or tap to browse',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Drop your document here\nor tap to browse your files',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.text3,
                              height: 1.5),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined,
                                  size: 10, color: AppColors.text2),
                              SizedBox(width: 4),
                              Text(
                                'Secure · Local Processing',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Format pills
                Row(
                  children: [
                    _FormatPill(label: 'PDF', color: AppColors.danger, onTap: onTap),
                    const SizedBox(width: 6),
                    _FormatPill(label: 'JPG', color: const Color(0xFFFB923C), onTap: onTap),
                    const SizedBox(width: 6),
                    _FormatPill(label: 'PNG', color: AppColors.success, onTap: onTap),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FormatPill({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
            ),
            const SizedBox(width: 5),
            Text('$label Document',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// File confirmed card
// ---------------------------------------------------------------------------
class _FileConfirmedCard extends StatelessWidget {
  final DocumentData doc;
  final Uint8List? thumbBytes;
  final VoidCallback onRemove;

  const _FileConfirmedCard({
    required this.doc,
    this.thumbBytes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = doc.type == DocumentType.pdf;
    final kbStr = (doc.sizeBytes / 1024).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // File type icon
                Container(
                  width: 48,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isPdf
                          ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                          : [const Color(0xFF059669), const Color(0xFF34D399)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.description,
                          color: Colors.white, size: 20),
                      Text(
                        isPdf ? 'PDF' : 'IMG',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$kbStr KB · ${isPdf ? 'PDF Document' : 'Image File'}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.text3),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.close,
                        size: 16, color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
          // Image thumbnail
          if (thumbBytes != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Image.memory(
                thumbBytes!,
                width: double.infinity,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          // PDF page indicator
          if (isPdf)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  ...List.generate(
                    5,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i == 0 ? AppColors.accent : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '5 pages',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.text3,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent section (mock)
// ---------------------------------------------------------------------------
class _RecentSection extends StatelessWidget {
  const _RecentSection();

  static const _items = [
    ('NDA_Agreement_2024.pdf', 'pdf', '2h ago'),
    ('invoice_scan.jpg', 'img', 'Yesterday'),
    ('Lease_Agreement.pdf', 'pdf', '3 days ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('RECENT FILES',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text3,
                    letterSpacing: 1)),
            GestureDetector(
              onTap: () {},
              child: const Text('Clear',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent2)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._items.map((item) => _RecentItem(
              name: item.$1,
              type: item.$2,
              date: item.$3,
            )),
      ],
    );
  }
}

class _RecentItem extends StatelessWidget {
  final String name;
  final String type;
  final String date;

  const _RecentItem({required this.name, required this.type, required this.date});

  @override
  Widget build(BuildContext context) {
    final isPdf = type == 'pdf';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPdf
                    ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                    : [const Color(0xFF059669), const Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isPdf ? 'PDF' : 'IMG',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(date,
              style: const TextStyle(fontSize: 10, color: AppColors.text3)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.text3, size: 16),
        ],
      ),
    );
  }
}
