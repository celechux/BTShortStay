// (Updated) my_reservations_page.dart
// - Fixed MyProfilePage navigation to use the correct constructor parameters
// - Kept the Theme wrapper around UserPopupMenu to force popup background to white
// - Added date range filter above the reservation filter
// - Increased paragraph spacing under About BT tab
// - Replaced "Help" tab with "User Agreement", moved it to the end, and added the formatted agreement content
// - Updated navigation mappings so bottom nav index 2 opens the User Agreement (now opens MessagesPage)
// - FIXES: show actual MyProfilePage inline for "My Profile" tab and GuestPrivacyPolicyPage for "Privacy Policy"
// - UPDATED: bottomNavigationBar replaced to match HomePage (Home, Bookings, Messages, Help, Logout)
// - FIX: removed `const` when opening MessagesPage to avoid const_with_non_const diagnostic
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'utils/empty_query_snapshot.dart';
import 'widgets/filter_tabs_with_badges.dart';
import 'widgets/empty_state.dart';
import 'widgets/apartment_reservation_card.dart';
import 'widgets/user_popup_menu.dart';
import 'widgets/my_profile_page.dart';
import 'main.dart';
import 'guest_privacy_policy.dart';
import 'messages_page.dart';

class MyReservationsPage extends StatefulWidget {
  final bool loggedIn;
  final String? userName;
  final String? userUid;
  final VoidCallback onLogout;

  const MyReservationsPage({
    super.key,
    required this.loggedIn,
    required this.userName,
    required this.userUid,
    required this.onLogout,
  });

  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all';
  String? _actualGuestName;
  String? _expandedReservationId;
  String _selectedTab = 'My Bookings';
  int _selectedBottomIndex = 0;

