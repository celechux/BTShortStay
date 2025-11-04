// Note: Add google_fonts to pubspec.yaml: google_fonts: ^5.0.0
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';

// Added: no external utils required here; blocked periods are parsed from apartment document
import 'login_page.dart';
import 'registration_page.dart';
import 'myreservations.dart';
import 'chat_detail_page.dart'; // Import your chat detail page

// Helper function to generate consistent chat IDs
String getChatId(String userA, String userB) {
  final sorted = [userA, userB]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

class ApartmentDetailsPage extends StatefulWidget {
  final String apartmentId;
  final bool loggedIn;
  final String? userName;
  final VoidCallback onLogout;
  final String? guestUid;

  const ApartmentDetailsPage({
    super.key,
    required this.apartmentId,
    required this.loggedIn,
    required this.userName,
    required this.onLogout,
    this.guestUid,
  });

  @override
  _ApartmentDetailsPageState createState() => _ApartmentDetailsPageState();
}

class _ApartmentDetailsPageState extends State<ApartmentDetailsPage> with WidgetsBindingObserver {
  bool _awaitingPayment = false;
  String? _pendingReservationId;
  String? _pendingPaymentReference;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime? checkInDate;
  DateTime? checkOutDate;

  final Set<DateTime> _reservedDates = {}; // normalized (date-only)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reservationsSub;
  DateTime _focusedDay = DateTime.now();
  final Set<DateTime> _blockedDates = {};

  int get numberOfDays {
    if (checkInDate != null && checkOutDate != null) {
      final diff = checkOutDate!.difference(checkInDate!).inDays;
      return diff > 0 ? diff : 0;
    }
    return 0;
  }

  // Feedback/Complaints box state
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _submittingFeedback = false;

  bool get isMobile {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide < 600;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startReservationsListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reservationsSub?.cancel();
    _feedbackController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startPayment({
    required String reservationId,
    required String email,
    required int amountInKobo,
  }) async {
    final functions = FirebaseFunctions.instance;
    if (reservationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid reservation ID')),
      );
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid email is required for payment')),
      );
      return;
    }
    if (amountInKobo < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid payment amount')),
      );
      return;
    }
    try {
      final HttpsCallable callable = functions.httpsCallable('initializePayment');
      final Map<String, dynamic> paymentData = {
        'email': email.trim().toLowerCase(),
        'amount': amountInKobo,
        'reference': reservationId.trim(),
      };
      final result = await callable.call(paymentData);
      final data = result.data as Map?;
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment initialization failed: no data returned')),
        );
        return;
      }
      final bool success = data['status'] == true || data['status'] == 'true' || data['success'] == true;
      if (!success) {
        final String message = data['message']?.toString() ?? 'Payment initialization failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $message')),
        );
        return;
      }
      final Map<dynamic, dynamic>? paystackData = data['data'] as Map<dynamic, dynamic>?;
      if (paystackData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment initialization failed: malformed response')),
        );
        return;
      }
      final String? authorizationUrl = paystackData['authorization_url'] as String?;
      final String? reference = paystackData['reference'] as String?;

      _pendingReservationId = reservationId;
      _pendingPaymentReference = reference;

      if (reference != null && reference.isNotEmpty) {
        try {
          await _firestore.collection('reservations').doc(reservationId).update({
            'paymentReference': reference,
            'paymentInitAt': FieldValue.serverTimestamp(),
            'paymentStatus': 'initialized',
          });
        } catch (e) {
          debugPrint('Warning: failed to save payment reference to reservation: $e');
        }
      }

      if (authorizationUrl != null && authorizationUrl.isNotEmpty) {
        final uri = Uri.parse(authorizationUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          _awaitingPayment = true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open payment URL')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment initialization did not return a checkout URL')),
        );
      }
    } catch (e, st) {
      String message = 'An unknown error occurred';
      try {
        if (e is FirebaseFunctionsException) {
          message = e.message ?? e.details?.toString() ?? e.code ?? e.toString();
        } else if (e is FirebaseException) {
          message = e.message ?? e.toString();
        } else {
          message = e.toString();
        }
      } catch (_) {
        message = e.toString();
      }
      debugPrint('Start payment error: $message\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $message')),
      );
    }
  }

  Future<void> _verifyAndHandlePayment() async {
    if (_pendingReservationId == null || _pendingPaymentReference == null) {
      return;
    }
    try {
      final functions = FirebaseFunctions.instance;
      final HttpsCallable callable = functions.httpsCallable('verifyPayment');
      final result = await callable.call({
        'reservationId': _pendingReservationId,
        'reference': _pendingPaymentReference,
      });
      final data = result.data as Map?;
      if (data != null && data['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Reservation confirmed.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final message = data?['message'] ?? 'Payment verification failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Payment verification error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment verification failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _pendingReservationId = null;
      _pendingPaymentReference = null;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MyReservationsPage(
              loggedIn: true,
              userName: FirebaseAuth.instance.currentUser?.email ?? "Guest",
              userUid: FirebaseAuth.instance.currentUser?.uid,
              onLogout: () async => await FirebaseAuth.instance.signOut(),
            ),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_awaitingPayment && state == AppLifecycleState.resumed) {
      _awaitingPayment = false;
      _verifyAndHandlePayment();
    }
  }

  void _startReservationsListener() {
    try {
      _reservationsSub = _firestore
          .collection('reservations')
          .where('apartmentId', isEqualTo: widget.apartmentId)
          .snapshots()
          .listen((snap) {
        final newSet = <DateTime>{};
        for (var doc in snap.docs) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();
          if (status == 'cancelled') continue;
          final checkInTs = data['checkIn'] as Timestamp?;
          final checkOutTs = data['checkOut'] as Timestamp?;
          if (checkInTs == null || checkOutTs == null) continue;
          final start = _dateOnly(checkInTs.toDate());
          final end = _dateOnly(checkOutTs.toDate());
          DateTime d = start;
          while (d.isBefore(end)) {
            newSet.add(_dateOnly(d));
            d = d.add(const Duration(days: 1));
          }
        }
        setState(() {
          _reservedDates
            ..clear()
            ..addAll(newSet);
          _focusedDay = _firstAvailableDate();
        });
      });
    } catch (e) {
      debugPrint('Failed to start reservations listener: $e');
    }
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Compute blocked dates set from apartment document blockedPeriods field.
  /// blockedPeriods expected as list of maps with startDate and endDate (Timestamp or ISO string).
  Set<DateTime> _blockedDatesFromApartment(Map<String, dynamic> apartmentData) {
    final Set<DateTime> out = {};
    try {
      final raw = apartmentData['blockedPeriods'];
      if (raw is List) {
        for (var item in raw) {
          if (item == null) continue;
          DateTime? start;
          DateTime? end;
          try {
            final s = item['startDate'];
            final e = item['endDate'];
            if (s is Timestamp) {
              start = DateTime.fromMillisecondsSinceEpoch(s.millisecondsSinceEpoch);
            } else if (s is String) start = DateTime.tryParse(s);
            else if (s is DateTime) start = s;
            if (e is Timestamp) {
              end = DateTime.fromMillisecondsSinceEpoch(e.millisecondsSinceEpoch);
            } else if (e is String) end = DateTime.tryParse(e);
            else if (e is DateTime) end = e;
          } catch (_) {}
          if (start != null && end != null) {
            DateTime d = _dateOnly(start);
            final DateTime endDate = _dateOnly(end);
            while (!d.isAfter(endDate)) {
              out.add(_dateOnly(d));
              d = d.add(const Duration(days: 1));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing blockedPeriods: $e');
    }
    return out;
  }

  /// Check if a date range contains any blocked dates.
  bool _rangeContainsBlocked(DateTime start, DateTime end, Set<DateTime> blockedDates) {
    DateTime d = _dateOnly(start);
    final ex = _dateOnly(end);
    while (d.isBefore(ex)) {
      if (blockedDates.contains(_dateOnly(d))) return true;
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  DateTime _firstAvailableDate() {
    DateTime day = _dateOnly(DateTime.now());
    for (int i = 0; i < 366; i++) {
      final candidate = day.add(Duration(days: i));
      if (!_reservedDates.contains(_dateOnly(candidate))) return candidate;
    }
    return day;
  }

  bool _rangeContainsReserved(DateTime start, DateTime end) {
    DateTime d = _dateOnly(start);
    final ex = _dateOnly(end);
    while (d.isBefore(ex)) {
      if (_reservedDates.contains(_dateOnly(d))) return true;
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Apartment Details',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.loggedIn)
                  _UserPopupMenu(
                    userName: widget.userName ?? "Guest",
                    onLogout: widget.onLogout,
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('apartments').doc(widget.apartmentId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2196F3)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Apartment not found'));
          }
          final apartmentData = snapshot.data!.data() as Map<String, dynamic>;

          final List<String> pictures =
              apartmentData['imageUrls'] != null ? List<String>.from(apartmentData['imageUrls']) : [];
          final title = apartmentData['title'] ?? 'No Title';
          final description = apartmentData['description'] ?? 'No description available';
          final facilities = List<String>.from(apartmentData['facilities'] ?? []);
          final double amount = double.tryParse(apartmentData['price']?.toString() ?? '0') ?? 0;

          if (mobile) {
            // MOBILE VIEW: vertical, full width
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                    child: _FunctionalGallery(images: pictures),
                  ),
                  _buildApartmentInfo(title, description),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Divider(),
                  ),
                  _buildFacilities(facilities),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Divider(),
                  ),
                  // MESSAGE HOST BUTTON (Mobile)
                  if (widget.loggedIn) _buildMessageHostButton(apartmentData),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Divider(),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: _buildReservationBox(apartmentData, amount),
                  ),
                  if (widget.loggedIn)
                    _buildFeedbackBox(context, apartmentData, title),
                  const SizedBox(height: 16),
                ],
              ),
            );
          } else {
            // DESKTOP/TABLET VIEW: original layout
            return SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: _FunctionalGallery(images: pictures),
                        ),
                        _buildApartmentInfo(title, description),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Divider(),
                        ),
                        _buildFacilities(facilities),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Divider(),
                        ),
                        // MESSAGE HOST BUTTON (Desktop)
                        if (widget.loggedIn) _buildMessageHostButton(apartmentData),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Divider(),
                        ),
                        if (widget.loggedIn)
                          _buildFeedbackBox(context, apartmentData, title),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Divider(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 370,
                    margin: const EdgeInsets.all(20),
                    child: _buildReservationBox(apartmentData, amount),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  // NEW: Message Host Button
  // (Replace only the _buildMessageHostButton method in your apartment_details.dart file with this implementation)

Widget _buildMessageHostButton(Map<String, dynamic> apartmentData) {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return const SizedBox.shrink();

  final currentUserId = currentUser.uid;

  // Try multiple possible field names for hostId
  final hostId = apartmentData['hostUID'] ??
      apartmentData['hostuid'] ??
      apartmentData['hostUid'] ??
      apartmentData['host_uid'] ??
      apartmentData['ownerId'] ??
      apartmentData['hostId'] ??
      apartmentData['owner_id'] ??
      '';

  // Don't show button if host is the current user or hostId is missing
  if (hostId.isEmpty || hostId == currentUserId) {
    return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.message, size: 20),
        label: Text(
          'Message Host',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        onPressed: () async {
          // Determine host display name from apartment data (several possible field names)
          String hostName = '';
          try {
            hostName = (apartmentData['hostName'] ??
                    apartmentData['hostDisplayName'] ??
                    apartmentData['ownerName'] ??
                    apartmentData['hostFullName'] ??
                    apartmentData['host_name'] ??
                    '')
                .toString();
          } catch (_) {
            hostName = '';
          }

          // If we still don't have a host name, attempt to fetch from users collection
          if (hostName.isEmpty) {
            try {
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(hostId).get();
              if (userDoc.exists) {
                final udata = userDoc.data();
                if (udata != null) {
                  hostName = (udata['displayName'] ?? udata['name'] ?? udata['fullName'] ?? '').toString();
                }
              }
            } catch (e) {
              debugPrint('Failed to fetch host name: $e');
            }
          }

          // Final fallback
          if (hostName.isEmpty) hostName = 'Host';

          final chatId = getChatId(currentUserId, hostId);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailPage(
                chatId: chatId,
                otherUserId: hostId,
                otherUserName: hostName, // <-- required parameter fixed
                apartmentId: widget.apartmentId,
              ),
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildApartmentInfo(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Description', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(description, style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildFacilities(List<String> facilities) {
    if (facilities.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Facilities', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: facilities
                .map(
                  (facility) => Chip(
                    label: Text(facility, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
                    backgroundColor: const Color(0xFF2196F3),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBox(BuildContext context, Map<String, dynamic> apartmentData, String apartmentTitle) {
    final user = FirebaseAuth.instance.currentUser;
    final guestEmail = user?.email ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback / Complaints',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _feedbackController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Your message',
                  labelStyle: GoogleFonts.poppins(),
                  border: const OutlineInputBorder(),
                  hintText: 'Enter feedback or complaint...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: GoogleFonts.poppins(),
                  hintText: 'Enter your phone number',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: _submittingFeedback
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Submit', style: GoogleFonts.poppins(color: Colors.white)),
                  onPressed: _submittingFeedback
                      ? null
                      : () async {
                          final message = _feedbackController.text.trim();
                          final phone = _phoneController.text.trim();
                          if (message.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a message')),
                            );
                            return;
                          }
                          if (guestEmail.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not determine your email')),
                            );
                            return;
                          }
                          setState(() => _submittingFeedback = true);
                          try {
                            await _firestore.collection('feedback').add({
                              'apartmentId': widget.apartmentId,
                              'apartmentTitle': apartmentTitle,
                              'guestEmail': guestEmail,
                              'phoneNumber': phone,
                              'message': message,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            _feedbackController.clear();
                            _phoneController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Feedback submitted. Thank you!'), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error submitting feedback: $e'), backgroundColor: Colors.red),
                            );
                          } finally {
                            setState(() => _submittingFeedback = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // COLLAPSIBLE RESERVATION BOX
  Widget _buildReservationBox(Map<String, dynamic> apartmentData, double amount) {
    // Compute blocked dates for this apartment from apartmentData
    final Set<DateTime> blockedDatesLocal = _blockedDatesFromApartment(apartmentData);

    final formatCurrency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final total = numberOfDays > 0 ? amount * numberOfDays : amount;
    final selectedRangeText = (checkInDate != null && checkOutDate != null)
        ? '${DateFormat('dd MMM yyyy').format(checkInDate!)} → ${DateFormat('dd MMM yyyy').format(checkOutDate!)}'
        : (checkInDate != null ? 'Start: ${DateFormat('dd MMM yyyy').format(checkInDate!)}' : 'Select dates');

    // Expansion state
    bool showCheckInCalendar = false;
    bool showCheckOutCalendar = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${formatCurrency.format(amount)} / night', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              Text(selectedRangeText, style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 8),

              // Collapsible Check-in section
              GestureDetector(
                onTap: () => setModalState(() {
                  showCheckInCalendar = !showCheckInCalendar;
                  showCheckOutCalendar = false;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          checkInDate != null
                              ? 'Check-in: ${DateFormat('EEE, dd MMM yyyy').format(checkInDate!)}'
                              : 'Select check-in date',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(showCheckInCalendar ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
              if (showCheckInCalendar)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TableCalendar(
                    firstDay: DateTime.now(),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: checkInDate ?? _focusedDay,
                    selectedDayPredicate: (day) => checkInDate != null && isSameDay(day, checkInDate),
                    calendarFormat: CalendarFormat.month,
                    enabledDayPredicate: (day) {
                      final date = _dateOnly(day);
                      return !(_reservedDates.contains(date) || blockedDatesLocal.contains(date));
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setModalState(() {
                        if (_reservedDates.contains(_dateOnly(selectedDay)) || blockedDatesLocal.contains(_dateOnly(selectedDay))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('This date is not available')),
                          );
                          return;
                        }
                        setState(() {
                          checkInDate = _dateOnly(selectedDay);
                          if (checkOutDate != null && checkOutDate!.isBefore(checkInDate!)) {
                            checkOutDate = null;
                          }
                        });
                        showCheckInCalendar = false;
                      });
                    },
                    headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                    calendarStyle: CalendarStyle(
                      disabledTextStyle: TextStyle(color: Colors.grey.shade400),
                      todayDecoration: BoxDecoration(
                        border: Border.all(color: Colors.lightBlue),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        shape: BoxShape.circle,
                      ),
                      disabledDecoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Collapsible Check-out section
              GestureDetector(
                onTap: () => setModalState(() {
                  showCheckOutCalendar = !showCheckOutCalendar;
                  showCheckInCalendar = false;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          checkOutDate != null
                              ? 'Check-out: ${DateFormat('EEE, dd MMM yyyy').format(checkOutDate!)}'
                              : 'Select check-out date',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(showCheckOutCalendar ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
              if (showCheckOutCalendar)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TableCalendar(
                    firstDay: checkInDate ?? DateTime.now(),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: checkOutDate ?? (checkInDate ?? _focusedDay),
                    selectedDayPredicate: (day) => checkOutDate != null && isSameDay(day, checkOutDate),
                    calendarFormat: CalendarFormat.month,
                    enabledDayPredicate: (day) {
                      if (checkInDate == null) return false;
                      if (day.isBefore(checkInDate!)) return false;
                      final date = _dateOnly(day);
                      if (_reservedDates.contains(date) || blockedDatesLocal.contains(date)) return false;
                      return true;
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setModalState(() {
                        if (checkInDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select check-in date first')),
                          );
                          return;
                        }
                        if (selectedDay.isBefore(checkInDate!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Check-out must be after check-in')),
                          );
                          return;
                        }
                        if (_reservedDates.contains(_dateOnly(selectedDay)) || blockedDatesLocal.contains(_dateOnly(selectedDay))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('This date is not available')),
                          );
                          return;
                        }
                        if (_rangeContainsReserved(checkInDate!, selectedDay) || _rangeContainsBlocked(checkInDate!, selectedDay, blockedDatesLocal)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Selected range includes unavailable or blocked dates. Choose another range.')),
                          );
                          setState(() {
                            checkOutDate = null;
                          });
                          return;
                        }
                        setState(() {
                          checkOutDate = _dateOnly(selectedDay);
                        });
                        showCheckOutCalendar = false;
                      });
                    },
                    headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                    calendarStyle: CalendarStyle(
                      disabledTextStyle: TextStyle(color: Colors.grey.shade400),
                      todayDecoration: BoxDecoration(
                        border: Border.all(color: Colors.lightBlue),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        shape: BoxShape.circle,
                      ),
                      disabledDecoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              if (numberOfDays > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('₦${amount.toStringAsFixed(0)} x $numberOfDays nights',
                        style: GoogleFonts.poppins(color: Colors.grey)),
                    Text('₦${total.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    Text('₦${total.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleReservation(apartmentData, amount),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Reserve Now', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleReservation(Map<String, dynamic> apartmentData, double amount) async {
    if (!widget.loggedIn) {
      _showSignInDialog();
      return;
    }
    if (checkInDate == null || checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select check-in and check-out dates')),
      );
      return;
    }
    final blockedForThis = _blockedDatesFromApartment(apartmentData);
    if (_rangeContainsReserved(checkInDate!, checkOutDate!) || _rangeContainsBlocked(checkInDate!, checkOutDate!, blockedForThis)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected dates include unavailable or blocked nights. Please choose another range.')),
      );
      return;
    }
    await _reserveApartment(apartmentData, amount);
  }

  void _showSignInDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text('You need to sign in or create an account to make a reservation.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegistrationPage()),
                );
              },
              child: const Text('Sign Up'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
              ),
              child: const Text('Sign In', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reserveApartment(Map<String, dynamic> apartmentData, double amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to reserve')),
      );
      return;
    }
    if (checkInDate == null || checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select check-in and check-out dates')),
      );
      return;
    }

    final total = numberOfDays > 0 ? amount * numberOfDays : amount;

    List<String> imageUrls = [];
    if (apartmentData['imageUrls'] != null) {
      imageUrls = List<String>.from(apartmentData['imageUrls']);
    }
    final apartmentImage = imageUrls.isNotEmpty ? imageUrls.first : '';

    final hostUid = apartmentData['hostUID'] ??
        apartmentData['hostuid'] ??
        apartmentData['hostUid'] ??
        apartmentData['host_uid'] ??
        apartmentData['ownerId'] ??
        apartmentData['hostId'] ??
        apartmentData['owner_id'] ??
        '';

    final reservationRef = _firestore.collection('reservations').doc();

    try {
      await reservationRef.set({
        'reservationId': reservationRef.id,
        'apartmentId': widget.apartmentId,
        'apartmentTitle': apartmentData['title'] ?? 'No Title',
        'apartmentImage': apartmentImage,
        'hostUID': hostUid,
        'authUID': hostUid,
        'guestUid': user.uid,
        'guestName': user.displayName ?? user.email ?? 'User',
        'guestEmail': user.email ?? '',
        'checkIn': Timestamp.fromDate(checkInDate!),
        'checkOut': Timestamp.fromDate(checkOutDate!),
        'numberOfNights': numberOfDays,
        'price': amount,
        'total': total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'paymentStatus': 'pending',
        'paymentMethod': '',
        'paymentReference': '',
        'paymentTimestamp': null,
      });

      // Show modern confirmation dialog (replaces the earlier AlertDialog)
      await _showReservationDialog(reservationRef.id, total, user.email ?? '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation created successfully! Total: ₦${total.toStringAsFixed(0)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReservationDialog(String reservationId, double total, String email) async {
    // Format date strings
    final checkInStr = checkInDate != null ? DateFormat('EEE, dd MMM yyyy').format(checkInDate!) : '-';
    final checkOutStr = checkOutDate != null ? DateFormat('EEE, dd MMM yyyy').format(checkOutDate!) : '-';

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F5FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.check, color: Color(0xFF0876D6), size: 38),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Reservation Created',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please complete payment to confirm your reservation. Note that reservation will be cancelled if payment is not made after 24hours',
                    style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.black54, height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dates', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text('$checkInStr → $checkOutStr', style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Nights', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('$numberOfDays', style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('Total', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('₦${total.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            if (total <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid payment amount')),
                              );
                              return;
                            }
                            final int amountInKobo = (total * 100).round();
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Email is required for payment')),
                              );
                              return;
                            }
                            if (amountInKobo < 100) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Minimum payment amount is ₦1')),
                              );
                              return;
                            }
                            await _startPayment(
                              reservationId: reservationId,
                              email: email,
                              amountInKobo: amountInKobo,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0876D6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Pay Now', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('You can pay later from your account.'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Pay Later', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Close', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserPopupMenu extends StatelessWidget {
  final String userName;
  final VoidCallback onLogout;

  const _UserPopupMenu({
    required this.userName,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: "User menu",
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF2196F3),
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, color: Colors.black54, size: 20),
        ],
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 1,
          child: ListTile(
            leading: const Icon(Icons.account_circle, color: Color(0xFF2196F3)),
            title: const Text('My Profile'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Go to My Profile (implement page)')),
              );
            },
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: Color(0xFF2196F3)),
            title: const Text('My Reservations'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyReservationsPage(
                    loggedIn: true,
                    userName: userName,
                    userUid: FirebaseAuth.instance.currentUser?.uid,
                    onLogout: onLogout,
                  ),
                ),
              );
            },
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 3,
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Log out'),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
        ),
      ],
    );
  }
}

class _FunctionalGallery extends StatefulWidget {
  final List<String> images;
  const _FunctionalGallery({required this.images});

  @override
  State<_FunctionalGallery> createState() => _FunctionalGalleryState();
}

class _FunctionalGalleryState extends State<_FunctionalGallery> with WidgetsBindingObserver {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void _openFullscreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          images: widget.images,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () => _openFullscreen(_currentIndex),
              child: SizedBox(
                height: 320,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.images[index],
                      width: double.infinity,
                      height: 320,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 320,
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 320,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CircleButton(
                    icon: Icons.chevron_left,
                    onTap: () {
                      if (_currentIndex > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    size: 28,
                    padding: const EdgeInsets.all(6),
                    backgroundColor: Colors.black.withOpacity(0.6),
                    iconColor: Colors.white,
                  ),
                ),
              ),
            if (widget.images.length > 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CircleButton(
                    icon: Icons.chevron_right,
                    onTap: () {
                      if (_currentIndex < widget.images.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    size: 28,
                    padding: const EdgeInsets.all(6),
                    backgroundColor: Colors.black.withOpacity(0.6),
                    iconColor: Colors.white,
                  ),
                ),
              ),
            if (widget.images.length > 1)
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.images.length > 1)
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = _currentIndex == index;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 100 : 90,
                    height: selected ? 68 : 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? const Color(0xFF2196F3) : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: [
                        if (selected)
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.12),
                            blurRadius: 8,
                          ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final EdgeInsetsGeometry padding;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
    this.size = 24,
    this.backgroundColor = const Color(0x99000000),
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: size),
      ),
    );
  }
}

class FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullscreenImageViewer({super.key, required this.images, this.initialIndex = 0});

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController controller;
  int current = 0;

  @override
  void initState() {
    super.initState();
    current = widget.initialIndex;
    controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _jumpTo(int index) {
    controller.animateToPage(index, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    setState(() => current = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 28),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: controller,
            onPageChanged: (i) => setState(() => current = i),
            itemCount: widget.images.length,
            itemBuilder: (_, index) => Center(
              child: Stack(
                children: [
                  InteractiveViewer(
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 72, color: Colors.white70),
                    ),
                  ),
                  if (widget.images.length > 1 && index > 0)
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _CircleButton(
                          icon: Icons.chevron_left,
                          onTap: () {
                            if (current > 0) {
                              controller.previousPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          size: 32,
                          padding: const EdgeInsets.all(8),
                          backgroundColor: Colors.black.withOpacity(0.6),
                          iconColor: Colors.white,
                        ),
                      ),
                    ),
                  if (widget.images.length > 1 && index < widget.images.length - 1)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _CircleButton(
                          icon: Icons.chevron_right,
                          onTap: () {
                            if (current < widget.images.length - 1) {
                              controller.nextPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          size: 32,
                          padding: const EdgeInsets.all(8),
                          backgroundColor: Colors.black.withOpacity(0.6),
                          iconColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (index) => GestureDetector(
                  onTap: () => _jumpTo(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: current == index ? const Color(0xFF2196F3) : Colors.white,
                      border: Border.all(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 60,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => _jumpTo(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: current == index ? 70 : 60,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: current == index ? const Color(0xFF2196F3) : Colors.white70,
                          width: current == index ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          if (current == index)
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.18),
                              blurRadius: 8,
                            ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        widget.images[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}