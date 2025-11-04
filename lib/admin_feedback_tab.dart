import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admindashboard_helpers.dart';

class FeedbackComplaintsTab extends StatelessWidget {
  final FirebaseFirestore firestore;

  const FeedbackComplaintsTab({
    super.key,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('feedback').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error loading feedback',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            );
          }

          final feedbackDocs = snapshot.data?.docs ?? [];

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.feedback_outlined, color: kPrimaryBlue, size: 32),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feedback Management',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryBlue,
                          ),
                        ),
                        Text(
                          'Manage user feedback and reviews',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _SummaryChip(
                      label: 'Total: ${feedbackDocs.length}',
                      color: kPrimaryBlue,
                      icon: Icons.feedback,
                    ),
                  ],
                ),
              ),

              // Summary Cards (removed complaints card)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: "Total Feedback",
                        count: feedbackDocs.length,
                        icon: Icons.feedback,
                        color: kPrimaryBlue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: "Unresolved",
                        count: feedbackDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['status'] != 'resolved';
                        }).length,
                        icon: Icons.warning_amber,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: "Resolved",
                        count: feedbackDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['status'] == 'resolved';
                        }).length,
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              // Feedback Cards List (one per row - wide cards)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ListView.builder(
                    itemCount: feedbackDocs.length,
                    itemBuilder: (context, index) {
                      final feedbackDoc = feedbackDocs[index];
                      final feedback = feedbackDoc.data() as Map<String, dynamic>;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: FeedbackCard(
                          feedback: feedback,
                          feedbackId: feedbackDoc.id,
                          firestore: firestore,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ----------- FEEDBACK CARD -----------
class FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> feedback;
  final String feedbackId;
  final FirebaseFirestore firestore;

  const FeedbackCard({
    super.key,
    required this.feedback,
    required this.feedbackId,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    final String userEmail = feedback['guestEmail'] ?? 'Unknown User';
    final String message = feedback['message'] ?? 'No message provided';
    final String status = feedback['status'] ?? 'pending';
    final Timestamp? timestamp = feedback['createdAt'];
    final String rating = feedback['rating']?.toString() ?? 'N/A';

    final DateTime? dateTime = timestamp?.toDate();
    final String formattedDate = dateTime != null
        ? '${dateTime.day}/${dateTime.month}/${dateTime.year}'
        : 'Unknown date';

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.pending;
    String statusText = 'Pending';

    switch (status.toLowerCase()) {
      case 'resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Resolved';
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        statusText = 'In Progress';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
    }

    return Card(
      elevation: kCardElevation,
      shadowColor: kShadowBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: kAccentBlue.withOpacity(0.3),
          width: 1
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              kPrimaryBlue.withOpacity(0.05),
              Colors.white
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar and basic info
              Column(
                children: [
                  CircleAvatar(
                    backgroundColor: kPrimaryBlue.withOpacity(0.2),
                    radius: 25,
                    child: Icon(
                      Icons.feedback,
                      color: kPrimaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userEmail,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        if (rating != 'N/A') ...[
                          const SizedBox(width: 16),
                          _InfoChip(
                            label: '$rating★',
                            color: Colors.amber,
                            icon: Icons.star,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Message
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _viewDetails(context),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('View Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (status != 'resolved')
                          ElevatedButton.icon(
                            onPressed: () => _markAsResolved(context),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Resolve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _deleteFeedback(context),
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewDetails(BuildContext context) async {
    final String userEmail = feedback['guestEmail'] ?? 'Unknown User';
    final String message = feedback['message'] ?? 'No message provided';
    final String status = feedback['status'] ?? 'pending';
    final Timestamp? timestamp = feedback['createdAt'];
    final String rating = feedback['rating']?.toString() ?? 'N/A';
    final String apartmentId = feedback['apartmentId'] ?? '';

    final DateTime? dateTime = timestamp?.toDate();
    final String formattedDate = dateTime != null
        ? '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
        : 'Unknown date';

    // Fetch apartment and host details
    String apartmentTitle = 'Unknown Apartment';
    String hostName = 'Unknown Host';
    String hostEmail = 'Unknown Host Email';

    if (apartmentId.isNotEmpty) {
      try {
        final apartmentDoc = await firestore.collection('apartments').doc(apartmentId).get();
        if (apartmentDoc.exists) {
          final apartmentData = apartmentDoc.data() as Map<String, dynamic>;
          apartmentTitle = apartmentData['title'] ?? apartmentData['name'] ?? 'Unknown Apartment';
          final hostUID = apartmentData['hostUID'] ?? '';
          if (hostUID.isNotEmpty) {
            var hostDoc = await firestore.collection('hosts').doc(hostUID).get();
            if (!hostDoc.exists) {
              final hostQuery = await firestore.collection('hosts')
                  .where('hostUID', isEqualTo: hostUID)
                  .limit(1)
                  .get();
              if (hostQuery.docs.isNotEmpty) {
                hostDoc = hostQuery.docs.first;
              }
            }
            if (!hostDoc.exists) {
              final authQuery = await firestore.collection('hosts')
                  .where('authUID', isEqualTo: hostUID)
                  .limit(1)
                  .get();
              if (authQuery.docs.isNotEmpty) {
                hostDoc = authQuery.docs.first;
              }
            }
            if (hostDoc.exists) {
              final hostData = hostDoc.data() as Map<String, dynamic>;
              hostName = hostData['fullName'] ??
                        hostData['name'] ??
                        hostData['firstName'] ??
                        hostData['displayName'] ??
                        'Unknown Host';
              hostEmail = hostData['email'] ??
                         hostData['emailAddress'] ??
                         'Unknown Host Email';
            }
          }
        }
      } catch (e) {}
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.feedback, color: kPrimaryBlue),
            const SizedBox(width: 12),
            const Text('Feedback Details'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Guest Email', userEmail),
              _DetailRow('Date', formattedDate),
              _DetailRow('Status', status),
              _DetailRow('Apartment', apartmentTitle),
              _DetailRow('Host Name', hostName),
              _DetailRow('Host Email', hostEmail),
              if (rating != 'N/A') _DetailRow('Rating', '$rating★'),
              const SizedBox(height: 16),
              const Text(
                'Message:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(message),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (status != 'resolved')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsResolved(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Mark Resolved', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _DetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _markAsResolved(BuildContext context) async {
    try {
      await firestore.collection('feedback').doc(feedbackId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback marked as resolved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating feedback: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteFeedback(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Feedback'),
        content: const Text('Are you sure you want to delete this feedback? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await firestore.collection('feedback').doc(feedbackId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Small helper widgets used in the feedback tab
class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _InfoChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: kCardElevation,
      shadowColor: kShadowBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}