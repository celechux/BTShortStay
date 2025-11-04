import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsTab extends StatefulWidget {
  final String hostUID;
  final VoidCallback? onNotificationsViewed;
  
  const NotificationsTab({
    super.key, 
    required this.hostUID,
    this.onNotificationsViewed,
  });

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  
  @override
  void initState() {
    super.initState();
    // Check for new announcements when this tab is first opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowNewAnnouncements();
    });
  }

  Future<void> _checkAndShowNewAnnouncements() async {
    try {
      // Get the last seen timestamp from local storage
      final prefs = await SharedPreferences.getInstance();
      final lastSeenTimestamp = prefs.getInt('last_seen_announcement_${widget.hostUID}') ?? 0;
      
      // Query for new announcements since last seen
      final querySnapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .where('timestamp', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(lastSeenTimestamp))
          .orderBy('timestamp', descending: true)
          .get();

      if (querySnapshot.docs.isNotEmpty && mounted) {
        _showAnnouncementPopup(querySnapshot.docs);
        
        // Update the last seen timestamp
        final latestTimestamp = querySnapshot.docs.first.data()['timestamp'] as Timestamp;
        await prefs.setInt('last_seen_announcement_${widget.hostUID}', latestTimestamp.millisecondsSinceEpoch);
        
        // Notify parent that notifications have been viewed
        widget.onNotificationsViewed?.call();
      }
    } catch (e) {
      debugPrint('Error checking announcements: $e');
    }
  }

  void _showAnnouncementPopup(List<QueryDocumentSnapshot> announcements) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AnnouncementPopupDialog(announcements: announcements);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print('NotificationsTab building for hostUID: ${widget.hostUID}');
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Detailed logging
        print('ConnectionState: ${snapshot.connectionState}');
        print('Has error: ${snapshot.hasError}');
        print('Has data: ${snapshot.hasData}');
        
        if (snapshot.hasError) {
          print('ERROR DETAILS: ${snapshot.error}');
          print('ERROR TYPE: ${snapshot.error.runtimeType}');
          
          // Check if it's a permission error
          String errorMessage = snapshot.error.toString();
          bool isPermissionError = errorMessage.contains('permission') || 
                                   errorMessage.contains('PERMISSION_DENIED');
          
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPermissionError ? Icons.lock : Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPermissionError 
                        ? 'Permission Denied' 
                        : 'Error Loading Announcements',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPermissionError
                        ? 'Please check Firestore security rules'
                        : errorMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (isPermissionError) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, 
                                   color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Firestore Rules Fix',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Go to Firebase Console → Firestore → Rules\nand add read permission for announcements collection',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading announcements...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('No announcements found');
          return Center(
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(40),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_none, 
                        size: 64, color: Color(0xFF2196F3)),
                    const SizedBox(height: 16),
                    const Text(
                      "No Announcements",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "There are no announcements at this time.\nCheck back later for updates.",
                      style: TextStyle(fontSize: 15, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Refresh"),
                      onPressed: () {
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final announcements = snapshot.data!.docs;
        print('Successfully loaded ${announcements.length} announcements');

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: announcements.length,
          itemBuilder: (context, index) {
            final announcement = announcements[index].data() as Map<String, dynamic>;
            final title = announcement['title'] ?? 'Untitled';
            final message = announcement['message'] ?? '';
            final timestamp = announcement['timestamp'] as Timestamp?;
            
            return AnnouncementCard(
              title: title,
              message: message,
              timestamp: timestamp,
            );
          },
        );
      },
    );
  }
}

class AnnouncementCard extends StatefulWidget {
  final String title;
  final String message;
  final Timestamp? timestamp;

  const AnnouncementCard({
    super.key,
    required this.title,
    required this.message,
    this.timestamp,
  });

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> 
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        elevation: 6,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: _toggleExpansion,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                    if (widget.timestamp != null)
                      Text(
                        _formatTimestamp(widget.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.expand_more,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
                SizeTransition(
                  sizeFactor: _animation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Popup Dialog Widget
class AnnouncementPopupDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot> announcements;

  const AnnouncementPopupDialog({
    super.key,
    required this.announcements,
  });

  @override
  State<AnnouncementPopupDialog> createState() => _AnnouncementPopupDialogState();
}

class _AnnouncementPopupDialogState extends State<AnnouncementPopupDialog> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, 
                      color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'New Announcements',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.announcements.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentIndex + 1} of ${widget.announcements.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: widget.announcements.length,
                itemBuilder: (context, index) {
                  final announcement = widget.announcements[index].data() as Map<String, dynamic>;
                  final title = announcement['title'] ?? 'Untitled';
                  final message = announcement['message'] ?? '';
                  final timestamp = announcement['timestamp'] as Timestamp?;

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ),
                            if (timestamp != null)
                              Text(
                                _formatTimestamp(timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              message,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Navigation dots (if multiple announcements)
            if (widget.announcements.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.announcements.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == index
                            ? const Color(0xFF2196F3)
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.announcements.length > 1 && _currentIndex > 0)
                    TextButton.icon(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    )
                  else
                    const SizedBox.shrink(),
                  
                  if (widget.announcements.length > 1 && 
                      _currentIndex < widget.announcements.length - 1)
                    TextButton.icon(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Got it!'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}