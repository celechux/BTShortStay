import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admindashboard_helpers.dart';
import 'admindashboard_tabs.dart';
import 'admindashboard_dialogs.dart';
import 'host_payments_tab.dart';
import 'main.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ScrollController _sidebarController = ScrollController();
  int _newPaymentNotifications = 0;

  final List<String> _tabs = [
    'Overview',
    'Apartments',
    'Hosts',
    'Guests',
    'Reservations',
    'Transactions Analytics',
    'Host Payments',
    'Feedback & Complaints',
    'Announcements',
  ];

  @override
  void initState() {
    super.initState();
    _listenToNewPayments();
    _testFeedbackCollection();
  }

  void _testFeedbackCollection() async {
    try {
      final snapshot = await _firestore.collection('feedback').get();
      print('Feedback collection debug:');
      print('Total documents: ${snapshot.docs.length}');
      for (var doc in snapshot.docs) {
        print('Document ID: ${doc.id}');
        print('Document data: ${doc.data()}');
      }
    } catch (e) {
      print('Error accessing feedback collection: $e');
    }
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  void _listenToNewPayments() {
    _firestore
        .collection('payments')
        .where('status', isEqualTo: 'completed')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        int newPayments = 0;
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final paymentTime = change.doc.data()?['timestamp'] as Timestamp?;
            if (paymentTime != null) {
              final now = DateTime.now();
              final paymentDateTime = paymentTime.toDate();
              if (now.difference(paymentDateTime).inMinutes <= 5) {
                newPayments++;
              }
            }
          }
        }
        if (newPayments > 0 && mounted) {
          setState(() {
            _newPaymentNotifications += newPayments;
          });
        }
      }
    });
  }

  void _clearNotifications() {
    setState(() {
      _newPaymentNotifications = 0;
    });
  }

  void _showNotifications() {
    _clearNotifications();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications, color: kPrimaryBlue),
            const SizedBox(width: 8),
            const Text('Recent Notifications'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('payments')
                .where('status', isEqualTo: 'completed')
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No recent payment notifications');
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final payment = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final timestamp = payment['timestamp'] as Timestamp?;
                  final amount = payment['amount'] ?? 0;
                  final guestName = payment['guestName'] ?? 'Unknown Guest';

                  return ListTile(
                    leading: Icon(Icons.payments, color: Colors.green),
                    title: Text('Payment Received'),
                    subtitle: Text('$guestName paid \$${amount.toStringAsFixed(2)}'),
                    trailing: timestamp != null
                        ? Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MyApp()),
        (route) => false,
      );
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(auth: _auth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: kTabLightBlue,
      drawer: isMobile ? _buildDrawer() : null,
      body: SafeArea(
        child: isMobile
            ? _buildMobileLayout()
            : Row(
                children: [
                  _buildSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: _buildSelectedTabContent(),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.admin_panel_settings, size: 48, color: kTabLightBlue),
          const SizedBox(height: 12),
          Text(
            'Admin Dashboard',
            style: const TextStyle(
              color: kTabLightBlue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return ListTile(
                  selected: isSelected,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTabIcon(index),
                        color: isSelected ? kPrimaryBlue : kTabLightBlue,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ],
                  ),
                  title: Text(
                    _tabs[index],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? kPrimaryBlue : Colors.black,
                    ),
                  ),
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text("Logout", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: kCardElevation / 2,
                ),
                onPressed: _logout,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Builder(
      builder: (context) => Column(
        children: [
          _buildHeader(isMobile: true, context: context),
          Expanded(
            child: _buildSelectedTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: kPrimaryBlue,
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.admin_panel_settings, size: 48, color: kTabLightBlue),
          const SizedBox(height: 12),
          Text(
            'Admin Dashboard',
            style: const TextStyle(
              color: kTabLightBlue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              controller: _sidebarController,
              child: ListView.builder(
                controller: _sidebarController,
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndex == index;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? kAccentBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      selected: isSelected,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getTabIcon(index),
                            color: isSelected ? Colors.white : kTabLightBlue,
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ],
                        ],
                      ),
                      title: Text(
                        _tabs[index],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text("Logout", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: kCardElevation / 2,
                ),
                onPressed: _logout,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  IconData _getTabIcon(int index) {
    switch (index) {
      case 0: return Icons.dashboard;
      case 1: return Icons.home_work;
      case 2: return Icons.verified_user;
      case 3: return Icons.people;
      case 4: return Icons.calendar_today;
      case 5: return Icons.payments;
      case 6: return Icons.people_alt;
      case 7: return Icons.feedback;
      case 8: return Icons.announcement;
      default: return Icons.circle;
    }
  }

  Widget _buildHeader({bool isMobile = false, BuildContext? context}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: kTabLightBlue,
        border: Border(bottom: BorderSide(color: kAccentBlue, width: 2)),
        boxShadow: [
          BoxShadow(
            color: kShadowBlue,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isMobile && context != null)
                IconButton(
                  icon: const Icon(Icons.menu, color: kPrimaryBlue),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              Text(
                _tabs[_selectedIndex],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _showNotifications,
                child: Stack(
                  children: [
                    Icon(Icons.notifications_none, color: kPrimaryBlue),
                    if (_newPaymentNotifications > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$_newPaymentNotifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTapDown: (details) {
                  showMenu(
                    context: context!,
                    position: RelativeRect.fromLTRB(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                    ),
                    items: [
                      PopupMenuItem(
                        child: ListTile(
                          leading: const Icon(Icons.lock, color: kPrimaryBlue),
                          title: const Text('Change Password'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _showChangePasswordDialog();
                          },
                        ),
                      ),
                      PopupMenuItem(
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Logout'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _logout();
                          },
                        ),
                      ),
                    ],
                  );
                },
                child: const CircleAvatar(
                  backgroundColor: kPrimaryBlue,
                  child: Icon(Icons.person, color: Colors.white),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    if (_selectedIndex == 6) {
      return HostPaymentsTab(
        reservationsStream: _firestore.collection('reservations').snapshots(),
      );
    }
    return AdminDashboardTabs(
      firestore: _firestore,
      selectedIndex: _selectedIndex,
      onTabChange: (index) => setState(() => _selectedIndex = index),
    );
  }
}