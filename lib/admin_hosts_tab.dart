// Note: adjust the file name/path to match your project
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'admindashboard_helpers.dart';
import 'admin_tabs.dart';

/// Shows a larger preview of a profile image (or initials if no image).
/// Kept as a file-private helper so it can be reused by both the list avatar
/// and the dialog header avatar without changing other parts of the file.
Future<void> _showProfilePreview(BuildContext context, String imageUrl, String title) {
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

class HostsTab extends StatefulWidget {
  final Stream<QuerySnapshot> hostsStream;
  final FirebaseFirestore firestore;

  const HostsTab({
    super.key,
    required this.hostsStream,
    required this.firestore,
  });

  @override
  State<HostsTab> createState() => _HostsTabState();
}

class _HostsTabState extends State<HostsTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Map<String, dynamic> hostData) {
    if (_searchQuery.isEmpty) return true;

    final query = _searchQuery.toLowerCase();
    final displayName = (hostData['fullName'] ??
            hostData['name'] ??
            hostData['firstName'] ??
            hostData['displayName'] ??
            '')
        .toString()
        .toLowerCase();
    final email = (hostData['email'] ?? hostData['emailAddress'] ?? '').toString().toLowerCase();

    return displayName.contains(query) || email.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Search Bar (same styling as GuestsTab)
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

