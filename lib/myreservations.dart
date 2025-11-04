import 'package:mime/mime.dart';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'main.dart'; // for redirection after logout

// Modern color palette for redesign
const Color kPrimaryBlue = Color(0xFF1976D2);
const Color kTabLightBlue = Color(0xFFE3F2FD);
const Color kAccentBlue = Color(0xFF64B5F6);
const Color kShadowBlue = Color(0x803197F5);
const double kCardElevation = 16.0;

// =====================================================================================
// MyReservationsPage
// =====================================================================================
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

class _MyReservationsPageState extends State<MyReservationsPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  String _selectedFilter = 'all';
  String? _actualGuestName;
  // Add this line to your existing state variables
  String? _expandedReservationId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchGuestName();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  // Reservations Stream
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

  // Filter reservations by status
  List<QueryDocumentSnapshot> _filterReservations(
      List<QueryDocumentSnapshot> docs) {
    if (_selectedFilter == 'all') return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status']?.toString().toLowerCase() ?? 'pending';
      return status == _selectedFilter;
    }).toList();
  }

  // Status helpers
  Color _getStatusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'confirmed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'completed':
        return Colors.blue.shade700;
      default:
        return kPrimaryBlue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
    // Cancel reservation
  Future<void> _cancelReservation(String reservationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_rounded, color: Colors.red.shade700),
        title: const Text('Cancel Reservation'),
        content: const Text('Are you sure you want to cancel this reservation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
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
          const SnackBar(
            content: Text('Reservation cancelled successfully'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel reservation: $e'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    }
  }

  // PDF download
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
          _pdfRow('Reservation ID', reservationId),
          _pdfRow('Apartment', val(data['apartmentTitle'])),
          if (address != null && address.isNotEmpty) _pdfRow('Address', address),
          _pdfRow('Guest Name', guestName ?? val(data['guestName'])),
          _pdfRow('Guest Email', val(data['guestEmail'])),
          if (guestPhone != null && guestPhone.isNotEmpty) _pdfRow('Guest Phone', guestPhone),
          _pdfRow('Status', _getStatusDisplayText(val(data['status']))),
          _pdfRow('Payment Status', val(data['paymentStatus'])),
          if (checkIn != null) _pdfRow('Check-in', formatDate.format(checkIn.toDate())),
          if (checkOut != null) _pdfRow('Check-out', formatDate.format(checkOut.toDate())),
          _pdfRow('Number of Nights', '${data['numberOfNights'] ?? data['numberOfDays'] ?? 0}'),
          _pdfRow('Price per Night', formatCurrency.format((data['price'] ?? 0).toDouble())),
          _pdfRow('Total Amount', formatCurrency.format((data['total'] ?? 0).toDouble())),
          if (createdAt != null) _pdfRow('Created', formatDate.format(createdAt.toDate())),
          if (val(data['paymentReference']).isNotEmpty) _pdfRow('Payment Reference', val(data['paymentReference'])),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'reservation_$reservationId.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  pw.Widget _pdfRow(String label, String value) {
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

  void _showReservationDetails(String reservationId, Map<String, dynamic> data,
    {String? address, String? guestName, String? guestPhone}) {
  final formatDate = DateFormat('MMM dd, yyyy');
  final formatCurrency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
  final checkIn = data['checkIn'] as Timestamp?;
  final checkOut = data['checkOut'] as Timestamp?;
  final createdAt = data['createdAt'] as Timestamp?;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      // FIXED: More restrictive padding and max width constraint
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Container(
        // FIXED: Added max width constraint
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24), // FIXED: Reduced padding from 32 to 24
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kAccentBlue, width: 2),
          boxShadow: [
            BoxShadow(
              color: kShadowBlue,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_rounded, color: kPrimaryBlue, size: 40), // FIXED: Reduced icon size
              const SizedBox(height: 12),
              Text('Reservation Details',
                style: TextStyle(
                  fontSize: 20, // FIXED: Reduced font size from 24 to 20
                  fontWeight: FontWeight.bold,
                  color: kPrimaryBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20), // FIXED: Reduced spacing from 24 to 20
              _detailCard([
                _detailRow('Reservation ID', reservationId),
                _detailRow('Apartment', data['apartmentTitle'] ?? 'Unknown'),
                if (address != null && address.isNotEmpty) _detailRow('Address', address),
              ]),
              const SizedBox(height: 12), // FIXED: Reduced spacing from 16 to 12
              _detailCard([
                _detailRow('Guest Name', guestName ?? data['guestName'] ?? 'Unknown'),
                if ((data['guestEmail'] ?? '').toString().isNotEmpty) _detailRow('Guest Email', data['guestEmail']),
                if (guestPhone != null && guestPhone.isNotEmpty) _detailRow('Guest Phone', guestPhone),
              ]),
              const SizedBox(height: 12),
              _detailCard([
                _detailRow('Status', _getStatusDisplayText(data['status'] ?? 'pending')),
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
              const SizedBox(height: 20), // FIXED: Reduced spacing from 24 to 20
              // FIXED: Made buttons more compact
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
                    icon: const Icon(Icons.download_rounded, color: kPrimaryBlue, size: 18),
                    label: const Text('Download PDF'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPrimaryBlue, width: 1.5),
                      foregroundColor: kPrimaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // FIXED: Reduced padding
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // FIXED: Reduced padding
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
    return Card(
      elevation: kCardElevation / 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      color: kTabLightBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kAccentBlue, width: 1.5),
      ),
      shadowColor: kShadowBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: kPrimaryBlue,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, color: kPrimaryBlue, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
    // Filter Tabs with Badges
  // Filter Tabs with Badges - FIXED VERSION
Widget _buildFilterTabsWithBadges() {
  return StreamBuilder<QuerySnapshot>(
    stream: _getReservationsStream(),
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? [];
      final allCount = docs.length;
      final pendingCount = docs.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'pending').length;
      final confirmedCount = docs.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'confirmed').length;
      final completedCount = docs.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'completed').length;
      final cancelledCount = docs.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'cancelled').length;

      Widget buildTab(String value, String label, int count, IconData icon) {
        final isSelected = _selectedFilter == value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : kPrimaryBlue),
              const SizedBox(width: 4),
              Text(
                label, 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  color: isSelected ? Colors.white : kPrimaryBlue,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : kPrimaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? kPrimaryBlue : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        width: double.infinity,
        color: kTabLightBlue,
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'all',
                    label: buildTab('all', 'All', allCount, Icons.list_rounded),
                  ),
                  ButtonSegment(
                    value: 'pending',
                    label: buildTab('pending', 'Pending', pendingCount, Icons.schedule_rounded),
                  ),
                  ButtonSegment(
                    value: 'confirmed',
                    label: buildTab('confirmed', 'Confirmed', confirmedCount, Icons.check_circle_rounded),
                  ),
                  ButtonSegment(
                    value: 'completed',
                    label: buildTab('completed', 'Completed', completedCount, Icons.task_alt_rounded),
                  ),
                  ButtonSegment(
                    value: 'cancelled',
                    label: buildTab('cancelled', 'Cancelled', cancelledCount, Icons.cancel_rounded),
                  ),
                ],
                selected: {_selectedFilter},
                onSelectionChanged: (value) {
                  setState(() => _selectedFilter = value.first);
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: kPrimaryBlue,
                  selectedForegroundColor: Colors.white,
                  backgroundColor: Colors.white,
                  foregroundColor: kPrimaryBlue,
                  side: const BorderSide(color: kPrimaryBlue, width: 1.5),
                  elevation: kCardElevation / 3,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}  // Empty State Widget
  Widget _buildEmptyState({bool isFiltered = false}) {
    String title;
    String subtitle;
    IconData icon;

    if (!isFiltered) {
      title = 'No reservations yet';
      subtitle = 'Your reservations will appear here once you make a booking';
      icon = Icons.event_busy_rounded;
    } else {
      switch (_selectedFilter) {
        case 'pending':
          title = 'No Pending Reservations';
          subtitle = "You don't have any pending reservations at the moment";
          icon = Icons.schedule_rounded;
          break;
        case 'confirmed':
          title = 'No Confirmed Reservations';
          subtitle = "You don't have any confirmed reservations at the moment";
          icon = Icons.check_circle_rounded;
          break;
        case 'completed':
          title = 'No Completed Reservations';
          subtitle = "You don't have any completed reservations at the moment";
          icon = Icons.task_alt_rounded;
          break;
        case 'cancelled':
          title = 'No Cancelled Reservations';
          subtitle = "You don't have any cancelled reservations at the moment";
          icon = Icons.cancel_rounded;
          break;
        default:
          title = 'No reservations for this filter';
          subtitle = 'Try selecting a different filter';
          icon = Icons.filter_list_off_rounded;
      }
    }

    return Center(
      child: Card(
        elevation: kCardElevation,
        margin: const EdgeInsets.all(32),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: kAccentBlue, width: 2),
        ),
        shadowColor: kShadowBlue,
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 80,
                color: kPrimaryBlue,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kPrimaryBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    if (!widget.loggedIn) {
      return Scaffold(
        backgroundColor: kTabLightBlue,
        body: Center(
          child: Card(
            elevation: kCardElevation,
            margin: const EdgeInsets.all(32),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: kAccentBlue, width: 2),
            ),
            shadowColor: kShadowBlue,
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.login_rounded,
                    size: 80,
                    color: kPrimaryBlue,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sign in Required',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kPrimaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please log in to view your reservations',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        appBar: AppBar(
          title: const Text('My Reservations', style: TextStyle(color: kPrimaryBlue)),
          centerTitle: true,
          backgroundColor: kTabLightBlue,
          elevation: 0,
        ),
      );
    }

    return Scaffold(
      backgroundColor: kTabLightBlue,
      appBar: AppBar(
        title: Text(
          'My Reservations',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: kPrimaryBlue,
          ),
        ),
        centerTitle: true,
        backgroundColor: kTabLightBlue,
        elevation: 0,
        actions: [
          _UserPopupMenu(
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
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Card(
                  elevation: kCardElevation / 2,
                  color: kTabLightBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: kAccentBlue, width: 2),
                  ),
                  shadowColor: kShadowBlue,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildFilterTabsWithBadges(),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getReservationsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildEmptyState();
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: kPrimaryBlue),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      final filteredDocs = _filterReservations(snapshot.data!.docs);
                      if (filteredDocs.isEmpty) {
                        return _buildEmptyState(isFiltered: true);
                      }

                      // Updated itemBuilder to pass new required parameters
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredDocs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 18),
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: _ApartmentReservationCard(
                                reservationId: doc.id,
                                data: data,
                                firestore: _firestore,
                                onCancel: _cancelReservation,
                                showDetails: _showReservationDetails,
                                guestUid: widget.userUid,
                                expandedReservationId: _expandedReservationId, // NEW
                                onToggleExpand: (reservationId) {                // NEW
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================================
// EmptyQuerySnapshot utility
// =====================================================================================
class EmptyQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => EmptySnapshotMetadata();

  @override
  int get size => 0;
}

class EmptySnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;

  @override
  bool get isFromCache => false;
}
// =====================================================================================
// Expandable Reservation card
// =====================================================================================
class _ApartmentReservationCard extends StatefulWidget {
  final String reservationId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  final Future<void> Function(String) onCancel;
  final void Function(String, Map<String, dynamic>, {String? address, String? guestName, String? guestPhone}) showDetails;
  final String? guestUid;
  final String? expandedReservationId;
  final Function(String?) onToggleExpand;

  const _ApartmentReservationCard({
    required this.reservationId,
    required this.data,
    required this.firestore,
    required this.onCancel,
    required this.showDetails,
    this.guestUid,
    required this.expandedReservationId,
    required this.onToggleExpand,
  });

  @override
  State<_ApartmentReservationCard> createState() => _ApartmentReservationCardState();
}

class _ApartmentReservationCardState extends State<_ApartmentReservationCard> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? apartmentData;
  bool isLoadingApartment = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ApartmentReservationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isExpanded = widget.expandedReservationId == widget.reservationId;
    if (isExpanded) {
      _animationController.forward();
      if (apartmentData == null) {
        _loadApartmentDetails();
      }
    } else {
      _animationController.reverse();
    }
  }

  Future<void> _loadApartmentDetails() async {
    final apartmentId = widget.data['apartmentId'];
    if (apartmentId == null || isLoadingApartment) return;

    setState(() => isLoadingApartment = true);
    
    try {
      final doc = await widget.firestore.collection('apartments').doc(apartmentId).get();
      if (doc.exists && mounted) {
        setState(() {
          apartmentData = doc.data();
          isLoadingApartment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingApartment = false);
      }
      debugPrint('Error loading apartment details: $e');
    }
  }

  void _toggleExpansion() {
    final isCurrentlyExpanded = widget.expandedReservationId == widget.reservationId;
    widget.onToggleExpand(isCurrentlyExpanded ? null : widget.reservationId);
  }

  @override
  Widget build(BuildContext context) {
    final apartmentId = widget.data['apartmentId'];
    final isExpanded = widget.expandedReservationId == widget.reservationId;

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        apartmentId != null ? widget.firestore.collection('apartments').doc(apartmentId).get() : Future.value(null),
        widget.guestUid != null ? widget.firestore.collection('guests').doc(widget.guestUid).get() : Future.value(null),
      ].where((future) => future != null).cast<Future<DocumentSnapshot>>()),
      builder: (context, snapshot) {
        String address = '';
        String? guestName;
        String? guestPhone;

        if (snapshot.hasData && snapshot.data != null) {
          final results = snapshot.data!;

          if (results.isNotEmpty && results[0].exists) {
            final aptData = results[0].data() as Map<String, dynamic>;
            address = aptData['address'] ?? '';
          }

          if (results.length > 1 && results[1].exists) {
            final guestData = results[1].data() as Map<String, dynamic>;
            guestName = guestData['guestName']?.toString();
            guestPhone = guestData['phoneNumber']?.toString();
          }
        }

        return _buildExpandableReservationCard(
          context,
          address: address,
          guestName: guestName,
          guestPhone: guestPhone,
          isExpanded: isExpanded,
        );
      },
    );
  }

  Widget _buildExpandableReservationCard(BuildContext context, {
    required String address, 
    String? guestName, 
    String? guestPhone,
    required bool isExpanded,
  }) {
    final apartmentTitle = widget.data['apartmentTitle'] ?? 'Unknown Apartment';
    final apartmentImage = widget.data['apartmentImage'] ?? '';
    final status = widget.data['status']?.toString() ?? 'pending';
    final numberOfNights = widget.data['numberOfNights'] ?? widget.data['numberOfDays'] ?? 0;
    final price = (widget.data['price'] ?? 0).toDouble();
    final total = (widget.data['total'] ?? 0).toDouble();
    final paymentStatus = widget.data['paymentStatus']?.toString() ?? 'pending';

    final checkIn = widget.data['checkIn'] as Timestamp?;
    final checkOut = widget.data['checkOut'] as Timestamp?;
    final createdAt = widget.data['createdAt'] as Timestamp?;

    final checkInDate = checkIn?.toDate();
    final checkOutDate = checkOut?.toDate();
    final createdDate = createdAt?.toDate();

    final formatDate = DateFormat('MMM dd, yyyy');
    final formatCurrency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

    Color statusColor = _getStatusColor(status, context);

    return Card(
      elevation: kCardElevation,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: isExpanded ? kPrimaryBlue : kAccentBlue, width: isExpanded ? 3 : 2),
      ),
      shadowColor: kShadowBlue,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: kTabLightBlue,
                        border: Border.all(color: kAccentBlue, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: apartmentImage.toString().isNotEmpty
                            ? Image.network(
                                apartmentImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.home_rounded,
                                  size: 32,
                                  color: kPrimaryBlue,
                                ),
                              )
                            : Icon(
                                Icons.home_rounded,
                                size: 32,
                                color: kPrimaryBlue,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: _toggleExpansion,
                            borderRadius: BorderRadius.circular(8),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      apartmentTitle,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: kPrimaryBlue,
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(
                                      Icons.expand_more_rounded,
                                      color: kPrimaryBlue,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: kPrimaryBlue,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: statusColor, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(status),
                                  size: 16,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _getStatusDisplayText(status),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (createdDate != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Booked ${formatDate.format(createdDate)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: kAccentBlue, thickness: 1, height: 2),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _dateInfo(
                        context,
                        'CHECK-IN',
                        checkInDate != null ? formatDate.format(checkInDate) : 'Not set',
                        Icons.login_rounded,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: kPrimaryBlue,
                      ),
                    ),
                    Expanded(
                      child: _dateInfo(
                        context,
                        'CHECK-OUT',
                        checkOutDate != null ? formatDate.format(checkOutDate) : 'Not set',
                        Icons.logout_rounded,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kTabLightBlue,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kAccentBlue, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: kShadowBlue,
                        blurRadius: 9,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${formatCurrency.format(price)} × $numberOfNights nights',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            formatCurrency.format(total),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: kPrimaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Status',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                          _buildPaymentStatus(context, paymentStatus, createdAt),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.showDetails(
                          widget.reservationId,
                          widget.data,
                          address: address,
                          guestName: guestName,
                          guestPhone: guestPhone,
                        ),
                        icon: const Icon(Icons.visibility_rounded, color: kPrimaryBlue),
                        label: const Text('View Details'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: kPrimaryBlue,
                          side: const BorderSide(color: kPrimaryBlue, width: 1.5),
                        ),
                      ),
                    ),
                    if (status.toLowerCase() == 'pending') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => widget.onCancel(widget.reservationId),
                          icon: const Icon(Icons.cancel_rounded, color: Colors.white),
                          label: const Text('Cancel'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Expandable apartment details section
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: kTabLightBlue.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border(
                  top: BorderSide(color: kPrimaryBlue, width: 2),
                ),
              ),
              child: _buildApartmentDetailsSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApartmentDetailsSection() {
    if (isLoadingApartment) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: kPrimaryBlue),
              SizedBox(height: 12),
              Text('Loading apartment details...', style: TextStyle(color: kPrimaryBlue)),
            ],
          ),
        ),
      );
    }

    if (apartmentData == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Unable to load apartment details',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final apartmentImages = (apartmentData!['images'] as List<dynamic>?)?.cast<String>() ?? [];
    final description = apartmentData!['description']?.toString() ?? '';
    final amenities = (apartmentData!['amenities'] as List<dynamic>?)?.cast<String>() ?? [];
    final bedrooms = apartmentData!['bedrooms']?.toString() ?? '0';
    final bathrooms = apartmentData!['bathrooms']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.home_rounded, color: kPrimaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Apartment Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kPrimaryBlue,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _toggleExpansion,
                icon: const Icon(Icons.expand_less_rounded, color: kPrimaryBlue),
                label: const Text('Collapse', style: TextStyle(color: kPrimaryBlue)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Image gallery
          if (apartmentImages.isNotEmpty) ...[
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: apartmentImages.length > 5 ? 5 : apartmentImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Container(
                    width: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kAccentBlue),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        apartmentImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: kTabLightBlue,
                          child: Icon(Icons.image_not_supported, color: kPrimaryBlue),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Basic info
          Row(
            children: [
              _infoChip(Icons.bed_rounded, '$bedrooms Bedrooms'),
              const SizedBox(width: 8),
              _infoChip(Icons.bathtub_rounded, '$bathrooms Bathrooms'),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          if (description.isNotEmpty) ...[
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: kPrimaryBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Amenities
          if (amenities.isNotEmpty) ...[
            Text(
              'Amenities',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: kPrimaryBlue,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: amenities.take(6).map((amenity) => _amenityChip(amenity)).toList(),
            ),
            if (amenities.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${amenities.length - 6} more amenities',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryBlue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kPrimaryBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: kPrimaryBlue,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amenityChip(String amenity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryBlue.withOpacity(0.3)),
      ),
      child: Text(
        amenity,
        style: const TextStyle(
          color: kPrimaryBlue,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _dateInfo(BuildContext context, String label, String value, IconData icon, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alignEnd) ...[
              Icon(icon, size: 16, color: kPrimaryBlue),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: kPrimaryBlue,
              ),
            ),
            if (alignEnd) ...[
              const SizedBox(width: 3),
              Icon(icon, size: 16, color: kPrimaryBlue),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: kPrimaryBlue,
          ),
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        ),
      ],
    );
  }

  Widget _buildPaymentStatus(BuildContext context, String paymentStatus, Timestamp? createdAt) {
    if (paymentStatus.toLowerCase() == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade700.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade700, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 4),
            const Text(
              'PAID',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Countdown timer: 24 hours from 'createdAt'
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        if (createdAt == null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade600.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade600, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: Colors.orange.shade600),
                const SizedBox(width: 4),
                const Text(
                  'PENDING',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        final expiry = createdAt.toDate().add(const Duration(hours: 24));
        final diff = expiry.difference(DateTime.now());

        if (diff.isNegative) {
          widget.firestore.collection('reservations').doc(widget.reservationId).update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade700.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade700, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel_rounded, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 4),
                const Text(
                  'EXPIRED',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        String two(int n) => n.toString().padLeft(2, '0');
        final hh = two(diff.inHours);
        final mm = two(diff.inMinutes.remainder(60));
        final ss = two(diff.inSeconds.remainder(60));

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kPrimaryBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kPrimaryBlue, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, size: 16, color: kPrimaryBlue),
              const SizedBox(width: 4),
              Text(
                '$hh:$mm:$ss left',
                style: const TextStyle(
                  color: kPrimaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'confirmed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'completed':
        return Colors.blue.shade700;
      default:
        return kPrimaryBlue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}

// =====================================================================================
// User menu — opens profile as modal bottom sheet
// =====================================================================================
// ... rest of your file remains unchanged ...
// =====================================================================================
// User menu — opens profile as modal bottom sheet
// =====================================================================================
class _UserPopupMenu extends StatelessWidget {
  final String userName;
  final String? userUid;
  final VoidCallback onLogout;
  final VoidCallback onRefreshReservations;

  const _UserPopupMenu({
    required this.userName,
    required this.userUid,
    required this.onLogout,
    required this.onRefreshReservations,
  });

  void _openProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => MyProfilePage(
        userUid: userUid,
        fallbackName: userName,
        compact: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'User menu',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          border: Border.all(color: kPrimaryBlue, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: kPrimaryBlue,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kPrimaryBlue,
              size: 20,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 1,
          child: ListTile(
            leading: const Icon(Icons.account_circle_rounded, color: kPrimaryBlue),
            title: const Text('My Profile'),
            subtitle: const Text('Edit your profile information'),
          ),
          onTap: () => Future.delayed(Duration.zero, () => _openProfile(context)),
        ),
        PopupMenuItem(
          value: 2,
          child: ListTile(
            leading: const Icon(Icons.refresh_rounded, color: kPrimaryBlue),
            title: const Text('Reservations'),
            subtitle: const Text('View Reservations'),
          ),
          onTap: () => Future.delayed(Duration.zero, onRefreshReservations),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 3,
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Log out'),
            subtitle: const Text('Sign out of your account'),
          ),
          onTap: () => Future.delayed(const Duration(milliseconds: 0), () async {
            try {
              await FirebaseAuth.instance.signOut();
            } catch (_) {}
            onLogout();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MyApp()),
              (route) => false,
            );
          }),
        ),
      ],
    );
  }
}

// =====================================================================================
// MyProfilePage — modern modal profile with photo upload
// =====================================================================================
class MyProfilePage extends StatefulWidget {
  final String? userUid;
  final String fallbackName;
  final bool compact;

  const MyProfilePage({
    super.key,
    required this.userUid,
    required this.fallbackName,
    this.compact = false,
  });

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}
class _MyProfilePageState extends State<MyProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  Timestamp? _createdAt;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    if (widget.userUid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('guests').doc(widget.userUid).get();

      if (doc.exists) {
        final data = doc.data()!;
        _nameCtrl.text = (data['guestName'] ?? widget.fallbackName).toString();
        _emailCtrl.text = (data['email'] ?? '').toString();
        _phoneCtrl.text = (data['phoneNumber'] ?? '').toString();
        _addressCtrl.text = (data['address'] ?? '').toString();
        _createdAt = data['createdAt'];
        _photoUrl = (data['photoUrl'] ?? '').toString().isEmpty ? null : data['photoUrl'];
      } else {
        _nameCtrl.text = widget.fallbackName;
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      _nameCtrl.text = widget.fallbackName;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || widget.userUid == null) return;
    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('guests').doc(widget.userUid).set({
        'guestName': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'photoUrl': _photoUrl,
        'createdAt': _createdAt ?? FieldValue.serverTimestamp(),
        'isActive': true,
        'emailVerified': false,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully"),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save profile: $e"),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    if (widget.userUid == null) return;

    try {
      setState(() => _uploading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _uploading = false);
        return;
      }

      final file = result.files.single;
      final storageRef = FirebaseStorage.instance.ref().child('guest_profiles/${widget.userUid}.jpg');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception('No bytes available for web upload');
        }
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: lookupMimeType(file.path ?? '') ?? 'image/jpeg'),
        );
      } else {
        if (file.bytes != null) {
          uploadTask = storageRef.putData(
            file.bytes as Uint8List,
            SettableMetadata(contentType: lookupMimeType(file.path ?? '') ?? 'image/jpeg'),
          );
        } else if (file.path != null) {
          uploadTask = storageRef.putFile(
            File(file.path!),
            SettableMetadata(contentType: lookupMimeType(file.path ?? '') ?? 'image/jpeg'),
          );
        } else {
          throw Exception('No file data selected');
        }
      }

      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('guests').doc(widget.userUid).set({'photoUrl': url}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _photoUrl = url;
          _uploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    if (widget.userUid == null) return;
    try {
      final storageRef = FirebaseStorage.instance.ref().child('guest_profiles/${widget.userUid}.jpg');
      await storageRef.delete().catchError((_) {});
      await FirebaseFirestore.instance.collection('guests').doc(widget.userUid).set({'photoUrl': FieldValue.delete()}, SetOptions(merge: true));
      if (mounted) {
        setState(() => _photoUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo: $e'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 60,
      backgroundColor: Colors.white,
      backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
      child: _photoUrl == null
          ? Icon(
              Icons.person_rounded,
              size: 60,
              color: kPrimaryBlue,
            )
          : null,
    );

    final avatarEditButton = Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryBlue,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
        ),
        child: IconButton(
          onPressed: _uploading ? null : _pickAndUploadPhoto,
          icon: _uploading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
      ),
    );

    if (widget.compact) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: kAccentBlue, width: 2),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: kPrimaryBlue,
                      backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty) ? NetworkImage(_photoUrl!) : null,
                      child: (_photoUrl == null || _photoUrl!.isEmpty)
                          ? Text(
                              (_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : widget.fallbackName[0]).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Profile',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 21,
                              color: kPrimaryBlue,
                            ),
                          ),
                          Text(
                            'Manage your account information',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: kPrimaryBlue),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Stack(
                                  children: [
                                    avatar,
                                    avatarEditButton,
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              const Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  color: kPrimaryBlue,
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _nameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: const Icon(Icons.person_outline_rounded, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: kTabLightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: const Icon(Icons.email_outlined, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: kTabLightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return null;
                                  final ok = RegExp(r'^.+@.+\..+').hasMatch(v.trim());
                                  return ok ? null : 'Please enter a valid email address';
                                },
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: const Icon(Icons.phone_outlined, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: kTabLightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _addressCtrl,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Address',
                                  prefixIcon: const Icon(Icons.location_on_outlined, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: kTabLightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                ),
                              ),

                              if (_createdAt != null) ...[
                                const SizedBox(height: 24),
                                Card(
                                  elevation: 0,
                                  color: kTabLightBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.event_rounded,
                                          color: kPrimaryBlue,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Member Since',
                                                style: TextStyle(
                                                  color: kPrimaryBlue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('MMMM dd, yyyy').format(_createdAt!.toDate()),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: kPrimaryBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 32),

                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _saveProfile,
                                  icon: _saving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded, color: Colors.white),
                                  label: const Text('Save Changes'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kPrimaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // Full screen version (if compact is false)
    return Scaffold(
      backgroundColor: kTabLightBlue,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: kPrimaryBlue)),
        centerTitle: true,
        backgroundColor: kTabLightBlue,
        elevation: 0,
        actions: [
          FilledButton.icon(
            onPressed: _saving ? null : _saveProfile,
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, color: Colors.white),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: kPrimaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: kTabLightBlue,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: kAccentBlue, width: 1.2)),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    avatar,
                                    avatarEditButton,
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _uploading ? null : _pickAndUploadPhoto,
                                      icon: _uploading
                                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.upload_rounded, color: kPrimaryBlue),
                                      label: const Text('Upload Photo', style: TextStyle(color: kPrimaryBlue)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: kPrimaryBlue, width: 1.2),
                                      ),
                                    ),
                                    if (_photoUrl != null) ...[
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: _removePhoto,
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                        label: const Text('Remove', style: TextStyle(color: Colors.red)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.red, width: 1.2),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: kAccentBlue, width: 1.2)),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Personal Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    color: kPrimaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: const Icon(Icons.person_outline_rounded, color: kPrimaryBlue),
                                    filled: true,
                                    fillColor: kTabLightBlue,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: const Icon(Icons.email_outlined, color: kPrimaryBlue),
                                    filled: true,
                                    fillColor: kTabLightBlue,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return null;
                                    final ok = RegExp(r'^.+@.+\..+').hasMatch(v.trim());
                                    return ok ? null : 'Please enter a valid email address';
                                  },
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    prefixIcon: const Icon(Icons.phone_outlined, color: kPrimaryBlue),
                                    filled: true,
                                    fillColor: kTabLightBlue,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _addressCtrl,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Address',
                                    prefixIcon: const Icon(Icons.location_on_outlined, color: kPrimaryBlue),
                                    filled: true,
                                    fillColor: kTabLightBlue,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                  ),
                                ),

                                if (_createdAt != null) ...[
                                  const SizedBox(height: 24),
                                  Card(
                                    elevation: 0,
                                    color: kTabLightBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.event_rounded,
                                            color: kPrimaryBlue,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Member Since',
                                                  style: TextStyle(
                                                    color: kPrimaryBlue,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('MMMM dd, yyyy').format(_createdAt!.toDate()),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: kPrimaryBlue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 32),

                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _saving ? null : _saveProfile,
                                    icon: _saving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.check_rounded, color: Colors.white),
                                    label: const Text('Save Changes'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: kPrimaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}