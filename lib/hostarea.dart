import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'overview_tab.dart';
import 'reservations_tab.dart';
import 'apartments_tab.dart';
import 'payments_tab.dart';
import 'profile_tab.dart';
import 'add_apartment_tab.dart';
import 'notifications_tab.dart';

class HostArea extends StatefulWidget {
  final int initialTab;
  const HostArea({super.key, this.initialTab = 0});

  @override
  State<HostArea> createState() => _HostAreaState();
}

class _HostAreaState extends State<HostArea>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String? hostUID;
  String? hostFullName;
  bool _isSidebarOpen = false;

  final ScrollController _sidebarController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final List<String> _tabs = [
    'Overview',
    'Reservations',
    'My Apartments',
    'My Payments',
    'My Profile',
    'Add Apartment',
    'Notifications',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    final user = FirebaseAuth.instance.currentUser;
    hostUID = user?.uid;
    _loadHostName();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadHostName() async {
    if (hostUID != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(hostUID)
            .get();
        if (doc.exists) {
          setState(() {
            hostFullName = doc.data()?['fullName'] ?? 'Host';
          });
        }
      } catch (e) {
        print('Error loading host name: $e');
      }
    }
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool get _isMobile {
    return MediaQuery.of(context).size.width < 768;
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (hostUID == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content
          Row(
            children: [
              // Desktop sidebar - only show on desktop
              if (!_isMobile) _buildDesktopSidebar(),
              // Main content area
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade50,
                        child: _selectedIndex == 6
                            ? NotificationsTab(hostUID: hostUID!)
                            : SingleChildScrollView(
                                padding: EdgeInsets.all(_isMobile ? 16.0 : 24.0),
                                child: _buildSelectedTabContent(),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Overlay to close sidebar when tapping outside
          if (_isMobile && _isSidebarOpen)
            GestureDetector(
              onTap: _toggleSidebar,
              child: Container(
                color: Colors.black26,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          // Mobile sidebar overlay (drawn on top of overlay)
          if (_isMobile) _buildMobileSidebar(),
        ],
      ),
      bottomNavigationBar: _isMobile ? _buildBottomNavigationBar() : null,
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 250,
      color: const Color(0xFF2196F3),
      child: _buildSidebarContent(),
    );
  }

  Widget _buildMobileSidebar() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value * 280, 0),
          child: Container(
            width: 280,
            height: double.infinity,
            color: const Color(0xFF2196F3),
            child: SafeArea(
              child: _buildSidebarContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarContent() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.home_work, size: 48, color: Colors.white),
        const SizedBox(height: 12),
        const Text(
          'Host Dashboard',
          style: TextStyle(
            color: Colors.white,
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    selected: _selectedIndex == index,
                    selectedTileColor: Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Icon(
                      _getTabIcon(index),
                      color: Colors.white,
                    ),
                    title: Text(
                      _tabs[index],
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                        if (_isMobile) {
                          _toggleSidebar();
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  IconData _getTabIcon(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard;
      case 1:
        return Icons.calendar_today;
      case 2:
        return Icons.home_work;
      case 3:
        return Icons.payment;
      case 4:
        return Icons.person;
      case 5:
        return Icons.add_home;
      case 6:
        return Icons.notifications;
      default:
        return Icons.circle;
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 16 : 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Mobile menu button
            if (_isMobile) ...[
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: _toggleSidebar,
              ),
              const SizedBox(width: 8),
            ],
            // Title - Show "Hi, FullName" for Overview on mobile, otherwise tab name
            Expanded(
              child: Text(
                _isMobile && _selectedIndex == 0
                    ? 'Hi, ${hostFullName ?? 'Host'}'
                    : _tabs[_selectedIndex],
                style: TextStyle(
                  fontSize: _isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 6; // Navigate to notifications
                    });
                  },
                ),
                const SizedBox(width: 8),
                const CircleAvatar(
                  backgroundColor: Color(0xFF2196F3),
                  radius: 18,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    Widget content;
    switch (_selectedIndex) {
      case 0:
        content = OverviewTabWithActivities(
          hostUID: hostUID!,
          isMobile: _isMobile,
          onApartmentsTap: () => setState(() => _selectedIndex = 2),
          onReservationsTap: () => setState(() => _selectedIndex = 1),
          onRevenueTap: () => setState(() => _selectedIndex = 3),
          onAddApartmentTap: () => setState(() => _selectedIndex = 5),
        );
        break;
      case 1:
        content = ReservationsTab(hostUID: hostUID!);
        break;
      case 2:
        content = ApartmentsTab(hostUID: hostUID!);
        break;
      case 3:
        content = PaymentsTab(hostUID: hostUID!);
        break;
      case 4:
        content = ProfileTab(hostUID: hostUID!);
        break;
      case 5:
        content = AddApartmentTab(hostUID: hostUID!);
        break;
      case 6:
        // NotificationsTab handled separately in build method
        content = const SizedBox.shrink();
        break;
      default:
        content = const Center(child: Text("Unknown Tab"));
    }

    // Wrap content in responsive container
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _isMobile ? double.infinity : 1200,
      ),
      child: content,
    );
  }

  Widget buildRecentActivities(bool isMobile) {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: const Color(0xFF2196F3),
                    size: isMobile ? 20 : 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Activities',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Clear All button for mobile
              if (isMobile)
                TextButton(
                  onPressed: () => _showClearAllDialog(),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: Color(0xFF2196F3),
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reservations')
                .where('hostUID', isEqualTo: hostUID)
                .snapshots(),
            builder: (context, reservationSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .snapshots(),
                builder: (context, announcementSnapshot) {
                  if (reservationSnapshot.connectionState == ConnectionState.waiting ||
                      announcementSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (reservationSnapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error loading reservations: ${reservationSnapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    );
                  }

                  if (announcementSnapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error loading announcements: ${announcementSnapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    );
                  }

                  // Get all reservations and sort manually, filtering out hidden ones
                  final allReservations = (reservationSnapshot.data?.docs ?? [])
                      .where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['hiddenFromHost'] != hostUID;
                      })
                      .toList();

                  allReservations.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = aData['timestamp'] as Timestamp?;
                    final bTime = bData['timestamp'] as Timestamp?;

                    if (aTime == null) return 1;
                    if (bTime == null) return -1;

                    return bTime.compareTo(aTime);
                  });

                  final reservations = allReservations.take(2).toList();

                  // Get all announcements and sort manually, filtering out hidden ones
                  final allAnnouncements = (announcementSnapshot.data?.docs ?? [])
                      .where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['hiddenFromHost'] != hostUID;
                      })
                      .toList();

                  allAnnouncements.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = aData['timestamp'] as Timestamp?;
                    final bTime = bData['timestamp'] as Timestamp?;

                    if (aTime == null) return 1;
                    if (bTime == null) return -1;

                    return bTime.compareTo(aTime);
                  });

                  final announcements = allAnnouncements.take(1).toList();

                  if (reservations.isEmpty && announcements.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No recent activities',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Announcements
                      ...announcements.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Announcement';
                        final message = data['message'] ?? '';
                        final timestamp = data['timestamp'] as Timestamp?;

                        return _buildActivityItem(
                          icon: Icons.campaign,
                          iconColor: Colors.orange,
                          title: title,
                          subtitle: message,
                          timestamp: timestamp,
                          onClear: isMobile ? () => _clearActivity(doc.id, 'announcements') : null,
                        );
                      }),

                      // Reservations
                      ...reservations.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final guestName = data['guestName'] ?? data['userName'] ?? 'Guest';
                        final apartmentName = data['apartmentName'] ?? data['apartmentTitle'] ?? 'Apartment';
                        final status = data['status'] ?? 'pending';
                        final timestamp = data['timestamp'] as Timestamp?;

                        return _buildActivityItem(
                          icon: Icons.bookmark,
                          iconColor: _getStatusColor(status),
                          title: 'New Reservation',
                          subtitle: '$guestName booked $apartmentName',
                          timestamp: timestamp,
                          onClear: isMobile ? () => _clearActivity(doc.id, 'reservations') : null,
                        );
                      }),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Timestamp? timestamp,
    VoidCallback? onClear,
  }) {
    final timeAgo = timestamp != null
        ? _getTimeAgo(timestamp.toDate())
        : 'Recently';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Clear button for mobile
          if (onClear != null)
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: Colors.grey.shade400,
              ),
              onPressed: onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  void _clearActivity(String docId, String collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Activity'),
        content: const Text('Are you sure you want to remove this activity from view?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Add a 'hidden' field to mark as cleared instead of deleting
                await FirebaseFirestore.instance
                    .collection(collection)
                    .doc(docId)
                    .update({'hiddenFromHost': hostUID});

                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activity cleared')),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Activities'),
        content: const Text('Are you sure you want to clear all recent activities from view?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Get all visible activities
                final reservationsQuery = await FirebaseFirestore.instance
                    .collection('reservations')
                    .where('hostUID', isEqualTo: hostUID)
                    .get();

                final announcementsQuery = await FirebaseFirestore.instance
                    .collection('announcements')
                    .get();

                // Update all to hidden
                final batch = FirebaseFirestore.instance.batch();

                for (var doc in reservationsQuery.docs) {
                  batch.update(doc.reference, {'hiddenFromHost': hostUID});
                }

                for (var doc in announcementsQuery.docs) {
                  batch.update(doc.reference, {'hiddenFromHost': hostUID});
                }

                await batch.commit();

                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All activities cleared')),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} week${difference.inDays > 13 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.dashboard, 'Home', 0),
              _buildBottomNavItem(Icons.calendar_today, 'Reservations', 1),
              _buildBottomNavItem(Icons.home_work, 'Apartments', 2),
              _buildBottomNavItem(Icons.payment, 'Payments', 3),
              _buildBottomNavItem(Icons.logout, 'Logout', -1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () async {
        if (index == -1) {
          // Logout
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (route) => false);
          }
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF2196F3) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Responsive Card Widget Helper
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      // Mobile: Light blue button-like design
      return Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD), // Light blue background
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      );
    } else {
      // Desktop: Traditional card design
      return Container(
        margin: margin ?? const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      );
    }
  }
}

