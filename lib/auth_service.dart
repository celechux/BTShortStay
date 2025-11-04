// Secure Firebase Auth-based authentication service.
// No password logic or custom hashing here; use FirebaseAuth for all auth!

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  
  UserModel({required this.uid, required this.email, this.displayName});
}

class AuthService {
  // Login with Firebase Auth and fetch user profile from Firestore
  Future<UserModel?> login(String email, String password) async {
    try {
      // Firebase Auth handles password check securely
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = credential.user;
      if (user == null) return null;

      // Fetch profile from Firestore "guests" collection
      final doc = await FirebaseFirestore.instance
          .collection('guests')
          .doc(user.uid)
          .get();

      final profile = doc.data();
      return UserModel(
        uid: user.uid,
        email: user.email ?? "",
        displayName: profile?['guestName'] ?? user.email,
      );
    } catch (e) {
      return null;
    }
  }

  // Logout method - signs out from Firebase Auth
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      throw Exception('Failed to logout: $e');
    }
  }

  // Get current user
  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  // Get current user model with Firestore data
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Fetch profile from Firestore "guests" collection
      final doc = await FirebaseFirestore.instance
          .collection('guests')
          .doc(user.uid)
          .get();

      final profile = doc.data();
      return UserModel(
        uid: user.uid,
        email: user.email ?? "",
        displayName: profile?['guestName'] ?? user.email,
      );
    } catch (e) {
      return null;
    }
  }

  // Register new user with Firebase Auth and create profile in Firestore
  Future<UserModel?> register(String email, String password, String guestName) async {
    try {
      // Create user with Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      final user = credential.user;
      if (user == null) return null;

      // Create user profile in Firestore "guests" collection
      await FirebaseFirestore.instance
          .collection('guests')
          .doc(user.uid)
          .set({
        'guestName': guestName.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return UserModel(
        uid: user.uid,
        email: user.email ?? "",
        displayName: guestName,
      );
    } catch (e) {
      return null;
    }
  }

  // Listen to auth state changes
  Stream<User?> get authStateChanges {
    return FirebaseAuth.instance.authStateChanges();
  }

  // Update user profile in Firestore
  Future<bool> updateProfile(String guestName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection('guests')
          .doc(user.uid)
          .update({
        'guestName': guestName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      return false;
    }
  }
}