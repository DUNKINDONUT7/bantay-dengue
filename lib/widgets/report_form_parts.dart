import 'package:flutter/material.dart';

import '../services/weather_service.dart';
import '../theme/app_theme.dart';

/// Presentation pieces for the report form, kept out of report_form.dart so
/// that file stays about flow and submission rather than layout detail.

// ── Step progress ───────────────────────────────────────────────────────────

class ReportStep {
  final String label;
  final IconData icon;
  final bool complete;
  final bool optional;

  const ReportStep({
    required this.label,
    required this.icon,
    required this.complete,
    this.optional = false,
  });
}

/// A three-stop progress rail across the top of the form. This is a progress
/// *indicator*, not a wizard — the form stays one scrollable page, because
/// splitting a short report across three pages would add taps without
/// removing any work. It exists so a resident can see at a glance how much
/// is left, and which part they still owe.
class ReportStepIndicator extends StatelessWidget {
  final List<ReportStep> steps;
  final Color accent;

  const ReportStepIndicator({
    super.key,
    required this.steps,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = steps.where((s) => s.complete).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: steps[i - 1].complete ? accent : scheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              _StepDot(step: steps[i], index: i, accent: accent),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$done of ${steps.length} sections ready',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final ReportStep step;
  final int index;
  final Color accent;

  const _StepDot({
    required this.step,
    required this.index,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final complete = step.complete;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: complete ? accent : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: complete ? accent : scheme.outline,
              width: 1.4,
            ),
          ),
          child: Icon(
            complete ? Icons.check : step.icon,
            size: 15,
            color: complete ? Colors.white : scheme.outline,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          step.label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: complete ? FontWeight.w700 : FontWeight.w500,
            color: complete ? scheme.onSurface : null,
          ),
        ),
      ],
    );
  }
}

// ── Quick tag chips ─────────────────────────────────────────────────────────

/// Tap-to-toggle chips for the things residents describe over and over —
/// symptoms on a case report, container types on a breeding-site report.
/// Two reasons this exists: typing a full description on a phone is the
/// slowest part of filing, and free text alone gives the reviewing health
/// worker nothing consistent to scan. The selections are folded into the
/// submitted description as a labelled line (see report_form.dart), so no
/// schema change was needed to carry them.
class QuickTagChips extends StatelessWidget {
  final String title;
  final String hint;
  final List<String> options;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;
  final Color accent;

  const QuickTagChips({
    super.key,
    required this.title,
    required this.hint,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.accent,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(hint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isOn = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isOn,
              onSelected: enabled ? (_) => onToggle(option) : null,
              showCheckmark: false,
              avatar: Icon(
                isOn ? Icons.check_circle : Icons.add_circle_outline,
                size: 15,
                color: isOn ? accent : theme.colorScheme.outline,
              ),
              backgroundColor: AppColors.surfaceCard,
              selectedColor: accent.withValues(alpha: 0.14),
              side: BorderSide(
                color: isOn ? accent : theme.colorScheme.outline,
                width: isOn ? 1.3 : 1,
              ),
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Severity ────────────────────────────────────────────────────────────────

enum CaseSeverity {
  mild('Mild', 'Manageable at home so far', AppColors.success),
  moderate('Moderate', 'Getting worse — wants a consultation', AppColors.warning),
  severe('Severe', 'Needs urgent in-person care', AppColors.danger);

  final String label;
  final String hint;
  final Color color;

  const CaseSeverity(this.label, this.hint, this.color);
}

/// How the reporter rates the case right now. Deliberately phrased as the
/// resident's own read of the situation, not a clinical grading — the app is
/// explicit everywhere else that it does not diagnose, and this control must
/// not quietly become an exception to that. Its real job is triage order:
/// it gives the health worker queue something to sort by before anyone has
/// opened the report.
class SeveritySelector extends StatelessWidget {
  final CaseSeverity? value;
  final bool enabled;
  final ValueChanged<CaseSeverity> onChanged;

  const SeveritySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How bad is it right now?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          'Your own read of the situation — this sets how urgently staff review it.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final severity in CaseSeverity.values) ...[
              if (severity != CaseSeverity.values.first)
                const SizedBox(width: 8),
              Expanded(
                child: _SeverityOption(
                  severity: severity,
                  selected: value == severity,
                  enabled: enabled,
                  onTap: () => onChanged(severity),
                ),
              ),
            ],
          ],
        ),
        if (value != null) ...[
          const SizedBox(height: 8),
          Text(value!.hint, style: theme.textTheme.bodySmall),
        ],
        if (value == CaseSeverity.severe) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emergency_outlined,
                  size: 18,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Don't wait on this report. Go to the nearest health "
                    'centre or emergency department now, or call 911.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SeverityOption extends StatelessWidget {
  final CaseSeverity severity;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _SeverityOption({
    required this.severity,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? severity.color.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? severity.color : scheme.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: selected ? severity.color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: severity.color, width: 1.6),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              severity.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weather nudge ───────────────────────────────────────────────────────────

/// Compact breeding-condition banner shown on the breeding-site form. Same
/// app-defined indicator as the dashboard and hotspot map — reused here so a
/// resident reporting stagnant water sees, at that exact moment, whether the
/// week's weather makes it worse. It never claims to describe dengue risk.
class WeatherNudge extends StatelessWidget {
  final WeatherRisk risk;

  const WeatherNudge({super.key, required this.risk});

  Color get _color => switch (risk.label) {
    'high' => AppColors.danger,
    'moderate' => AppColors.warning,
    'low' => AppColors.success,
    _ => AppColors.info,
  };

  String get _headline => switch (risk.label) {
    'high' => 'Breeding conditions are high this week',
    'moderate' => 'Breeding conditions are moderate this week',
    'low' => 'Breeding conditions are low this week',
    _ => 'Breeding conditions unavailable',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rain = risk.precipitationMm;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.water_drop_outlined, size: 18, color: _color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_headline, style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  rain == null
                      ? 'Live forecast unavailable right now.'
                      : '${rain.toStringAsFixed(0)} mm of rain forecast over 7 days. '
                            'Reporting standing water now helps most.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
