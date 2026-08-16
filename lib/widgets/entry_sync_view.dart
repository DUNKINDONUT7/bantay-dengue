import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen entry/session loading state, intentionally used only while the
/// app starts, restores a session, or completes sign-in/profile loading.
class EntrySyncView extends StatelessWidget {
  final String title;
  final String message;
  final String cancelLabel;
  final VoidCallback? onCancel;

  const EntrySyncView({
    super.key,
    this.title = 'Syncing your account',
    this.message =
        "We're loading your latest reports and account access.\nThis usually takes a few seconds.",
    this.cancelLabel = 'Cancel',
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                  if (onCancel != null) ...[
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
