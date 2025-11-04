import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'admindashboard_helpers.dart';

// Data Models
enum PaymentFilter { pending, completed }

class HostPaymentData {
  final String hostId;
  final String hostName;
  final String hostEmail;
  final BankAccountData? bankAccount;
  double totalEarnings;
  double pendingPayout;
  int successfulBookings;
  List<ApartmentPayment> apartments;

  HostPaymentData({
    required this.hostId,
    required this.hostName,
    required this.hostEmail,
    this.bankAccount,
    required this.totalEarnings,
    required this.pendingPayout,
    required this.successfulBookings,
    required this.apartments,
  });
}

class BankAccountData {
  final String bankName;
  final String accountNumber;
  final String accountName;

  BankAccountData({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });
}

class ApartmentPayment {
  final String apartmentId;
  final String apartmentTitle;
  final double amountPaid;
  final double commission;
  final String paymentStatus;
  final DateTime createdAt;
  final String guestName;
  final String reservationId;
  final String commissionId;

  ApartmentPayment({
    required this.apartmentId,
    required this.apartmentTitle,
    required this.amountPaid,
    required this.commission,
    required this.paymentStatus,
    required this.createdAt,
    required this.guestName,
    required this.reservationId,
    required this.commissionId,
  });
}

class HostPaymentsTab extends StatefulWidget {
  final Stream<QuerySnapshot> reservationsStream;

  const HostPaymentsTab({super.key, required this.reservationsStream});

  @override
  State<HostPaymentsTab> createState() => _HostPaymentsTabState();
}

class _HostPaymentsTabState extends State<HostPaymentsTab> {
  String _searchQuery = '';
  PaymentFilter _currentFilter = PaymentFilter.pending;
  final TextEditingController _searchController = TextEditingController();

  double _totalPendingPayments = 0.0;
  double _totalCompletedPayments = 0.0;

