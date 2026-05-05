import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String tagline;
  final Widget? trailing;
  final bool showProfile;

  const AppHeader({
    super.key,
    this.tagline = 'Mobile Document Signing',
    this.trailing,
    this.showProfile = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Logo mark
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accent, Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGlow,
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.edit_document,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SignEase',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 17,
                        color: AppColors.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      tagline,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.text2,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (showProfile) const _ProfileIconButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileIconButton extends StatelessWidget {
  const _ProfileIconButton();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final initial = profile?.email.isNotEmpty == true
        ? profile!.email[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, Color(0xFF6D28D9)],
          ),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 12)],
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
