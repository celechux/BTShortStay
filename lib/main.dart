import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'hostregistration.dart';
import 'hostarea.dart';
import 'apartment_details.dart';
import 'login_page.dart';

import 'my_reservations_page.dart';
import 'utils/date_blocking_utils.dart';
import 'widgets/chat_widget.dart';
import 'about_bt_page.dart';
import 'messages_page.dart';
// <-- ADD THIS LINE

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _loggedIn = false;
  String? _userName;
  String? _userUid;
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _handleLogin(String name, [String? uid]) async {
    final hostDoc = await FirebaseFirestore.instance.collection('hosts').doc(uid).get();
    final userDoc = await FirebaseFirestore.instance.collection('guests').doc(uid).get();
    setState(() {
      _loggedIn = true;
      _userName = name;
      _userUid = uid;
      _isHost = hostDoc.exists;
    });

    if (!hostDoc.exists && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MyReservationsPage(
            loggedIn: true,
            userName: userDoc.exists
                ? (userDoc.data()?['guestName']?.toString() ?? name)
                : name,
            onLogout: _handleLogout,
            userUid: uid,
          ),
        ),
        (route) => false,
      );
    }
  }

  void _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      _loggedIn = false;
      _userName = null;
      _userUid = null;
      _isHost = false;
    });
  }

  void _checkAuthState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final hostDoc = await FirebaseFirestore.instance.collection('hosts').doc(user.uid).get();
      setState(() {
        _loggedIn = true;
        _userName = user.email ?? "User";
        _userUid = user.uid;
        _isHost = hostDoc.exists;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BT ShortStay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          primary: Colors.lightBlue,
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          headerBackgroundColor: Colors.lightBlue,
          headerForegroundColor: Colors.white,
          dayStyle: const TextStyle(color: Colors.black87),
          yearStyle: const TextStyle(color: Colors.black87),
          dayOverlayColor: WidgetStateProperty.all(Colors.lightBlue.withOpacity(0.1)),
          todayBackgroundColor: WidgetStateProperty.all(Colors.lightBlue.withOpacity(0.3)),
          rangeSelectionBackgroundColor: Colors.lightBlue.withOpacity(0.2),
        ),
      ),
      home: _isHost
          ? const HostArea()
          : HomePage(
              loggedIn: _loggedIn,
              userName: _userName,
              onLogout: _handleLogout,
              onLogin: _handleLogin,
              userUid: _userUid,
            ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool loggedIn;
  final String? userName;
  final String? userUid;
  final VoidCallback onLogout;
  final void Function(String userName, [String? uid]) onLogin;

  const HomePage({
    super.key,
    required this.loggedIn,
    required this.userName,
    required this.onLogout,
    required this.onLogin,
    required this.userUid,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? checkInDate;
  DateTime? checkOutDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _locationController = TextEditingController();
  String _searchLocation = "";

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedBottomIndex = 0;
  String _selectedTab = 'Home';
  String? _actualGuestName;

  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _lightBlue = Color(0xFFE3F2FD);
  static const Color _darkBlue = Color(0xFF1976D2);

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Home', 'icon': Icons.home_rounded},
    {'label': 'My Profile', 'icon': Icons.person_rounded},
    {'label': 'My Bookings', 'icon': Icons.calendar_today_rounded},
    {'label': 'Report an Issue', 'icon': Icons.report_problem_rounded},
    {'label': 'About BT', 'icon': Icons.info_rounded},
    {'label': 'Help', 'icon': Icons.help_rounded},
    {'label': 'FAQ', 'icon': Icons.question_answer_rounded},
    {'label': 'Privacy Policy', 'icon': Icons.privacy_tip_rounded},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.loggedIn) {
      _fetchGuestName();
    }
  }

  Future<void> _fetchGuestName() async {
    if (widget.userUid == null) return;
    try {
      final doc = await _firestore.collection('guests').doc(widget.userUid).get();
      if (doc.exists && mounted) {
        setState(() {
          _actualGuestName = doc.data()?['guestName']?.toString() ?? widget.userName;
        });
      }
    } catch (e) {
      debugPrint('Error fetching guest name: $e');
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getApartmentStream() {
    return _firestore
        .collection('apartments')
        .orderBy('createdAt', descending: true)
        .limit(15)
        .snapshots();
  }

  void _performSearch() {
    setState(() {
      _searchLocation = _locationController.text.trim();
    });
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedBottomIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomePage(
              loggedIn: widget.loggedIn,
              userName: widget.userName,
              onLogout: widget.onLogout,
              onLogin: widget.onLogin,
              userUid: widget.userUid,
            ),
          ),
          (route) => false,
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyReservationsPage(
              loggedIn: true,
              userName: widget.userName ?? '',
              onLogout: widget.onLogout,
              userUid: widget.userUid,
            ),
          ),
        );
        break;
      case 2:
        // Navigate to MessagesPage (MessagesPage uses FirebaseAuth internally, so no params required)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessagesPage(),
          ),
        );
        break;
      case 3:
        setState(() {
          _selectedTab = 'Help';
        });
        _scaffoldKey.currentState?.openDrawer();
        break;
      case 4:
        widget.onLogout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MyApp()),
          (route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = _isMobile(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: widget.loggedIn ? _buildLeftDrawer(isMobile) : (isMobile ? _buildDrawer(context) : null),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.lightBlue, Colors.blue],
                    ),
                  ),
                  child: _buildBookingComStyleAppBar(isMobile),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              SliverPadding(padding: const EdgeInsets.all(20), sliver: _buildApartmentGrid()),
              SliverToBoxAdapter(child: _buildFooter()),
              if (isMobile)
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          if (!isMobile) const ChatWidget(),
        ],
      ),
      bottomNavigationBar: (isMobile && widget.loggedIn) ? _buildBottomNavBar() : null,
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: _lightBlue,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedBottomIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: _lightBlue,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: Colors.blue.shade700,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_rounded),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_rounded),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_rounded),
            label: 'Help',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout_rounded),
            label: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildLeftDrawer(bool isMobile) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isMobile ? 40 : 50,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryBlue, _darkBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: isMobile ? 32 : 36,
                  child: Text(
                    (_actualGuestName ?? widget.userName ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: isMobile ? 28 : 32,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _actualGuestName ?? widget.userName ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _tabs.map((tab) {
                final isSelected = _selectedTab == tab['label'];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? _lightBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      tab['icon'] as IconData,
                      color: isSelected ? _primaryBlue : Colors.black54,
                      size: 24,
                    ),
                    title: Text(
                      tab['label'] as String,
                      style: TextStyle(
                        color: isSelected ? _primaryBlue : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: isMobile ? 14 : 15,
                      ),
                    ),
                    selected: isSelected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedTab = tab['label'] as String;
                      });
                      if (isMobile) {
                        Navigator.pop(context);
                      }
                      
                      if (_selectedTab == 'My Bookings') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MyReservationsPage(
                              loggedIn: true,
                              userName: widget.userName ?? '',
                              onLogout: widget.onLogout,
                              userUid: widget.userUid,
                            ),
                          ),
                        );
                      } else if (_selectedTab == 'Home') {
                        // Already on home page
                      } else if (_selectedTab == 'About BT') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutBTPage()));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$_selectedTab coming soon'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: _primaryBlue,
                          ),
                        );
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: Colors.red.shade700),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 14 : 15,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (_) {}
                widget.onLogout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MyApp()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              width: double.infinity,
              color: Colors.lightBlue,
              child: Center(
                child: Text(
                  '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: const Text('List your property'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HostRegistrationPage(
                            onRegistered: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const HostArea(initialTab: 3)),
                                (route) => false,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('Sign in'),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage(onLogin: widget.onLogin)),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingComStyleAppBar(bool isMobile) {
    final width = MediaQuery.of(context).size.width;

    if (isMobile) {
      return Column(
        children: [
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 12),
                  Image.asset(
                    'assets/images/btslogo.png',
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        'BT ShortStay',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  if (widget.loggedIn)
                    GestureDetector(
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Find Your Perfect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Place to Stay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildModernLocationField(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildModernCheckInField()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildModernCheckOutField()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildModernSearchButton(),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final double titleFontSize = (width < 420) ? 24 : ((width < 800) ? 32 : 42);

    return Column(
      children: [
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.loggedIn) ...[
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HostRegistrationPage(
                                onRegistered: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const HostArea(initialTab: 3)),
                                    (route) => false,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        child: const Text('List your property', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage(onLogin: widget.onLogin)));
                          if (mounted) setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.lightBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ] else
                      _UserPopupMenu(
                        userName: widget.userName ?? "",
                        onLogout: () {
                          widget.onLogout();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Color(0xFFE3F2FD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  'Find a home away from home',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -0.5,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 680),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 500;
                  if (isWideScreen) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(flex: 6, child: _buildLocationField(isMobile)),
                        _verticalDivider(),
                        Flexible(flex: 2, child: _buildCheckInField()),
                        _verticalDivider(),
                        Flexible(flex: 2, child: _buildCheckOutField()),
                        _verticalDivider(),
                        _buildSearchButton(),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildLocationField(isMobile)),
                            _verticalDivider(),
                            Expanded(child: _buildCheckInField()),
                            _verticalDivider(),
                            Expanded(child: _buildCheckOutField()),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [Expanded(child: _buildSearchButton())],
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernLocationField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 20, color: _primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              hintText: 'Where are you going?',
              hintStyle: TextStyle(
                color: Colors.black38,
                fontSize: 15,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            onSubmitted: (_) => _performSearch(),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCheckInField() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: checkInDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() => checkInDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: _primaryBlue),
                const SizedBox(width: 8),
                const Text(
                  'Check-in',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              checkInDate != null 
                  ? DateFormat('MMM d, yyyy').format(checkInDate!) 
                  : 'Select date',
              style: TextStyle(
                fontSize: 15,
                color: checkInDate != null ? Colors.black87 : Colors.black38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCheckOutField() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: checkOutDate ?? 
              (checkInDate?.add(const Duration(days: 1)) ?? 
              DateTime.now().add(const Duration(days: 1))),
          firstDate: checkInDate ?? DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() => checkOutDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: _primaryBlue),
                const SizedBox(width: 8),
                const Text(
                  'Check-out',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              checkOutDate != null 
                  ? DateFormat('MMM d, yyyy').format(checkOutDate!) 
                  : 'Select date',
              style: TextStyle(
                fontSize: 15,
                color: checkOutDate != null ? Colors.black87 : Colors.black38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _performSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search, size: 22),
            SizedBox(width: 8),
            Text(
              'Search Apartments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  Widget _buildLocationField(bool isMobile) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              isMobile ? 'Location' : 'Where do you want to stay?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ]),
          const SizedBox(height: 2),
          Expanded(
            child: TextField(
              controller: _locationController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Enter location',
                hintStyle: TextStyle(color: Colors.black54, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              onSubmitted: (_) => _performSearch(),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInField() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: checkInDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() => checkInDate = picked);
        }
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.calendar_today, size: 18, color: Colors.black54),
              SizedBox(width: 6),
              Text('Check-in', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87), textAlign: TextAlign.center),
            ]),
            const SizedBox(height: 2),
            Expanded(
              child: Center(
                child: Text(
                  checkInDate != null ? DateFormat('MMM d').format(checkInDate!) : 'Select date',
                  style: TextStyle(fontSize: 14, color: checkInDate != null ? Colors.black87 : Colors.black54),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckOutField() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: checkOutDate ?? (checkInDate?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1))),
          firstDate: checkInDate ?? DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() => checkOutDate = picked);
        }
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.calendar_today, size: 18, color: Colors.black54),
              SizedBox(width: 6),
              Text('Check-out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87), textAlign: TextAlign.center),
            ]),
            const SizedBox(height: 2),
            Expanded(
              child: Center(
                child: Text(
                  checkOutDate != null ? DateFormat('MMM d').format(checkOutDate!) : 'Select date',
                  style: TextStyle(fontSize: 14, color: checkOutDate != null ? Colors.black87 : Colors.black54),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _performSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          minimumSize: const Size(80, 48),
        ),
        child: const Text('Search', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }

  Widget _buildApartmentGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getApartmentStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.lightBlue),
                    SizedBox(height: 16),
                    Text('Loading apartments...', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }

        var apartments = snapshot.data?.docs ?? [];

        if (_searchLocation.isNotEmpty) {
          final query = _searchLocation.toLowerCase();
          apartments = apartments.where((doc) {
            final address = (doc['address'] ?? '').toString().toLowerCase();
            return address.contains(query);
          }).toList();
        }

        if (apartments.length > 15) {
          apartments = apartments.sublist(0, 15);
        }

        if (apartments.isEmpty) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 400,
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.home_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No apartments available', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  SizedBox(height: 8),
                  Text('Check back later for new listings', style: TextStyle(fontSize: 16, color: Colors.black54)),
                ]),
              ),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Latest apartments in Abuja',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                ),
                itemCount: apartments.length,
                itemBuilder: (context, index) {
                  try {
                    return _buildApartmentCard(apartments[index]);
                  } catch (e) {
                    print('❌ Error building apartment card $index: $e');
                    return Container(
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('Error loading apartment', style: TextStyle(color: Colors.black54))),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 5;
    if (width > 1100) return 4;
    if (width > 800) return 3;
    if (width > 500) return 2;
    return 1;
  }

  Widget _buildApartmentCard(DocumentSnapshot apartment) {
    try {
      final data = apartment.data() as Map<String, dynamic>? ?? {};
      final title = data['title'] ?? data['name'] ?? 'No Title';

      final blockedPeriods = DateBlockingUtils.parseBlockedPeriods(data['blockedPeriods']);
      
      String availabilityStatus = 'Available';
      DateTime? nextAvailableDate;
      bool hasDateConflict = false;

      if (blockedPeriods.isNotEmpty) {
        final now = DateTime.now();
        final farFuture = DateTime(2099, 12, 31);
        
        if (DateBlockingUtils.isDateRangeBlocked(blockedPeriods, now, farFuture)) {
          availabilityStatus = 'Booked for a period';
        } else {
          availabilityStatus = 'Partially Booked';
          nextAvailableDate = DateBlockingUtils.getNextAvailableDate(blockedPeriods, now);
        }

        if (checkInDate != null && checkOutDate != null) {
          hasDateConflict = DateBlockingUtils.isDateRangeBlocked(
            blockedPeriods,
            checkInDate!,
            checkOutDate!,
          );
        }
      }

      String? imageUrl;
      if (data['imageUrls'] != null) {
        if (data['imageUrls'] is List && (data['imageUrls'] as List).isNotEmpty) {
          final urlList = data['imageUrls'] as List;
          final firstUrl = urlList.first?.toString().trim();

          if (firstUrl != null && firstUrl.isNotEmpty && _isValidUrl(firstUrl)) {
            imageUrl = _fixFirebaseStorageUrl(firstUrl);
          }
        } else if (data['imageUrls'] is String) {
          final urlString = data['imageUrls'].toString().trim();

          if (urlString.isNotEmpty && _isValidUrl(urlString)) {
            imageUrl = _fixFirebaseStorageUrl(urlString);
          }
        }
      }

      double amount = 0;
      if (data['price'] != null) {
        try {
          amount = double.parse(data['price'].toString());
        } catch (_) {}
      }

      final formatter = NumberFormat('#,###');
      final formattedAmount = formatter.format(amount);

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ApartmentDetailsPage(
                apartmentId: apartment.id,
                loggedIn: widget.loggedIn,
                userName: widget.userName,
                onLogout: widget.onLogout,
                guestUid: widget.userUid,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(child: CircularProgressIndicator(color: Colors.lightBlue, strokeWidth: 2)),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.broken_image, color: Colors.grey, size: 32),
                                      SizedBox(height: 8),
                                      Text('Image Error', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                    ]),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.image_not_supported, color: Colors.grey, size: 32),
                                  SizedBox(height: 8),
                                  Text('No Image', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                ]),
                              ),
                            ),
                    ),
                    if (hasDateConflict)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Not available for selected dates',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (data['address'] != null)
                      Text(
                        data['address'].toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (data['rating'] != null) ...[
                          const Icon(Icons.star, color: Colors.black87, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            data['rating'].toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                        ],
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '₦$formattedAmount',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const TextSpan(
                                text: ' /night',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Error in apartment card: $e');
      return Container(
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('Error loading apartment', style: TextStyle(color: Colors.black54), textAlign: TextAlign.center)),
      );
    }
  }

  bool _isValidUrl(String url) {
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (e) {
      return false;
    }
  }

  String _fixFirebaseStorageUrl(String url) {
    if (url.contains('firebasestorage.googleapis.com') && !url.contains('?alt=media')) {
      if (url.contains('?')) {
        return '$url&alt=media';
      } else {
        return '$url?alt=media';
      }
    }
    return url;
  }

  Widget _buildFooter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 768;
        
        if (isMobile) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.all(24),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildFooterColumn(context, 'Company', ['About', 'Updates', 'Feedback'])),
                  Expanded(child: _buildFooterColumn(context, 'Policies', ['Privacy', 'Terms of Use', 'Cookies'])),
                  Expanded(child: _buildFooterColumn(context, 'Help', ['Support', 'How to book an apartment', 'How to become a host'])),
                  Expanded(child: _buildFooterColumn(context, 'Contact', ['Email: info@btshortstay.com', 'Phone: 07041977207', 'Phone: 08035140692'])),
                ],
              ),
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  '© 2025 BT ShortStay All rights reserved.',
                  style: TextStyle(color: Colors.black54, fontSize: 14, fontFamily: 'Roboto'),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooterColumn(BuildContext context, String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Roboto')),
        const SizedBox(height: 12),
        ...links.map((link) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              if (title == 'Company' && link == 'About') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutBTPage()));
                return;
              }
              print('Tapped: $link');
            },
            child: Text(link, style: const TextStyle(fontSize: 14, color: Colors.black87, fontFamily: 'Roboto', decoration: TextDecoration.none)),
          ),
        )),
      ],
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
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'reservations':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyReservationsPage(
                  loggedIn: true,
                  userName: userName,
                  onLogout: onLogout,
                  userUid: FirebaseAuth.instance.currentUser?.uid,
                ),
              ),
            );
            break;
          case 'logout':
            onLogout();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'reservations',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border, size: 18),
              SizedBox(width: 8),
              Flexible(child: Text('My Reservations', overflow: TextOverflow.ellipsis, maxLines: 1)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 8),
              Flexible(child: Text('Sign out', overflow: TextOverflow.ellipsis, maxLines: 1)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.account_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
        ]),
      ),
    );
  }
}