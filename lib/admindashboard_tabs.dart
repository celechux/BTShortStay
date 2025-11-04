// Admin Dashboard main tabs container
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_tabs.dart';

class AdminDashboardTabs extends StatefulWidget {
  final FirebaseFirestore firestore;
  final int selectedIndex;
  final ValueChanged<int> onTabChange;

  const AdminDashboardTabs({
    super.key,
    required this.firestore,
    required this.selectedIndex,
    required this.onTabChange,
  });

  @override
  State<AdminDashboardTabs> createState() => _AdminDashboardTabsState();
}

class _AdminDashboardTabsState extends State<AdminDashboardTabs> {
  late final Stream<QuerySnapshot> apartmentsStream;
  late final Stream<QuerySnapshot> hostsStream;
  late final Stream<QuerySnapshot> guestsStream;
  late final Stream<QuerySnapshot> reservationsStream;

  @override
  void initState() {
    super.initState();
    apartmentsStream = widget.firestore.collection('apartments').snapshots();
    hostsStream = widget.firestore.collection('hosts').snapshots();
    guestsStream = widget.firestore.collection('guests').snapshots();
    reservationsStream = widget.firestore.collection('reservations').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.selectedIndex,
      children: [
        // Index 0: Overview
        OverviewTab(
          apartmentsStream: apartmentsStream,
          hostsStream: hostsStream,
          guestsStream: guestsStream,
          reservationsStream: reservationsStream,
          onTabChange: widget.onTabChange,
        ),
        // Index 1: Apartments
        ApartmentsTab(
          apartmentsStream: apartmentsStream,
          reservationsStream: reservationsStream,
          firestore: widget.firestore,
        ),
        // Index 2: Hosts
        HostsTab(
          hostsStream: hostsStream,
          firestore: widget.firestore,
        ),
        // Index 3: Guests
        GuestsTab(
          guestsStream: guestsStream,
          firestore: widget.firestore,
        ),
        // Index 4: Reservations
        ReservationsTab(
          reservationsStream: reservationsStream,
          firestore: widget.firestore,
        ),
        // Index 5: Transactions Analytics
        PaymentsTab(
          reservationsStream: reservationsStream,
          onViewAll: () => widget.onTabChange(4),
        ),
        // Index 6: Host Payments
        const InfoTab(message: "Host Payments - Coming Soon"),
        // Index 7: Feedback & Complaints
        FeedbackComplaintsTab(
          firestore: widget.firestore,
        ),
        // Index 8: Announcements
        AnnouncementsTab(firestore: widget.firestore),
      ],
    );
  }
}