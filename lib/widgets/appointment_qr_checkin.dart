import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/appointment_checkin.dart';

/// Shows the resident-facing check-in QR for one approved appointment.
/// Staff scan this (or type the appointment id manually) to check the
/// resident in — see [AppointmentScanScreen].
Future<void> showAppointmentQrDialog(
  BuildContext context, {
  required String appointmentId,
  required String reason,
  required String scheduledLabel,
}) {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 28, color: AppColors.ink),
            const SizedBox(height: 8),
            Text(
              'Check-in code',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            Text(
              scheduledLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: QrImageView(
                data: encodeAppointmentCheckIn(appointmentId),
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Show this to the front desk when you arrive. No personal '
              'details are encoded in the code itself.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Staff-facing scanner: camera scan with a manual-entry fallback for
/// desktop/web sessions without camera access. Pops the raw appointment id
/// on a recognized code, or null if the sheet is dismissed.
class AppointmentScanScreen extends StatefulWidget {
  const AppointmentScanScreen({super.key});

  @override
  State<AppointmentScanScreen> createState() => _AppointmentScanScreenState();
}

class _AppointmentScanScreenState extends State<AppointmentScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  bool _handled = false;
  bool _cameraFailed = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final id = decodeAppointmentCheckIn(raw);
      if (id != null) {
        _handled = true;
        Navigator.pop(context, id);
        return;
      }
    }
  }

  void _submitManual() {
    final id = decodeAppointmentCheckIn(_manualController.text);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Not a recognized check-in code. Paste the full code from the '
            "resident's QR screen.",
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan check-in')),
      body: Column(
        children: [
          Expanded(
            child: _cameraFailed
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Camera unavailable on this device. Use manual '
                        'entry below instead.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _cameraFailed = true);
                      });
                      return const SizedBox.shrink();
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'No camera? Paste the code manually.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualController,
                          decoration: const InputDecoration(
                            hintText: 'bantaydengue:appointment:...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _submitManual(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _submitManual,
                        child: const Text('Check in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