  bool _isAdmin = false;
  bool _checkingAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
  }

  Future<void> _checkIfAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isAdmin = false;
          _checkingAdmin = false;
        });
        return;
      }
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims ?? {};
      if (claims['admin'] == true) {
        setState(() {
          _isAdmin = true;
          _checkingAdmin = false;
        });
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = doc.exists ? (doc.data()?['role'] ?? '') : '';
      setState(() {
        _isAdmin = (role == 'admin');
        _checkingAdmin = false;
      });
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _checkingAdmin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('commissions').snapshots(),
      builder: (context, commissionSnapshot) {
        if (!commissionSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final commissions = commissionSnapshot.data!.docs;

        return FutureBuilder<List<HostPaymentData>>(
          future: _buildHostPaymentsWithDetails(commissions),
          builder: (context, hostDataSnapshot) {
            if (!hostDataSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final allHosts = hostDataSnapshot.data!;
            final filteredHosts = _filterHosts(allHosts);

            _calculateTotals(allHosts);

            return Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.red[600],
                          shadowColor: Colors.red[200],
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Icon(Icons.pending_actions, color: Colors.white, size: 30),
                                const SizedBox(height: 8),
                                const Text('Total Pending', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text('₦${formatCurrency(_totalPendingPayments)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          color: Colors.green[600],
                          shadowColor: Colors.green[200],
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: 30),
                                const SizedBox(height: 8),
                                const Text('Total Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text('₦${formatCurrency(_totalCompletedPayments)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar (centered between cards and filters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPrimaryBlue, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryBlue.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search by Host Name or Email...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: kPrimaryBlue),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),

                // Filter Buttons
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentFilter == PaymentFilter.pending ? kPrimaryBlue : Colors.white,
                            foregroundColor: _currentFilter == PaymentFilter.pending ? Colors.white : kPrimaryBlue,
                            side: BorderSide(color: kPrimaryBlue, width: 1.4),
                          ),
                          onPressed: () => setState(() => _currentFilter = PaymentFilter.pending),
                          child: const Text('Pending Payments', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentFilter == PaymentFilter.completed ? kPrimaryBlue : Colors.white,
                            foregroundColor: _currentFilter == PaymentFilter.completed ? Colors.white : kPrimaryBlue,
                            side: BorderSide(color: kPrimaryBlue, width: 1.4),
                          ),
                          onPressed: () => setState(() => _currentFilter = PaymentFilter.completed),
                          child: const Text('Completed Payments', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: filteredHosts.isEmpty
                      ? const Center(child: Text("No hosts found"))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredHosts.length,
                          itemBuilder: (context, index) {
                            final host = filteredHosts[index];
                            return _buildHostCard(host, index);
                          },
                        ),
                ),

                // View Payout History Button at bottom
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryBlue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()));
                      },
                      icon: const Icon(Icons.history, size: 18, color: Colors.white),
                      label: const Text("View Payout History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _calculateTotals(List<HostPaymentData> allHosts) {
    _totalPendingPayments = 0.0;
    _totalCompletedPayments = 0.0;
    for (var host in allHosts) {
      _totalPendingPayments += host.pendingPayout;
      _totalCompletedPayments += host.totalEarnings;
    }
  }

  List<HostPaymentData> _filterHosts(List<HostPaymentData> allHosts) {
    List<HostPaymentData> filtered;
    if (_currentFilter == PaymentFilter.pending) {
      filtered = allHosts.where((host) => host.pendingPayout > 0).toList();
    } else {
      filtered = allHosts.where((host) => host.totalEarnings > 0).toList();
    }
    if (_searchQuery.isEmpty) return filtered;
    return filtered.where((host) {
      return host.hostName.toLowerCase().contains(_searchQuery) ||
          host.hostEmail.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<List<HostPaymentData>> _buildHostPaymentsWithDetails(List<QueryDocumentSnapshot> commissions) async {
    final Map<String, HostPaymentData> hosts = {};
    final Set<String> hostIds = {};

    for (var doc in commissions) {
      final data = doc.data() as Map<String, dynamic>;
      final hostId = data['hostUid'] ?? '';
      if (hostId.isNotEmpty) {
        hostIds.add(hostId);
      }
    }

    final hostDetailsMap = await _fetchHostDetails(hostIds.toList());
    final bankAccountsMap = await _fetchBankAccounts(hostIds.toList());

    for (var doc in commissions) {
      final data = doc.data() as Map<String, dynamic>;
      final hostId = data['hostUid'] ?? '';
      final apartmentId = data['apartmentId'] ?? '';
      final apartmentTitle = data['apartmentTitle'] ?? '';
      final guestName = data['guestName'] ?? '-';
      final reservationId = data['reservationId'] ?? '';
      final commissionId = doc.id;
      final bookingAmount = toDouble(data['bookingAmount']);
      final commissionAmount = toDouble(data['commissionAmount']);
      final hostPayout = toDouble(data['hostPayout']);
      final createdAt = data['calculatedAt'] is Timestamp
          ? (data['calculatedAt'] as Timestamp).toDate()
          : DateTime.now();
      final status = (data['status'] ?? '').toString().toLowerCase();

      if (hostId == '') continue;

      if (!hosts.containsKey(hostId)) {
        final hostDetails = hostDetailsMap[hostId];
        hosts[hostId] = HostPaymentData(
          hostId: hostId,
          hostName: hostDetails?['name'] ?? 'Unknown Host',
          hostEmail: hostDetails?['email'] ?? 'No email',
          bankAccount: bankAccountsMap[hostId],
          totalEarnings: 0,
          pendingPayout: 0,
          successfulBookings: 0,
          apartments: [],
        );
      }

      hosts[hostId]!.apartments.add(
        ApartmentPayment(
          apartmentId: apartmentId,
          apartmentTitle: apartmentTitle,
          amountPaid: bookingAmount,
          commission: commissionAmount,
          paymentStatus: status,
          createdAt: createdAt,
          guestName: guestName,
          reservationId: reservationId,
          commissionId: commissionId,
        ),
      );

      if (status == 'paid') {
        hosts[hostId]!.totalEarnings += hostPayout;
        hosts[hostId]!.successfulBookings += 1;
      }
      if (status == 'calculated') {
        hosts[hostId]!.pendingPayout += hostPayout;
      }
    }

    final result = hosts.values.toList();
    if (_currentFilter == PaymentFilter.pending) {
      result.sort((a, b) => b.pendingPayout.compareTo(a.pendingPayout));
    } else {
      result.sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));
    }
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchHostDetails(List<String> hostIds) async {
    if (hostIds.isEmpty) return {};
    final Map<String, Map<String, dynamic>> hostDetails = {};
    for (int i = 0; i < hostIds.length; i += 10) {
      final batch = hostIds.skip(i).take(10).toList();
      final snapshot = await FirebaseFirestore.instance
          .collection('hosts')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        hostDetails[doc.id] = {
          'name': data['fullName'] ?? data['displayName'] ?? 'Unknown Host',
          'email': data['email'] ?? 'No email',
        };
      }
    }
    return hostDetails;
  }

  Future<Map<String, BankAccountData?>> _fetchBankAccounts(List<String> hostIds) async {
    if (hostIds.isEmpty) return {};
    final Map<String, BankAccountData?> bankAccounts = {};
    final possibleCollections = ['HostAccounts', 'hostAccounts', 'bankAccounts', 'accounts'];
    final possibleHostIdFields = ['hostUID', 'hostId', 'userId', 'ownerId'];
    for (String collectionName in possibleCollections) {
      try {
        for (String hostIdField in possibleHostIdFields) {
          for (int i = 0; i < hostIds.length; i += 10) {
            final batch = hostIds.skip(i).take(10).toList();
            final snapshot = await FirebaseFirestore.instance
                .collection(collectionName)
                .where(hostIdField, whereIn: batch)
                .get();
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final hostUID = data[hostIdField];
              if (hostUID != null) {
                bankAccounts[hostUID] = BankAccountData(
                  bankName: data['bankName'] ?? data['bank'] ?? '',
                  accountNumber: data['accountNumber'] ?? data['accountNo'] ?? '',
                  accountName: data['accountName'] ?? data['accountHolderName'] ?? '',
                );
              }
            }
          }
          if (bankAccounts.isNotEmpty) return bankAccounts;
        }
      } catch (e) {
        continue;
      }
    }
    return bankAccounts;
  }

  Widget _buildHostCard(HostPaymentData host, int index) {
    final displayAmount = _currentFilter == PaymentFilter.pending ? host.pendingPayout : host.totalEarnings;
    final displayColor = _currentFilter == PaymentFilter.pending ? Colors.orange.shade700 : Colors.green.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            CircleAvatar(backgroundColor: kPrimaryBlue, child: Text("${index + 1}", style: const TextStyle(color: Colors.white))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(host.hostName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(host.hostEmail, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: displayColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                Text("₦${formatCurrency(displayAmount)}", style: TextStyle(color: displayColor, fontWeight: FontWeight.bold)),
                Text("${_currentFilter == PaymentFilter.pending ? host.apartments.where((a) => a.paymentStatus == 'calculated').length : host.successfulBookings} bookings",
                    style: TextStyle(color: displayColor.withOpacity(0.8), fontSize: 11)),
              ]),
            ),
          ],
        ),
        children: [
          if (host.bankAccount != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Bank: ${host.bankAccount!.bankName}", style: const TextStyle(fontWeight: FontWeight.w600)),
                Text("Acc: ${host.bankAccount!.accountNumber}"),
                Text(host.bankAccount!.accountName),
              ]),
            ),
          if (_currentFilter == PaymentFilter.pending) ...[
            ...host.apartments.where((a) => a.paymentStatus == 'calculated' || a.paymentStatus == 'failed').map((apartment) => _buildApartmentPaymentRow(apartment)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.payments),
                label: const Text("Process All Pending"),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue),
                onPressed: _checkingAdmin
                    ? null
                    : !_isAdmin
                        ? null
                        : () async {
                            final pendingCommissions = host.apartments.where((a) => a.paymentStatus == 'calculated').map((a) => a.commissionId).toList();
                            if (pendingCommissions.isEmpty) return;
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Process All Pending Payouts?'),
                                content: Text('Pay ₦${formatCurrency(host.pendingPayout)} to ${host.hostName} (${pendingCommissions.length} bookings)?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            await _processPaymentsForHostParallel(host, pendingCommissions);
                          },
              ),
            ]),
          ] else ...[
            ...host.apartments.where((a) => a.paymentStatus == 'paid').map((apartment) => _buildApartmentPaymentRow(apartment)),
          ],
        ],
      ),
    );
  }

  Widget _buildApartmentPaymentRow(ApartmentPayment apartment) {
    final status = apartment.paymentStatus;
    Color chipColor;
    String chipText;
    if (status == 'paid') {
      chipColor = Colors.green.shade100;
      chipText = 'Paid';
    } else if (status == 'failed') {
      chipColor = Colors.red.shade100;
      chipText = 'Failed';
    } else {
      chipColor = Colors.orange.shade100;
      chipText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black.withOpacity(0.04))),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(apartment.apartmentTitle.isNotEmpty ? apartment.apartmentTitle : apartment.apartmentId, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Guest: ${apartment.guestName}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(formatDate(apartment.createdAt), style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text("₦${formatCurrency(apartment.amountPaid - apartment.commission)}", style: const TextStyle(fontWeight: FontWeight.w700)),
            Text("Fee: ₦${formatCurrency(apartment.commission)}", style: const TextStyle(fontSize: 11, color: Colors.black45)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(6)),
              child: Text(chipText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: chipText == 'Paid' ? Colors.green.shade800 : (chipText == 'Failed' ? Colors.red.shade800 : Colors.orange.shade800))),
            ),
            if (status == 'calculated')
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: ElevatedButton(
                  onPressed: _checkingAdmin
                      ? null
                      : !_isAdmin
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can process payouts'), backgroundColor: Colors.red));
                            }
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Confirm Payout'),
                                  content: Text('Pay this host ₦${formatCurrency(apartment.amountPaid - apartment.commission)} for booking ${apartment.reservationId}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              await _processSinglePayout(apartment.commissionId);
                            },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Pay Now', style: TextStyle(fontSize: 12)),
                ),
              ),
            if (status == 'failed')
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text("Retry", style: TextStyle(fontSize: 12)),
                  onPressed: _checkingAdmin
                      ? null
                      : !_isAdmin
                          ? null
                          : () => _retryPayout(apartment.commissionId),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Future<void> _processSinglePayout(String commissionId, {bool showSnack = true}) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

      final callable = FirebaseFunctions.instance.httpsCallable('transferPayoutToHost');
      final result = await callable.call({'commissionId': commissionId});
      Navigator.pop(context);

      final data = result.data;
      if (data != null && data['success'] == true) {
        if (showSnack) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ${data['hostName'] ?? 'Host'} paid ₦${data['amount']}"), backgroundColor: Colors.green));
        }
        
        try {
          final commissionDoc = await FirebaseFirestore.instance.collection('commissions').doc(commissionId).get();
          final commissionData = commissionDoc.data() ?? {};
          final hostUid = commissionData['hostUid'] ?? '';
          final hostDoc = await FirebaseFirestore.instance.collection('hosts').doc(hostUid).get();
          final hostEmail = hostDoc.exists ? (hostDoc.data()?['email'] ?? data['hostEmail']) : data['hostEmail'];

          if (hostEmail != null && hostEmail.toString().contains('@')) {
            await FirebaseFirestore.instance.collection('mail').add({
              'to': hostEmail,
              'subject': "Payment processed — ₦${data['amount']}",
              'text': """Hi ${hostDoc.exists ? (hostDoc.data()?['fullName'] ?? '') : ''},

We have processed your payout of ₦${data['amount']} for reservation ${commissionData['reservationId'] ?? ''}.
Transfer reference: ${data['transfer_code'] ?? data['transferCode'] ?? data['transferReference'] ?? ''}

If you don't see the money in your account shortly, please contact support.

Thanks,
Your Team""",
              'sent': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint('Failed to enqueue payout email: $e');
        }

        setState(() {});
      } else {
        final message = data != null ? (data['message'] ?? data.toString()) : 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Payout failed: $message"), backgroundColor: Colors.red));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Error processing payout: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _processPaymentsForHostParallel(HostPaymentData host, List<String> pendingCommissionIds) async {
    if (pendingCommissionIds.isEmpty) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) {
      return AlertDialog(
        title: const Text('Processing payouts'),
        content: Column(mainAxisSize: MainAxisSize.min, children: const [
          Text('Processing payouts — this may take a few seconds...'),
          SizedBox(height: 16),
          LinearProgressIndicator(),
        ]),
      );
    });

    try {
      final futures = pendingCommissionIds.map((id) => _processSinglePayout(id, showSnack: false)).toList();
      await Future.wait(futures);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("All pending payouts processed for ${host.hostName}"), backgroundColor: Colors.green));
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error processing some payouts: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() {});
    }
  }

  Future<void> _retryPayout(String commissionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Retry Payout'),
        content: const Text('Retry this failed payout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retry')),
        ],
      ),
    );
    if (confirmed == true) {
      await _processSinglePayout(commissionId);
    }
  }
}

