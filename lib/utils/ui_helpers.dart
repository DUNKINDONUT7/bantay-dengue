import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

String humanize(String? value) {
  if (value == null || value.isEmpty) return 'Not specified';
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String formatDateTime(dynamic value) {
  final date = value is DateTime ? value : DateTime.tryParse('$value');
  if (date == null) return 'Not scheduled';
  final local = date.toLocal();
  final hour = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${_months[local.month - 1]} ${local.day}, ${local.year} · $hour:$minute $suffix';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

Color statusColor(String? status, ColorScheme scheme) {
  switch (status) {
    case 'verified':
    case 'resolved':
    case 'approved':
    case 'completed':
    case 'collected':
    case 'low':
      return AppColors.success;
    case 'rejected':
    case 'cancelled':
    case 'high':
      return scheme.error;
    case 'under_review':
    case 'scheduled':
    case 'moderate':
    case 'medium':
      return AppColors.warning;
    default:
      return scheme.primary;
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
}

String errorMessage(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status, Theme.of(context).colorScheme);
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.circle, size: 8, color: color),
      label: Text(humanize(status)),
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.surfaceCard,
    );
  }
}

class AsyncStateView extends StatelessWidget {
  final bool loading;
  final Object? error;
  final bool empty;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onRetry;
  final Widget child;

  const AsyncStateView({
    super.key,
    required this.loading,
    required this.error,
    required this.empty,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 40,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(errorMessage(error!), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (empty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(emptyTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(emptyMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return child;
  }
}
