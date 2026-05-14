import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

// ─── Signer slot colors ───────────────────────────────────────────────────────

const _kSlotColors = [
  Color(0xFF8B5CF6),
  Color(0xFF3B82F6),
  Color(0xFF34D399),
  Color(0xFFFB923C),
  Color(0xFFF87171),
  Color(0xFF2DD4BF),
];

Color _slotColor(int slot) => _kSlotColors[(slot - 1) % _kSlotColors.length];

// ─── Screen ───────────────────────────────────────────────────────────────────

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  SigningRequestInfo? _request;
  List<AuditEvent>?  _auditEvents;
  bool  _loadingRequest = true;
  bool  _loadingAudit   = false;
  bool  _auditExpanded  = false;
  bool  _downloadingCert = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loadingRequest = true; _error = null; });
    try {
      final r = await ApiService.instance.getRequest(widget.requestId);
      if (!mounted) return;
      setState(() { _request = r; _loadingRequest = false; });
      if (r.isCompleted) _loadAudit();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loadingRequest = false; });
    }
  }

  Future<void> _loadAudit() async {
    setState(() => _loadingAudit = true);
    try {
      final events = await ApiService.instance.getAuditTrail(widget.requestId);
      if (mounted) setState(() { _auditEvents = events; _loadingAudit = false; });
    } catch (_) {
      if (mounted) setState(() { _auditEvents = null; _loadingAudit = false; });
    }
  }

  Future<void> _downloadCertificate() async {
    setState(() => _downloadingCert = true);
    try {
      final bytes = await ApiService.instance.downloadCertificate(widget.requestId);
      final dir   = await getTemporaryDirectory();
      final name  = (_request?.documentName ?? 'document').replaceAll(RegExp(r'\.[^.]+$'), '');
      final file  = File('${dir.path}/$name-certificate.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Certificate of completion');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _downloadingCert = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppHeader(
        tagline: _request?.documentName ?? 'Request Detail',
        showProfile: false,
      ),
      body: _loadingRequest
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      _buildStatusBanner(),
                      const SizedBox(height: 16),
                      _buildSignerList(),
                      if (_request!.isCompleted) ...[
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                        if (_auditEvents != null && _auditEvents!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildAuditSection(),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  // ── Status banner ─────────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final r = _request!;
    final signed = r.signedCount;
    final total  = r.totalSlots;
    final pct    = total > 0 ? signed / total : 0.0;

    Color bannerBorder = AppColors.accent.withValues(alpha: 0.25);
    Color bannerBg     = AppColors.accent.withValues(alpha: 0.05);
    Color headColor    = AppColors.text;
    String headline;

    if (r.isCompleted) {
      bannerBorder = AppColors.success.withValues(alpha: 0.3);
      bannerBg     = AppColors.success.withValues(alpha: 0.05);
      headColor    = AppColors.success;
      headline     = 'All signatures complete';
    } else if (r.isExpired) {
      bannerBorder = AppColors.danger.withValues(alpha: 0.3);
      bannerBg     = AppColors.danger.withValues(alpha: 0.05);
      headColor    = AppColors.danger;
      headline     = 'Signing request expired';
    } else {
      final remaining = total - signed;
      headline = 'Awaiting $remaining more signature${remaining != 1 ? 's' : ''}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: headColor)),
                    const SizedBox(height: 2),
                    Text(_formatDate(r.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                  ],
                ),
              ),
              Text('$signed/$total',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: headColor)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(headColor),
              minHeight: 6,
            ),
          ),
          if (r.expiresAt != null) ...[
            const SizedBox(height: 8),
            _ExpiryChip(expiresAt: r.expiresAt!, isExpired: r.isExpired),
          ],
        ],
      ),
    );
  }

  // ── Signer list ───────────────────────────────────────────────────────────

  Widget _buildSignerList() {
    final r = _request!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Text('Signing order & status',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text2)),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...r.slots.asMap().entries.map((entry) {
            final i    = entry.key;
            final slot = entry.value;
            final signed    = slot.signedAt != null;
            final isCurrent = !signed && slot.slot == r.currentSlot;
            final isWaiting = !signed && slot.slot > r.currentSlot;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _slotColor(slot.slot),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(slot.label,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                            Text(slot.email,
                                style: const TextStyle(fontSize: 11, color: AppColors.text3),
                                overflow: TextOverflow.ellipsis),
                            if (signed)
                              Text('Signed ${_formatDate(slot.signedAt!)}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.success)),
                          ],
                        ),
                      ),
                      if (signed)
                        _Chip('Signed', AppColors.success)
                      else if (isCurrent)
                        _Chip('Notified', AppColors.accent2)
                      else if (isWaiting)
                        _Chip('Waiting', AppColors.text3),
                    ],
                  ),
                ),
                if (i < r.slots.length - 1)
                  const Divider(height: 1, indent: 58, color: AppColors.border),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _downloadingCert ? null : _downloadCertificate,
            icon: _downloadingCert
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_outlined, size: 18),
            label: Text(_downloadingCert ? 'Downloading…' : 'Download Certificate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: AppColors.accent2),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Premium: Certificate includes full audit trail with IP addresses and SHA-256 signature hashes.',
                  style: TextStyle(fontSize: 11, color: AppColors.text2, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Audit section ─────────────────────────────────────────────────────────

  Widget _buildAuditSection() {
    final events = _auditEvents!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _auditExpanded = !_auditExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: AppColors.accent2),
                  const SizedBox(width: 8),
                  const Text('Audit Trail',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('${events.length}',
                        style: const TextStyle(fontSize: 10, color: AppColors.text3)),
                  ),
                  const Spacer(),
                  Icon(
                    _auditExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.text3,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_auditExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: events.asMap().entries.map((entry) {
                  final i  = entry.key;
                  final ev = entry.value;
                  return _AuditRow(event: ev, isLast: i == events.length - 1);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Audit row ────────────────────────────────────────────────────────────────

class _AuditRow extends StatelessWidget {
  final AuditEvent event;
  final bool isLast;
  const _AuditRow({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    switch (event.eventType) {
      case 'slot_signed':
      case 'completed':
        dotColor = AppColors.success;
        break;
      case 'slot_viewed':
        dotColor = AppColors.accent2;
        break;
      default:
        dotColor = AppColors.text3;
    }

    final ts = '${event.createdAt.day}/${event.createdAt.month} '
        '${event.createdAt.hour.toString().padLeft(2, '0')}:${event.createdAt.minute.toString().padLeft(2, '0')}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                if (!isLast)
                  Expanded(child: Container(width: 1.5,
                      color: AppColors.border.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(event.label,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: dotColor)),
                      if (event.slot != null)
                        Text(' · Signer ${event.slot}',
                            style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                      const Spacer(),
                      Text(ts, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
                    ],
                  ),
                  if (event.actorEmail != null)
                    Text(event.actorEmail!,
                        style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                  if (event.ipAddress != null)
                    Text('IP: ${event.ipAddress}',
                        style: const TextStyle(fontSize: 10, color: AppColors.text3)),
                  if (event.sigHash != null)
                    Text(
                      'SHA-256: ${event.sigHash!.substring(0, 16)}…',
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.text3, fontFamily: 'monospace'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expiry chip ──────────────────────────────────────────────────────────────

class _ExpiryChip extends StatelessWidget {
  final DateTime expiresAt;
  final bool isExpired;
  const _ExpiryChip({required this.expiresAt, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    if (isExpired) {
      text  = 'Expired ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}';
      color = AppColors.danger;
    } else {
      final diff = expiresAt.difference(DateTime.now()).inDays;
      text  = diff <= 0 ? 'Expiring today' : 'Expires in $diff day${diff != 1 ? 's' : ''}';
      color = AppColors.text3;
    }
    return Row(
      children: [
        Icon(Icons.schedule, size: 11, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

// ─── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text2, fontSize: 13)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                child: const Text('Retry',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