// Responsive Grid Helper - Modified for horizontal scroll on mobile
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.childAspectRatio = 1.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      // Mobile: Horizontal scrollable buttons
      return SizedBox(
        height: 180, // Increased height to prevent overflow
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: children.length,
          itemBuilder: (context, index) {
            return Container(
              width: screenWidth * 0.85, // 85% of screen width
              margin: const EdgeInsets.only(right: 12),
              child: children[index],
            );
          },
        ),
      );
    } else {
      // Desktop: Traditional grid
      int crossAxisCount;
      if (screenWidth < 900) {
        crossAxisCount = 2; // Tablet: 2 columns
      } else {
        crossAxisCount = 3; // Desktop: 3 columns
      }

      return GridView.count(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        padding: padding ?? const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      );
    }
  }
}

// Responsive Row/Column Helper
class ResponsiveLayout extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double breakpoint;

  const ResponsiveLayout({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.breakpoint = 768,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < breakpoint;

    if (isMobile) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    } else {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children.map((child) => Expanded(child: child)).toList(),
      );
    }
  }
}

// Wrapper class to inject Recent Activities into OverviewTab
class OverviewTabWithActivities extends StatelessWidget {
  final String hostUID;
  final bool isMobile;
  final VoidCallback? onApartmentsTap;
  final VoidCallback? onReservationsTap;
  final VoidCallback? onRevenueTap;
  final VoidCallback? onAddApartmentTap;

