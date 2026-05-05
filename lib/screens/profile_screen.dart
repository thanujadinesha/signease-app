import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh profile data on open
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<AuthProvider>().refreshProfile());
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out',
            style: TextStyle(color: AppColors.text, fontSize: 18)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
      // Auth gate handles navigation
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
        title: const Text(
          'My Account',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: profile == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + info
                  _ProfileHero(profile: profile),
                  const SizedBox(height: 24),

                  // Usage card
                  _UsageCard(profile: profile),
                  const SizedBox(height: 16),

                  // Upgrade card (only for non-unlimited)
                  if (!profile.isUnlimited) _UpgradeCard(profile: profile),
                  if (!profile.isUnlimited) const SizedBox(height: 16),

                  // Account details
                  _SectionHeader(title: 'Account Details'),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: profile.email,
                  ),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Plan',
                    value: _tierLabel(profile.tier),
                    valueColor: _tierColor(profile.tier),
                  ),

                  const SizedBox(height: 24),

                  // Sign out
                  GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, size: 18, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text(
                            'Sign out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Privacy note
                  const Center(
                    child: Text(
                      '🔒  Documents are processed on-device.\nNo files are uploaded to any server.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.text3, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _tierLabel(String tier) {
    switch (tier) {
      case 'pro':
        return 'Pro';
      case 'unlimited':
        return 'Unlimited';
      default:
        return 'Free';
    }
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'pro':
        return AppColors.accent2;
      case 'unlimited':
        return AppColors.success;
      default:
        return AppColors.text2;
    }
  }
}

// ── Profile hero ──────────────────────────────────────────────
class _ProfileHero extends StatelessWidget {
  final UserProfile profile;
  const _ProfileHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initials = profile.email.isNotEmpty
        ? profile.email[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, Color(0xFF6D28D9)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.accentGlow, blurRadius: 20)
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 26, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.email,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _TierBadge(tier: profile.tier),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      'pro' => ('Pro', AppColors.accent),
      'unlimited' => ('Unlimited', AppColors.success),
      _ => ('Free', AppColors.text3),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Usage card ────────────────────────────────────────────────
class _UsageCard extends StatelessWidget {
  final UserProfile profile;
  const _UsageCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final used = profile.signaturesUsed;
    final limit = profile.limit;
    final remaining = profile.remaining;
    final progress = limit < 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final isCritical = !profile.isUnlimited && remaining <= 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.08),
            AppColors.accent.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical
              ? AppColors.danger.withValues(alpha: 0.4)
              : AppColors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Signature Usage',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCritical
                      ? AppColors.danger.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isCritical
                          ? AppColors.danger.withValues(alpha: 0.3)
                          : AppColors.border),
                ),
                child: Text(
                  profile.isUnlimited
                      ? 'Unlimited'
                      : '$used / $limit used',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCritical ? AppColors.danger : AppColors.text2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Big numbers
          Row(
            children: [
              _BigStat(
                value: '$used',
                label: 'Signed',
                color: AppColors.accent,
              ),
              const SizedBox(width: 20),
              Container(width: 1, height: 40, color: AppColors.border),
              const SizedBox(width: 20),
              _BigStat(
                value: profile.isUnlimited ? '∞' : '$remaining',
                label: 'Remaining',
                color: isCritical ? AppColors.danger : AppColors.success,
              ),
              if (!profile.isUnlimited) ...[
                const SizedBox(width: 20),
                Container(width: 1, height: 40, color: AppColors.border),
                const SizedBox(width: 20),
                _BigStat(
                  value: '$limit',
                  label: 'Limit',
                  color: AppColors.text2,
                ),
              ],
            ],
          ),

          if (!profile.isUnlimited) ...[
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(
                  isCritical ? AppColors.danger : AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCritical
                  ? remaining == 0
                      ? 'No signatures remaining — upgrade to continue'
                      : '$remaining signature remaining'
                  : '$remaining of $limit signatures remaining',
              style: TextStyle(
                fontSize: 11,
                color: isCritical ? AppColors.danger : AppColors.text3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _BigStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.text3)),
      ],
    );
  }
}

// ── Upgrade card ──────────────────────────────────────────────
class _UpgradeCard extends StatelessWidget {
  final UserProfile profile;
  const _UpgradeCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6D28D9).withValues(alpha: 0.15),
            AppColors.accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium,
                color: AppColors.accent2, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upgrade to Pro',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.tier == 'free'
                      ? 'Get 50 signatures & priority support'
                      : 'Get unlimited signatures',
                  style: const TextStyle(fontSize: 11, color: AppColors.text2),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFF6D28D9)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account detail row ─────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.text3,
          letterSpacing: 1),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.text3),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
