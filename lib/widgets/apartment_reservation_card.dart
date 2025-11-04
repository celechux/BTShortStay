import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ApartmentReservationCard extends StatefulWidget {
  final String reservationId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  final Future<void> Function(String) onCancel;
  final void Function(String, Map<String, dynamic>, {String? address, String? guestName, String? guestPhone}) showDetails;
  final String? guestUid;
  final String? expandedReservationId;
  final Function(String?) onToggleExpand;

  const ApartmentReservationCard({
    super.key,
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
  State<ApartmentReservationCard> createState() => _ApartmentReservationCardState();
}

class _ApartmentReservationCardState extends State<ApartmentReservationCard> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? apartmentData;
  bool isLoadingApartment = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  // Modern color palette
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _lightBlue = Color(0xFFE3F2FD);
  static const Color _darkBlue = Color(0xFF1976D2);

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
  void didUpdateWidget(ApartmentReservationCard oldWidget) {
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
    final isMobile = MediaQuery.of(context).size.width < 600;

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

          if (results.isNotEmpty && results[0].exists == true) {
            final aptData = results[0].data() as Map<String, dynamic>;
            address = aptData['address'] ?? '';
          }

          if (results.length > 1 && results[1].exists == true) {
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
          isMobile: isMobile,
        );
      },
    );
  }

  Widget _buildExpandableReservationCard(
    BuildContext context, {
    required String address,
    String? guestName,
    String? guestPhone,
    required bool isExpanded,
    required bool isMobile,
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

    Color statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
        side: BorderSide(
          color: isExpanded ? _primaryBlue : _primaryBlue.withOpacity(0.3),
          width: isExpanded ? 2 : 1,
        ),
      ),
      shadowColor: Colors.blue.shade100.withOpacity(0.3),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: isMobile ? 52 : 64,
                      height: isMobile ? 52 : 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                        color: _lightBlue,
                        border: Border.all(color: _primaryBlue.withOpacity(0.3), width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                        child: apartmentImage.toString().isNotEmpty
                            ? Image.network(
                                apartmentImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.home_rounded,
                                  size: isMobile ? 24 : 32,
                                  color: _primaryBlue,
                                ),
                              )
                            : Icon(
                                Icons.home_rounded,
                                size: isMobile ? 24 : 32,
                                color: _primaryBlue,
                              ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 10 : 14),
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
                                            color: _primaryBlue,
                                            decoration: TextDecoration.underline,
                                            fontSize: isMobile ? 14 : null,
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
                                      color: _primaryBlue,
                                      size: isMobile ? 18 : 20,
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
                                Icon(
                                  Icons.location_on_outlined,
                                  size: isMobile ? 14 : 16,
                                  color: _primaryBlue,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.black87,
                                          fontSize: isMobile ? 12 : null,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: isMobile ? 6 : 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 10,
                              vertical: isMobile ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: statusColor, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(status),
                                  size: isMobile ? 14 : 16,
                                  color: statusColor,
                                ),
                                SizedBox(width: isMobile ? 4 : 5),
                                Text(
                                  _getStatusDisplayText(status),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: isMobile ? 11 : 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (createdDate != null) ...[
                            SizedBox(height: isMobile ? 4 : 6),
                            Text(
                              'Booked ${formatDate.format(createdDate)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.black54,
                                    fontSize: isMobile ? 11 : null,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 10 : 14),
                Divider(color: _primaryBlue.withOpacity(0.2), thickness: 1, height: 2),
                SizedBox(height: isMobile ? 8 : 10),
                Row(
                  children: [
                    Expanded(
                      child: _dateInfo(
                        context,
                        'CHECK-IN',
                        checkInDate != null ? formatDate.format(checkInDate) : 'Not set',
                        Icons.login_rounded,
                        isMobile: isMobile,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: isMobile ? 16 : 20,
                        color: _primaryBlue,
                      ),
                    ),
                    Expanded(
                      child: _dateInfo(
                        context,
                        'CHECK-OUT',
                        checkOutDate != null ? formatDate.format(checkOutDate) : 'Not set',
                        Icons.logout_rounded,
                        alignEnd: true,
                        isMobile: isMobile,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 8 : 10),
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: _lightBlue,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryBlue.withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${formatCurrency.format(price)} × $numberOfNights nights',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.black87,
                                    fontSize: isMobile ? 12 : null,
                                  ),
                            ),
                          ),
                          Text(
                            formatCurrency.format(total),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _primaryBlue,
                                  fontSize: isMobile ? 16 : null,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 6 : 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Status',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.black87,
                                  fontSize: isMobile ? 12 : null,
                                ),
                          ),
                          _buildPaymentStatus(context, paymentStatus, widget.data['createdAt'] as Timestamp?, isMobile),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 10 : 14),
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
                        icon: Icon(Icons.visibility_rounded, color: _primaryBlue, size: isMobile ? 16 : 18),
                        label: Text('View', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
                          foregroundColor: _primaryBlue,
                          side: BorderSide(color: _primaryBlue, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (status.toLowerCase() == 'pending') ...[
                      SizedBox(width: isMobile ? 6 : 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => widget.onCancel(widget.reservationId),
                          icon: Icon(Icons.cancel_rounded, color: Colors.white, size: isMobile ? 16 : 18),
                          label: Text('Cancel', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                color: _lightBlue.withOpacity(0.5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(isMobile ? 16 : 18),
                  bottomRight: Radius.circular(isMobile ? 16 : 18),
                ),
                border: Border(
                  top: BorderSide(color: _primaryBlue, width: 2),
                ),
              ),
              child: _buildApartmentDetailsSection(isMobile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApartmentDetailsSection(bool isMobile) {
    if (isLoadingApartment) {
      return Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: _primaryBlue),
              SizedBox(height: isMobile ? 8 : 12),
              Text(
                'Loading apartment details...',
                style: TextStyle(color: _primaryBlue, fontSize: isMobile ? 12 : 14),
              ),
            ],
          ),
        ),
      );
    }

    if (apartmentData == null) {
      return Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: const Center(
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
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.home_rounded, color: _primaryBlue, size: isMobile ? 18 : 20),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                'Apartment Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _primaryBlue,
                      fontSize: isMobile ? 14 : null,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _toggleExpansion,
                icon: Icon(Icons.expand_less_rounded, color: _primaryBlue, size: isMobile ? 18 : 20),
                label: Text('Collapse', style: TextStyle(color: _primaryBlue, fontSize: isMobile ? 12 : 14)),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),

          // Image gallery
          if (apartmentImages.isNotEmpty) ...[
            SizedBox(
              height: isMobile ? 100 : 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: apartmentImages.length > 5 ? 5 : apartmentImages.length,
                separatorBuilder: (_, __) => SizedBox(width: isMobile ? 6 : 8),
                itemBuilder: (context, index) {
                  return Container(
                    width: isMobile ? 140 : 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _primaryBlue.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        apartmentImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _lightBlue,
                          child: Icon(Icons.image_not_supported, color: _primaryBlue),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
          ],

          // Basic info
          Row(
            children: [
              _infoChip(Icons.bed_rounded, '$bedrooms Bedrooms', isMobile),
              SizedBox(width: isMobile ? 6 : 8),
              _infoChip(Icons.bathtub_rounded, '$bathrooms Bathrooms', isMobile),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),

          // Description
          if (description.isNotEmpty) ...[
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                    fontSize: isMobile ? 13 : null,
                  ),
            ),
            SizedBox(height: isMobile ? 4 : 6),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    fontSize: isMobile ? 12 : null,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 8 : 12),
          ],

          // Amenities
          if (amenities.isNotEmpty) ...[
            Text(
              'Amenities',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                    fontSize: isMobile ? 13 : null,
                  ),
            ),
            SizedBox(height: isMobile ? 4 : 6),
            Wrap(
              spacing: isMobile ? 4 : 6,
              runSpacing: isMobile ? 3 : 4,
              children: amenities.take(6).map((amenity) => _amenityChip(amenity, isMobile)).toList(),
            ),
            if (amenities.length > 6)
              Padding(
                padding: EdgeInsets.only(top: isMobile ? 3 : 4),
                child: Text(
                  '+${amenities.length - 6} more amenities',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _primaryBlue,
                        fontStyle: FontStyle.italic,
                        fontSize: isMobile ? 11 : null,
                      ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 5 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryBlue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 14 : 16, color: _primaryBlue),
          SizedBox(width: isMobile ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              color: _primaryBlue,
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amenityChip(String amenity, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: isMobile ? 3 : 4),
      decoration: BoxDecoration(
        color: _primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primaryBlue.withOpacity(0.3)),
      ),
      child: Text(
        amenity,
        style: TextStyle(
          color: _primaryBlue,
          fontSize: isMobile ? 10 : 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _dateInfo(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool alignEnd = false,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alignEnd) ...[
              Icon(icon, size: isMobile ? 14 : 16, color: _primaryBlue),
              SizedBox(width: isMobile ? 2 : 3),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _primaryBlue,
                    fontSize: isMobile ? 10 : null,
                  ),
            ),
            if (alignEnd) ...[
              SizedBox(width: isMobile ? 2 : 3),
              Icon(icon, size: isMobile ? 14 : 16, color: _primaryBlue),
            ],
          ],
        ),
        SizedBox(height: isMobile ? 3 : 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: _primaryBlue,
                fontSize: isMobile ? 12 : null,
              ),
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        ),
      ],
    );
  }

  Widget _buildPaymentStatus(BuildContext context, String paymentStatus, Timestamp? createdAt, bool isMobile) {
    if (paymentStatus.toLowerCase() == 'completed') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 3 : 4),
        decoration: BoxDecoration(
          color: Colors.green.shade700.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade700, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: isMobile ? 14 : 16, color: Colors.green.shade700),
            SizedBox(width: isMobile ? 3 : 4),
            Text(
              'PAID',
              style: TextStyle(
                color: Colors.green,
                fontSize: isMobile ? 10 : 12,
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
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 3 : 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade600.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade600, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: isMobile ? 14 : 16, color: Colors.orange.shade600),
                SizedBox(width: isMobile ? 3 : 4),
                Text(
                  'PENDING',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: isMobile ? 10 : 12,
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
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 3 : 4),
            decoration: BoxDecoration(
              color: Colors.red.shade700.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade700, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel_rounded, size: isMobile ? 14 : 16, color: Colors.red.shade700),
                SizedBox(width: isMobile ? 3 : 4),
                Text(
                  'EXPIRED',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: isMobile ? 10 : 12,
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
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 3 : 4),
          decoration: BoxDecoration(
            color: _primaryBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _primaryBlue, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, size: isMobile ? 14 : 16, color: _primaryBlue),
              SizedBox(width: isMobile ? 3 : 4),
              Text(
                '$hh:$mm:$ss',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
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
        return _primaryBlue;
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