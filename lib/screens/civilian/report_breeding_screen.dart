import 'package:flutter/material.dart';

import '../../widgets/report_form.dart';

class ReportBreedingScreen extends StatelessWidget {
  const ReportBreedingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportForm(
      reportType: 'breeding_site',
      title: 'Report a mosquito breeding site',
      description:
          'Report stagnant water, unmanaged containers, blocked drains, or other suspected breeding areas for local verification.',
      icon: Icons.pest_control_outlined,
    );
  }
}
