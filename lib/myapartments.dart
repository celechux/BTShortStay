import 'package:flutter/material.dart';

class MyApartmentsPage extends StatelessWidget {
  const MyApartmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace with a Firestore stream of apartments belonging to this host
    return Center(
      child: Text('Your Apartments will appear here.',
          style: TextStyle(fontSize: 22, color: Colors.black54)),
    );
  }
}