import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'hostarea.dart';
import 'screens/forgot_password.dart';  // Corrected import path

class HostLoginPage extends StatefulWidget {
  const HostLoginPage({super.key});

  @override
  State<HostLoginPage> createState() => _HostLoginPageState();
}

class _HostLoginPageState extends State<HostLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _loginError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) return 'Please enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  /// Setup Paystack recipient with detailed logging
  Future<void> _setupPaystackRecipient(String hostUID) async {
    try {
      print('==========================================');
      print('🔍 STARTING PAYSTACK SETUP');
      print('Host UID: $hostUID');
      print('==========================================');
      
      // Get host document
      final hostDoc = await FirebaseFirestore.instance
          .collection('hosts')
          .doc(hostUID)
          .get();
      
      if (!hostDoc.exists) {
        print('❌ ERROR: Host document does not exist!');
        print('==========================================');
        return;
      }

      final data = hostDoc.data();
      print('✅ Host document found');
      
      // Check bank details
      final bankDetails = data?['bankDetails'];
      if (bankDetails == null) {
        print('❌ ERROR: No bankDetails field found!');
        print('==========================================');
        return;
      }
      
      print('Bank Details:');
      print('  - Bank Name: ${bankDetails['bankName']}');
      print('  - Account Number: ${bankDetails['accountNumber']}');
      print('  - Account Name: ${bankDetails['accountName']}');
      print('  - Recipient Code: ${bankDetails['paystackRecipientCode']}');
      
      final recipientCode = bankDetails['paystackRecipientCode'];
      
      // If already has a recipient code, skip
      if (recipientCode != null && recipientCode.toString().isNotEmpty) {
        print('✅ Already has recipient code: $recipientCode');
        print('Skipping Paystack setup');
        print('==========================================');
        return;
      }

      print('');
      print('🔄 No recipient code found. Calling Cloud Function...');
      print('');

      // Call Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('createPaystackRecipient');
      final result = await callable.call({'hostId': hostUID});
      
      print('==========================================');
      print('✅ CLOUD FUNCTION RESPONSE:');
      print('Success: ${result.data['success']}');
      print('Recipient Code: ${result.data['recipient_code']}');
      print('Message: ${result.data['message']}');
      print('Full Response: ${result.data}');
      print('==========================================');
      
    } on FirebaseFunctionsException catch (e) {
      print('==========================================');
      print('❌ FIREBASE FUNCTIONS ERROR:');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
      print('==========================================');
    } catch (e, stackTrace) {
      print('==========================================');
      print('❌ ERROR IN PAYSTACK SETUP:');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('==========================================');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    try {
      // Sign in with Firebase Auth
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Login failed: No user returned');
      }

      print('✅ User logged in successfully: ${user.uid}');

      // Setup Paystack in background (await it so we can see the logs before navigation)
      await _setupPaystackRecipient(user.uid);

      // Navigate to host dashboard
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HostArea()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed. Please try again.';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many login attempts. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }

      setState(() {
        _loginError = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loginError = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
      print('❌ Login error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.login,
                                size: 48,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Host Login',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to your host dashboard',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          validator: _validateEmail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address *',
                            hintText: 'Enter your email address',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          validator: _validatePassword,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password *',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (_loginError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _loginError!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Login button
                        FilledButton(
                          onPressed: _isLoading ? null : _login,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Text('Logging in...'),
                                  ],
                                )
                              : const Text('Login'),
                        ),
                        const SizedBox(height: 16),

                        // Forgot password link
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: const Text('Forgot Password?'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}