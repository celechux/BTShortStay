import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../widgets/my_profile_page.dart';
import '../main.dart';

class UserPopupMenu extends StatelessWidget {
  final String userName;
  final String? userUid;
  final VoidCallback onLogout;
  final VoidCallback onRefreshReservations;

  const UserPopupMenu({
    super.key,
    required this.userName,
    required this.userUid,
    required this.onLogout,
    required this.onRefreshReservations,
  });

  void _openProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => MyProfilePage(
        userUid: userUid,
        fallbackName: userName,
        compact: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'User menu',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          border: Border.all(color: kPrimaryBlue, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: kPrimaryBlue,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kPrimaryBlue,
              size: 20,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 1,
          child: ListTile(
            leading: const Icon(Icons.account_circle_rounded, color: kPrimaryBlue),
            title: const Text('My Profile'),
            subtitle: const Text('Edit your profile information'),
          ),
          onTap: () => Future.delayed(Duration.zero, () => _openProfile(context)),
        ),
        PopupMenuItem(
          value: 2,
          child: ListTile(
            leading: const Icon(Icons.refresh_rounded, color: kPrimaryBlue),
            title: const Text('Reservations'),
            subtitle: const Text('View Reservations'),
          ),
          onTap: () => Future.delayed(Duration.zero, onRefreshReservations),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 3,
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Log out'),
            subtitle: const Text('Sign out of your account'),
          ),
          onTap: () => Future.delayed(const Duration(milliseconds: 0), () async {
            try {
              await FirebaseAuth.instance.signOut();
            } catch (_) {}
            onLogout();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MyApp()),
              (route) => false,
            );
          }),
        ),
      ],
    );
  }
}