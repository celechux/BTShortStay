import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OverviewTab extends StatelessWidget {
  final String hostUID;
  final Widget? recentActivitiesWidget;

  // New: callbacks for navigation (passed from parent)
  final VoidCallback? onApartmentsTap;
  final VoidCallback? onReservationsTap;
  final VoidCallback? onRevenueTap;
  final VoidCallback? onAddApartmentTap;

  const OverviewTab({
    super.key,
    required this.hostUID,
    this.recentActivitiesWidget,
    this.onApartmentsTap,
    this.onReservationsTap,
    this.onRevenueTap,
    this.onAddApartmentTap,
  });

  @override
  Widget build(BuildContext context) {
    final apartmentsStream = FirebaseFirestore.instance
        .collection('apartments')
        .where('hostUID', isEqualTo: hostUID)
        .snapshots();
    final reservationsStream = FirebaseFirestore.instance
        .collection('reservations')
        .where('hostUID', isEqualTo: hostUID)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: apartmentsStream,
      builder: (context, apartmentSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: reservationsStream,
          builder: (context, reservationSnapshot) {
            double totalRevenue = 0;
            if (reservationSnapshot.hasData) {
              for (var doc in reservationSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if ((data['status'] ?? '') == 'confirmed') {
                  totalRevenue += (data['totalAmount'] ?? 0).toDouble();
                }
              }
            }

            final apartmentsCount = apartmentSnapshot.hasData ? apartmentSnapshot.data!.docs.length : 0;
            final reservationsCount = reservationSnapshot.hasData ? reservationSnapshot.data!.docs.length : 0;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;

                if (isMobile) {
                  // Mobile View: Horizontal stats card, add apartment, activities
                  return _buildMobileView(
                    context,
                    apartmentsCount,
                    reservationsCount,
                    totalRevenue,
                  );
                } else {
                  // Desktop View: Stats card and add apartment action only
                  return _buildDesktopView(
                    context,
                    apartmentsCount,
                    reservationsCount,
                    totalRevenue,
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMobileView(
    BuildContext context,
    int apartmentsCount,
    int reservationsCount,
    double totalRevenue,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards Container - Matching Payments Tab Style
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat(
                  icon: Icons.home_work,
                  label: "My Apartments",
                  value: apartmentsCount.toString(),
                  onTap: onApartmentsTap,
                ),
                _verticalDivider(),
                _buildStat(
                  icon: Icons.calendar_today,
                  label: "Reservations",
                  value: reservationsCount.toString(),
                  onTap: onReservationsTap,
                ),
                _verticalDivider(),
                _buildStat(
                  icon: Icons.account_balance_wallet,
                  label: "Total Revenue",
                  value: '₦${_formatCurrency(totalRevenue)}',
                  onTap: onRevenueTap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Add New Apartment Action Card - Slimmer and Longer
          SlimAddApartmentCard(
            onTap: onAddApartmentTap,
          ),

          // Recent Activities Section (injected from parent)
          if (recentActivitiesWidget != null) ...[
            const SizedBox(height: 16),
            recentActivitiesWidget!,
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopView(
    BuildContext context,
    int apartmentsCount,
    int reservationsCount,
    double totalRevenue,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards Container - Matching Payments Tab Style
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat(
                    icon: Icons.home_work,
                    label: "My Apartments",
                    value: apartmentsCount.toString(),
                    onTap: onApartmentsTap,
                  ),
                  _verticalDivider(),
                  _buildStat(
                    icon: Icons.calendar_today,
                    label: "Reservations",
                    value: reservationsCount.toString(),
                    onTap: onReservationsTap,
                  ),
                  _verticalDivider(),
                  _buildStat(
                    icon: Icons.account_balance_wallet,
                    label: "Total Revenue",
                    value: '₦${_formatCurrency(totalRevenue)}',
                    onTap: onRevenueTap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Add New Apartment Action Card - Slimmer and Longer
            SlimAddApartmentCard(
              onTap: onAddApartmentTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() => Container(
        width: 1,
        height: 50,
        color: Colors.blue.shade100,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF2196F3).withOpacity(0.15),
              radius: 22,
              child: Icon(
                icon,
                color: const Color(0xFF2196F3),
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return "${(amount / 1000000).toStringAsFixed(1)}M";
    } else if (amount >= 1000) {
      return "${(amount / 1000).toStringAsFixed(1)}K";
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}

/// Slim Add Apartment Action Card - Blue with White Text
class SlimAddApartmentCard extends StatelessWidget {
  final VoidCallback? onTap;

  const SlimAddApartmentCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade300.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_home,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add New Apartment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'List a new property',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}