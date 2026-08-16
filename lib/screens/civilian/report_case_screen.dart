import 'package:flutter/material.dart';

import '../../widgets/report_form.dart';

class ReportCaseScreen extends StatelessWidget {
  const ReportCaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportForm(
      reportType: 'dengue_case',
      title: 'Report a suspected dengue case',
      description:
          'Send details to the Barangay Health Center for assessment. This report is not a diagnosis and does not replace urgent care.',
      icon: Icons.medical_information_outlined,
    );
  }
}
