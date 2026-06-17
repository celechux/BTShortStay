import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Login user and save FCM token
  Future<UserCredential?> loginUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save FCM token after successful login
      await _saveFCMToken(userCredential.user!.uid);

      return userCredential;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Register new user and save FCM token
  Future<UserCredential?> registerUser({
    required String email,
    required String password,
    required String name,
    required String role, // 'host', 'admin', or 'user'
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get FCM token
      String? token = await _messaging.getToken();

      // Save user data with FCM token to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'name': name,
        'role': role,
        'fcmToken': token,
        'createdAt': FieldValue.serverTimestamp(),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      print('User registered successfully with FCM token: $token');
      return userCredential;
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMToken(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
        print('FCM token saved for user: $userId');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Update FCM token (call this on app startup)
  Future<void> updateFCMToken() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _saveFCMToken(user.uid);
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      // Optional: Clear FCM token on logout
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'lastLogout': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();
      print('User logged out successfully');
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user data
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
      print('User data updated successfully');
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }
}