/// Payout History Screen (separate route)
class PayoutHistoryScreen extends StatefulWidget {
  const PayoutHistoryScreen({super.key});

  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  final _commissionsQuery = FirebaseFirestore.instance
      .collection('commissions')
      .where('status', isEqualTo: 'paid')
      .orderBy('paidToHostAt', descending: true)
      .limit(200);

  Future<void> _exportToPDF(List<QueryDocumentSnapshot> docs) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdf = pw.Document();
      
      // Fetch host details for all payouts
      final hostIds = docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return (data['hostUid'] ?? '') as String;
      }).where((id) => id.isNotEmpty).toSet().toList();

      final hostDetails = await _fetchHostDetailsForPDF(hostIds);

      // Calculate totals
      double totalAmount = 0;
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = data['transferAmount'] ?? data['hostPayout'] ?? 0;
        totalAmount += amount.toDouble();
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.blue)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Payout History Report',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Generated on ${formatDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Total Payouts: ₦${formatCurrency(totalAmount)} | Count: ${docs.length}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.8),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _buildTableCell('Host Name', isHeader: true),
                      _buildTableCell('Apartment', isHeader: true),
                      _buildTableCell('Amount (₦)', isHeader: true),
                      _buildTableCell('Date', isHeader: true),
                      _buildTableCell('Reference', isHeader: true),
                    ],
                  ),
                  // Data rows
                  ...docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final hostUid = data['hostUid'] ?? '';
                    final hostName = hostDetails[hostUid] ?? 'Unknown Host';
                    final amount = data['transferAmount'] ?? data['hostPayout'] ?? 0;
                    final paidAt = (data['paidToHostAt'] is Timestamp) 
                        ? (data['paidToHostAt'] as Timestamp).toDate() 
                        : null;
                    final transferCode = data['transferCode'] ?? data['transfer_code'] ?? '-';
                    final apartmentTitle = data['apartmentTitle'] ?? data['reservationId'] ?? '-';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(hostName),
                        _buildTableCell(apartmentTitle),
                        _buildTableCell(formatCurrency(amount.toDouble())),
                        _buildTableCell(paidAt != null ? formatDate(paidAt) : '-'),
                        _buildTableCell(transferCode),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      Navigator.pop(context); // Remove loading dialog

      // Show PDF preview and allow printing/sharing
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'payout_history_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      Navigator.pop(context); // Ensure loading dialog is removed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blue900 : PdfColors.black,
        ),
      ),
    );
  }

  Future<Map<String, String>> _fetchHostDetailsForPDF(List<String> hostIds) async {
    if (hostIds.isEmpty) return {};
    final Map<String, String> hostDetails = {};
    
    for (int i = 0; i < hostIds.length; i += 10) {
      final batch = hostIds.skip(i).take(10).toList();
      final snapshot = await FirebaseFirestore.instance
          .collection('hosts')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        hostDetails[doc.id] = data['fullName'] ?? data['displayName'] ?? 'Unknown Host';
      }
    }
    return hostDetails;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout History', style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to PDF',
            onPressed: () async {
              final snapshot = await _commissionsQuery.get();
              if (snapshot.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No payout history to export')),
                );
                return;
              }
              await _exportToPDF(snapshot.docs);
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _commissionsQuery.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No payout history yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final hostUid = data['hostUid'] ?? '';
              final amount = data['transferAmount'] ?? data['hostPayout'] ?? 0;
              final paidAt = (data['paidToHostAt'] is Timestamp) 
                  ? (data['paidToHostAt'] as Timestamp).toDate() 
                  : null;
              final transferCode = data['transferCode'] ?? data['transfer_code'] ?? '';
              final reservationId = data['reservationId'] ?? '';
              final apartmentTitle = data['apartmentTitle'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.check_circle, color: Colors.green[700]),
                  ),
                  title: Text(
                    '₦${formatCurrency(amount.toDouble())} — ${apartmentTitle.isNotEmpty ? apartmentTitle : reservationId}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Host UID: $hostUid', style: const TextStyle(fontSize: 12)),
                      if (paidAt != null) Text('Paid: ${formatDate(paidAt)}', style: const TextStyle(fontSize: 12)),
                      if (transferCode.isNotEmpty) Text('Ref: $transferCode', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.blue),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Payout Details'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDetailRow('Amount', '₦${formatCurrency(amount.toDouble())}'),
                                _buildDetailRow('Reservation', reservationId),
                                _buildDetailRow('Apartment', apartmentTitle),
                                if (paidAt != null) _buildDetailRow('Paid at', formatDate(paidAt)),
                                if (transferCode.isNotEmpty) _buildDetailRow('Transfer code', transferCode),
                                _buildDetailRow('Host UID', hostUid),
                                _buildDetailRow('Commission doc id', d.id),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}