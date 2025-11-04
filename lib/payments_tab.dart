import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class PaymentsTab extends StatelessWidget {
  final String hostUID;
  const PaymentsTab({super.key, required this.hostUID});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservations')
            .where('hostUID', isEqualTo: hostUID)
            .where('paymentStatus', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          double totalRevenue = 0;
          double totalDeductions = 0;
          Map<String, double> monthlyRevenue = {};

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final amount = (data['totalAmount'] ?? 0).toDouble();
              totalRevenue += amount;
              totalDeductions += amount * 0.1;

              // Calculate monthly revenue
              final createdAt = data['createdAt'] as Timestamp?;
              if (createdAt != null) {
                final date = createdAt.toDate();
                final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
                monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + amount;
              }
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reservations')
                .where('hostUID', isEqualTo: hostUID)
                .where('paymentStatus', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, pendingSnapshot) {
              int pendingPayments = 0;
              if (pendingSnapshot.hasData) {
                pendingPayments = pendingSnapshot.data!.docs.length;
              }

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Cards Container - Matching Overview Page Style
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
                              icon: Icons.account_balance_wallet,
                              label: 'Total Revenue',
                              value: '₦${_formatCurrency(totalRevenue)}',
                            ),
                            _verticalDivider(),
                            _buildStat(
                              icon: Icons.trending_down,
                              label: 'Total Deductions',
                              value: '₦${_formatCurrency(totalDeductions)}',
                            ),
                            _verticalDivider(),
                            _buildStat(
                              icon: Icons.schedule,
                              label: 'Pending Payments',
                              value: pendingPayments.toString(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Revenue Trend Chart
                      const Text(
                        'Revenue Trend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F9FF),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        height: 300,
                        child: _buildRevenueChart(monthlyRevenue),
                      ),
                      const SizedBox(height: 24),
                      
                      // View History Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showPaymentHistoryDialog(context, hostUID),
                          icon: const Icon(Icons.history),
                          label: const Text('View Full Payment History'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
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
              );
            },
          );
        },
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

  Widget _buildRevenueChart(Map<String, double> monthlyRevenue) {
    if (monthlyRevenue.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No revenue data yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sort months and get last 6 months
    final sortedMonths = monthlyRevenue.keys.toList()..sort();
    final last6Months = sortedMonths.length > 6 
        ? sortedMonths.sublist(sortedMonths.length - 6) 
        : sortedMonths;

    final spots = <FlSpot>[];
    for (int i = 0; i < last6Months.length; i++) {
      spots.add(FlSpot(i.toDouble(), monthlyRevenue[last6Months[i]]!));
    }

    final maxY = monthlyRevenue.values.isNotEmpty 
        ? monthlyRevenue.values.reduce((a, b) => a > b ? a : b) * 1.2 
        : 100.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 5 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300],
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= 0 && value.toInt() < last6Months.length) {
                  final monthKey = last6Months[value.toInt()];
                  final parts = monthKey.split('-');
                  final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  final monthName = monthNames[int.parse(parts[1]) - 1];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      monthName,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY > 0 ? maxY / 5 : 1,
              reservedSize: 45,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  '₦${_formatCurrency(value)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (last6Months.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF2196F3),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF2196F3),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF2196F3).withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color(0xFF2196F3),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                return LineTooltipItem(
                  '₦${barSpot.y.toStringAsFixed(0)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  void _showPaymentHistoryDialog(BuildContext context, String hostUID) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.history, color: Color(0xFF2196F3)),
            SizedBox(width: 8),
            Text('Payment History'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reservations')
                      .where('hostUID', isEqualTo: hostUID)
                      .where('paymentStatus', isEqualTo: 'completed')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No payment history yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final payment = snapshot.data!.docs[index];
                        final data = payment.data() as Map<String, dynamic>;
                        final createdAt = data['createdAt'] as Timestamp?;
                        final amount = (data['totalAmount'] ?? 0).toDouble();
                        final deduction = amount * 0.1;
                        final netAmount = amount - deduction;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child: const Icon(Icons.payment, color: Colors.white),
                            ),
                            title: Text(
                              data['apartmentTitle'] ?? 'Apartment Payment',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Gross: ₦${amount.toStringAsFixed(0)}'),
                                Text('Deduction: ₦${deduction.toStringAsFixed(0)}'),
                                Text(
                                  'Net: ₦${netAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    _formatDate(createdAt.toDate()),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PDF download feature will be implemented soon'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}