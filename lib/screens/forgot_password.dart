import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
const ForgotPasswordScreen({super.key});

@override
State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
final TextEditingController emailController = TextEditingController();
bool isLoading = false;

Future<void> sendPasswordReset(String email) async {
try {
setState(() => isLoading = true);
await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Password reset link sent to $email'),
backgroundColor: Colors.green,
),
);
emailController.clear();
} catch (e) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Error: ${e.toString()}'),
backgroundColor: Colors.redAccent,
),
);
} finally {
setState(() => isLoading = false);
}
}

@override
Widget build(BuildContext context) {
final themeColor = const Color(0xFF007BFF); // BT ShortStay blue
return Scaffold(
backgroundColor: Colors.white,
appBar: AppBar(
backgroundColor: themeColor,
title: const Text(
'Forgot Password',
style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
),
elevation: 0,
centerTitle: true,
),
body: Center(
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 24.0),
child: SingleChildScrollView(
child: Column(
children: [
const SizedBox(height: 30),
// Logo section
Image.asset(
'assets/logo.png', // <-- place your BT ShortStay logo here
height: 100,
),
const SizedBox(height: 20),
const Text(
'Reset Your Password',
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.bold,
color: Colors.black87,
),
),
const SizedBox(height: 10),
const Text(
'Enter your registered email below and we’ll send you a link to reset your password.',
textAlign: TextAlign.center,
style: TextStyle(color: Colors.black54, fontSize: 15),
),
const SizedBox(height: 30),
TextField(
controller: emailController,
keyboardType: TextInputType.emailAddress,
decoration: InputDecoration(
labelText: 'Email Address',
prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
),
focusedBorder: OutlineInputBorder(
borderSide: BorderSide(color: themeColor, width: 2),
borderRadius: BorderRadius.circular(12),
),
),
),
const SizedBox(height: 25),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: isLoading
? null
: () {
final email = emailController.text.trim();
if (email.isNotEmpty) {
sendPasswordReset(email);
} else {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Please enter your email'),
backgroundColor: Colors.orange,
),
);
}
},
style: ElevatedButton.styleFrom(
backgroundColor: themeColor,
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),
child: isLoading
? const CircularProgressIndicator(color: Colors.white)
: const Text(
'Send Reset Link',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: Colors.white,
),
),
),
),
const SizedBox(height: 25),
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text(
'Back to Login',
style: TextStyle(color: Colors.black54, fontSize: 15),
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
