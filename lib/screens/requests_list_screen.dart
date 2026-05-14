import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'request_detail_screen.dart';

class RequestsListScreen extends StatefulWidget {
  const RequestsListScreen({super.key});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  List<SigningRequestInfo>? _requests;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() { _loading = true; _error = null; });
    try {
      final requests = await ApiService.instance.listRequests();
      if (mounted) setState(() { _requests = requests; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppHeader(tagline: 'My Signing Requests'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadRequests)
              : _requests == null || _requests!.isEmpty
                  ? const _EmptyView()
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      color: AppColors.accent,
                      backgroundColor: AppColors.surface,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: _requests!.length,
                        itemBuilder: (_, i) =>
                            _RequestCard(request: _requests![i]),
                      ),
                    ),
    );
  }
}

// ─── Request card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final SigningRequestInfo request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final signed = request.signedCount;
    final total = request.totalSlots;
    final progress = total > 0 ? signed / total : 0.0;
    final isComplete = request.isCompleted;
    final isExpired  = request.isExpired;

    Color borderColor = AppColors.border;
    if (isComplete) borderColor = AppColors.success.withValues(alpha: 0.3);
    if (isExpired)  borderColor = AppColors.danger.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(requestId: request.id),
        ),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppColors.success.withValues(alpha: 0.12)
                      : isExpired
                          ? AppColors.danger.withValues(alpha: 0.1)
                          : AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isComplete
                      ? Icons.check_circle_outline
                      : isExpired
                          ? Icons.timer_off_outlined
                          : Icons.pending_outlined,
                  color: isComplete
                      ? AppColors.success
                      : isExpired
                          ? AppColors.danger
                          : AppColors.accent2,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.documentName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatDate(request.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.text3),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: request.status),
            ],
          ),

          const SizedBox(height: 12),

          // Progress
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? AppColors.success : AppColors.accent,
                    ),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$signed/$total signed',
                style: const TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Signers
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: request.slots.map((slot) {
              final isSigned = slot.signedAt != null;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSigned
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSigned
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSigned ? Icons.check : Icons.schedule,
                      size: 10,
                      color: isSigned ? AppColors.success : AppColors.text3,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      slot.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSigned ? AppColors.success : AppColors.text2,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ), // Container
    ); // GestureDetector
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isComplete = status == 'completed';
    final isExpired  = status == 'expired';
    final Color bg    = isComplete ? AppColors.success.withValues(alpha: 0.12)
                      : isExpired  ? AppColors.danger.withValues(alpha: 0.1)
                      :              AppColors.accent.withValues(alpha: 0.1);
    final Color color = isComplete ? AppColors.success
                      : isExpired  ? AppColors.danger
                      :              AppColors.accent2;
    final String label = isComplete ? 'Completed' : isExpired ? 'Expired' : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─── Empty view ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 56, color: AppColors.text3),
            SizedBox(height: 16),
            Text('No requests yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
            SizedBox(height: 6),
            Text(
              'Send your first signing request from the home screen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.text3, height: 1.5),
            ),
          ],
        ),
      ),
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
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