  DateTime? _fromDate;
  DateTime? _toDate;

  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _lightBlue = Color(0xFFE3F2FD);
  static const Color _darkBlue = Color(0xFF1976D2);

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'My Profile', 'icon': Icons.person_rounded},
    {'label': 'My Bookings', 'icon': Icons.calendar_today_rounded},
    {'label': 'Report an Issue', 'icon': Icons.report_problem_rounded},
    {'label': 'About BT', 'icon': Icons.info_rounded},
    {'label': 'FAQ', 'icon': Icons.question_answer_rounded},
    {'label': 'Privacy Policy', 'icon': Icons.privacy_tip_rounded},
    {'label': 'User Agreement', 'icon': Icons.rule_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fetchGuestName();
  }

  Future<void> _fetchGuestName() async {
    if (widget.userUid == null) return;
    try {
      final doc = await _firestore.collection('guests').doc(widget.userUid).get();
      if (doc.exists && mounted) {
        setState(() {
          _actualGuestName = doc.data()?['guestName']?.toString() ?? widget.userName ?? 'Guest';
        });
      }
    } catch (e) {
      debugPrint('Error fetching guest name: $e');
    }
  }

  Stream<QuerySnapshot> _getReservationsStream() {
    final queryUid = widget.userUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (queryUid == null || queryUid.isEmpty) {
      return Stream.value(EmptyQuerySnapshot());
    }
    return _firestore
        .collection('reservations')
        .where('guestUid', isEqualTo: queryUid)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterReservations(List<QueryDocumentSnapshot> docs) {
    final DateFormat format = DateFormat('yyyy-MM-dd');

    Iterable<QueryDocumentSnapshot> results = docs;

    // Status filter
    if (_selectedFilter != 'all') {
      results = results.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString().toLowerCase() ?? 'pending';
        return status == _selectedFilter;
      });
    }

    // Date range filter: if set, compare using checkIn if available, otherwise createdAt
    if (_fromDate != null && _toDate != null) {
      final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);

      results = results.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        Timestamp? ts = data['checkIn'] as Timestamp?;
        ts ??= data['createdAt'] as Timestamp?;
        if (ts == null) return false;
        final d = ts.toDate();
        return (d.isAtSameMomentAs(from) || d.isAfter(from)) && (d.isAtSameMomentAs(to) || d.isBefore(to));
      });
    }

    return results.toList();
  }

  Future<void> _cancelReservation(String reservationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 48),
        title: const Text(
          'Cancel Reservation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this reservation? This action cannot be undone.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep', style: TextStyle(color: _primaryBlue)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel Reservation'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('reservations').doc(reservationId).update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reservation cancelled successfully'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
            backgroundColor: _primaryBlue,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel reservation: $e'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _downloadAllReservationsPdf() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: _primaryBlue),
        ),
      );

      final queryUid = widget.userUid ?? FirebaseAuth.instance.currentUser?.uid;
      if (queryUid == null) {
        Navigator.pop(context);
        return;
      }

      final snapshot = await _firestore
          .collection('reservations')
          .where('guestUid', isEqualTo: queryUid)
          .get();

      if (snapshot.docs.isEmpty) {
        Navigator.pop(context);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No reservations to download'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      final formatDate = DateFormat('MMM dd, yyyy');
      final formatCurrency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'All Reservations Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Guest: ${_actualGuestName ?? widget.userName ?? 'Guest'}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Generated: ${formatDate.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Total Reservations: ${snapshot.docs.length}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 24),
              pw.Divider(thickness: 2),
            ],
          ),
        ),
      );

      for (var i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        final checkIn = data['checkIn'] as Timestamp?;
        final checkOut = data['checkOut'] as Timestamp?;
        final createdAt = data['createdAt'] as Timestamp?;

        String? address;
        if (data['apartmentId'] != null) {
          try {
            final aptDoc = await _firestore
                .collection('apartments')
                .doc(data['apartmentId'])
                .get();
            address = aptDoc.data()?['address']?.toString();
          } catch (e) {
            debugPrint('Error fetching apartment: $e');
          }
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (context) => [
              pw.Header(
                level: 1,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Reservation ${i + 1} of ${snapshot.docs.length}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'ID: ${doc.id.substring(0, 8)}...',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              _buildPdfRow('Reservation ID', doc.id),
              _buildPdfRow('Apartment', data['apartmentTitle'] ?? 'Unknown'),
              if (address != null && address.isNotEmpty) _buildPdfRow('Address', address),
              pw.Divider(),
              _buildPdfRow('Guest Name', data['guestName'] ?? 'Unknown'),
              _buildPdfRow('Guest Email', data['guestEmail'] ?? ''),
              pw.Divider(),
              _buildPdfRow('Status', data['status'] ?? 'pending'),
              _buildPdfRow('Payment Status', data['paymentStatus'] ?? 'pending'),
              if (checkIn != null) _buildPdfRow('Check-in', formatDate.format(checkIn.toDate())),
              if (checkOut != null) _buildPdfRow('Check-out', formatDate.format(checkOut.toDate())),
              pw.Divider(),
              _buildPdfRow('Number of Nights', '${data['numberOfNights'] ?? data['numberOfDays'] ?? 0}'),
              _buildPdfRow('Price per Night', formatCurrency.format((data['price'] ?? 0).toDouble())),
              _buildPdfRow('Total Amount', formatCurrency.format((data['total'] ?? 0).toDouble())),
              if (createdAt != null) _buildPdfRow('Created', formatDate.format(createdAt.toDate())),
              if (data['paymentReference'] != null && data['paymentReference'].toString().isNotEmpty)
                _buildPdfRow('Payment Reference', data['paymentReference']),
              if (i < snapshot.docs.length - 1) pw.SizedBox(height: 24),
            ],
          ),
        );
      }

      final bytes = await pdf.save();
      final fileName = 'all_reservations_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      Navigator.pop(context);
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded ${snapshot.docs.length} reservations'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primaryBlue,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 140,
            child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  Future<void> _downloadReservationPdf({
    required String reservationId,
    required Map<String, dynamic> data,
    String? address,
    String? guestName,
    String? guestPhone,
  }) async {
    final formatDate = DateFormat('MMM dd, yyyy');
    final formatCurrency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final checkIn = data['checkIn'] as Timestamp?;
    final checkOut = data['checkOut'] as Timestamp?;
    final createdAt = data['createdAt'] as Timestamp?;
    final pdf = pw.Document();

    String val(dynamic v) => (v ?? '').toString();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Reservation Details',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 8),
          _buildPdfRow('Reservation ID', reservationId),
          _buildPdfRow('Apartment', val(data['apartmentTitle'])),
          if (address != null && address.isNotEmpty) _buildPdfRow('Address', address),
          _buildPdfRow('Guest Name', guestName ?? val(data['guestName'])),
          _buildPdfRow('Guest Email', val(data['guestEmail'])),
          if (guestPhone != null && guestPhone.isNotEmpty) _buildPdfRow('Guest Phone', guestPhone),
          _buildPdfRow('Status', val(data['status'])),
          _buildPdfRow('Payment Status', val(data['paymentStatus'])),
          if (checkIn != null) _buildPdfRow('Check-in', formatDate.format(checkIn.toDate())),
          if (checkOut != null) _buildPdfRow('Check-out', formatDate.format(checkOut.toDate())),
          _buildPdfRow('Number of Nights', '${data['numberOfNights'] ?? data['numberOfDays'] ?? 0}'),
          _buildPdfRow('Price per Night', formatCurrency.format((data['price'] ?? 0).toDouble())),
          _buildPdfRow('Total Amount', formatCurrency.format((data['total'] ?? 0).toDouble())),
          if (createdAt != null) _buildPdfRow('Created', formatDate.format(createdAt.toDate())),
          if (val(data['paymentReference']).isNotEmpty) _buildPdfRow('Payment Reference', val(data['paymentReference'])),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'reservation_$reservationId.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  void _showReservationDetails(
    String reservationId,
    Map<String, dynamic> data, {
    String? address,
    String? guestName,
    String? guestPhone,
  }) {
    final formatDate = DateFormat('MMM dd, yyyy');
    final formatCurrency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final checkIn = data['checkIn'] as Timestamp?;
    final checkOut = data['checkOut'] as Timestamp?;
    final createdAt = data['createdAt'] as Timestamp?;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: _primaryBlue.withOpacity(0.15),
                  radius: 32,
                  child: Icon(Icons.receipt_long_rounded, color: _primaryBlue, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reservation Details',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _detailCard([
                  _detailRow('Reservation ID', reservationId),
                  _detailRow('Apartment', data['apartmentTitle'] ?? 'Unknown'),
                  if (address != null && address.isNotEmpty) _detailRow('Address', address),
                ]),
                const SizedBox(height: 12),
                _detailCard([
                  _detailRow('Guest Name', guestName ?? data['guestName'] ?? 'Unknown'),
                  if ((data['guestEmail'] ?? '').toString().isNotEmpty) _detailRow('Guest Email', data['guestEmail']),
                  if (guestPhone != null && guestPhone.isNotEmpty) _detailRow('Guest Phone', guestPhone),
                ]),
                const SizedBox(height: 12),
                _detailCard([
                  _detailRow('Status', data['status'] ?? 'pending'),
                  _detailRow('Payment Status', data['paymentStatus'] ?? 'pending'),
                  if (checkIn != null) _detailRow('Check-in', formatDate.format(checkIn.toDate())),
                  if (checkOut != null) _detailRow('Check-out', formatDate.format(checkOut.toDate())),
                ]),
                const SizedBox(height: 12),
                _detailCard([
                  _detailRow('Number of Nights', '${data['numberOfNights'] ?? data['numberOfDays'] ?? 0}'),
                  _detailRow('Price per Night', formatCurrency.format((data['price'] ?? 0).toDouble())),
                  _detailRow('Total Amount', formatCurrency.format((data['total'] ?? 0).toDouble())),
                  if (createdAt != null) _detailRow('Created', formatDate.format(createdAt.toDate())),
                  if (data['paymentReference'] != null && data['paymentReference'].toString().isNotEmpty)
                    _detailRow('Payment Reference', data['paymentReference']),
                ]),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _downloadReservationPdf(
                        reservationId: reservationId,
                        data: data,
                        address: address,
                        guestName: guestName,
                        guestPhone: guestPhone,
                      ),
                      icon: Icon(Icons.download_rounded, color: _primaryBlue, size: 20),
                      label: const Text('Download PDF'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _primaryBlue, width: 1.5),
                        foregroundColor: _primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _lightBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryBlue.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _primaryBlue,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportAnIssueContent() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: isMobile ? 16 : 24),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 880),
          padding: EdgeInsets.all(isMobile ? 18 : 28),
          decoration: BoxDecoration(
            color: _lightBlue,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report an Issue',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emergency_rounded,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Emergency Contact',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'For emergency issues, you can reach us:',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildContactItem(
                      icon: Icons.phone_rounded,
                      label: '07041977207',
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 10),
                    _buildContactItem(
                      icon: Icons.phone_rounded,
                      label: '08035140692',
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 10),
                    _buildContactItem(
                      icon: Icons.email_rounded,
                      label: 'support@btshortstay.com',
                      isMobile: isMobile,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _primaryBlue.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.home_rounded,
                          color: _primaryBlue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Host or Apartment Issues',
                          style: TextStyle(
                            color: _primaryBlue,
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'If you have any issues with a specific host or apartment:',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _primaryBlue.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Kindly reach out to us using the message box on the specific apartment to help us keep track of your issues as it relates with the host/apartment.',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: isMobile ? 13 : 14,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_rounded,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We\'re here to help! Providing detailed information about your issue helps us resolve it faster.',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: isMobile ? 12 : 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAgreementContent() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final headingStyle = TextStyle(
      color: _primaryBlue,
      fontSize: isMobile ? 18 : 20,
      fontWeight: FontWeight.w800,
    );
    final sectionTitle = TextStyle(
      fontSize: isMobile ? 15 : 16,
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    );
    final bodyStyle = TextStyle(
      fontSize: isMobile ? 13 : 14,
      color: Colors.black87,
      height: 1.6,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: isMobile ? 16 : 24),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 880),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade50.withOpacity(0.9),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: _primaryBlue.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BT ShortStay – Guest User Agreement', style: headingStyle),
              const SizedBox(height: 8),
              Text('Last Updated: October 2025', style: TextStyle(color: Colors.black54, fontSize: isMobile ? 12 : 13)),
              const SizedBox(height: 16),
              Text(
                'Welcome to BT ShortStay. By creating an account or using the BT ShortStay mobile app, website, or any related services (collectively, “the Platform”), you agree to the following terms and conditions (“Agreement”). Please read this Agreement carefully before using BT ShortStay.',
                style: bodyStyle,
              ),
              const SizedBox(height: 18),

              // Sections
              Text('1. Overview', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'BT ShortStay is a Nigerian accommodation platform that connects guests seeking short-term stays (“Guests,” “you”) with verified property owners (“Hosts”) offering apartments for rent. We act as an intermediary platform only — not as a landlord, agent, or property owner.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('2. Eligibility', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'To use BT ShortStay, you must:\n\n'
                '- Be at least 18 years old.\n'
                '- Provide accurate and complete information when registering.\n'
                '- Agree to comply with all applicable laws and regulations in Nigeria.\n'
                '- If you register on behalf of another person or entity, you represent that you have the legal authority to do so.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('3. Account Registration', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'You must create an account to make a booking. You agree to keep your login credentials confidential, be responsible for all activity that occurs under your account, and notify us immediately if you suspect unauthorized access. BT ShortStay reserves the right to suspend or terminate accounts found to be fraudulent or in violation of this Agreement.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('4. Booking and Payments', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'When you make a booking you agree to pay the total booking amount displayed on the platform, including taxes and service charges (if applicable). All payments are processed securely through Paystack or other approved payment providers. A booking is only confirmed once payment has been successfully completed and you receive a confirmation message or email. BT ShortStay does not guarantee the accuracy of a Host’s listing but takes steps to verify listings before they appear on the app.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('5. Cancellations and Refunds', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'Each Host sets their own cancellation policy, displayed on the apartment listing before booking. If you cancel a booking within the allowed timeframe, you may receive a partial or full refund as per the host’s policy. Refunds are processed through your original payment method and may take 5–10 working days to reflect. BT ShortStay reserves the right to charge a small service fee for processing cancellations.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('6. Guest Responsibilities', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'As a Guest, you agree to treat the host’s property with respect and care, follow all apartment rules set by the Host, not engage in illegal or disruptive activities on the premises, and leave the apartment in good condition at checkout. Any damages, loss, or violations may result in charges, account suspension, or legal action.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('7. Platform Rules and Conduct', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'You must not use BT ShortStay for fraudulent or unlawful purposes, misuse the messaging system or harass hosts, circumvent the platform to make off-app payments, or post false reviews or misleading information. Violations may result in suspension or permanent removal from the platform.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('8. Our Role', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'BT ShortStay provides a platform for connecting Guests and Hosts. We do not own or manage the listed apartments and are not responsible for the condition, safety, or legality of any property. We facilitate payments and communication only. In case of disputes between Guests and Hosts, we may help mediate but are not obligated to resolve conflicts or offer compensation.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('9. Privacy', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'Your personal information is handled according to our Privacy Policy, which explains how we collect, use, and protect your data. By using BT ShortStay, you consent to the terms of our Privacy Policy.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('10. Limitation of Liability', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'To the fullest extent permitted by law, BT ShortStay is not liable for any indirect, incidental, or consequential damages arising from your use of the platform. We are not responsible for any disputes, losses, injuries, or damages resulting from stays booked through our platform. Your use of BT ShortStay is at your own risk.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('11. Termination', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'BT ShortStay may suspend or terminate your account at any time if you violate these terms, engage in fraudulent or abusive behavior, or when required by law or regulatory authority. You may also delete your account at any time by contacting support@btshortstay.com.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('12. Updates to This Agreement', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'BT ShortStay may update this Agreement periodically. Changes take effect once published in the app or on our website. Continued use of the platform means you accept the updated terms.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('13. Governing Law', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'This Agreement is governed by the laws of the Federal Republic of Nigeria. Any disputes shall be settled in the competent courts of Nigeria.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),

              Text('14. Contact Us', style: sectionTitle),
              const SizedBox(height: 8),
              Text(
                'For questions or concerns about this Agreement, please contact:\n\nBT ShortStay\nEmail: legal@btshortstay.com\nAlternate: support@btshortstay.com',
                style: bodyStyle,
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required bool isMobile,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.red.shade700,
          size: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftDrawer(bool isMobile) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isMobile ? 40 : 50,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryBlue, _darkBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: isMobile ? 32 : 36,
                  child: Text(
                    (_actualGuestName ?? widget.userName ?? 'G')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: isMobile ? 28 : 32,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _actualGuestName ?? widget.userName ?? 'Guest',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _tabs.map((tab) {
                final isSelected = _selectedTab == tab['label'];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? _lightBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      tab['icon'] as IconData,
                      color: isSelected ? _primaryBlue : Colors.black54,
                      size: 24,
                    ),
                    title: Text(
                      tab['label'] as String,
                      style: TextStyle(
                        color: isSelected ? _primaryBlue : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: isMobile ? 14 : 15,
                      ),
                    ),
                    selected: isSelected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      final label = tab['label'] as String;

                      // Link My Profile to the MyProfilePage that expects `userUid` and `fallbackName`
                      if (label == 'My Profile') {
                        Navigator.pop(context); // close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyProfilePage(
                              userUid: widget.userUid,
                              // MyProfilePage requires `fallbackName` (required)
                              fallbackName: _actualGuestName ?? widget.userName ?? 'Guest',
                              // compact is optional; default is false — you can pass true if you want
                            ),
                          ),
                        );
                        return;
                      }

                      if (label == 'Privacy Policy') {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GuestPrivacyPolicyPage()),
                        );
                        return;
                      }

                      setState(() {
                        _selectedTab = label;
                        if (_selectedTab == 'My Bookings') {
                          _selectedBottomIndex = 1;
                        } else if (_selectedTab == 'User Agreement') {
                          _selectedBottomIndex = 2;
                        }
                      });
                      if (isMobile) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: Colors.red.shade700),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 14 : 15,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (_) {}
                widget.onLogout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MyApp()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'My Profile':
        // show the real profile page inline
        return MyProfilePage(
          userUid: widget.userUid,
          fallbackName: _actualGuestName ?? widget.userName ?? 'Guest',
        );
      case 'My Bookings':
        return _buildBookingsContent();
      case 'Report an Issue':
        return _buildReportAnIssueContent();
      case 'About BT':
        return _buildAboutBtContent();
      case 'FAQ':
        return _buildFaqContent();
      case 'Privacy Policy':
        // show actual privacy policy page
        return const GuestPrivacyPolicyPage();
      case 'User Agreement':
        return _buildUserAgreementContent();
      default:
        return _buildBookingsContent();
    }
  }

  Widget _buildAboutBtContent() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: isMobile ? 16 : 24),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 880),
          padding: EdgeInsets.all(isMobile ? 18 : 28),
          decoration: BoxDecoration(
            color: _lightBlue,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About BT ShortStay',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'BT ShortStay is a Nigerian company dedicated to redefining short-term accommodation experiences. We connect guests seeking convenient, comfortable, and affordable short-stay apartments with verified property owners across Nigeria.',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: isMobile ? 14 : 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Our platform offers a seamless way for travelers, business professionals, and vacationers to find quality short-term housing, while also empowering apartment owners to showcase their properties to a wider audience.',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: isMobile ? 14 : 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'At BT ShortStay, we combine technology, trust, and convenience to make short-term rentals simple, secure, and rewarding for everyone. Whether you need a cozy space for a few nights or want to monetize your property, BT ShortStay provides the perfect solution.',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: isMobile ? 14 : 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqContent() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final questionStyle = TextStyle(
      fontWeight: FontWeight.w800,
      color: _primaryBlue,
      fontSize: isMobile ? 15 : 16,
    );
    final answerStyle = TextStyle(
      color: Colors.black87,
      fontSize: isMobile ? 14 : 15,
      height: 1.5,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: isMobile ? 16 : 24),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 880),
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          decoration: BoxDecoration(
            color: _lightBlue,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAQ',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: isMobile ? 20 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),

              Text('1. What is BT ShortStay?', style: questionStyle),
              const SizedBox(height: 6),
              Text(
                'BT ShortStay is a Nigerian platform that connects guests looking for short-term accommodation with verified apartment owners offering comfortable spaces for rent.',
                style: answerStyle,
              ),
              const SizedBox(height: 14),

              Text('2. How do I book an apartment?', style: questionStyle),
              const SizedBox(height: 6),
              Text(
                'Simply browse available listings, choose your preferred apartment, select your dates, and make a secure payment directly through the app.',
                style: answerStyle,
              ),
              const SizedBox(height: 14),

              Text('3. Are the apartments verified?', style: questionStyle),
              const SizedBox(height: 6),
              Text(
                'Yes. All apartments listed on BT ShortStay are verified to ensure quality, safety, and reliability before being made available for booking.',
                style: answerStyle,
              ),
              const SizedBox(height: 14),

              Text('4. Can I cancel or change my booking?', style: questionStyle),
              const SizedBox(height: 6),
              Text(
                'Yes, but cancellation policies vary by host. You can view the cancellation terms on the apartment\'s listing page before confirming your booking.',
                style: answerStyle,
              ),
              const SizedBox(height: 14),

              Text('5. What payment methods are accepted?', style: questionStyle),
              const SizedBox(height: 6),
              Text(
                'BT ShortStay accepts secure online payments through Paystack and other supported methods, ensuring a smooth and reliable transaction process.',
                style: answerStyle,
              ),
              const SizedBox(height: 14),

              Text('6. Is there customer support if I have an issue with my booking?', style: questionStyle),
              const SizedBox(height: 6),
              Text(
                'Absolutely. You can contact our support team anytime through the in-app chat or via email at support@btshortstay.com',
                style: answerStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderContent(String title, IconData icon) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: _lightBlue,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: _primaryBlue.withOpacity(0.15),
              radius: 48,
              child: Icon(icon, size: 56, color: _primaryBlue),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Coming soon...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final initial = (_fromDate != null && _toDate != null)
        ? DateTimeRange(start: _fromDate!, end: _toDate!)
        : null;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initial,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  Widget _buildDateRangeFilter(bool isMobile) {
    final format = DateFormat('MMM dd, yyyy');
    final label = (_fromDate != null && _toDate != null)
        ? '${format.format(_fromDate!)} - ${format.format(_toDate!)}'
        : 'All dates';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: _lightBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryBlue.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.date_range_rounded, color: _primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_fromDate != null && _toDate != null)
            TextButton(
              onPressed: _clearDateRange,
              child: Text('Clear', style: TextStyle(color: Colors.red.shade700)),
            ),
          IconButton(
            onPressed: _pickDateRange,
            icon: Icon(Icons.edit_calendar_rounded, color: _primaryBlue),
            tooltip: 'Pick date range',
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsContent() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        SizedBox(height: isMobile ? 12 : 16),

        // New date range filter (above the reservation status filter)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 0),
          child: _buildDateRangeFilter(isMobile),
        ),

        if (isMobile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildMobileFilterDropdown(),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _lightBlue,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FilterTabsWithBadges(
              selectedFilter: _selectedFilter,
              onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
              reservationsStream: _getReservationsStream(),
            ),
          ),
        SizedBox(height: isMobile ? 12 : 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getReservationsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return EmptyStateWidget(selectedFilter: _selectedFilter);
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: _primaryBlue),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return EmptyStateWidget(selectedFilter: _selectedFilter);
              }

              final filteredDocs = _filterReservations(snapshot.data!.docs);
              if (filteredDocs.isEmpty) {
                return EmptyStateWidget(selectedFilter: _selectedFilter);
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: filteredDocs.length,
                separatorBuilder: (context, index) => SizedBox(height: isMobile ? 12 : 18),
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 640),
                      child: ApartmentReservationCard(
                        reservationId: doc.id,
                        data: data,
                        firestore: _firestore,
                        onCancel: _cancelReservation,
                        showDetails: _showReservationDetails,
                        guestUid: widget.userUid,
                        expandedReservationId: _expandedReservationId,
                        onToggleExpand: (reservationId) {
                          setState(() {
                            _expandedReservationId = reservationId;
                          });
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _getReservationsStream(),
          builder: (context, snapshot) {
            final hasReservations = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
            if (!hasReservations) return const SizedBox.shrink();
            
            return Container(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 12 : 16,
                horizontal: isMobile ? 16 : 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: ElevatedButton.icon(
                    onPressed: _downloadAllReservationsPdf,
                    icon: Icon(Icons.download_rounded, size: 20),
                    label: const Text('Download Reservations'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 24,
                        vertical: isMobile ? 14 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!widget.loggedIn) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Container(
            margin: EdgeInsets.all(isMobile ? 16 : 32),
            padding: EdgeInsets.all(isMobile ? 24 : 48),
            decoration: BoxDecoration(
              color: _lightBlue,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100.withOpacity(0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: _primaryBlue.withOpacity(0.15),
                  radius: isMobile ? 36 : 48,
                  child: Icon(
                    Icons.login_rounded,
                    size: isMobile ? 42 : 56,
                    color: _primaryBlue,
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 24),
                Text(
                  'Sign in Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _primaryBlue,
                        fontSize: isMobile ? 18 : null,
                      ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Text(
                  'Please log in to view your reservations',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black54,
                        fontSize: isMobile ? 14 : null,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        appBar: AppBar(
          title: Text(
            'My Reservations',
            style: TextStyle(
              color: _primaryBlue,
              fontWeight: FontWeight.w700,
              fontSize: isMobile ? 18 : null,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: _primaryBlue),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          _selectedTab,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: _primaryBlue,
                fontSize: isMobile ? 18 : null,
              ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Wrap UserPopupMenu in a Theme to force popup menu background to white
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: const PopupMenuThemeData(color: Colors.white),
            ),
            child: UserPopupMenu(
              userUid: widget.userUid,
              userName: _actualGuestName ?? widget.userName ?? 'Guest',
              onLogout: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (_) {}
                widget.onLogout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MyApp()),
                  (route) => false,
                );
              },
              onRefreshReservations: () {
                if (mounted) setState(() {});
              },
            ),
          ),
          SizedBox(width: isMobile ? 8 : 16),
        ],
      ),
      drawer: _buildLeftDrawer(isMobile),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
            child: _buildTabContent(),
          ),
        ),
      ),
      
      // Bottom navigation replaced to match HomePage: Home, Bookings, Messages, Help, Logout
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _lightBlue,
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedBottomIndex,
          onTap: (index) {
            setState(() {
              _selectedBottomIndex = index;
            });

            switch (index) {
              case 0: // Home
                // Navigate back to the main apartments listing (HomePage)
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => HomePage(
                      loggedIn: widget.loggedIn,
                      userName: widget.userName,
                      onLogout: widget.onLogout,
                      onLogin: (name, [uid]) {}, // noop for this context
                      userUid: widget.userUid,
                    ),
                  ),
                  (route) => false,
                );
                break;
              case 1: // Bookings (stay on this page / show bookings tab)
                setState(() {
                  _selectedTab = 'My Bookings';
                });
                break;
              case 2: // Messages -> open messages_page.dart
                // Use rootNavigator: true to ensure we have a Navigator above this context
                try {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (context) => MessagesPage()),
                  );
                } catch (e) {
                  debugPrint("❌ Error navigating to Messages: $e");
                  // Fallback: show a snackbar if navigation fails
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Unable to open messages'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _primaryBlue,
                    ),
                  );
                }
                break;
              case 3: // Help => open Report an Issue tab and open drawer
                setState(() {
                  _selectedTab = 'Report an Issue';
                });
                // Try opening drawer (may be no-op on some platforms)
                try {
                  Scaffold.of(context).openDrawer();
                } catch (_) {}
                break;
              case 4: // Logout
                widget.onLogout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MyApp()),
                  (route) => false,
                );
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: _lightBlue,
          selectedItemColor: _primaryBlue,
          unselectedItemColor: Colors.blue.shade700,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message_rounded),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.help_rounded),
              label: 'Help',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.logout_rounded),
              label: 'Logout',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFilterDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getReservationsStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final allCount = docs.length;
        final pendingCount = docs.where((doc) => (doc.data() as Map)['status']?.toString().toLowerCase() == 'pending').length;
        final confirmedCount = docs.where((doc) => (doc.data() as Map)['status']?.toString().toLowerCase() == 'confirmed').length;
        final cancelledCount = docs.where((doc) => (doc.data() as Map)['status']?.toString().toLowerCase() == 'cancelled').length;
        final completedCount = docs.where((doc) => (doc.data() as Map)['status']?.toString().toLowerCase() == 'completed').length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _lightBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryBlue.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFilter,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: _primaryBlue),
              style: TextStyle(
                color: _primaryBlue,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              dropdownColor: _lightBlue,
              borderRadius: BorderRadius.circular(16),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => _selectedFilter = newValue);
                }
              },
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: _buildDropdownItem('All Reservations', allCount, Icons.list_rounded),
                ),
                DropdownMenuItem(
                  value: 'pending',
                  child: _buildDropdownItem('Pending', pendingCount, Icons.schedule_rounded, Colors.orange.shade600),
                ),
                DropdownMenuItem(
                  value: 'confirmed',
                  child: _buildDropdownItem('Confirmed', confirmedCount, Icons.check_circle_rounded, Colors.green.shade700),
                ),
                DropdownMenuItem(
                  value: 'cancelled',
                  child: _buildDropdownItem('Cancelled', cancelledCount, Icons.cancel_rounded, Colors.red.shade700),
                ),
                DropdownMenuItem(
                  value: 'completed',
                  child: _buildDropdownItem('Completed', completedCount, Icons.task_alt_rounded, Colors.blue.shade700),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdownItem(String label, int count, IconData icon, [Color? color]) {
    final itemColor = color ?? _primaryBlue;
    return Row(
      children: [
        Icon(icon, color: itemColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: itemColor),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: itemColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: itemColor.withOpacity(0.4), width: 1),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: itemColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}