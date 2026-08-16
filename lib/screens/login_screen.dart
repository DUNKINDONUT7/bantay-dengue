import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/entry_sync_view.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  int _loginAttempt = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final attempt = ++_loginAttempt;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (attempt != _loginAttempt) await authService.signOut();
      // GoRouter redirects only after the authenticated profile and role load.
    } catch (error) {
      if (mounted && attempt == _loginAttempt) {
        setState(() => _errorMessage = _friendlyError(error));
      }
    } finally {
      if (mounted && attempt == _loginAttempt) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancelLogin() {
    _loginAttempt++;
    setState(() => _isLoading = false);
    unawaited(authService.signOut());
  }

  String _friendlyError(Object error) {
    final message = error is AuthException ? error.message : error.toString();
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login') ||
        normalized.contains('invalid email or password') ||
        normalized.contains('password')) {
      return 'Incorrect email or password.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Confirm your email before signing in.';
    }
    if (normalized.contains('network') || normalized.contains('socket')) {
      return 'No internet connection. Please try again.';
    }
    return message;
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }
    try {
      await authService.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send a reset email right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      eyebrow: 'Secure access',
      title: 'Your barangay response workspace.',
      description:
          'Sign in once and BantayDengue securely opens the correct resident, health center, waste personnel, or administrator workspace.',
      overlay: _isLoading
          ? EntrySyncView(
              title: 'Signing you in',
              message:
                  "We're securely syncing your account and access.\nThis usually takes a few seconds.",
              onCancel: _cancelLogin,
            )
          : null,
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Enter your Supabase account credentials to continue.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const AuthFieldLabel('Email'),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'you@email.com',
                      prefixIcon: Icon(Icons.mail_outline, size: 20),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Email is required';
                      if (!email.contains('@') || !email.contains('.')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  const AuthFieldLabel('Password'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  AuthInlineError(_errorMessage),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: const Text('Sign in securely'),
                  ),
                  const SizedBox(height: 14),
                  const AuthRoleNotice(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Flexible(
                child: Text(
                  "Don't have an account?",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : () => context.go('/signup'),
                child: const Text('Create one'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
