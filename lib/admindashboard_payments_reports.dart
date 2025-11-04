import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'admindashboard_helpers.dart';

/// ENHANCED PAYMENTS DASHBOARD WITH COMMISSION TRACKING
class PaymentsDashboard extends StatelessWidget {
  final List<QueryDocumentSnapshot> reservations;
  final VoidCallback onViewAll;

  const PaymentsDashboard({
    super.key,
    required this.reservations,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('commissions').snapshots(),
      builder: (context, commissionSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('payments').snapshots(),
          builder: (context, paymentSnapshot) {
            final metrics = _calculateMetrics(
              reservations, 
              commissionSnapshot.data?.docs ?? [], 
              paymentSnapshot.data?.docs ?? []
            );

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Revenue Cards
                  Row(
                    children: [
                      _statCard("Total Revenue", "₦${formatCurrency(metrics.totalRevenue)}", Icons.attach_money, kPrimaryBlue),
                      const SizedBox(width: 12),
                      _statCard("Platform Earnings", "₦${formatCurrency(metrics.totalCommissions)}", Icons.trending_up, Colors.orange),
                      const SizedBox(width: 12),
                      _statCard("Host Payouts", "₦${formatCurrency(metrics.totalHostPayouts)}", Icons.account_balance_wallet, Colors.green),
                      const SizedBox(width: 12),
                      _statCard("Pending Payouts", "₦${formatCurrency(metrics.pendingPayouts)}", Icons.hourglass_bottom, Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Payment Status Cards
                  Row(
                    children: [
                      _statCard("Completed", "${metrics.paidCount}", Icons.check_circle, Colors.green),
                      const SizedBox(width: 12),
                      _statCard("Pending", "${metrics.pendingCount}", Icons.hourglass_bottom, Colors.amber),
                      const SizedBox(width: 12),
                      _statCard("Failed", "${metrics.failedCount}", Icons.cancel, Colors.red),
                      const SizedBox(width: 12),
                      _statCard("Avg Commission", "${(metrics.avgCommissionRate * 100).toStringAsFixed(1)}%", Icons.percent, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Revenue vs Commission Chart
                  Text("Revenue & Commission Trends", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kPrimaryBlue)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: LineChart(_buildRevenueCommissionChart(metrics.monthlyData)),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Host Payout Summary
                  Text("Top Earning Hosts", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kPrimaryBlue)),
                  const SizedBox(height: 16),
                  _buildHostPayoutSummary(metrics.hostEarnings),
                  
                  const SizedBox(height: 32),
                  
                  // Recent Transactions
                  Row(
                    children: [
                      Text("Recent Transactions", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kPrimaryBlue)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onViewAll,
                        icon: const Icon(Icons.list, color: kPrimaryBlue),
                        label: const Text("View All", style: TextStyle(color: kPrimaryBlue)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...reservations.take(5).map((doc) => _buildTransactionCard(doc)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  DashboardMetrics _calculateMetrics(List<QueryDocumentSnapshot> reservations, 
                                   List<QueryDocumentSnapshot> commissions, 
                                   List<QueryDocumentSnapshot> payments) {
    double totalRevenue = 0;
    double totalCommissions = 0;
    double totalHostPayouts = 0;
    double pendingPayouts = 0;
    int paidCount = 0, pendingCount = 0, failedCount = 0;
    Map<String, MonthlyData> monthlyData = {};
    Map<String, HostEarnings> hostEarnings = {};

    for (var doc in reservations) {
      final data = doc.data() as Map<String, dynamic>;
      String? paymentStatus = data['paymentStatus'];
      
      if (paymentStatus == 'completed' || paymentStatus == 'paid') {
        paidCount++;
      } else if (paymentStatus == 'pending') {
        pendingCount++;
      } else if (paymentStatus == 'failed') {
        failedCount++;
      }
    }

    for (var doc in commissions) {
      final data = doc.data() as Map<String, dynamic>;
      double bookingAmount = toDouble(data['bookingAmount']);
      double commissionAmount = toDouble(data['commissionAmount']);
      double hostPayout = toDouble(data['hostPayout']);
      String status = data['status'] ?? '';
      String hostUid = data['hostUid'] ?? '';
      Timestamp? createdAt = data['calculatedAt'];
      DateTime date = createdAt?.toDate() ?? DateTime.now();
      String monthKey = "${date.year}-${date.month}";

      totalRevenue += bookingAmount;
      totalCommissions += commissionAmount;
      totalHostPayouts += hostPayout;

      if (status == 'calculated') {
        pendingPayouts += hostPayout;
      }

      if (monthlyData[monthKey] == null) {
        monthlyData[monthKey] = MonthlyData(monthKey, 0, 0, 0);
      }
      monthlyData[monthKey]!.revenue += bookingAmount;
      monthlyData[monthKey]!.commission += commissionAmount;
      monthlyData[monthKey]!.hostPayout += hostPayout;

      if (hostEarnings[hostUid] == null) {
        hostEarnings[hostUid] = HostEarnings(hostUid, 0, 0, 0);
      }
      hostEarnings[hostUid]!.totalEarnings += hostPayout;
      hostEarnings[hostUid]!.bookingCount++;
      if (status == 'calculated') {
        hostEarnings[hostUid]!.pendingPayout += hostPayout;
      }
    }

    double avgCommissionRate = totalRevenue > 0 ? totalCommissions / totalRevenue : 0.05;

    return DashboardMetrics(
      totalRevenue: totalRevenue,
      totalCommissions: totalCommissions,
      totalHostPayouts: totalHostPayouts,
      pendingPayouts: pendingPayouts,
      paidCount: paidCount,
      pendingCount: pendingCount,
      failedCount: failedCount,
      avgCommissionRate: avgCommissionRate,
      monthlyData: monthlyData,
      hostEarnings: hostEarnings,
    );
  }

  LineChartData _buildRevenueCommissionChart(Map<String, MonthlyData> monthlyData) {
    var months = monthlyData.keys.toList()..sort();
    
    return LineChartData(
      gridData: FlGridData(show: true, drawHorizontalLine: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              int idx = value.toInt();
              if (idx < 0 || idx >= months.length) return Container();
              var ym = months[idx].split('-');
              return Text("${ym[1]}/${ym[0]}", style: TextStyle(fontSize: 11));
            },
          ),
        ),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      minX: 0,
      maxX: months.isNotEmpty ? (months.length - 1).toDouble() : 0,
      lineBarsData: [
        LineChartBarData(
          spots: [for (int i = 0; i < months.length; i++) FlSpot(i.toDouble(), monthlyData[months[i]]?.revenue ?? 0)],
          isCurved: true, barWidth: 3, color: kPrimaryBlue, dotData: FlDotData(show: true),
        ),
        LineChartBarData(
          spots: [for (int i = 0; i < months.length; i++) FlSpot(i.toDouble(), monthlyData[months[i]]?.commission ?? 0)],
          isCurved: true, barWidth: 3, color: Colors.orange, dotData: FlDotData(show: true),
        ),
        LineChartBarData(
          spots: [for (int i = 0; i < months.length; i++) FlSpot(i.toDouble(), monthlyData[months[i]]?.hostPayout ?? 0)],
          isCurved: true, barWidth: 3, color: Colors.green, dotData: FlDotData(show: true),
        ),
      ],
    );
  }

  Widget _buildHostPayoutSummary(Map<String, HostEarnings> hostEarnings) {
    var topHosts = hostEarnings.values.toList()..sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));
    
    return Column(
      children: topHosts.take(5).map((host) {
        int index = topHosts.indexOf(host);
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('hosts').doc(host.hostId).get(),
          builder: (context, snapshot) {
            String hostName = 'Loading...';
            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              hostName = userData?['fullName'] ?? 'Unknown Host';
            } else if (snapshot.connectionState == ConnectionState.done) {
              hostName = 'Unknown Host';
            }

            return Card(
              color: Colors.white,
              elevation: 2,
              margin: EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: kPrimaryBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 12),
                    
                    // Host Name
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hostName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "${host.bookingCount} bookings",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Total Earnings
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Total",
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            "₦${formatCurrency(host.totalEarnings)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 8),
                    
                    // Pending Payout
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Pending",
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            "₦${formatCurrency(host.pendingPayout)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildTransactionCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      color: Colors.white, elevation: 2, margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(getPaymentIcon(data['paymentStatus']), color: getPaymentStatusColor(data['paymentStatus']), size: 32),
        title: Row(children: [
          Text("₦${formatCurrency(toDouble(data['total']))}"),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
            child: Text("Commission: ₦${formatCurrency(toDouble(data['total']) * 0.05)}", style: TextStyle(fontSize: 10, color: Colors.orange[800])),
          ),
        ]),
        subtitle: Text("${data['apartmentTitle'] ?? '-'} • ${data['guestName'] ?? '-'}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(data['paymentStatus'] ?? '-', style: TextStyle(color: getPaymentStatusColor(data['paymentStatus']), fontWeight: FontWeight.bold)),
            Text(data['createdAt'] is Timestamp ? formatDate((data['createdAt'] as Timestamp).toDate()) : '', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Card(
      color: Colors.white, elevation: 2, margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color, width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ]),
      ),
    ),
  );
}

/// NEW TABBED FINANCIAL REPORTS DASHBOARD
class FinancialReportsDashboard extends StatefulWidget {
  final Stream<QuerySnapshot> reservationsStream;

  const FinancialReportsDashboard({super.key, required this.reservationsStream});

  @override
  State<FinancialReportsDashboard> createState() => _FinancialReportsDashboardState();
}

class _FinancialReportsDashboardState extends State<FinancialReportsDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Tab Bar
        Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: kPrimaryBlue,
            indicator: BoxDecoration(
              color: kPrimaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 18),
                    SizedBox(width: 8),
                    Text("Performance Reports"),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 18),
                    SizedBox(width: 8),
                    Text("Host Payments"),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Performance Reports Tab
              PerformanceReportsTab(reservationsStream: widget.reservationsStream),
              
              // Host Payments Tab
              HostPaymentsTab(reservationsStream: widget.reservationsStream),
            ],
          ),
        ),
      ],
    );
  }
}

/// PERFORMANCE REPORTS TAB
class PerformanceReportsTab extends StatelessWidget {
  final Stream<QuerySnapshot> reservationsStream;

  const PerformanceReportsTab({super.key, required this.reservationsStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('commissions').snapshots(),
      builder: (context, commissionSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('payments').snapshots(),
          builder: (context, paymentSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: reservationsStream,
              builder: (context, reservationSnapshot) {
                if (!reservationSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final metrics = _calculateDetailedMetrics(
                  reservationSnapshot.data!.docs,
                  commissionSnapshot.data?.docs ?? [],
                  paymentSnapshot.data?.docs ?? [],
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Financial Overview Cards
                      Row(
                        children: [
                          _statCard("Total Revenue", "₦${formatCurrency(metrics.totalRevenue)}", Icons.money, kPrimaryBlue),
                          const SizedBox(width: 16),
                          _statCard("Platform Revenue", "₦${formatCurrency(metrics.totalCommissions)}", Icons.trending_up, Colors.orange),
                          const SizedBox(width: 16),
                          _statCard("Host Payouts", "₦${formatCurrency(metrics.totalHostPayouts)}", Icons.account_balance_wallet, Colors.green),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _statCard("Avg Booking", "₦${formatCurrency(metrics.avgBookingValue)}", Icons.receipt, Colors.purple),
                          const SizedBox(width: 16),
                          _statCard("Commission Rate", "${(metrics.avgCommissionRate * 100).toStringAsFixed(1)}%", Icons.percent, Colors.indigo),
                          const SizedBox(width: 16),
                          _statCard("Active Hosts", "${metrics.activeHosts}", Icons.people, Colors.teal),
                        ],
                      ),

                      const SizedBox(height: 32),
                      
                      // Financial Performance Chart
                      _buildSectionHeader("Financial Performance", Icons.bar_chart),
                      const SizedBox(height: 16),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
                        ),
                        padding: EdgeInsets.all(16),
                        child: BarChart(_buildComprehensiveChart(metrics.monthlyData)),
                      ),

                      const SizedBox(height: 32),

                      // Export Actions
                      _buildActionButtons(context, metrics),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kPrimaryBlue, size: 24),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kPrimaryBlue)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, DetailedMetrics metrics) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _exportFinancialData(context, metrics),
            icon: const Icon(Icons.table_chart, color: Colors.white),
            label: const Text("Export CSV", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryBlue,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _generatePayoutReport(context, metrics),
            icon: const Icon(Icons.assessment, color: Colors.white),
            label: const Text("Generate Report", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  DetailedMetrics _calculateDetailedMetrics(
    List<QueryDocumentSnapshot> reservations,
    List<QueryDocumentSnapshot> commissions,
    List<QueryDocumentSnapshot> payments,
  ) {
    double totalRevenue = 0;
    double totalCommissions = 0;
    double totalHostPayouts = 0;
    double pendingPayouts = 0;
    int paidCount = 0, pendingCount = 0, failedCount = 0;
    Map<String, MonthlyData> monthlyData = {};
    Map<String, HostEarnings> hostEarnings = {};
    Set<String> activeHosts = {};

    for (var doc in reservations) {
      final data = doc.data() as Map<String, dynamic>;
      String? paymentStatus = data['paymentStatus'];
      
      if (paymentStatus == 'completed' || paymentStatus == 'paid') {
        paidCount++;
      } else if (paymentStatus == 'pending') {
        pendingCount++;
      } else if (paymentStatus == 'failed') {
        failedCount++;
      }
    }

    for (var doc in commissions) {
      final data = doc.data() as Map<String, dynamic>;
      double bookingAmount = toDouble(data['bookingAmount']);
      double commissionAmount = toDouble(data['commissionAmount']);
      double hostPayout = toDouble(data['hostPayout']);
      String status = data['status'] ?? '';
      String hostUid = data['hostUid'] ?? '';
      Timestamp? createdAt = data['calculatedAt'];
      DateTime date = createdAt?.toDate() ?? DateTime.now();
      String monthKey = "${date.year}-${date.month}";
      
      totalRevenue += bookingAmount;
      totalCommissions += commissionAmount;
      totalHostPayouts += hostPayout;
      activeHosts.add(hostUid);

      if (status == 'calculated') {
        pendingPayouts += hostPayout;
      }

      if (monthlyData[monthKey] == null) {
        monthlyData[monthKey] = MonthlyData(monthKey, 0, 0, 0);
      }
      monthlyData[monthKey]!.revenue += bookingAmount;
      monthlyData[monthKey]!.commission += commissionAmount;
      monthlyData[monthKey]!.hostPayout += hostPayout;

      if (hostEarnings[hostUid] == null) {
        hostEarnings[hostUid] = HostEarnings(hostUid, 0, 0, 0);
      }
      hostEarnings[hostUid]!.totalEarnings += hostPayout;
      hostEarnings[hostUid]!.bookingCount++;
      if (status == 'calculated') {
        hostEarnings[hostUid]!.pendingPayout += hostPayout;
      }
    }

    double avgBookingValue = activeHosts.isNotEmpty ? totalRevenue / activeHosts.length : 0;
    double avgCommissionRate = totalRevenue > 0 ? totalCommissions / totalRevenue : 0.05;

    return DetailedMetrics(
      totalRevenue: totalRevenue,
      totalCommissions: totalCommissions,
      totalHostPayouts: totalHostPayouts,
      pendingPayouts: pendingPayouts,
      paidCount: paidCount,
      pendingCount: pendingCount,
      failedCount: failedCount,
      avgCommissionRate: avgCommissionRate,
      monthlyData: monthlyData,
      hostEarnings: hostEarnings,
      avgBookingValue: avgBookingValue,
      activeHosts: activeHosts.length,
    );
  }

  BarChartData _buildComprehensiveChart(Map<String, MonthlyData> monthlyData) {
    var months = monthlyData.keys.toList()..sort();
    
    return BarChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              int idx = value.toInt();
              if (idx < 0 || idx >= months.length) return Container();
              var ym = months[idx].split('-');
              return Text("${ym[1]}/${ym[0]}", style: TextStyle(fontSize: 11));
            },
          ),
        ),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      barGroups: [
        for (int i = 0; i < months.length; i++)
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: monthlyData[months[i]]?.revenue ?? 0, color: kPrimaryBlue, width: 15),
              BarChartRodData(toY: monthlyData[months[i]]?.commission ?? 0, color: Colors.orange, width: 15),
              BarChartRodData(toY: monthlyData[months[i]]?.hostPayout ?? 0, color: Colors.green, width: 15),
            ],
          ),
      ],
    );
  }

  void _exportFinancialData(BuildContext context, DetailedMetrics metrics) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting financial data with commission details...')),
    );
  }

  void _generatePayoutReport(BuildContext context, DetailedMetrics metrics) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generating host payout report...')),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Card(
      color: Colors.white, elevation: 2, margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color, width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ]),
      ),
    ),
  );
}

