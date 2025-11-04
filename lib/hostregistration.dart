import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'dart:math';
import 'hostlogin.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';

class HostRegistrationPage extends StatefulWidget {
  final VoidCallback? onRegistered;
  const HostRegistrationPage({super.key, this.onRegistered});

  @override
  _HostRegistrationPageState createState() => _HostRegistrationPageState();
}

class _HostRegistrationPageState extends State<HostRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Current step tracking
  int _currentStep = 0;

  // Form controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  // Add these for new fields
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  // Bank selection
  String? _selectedBank;

  // Verification document state
  Uint8List? _verificationDocBytes;
  String? _verificationDocName;
  String? _verificationDocType;

  // Form state
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;
  Uint8List? _profileImageBytes;
  String? _profileImageName;

  // Email verification state
  bool _emailVerificationSent = false;
  bool _isEmailVerified = false;
  String? _emailVerificationCodeSent;
  DateTime? _emailVerificationCodeExpiry;
  final _emailVerificationCodeController = TextEditingController();
  bool _isSendingEmail = false;

  // Custom colors for the redesign
  static const Color lightBlue = Color(0xFF2196F3);
  static const Color lightBlueShadow = Color(0x1A2196F3);

  // List of Nigerian banks
  static const List<String> nigerianBanks = [
    'Access Bank',
    'Citibank Nigeria',
    'Ecobank Nigeria',
    'Fidelity Bank',
    'First Bank of Nigeria',
    'First City Monument Bank (FCMB)',
    'Globus Bank',
    'Guaranty Trust Bank (GTBank)',
    'Heritage Bank',
    'Jaiz Bank',
    'Keystone Bank',
    'Polaris Bank',
    'Providus Bank',
    'Stanbic IBTC Bank',
    'Standard Chartered Bank',
    'Sterling Bank',
    'SunTrust Bank',
    'Titan Trust Bank',
    'Union Bank of Nigeria',
    'United Bank for Africa (UBA)',
    'Unity Bank',
    'Wema Bank',
    'Zenith Bank',
  ];

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _scrollController.dispose();
    _emailVerificationCodeController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    if (value == null || value.isEmpty) return 'Full name is required';
    if (value.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) return 'Please enter a valid email address';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    if (!phoneRegex.hasMatch(value)) return 'Please enter a valid phone number';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain uppercase, lowercase, and number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  void _selectProfilePictureWeb() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _profileImageBytes = file.bytes;
          _profileImageName = file.name;
        });
      }
    } catch (e) {
      print('Error picking profile picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _selectVerificationDocWeb(String docType) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _verificationDocBytes = file.bytes;
          _verificationDocName = file.name;
          _verificationDocType = docType;
        });
      }
    } catch (e) {
      print('Error picking verification document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadProfileImage(String authUID) async {
    if (_profileImageBytes == null || _profileImageName == null) return null;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('host_profile_pictures/${authUID}_${DateTime.now().millisecondsSinceEpoch}_$_profileImageName');
      await storageRef.putData(_profileImageBytes!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _uploadVerificationDoc(String authUID) async {
    if (_verificationDocBytes == null || _verificationDocName == null || _verificationDocType == null) return null;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('host_verification_docs/$authUID/$_verificationDocType-${DateTime.now().millisecondsSinceEpoch}_$_verificationDocName');
      await storageRef.putData(_verificationDocBytes!);
      final url = await storageRef.getDownloadURL();
      return {
        'type': _verificationDocType,
        'url': url,
        'name': _verificationDocName,
        'uploadedAt': Timestamp.now(),
      };
    } catch (e) {
      print('Verification doc upload error: $e');
      return null;
    }
  }

  /// UPDATED: send email verification code using Cloud Function
  Future<void> _sendEmailVerificationCode() async {
    // Validate email first
    if (_validateEmail(_emailController.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address first'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSendingEmail = true;
    });

    try {
      // Generate a 6-digit code and set expiry to 10 minutes from now
      final code = (100000 + (Random().nextInt(900000))).toString();
      _emailVerificationCodeSent = code;
      _emailVerificationCodeExpiry = DateTime.now().add(const Duration(minutes: 10));

      // Call the Cloud Function to send email
      final callable = FirebaseFunctions.instance.httpsCallable('sendVerificationCodeEmail');
      final result = await callable.call({
        'email': _emailController.text.trim(),
        'code': code,
      });

      setState(() {
        _emailVerificationSent = true;
        _isSendingEmail = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code sent to ${_emailController.text.trim()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );

      print('✅ Email sent successfully: ${result.data}');
    } catch (e) {
      setState(() {
        _isSendingEmail = false;
      });

      print('❌ Error sending verification email: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send verification email: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Verify email code with expiry
  void _verifyEmailCode() {
    final entered = _emailVerificationCodeController.text.trim();
    if (entered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the verification code"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_emailVerificationCodeSent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please request a verification code first"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_emailVerificationCodeExpiry == null || DateTime.now().isAfter(_emailVerificationCodeExpiry!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verification code expired. Please request a new one."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      // reset state to allow new code
      setState(() {
        _emailVerificationSent = false;
        _emailVerificationCodeSent = null;
        _emailVerificationCodeExpiry = null;
        _emailVerificationCodeController.clear();
      });
      return;
    }

    if (entered == _emailVerificationCodeSent) {
      setState(() {
        _isEmailVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email verified successfully!"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: lightBlue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid verification code. Please try again."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Validate current step before moving to next
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Personal Information
        // First validate the form fields
        if (!_formKey.currentState!.validate()) {
          return false;
        }
        
        // Then check email verification
        if (!_isEmailVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please verify your email address before continuing'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return false;
        }
        return true;
        
      case 1: // Business & Banking
        if (_businessNameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Business name is required'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        if (_selectedBank == null || 
            _accountNumberController.text.isEmpty || 
            _accountNameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill all bank details'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        return true;
        
      case 2: // Verification
        if (_profileImageBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please upload a profile picture'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        if (_verificationDocBytes == null || _verificationDocType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please upload an identity verification document'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        return true;
        
      case 3: // Review & Terms
        if (!_agreeToTerms) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please agree to the Terms and Conditions'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        return true;
        
      default:
        return true;
    }
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      setState(() {
        _currentStep++;
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    setState(() {
      _currentStep--;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1️⃣ Create Firebase Auth user
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      final authUID = userCredential.user!.uid;

      // 2️⃣ Upload profile image and verification document
      String? profileImageUrl;
      Map<String, dynamic>? verificationDoc;

      if (_profileImageBytes != null) {
        profileImageUrl = await _uploadProfileImage(authUID);
      }

      if (_verificationDocBytes != null) {
        verificationDoc = await _uploadVerificationDoc(authUID);
      }

      // 3️⃣ Save host details to Firestore
      await FirebaseFirestore.instance.collection('hosts').doc(authUID).set({
        'hostUID': authUID,
        'authUID': authUID,
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'businessName': _businessNameController.text.trim(),
        'profileImageUrl': profileImageUrl,
        'verificationDocument': verificationDoc,
        'bankDetails': {
          'bankName': _selectedBank,
          'accountNumber': _accountNumberController.text.trim(),
          'accountName': _accountNameController.text.trim(),
          'paystackRecipientCode': null,
        },
        'status': 'pending',
        'emailVerified': _isEmailVerified,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Host registered successfully with UID: $authUID');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Please log in.'),
          backgroundColor: lightBlue,
        ),
      );

      // 4️⃣ Navigate to login page
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HostLoginPage()),
        );
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for this email.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address.';
      } else {
        errorMessage = e.message ?? 'Registration failed';
      }
      
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      print('❌ Error during registration: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Progress Indicator
                _buildProgressIndicator(),
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.black, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: lightBlueShadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildStepContent(),
                              const SizedBox(height: 40),
                              _buildNavigationButtons(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _currentStep ? lightBlue : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildBusinessBankingStep();
      case 2:
        return _buildVerificationStep();
      case 3:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: lightBlue, width: 2),
              ),
              child: const Icon(
                Icons.person_outline,
                size: 48,
                color: lightBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Step 1 of 4',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        // Form Fields
        _buildTextField(
          controller: _fullNameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person_outline,
          validator: _validateFullName,
          textCapitalization: TextCapitalization.words,
          required: true,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your email address',
          icon: Icons.email_outlined,
          validator: _validateEmail,
          keyboardType: TextInputType.emailAddress,
          required: true,
        ),
        const SizedBox(height: 24),
        // Email Verification Section
        if (_emailVerificationSent) ...[
          _buildEmailVerificationSection(),
          const SizedBox(height: 24),
        ] else ...[
          ElevatedButton.icon(
            onPressed: (_emailController.text.isEmpty || _isSendingEmail)
                ? null
                : _sendEmailVerificationCode,
            icon: _isSendingEmail
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: lightBlue,
                    ),
                  )
                : const Icon(Icons.mark_email_read_outlined),
            label: Text(_isSendingEmail ? 'Sending...' : 'Send Verification Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: lightBlue.withOpacity(0.1),
              foregroundColor: lightBlue,
              side: const BorderSide(color: lightBlue),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 24),
        ],
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          icon: Icons.phone_outlined,
          validator: _validatePhone,
          keyboardType: TextInputType.phone,
          required: true,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Create a strong password',
          icon: Icons.lock_outline,
          validator: _validatePassword,
          obscureText: _obscurePassword,
          required: true,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: lightBlue,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Re-enter your password',
          icon: Icons.lock_outline,
          validator: _validateConfirmPassword,
          obscureText: _obscureConfirmPassword,
          required: true,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: lightBlue,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
        ),
        // Address fields
        const SizedBox(height: 24),
        _buildTextField(
          controller: _addressController,
          label: 'Address',
          hint: 'Enter your address',
          icon: Icons.home_outlined,
          required: true,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _cityController,
          label: 'City',
          hint: 'Enter your city',
          icon: Icons.location_city_outlined,
          required: true,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _stateController,
          label: 'State',
          hint: 'Enter your state',
          icon: Icons.map_outlined,
          required: true,
        ),
      ],
    );
  }

  Widget _buildBusinessBankingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: lightBlue, width: 2),
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 48,
                color: lightBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Business & Banking',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Step 2 of 4',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        // Form Fields
        _buildTextField(
          controller: _businessNameController,
          label: 'Business Name',
          hint: 'Enter your business name',
          icon: Icons.business_outlined,
          textCapitalization: TextCapitalization.words,
          required: true,
        ),
        const SizedBox(height: 32),
        const Text(
          'Bank Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'For receiving payments from bookings',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 24),
        // Bank Name Dropdown
        Container(
          decoration: BoxShadow(
            color: lightBlueShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ).toBoxDecoration(),
          child: DropdownButtonFormField<String>(
            value: _selectedBank,
            decoration: const InputDecoration(
              labelText: 'Bank Name *',
              hintText: 'Select your bank',
              prefixIcon: Icon(Icons.account_balance_outlined, color: lightBlue),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: lightBlue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
              ),
              filled: true,
              fillColor: Colors.white,
              labelStyle: TextStyle(color: Colors.black54),
              hintStyle: TextStyle(color: Colors.black38),
            ),
            items: nigerianBanks.map((String bank) {
              return DropdownMenuItem<String>(
                value: bank,
                child: Text(bank),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedBank = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a bank';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _accountNumberController,
          label: 'Account Number',
          hint: 'Enter 10-digit account number',
          icon: Icons.confirmation_number_outlined,
          keyboardType: TextInputType.number,
          required: true,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _accountNameController,
          label: 'Account Name',
          hint: 'Enter the account name',
          icon: Icons.person_outline,
          required: true,
        ),
      ],
    );
  }

  Widget _buildVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: lightBlue, width: 2),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 48,
                color: lightBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Verification',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Step 3 of 4',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        // Profile Picture Section
        const Text(
          'Profile Picture',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _selectProfilePictureWeb,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: lightBlueShadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _profileImageBytes != null
                  ? ClipOval(
                      child: Image.memory(
                        _profileImageBytes!,
                        fit: BoxFit.cover,
                        width: 150,
                        height: 150,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 40,
                          color: lightBlue,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add Photo',
                          style: TextStyle(
                            color: lightBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        // Verification Document Section
        _buildVerificationDocSection(),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: lightBlue, width: 2),
              ),
              child: const Icon(
                Icons.checklist_outlined,
                size: 48,
                color: lightBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Review & Submit',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Step 4 of 4',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        // Review Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registration Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              _buildSummaryRow(Icons.person_outline, 'Name', _fullNameController.text),
              _buildSummaryRow(Icons.email_outlined, 'Email', _emailController.text),
              _buildSummaryRow(Icons.phone_outlined, 'Phone', _phoneController.text),
              _buildSummaryRow(Icons.home_outlined, 'Address', _addressController.text),
              _buildSummaryRow(Icons.location_city_outlined, 'City', _cityController.text),
              _buildSummaryRow(Icons.map_outlined, 'State', _stateController.text),
              _buildSummaryRow(Icons.business_outlined, 'Business', _businessNameController.text),
              _buildSummaryRow(Icons.account_balance_outlined, 'Bank', _selectedBank ?? 'Not selected'),
              _buildSummaryRow(Icons.confirmation_number_outlined, 'Account', _accountNumberController.text),
              _buildSummaryRow(Icons.check_circle_outline, 'Email Verified', _isEmailVerified ? 'Yes' : 'No'),
              _buildSummaryRow(Icons.image_outlined, 'Profile Picture', _profileImageBytes != null ? 'Uploaded' : 'Not uploaded'),
              _buildSummaryRow(Icons.verified_user_outlined, 'ID Document', _verificationDocBytes != null ? 'Uploaded' : 'Not uploaded'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Terms and Conditions
        _buildTermsSection(),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: lightBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        if (_currentStep == 3)
          ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: lightBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text('Creating Account...'),
                    ],
                  )
                : const Text('Create Host Account'),
          )
        else
          ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: lightBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text('Continue'),
          ),
        const SizedBox(height: 16),
        if (_currentStep > 0)
          OutlinedButton(
            onPressed: _previousStep,
            style: OutlinedButton.styleFrom(
              foregroundColor: lightBlue,
              side: const BorderSide(color: lightBlue),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Back'),
          )
        else
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HostLoginPage()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: lightBlue,
            ),
            child: const Text('Already have an account? Sign in'),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    bool required = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxShadow(
        color: lightBlueShadow,
        blurRadius: 4,
        offset: const Offset(0, 2),
      ).toBoxDecoration(),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: Icon(icon, color: lightBlue),
          suffixIcon: suffixIcon,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: lightBlue, width: 2),
          ),
          errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red),
          ),
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Colors.black54),
          hintStyle: const TextStyle(color: Colors.black38),
        ),
      ),
    );
  }

  Widget _buildEmailVerificationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: [
          BoxShadow(
            color: lightBlueShadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  color: lightBlue,
                ),
                SizedBox(width: 8),
                Text(
                  'Email Verification',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailVerificationCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Verification Code',
                      hintText: 'Enter 6-digit code',
                      prefixIcon: Icon(Icons.security_outlined, color: lightBlue),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: lightBlue, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _verifyEmailCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Verify'),
                ),
              ],
            ),
            if (_isEmailVerified) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: lightBlue,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Email verified successfully!',
                    style: TextStyle(
                      color: lightBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ] else if (_emailVerificationSent && _emailVerificationCodeExpiry != null) ...[
              const SizedBox(height: 12),
              Text(
                'A code was sent to ${_emailController.text.trim()}. It will expire in 10 minutes.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isSendingEmail ? null : _sendEmailVerificationCode,
                icon: _isSendingEmail
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: lightBlue,
                        ),
                      )
                    : const Icon(Icons.refresh_outlined, size: 18),
                label: Text(_isSendingEmail ? 'Resending...' : 'Resend Code'),
                style: TextButton.styleFrom(
                  foregroundColor: lightBlue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationDocSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: [
          BoxShadow(
            color: lightBlueShadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: lightBlue,
                ),
                SizedBox(width: 8),
                Text(
                  'Identity Verification *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload an official document for verification',
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxShadow(
                      color: lightBlueShadow,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ).toBoxDecoration(),
                    child: DropdownButtonFormField<String>(
                      value: _verificationDocType,
                      decoration: const InputDecoration(
                        labelText: 'Document Type',
                        prefixIcon: Icon(Icons.description_outlined, color: lightBlue),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: lightBlue, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'id', child: Text('Government ID')),
                        DropdownMenuItem(value: 'passport', child: Text('Passport')),
                        DropdownMenuItem(value: 'certificate', child: Text('Business Certificate')),
                        DropdownMenuItem(value: 'other', child: Text('Other Document')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _verificationDocType = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _verificationDocType == null 
                      ? null 
                      : () => _selectVerificationDocWeb(_verificationDocType!),
                  icon: Icon(_verificationDocBytes == null 
                      ? Icons.upload_file_outlined 
                      : Icons.check_circle_outline),
                  label: Text(_verificationDocBytes == null ? 'Upload' : 'Selected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightBlue.withOpacity(0.1),
                    foregroundColor: lightBlue,
                    side: const BorderSide(color: lightBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            if (_verificationDocBytes != null && _verificationDocName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lightBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: lightBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.attach_file_outlined,
                      size: 20,
                      color: lightBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _verificationDocName!,
                        style: const TextStyle(
                          color: lightBlue,
                          fontWeight: FontWeight.w500,
                        ),
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

  Widget _buildTermsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreeToTerms,
          onChanged: (value) {
            setState(() {
              _agreeToTerms = value ?? false;
            });
          },
          activeColor: lightBlue,
          checkColor: Colors.white,
          side: const BorderSide(color: Colors.black),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  WidgetSpan(
                    child: InkWell(
                      onTap: () => _showTermsDialog(context),
                      child: const Text(
                        'Terms and Conditions',
                        style: TextStyle(
                          color: lightBlue,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  WidgetSpan(
                    child: InkWell(
                      onTap: () => _showPrivacyPolicyDialog(context),
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: lightBlue,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: lightBlue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Service Agreement / Terms and Conditions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTermsContent(),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: lightBlue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPrivacyPolicyContent(),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BT Short Stay – Service Agreement / Contract',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Company Name: BT Short Stay',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        const Text(
          'Website: www.btshortstay.com',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Introduction'),
        _buildSectionText(
          'This Service Agreement ("Agreement") is made between BT Short Stay ("Company") and the Property Owner/Host ("Host") for the purpose of listing, marketing, and managing bookings for short-stay apartment rentals through the BT Short Stay platform.',
        ),
        _buildSectionTitle('1. Scope of Services'),
        _buildSectionText('BT Short Stay agrees to:'),
        _buildBulletPoint('List the Host\'s property on btshortstay.com and other promotional platforms.'),
        _buildBulletPoint('Market the property to potential guests.'),
        _buildBulletPoint('Manage bookings, guest communication, and payment collection.'),
        _buildSectionTitle('2. Commission and Revenue Sharing'),
        _buildSectionText('BT Short Stay charges a service commission on each confirmed booking:'),
        _buildBulletPoint('Host\'s Share: 95% of the total booking fee'),
        _buildBulletPoint('BT Short Stay\'s Commission: 5% of the total booking fee'),
        _buildSectionText('Commissions are automatically deducted before payouts to the Host.'),
        _buildSectionTitle('3. Payment Terms'),
        _buildBulletPoint('BT Short Stay will process guest payments and remit the Host\'s share within 24 hours after the guest\'s check-out.'),
        _buildBulletPoint('Payouts will be made via bank electronic transfer or other agreed payment methods.'),
        _buildBulletPoint('A detailed monthly statement of earnings and deductions will be provided to the Host.'),
        _buildSectionTitle('4. Host Responsibilities'),
        _buildSectionText('The Host agrees to:'),
        _buildBulletPoint('Ensure the property is clean, safe, and ready for guest check-in.'),
        _buildBulletPoint('Provide accurate property details, pricing, and availability.'),
        _buildBulletPoint('Maintain utilities, amenities, and security features.'),
        _buildBulletPoint('Handle minor maintenance and repairs promptly.'),
        _buildBulletPoint('Notify BT Short Stay in advance of any unavailability or booking conflicts.'),
        _buildSectionTitle('5. BT Short Stay Responsibilities'),
        _buildSectionText('BT Short Stay agrees to:'),
        _buildBulletPoint('Market and promote the property to potential guests.'),
        _buildBulletPoint('Manage reservations and payment processing.'),
        _buildBulletPoint('Provide 24/7 guest support where applicable.'),
        _buildBulletPoint('Remit payments promptly as per the agreed timeline.'),
        _buildSectionTitle('6. Guest Handling'),
        _buildBulletPoint('Guests are bound by BT Short Stay\'s Guest Agreement and Refund Policy.'),
        _buildBulletPoint('The Host must comply with all rules related to guest conduct, security, and property care.'),
        _buildBulletPoint('Any damages caused by guests will be handled in accordance with the Damage & Liability Policy of the host.'),
        _buildSectionTitle('7. Taxes and Compliance'),
        _buildBulletPoint('Hosts are responsible for complying with local tax laws related to income from property rentals.'),
        _buildBulletPoint('BT Short Stay will provide necessary statements to assist Hosts with tax filing but will not withhold taxes unless required by law.'),
        _buildSectionTitle('8. Dispute Resolution'),
        _buildBulletPoint('In case of disagreements, both parties agree to first attempt informal resolution.'),
        _buildBulletPoint('If unresolved, disputes will be escalated to arbitration or resolved under the laws of the Federal Republic of Nigeria.'),
        _buildSectionTitle('9. Death/Related Hazards'),
        _buildBulletPoint('In any case of death or any occurrence of hazardous events on the guests, BT Short Stay will not be held responsible.'),
        _buildBulletPoint('We shall only available to provide relevant information to the authorities for investigation if the need arises.'),
        _buildSectionTitle('10. Termination of Agreement'),
        _buildSectionText('Either party may terminate this Agreement with 30 days\' written notice.'),
        _buildSectionText('BT Short Stay reserves the right to suspend or delist a property if:'),
        _buildBulletPoint('The Host violates company policies'),
        _buildBulletPoint('Guests consistently report poor experiences'),
        _buildBulletPoint('The Host fails to maintain required quality standards'),
        _buildSectionTitle('11. Confidentiality'),
        _buildBulletPoint('Both parties agree to keep sensitive information (pricing, guest data, revenue details, etc.) confidential and not disclose it to third parties without prior consent.'),
        _buildSectionTitle('12. Entire Agreement'),
        _buildBulletPoint('This Agreement constitutes the entire understanding between BT Short Stay and the Host, superseding any prior agreements or understandings, whether written or oral.'),
        _buildSectionTitle('13. Acceptance'),
        _buildBulletPoint('By agreeing to this, you confirm that you have read, understood, and accepted the terms of this Service Agreement.'),
      ],
    );
  }

  Widget _buildPrivacyPolicyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionText(
          'At BT Short Stay ("we", "our", "us"), accessible at btshortstay.com, we respect your privacy and are committed to protecting your personal information. This Privacy Policy explains how we collect, use, store, and safeguard your data when you use our website, mobile app, and services.',
        ),
        _buildSectionTitle('1. Information We Collect'),
        _buildBulletPoint('Personal Information: Name, email, phone number, payment details, government ID (where applicable).'),
        _buildBulletPoint('Usage Data: IP address, device type, browser, log data, and interactions on our platform.'),
        _buildBulletPoint('Booking Information: Stay preferences, check-in/check-out details, and communication with hosts/guests.'),
        _buildSectionTitle('2. How We Use Your Information'),
        _buildBulletPoint('To provide and manage bookings and reservations.'),
        _buildBulletPoint('To communicate with you (support, updates, confirmations).'),
        _buildBulletPoint('To process payments securely.'),
        _buildBulletPoint('To improve our website, app, and services.'),
        _buildBulletPoint('To comply with legal obligations.'),
        _buildSectionTitle('3. Sharing of Information'),
        _buildSectionText('We do not sell your personal data. We may share information with:'),
        _buildBulletPoint('Hosts and Guests (for booking purposes).'),
        _buildBulletPoint('Payment processors and financial institutions.'),
        _buildBulletPoint('Law enforcement, regulators, or legal processes if required.'),
        _buildSectionTitle('4. Cookies & Tracking'),
        _buildSectionText(
          'Our website may use cookies to enhance your experience, analyze traffic, and personalize services. You can manage or disable cookies in your browser settings.',
        ),
        _buildSectionTitle('5. Data Security'),
        _buildSectionText(
          'We implement reasonable technical and organizational safeguards to protect your information against unauthorized access, alteration, or loss.',
        ),
        _buildSectionTitle('6. Data Retention'),
        _buildSectionText(
          'We retain personal information for as long as necessary to provide our services and comply with legal requirements.',
        ),
        _buildSectionTitle('7. Your Rights'),
        _buildSectionText(
          'You have the right to access, correct, or delete your personal data. You may also request restriction of processing or object to data use in certain cases.',
        ),
        _buildSectionTitle('8. Children\'s Privacy'),
        _buildSectionText(
          'Our services are not directed to anyone under the age of 18. We do not knowingly collect data from children.',
        ),
        _buildSectionTitle('9. Changes to This Policy'),
        _buildSectionText(
          'We may update this Privacy Policy from time to time. Any changes will be posted on btshortstay.com with the updated date.',
        ),
        _buildSectionTitle('10. Contact Us'),
        _buildSectionText('If you have any questions or concerns about this Privacy Policy, contact us at:'),
        _buildBulletPoint('Email: info@btshortstay.com'),
        _buildBulletPoint('Website: btshortstay.com'),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: lightBlue,
        ),
      ),
    );
  }

  Widget _buildSectionText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension BoxShadowExtension on BoxShadow {
  BoxDecoration toBoxDecoration() {
    return BoxDecoration(
      boxShadow: [this],
    );
  }
}