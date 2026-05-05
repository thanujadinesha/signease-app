import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _success = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.signUp(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) {
      setState(() => _success = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.chevron_left, color: AppColors.text2, size: 28),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _success
              ? _buildSuccessState()
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Create account',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 28,
                          color: AppColors.text,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Start signing documents for free',
                        style:
                            TextStyle(fontSize: 14, color: AppColors.text2),
                      ),

                      // Free tier info chip
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 16, color: AppColors.success),
                            SizedBox(width: 8),
                            Text(
                              'Free tier includes 3 signed documents',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.success),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      AuthFieldLabel(label:'Email address'),
                      const SizedBox(height: 8),
                      AuthField(
                        controller: _emailCtrl,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Enter your email';
                          if (!v.contains('@'))
                            return 'Enter a valid email';
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      AuthFieldLabel(label:'Password'),
                      const SizedBox(height: 8),
                      AuthField(
                        controller: _passCtrl,
                        hint: 'Min. 6 characters',
                        obscure: _obscurePass,
                        suffix: GestureDetector(
                          onTap: () =>
                              setState(() => _obscurePass = !_obscurePass),
                          child: Icon(
                            _obscurePass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.text3,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Enter a password';
                          if (v.length < 6) return 'Minimum 6 characters';
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      AuthFieldLabel(label:'Confirm password'),
                      const SizedBox(height: 8),
                      AuthField(
                        controller: _confirmCtrl,
                        hint: 'Re-enter password',
                        obscure: _obscureConfirm,
                        suffix: GestureDetector(
                          onTap: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                          child: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.text3,
                          ),
                        ),
                        validator: (v) {
                          if (v != _passCtrl.text)
                            return 'Passwords do not match';
                          return null;
                        },
                      ),

                      // Error
                      if (auth.error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 16, color: AppColors.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(auth.error!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.danger)),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 28),

                      AuthButton(
                        label: 'Create account',
                        loading: auth.loading,
                        onTap: _submit,
                      ),

                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Center(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: 'Already have an account? ',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.text2),
                              ),
                              TextSpan(
                                text: 'Sign in',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent2,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.mark_email_read_outlined,
                color: AppColors.success, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Check your email',
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 24, color: AppColors.text),
          ),
          const SizedBox(height: 10),
          const Text(
            'We sent a confirmation link to your email.\nClick it to activate your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppColors.text2, height: 1.6),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Back to Sign in',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
