import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admindashboard_helpers.dart';
import 'admin_tabs.dart';

class ApartmentsTab extends StatefulWidget {
  final Stream<QuerySnapshot> apartmentsStream;
  final Stream<QuerySnapshot> reservationsStream;
  final FirebaseFirestore firestore;

  const ApartmentsTab({
    super.key,
    required this.apartmentsStream,
    required this.reservationsStream,
    required this.firestore,
  });

  @override
  State<ApartmentsTab> createState() => _ApartmentsTabState();
}

class _ApartmentsTabState extends State<ApartmentsTab> {
  String _filterStatus = "All";

  String _getApartmentName(Map<String, dynamic> apartment) {
    // Try multiple possible field names for apartment name
    return apartment['name'] ?? 
           apartment['title'] ?? 
           apartment['apartmentName'] ?? 
           apartment['apartment_name'] ??
           'Apartment';
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: StreamBuilder<QuerySnapshot>(
        stream: widget.apartmentsStream,
        builder: (context, apartmentSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: widget.reservationsStream,
            builder: (context, reservationSnapshot) {
              if (apartmentSnapshot.connectionState == ConnectionState.waiting ||
                  reservationSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: kPrimaryBlue),
                );
              }
              if (!apartmentSnapshot.hasData || apartmentSnapshot.data!.docs.isEmpty) {
                return InfoTab(message: "No apartments found");
              }

              final reservations = reservationSnapshot.hasData
                  ? reservationSnapshot.data!.docs
                  : <QueryDocumentSnapshot>[];
              final apartments = apartmentSnapshot.data!.docs;

              // Calculate counts
              int totalCount = apartments.length;
              int availableCount = apartments.where((doc) {
                return getReservationStatus(doc.id, reservations) == 'Available';
              }).length;
              int reservedCount = apartments.where((doc) {
                return getReservationStatus(doc.id, reservations) == 'Reserved';
              }).length;
              int inactiveCount = apartments.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] != 'active';
              }).length;

              // Filtering logic
              List<QueryDocumentSnapshot> filteredApartments;
              if (_filterStatus == "Available") {
                filteredApartments = apartments.where((doc) =>
                  getReservationStatus(doc.id, reservations) == 'Available'
                ).toList();
              } else if (_filterStatus == "Reserved") {
                filteredApartments = apartments.where((doc) =>
                  getReservationStatus(doc.id, reservations) == 'Reserved'
                ).toList();
              } else if (_filterStatus == "Inactive") {
                filteredApartments = apartments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] != 'active';
                }).toList();
              } else {
                filteredApartments = apartments;
              }

              // Summary cards widget
              Widget summaryCards;
              if (isMobile) {
                summaryCards = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterCard(
                        title: "Total",
                        count: totalCount,
                        icon: Icons.home_work,
                        color: kPrimaryBlue,
                        selected: _filterStatus == "All",
                        onTap: () => setState(() => _filterStatus = "All"),
                      ),
                      const SizedBox(width: 8),
                      _FilterCard(
                        title: "Available",
                        count: availableCount,
                        icon: Icons.check_circle,
                        color: Colors.green,
                        selected: _filterStatus == "Available",
                        onTap: () => setState(() => _filterStatus = "Available"),
                      ),
                      const SizedBox(width: 8),
                      _FilterCard(
                        title: "Reserved",
                        count: reservedCount,
                        icon: Icons.event_busy,
                        color: Colors.orange,
                        selected: _filterStatus == "Reserved",
                        onTap: () => setState(() => _filterStatus = "Reserved"),
                      ),
                      const SizedBox(width: 8),
                      _FilterCard(
                        title: "Inactive",
                        count: inactiveCount,
                        icon: Icons.pause_circle,
                        color: Colors.red,
                        selected: _filterStatus == "Inactive",
                        onTap: () => setState(() => _filterStatus = "Inactive"),
                      ),
                    ],
                  ),
                );
              } else {
                summaryCards = Row(
                  children: [
                    Expanded(
                      child: _FilterCard(
                        title: "Total",
                        count: totalCount,
                        icon: Icons.home_work,
                        color: kPrimaryBlue,
                        selected: _filterStatus == "All",
                        onTap: () => setState(() => _filterStatus = "All"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FilterCard(
                        title: "Available",
                        count: availableCount,
                        icon: Icons.check_circle,
                        color: Colors.green,
                        selected: _filterStatus == "Available",
                        onTap: () => setState(() => _filterStatus = "Available"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FilterCard(
                        title: "Reserved",
                        count: reservedCount,
                        icon: Icons.event_busy,
                        color: Colors.orange,
                        selected: _filterStatus == "Reserved",
                        onTap: () => setState(() => _filterStatus = "Reserved"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FilterCard(
                        title: "Inactive",
                        count: inactiveCount,
                        icon: Icons.pause_circle,
                        color: Colors.red,
                        selected: _filterStatus == "Inactive",
                        onTap: () => setState(() => _filterStatus = "Inactive"),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                    child: summaryCards,
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredApartments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final apartmentDoc = filteredApartments[index];
                        final apartment = apartmentDoc.data() as Map<String, dynamic>;
                        final reservationStatus = getReservationStatus(apartmentDoc.id, reservations);
                        final apartmentName = _getApartmentName(apartment);
                        final apartmentAddress = apartment['address'] ?? 'No address';
                        final apartmentImage = (apartment['image']?.toString() ??
                                apartment['photo']?.toString() ??
                                apartment['photoURL']?.toString() ??
                                '')
                            .trim();
                        final isActive = apartment['status'] == 'active';

                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => ApartmentDetailsDialog(
                                apartmentId: apartmentDoc.id,
                                apartmentData: apartment,
                                reservationStatus: reservationStatus,
                                firestore: widget.firestore,
                                reservations: reservations,
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
                                  // Apartment image/avatar
                                  GestureDetector(
                                    onTap: () {
                                      _showApartmentImagePreview(
                                        context,
                                        apartmentImage,
                                        apartmentName,
                                      );
                                    },
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: apartmentImage.isEmpty
                                            ? LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  kPrimaryBlue.withOpacity(0.3),
                                                  kPrimaryBlue.withOpacity(0.1),
                                                ],
                                              )
                                            : null,
                                      ),
                                      child: apartmentImage.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                apartmentImage,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Center(
                                                  child: Icon(
                                                    Icons.apartment,
                                                    color: kPrimaryBlue,
                                                    size: 28,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Icon(
                                                Icons.apartment,
                                                color: kPrimaryBlue,
                                                size: 28,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Apartment info
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
                                          apartmentAddress,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Status badges
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Reservation status badge
                                      _statusBadge(
                                        reservationStatus,
                                        _getStatusColor(reservationStatus),
                                      ),
                                      // Inactive badge
                                      if (!isActive) ...[
                                        const SizedBox(height: 6),
                                        _statusBadge('Inactive', Colors.red),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(width: 12),

                                  // Chevron
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Reserved':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'Available'
                ? Icons.check_circle
                : label == 'Reserved'
                    ? Icons.event_busy
                    : Icons.circle_outlined,
            size: 14,
            color: color,
          ),
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

  Future<void> _showApartmentImagePreview(
    BuildContext context,
    String imageUrl,
    String title,
  ) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                  color: Colors.grey.shade50,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.apartment, color: kPrimaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.black.withOpacity(0.02),
                constraints: const BoxConstraints(maxHeight: 560),
                child: imageUrl.isNotEmpty
                    ? InteractiveViewer(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, size: 72, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Center(
                          child: Icon(Icons.apartment, size: 72, color: Colors.grey.shade400),
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Apartment Details Dialog
class ApartmentDetailsDialog extends StatefulWidget {
  final String apartmentId;
  final Map<String, dynamic> apartmentData;
  final String reservationStatus;
  final FirebaseFirestore firestore;
  final List<QueryDocumentSnapshot> reservations;

  const ApartmentDetailsDialog({
    super.key,
    required this.apartmentId,
    required this.apartmentData,
    required this.reservationStatus,
    required this.firestore,
    required this.reservations,
  });

  @override
  State<ApartmentDetailsDialog> createState() => _ApartmentDetailsDialogState();
}

class _ApartmentDetailsDialogState extends State<ApartmentDetailsDialog> {
  bool _saving = false;

  String _getApartmentName(Map<String, dynamic> apartment) {
    return apartment['name'] ?? 
           apartment['title'] ?? 
           apartment['apartmentName'] ?? 
           apartment['apartment_name'] ??
           'Apartment';
  }

  Map<String, dynamic>? _getReservationForApartment() {
    try {
      for (var doc in widget.reservations) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['apartmentId'] == widget.apartmentId) {
          return data;
        }
      }
    } catch (e) {
      print('Error finding reservation: $e');
    }
    return null;
  }

  String _getReservationDuration() {
    final reservation = _getReservationForApartment();
    if (reservation == null) return 'No reservation';

    try {
      final checkIn = reservation['checkInDate'];
      final checkOut = reservation['checkOutDate'];

      if (checkIn == null || checkOut == null) {
        return 'Duration not available';
      }

      DateTime checkInDate;
      DateTime checkOutDate;

      if (checkIn is Timestamp) {
        checkInDate = checkIn.toDate();
      } else if (checkIn is String) {
        checkInDate = DateTime.parse(checkIn);
      } else {
        return 'Invalid date format';
      }

      if (checkOut is Timestamp) {
        checkOutDate = checkOut.toDate();
      } else if (checkOut is String) {
        checkOutDate = DateTime.parse(checkOut);
      } else {
        return 'Invalid date format';
      }

      final duration = checkOutDate.difference(checkInDate).inDays;
      return '${checkInDate.toString().split(' ')[0]} to ${checkOutDate.toString().split(' ')[0]} ($duration days)';
    } catch (e) {
      return 'Error calculating duration';
    }
  }

  Future<void> _toggleSuspend() async {
    final apartmentRef = widget.firestore.collection('apartments').doc(widget.apartmentId);
    setState(() => _saving = true);
    try {
      final isActive = widget.apartmentData['status'] == 'active';
      await apartmentRef.update({
        'status': isActive ? 'inactive' : 'active',
      });

      setState(() {
        widget.apartmentData['status'] = isActive ? 'inactive' : 'active';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'Apartment deactivated' : 'Apartment activated'),
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

  Future<void> _deleteApartment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Apartment'),
        content: const Text('Are you sure? This cannot be undone. This will permanently remove the apartment.'),
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
      final apartmentRef = widget.firestore.collection('apartments').doc(widget.apartmentId);
      await apartmentRef.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apartment deleted successfully'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting apartment: ${e.toString()}'),
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
    final apartment = widget.apartmentData;
    final apartmentName = _getApartmentName(apartment);
    final address = apartment['address'] ?? 'Not provided';
    final city = apartment['city'] ?? '';
    final country = apartment['country'] ?? '';
    final location = [city, country].where((s) => s.isNotEmpty).join(', ');
    final price = apartment['price']?.toString() ?? 'Not provided';
    final bedrooms = apartment['bedrooms']?.toString() ?? 'Not provided';
    final bathrooms = apartment['bathrooms']?.toString() ?? 'Not provided';
    final description = apartment['description'] ?? 'No description';
    final isActive = apartment['status'] == 'active';
    final apartmentImage = (apartment['image']?.toString() ??
            apartment['photo']?.toString() ??
            apartment['photoURL']?.toString() ??
            '')
        .trim();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
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
                  // Tappable avatar for larger preview
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => _ApartmentImagePreview(
                          imageUrl: apartmentImage,
                          title: apartmentName,
                        ),
                      );
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: apartmentImage.isEmpty
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  kPrimaryBlue.withOpacity(0.3),
                                  kPrimaryBlue.withOpacity(0.1),
                                ],
                              )
                            : null,
                      ),
                      child: apartmentImage.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                apartmentImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(
                                    Icons.apartment,
                                    color: kPrimaryBlue,
                                    size: 28,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.apartment,
                                color: kPrimaryBlue,
                                size: 28,
                              ),
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
                        Text(address, style: TextStyle(color: Colors.grey.shade600)),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(location, style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusBadge('Active', isActive, isActive ? Colors.green : Colors.grey),
                      const SizedBox(height: 6),
                      _statusBadge(widget.reservationStatus, true, _getStatusColor(widget.reservationStatus)),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Apartment Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 14),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _detailRow('Name', apartmentName),
                                _detailRow('Address', address),
                                if (location.isNotEmpty) _detailRow('Location', location),
                                _detailRow('Price', price),
                                _detailRow('Bedrooms', bedrooms),
                                _detailRow('Bathrooms', bathrooms),
                                _detailRow('Status', isActive ? 'Active' : 'Inactive'),
                                _detailRow('Reservation Status', widget.reservationStatus),
                                if (widget.reservationStatus == 'Reserved') ...[
                                  const SizedBox(height: 12),
                                  _detailRow('Reservation Duration', _getReservationDuration()),
                                ],
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text(description, style: const TextStyle(color: Colors.black87)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Action buttons
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _toggleSuspend,
                                    icon: Icon(isActive ? Icons.pause : Icons.play_arrow, size: 16),
                                    label: Text(_saving ? 'Processing...' : (isActive ? 'Deactivate' : 'Activate')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isActive ? Colors.orange : Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _deleteApartment,
                                    icon: const Icon(Icons.delete, size: 16),
                                    label: Text(_saving ? 'Deleting...' : 'Delete'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Reserved':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _statusBadge(String label, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_circle : Icons.circle_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
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
            width: 130,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

// Reusable image preview widget
class _ApartmentImagePreview extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _ApartmentImagePreview({
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment, color: kPrimaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.black.withOpacity(0.02),
              constraints: const BoxConstraints(maxHeight: 560),
              child: imageUrl.isNotEmpty
                  ? InteractiveViewer(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, size: 72, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Center(
                        child: Icon(Icons.apartment, size: 72, color: Colors.grey.shade400),
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
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
}

// Filter card widget
class _FilterCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? color.withOpacity(0.15) : Colors.white,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}