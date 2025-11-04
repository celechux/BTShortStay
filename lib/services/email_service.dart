import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static const String _smtpUsername = 'btshortstay@outlook.com';
  static const String _smtpPassword = 'hfcbotpygtwzegtl'; // <-- Use your App Password here
  static const String _senderName = 'BT Short Stay';
  static const bool _developmentMode = false; // Must be FALSE to send real emails

  // Send verification email
  static Future<bool> sendVerificationEmail({
    required String recipientEmail,
    required String recipientName,
    required String code,
  }) async {
    try {
      if (_developmentMode) {
        print('[DEV MODE] Pretending to send verification email to: $recipientEmail');
        print('[DEV MODE] Code: $code');
        return true;
      }

      final smtpServer = SmtpServer(
        'smtp.office365.com',
        port: 587,
        username: _smtpUsername,
        password: _smtpPassword,
        ssl: false,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      final message = Message()
        ..from = Address(_smtpUsername, _senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Verify Your Email - $_senderName'
        ..html = _buildVerificationEmailTemplate(code, recipientName)
        ..text = _buildVerificationEmailText(code, recipientName);

      final sendReport = await send(message, smtpServer);
      print('✅ Email sent successfully to $recipientEmail');
      print('📦 Send report: $sendReport');
      return true;
    } catch (e, stackTrace) {
      print('❌ Email sending failed for $recipientEmail');
      print('📛 Error: $e');
      print('📌 Stack trace:\n$stackTrace');
      return false;
    }
  }

  // Send welcome email
  static Future<bool> sendWelcomeEmail({
    required String recipientEmail,
    required String recipientName,
  }) async {
    try {
      if (_developmentMode) {
        print('[DEV MODE] Pretending to send welcome email to: $recipientEmail');
        return true;
      }

      final smtpServer = SmtpServer(
        'smtp.office365.com',
        port: 587,
        username: _smtpUsername,
        password: _smtpPassword,
        ssl: false,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      final message = Message()
        ..from = Address(_smtpUsername, _senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Welcome to $_senderName!'
        ..html = _buildWelcomeEmailTemplate(recipientName)
        ..text = _buildWelcomeEmailText(recipientName);

      final sendReport = await send(message, smtpServer);
      print('✅ Welcome email sent successfully to $recipientEmail');
      print('📦 Send report: $sendReport');
      return true;
    } catch (e, stackTrace) {
      print('❌ Welcome email sending failed for $recipientEmail');
      print('📛 Error: $e');
      print('📌 Stack trace:\n$stackTrace');
      return false;
    }
  }

  // Generate random 6-digit code
  static String generateVerificationCode({int length = 6}) {
    final rand = Random();
    return List.generate(length, (_) => rand.nextInt(10)).join();
  }

  // Save code to Firestore
  static Future<void> saveVerificationCodeToFirestore({
    required String email,
    required String code,
  }) async {
    final now = Timestamp.now();
    final expiry = Timestamp.fromDate(now.toDate().add(const Duration(minutes: 10)));

    await FirebaseFirestore.instance.collection('email_verifications').doc(email).set({
      'email': email,
      'code': code,
      'createdAt': now,
      'expiresAt': expiry,
    });
  }

  // Verify submitted code
  static Future<bool> verifyCode({
    required String email,
    required String enteredCode,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('email_verifications')
        .doc(email)
        .get();

    if (!doc.exists) return false;

    final data = doc.data()!;
    final code = data['code'];
    final expiresAt = data['expiresAt'] as Timestamp;

    if (Timestamp.now().compareTo(expiresAt) > 0) {
      print('⏰ Code for $email has expired');
      return false;
    }

    return code == enteredCode;
  }

  // Optional: delete used or expired codes
  static Future<void> deleteVerificationCode(String email) async {
    await FirebaseFirestore.instance.collection('email_verifications').doc(email).delete();
  }

  // Email templates (HTML and plain text)
  static String _buildVerificationEmailTemplate(String code, String name) {
    return '''
      <html>
        <body>
          <h2>Hello $name,</h2>
          <p>Thank you for registering with <strong>$_senderName</strong>.</p>
          <p>Your verification code is:</p>
          <h1 style="color: #007BFF;">$code</h1>
          <p>This code will expire in 10 minutes.</p>
        </body>
      </html>
    ''';
  }

  static String _buildVerificationEmailText(String code, String name) {
    return '''
Hello $name,

Thanks for registering with $_senderName.

Your verification code is: $code

This code will expire in 10 minutes.
''';
  }

  static String _buildWelcomeEmailTemplate(String name) {
    return '''
      <html>
        <body>
          <h2>Welcome, $name!</h2>
          <p>We’re excited to have you at <strong>$_senderName</strong>.</p>
          <p>You can now explore and enjoy our platform.</p>
        </body>
      </html>
    ''';
  }

  static String _buildWelcomeEmailText(String name) {
    return '''
Welcome, $name!

Thank you for joining $_senderName.
We're glad to have you on board.
''';
  }
}
