import 'package:flutter/material.dart';

import 'admindashboard_helpers.dart';

class InfoTab extends StatelessWidget {
  final String message;
  const InfoTab({super.key, required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      color: Colors.white,
      elevation: kCardElevation,
      shadowColor: kShadowBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kAccentBlue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: TextStyle(fontSize: 20, color: kPrimaryBlue, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
}