/// HOST PAYMENTS TAB WITH FILTERS
class HostPaymentsTab extends StatefulWidget {
  final Stream<QuerySnapshot> reservationsStream;

  const HostPaymentsTab({super.key, required this.reservationsStream});

  @override
  State<HostPaymentsTab> createState() => _HostPaymentsTabState();
}

class _HostPaymentsTabState extends State<HostPaymentsTab> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('commissions').snapshots(),
      builder: (context, commissionSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: widget.reservationsStream,
          builder: (context, reservationSnapshot) {
            if (!reservationSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final metrics = _calculateDetailedMetrics(
              reservationSnapshot.data!.docs,
              commissionSnapshot.data?.docs ?? [],
              [],
            );

            var filteredHosts = _filterHosts(metrics.hostEarnings);

            return Column(
              children: [
                // Filter and Search Controls
                _buildFilterControls(metrics),
                
                // Summary Cards
                _buildSummaryCards(metrics),
                
                // Host Payments Table
                Expanded(
                  child: _buildHostPaymentsTable(filteredHosts),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterControls(DetailedMetrics metrics) {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          // Filter Chips
          Row(
            children: [
              Text("Filter: ", style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue)),
              SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: ['All', 'Pending', 'Completed', 'High Earners'].map((filter) {
                    return FilterChip(
                      label: Text(filter),
                      selected: _selectedFilter == filter,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = selected ? filter : 'All';
                        });
                      },
                      selectedColor: kPrimaryBlue.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _selectedFilter == filter ? kPrimaryBlue : Colors.grey[600],
                        fontWeight: _selectedFilter == filter ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by Host ID...',
              prefixIcon: Icon(Icons.search, color: kPrimaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: kPrimaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(DetailedMetrics metrics) {
    var pendingHosts = metrics.hostEarnings.values.where((h) => h.pendingPayout > 0).length;
    var totalPendingAmount = metrics.hostEarnings.values.fold(0.0, (sum, h) => sum + h.pendingPayout);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _summaryCard("Total Hosts", "${metrics.hostEarnings.length}", Icons.people, kPrimaryBlue),
          SizedBox(width: 16),
          _summaryCard("Pending Payouts", "$pendingHosts", Icons.hourglass_bottom, Colors.orange),
          SizedBox(width: 16),
          _summaryCard("Pending Amount", "₦${formatCurrency(totalPendingAmount)}", Icons.account_balance_wallet, Colors.red),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 8),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostPaymentsTable(List<HostEarnings> hosts) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.payment, color: kPrimaryBlue),
                SizedBox(width: 8),
                Text("Host Payment Management", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryBlue)),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _bulkProcessPayouts(hosts.where((h) => h.pendingPayout > 0).toList()),
                  icon: Icon(Icons.send_to_mobile, size: 16),
                  label: Text("Process All Pending"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          
          // Table Content
          Expanded(
            child: hosts.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text("No hosts found", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      Text("Try adjusting your filters", style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: hosts.length,
                  itemBuilder: (context, index) {
                    final host = hosts[index];
                    return _buildHostPaymentCard(host, index);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostPaymentCard(HostEarnings host, int index) {
    bool hasPendingPayout = host.pendingPayout > 0;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: hasPendingPayout ? Colors.orange.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Host Avatar and Rank
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: hasPendingPayout ? Colors.orange.withOpacity(0.2) : kPrimaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("#${index + 1}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                  Icon(Icons.person, size: 20, color: kPrimaryBlue),
                ],
              ),
            ),
            
            SizedBox(width: 16),
            
            // Host Details
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    host.hostId.length > 12 ? "${host.hostId.substring(0, 12)}..." : host.hostId,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text("${host.bookingCount} bookings", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            
            // Earnings
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Total Earnings", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text("₦${formatCurrency(host.totalEarnings)}", 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            
            // Pending Payout
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Pending", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text("₦${formatCurrency(host.pendingPayout)}", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: hasPendingPayout ? Colors.orange : Colors.grey[400]
                    )),
                ],
              ),
            ),
            
            // Action Buttons
            Column(
              children: [
                if (hasPendingPayout)
                  ElevatedButton(
                    onPressed: () => _initiateHostPayout(host.hostId, host.pendingPayout),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      minimumSize: Size(80, 30),
                    ),
                    child: Text("Pay Now", style: TextStyle(fontSize: 12)),
                  )
                else
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("Paid", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ),
                
                SizedBox(height: 8),
                
                TextButton(
                  onPressed: () => _showHostDetails(host),
                  style: TextButton.styleFrom(
                    foregroundColor: kPrimaryBlue,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size(80, 25),
                  ),
                  child: Text("Details", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<HostEarnings> _filterHosts(Map<String, HostEarnings> hostEarnings) {
    var hosts = hostEarnings.values.toList();
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      hosts = hosts.where((host) => host.hostId.toLowerCase().contains(_searchQuery)).toList();
    }
    
    // Apply status filter
    switch (_selectedFilter) {
      case 'Pending':
        hosts = hosts.where((host) => host.pendingPayout > 0).toList();
        break;
      case 'Completed':
        hosts = hosts.where((host) => host.pendingPayout == 0 && host.totalEarnings > 0).toList();
        break;
      case 'High Earners':
        hosts = hosts.where((host) => host.totalEarnings > 50000).toList();
        break;
      default:
        // All hosts
        break;
    }
    
    // Sort by pending payout (descending), then by total earnings
    hosts.sort((a, b) {
      if (a.pendingPayout != b.pendingPayout) {
        return b.pendingPayout.compareTo(a.pendingPayout);
      }
      return b.totalEarnings.compareTo(a.totalEarnings);
    });
    
    return hosts;
  }

  void _bulkProcessPayouts(List<HostEarnings> pendingHosts) {
    if (pendingHosts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pending payouts to process.')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Process All Payouts'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to process payouts for:'),
            SizedBox(height: 8),
            Text('• ${pendingHosts.length} hosts', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Total amount: ₦${formatCurrency(pendingHosts.fold(0.0, (sum, h) => sum + h.pendingPayout))}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            SizedBox(height: 16),
            Text('This action cannot be undone.', style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processBulkPayouts(pendingHosts);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Process All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _processBulkPayouts(List<HostEarnings> hosts) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 16),
            Text('Processing ${hosts.length} payouts...'),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );
    
    // Simulate processing
    Future.delayed(Duration(seconds: 3), () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Successfully processed ${hosts.length} payouts'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _initiateHostPayout(String hostId, double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Process Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Host: ${hostId.substring(0, 12)}...'),
            Text('Amount: ₦${formatCurrency(amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Processing payout for host...')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Process', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showHostDetails(HostEarnings host) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Host Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Host ID: ${host.hostId}'),
            SizedBox(height: 8),
            Text('Total Earnings: ₦${formatCurrency(host.totalEarnings)}'),
            Text('Pending Payout: ₦${formatCurrency(host.pendingPayout)}'),
            Text('Total Bookings: ${host.bookingCount}'),
            if (host.bookingCount > 0)
              Text('Avg per Booking: ₦${formatCurrency(host.totalEarnings / host.bookingCount)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  DetailedMetrics _calculateDetailedMetrics(
    List<QueryDocumentSnapshot> reservations,
    List<QueryDocumentSnapshot> commissions,
    List<QueryDocumentSnapshot> payments,
  ) {
    double totalRevenue = 0;
    double totalCommissions = 0;
    double totalHostPayouts = 0;
    double pendingPayouts = 0;
    int paidCount = 0, pendingCount = 0, failedCount = 0;
    Map<String, MonthlyData> monthlyData = {};
    Map<String, HostEarnings> hostEarnings = {};
    Set<String> activeHosts = {};

    for (var doc in reservations) {
      final data = doc.data() as Map<String, dynamic>;
      String? paymentStatus = data['paymentStatus'];
      
      if (paymentStatus == 'completed' || paymentStatus == 'paid') {
        paidCount++;
      } else if (paymentStatus == 'pending') {
        pendingCount++;
      } else if (paymentStatus == 'failed') {
        failedCount++;
      }
    }

    for (var doc in commissions) {
      final data = doc.data() as Map<String, dynamic>;
      double bookingAmount = toDouble(data['bookingAmount']);
      double commissionAmount = toDouble(data['commissionAmount']);
      double hostPayout = toDouble(data['hostPayout']);
      String status = data['status'] ?? '';
      String hostUid = data['hostUid'] ?? '';
      Timestamp? createdAt = data['calculatedAt'];
      DateTime date = createdAt?.toDate() ?? DateTime.now();
      String monthKey = "${date.year}-${date.month}";
      
      totalRevenue += bookingAmount;
      totalCommissions += commissionAmount;
      totalHostPayouts += hostPayout;
      activeHosts.add(hostUid);

      if (status == 'calculated') {
        pendingPayouts += hostPayout;
      }

      if (monthlyData[monthKey] == null) {
        monthlyData[monthKey] = MonthlyData(monthKey, 0, 0, 0);
      }
      monthlyData[monthKey]!.revenue += bookingAmount;
      monthlyData[monthKey]!.commission += commissionAmount;
      monthlyData[monthKey]!.hostPayout += hostPayout;

      if (hostEarnings[hostUid] == null) {
        hostEarnings[hostUid] = HostEarnings(hostUid, 0, 0, 0);
      }
      hostEarnings[hostUid]!.totalEarnings += hostPayout;
      hostEarnings[hostUid]!.bookingCount++;
      if (status == 'calculated') {
        hostEarnings[hostUid]!.pendingPayout += hostPayout;
      }
    }

    double avgBookingValue = activeHosts.isNotEmpty ? totalRevenue / activeHosts.length : 0;
    double avgCommissionRate = totalRevenue > 0 ? totalCommissions / totalRevenue : 0.05;

    return DetailedMetrics(
      totalRevenue: totalRevenue,
      totalCommissions: totalCommissions,
      totalHostPayouts: totalHostPayouts,
      pendingPayouts: pendingPayouts,
      paidCount: paidCount,
      pendingCount: pendingCount,
      failedCount: failedCount,
      avgCommissionRate: avgCommissionRate,
      monthlyData: monthlyData,
      hostEarnings: hostEarnings,
      avgBookingValue: avgBookingValue,
      activeHosts: activeHosts.length,
    );
  }
}

// Data Models
class DashboardMetrics {
  final double totalRevenue;
  final double totalCommissions;
  final double totalHostPayouts;
  final double pendingPayouts;
  final int paidCount;
  final int pendingCount;
  final int failedCount;
  final double avgCommissionRate;
  final Map<String, MonthlyData> monthlyData;
  final Map<String, HostEarnings> hostEarnings;

  DashboardMetrics({
    required this.totalRevenue,
    required this.totalCommissions,
    required this.totalHostPayouts,
    required this.pendingPayouts,
    required this.paidCount,
    required this.pendingCount,
    required this.failedCount,
    required this.avgCommissionRate,
    required this.monthlyData,
    required this.hostEarnings,
  });
}

class DetailedMetrics extends DashboardMetrics {
  final double avgBookingValue;
  final int activeHosts;

  DetailedMetrics({
    required super.totalRevenue,
    required super.totalCommissions,
    required super.totalHostPayouts,
    required super.pendingPayouts,
    required super.paidCount,
    required super.pendingCount,
    required super.failedCount,
    required super.avgCommissionRate,
    required super.monthlyData,
    required super.hostEarnings,
    required this.avgBookingValue,
    required this.activeHosts,
  });
}

class MonthlyData {
  final String month;
  double revenue;
  double commission;
  double hostPayout;

  MonthlyData(this.month, this.revenue, this.commission, this.hostPayout);
}

class HostEarnings {
  final String hostId;
  double totalEarnings;
  double pendingPayout;
  int bookingCount;

  HostEarnings(this.hostId, this.totalEarnings, this.pendingPayout, this.bookingCount);
}