          // Hosts List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.hostsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kPrimaryBlue),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading hosts: ${snapshot.error}',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return InfoTab(message: "No hosts found");
                }

                final hostDocs = snapshot.data!.docs;
                final filteredHosts = hostDocs
                    .where((doc) => _matchesSearch(doc.data() as Map<String, dynamic>))
                    .toList();

                if (filteredHosts.isEmpty) {
                  return Center(
                    child: Text(
                      'No hosts match "$_searchQuery"',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredHosts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filteredHosts[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final displayName = data['fullName'] ??
                        data['name'] ??
                        data['firstName'] ??
                        data['displayName'] ??
                        'Unknown Host';
                    final email = data['email'] ?? data['emailAddress'] ?? 'No email';
                    final suspended = data['suspended'] == true;
                    final verified = data['verified'] == true || data['isVerified'] == true || (data['status']=='verified');
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
                          builder: (context) => HostDetailsDialog(
                            hostId: doc.id,
                            hostData: data,
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
                                  // show larger preview when avatar tapped
                                  _showProfilePreview(context, profileImage, displayName);
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

                              // Host info
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
                                  // Verification badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: verified
                                          ? Colors.green.withOpacity(0.12)
                                          : Colors.orange.withOpacity(0.12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          verified ? Icons.verified : Icons.info_outline,
                                          size: 14,
                                          color: verified ? Colors.green : Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          verified ? 'Verified' : 'Unverified',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: verified ? Colors.green : Colors.orange,
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

// Enhanced HostDetailsDialog (unchanged from your provided version but with verify flow)
// I updated the verify/unverify logic below to implement the Firestore 'status' update and the call
// to the createPaystackRecipient Cloud Function. It preserves the rest of the dialog behavior.
class HostDetailsDialog extends StatefulWidget {
  final String hostId;
  final Map<String, dynamic> hostData;
  final FirebaseFirestore firestore;

  const HostDetailsDialog({
    super.key,
    required this.hostId,
    required this.hostData,
    required this.firestore,
  });

  @override
  State<HostDetailsDialog> createState() => _HostDetailsDialogState();
}

class _HostDetailsDialogState extends State<HostDetailsDialog> {
  bool _loadingDocs = true;
  List<Map<String, dynamic>> _documents = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocs = true);
    final hostId = widget.hostId;
    final firestore = widget.firestore;
    final List<Map<String, dynamic>> docs = [];

    try {
      final hostSnap = await firestore.collection('hosts').doc(hostId).get();
      if (hostSnap.exists) {
        final hostMap = hostSnap.data() as Map<String, dynamic>;
        final possibleFields = ['documents', 'verificationDocs', 'verification_documents', 'uploadedDocs'];
        for (final field in possibleFields) {
          if (hostMap.containsKey(field) && hostMap[field] is List) {
            final list = hostMap[field] as List;
            for (var item in list) {
              if (item is String) {
                docs.add({'name': _basenameFromUrl(item), 'url': item});
              } else if (item is Map) {
                final map = Map<String, dynamic>.from(item);
                map['name'] = map['name'] ?? _basenameFromUrl(map['url']?.toString() ?? '');
                docs.add(map);
              }
            }
            break;
          }
        }
      }

      if (docs.isEmpty) {
        final sub = await firestore.collection('hosts').doc(hostId).collection('documents').get();
        if (sub.docs.isNotEmpty) {
          for (final d in sub.docs) {
            final m = d.data();
            m['id'] = d.id;
            m['name'] = m['name'] ?? m['filename'] ?? _basenameFromUrl(m['url']?.toString() ?? '');
            docs.add(m);
          }
        }
      }

      if (docs.isEmpty) {
        final altCollections = ['host_documents', 'hostDocuments', 'host_docs'];
        for (final col in altCollections) {
          final query = await firestore.collection(col).where('hostId', isEqualTo: hostId).get();
          if (query.docs.isNotEmpty) {
            for (final d in query.docs) {
              final m = d.data();
              m['id'] = d.id;
              m['name'] = m['name'] ?? m['filename'] ?? _basenameFromUrl(m['url']?.toString() ?? '');
              docs.add(m);
            }
            break;
          }
        }
      }
    } catch (e) {
      // swallow
    } finally {
      setState(() {
        _documents = docs;
        _loadingDocs = false;
      });
    }
  }

  String _basenameFromUrl(String url) {
    if (url.isEmpty) return 'document';
    try {
      final uri = Uri.parse(url);
      final segs = uri.pathSegments;
      return segs.isNotEmpty ? segs.last : url;
    } catch (e) {
      return url;
    }
  }

  /// Updated verify/unverify flow:
  /// - When verifying: set status:'verified' (and verified:true), then call the Cloud Function
  ///   'createPaystackRecipient' with {'hostId': hostId}. If the function returns a recipient code,
  ///   save it on the host document as 'paystackRecipientCode'.
  /// - When unverifying: set status:'unverified' (and verified:false). We do not try to delete
  ///   any existing paystack recipient here — that depends on your backend processes.
  Future<void> _toggleVerified() async {
    final hostRef = widget.firestore.collection('hosts').doc(widget.hostId);
    setState(() => _saving = true);
    try {
      final current =
          (widget.hostData['verified'] == true || widget.hostData['isVerified'] == true || widget.hostData['status'] == 'verified');

      if (current) {
        // Unverify flow
        await hostRef.update({'status': 'unverified', 'verified': false});
        setState(() {
          widget.hostData['verified'] = false;
          widget.hostData['status'] = 'unverified';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host unverified'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // Verify flow: update status first, then call Cloud Function
      await hostRef.update({'status': 'verified', 'verified': true});

      // Call Cloud Function to create Paystack recipient
      final callable = FirebaseFunctions.instance.httpsCallable('createPaystackRecipient');
final result = await callable.call({'hostId': widget.hostId});

      String? recipientCode;
      final data = result.data;
      if (data is Map) {
        // Try common key variations
        recipientCode = (data['recipient_code'] ?? data['recipientCode'] ?? data['recipient'] ?? data['recipientId'])?.toString();
        // Some functions might return nested objects; try to inspect common shapes:
        if ((recipientCode == null || recipientCode.isEmpty) && data.containsKey('data') && data['data'] is Map) {
          final inner = data['data'] as Map;
          recipientCode = (inner['recipient_code'] ?? inner['recipientCode'] ?? inner['recipient'])?.toString();
        }
      } else if (data != null) {
        recipientCode = data.toString();
      }

      if (recipientCode != null && recipientCode.isNotEmpty) {
        try {
          await hostRef.update({'paystackRecipientCode': recipientCode});
        } catch (_) {
          // If saving recipient code fails, we still proceed but log / show a message
        }
      }

      setState(() {
        widget.hostData['verified'] = true;
        widget.hostData['status'] = 'verified';
        if (recipientCode != null && recipientCode.isNotEmpty) {
          widget.hostData['paystackRecipientCode'] = recipientCode;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(recipientCode != null && recipientCode.isNotEmpty
              ? 'Host verified and Paystack recipient created: $recipientCode'
              : 'Host verified (recipient code not returned)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Friendly message for users, log raw errors elsewhere if needed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying host: $e'), backgroundColor: Colors.red),
      );
      // Optional: attempt to revert the status change if it was set but function failed.
      // For now we leave the status as-is; you may choose to revert depending on your requirements.
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _toggleSuspend() async {
    final hostRef = widget.firestore.collection('hosts').doc(widget.hostId);
    setState(() => _saving = true);
    try {
      final current = (widget.hostData['suspended'] == true);
      await hostRef.update({'suspended': !current});
      setState(() {
        widget.hostData['suspended'] = !current;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!current ? 'Host suspended' : 'Host unsuspended'),
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

  Future<void> _deleteHost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Host'),
        content: const Text('Are you sure? This cannot be undone.'),
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
      await widget.firestore.collection('hosts').doc(widget.hostId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Host deleted'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  void _viewDocument(Map<String, dynamic> doc) {
    final url = (doc['url'] ?? doc['fileUrl'] ?? doc['downloadUrl'] ?? '').toString();
    final name = doc['name']?.toString() ?? _basenameFromUrl(url);
    final isImage = url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.webp') ||
        url.toLowerCase().endsWith('.gif');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
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
                  const Icon(Icons.image, color: kPrimaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Container(
              constraints: const BoxConstraints(maxHeight: 600, maxWidth: 700),
              color: Colors.black.withOpacity(0.02),
              child: url.isNotEmpty
                  ? InteractiveViewer(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'No preview available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.hostData;
    final displayName = host['fullName'] ??
        host['name'] ??
        host['firstName'] ??
        host['displayName'] ??
        'Unknown Host';
    final email = host['email'] ?? host['emailAddress'] ?? 'Not provided';
    final phone = host['phone'] ?? host['phoneNumber'] ?? 'Not provided';
    final suspended = host['suspended'] == true;
    final verified = host['verified'] == true || host['isVerified'] == true || (host['status'] == 'verified');
    final profileImage = (host['profileImage']?.toString() ??
            host['profilePicture']?.toString() ??
            host['image']?.toString() ??
            host['photoURL']?.toString() ??
            host['photo']?.toString() ??
            '')
        .trim();
    final createdAt = host['createdAt'] is Timestamp ? (host['createdAt'] as Timestamp).toDate() : null;
    final joinedText = createdAt != null ? '${createdAt.day}/${createdAt.month}/${createdAt.year}' : 'Unknown';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 750),
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
                  // Make the larger avatar in the dialog tappable to show a bigger preview.
                  GestureDetector(
                    onTap: () => _showProfilePreview(context, profileImage, displayName),
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
                      _statusBadge('Verified', verified, verified ? Colors.green : Colors.orange),
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
                child: Row(
                  children: [
                    // Left: Details
                    Expanded(
                      flex: 2,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Host Details',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 14),
                              _detailRow('Full name', displayName),
                              _detailRow('Email', email),
                              _detailRow('Phone', phone),
                              _detailRow('Verified', verified ? 'Yes' : 'No'),
                              _detailRow('Suspended', suspended ? 'Yes' : 'No'),
                              const Spacer(),
                              // Action buttons
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _saving ? null : _toggleVerified,
                                          icon: Icon(verified ? Icons.close : Icons.verified, size: 16),
                                          label: Text(_saving ? 'Processing...' : (verified ? 'Unverify' : 'Verify')),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: verified ? Colors.orange : Colors.green,
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
                                          onPressed: _saving ? null : _toggleSuspend,
                                          icon: Icon(suspended ? Icons.play_arrow : Icons.pause, size: 16),
                                          label: Text(_saving ? 'Processing...' : (suspended ? 'Unsuspend' : 'Suspend')),
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
                                          onPressed: _saving ? null : _deleteHost,
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

                    const SizedBox(width: 16),

                    // Right: Documents
                    Expanded(
                      flex: 3,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Verification Documents',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              if (_loadingDocs)
                                const Expanded(
                                  child: Center(child: CircularProgressIndicator(color: kPrimaryBlue)),
                                )
                              else if (_documents.isEmpty)
                                const Expanded(
                                  child: Center(
                                    child: Text('No documents uploaded',
                                        style: TextStyle(color: Colors.grey)),
                                  ),
                                )
                              else
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _documents.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, i) {
                                      final doc = _documents[i];
                                      final name = doc['name']?.toString() ?? 'Document ${i + 1}';
                                      final url =
                                          (doc['url'] ?? doc['fileUrl'] ?? doc['downloadUrl'] ?? '').toString();
                                      final label = doc['type'] ?? doc['label'] ?? '';
                                      final uploadedAt = (doc['uploadedAt'] is Timestamp)
                                          ? (doc['uploadedAt'] as Timestamp).toDate()
                                          : null;
                                      final uploadedText = uploadedAt != null
                                          ? '${uploadedAt.day}/${uploadedAt.month}/${uploadedAt.year}'
                                          : '';

                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        leading: _documentThumbnail(url),
                                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        subtitle: Text(
                                          [label, uploadedText].where((s) => s?.isNotEmpty == true).join(' • '),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () => _viewDocument(doc),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kPrimaryBlue,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                          child: const Text(
                                            'View',
                                            style: TextStyle(fontSize: 12, color: Colors.white),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
          Icon(active ? Icons.verified : Icons.info_outline, size: 14, color: color),
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
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _documentThumbnail(String url) {
    if (url.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade100),
        child: const Icon(Icons.insert_drive_file, color: Colors.grey, size: 24),
      );
    }

    final isImage = url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.webp') ||
        url.toLowerCase().endsWith('.gif');

    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          color: Colors.grey.shade100,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 24),
          ),
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.blue.shade50),
      child: const Icon(Icons.insert_drive_file, color: kPrimaryBlue, size: 24),
    );
  }
}