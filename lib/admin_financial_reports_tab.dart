import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admindashboard_payments_reports.dart';

class FinancialReportsTab extends StatelessWidget {
  final Stream<QuerySnapshot> reservationsStream;

  const FinancialReportsTab({
    super.key,
    required this.reservationsStream,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FinancialReportsDashboard(reservationsStream: reservationsStream),
    );
  }
}