import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admindashboard_helpers.dart';

import 'admin_tabs.dart';

class ReservationsTab extends StatefulWidget {
  final Stream<QuerySnapshot> reservationsStream;
  final FirebaseFirestore firestore;

  const ReservationsTab({
    super.key,
    required this.reservationsStream,
    required this.firestore,
  });

  @override
  State<ReservationsTab> createState() => _ReservationsTabState();
}

class _ReservationsTabState extends State<ReservationsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterReservations(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final apartmentName = (data['apartmentName'] ?? 
          data['propertyName'] ?? 
          data['apartmentTitle'] ?? '').toString().toLowerCase();
      final guestEmail = (data['guestEmail'] ?? '').toString().toLowerCase();
      final guestName = (data['guestName'] ?? 
          data['guestFullName'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return apartmentName.contains(query) || 
             guestEmail.contains(query) ||
             guestName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by apartment name, guest name, or email...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: kPrimaryBlue, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Reservations List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.reservationsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kPrimaryBlue),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading reservations: ${snapshot.error}',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return InfoTab(message: "No reservations found");
                }

                final allReservations = snapshot.data!.docs;
                final filteredReservations = _filterReservations(allReservations);

                if (filteredReservations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No reservations match your search',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                          child: const Text('Clear search'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredReservations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filteredReservations[index];
                    final data = doc.data() as Map<String, dynamic>;
              
              // Extract reservation details
              final apartmentName = data['apartmentName'] ?? 
                  data['propertyName'] ?? 
                  data['apartmentTitle'] ?? 
                  'Unknown Property';
              final guestName = data['guestName'] ?? 
                  data['guestFullName'] ?? 
                  'Unknown Guest';
              final hostName = data['hostName'] ?? 
                  data['hostFullName'] ?? 
                  'Unknown Host';
              
              // Status handling
              final status = (data['status']?.toString() ?? 'pending').toLowerCase();
              
              // Dates
              final checkIn = data['checkIn'] is Timestamp 
                  ? (data['checkIn'] as Timestamp).toDate() 
                  : null;
              final checkOut = data['checkOut'] is Timestamp 
                  ? (data['checkOut'] as Timestamp).toDate() 
                  : null;
              
              final checkInText = checkIn != null 
                  ? '${checkIn.day}/${checkIn.month}/${checkIn.year}' 
                  : 'N/A';
              final checkOutText = checkOut != null 
                  ? '${checkOut.day}/${checkOut.month}/${checkOut.year}' 
                  : 'N/A';
              
              // Amount
              final amount = data['totalAmount'] ?? 
                  data['amount'] ?? 
                  data['price'] ?? 
                  0;
              final amountText = '₦${amount.toString()}';

              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => ReservationDetailsDialog(
                      reservationId: doc.id,
                      reservationData: data,
                      firestore: widget.firestore,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.grey.shade50,
                      ],
                    ),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Icon/Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                kPrimaryBlue.withOpacity(0.3),
                                kPrimaryBlue.withOpacity(0.1),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.apartment,
                              color: kPrimaryBlue,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Reservation info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                apartmentName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Guest: $guestName',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$checkInText - $checkOutText',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Status badge and amount
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _statusBadge(status),
                            const SizedBox(height: 8),
                            Text(
                              amountText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Chevron
                        Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
          )
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'confirmed':
      case 'active':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Confirmed';
        break;
      case 'completed':
      case 'complete':
        color = Colors.blue;
        icon = Icons.done_all;
        label = 'Completed';
        break;
      case 'cancelled':
      case 'canceled':
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Cancelled';
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.schedule;
        label = 'Pending';
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
        label = status.isNotEmpty 
            ? status[0].toUpperCase() + status.substring(1) 
            : 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Reservation Details Dialog
class ReservationDetailsDialog extends StatefulWidget {
  final String reservationId;
  final Map<String, dynamic> reservationData;
  final FirebaseFirestore firestore;

  const ReservationDetailsDialog({
    super.key,
    required this.reservationId,
    required this.reservationData,
    required this.firestore,
  });

  @override
  State<ReservationDetailsDialog> createState() => _ReservationDetailsDialogState();
}

class _ReservationDetailsDialogState extends State<ReservationDetailsDialog> {
  bool _saving = false;

  Future<void> _updateStatus(String newStatus) async {
    final reservationRef = widget.firestore.collection('reservations').doc(widget.reservationId);
    setState(() => _saving = true);
    try {
      await reservationRef.update({'status': newStatus});
      setState(() {
        widget.reservationData['status'] = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteReservation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Reservation'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final reservationRef = widget.firestore.collection('reservations').doc(widget.reservationId);
      
      try {
        await reservationRef.delete();
      } catch (deleteError) {
        if (deleteError.toString().contains('PERMISSION_DENIED') || 
            deleteError.toString().contains('Missing or insufficient permissions')) {
          await reservationRef.update({
            'deleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
            'status': 'cancelled',
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reservation marked as deleted and cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
          return;
        }
        rethrow;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation deleted successfully'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting reservation: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservationData;
    
    // Extract all details
    final apartmentName = reservation['apartmentName'] ?? 
        reservation['propertyName'] ?? 
        reservation['apartmentTitle'] ?? 
        'Unknown Property';
    final guestName = reservation['guestName'] ?? 
        reservation['guestFullName'] ?? 
        'Unknown Guest';
    final hostName = reservation['hostName'] ?? 
        reservation['hostFullName'] ?? 
        'Unknown Host';
    final guestEmail = reservation['guestEmail'] ?? 'Not provided';
    final hostEmail = reservation['hostEmail'] ?? 'Not provided';
    final guestPhone = reservation['guestPhone'] ?? 'Not provided';
    
    final status = (reservation['status']?.toString() ?? 'pending').toLowerCase();
    
    final checkIn = reservation['checkIn'] is Timestamp 
        ? (reservation['checkIn'] as Timestamp).toDate() 
        : null;
    final checkOut = reservation['checkOut'] is Timestamp 
        ? (reservation['checkOut'] as Timestamp).toDate() 
        : null;
    final createdAt = reservation['createdAt'] is Timestamp 
        ? (reservation['createdAt'] as Timestamp).toDate() 
        : null;
    
    final checkInText = checkIn != null 
        ? '${checkIn.day}/${checkIn.month}/${checkIn.year}' 
        : 'N/A';
    final checkOutText = checkOut != null 
        ? '${checkOut.day}/${checkOut.month}/${checkOut.year}' 
        : 'N/A';
    final createdText = createdAt != null 
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}' 
        : 'Unknown';
    
    final nights = reservation['nights']?.toString() ?? 
        (checkIn != null && checkOut != null 
            ? checkOut.difference(checkIn).inDays.toString() 
            : '0');
    final guests = reservation['guests']?.toString() ?? 
        reservation['numberOfGuests']?.toString() ?? 
        '1';
    
    final totalAmount = reservation['totalAmount'] ?? 
        reservation['amount'] ?? 
        reservation['price'] ?? 
        0;
    final amountText = '₦${totalAmount.toString()}';
    
    final paymentMethod = reservation['paymentMethod'] ?? 'Not specified';
    final paymentStatus = reservation['paymentStatus'] ?? 'Not specified';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kPrimaryBlue.withOpacity(0.3),
                          kPrimaryBlue.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.apartment,
                        color: kPrimaryBlue,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apartmentName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Reservation ID: ${widget.reservationId}', 
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('Created: $createdText', 
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusBadge(status),
                      const SizedBox(height: 8),
                      Text(
                        amountText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Left: Details
                    Expanded(
                      flex: 3,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Reservation Details',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 14),
                                
                                // Guest Information
                                Text('Guest Information', 
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kPrimaryBlue)),
                                const SizedBox(height: 8),
                                _detailRow('Name', guestName),
                                _detailRow('Email', guestEmail),
                                _detailRow('Phone', guestPhone),
                                
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),
                                
                                // Host Information
                                Text('Host Information', 
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kPrimaryBlue)),
                                const SizedBox(height: 8),
                                _detailRow('Name', hostName),
                                _detailRow('Email', hostEmail),
                                
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),
                                
                                // Booking Information
                                Text('Booking Information', 
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kPrimaryBlue)),
                                const SizedBox(height: 8),
                                _detailRow('Property', apartmentName),
                                _detailRow('Check-in', checkInText),
                                _detailRow('Check-out', checkOutText),
                                _detailRow('Nights', nights),
                                _detailRow('Guests', guests),
                                _detailRow('Status', status[0].toUpperCase() + status.substring(1)),
                                
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),
                                
                                // Payment Information
                                Text('Payment Information', 
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kPrimaryBlue)),
                                const SizedBox(height: 8),
                                _detailRow('Total Amount', amountText),
                                _detailRow('Payment Method', paymentMethod),
                                _detailRow('Payment Status', paymentStatus),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Right: Actions
                    Expanded(
                      flex: 2,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Actions',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),
                              
                              Text('Update Status', 
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              const SizedBox(height: 12),
                              
                              // Status buttons
                              _actionButton(
                                'Confirm Reservation',
                                Icons.check_circle,
                                Colors.green,
                                status != 'confirmed' && !_saving,
                                () => _updateStatus('confirmed'),
                              ),
                              const SizedBox(height: 8),
                              _actionButton(
                                'Mark as Completed',
                                Icons.done_all,
                                Colors.blue,
                                status != 'completed' && !_saving,
                                () => _updateStatus('completed'),
                              ),
                              const SizedBox(height: 8),
                              _actionButton(
                                'Cancel Reservation',
                                Icons.cancel,
                                Colors.orange,
                                status != 'cancelled' && !_saving,
                                () => _updateStatus('cancelled'),
                              ),
                              
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 12),
                              
                              Text('Danger Zone', 
                                  style: TextStyle(fontSize: 13, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              
                              _actionButton(
                                'Delete Reservation',
                                Icons.delete,
                                Colors.red,
                                !_saving,
                                _deleteReservation,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'confirmed':
      case 'active':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Confirmed';
        break;
      case 'completed':
      case 'complete':
        color = Colors.blue;
        icon = Icons.done_all;
        label = 'Completed';
        break;
      case 'cancelled':
      case 'canceled':
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Cancelled';
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.schedule;
        label = 'Pending';
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
        label = status.isNotEmpty 
            ? status[0].toUpperCase() + status.substring(1) 
            : 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87))
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, bool enabled, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 16),
        label: Text(_saving ? 'Processing...' : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }
}