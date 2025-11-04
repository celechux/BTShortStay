import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:intl/intl.dart';
import '../utils/constants.dart';

class MyProfilePage extends StatefulWidget {
  final String? userUid;
  final String fallbackName;
  final bool compact;

  const MyProfilePage({
    super.key,
    required this.userUid,
    required this.fallbackName,
    this.compact = false,
  });

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  Timestamp? _createdAt;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    if (widget.userUid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('guests').doc(widget.userUid).get();

      if (doc.exists) {
        final data = doc.data()!;
        _nameCtrl.text = (data['guestName'] ?? widget.fallbackName).toString();
        _emailCtrl.text = (data['email'] ?? '').toString();
        _phoneCtrl.text = (data['phoneNumber'] ?? '').toString();
        _addressCtrl.text = (data['address'] ?? '').toString();
        _createdAt = data['createdAt'];
        _photoUrl = (data['photoUrl'] ?? '').toString().isEmpty ? null : data['photoUrl'];
      } else {
        _nameCtrl.text = widget.fallbackName;
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      _nameCtrl.text = widget.fallbackName;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || widget.userUid == null) return;
    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('guests').doc(widget.userUid).set({
        'guestName': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'photoUrl': _photoUrl,
        'createdAt': _createdAt ?? FieldValue.serverTimestamp(),
        'isActive': true,
        'emailVerified': false,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully"),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save profile: $e"),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    if (widget.userUid == null) return;

    try {
      setState(() => _uploading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _uploading = false);
        return;
      }

      final file = result.files.single;
      final storageRef = FirebaseStorage.instance.ref().child('guest_profiles/${widget.userUid}.jpg');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception('No bytes available for web upload');
        }
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: file.extension == null ? 'image/jpeg' : 'image/${file.extension}'),
        );
      } else {
        if (file.bytes != null) {
          uploadTask = storageRef.putData(
            file.bytes as Uint8List,
            SettableMetadata(contentType: file.extension == null ? 'image/jpeg' : 'image/${file.extension}'),
          );
        } else if (file.path != null) {
          uploadTask = storageRef.putFile(
            File(file.path!),
            SettableMetadata(contentType: file.extension == null ? 'image/jpeg' : 'image/${file.extension}'),
          );
        } else {
          throw Exception('No file data selected');
        }
      }

      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('guests').doc(widget.userUid).set({'photoUrl': url}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _photoUrl = url;
          _uploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    if (widget.userUid == null) return;
    try {
      final storageRef = FirebaseStorage.instance.ref().child('guest_profiles/${widget.userUid}.jpg');
      await storageRef.delete().catchError((_) {});
      await FirebaseFirestore.instance.collection('guests').doc(widget.userUid).set({'photoUrl': FieldValue.delete()}, SetOptions(merge: true));
      if (mounted) {
        setState(() => _photoUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo: $e'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 60,
      backgroundColor: Colors.white,
      backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
      child: _photoUrl == null
          ? Icon(
              Icons.person_rounded,
              size: 60,
              color: kPrimaryBlue,
            )
          : null,
    );

    final avatarEditButton = Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryBlue,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
        ),
        child: IconButton(
          onPressed: _uploading ? null : _pickAndUploadPhoto,
          icon: _uploading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
      ),
    );

    if (widget.compact) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: kAccentBlue, width: 2),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: kPrimaryBlue,
                      backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty) ? NetworkImage(_photoUrl!) : null,
                      child: (_photoUrl == null || _photoUrl!.isEmpty)
                          ? Text(
                              (_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : widget.fallbackName[0]).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Profile',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 21,
                              color: kPrimaryBlue,
                            ),
                          ),
                          Text(
                            'Manage your account information',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.black54,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: kPrimaryBlue),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Stack(
                                  children: [
                                    avatar,
                                    avatarEditButton,
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              const Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  color: kPrimaryBlue,
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _nameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: const Icon(Icons.person_outline_rounded, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: kTabLightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: const Icon(Icons.email_outlined, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: kTabLightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return null;
                                  final ok = RegExp(r'^.+@.+\..+').hasMatch(v.trim());
                                  return ok ? null : 'Please enter a valid email address';
                                },
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: const Icon(Icons.phone_outlined, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: kTabLightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _addressCtrl,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Address',
                                  prefixIcon: const Icon(Icons.location_on_outlined, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: kTabLightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                ),
                              ),

                              if (_createdAt != null) ...[
                                const SizedBox(height: 24),
                                Card(
                                  elevation: 0,
                                  color: kTabLightBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(color: kAccentBlue, width: 1.2),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.event_rounded,
                                          color: kPrimaryBlue,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Member Since',
                                                style: TextStyle(
                                                  color: kPrimaryBlue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('MMMM dd, yyyy').format(_createdAt!.toDate()),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: kPrimaryBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 32),

                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _saveProfile,
                                  icon: _saving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded, color: Colors.white),
                                  label: const Text('Save Changes'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kPrimaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // Full screen version (if compact is false)
    return Scaffold(
      backgroundColor: kTabLightBlue,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: kPrimaryBlue)),
        centerTitle: true,
        backgroundColor: kTabLightBlue,
        elevation: 0,
        actions: [
          FilledButton.icon(
            onPressed: _saving ? null : _saveProfile,
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, color: Colors.white),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: kPrimaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: kTabLightBlue,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: kAccentBlue, width: 1.2)),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    avatar,
                                    avatarEditButton,
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _uploading ? null : _pickAndUploadPhoto,
                                      icon: _uploading
                                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.upload_rounded, color: kPrimaryBlue),
                                      label: const Text('Upload Photo', style: TextStyle(color: kPrimaryBlue)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: kPrimaryBlue, width: 1.2),
                                      ),
                                    ),
                                    if (_photoUrl != null) ...[
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: _removePhoto,
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                        label: const Text('Remove', style: TextStyle(color: Colors.red)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.red, width: 1.2),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: kAccentBlue, width: 1.2)),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Personal Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    color: kPrimaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: const Icon(Icons.person_outline_rounded, color: kPrimaryBlue),
                                    filled: true,
                                    fillColor: kTabLightBlue,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: const Icon(Icons.email_outlined, color: kPrimaryBlue),
                                    filled: true,
                                    fillColor: kTabLightBlue,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return null;
                                    final ok = RegExp(r'^.+@.+\..+').hasMatch(v.trim());
                                    return ok ? null : 'Please enter a valid email address';
                                  },
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    prefixIcon: const Icon(Icons.phone_outlined, color: kPrimaryBlue),
                                    filled: true,
                                    fillColor: kTabLightBlue,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _addressCtrl,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Address',
                                    prefixIcon: const Icon(Icons.location_on_outlined, color: kPrimaryBlue),
                                    filled: true,
                                    fillColor: kTabLightBlue,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                  ),
                                ),

                                if (_createdAt != null) ...[
                                  const SizedBox(height: 24),
                                  Card(
                                    elevation: 0,
                                    color: kTabLightBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(color: kAccentBlue, width: 1.2),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.event_rounded,
                                            color: kPrimaryBlue,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Member Since',
                                                  style: TextStyle(
                                                    color: kPrimaryBlue,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('MMMM dd, yyyy').format(_createdAt!.toDate()),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: kPrimaryBlue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 32),

                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _saving ? null : _saveProfile,
                                    icon: _saving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.check_rounded, color: Colors.white),
                                    label: const Text('Save Changes'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: kPrimaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}