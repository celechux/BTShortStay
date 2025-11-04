import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admindashboard_helpers.dart';
import 'admin_tabs.dart';

/// Shows a larger preview of a profile image (or initials if no image).
Future<void> _showGuestProfilePreview(BuildContext context, String imageUrl, String title) {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: kPrimaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            // Content
            Container(
              color: Colors.black.withOpacity(0.02),
              constraints: const BoxConstraints(maxHeight: 560),
              child: imageUrl.isNotEmpty
                  ? InteractiveViewer(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, size: 72, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                kPrimaryBlue.withOpacity(0.3),
                                kPrimaryBlue.withOpacity(0.1),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              title.isNotEmpty ? title[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: kPrimaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 72,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class GuestsTab extends StatefulWidget {
  final Stream<QuerySnapshot> guestsStream;
  final FirebaseFirestore firestore;

  const GuestsTab({
    super.key,
    required this.guestsStream,
    required this.firestore,
  });

  @override
  State<GuestsTab> createState() => _GuestsTabState();
}

class _GuestsTabState extends State<GuestsTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Map<String, dynamic> guestData) {
    if (_searchQuery.isEmpty) return true;

    final query = _searchQuery.toLowerCase();
    final displayName = (guestData['fullName'] ??
            guestData['name'] ??
            guestData['firstName'] ??
            guestData['displayName'] ??
            '')
        .toString()
        .toLowerCase();
    final email = (guestData['email'] ?? guestData['emailAddress'] ?? '')
        .toString()
        .toLowerCase();

    return displayName.contains(query) || email.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, color: Colors.grey.shade500),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          // Guests List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.guestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kPrimaryBlue),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading guests: ${snapshot.error}',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return InfoTab(message: "No guests found");
                }

                final guestDocs = snapshot.data!.docs;
                final filteredGuests = guestDocs
                    .where((doc) => _matchesSearch(doc.data() as Map<String, dynamic>))
                    .toList();

                if (filteredGuests.isEmpty) {
                  return Center(
                    child: Text(
                      'No guests match "$_searchQuery"',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredGuests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filteredGuests[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final displayName = data['fullName'] ??
                        data['name'] ??
                        data['firstName'] ??
                        data['displayName'] ??
                        'Unknown Guest';
                    final email = data['email'] ?? data['emailAddress'] ?? 'No email';
                    final suspended = data['suspended'] == true;
                    final active = data['active'] == true || data['isActive'] == true;
                    final profileImage = (data['profileImage']?.toString() ??
                            data['profilePicture']?.toString() ??
                            data['image']?.toString() ??
                            data['photoURL']?.toString() ??
                            data['photo']?.toString() ??
                            '')
                        .trim();

                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => GuestDetailsDialog(
                            guestId: doc.id,
                            guestData: data,
                            firestore: widget.firestore,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.grey.shade50,
                            ],
                          ),
                          border: Border.all(color: Colors.grey.shade200, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Avatar with profile image
                              GestureDetector(
                                onTap: () {
                                  _showGuestProfilePreview(context, profileImage, displayName);
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: profileImage.isEmpty
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              kPrimaryBlue.withOpacity(0.3),
                                              kPrimaryBlue.withOpacity(0.1),
                                            ],
                                          )
                                        : null,
                                  ),
                                  child: profileImage.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            profileImage,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                                style: const TextStyle(
                                                  color: kPrimaryBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: kPrimaryBlue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Guest info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Status badges
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Active/Inactive badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: active
                                          ? Colors.green.withOpacity(0.12)
                                          : Colors.grey.withOpacity(0.12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          active ? Icons.check_circle : Icons.circle_outlined,
                                          size: 14,
                                          color: active ? Colors.green : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          active ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: active ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Suspended badge (if applicable)
                                  if (suspended) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: Colors.red.withOpacity(0.12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.block, size: 14, color: Colors.red),
                                          SizedBox(width: 4),
                                          Text(
                                            'Suspended',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(width: 12),

                              // Chevron
                              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Guest Details Dialog
class GuestDetailsDialog extends StatefulWidget {
  final String guestId;
  final Map<String, dynamic> guestData;
  final FirebaseFirestore firestore;

  const GuestDetailsDialog({
    super.key,
    required this.guestId,
    required this.guestData,
    required this.firestore,
  });

  @override
  State<GuestDetailsDialog> createState() => _GuestDetailsDialogState();
}

class _GuestDetailsDialogState extends State<GuestDetailsDialog> {
  bool _saving = false;

  Future<void> _toggleSuspend() async {
    final guestRef = widget.firestore.collection('guests').doc(widget.guestId);
    setState(() => _saving = true);
    try {
      final current = (widget.guestData['suspended'] == true);
      final newActive = current;

      await guestRef.update({
        'suspended': !current,
        'active': newActive,
        'isActive': newActive,
      });

      setState(() {
        widget.guestData['suspended'] = !current;
        widget.guestData['active'] = newActive;
        widget.guestData['isActive'] = newActive;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!current ? 'Guest suspended (Inactive)' : 'Guest unsuspended (Active)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteGuest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Guest'),
        content: const Text('Are you sure? This cannot be undone. This will permanently remove the guest account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final guestRef = widget.firestore.collection('guests').doc(widget.guestId);

      try {
        await guestRef.delete();
      } catch (deleteError) {
        if (deleteError.toString().contains('PERMISSION_DENIED') ||
            deleteError.toString().contains('Missing or insufficient permissions')) {
          await guestRef.update({
            'deleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
            'active': false,
            'isActive': false,
            'suspended': true,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guest marked as deleted (account deactivated)'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
          return;
        }
        rethrow;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guest deleted successfully'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting guest: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.guestData;
    final displayName = guest['fullName'] ??
        guest['name'] ??
        guest['firstName'] ??
        guest['displayName'] ??
        'Unknown Guest';
    final email = guest['email'] ?? guest['emailAddress'] ?? 'Not provided';
    final phone = guest['phone'] ?? guest['phoneNumber'] ?? 'Not provided';
    final suspended = guest['suspended'] == true;
    final active = guest['active'] == true || guest['isActive'] == true;
    final profileImage = (guest['profileImage']?.toString() ??
            guest['profilePicture']?.toString() ??
            guest['image']?.toString() ??
            guest['photoURL']?.toString() ??
            guest['photo']?.toString() ??
            '')
        .trim();
    final createdAt = guest['createdAt'] is Timestamp ? (guest['createdAt'] as Timestamp).toDate() : null;
    final joinedText = createdAt != null ? '${createdAt.day}/${createdAt.month}/${createdAt.year}' : 'Unknown';

    final address = guest['address'] ?? 'Not provided';
    final city = guest['city'] ?? '';
    final country = guest['country'] ?? '';
    final location = [city, country].where((s) => s.isNotEmpty).join(', ');
    final totalBookings = guest['totalBookings']?.toString() ?? '0';
    final lastBooking =
        guest['lastBooking'] is Timestamp ? (guest['lastBooking'] as Timestamp).toDate() : null;
    final lastBookingText =
        lastBooking != null ? '${lastBooking.day}/${lastBooking.month}/${lastBooking.year}' : 'None';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  // Tappable avatar for larger preview
                  GestureDetector(
                    onTap: () => _showGuestProfilePreview(context, profileImage, displayName),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: profileImage.isEmpty
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  kPrimaryBlue.withOpacity(0.3),
                                  kPrimaryBlue.withOpacity(0.1),
                                ],
                              )
                            : null,
                      ),
                      child: profileImage.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                profileImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: kPrimaryBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: kPrimaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(email, style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text('Phone: $phone', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusBadge('Active', active, active ? Colors.green : Colors.grey),
                      if (suspended) ...[
                        const SizedBox(height: 6),
                        _statusBadge('Suspended', true, Colors.red),
                      ],
                      const SizedBox(height: 12),
                      Text('Joined: $joinedText', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Guest Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 14),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _detailRow('Full name', displayName),
                                _detailRow('Email', email),
                                _detailRow('Phone', phone),
                                _detailRow('Address', address),
                                if (location.isNotEmpty) _detailRow('Location', location),
                                _detailRow('Active', active ? 'Yes' : 'No'),
                                _detailRow('Suspended', suspended ? 'Yes' : 'No'),
                                _detailRow('Total Bookings', totalBookings),
                                _detailRow('Last Booking', lastBookingText),
                                _detailRow('Member Since', joinedText),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Action buttons
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _toggleSuspend,
                                    icon: Icon(suspended ? Icons.play_arrow : Icons.pause, size: 16),
                                    label:
                                        Text(_saving ? 'Processing...' : (suspended ? 'Unsuspend' : 'Suspend')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: suspended ? Colors.green : Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _deleteGuest,
                                    icon: const Icon(Icons.delete, size: 16),
                                    label: Text(_saving ? 'Deleting...' : 'Delete'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_circle : Icons.circle_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}