import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admindashboard_helpers.dart';

// ---------- CHANGE PASSWORD DIALOG ----------
class ChangePasswordDialog extends StatefulWidget {
  final FirebaseAuth auth;
  const ChangePasswordDialog({super.key, required this.auth});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final user = widget.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = "No user logged in.";
          _loading = false;
        });
        return;
      }
      if (_newController.text != _confirmController.text) {
        setState(() {
          _error = "New passwords do not match.";
          _loading = false;
        });
        return;
      }
      final cred = EmailAuthProvider.credential(
        email: user.email ?? "",
        password: _oldController.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newController.text);
      setState(() {
        _loading = false;
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password changed successfully!")),
        );
      }
    } catch (e) {
      setState(() {
        _error = "Failed: ${e.toString()}";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kAccentBlue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: kPrimaryBlue)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _oldController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Old Password",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? "Enter old password" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "New Password",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? "Min 6 characters" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Confirm New Password",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v != _newController.text) ? "Passwords do not match" : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                if (_formKey.currentState?.validate() ?? false) {
                                  await _changePassword();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Change Password", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- HOST DETAILS DIALOG (STUB) ----------
class HostDetailsDialog extends StatelessWidget {
  final String hostId;
  final Map<String, dynamic> hostData;
  final FirebaseFirestore firestore;
  final bool showActions;

  const HostDetailsDialog({
    super.key,
    required this.hostId,
    required this.hostData,
    required this.firestore,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    // For brevity, this is a stub. Use your detailed UI from your original code here.
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kAccentBlue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hostData['fullName'] ?? 'Host', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(hostData['email'] ?? ''),
              // ... Add more details as in your original code ...
              const SizedBox(height: 20),
              Row(
                children: [
                  if (showActions)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await firestore.collection('hosts').doc(hostId).update({'isActive': false});
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('Suspend'),
                      ),
                    ),
                  if (showActions) const SizedBox(width: 10),
                  if (showActions)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await firestore.collection('hosts').doc(hostId).delete();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- APARTMENT DETAILS DIALOG (STUB) ----------
class ApartmentDetailsAdminDialog extends StatelessWidget {
  final String apartmentId;
  final Map<String, dynamic> apartmentData;
  final String reservationStatus;

  const ApartmentDetailsAdminDialog({
    super.key,
    required this.apartmentId,
    required this.apartmentData,
    required this.reservationStatus,
  });

  @override
  Widget build(BuildContext context) {
    // For brevity, this is a stub. Use your detailed UI from your original code here.
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kAccentBlue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(apartmentData['title'] ?? 'Apartment', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(apartmentData['address'] ?? ''),
              // ... Add more details as in your original code ...
              const SizedBox(height: 20),
              Text('Reservation Status: $reservationStatus'),
            ],
          ),
        ),
      ),
    );
  }
}