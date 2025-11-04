import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  const String smtpUsername = 'btshortstay@outlook.com';
  const String smtpPassword = 'your-app-password-here'; // paste app password here (no spaces)
  const String senderName = 'BT Short Stay';
  const String recipientEmail = 'celelechux@gmail.com'; // or your second email to test

  final smtpServer = SmtpServer(
    'smtp.office365.com',
    port: 587,
    username: smtpUsername,
    password: smtpPassword,
    ssl: false,
  );

  final message = Message()
    ..from = Address(smtpUsername, senderName)
    ..recipients.add(recipientEmail)
    ..subject = 'Test Email from BT Short Stay'
    ..text = 'Hello! This is a test email from your Flutter app using Outlook SMTP.'
    ..html = '''
      <html>
        <body>
          <h2>Hello!</h2>
          <p>This is a test email sent from your <strong>BT Short Stay</strong> app.</p>
          <p>If you're reading this, SMTP is working 🎉</p>
        </body>
      </html>
    ''';

  try {
    final sendReport = await send(message, smtpServer);
    print('✅ Email sent successfully: ${sendReport.toString()}');
  } catch (e) {
    print('❌ Failed to send email: $e');
  }
}
