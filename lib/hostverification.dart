import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HostVerificationPage extends StatelessWidget {
  const HostVerificationPage({super.key});

  Future<void> _setVerificationStatus(String hostId, bool isVerified) async {
    await FirebaseFirestore.instance
        .collection('bthosts')
        .doc(hostId)
        .update({'isIdVerified': isVerified});
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black,
                  ),
                  padding: EdgeInsets.all(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.6,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade300,
                        child: Icon(Icons.broken_image, size: 80, color: Colors.grey.shade600),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 34),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Verification'),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bthosts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final hosts = snapshot.data!.docs;
          if (hosts.isEmpty) {
            return const Center(child: Text('No host registrations found.'));
          }
          return ListView.builder(
            itemCount: hosts.length,
            itemBuilder: (context, index) {
              final doc = hosts[index];
              final data = doc.data() as Map<String, dynamic>;
              final profileImageUrl = data['profileImageUrl'] ?? '';
              final verificationDocs = data['verificationDocs'] as List<dynamic>? ?? [];
              final isEmailVerified = data['isEmailVerified'] == true;
              final isIdVerified = data['isIdVerified'] == true;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile row with clickable image for full-size view
                      Row(
                        children: [
                          if (profileImageUrl.isNotEmpty)
                            GestureDetector(
                              onTap: () =>
                                  _showImageDialog(context, profileImageUrl),
                              child: Hero(
                                tag: 'profile_$index',
                                child: CircleAvatar(
                                  backgroundImage: NetworkImage(profileImageUrl),
                                  radius: 32,
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white70,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.all(2),
                                      child: Icon(Icons.zoom_in, size: 16, color: Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const CircleAvatar(
                              radius: 32,
                              child: Icon(Icons.person, size: 32),
                            ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['fullName'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(data['email'] ?? '', style: const TextStyle(fontSize: 16)),
                                Text(data['phone'] ?? '', style: const TextStyle(fontSize: 16)),
                                if (data['businessName'] != null && data['businessName'].toString().isNotEmpty)
                                  Text('Business: ${data['businessName']}', style: const TextStyle(fontSize: 15, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Chip(
                            label: Text(isEmailVerified ? 'Email Verified' : 'Email Not Verified'),
                            backgroundColor: isEmailVerified ? Colors.green.shade100 : Colors.red.shade100,
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(isIdVerified ? 'ID Verified' : 'ID Pending'),
                            backgroundColor: isIdVerified ? Colors.green.shade100 : Colors.orange.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Text('Verification Documents:', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (verificationDocs.isEmpty)
                        const Text('No documents uploaded.', style: TextStyle(color: Colors.red))
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: verificationDocs.map((doc) {
                            String type = doc['type'] ?? 'Unknown';
                            String url = doc['url'] ?? '';
                            String name = doc['name'] ?? '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Text('$type:', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  if (url.isNotEmpty)
                                    InkWell(
                                      onTap: () => _showImageDialog(context, url),
                                      child: Text(
                                        name,
                                        style: const TextStyle(color: Color(0xFF2196F3), decoration: TextDecoration.underline),
                                      ),
                                    )
                                  else
                                    Text('No file', style: const TextStyle(color: Colors.red)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: isIdVerified
                                ? null
                                : () async {
                                    await _setVerificationStatus(doc.id, true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Host marked as ID verified.'), backgroundColor: Colors.green),
                                    );
                                  },
                            icon: const Icon(Icons.check),
                            label: const Text('Approve Verification'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: isIdVerified
                                ? () async {
                                    await _setVerificationStatus(doc.id, false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Host marked as ID pending.'), backgroundColor: Colors.orange),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.cancel),
                            label: const Text('Mark as Pending'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
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
}