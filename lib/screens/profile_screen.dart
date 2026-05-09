import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

// ─── Plan data ────────────────────────────────────────────────────────────────

class _PlanInfo {
  final String id;
  final String name;
  final int price;        // USD, 0 = free
  final String period;    // 'year' or ''
  final String sigLabel;  // '3 total', '50 / year', 'Unlimited'
  final List<String> features;
  final Color color;
  final bool popular;

  const _PlanInfo({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    required this.sigLabel,
    required this.features,
    required this.color,
    this.popular = false,
  });
}

const _plans = [
  _PlanInfo(
    id: 'free', name: 'Free', price: 0, period: '', sigLabel: '3 total',
    features: ['3 signatures total', 'PDF & image support', 'Download signed docs'],
    color: AppColors.text3,
  ),
  _PlanInfo(
    id: 'pro', name: 'Pro', price: 25, period: 'year', sigLabel: '50 / year',
    features: ['50 signatures / year', 'All Free features', 'Priority support'],
    color: AppColors.accent2,
    popular: true,
  ),
  _PlanInfo(
    id: 'premium', name: 'Premium', price: 50, period: 'year', sigLabel: 'Unlimited',
    features: ['Unlimited signatures', 'All Pro features', 'Team management'],
    color: AppColors.success,
  ),
];

int _tierLevel(String tier) {
  switch (tier) {
    case 'pro':      return 1;
    case 'premium':
    case 'unlimited': return 2;
    default:          return 0;
  }
}

String _tierLabel(String tier) {
  switch (tier) {
    case 'pro':       return 'Pro';
    case 'premium':
    case 'unlimited': return 'Premium';
    default:          return 'Free';
  }
}

// ─── Upgrade bottom sheet ─────────────────────────────────────────────────────

class _UpgradeSheet extends StatefulWidget {
  final String currentTier;
  const _UpgradeSheet({required this.currentTier});

