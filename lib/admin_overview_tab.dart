import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class OverviewTab extends StatelessWidget {
  final Stream<QuerySnapshot> apartmentsStream;
  final Stream<QuerySnapshot> hostsStream;
  final Stream<QuerySnapshot> guestsStream;
  final Stream<QuerySnapshot> reservationsStream;
  final ValueChanged<int> onTabChange;

  const OverviewTab({
    super.key,
    required this.apartmentsStream,
    required this.hostsStream,
    required this.guestsStream,
    required this.reservationsStream,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: apartmentsStream,
      builder: (context, apartmentSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: reservationsStream,
          builder: (context, reservationSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: hostsStream,
              builder: (context, hostSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: guestsStream,
                  builder: (context, guestSnapshot) {
                    // Calculate stats
                    final apartmentsCount = apartmentSnapshot.hasData 
                        ? apartmentSnapshot.data!.docs.length 
                        : 0;
                    
                    final reservationsCount = reservationSnapshot.hasData 
                        ? reservationSnapshot.data!.docs.length 
                        : 0;
                    
                    final hostsCount = hostSnapshot.hasData 
                        ? hostSnapshot.data!.docs.length 
                        : 0;
                    
                    final guestsCount = guestSnapshot.hasData 
                        ? guestSnapshot.data!.docs.length 
                        : 0;
                    
                    double totalRevenue = 0;
                    if (reservationSnapshot.hasData) {
                      for (var doc in reservationSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['paymentStatus'] == 'completed' || data['paymentStatus'] == 'paid') {
                          totalRevenue += (data['total'] ?? 0).toDouble();
                        }
                      }
                    }
                    
                    int completedPayments = 0;
                    if (reservationSnapshot.hasData) {
                      for (var doc in reservationSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['paymentStatus'] == 'completed' || data['paymentStatus'] == 'paid') {
                          completedPayments++;
                        }
                      }
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 768;
                        
                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade100.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isMobile 
                                  ? _buildMobileLayout(
                                      apartmentsCount,
                                      reservationsCount,
                                      hostsCount,
                                      guestsCount,
                                      totalRevenue,
                                      completedPayments,
                                    )
                                  : _buildDesktopLayout(
                                      apartmentsCount,
                                      reservationsCount,
                                      hostsCount,
                                      guestsCount,
                                      totalRevenue,
                                      completedPayments,
                                    ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(
    int apartments,
    int reservations,
    int hosts,
    int guests,
    double revenue,
    int payments,
  ) {
    return Column(
      children: [
        // First Row
        Row(
          children: [
            _buildStat(
              icon: Icons.home_work,
              label: "Apartments",
              value: apartments.toString(),
            ),
            _verticalDivider(),
            _buildStat(
              icon: Icons.calendar_today,
              label: "Reservations",
              value: reservations.toString(),
            ),
            _verticalDivider(),
            _buildStat(
              icon: Icons.verified_user,
              label: "Hosts",
              value: hosts.toString(),
            ),
          ],
        ),
        _horizontalDivider(),
        // Second Row
        Row(
          children: [
            _buildStat(
              icon: Icons.people,
              label: "Guests",
              value: guests.toString(),
            ),
            _verticalDivider(),
            _buildStat(
              icon: Icons.account_balance_wallet,
              label: "Total Revenue",
              value: '₦${_formatCurrency(revenue)}',
            ),
            _verticalDivider(),
            _buildStat(
              icon: Icons.payments,
              label: "Payments",
              value: payments.toString(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(
    int apartments,
    int reservations,
    int hosts,
    int guests,
    double revenue,
    int payments,
  ) {
    return Column(
      children: [
        // First Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStat(
              icon: Icons.home_work,
              label: "Apartments",
              value: apartments.toString(),
            ),
            _verticalDivider(),
            _buildStat(
              icon: Icons.calendar_today,
              label: "Reservations",
              value: reservations.toString(),
            ),
            _verticalDivider(),
            _buildStat(
              icon: Icons.verified_user,
              label: "Hosts",
              value: hosts.toString(),
            ),
          ],
        ),
        _horizontalDivider(),
        // Second Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStat(
              icon: Icons.people,
              label: "Guests",
              value: guests.toString(),
            ),
            _verticalDivider(),
            _buildStat(
              icon: Icons.account_balance_wallet,
              label: "Total Revenue",
              value: '₦${_formatCurrency(revenue)}',
            ),
            _verticalDivider(),
            _buildStat(
              icon: Icons.payments,
              label: "Payments",
              value: payments.toString(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _verticalDivider() => Container(
        width: 1,
        height: 50,
        color: Colors.blue.shade100,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );

  Widget _horizontalDivider() => Container(
        height: 1,
        color: Colors.blue.shade100,
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      );

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
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