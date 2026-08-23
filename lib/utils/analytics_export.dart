import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'ui_helpers.dart';

/// Shared CSV-encode-and-share machinery — works the same way on web,
/// Android, and iOS because the bytes are handed over in memory (no
/// filesystem/path_provider dependency). Every `export*Csv` function below
/// only differs in what columns/rows it builds; this is the one place that
/// actually encodes and opens the share sheet.
Future<void> _shareCsv(
  BuildContext context, {
  required String filenamePrefix,
  required String subject,
  required List<List<dynamic>> rows,
}) async {
  try {
    final csvText = Csv().encode(rows);
    final bytes = Uint8List.fromList(utf8.encode(csvText));
    final stamp = DateTime.now().toIso8601String().split('T').first;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: '${filenamePrefix}_$stamp.csv',
            mimeType: 'text/csv',
          ),
        ],
        subject: subject,
      ),
    );
  } catch (error) {
    if (context.mounted) {
      showMessage(context, 'Unable to export CSV: $error', error: true);
    }
  }
}

Future<void> exportReportsCsv(
  BuildContext context,
  List<Map<String, dynamic>> reports,
) {
  return _shareCsv(
    context,
    filenamePrefix: 'bantaydengue_reports',
    subject: 'BantayDengue reports export',
    rows: [
      ['Report ID', 'Type', 'Status', 'Location', 'Reported at'],
      for (final r in reports)
        [
          r['id'],
          humanize(r['report_type'] as String?),
          humanize(r['status'] as String?),
          r['location_text'] ?? '',
          formatDateTime(r['created_at']),
        ],
    ],
  );
}

Future<void> exportUsersCsv(
  BuildContext context,
  List<Map<String, dynamic>> users,
) {
  return _shareCsv(
    context,
    filenamePrefix: 'bantaydengue_users',
    subject: 'BantayDengue user directory export',
    rows: [
      ['Full name', 'Email', 'Role', 'Barangay', 'Active', 'Joined'],
      for (final u in users)
        [
          u['full_name'] ?? '',
          u['email'] ?? '',
          humanize(u['role'] as String?),
          u['barangay'] ?? '',
          (u['is_active'] as bool? ?? true) ? 'Yes' : 'No',
          formatDateTime(u['created_at']),
        ],
    ],
  );
}

Future<void> exportWasteCsv(
  BuildContext context,
  List<Map<String, dynamic>> requests,
) {
  return _shareCsv(
    context,
    filenamePrefix: 'bantaydengue_waste_requests',
    subject: 'BantayDengue waste requests export',
    rows: [
      [
        'Request ID',
        'Location',
        'Status',
        'Requested by',
        'Preferred date',
        'Requested at',
      ],
      for (final w in requests)
        [
          w['id'],
          w['location_text'] ?? '',
          humanize(w['status'] as String?),
          (w['profiles'] as Map<String, dynamic>?)?['full_name'] ?? '',
          formatDateTime(w['scheduled_at']),
          formatDateTime(w['created_at']),
        ],
    ],
  );
}

Future<void> exportAppointmentsCsv(
  BuildContext context,
  List<Map<String, dynamic>> appointments,
) {
  return _shareCsv(
    context,
    filenamePrefix: 'bantaydengue_appointments',
    subject: 'BantayDengue appointments export',
    rows: [
      ['Appointment ID', 'Patient', 'Status', 'Scheduled at', 'Reason'],
      for (final a in appointments)
        [
          a['id'],
          (a['profiles'] as Map<String, dynamic>?)?['full_name'] ?? '',
          humanize(a['status'] as String?),
          formatDateTime(a['scheduled_at']),
          a['reason'] ?? '',
        ],
    ],
  );
}

/// Builds and opens the platform print/save dialog for a one-page PDF
/// analytics summary — `printing` handles this the same way across web
/// (browser print dialog), Android, iOS, and desktop.
Future<void> exportAnalyticsPdf(
  BuildContext context, {
  required int totalUsers,
  required int pendingReports,
  required int verifiedReports,
  required int activeWaste,
  required Map<String, int> statusCounts,
  required List<({String label, int value})> topHotspots,
}) async {
  final doc = pw.Document();
  final generatedAt = formatDateTime(DateTime.now().toIso8601String());

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'BantayDengue — Administration & Analytics Summary',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated $generatedAt · verified reports only should '
              'inform official local decisions.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfStat('Users', '$totalUsers'),
                _pdfStat('Pending reports', '$pendingReports'),
                _pdfStat('Verified reports', '$verifiedReports'),
                _pdfStat('Active waste requests', '$activeWaste'),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Reports by status',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const ['Status', 'Count'],
              data: statusCounts.entries
                  .map((e) => [humanize(e.key), '${e.value}'])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Hotspots by barangay (verified case count)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            topHotspots.isEmpty
                ? pw.Text(
                    'No hotspot data yet.',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  )
                : pw.TableHelper.fromTextArray(
                    headers: const ['Barangay', 'Verified cases'],
                    data: topHotspots
                        .map((h) => [h.label, '${h.value}'])
                        .toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellStyle: const pw.TextStyle(fontSize: 10),
                  ),
          ],
        );
      },
    ),
  );

  try {
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'bantaydengue_analytics.pdf',
    );
  } catch (error) {
    if (context.mounted) {
      showMessage(context, 'Unable to export PDF: $error', error: true);
    }
  }
}

pw.Widget _pdfStat(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ],
  );
}
