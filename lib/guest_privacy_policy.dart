import 'package:flutter/material.dart';

/// Guest privacy policy page for BT ShortStay.
/// 
/// Usage:
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const GuestPrivacyPolicyPage()),
/// );
class GuestPrivacyPolicyPage extends StatelessWidget {
  const GuestPrivacyPolicyPage({super.key});

  // Keep colors in sync with MyReservationsPage
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _lightBlue = Color(0xFFE3F2FD);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryBlue),
        titleTextStyle: TextStyle(
          color: _primaryBlue,
          fontWeight: FontWeight.w700,
          fontSize: isMobile ? 18 : 20,
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 20),
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: _lightBlue,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: _primaryBlue,
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last Updated: October 2025',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: isMobile ? 12 : 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Welcome to BT ShortStay.\n\n'
                    'Your privacy is important to us. This Privacy Policy explains how we collect, use, and protect your personal information when you use our mobile app, website, and related services (collectively referred to as “the Platform”).\n\n'
                    'By using BT ShortStay, you agree to the practices described in this Privacy Policy.',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _sectionTitle('1. Information We Collect'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'We collect information from you when you use our platform in the following ways:',
                  ),
                  const SizedBox(height: 8),

                  _subSectionTitle('a. Information You Provide Directly'),
                  _sectionBody(
                    '• Account Information: Name, email address, phone number, and password when you register.\n'
                    '• Profile Details: Profile photo, gender, and other optional personal details.\n'
                    '• Booking Information: Dates, property preferences, and guest details for reservations.\n'
                    '• Payment Information: Billing details and bank or card information (processed securely via third-party payment providers such as Paystack).\n'
                    '• Communication: Messages, reviews, or feedback you send through the app.',
                  ),
                  const SizedBox(height: 10),

                  _subSectionTitle('b. Information Collected Automatically'),
                  _sectionBody(
                    '• Device Information: Device model, operating system, app version, and unique device identifiers.\n'
                    '• Usage Data: How you interact with the app, pages viewed, and session duration.\n'
                    '• Location Data: With your consent, we may collect location information to show nearby apartments and improve your experience.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('2. How We Use Your Information'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'We use your personal data to:\n\n'
                    '• Provide, improve, and personalize our services.\n'
                    '• Facilitate apartment listings, bookings, and payments.\n'
                    '• Communicate with you about your account, bookings, or support inquiries.\n'
                    '• Verify user identities and maintain trust between guests and hosts.\n'
                    '• Send promotional offers, updates, or service notifications (you can opt out anytime).\n'
                    '• Comply with legal obligations and prevent fraudulent activities.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('3. How We Share Your Information'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'We do not sell your personal data.\n\n'
                    'However, we may share information in the following situations:\n\n'
                    '• With Hosts/Guests: When you make a booking, relevant information (e.g., name, contact, check-in details) is shared with the other party.\n'
                    '• With Service Providers: Such as payment processors, cloud hosting, and analytics tools who help us operate the platform.\n'
                    '• For Legal Reasons: If required by law, regulation, or government request to protect our rights and users’ safety.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('4. Data Security'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'We use industry-standard security measures (SSL encryption, secure servers, and access controls) to protect your information. However, no online system is 100% secure, so we encourage users to keep login credentials confidential.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('5. Your Rights'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'You have the right to:\n\n'
                    '• Access and review your personal data.\n'
                    '• Update or correct inaccurate information.\n'
                    '• Delete your account or request data deletion.\n'
                    '• Withdraw consent to data processing (where applicable).\n\n'
                    'To exercise these rights, contact us at privacy@btshortstay.com.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('6. Cookies and Tracking Technologies'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'We may use cookies and similar technologies to enhance user experience, remember preferences, and collect usage analytics. You can disable cookies through your device settings, but some features may not function properly.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('7. Data Retention'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'We retain your information only as long as necessary for legitimate business purposes or to comply with legal obligations.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('8. Third-Party Links'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'BT ShortStay may contain links to third-party websites or services. We are not responsible for the privacy practices of such external platforms. Please review their privacy policies separately.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('9. Children’s Privacy'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'Our services are not directed to children under 18. We do not knowingly collect personal information from minors. If you believe a child has provided us their data, please contact us immediately.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('10. Changes to This Policy'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'We may update this Privacy Policy occasionally to reflect changes in our practices. Updates will be posted on our app or website with the revised date. Continued use of BT ShortStay means you accept the updated policy.',
                  ),
                  const SizedBox(height: 14),

                  _sectionTitle('11. Contact Us'),
                  const SizedBox(height: 6),
                  _sectionBody(
                    'If you have any questions or concerns about this Privacy Policy or your data, please contact us at:\n\n'
                    'BT ShortStay\n'
                    'Email: privacy@btshortstay.com\n\n'
                    'Alternate Email: info@btshortstay.com',
                  ),

                  const SizedBox(height: 18),
                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: _primaryBlue,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _subSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.black87,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _sectionBody(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}