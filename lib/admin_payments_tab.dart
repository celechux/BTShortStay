import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admindashboard_helpers.dart';
import 'admindashboard_payments_reports.dart';
import 'admin_tabs.dart'; // if admin_tabs.dart exports admin_info_tab.dart

class PaymentsTab extends StatelessWidget {
  final Stream<QuerySnapshot> reservationsStream;
  final VoidCallback onViewAll;

  const PaymentsTab({
    super.key,
    required this.reservationsStream,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: reservationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return InfoTab(message: "No payment data found");
          }
          return PaymentsDashboard(reservations: snapshot.data!.docs, onViewAll: onViewAll);
        },
      ),
    );
  }
}