  @override
  State<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends State<_UpgradeSheet> {
  String? _loading;
  String  _error = '';

  Future<void> _checkout(String plan) async {
    setState(() { _loading = plan; _error = ''; });
    try {
      final url = await ApiService.instance.createCheckoutSession(plan);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _error = 'Could not open payment page');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = _tierLevel(widget.currentTier);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),

            const Text('Choose a Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Upgrade to sign more documents', style: TextStyle(fontSize: 12, color: AppColors.text2)),
            const SizedBox(height: 20),

            if (_error.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                ),
                child: Text(_error, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),

            // Plan cards
            ..._plans.map((plan) {
              final level     = _tierLevel(plan.id == 'free' ? 'free' : plan.id);
              final isCurrent = widget.currentTier == plan.id ||
                  (plan.id == 'premium' && (widget.currentTier == 'premium' || widget.currentTier == 'unlimited'));
              final canUpgrade = !isCurrent && level > currentLevel && plan.id != 'free';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent
                        ? plan.color.withValues(alpha: 0.5)
                        : plan.popular
                            ? AppColors.accent.withValues(alpha: 0.3)
                            : AppColors.border,
                    width: isCurrent || plan.popular ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(plan.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: plan.color)),
                          if (plan.popular) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                              child: const Text('POPULAR', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                            ),
                          ],
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: plan.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: plan.color.withValues(alpha: 0.3)),
                              ),
                              child: Text('CURRENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: plan.color, letterSpacing: 0.5)),
                            ),
                          ],
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                plan.price == 0 ? 'Free' : '\$${plan.price}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                              ),
                              if (plan.period.isNotEmpty)
                                Text('/ ${plan.period}', style: const TextStyle(fontSize: 10, color: AppColors.text3)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...plan.features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: plan.color),
                            const SizedBox(width: 6),
                            Text(f, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
                          ],
                        ),
                      )),
                      if (canUpgrade) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading != null ? null : () => _checkout(plan.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _loading == plan.id
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text('Upgrade to ${plan.name} — \$${plan.price}/yr', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            // Extra seat add-on (Pro/Premium only)
            if (currentLevel >= 1) ...[
              const Divider(color: AppColors.border, height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.person_add_outlined, color: AppColors.success, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Add Team Member', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                          SizedBox(height: 2),
                          Text('\$5 per additional user', style: TextStyle(fontSize: 11, color: AppColors.text2)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _loading != null ? null : () => _checkout('seat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _loading == 'seat'
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success))
                          : const Text('Add \$5', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Secure payment via Stripe · 1-year access · No auto-renewal',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppColors.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile screen ───────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<AuthProvider>().refreshProfile());
  }

  void _showUpgradeSheet() {
    final profile = context.read<AuthProvider>().profile;
    if (profile == null) return;
    final authProvider = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpgradeSheet(currentTier: profile.tier),
    ).then((_) {
      // Refresh after sheet closes in case payment happened
      authProvider.refreshProfile();
    });
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out', style: TextStyle(color: AppColors.text, fontSize: 18)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(color: AppColors.text2, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.text2))),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Sign out', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.chevron_left, color: AppColors.text2, size: 28),
        ),
        title: const Text('My Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHero(profile: profile),
                  const SizedBox(height: 16),

                  _UsageCard(profile: profile),
                  const SizedBox(height: 16),

                  // Plan summary cards
                  _PlanSummaryRow(currentTier: profile.tier),
                  const SizedBox(height: 16),

                  // Upgrade CTA
                  if (_tierLevel(profile.tier) < 2)
                    GestureDetector(
                      onTap: _showUpgradeSheet,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [const Color(0xFF6D28D9).withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0.1)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.bolt, color: AppColors.accent2, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _tierLevel(profile.tier) == 0 ? 'Upgrade to Pro or Premium' : 'Upgrade to Premium',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _tierLevel(profile.tier) == 0 ? 'Pro \$25/yr · Premium \$50/yr' : 'Unlimited signatures for \$50/yr',
                                    style: const TextStyle(fontSize: 11, color: AppColors.text2),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.accent2, size: 20),
                          ],
                        ),
                      ),
                    ),

                  if (_tierLevel(profile.tier) < 2) const SizedBox(height: 12),

                  // Team member CTA (Pro/Premium only)
                  if (_tierLevel(profile.tier) >= 1)
                    GestureDetector(
                      onTap: _showUpgradeSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.person_add_outlined, color: AppColors.success, size: 20),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Add Team Member', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                                  SizedBox(height: 2),
                                  Text('\$5 per additional user', style: TextStyle(fontSize: 11, color: AppColors.text2)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
                          ],
                        ),
                      ),
                    ),

                  if (_tierLevel(profile.tier) >= 1) const SizedBox(height: 16),

                  _SectionHeader(title: 'Account Details'),
                  const SizedBox(height: 10),
                  _DetailRow(icon: Icons.email_outlined,   label: 'Email', value: profile.email),
                  _DetailRow(
                    icon: Icons.shield_outlined,
                    label: 'Plan',
                    value: _tierLabel(profile.tier),
                    valueColor: _tierLevel(profile.tier) >= 2 ? AppColors.success : _tierLevel(profile.tier) == 1 ? AppColors.accent2 : AppColors.text2,
                  ),
                  const SizedBox(height: 24),

                  GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, size: 18, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text('Sign out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Center(
                    child: Text(
                      '🔒  Documents are processed on-device.\nNo files are uploaded to any server.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.text3, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Plan summary row ─────────────────────────────────────────────────────────

class _PlanSummaryRow extends StatelessWidget {
  final String currentTier;
  const _PlanSummaryRow({required this.currentTier});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _plans.map((plan) {
        final isActive = currentTier == plan.id ||
            (plan.id == 'premium' && (currentTier == 'premium' || currentTier == 'unlimited'));
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? plan.color.withValues(alpha: 0.5) : AppColors.border,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(plan.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? plan.color : AppColors.text3)),
                const SizedBox(height: 3),
                Text(plan.price == 0 ? 'Free' : '\$${plan.price}/yr', style: const TextStyle(fontSize: 9, color: AppColors.text3)),
                if (isActive) ...[
                  const SizedBox(height: 4),
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final UserProfile profile;
  const _ProfileHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final level    = _tierLevel(profile.tier);
    final badgeColor = level >= 2 ? AppColors.success : level == 1 ? AppColors.accent2 : AppColors.text3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, Color(0xFF6D28D9)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 20)],
            ),
            child: Center(child: Text(profile.email[0].toUpperCase(), style: GoogleFonts.dmSerifDisplay(fontSize: 26, color: Colors.white))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(_tierLabel(profile.tier), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final UserProfile profile;
  const _UsageCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final used      = profile.signaturesUsed;
    final limit     = profile.limit;
    final remaining = profile.remaining;
    final progress  = limit < 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final isCritical = !profile.isUnlimited && remaining <= 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.accent.withValues(alpha: 0.08), AppColors.accent.withValues(alpha: 0.03)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCritical ? AppColors.danger.withValues(alpha: 0.4) : AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Signature Usage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCritical ? AppColors.danger.withValues(alpha: 0.12) : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isCritical ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
                ),
                child: Text(profile.isUnlimited ? 'Unlimited' : '$used / $limit used',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isCritical ? AppColors.danger : AppColors.text2)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _BigStat(value: '$used', label: 'Signed', color: AppColors.accent),
              const SizedBox(width: 20),
              Container(width: 1, height: 40, color: AppColors.border),
              const SizedBox(width: 20),
              _BigStat(value: profile.isUnlimited ? '∞' : '$remaining', label: 'Remaining', color: isCritical ? AppColors.danger : AppColors.success),
              if (!profile.isUnlimited) ...[
                const SizedBox(width: 20),
                Container(width: 1, height: 40, color: AppColors.border),
                const SizedBox(width: 20),
                _BigStat(value: '$limit', label: 'Limit', color: AppColors.text2),
              ],
            ],
          ),
          if (!profile.isUnlimited) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress, minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(isCritical ? AppColors.danger : AppColors.accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCritical
                  ? remaining == 0 ? 'No signatures remaining — upgrade to continue' : '$remaining signature remaining'
                  : '$remaining of $limit signatures remaining',
              style: TextStyle(fontSize: 11, color: isCritical ? AppColors.danger : AppColors.text3),
            ),
          ],
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value; final String label; final Color color;
  const _BigStat({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 1));
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color? valueColor;
  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.text3),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.text)),
      ],
    ),
  );
}
