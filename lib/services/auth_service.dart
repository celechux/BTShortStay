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
  Future<UserCredential?> loginUser(
    String email,
    String password, {
    required String userType, // 'guest' or 'host'
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save FCM token after successful login
      await _saveFCMToken(userCredential.user!.uid, userType);

      return userCredential;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Register guest and save FCM token
  Future<UserCredential?> registerGuest({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final guestUid = userCredential.user!.uid;

      // Get FCM token
      String? token = await _messaging.getToken();

      // Save guest data with FCM token to Firestore
      await _firestore.collection('guests').doc(guestUid).set({
        'guestUid': guestUid,
        'guestName': name,
        'email': email,
        'phoneNumber': phone,
        'fcmToken': token,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': userCredential.user!.emailVerified,
        'isActive': true,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      print('Guest registered successfully with FCM token: $token');
      return userCredential;
    } catch (e) {
      print('Guest registration error: $e');
      rethrow;
    }
  }

  // Register host and save FCM token
  Future<UserCredential?> registerHost({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String businessName,
    required String address,
    required String city,
    required String state,
    String? profileImageUrl,
    Map<String, dynamic>? verificationDocument,
    Map<String, dynamic>? bankDetails,
    String? referral,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final authUID = userCredential.user!.uid;

      // Get FCM token
      String? token = await _messaging.getToken();

      // Save host data with FCM token to Firestore
      await _firestore.collection('hosts').doc(authUID).set({
        'hostUID': authUID,
        'authUID': authUID,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'state': state,
        'businessName': businessName,
        'profileImageUrl': profileImageUrl,
        'verificationDocument': verificationDocument,
        'bankDetails': bankDetails,
        'referral': referral,
        'fcmToken': token,
        'status': 'pending',
        'emailVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      print('Host registered successfully with FCM token: $token');
      return userCredential;
    } catch (e) {
      print('Host registration error: $e');
      rethrow;
    }
  }

  // Save FCM token to the correct collection (guests or hosts)
  Future<void> _saveFCMToken(String userId, String userType) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        final collectionName = userType == 'guest' ? 'guests' : 'hosts';
        
        await _firestore.collection(collectionName).doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
        
        print('FCM token saved for $userType: $userId');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Update FCM token (call this on app startup)
  // You'll need to determine the user type from your current user context
  Future<void> updateFCMToken(String userType) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _saveFCMToken(user.uid, userType);
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Logout user
  Future<void> logout(String userType) async {
    try {
      // Optional: Clear FCM token on logout for privacy
      User? user = _auth.currentUser;
      if (user != null) {
        final collectionName = userType == 'guest' ? 'guests' : 'hosts';
        
        await _firestore.collection(collectionName).doc(user.uid).update({
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

  // Get user data from Firestore (guests or hosts)
  Future<Map<String, dynamic>?> getUserData(String userId, String userType) async {
    try {
      final collectionName = userType == 'guest' ? 'guests' : 'hosts';
      DocumentSnapshot doc =
          await _firestore.collection(collectionName).doc(userId).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user data (guests or hosts)
  Future<void> updateUserData(
    String userId,
    String userType,
    Map<String, dynamic> data,
  ) async {
    try {
      final collectionName = userType == 'guest' ? 'guests' : 'hosts';
      await _firestore.collection(collectionName).doc(userId).update(data);
      print('User data updated successfully');
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }
}