  const OverviewTabWithActivities({
    super.key,
    required this.hostUID,
    required this.isMobile,
    this.onApartmentsTap,
    this.onReservationsTap,
    this.onRevenueTap,
    this.onAddApartmentTap,
  });

  @override
  Widget build(BuildContext context) {
    // Get the parent state to access buildRecentActivities
    final hostAreaState = context.findAncestorStateOfType<_HostAreaState>();

    return OverviewTab(
      hostUID: hostUID,
      recentActivitiesWidget: hostAreaState?.buildRecentActivities(isMobile),
      onApartmentsTap: onApartmentsTap,
      onReservationsTap: onReservationsTap,
      onRevenueTap: onRevenueTap,
      onAddApartmentTap: onAddApartmentTap,
    );
  }
}

// Combined Stats Card for Mobile - Horizontal Layout with Blue Icons - NOW CLICKABLE
class CombinedStatsCard extends StatelessWidget {
  final int apartmentsCount;
  final int reservationsCount;
  final double totalRevenue;
  final VoidCallback? onApartmentsTap;
  final VoidCallback? onReservationsTap;
  final VoidCallback? onRevenueTap;

  const CombinedStatsCard({
    super.key,
    required this.apartmentsCount,
    required this.reservationsCount,
    required this.totalRevenue,
    this.onApartmentsTap,
    this.onReservationsTap,
    this.onRevenueTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.home_work,
            value: apartmentsCount.toString(),
            label: 'My Apartments',
            onTap: onApartmentsTap,
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.blue.shade200,
          ),
          _buildStatItem(
            icon: Icons.calendar_today,
            value: reservationsCount.toString(),
            label: 'Reservations',
            onTap: onReservationsTap,
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.blue.shade200,
          ),
          _buildStatItem(
            icon: Icons.payments,
            value: '₦${totalRevenue.toStringAsFixed(0)}',
            label: 'Total Revenue',
            onTap: onRevenueTap,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF2196F3),
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add Apartment Action Card for Mobile - NOW CLICKABLE
class AddApartmentActionCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddApartmentActionCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade300.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_home,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Apartment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'List a new property',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}