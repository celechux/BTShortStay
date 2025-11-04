import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'apartment_form_data.dart';
import 'hostarea.dart'; // Import HostArea

class Step5UploadImages extends StatefulWidget {
  final Function(ApartmentFormData)? onNext;
  final VoidCallback onBack;
  final ApartmentFormData formData;
  final String hostUID;

  const Step5UploadImages({
    super.key,
    this.onNext,
    required this.onBack,
    required this.formData,
    required this.hostUID,
  });

  @override
  State<Step5UploadImages> createState() => _Step5UploadImagesState();
}

class _Step5UploadImagesState extends State<Step5UploadImages> {
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (kDebugMode) {
      print('🔐 Current user: ${user?.uid}');
      print('🔐 User email: ${user?.email}');
      print('🔐 Is anonymous: ${user?.isAnonymous}');
      print('🔐 Auth provider: ${user?.providerData}');
    }
    
    if (user == null && kDebugMode) {
      print('❌ No authenticated user found!');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> selected = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (selected.isNotEmpty) {
        setState(() => _images.addAll(selected));
        if (kDebugMode) {
          print('📸 Selected ${selected.length} images');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error picking images: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting images: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_images.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least 5 images')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to upload images'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (kDebugMode) {
      print('🔐 User authenticated: ${currentUser.uid}');
    }

    setState(() {
      _isSubmitting = true;
      _uploadStatus = 'Starting upload...';
    });

    try {
      final List<String> imageUrls = [];
      if (kDebugMode) {
        print('🚀 Starting upload of ${_images.length} images');
      }

      for (int i = 0; i < _images.length; i++) {
        final image = _images[i];
        setState(() {
          _uploadStatus = 'Uploading image ${i + 1} of ${_images.length}...';
        });

        if (kDebugMode) {
          print('📤 Uploading image ${i + 1}: ${image.name}');
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${currentUser.uid}_${timestamp}_${i}_${image.name.replaceAll(' ', '_')}';
        final ref = FirebaseStorage.instance.ref('apartments/$fileName');

        try {
          UploadTask uploadTask;
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'public,max-age=31536000',
            customMetadata: {
              'uploadedBy': currentUser.uid,
              'uploadedAt': DateTime.now().toIso8601String(),
              'userEmail': currentUser.email ?? 'unknown',
              'apartmentTitle': widget.formData.title ?? 'Unknown',
              'imageIndex': i.toString(),
            },
          );

          if (kIsWeb) {
            final bytes = await image.readAsBytes();
            uploadTask = ref.putData(bytes, metadata);
          } else {
            final file = File(image.path);
            uploadTask = ref.putFile(file, metadata);
          }

          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
            if (mounted) {
              setState(() {
                _uploadStatus = 'Uploading image ${i + 1}: ${progress.toStringAsFixed(1)}%';
              });
            }
          });

          await uploadTask;
          final url = await ref.getDownloadURL();
          imageUrls.add(url);

        } catch (uploadError) {
          String errorMessage = 'Failed to upload image ${i + 1}: ${uploadError.toString()}';
          throw Exception(errorMessage);
        }
      }

      setState(() {
        _uploadStatus = 'Saving apartment data...';
      });

      widget.formData.imageUrls = imageUrls;

      final docRef = FirebaseFirestore.instance.collection('apartments').doc();
      final String apartmentId = docRef.id;

      final apartmentData = {
        'apartmentId': apartmentId,
        'title': widget.formData.title,
        'address': widget.formData.address,
        'bedrooms': widget.formData.bedrooms,
        'beds': widget.formData.beds,
        'bathrooms': widget.formData.bathrooms,
        'kitchens': widget.formData.kitchens,
        'facilities': widget.formData.facilities.toList(),
        'maxGuests': widget.formData.maxGuests,
        'price': widget.formData.price,
        'description': widget.formData.description,
        'imageUrls': imageUrls,
        'hostUID': widget.hostUID,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'status': 'active',
        'verified': false,
        'featured': false,
        'imageCount': imageUrls.length,
      };

      await docRef.set(apartmentData);

      setState(() {
        _uploadStatus = 'Success!';
      });

      if (mounted) {
        await _showSuccessDialog();
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Submission error: $e');
      }
      setState(() {
        _uploadStatus = 'Error occurred';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 50),
              const SizedBox(height: 16),
              const Text(
                "Apartment Successfully Added",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    // Navigate back to HostArea with My Apartments tab (index 1)
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => HostArea(initialTab: 1),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Widget _buildThumbnail(XFile img, int index) {
    return Stack(
      children: [
        FutureBuilder<Uint8List>(
          future: img.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  snapshot.data!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              );
            } else if (snapshot.hasError) {
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 24),
                    Text('Error', style: TextStyle(fontSize: 10, color: Colors.red)),
                  ],
                ),
              );
            } else {
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              );
            }
          },
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Center(
            child: Card(
              elevation: 6,
              margin: const EdgeInsets.all(16),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.lightBlue.withOpacity(0.3),
              child: Container(
                width: constraints.maxWidth > 600 ? 500 : double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Step 5: Upload Apartment Pictures',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        children: [
                          const TextSpan(text: 'At least 5 pictures of your apartment ('),
                          TextSpan(
                            text: '${_images.length}',
                            style: TextStyle(
                              color: _images.length >= 5 ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: ' selected)'),
                        ],
                      ),
                    ),
                    if (_images.length >= 5) ...[
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Minimum requirement met!',
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // Images grid with flexible height
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                        minHeight: 120,
                      ),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (int i = 0; i < _images.length; i++)
                              _buildThumbnail(_images[i], i),
                            GestureDetector(
                              onTap: _isSubmitting ? null : _pickImages,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: _isSubmitting ? Colors.grey[300] : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _isSubmitting ? Colors.grey : Colors.black, 
                                    width: 1.5
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo, 
                                      size: 32, 
                                      color: _isSubmitting ? Colors.grey : Colors.black
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add More',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _isSubmitting ? Colors.grey : Colors.black,
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
                    
                    if (_isSubmitting) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlue),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _uploadStatus,
                        style: const TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    ],
                    const SizedBox(height: 20),
                    
                    // Buttons row with proper spacing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : widget.onBack,
                            icon: const Icon(Icons.arrow_back, color: Colors.black),
                            label: const Text('Back', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              foregroundColor: Colors.black,
                              minimumSize: const Size(100, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _isSubmitting
                              ? Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(child: CircularProgressIndicator()),
                                )
                              : FilledButton.icon(
                                  onPressed: _images.length >= 5 ? _submit : null,
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Submit'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(120, 48),
                                    backgroundColor: _images.length >= 5 ? Colors.lightBlue : Colors.grey,
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Tip text - made more compact
                    Text(
                      'Tip: Upload high-quality images showing different angles of your apartment. The first image will be used as the main cover photo.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    
                    // Debug info - only show in debug mode and make it more compact
                    if (kDebugMode && _images.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Debug: ${_images.length} images, ready: ${_images.length >= 5}',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}