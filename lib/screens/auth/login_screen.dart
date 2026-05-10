import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.signIn(_emailCtrl.text.trim(), _passCtrl.text);
    // Navigation handled by auth gate in main.dart
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.15),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),

                    // Logo
                    Image.asset(
                      'assets/images/isigner_logo.png',
                      height: 52,
                    ),

                    const SizedBox(height: 48),

                    Text(
                      'Welcome back',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 28,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to your account to continue',
                      style: TextStyle(fontSize: 14, color: AppColors.text2),
                    ),

                    const SizedBox(height: 36),

                    // Email
                    AuthFieldLabel(label:'Email address'),
                    const SizedBox(height: 8),
                    AuthField(
                      controller: _emailCtrl,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter your email';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password
                    AuthFieldLabel(label:'Password'),
                    const SizedBox(height: 8),
                    AuthField(
                      controller: _passCtrl,
                      hint: '••••••••',
                      obscure: _obscure,
                      suffix: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                          color: AppColors.text3,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your password';
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    // Error message
                    if (auth.error != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 16, color: AppColors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.error!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 28),

                    // Sign in button
                    AuthButton(
                      label: 'Sign in',
                      loading: auth.loading,
                      onTap: _submit,
                    ),

                    const SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: const Text('or',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.text3)),
                        ),
                        const Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Register link
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.text2),
                            ),
                            Text(
                              'Create one',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Privacy note
                    const Center(
                      child: Text(
                        '🔒  All documents are processed on-device.\nNo files are ever uploaded to our servers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.text3,
                            height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

