import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_loader.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _remember   = false;

  // For tracking forgot-password loading state independently
  bool _resetLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok   = await auth.login(
        email: _emailCtrl.text, password: _passCtrl.text);
    if (!mounted) return;
    if (!ok && auth.errorMessage != null) {
      AppUtils.showSnackBar(context, auth.errorMessage!, isError: true);
      auth.clearError();
    }
  }

  // ── FORGOT PASSWORD ────────────────────────────────────────────────────────
  //
  // FIX: Call FirebaseAuth.instance.sendPasswordResetEmail() directly so we
  // can inspect the exact FirebaseAuthException code and show useful messages.
  //
  // Root-cause notes:
  //   • "success" was shown before: it fires correctly if the email address
  //     exists in Firebase Auth.  Common reasons the email is not received:
  //     1. Email is in spam/junk folder — very common.
  //     2. The Firebase project has email sending from a sandbox domain.
  //     3. Wrong email address (typo).
  //   • We add a debug log so you can confirm the exact address being sent.
  Future<void> _forgot() async {
    // Capture email before any async work
    String emailText = _emailCtrl.text.trim();

    if (emailText.isEmpty) {
      // Show a dialog so the user can enter their email without leaving the page
      final entered = await _showEmailDialog();
      if (entered == null || entered.isEmpty || !mounted) return;
      emailText = entered;
      _emailCtrl.text = emailText; // pre-fill for convenience
    }

    // Basic email format validation
    final emailError = Validators.validateEmail(emailText);
    if (emailError != null) {
      if (mounted) {
        AppUtils.showSnackBar(context, emailError, isError: true);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _resetLoading = true);

    // Debug log — confirms exact address being used
    dev.log('[ForgotPassword] Sending reset email to: $emailText',
        name: 'AUTH');

    try {
      // Call Firebase directly — most reliable approach
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: emailText.toLowerCase().trim());

      dev.log('[ForgotPassword] Reset email sent successfully to: $emailText',
          name: 'AUTH');

      if (!mounted) return;

      // Show a detailed success dialog (not just a snackbar) so users
      // know to check spam
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_outlined,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Email Sent',
                    style: TextStyle(fontSize: 18))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Password reset email sent to:\n$emailText',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check your spam/junk folder if you do not see it in your inbox within a few minutes.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              const Text(
                'Make sure this email address is registered in FundiHub.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK, Got it'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      dev.log('[ForgotPassword] FirebaseAuthException: '
          'code=${e.code} message=${e.message}', name: 'AUTH');

      if (!mounted) return;
      final msg = _resetErrorMessage(e.code, e.message);
      AppUtils.showSnackBar(context, msg, isError: true);
    } catch (e) {
      dev.log('[ForgotPassword] Unexpected error: $e', name: 'AUTH');
      if (!mounted) return;
      AppUtils.showSnackBar(
        context,
        'Could not send reset email. Please check your internet connection and try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  /// Returns a user-friendly message for each Firebase Auth error code.
  String _resetErrorMessage(String code, String? message) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address. '
            'Please check for typos or register a new account.';
      case 'invalid-email':
        return 'The email address format is invalid. '
            'Please enter a valid email.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many reset requests. Please wait a few minutes and try again.';
      case 'missing-android-pkg-name':
      case 'missing-ios-bundle-id':
      case 'missing-continue-uri':
      case 'invalid-continue-uri':
      case 'unauthorized-continue-uri':
        // Firebase project misconfiguration — rare in production
        return 'Reset email configuration error. '
            'Please contact support.';
      default:
        return message ??
            'Failed to send reset email. '
                'Please try again or contact support.';
    }
  }

  /// Shows a dialog to collect the email address if the field is empty.
  Future<String?> _showEmailDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Enter your account email address. We will send you a link to reset your password.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller:  ctrl,
            keyboardType: TextInputType.emailAddress,
            autofocus:   true,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            decoration: const InputDecoration(
              labelText:   'Email address',
              prefixIcon:  Icon(Icons.email_outlined),
              border:      OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = AppL10n.of(context);
    final loading = auth.isLoading || _resetLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceXXL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTheme.spaceLG),
                const Align(
                  alignment: Alignment.centerRight,
                  child: _LanguageToggleButton(),
                ),
                const SizedBox(height: AppTheme.spaceXXL),
                AuthHeader(
                    title:    l10n.welcomeBack,
                    subtitle: l10n.signInSubtitle),
                const SizedBox(height: AppTheme.space3XL),
                AppTextField(
                  controller:      _emailCtrl,
                  label:           l10n.emailAddress,
                  hint:            l10n.emailHint,
                  prefixIcon:      Icons.email_outlined,
                  keyboardType:    TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator:       Validators.validateEmail,
                ),
                const SizedBox(height: AppTheme.spaceXL),
                AppTextField(
                  controller:      _passCtrl,
                  label:           l10n.password,
                  hint:            l10n.passwordHint,
                  prefixIcon:      Icons.lock_outline,
                  obscureText:     true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v == null || v.isEmpty
                      ? (l10n.sw
                          ? 'Nenosiri linahitajika'
                          : 'Password is required')
                      : null,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                Row(children: [
                  Row(children: [
                    Checkbox(
                        value:     _remember,
                        onChanged: (v) =>
                            setState(() => _remember = v ?? false)),
                    Text(l10n.rememberMe,
                        style: AppTextStyles.bodySmall),
                  ]),
                  const Spacer(),
                  // Forgot password — shows spinner while sending
                  _resetLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width:  18,
                            height: 18,
                            child:  AppLoader(size: 20),
                          ),
                        )
                      : TextButton(
                          onPressed: _forgot,
                          child: Text(
                            l10n.forgotPassword,
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                ]),
                const SizedBox(height: AppTheme.spaceXL),
                AppButton(
                    label:     l10n.signIn,
                    isLoading: loading,
                    onPressed: _login),
                const SizedBox(height: AppTheme.spaceXL),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMD),
                    child: Text(l10n.dontHaveAccount,
                        style: AppTextStyles.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: AppTheme.spaceXL),
                AppButton(
                    label:     l10n.createAccount,
                    type:      AppButtonType.outline,
                    onPressed: loading ? null : () => context.go('/register')),
                const SizedBox(height: AppTheme.spaceMD),
                // ── OR divider ─────────────────────────────────────────
                const SizedBox(height: AppTheme.spaceXL),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMD),
                    child: Text('or',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: AppTheme.spaceXL),
                // ── Google Sign-In ──────────────────────────────────────
                _GoogleSignInButton(loading: loading),
                const SizedBox(height: AppTheme.spaceXL),
                // ── Guest browsing → full client dashboard ─────────────
                TextButton(
                  onPressed: loading ? null : () =>
                      context.go('/client/dashboard'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('Browse as Guest',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space3XL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageToggleButton extends StatelessWidget {
  const _LanguageToggleButton();

  @override
  Widget build(BuildContext context) {
    final lang      = context.watch<LangProvider>();
    final isSwahili = lang.isSwahili;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.read<LangProvider>().toggle(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical:   AppTheme.spaceSM,
          ),
          decoration: BoxDecoration(
            color:        AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border:       Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppTheme.spaceSM),
              Text(
                isSwahili ? 'English' : 'Kiswahili',
                style: AppTextStyles.labelMedium.copyWith(
                  color:      AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Google Sign-In button ─────────────────────────────────────────────────────

class _GoogleSignInButton extends StatefulWidget {
  final bool loading;
  const _GoogleSignInButton({required this.loading});
  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (widget.loading || _busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok   = await auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok && auth.errorMessage != null) {
      AppUtils.showSnackBar(context, auth.errorMessage!, isError: true);
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: widget.loading || _busy ? null : _signIn,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          side:  const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textPrimary,
        ),
        child: _busy
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                      color: Colors.white,
                    ),
                    child: const Center(
                      child: Text('G',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4285F4))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Continue with Google',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ],
              ),
      );
}
