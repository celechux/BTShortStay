import 'package:cloud_firestore/cloud_firestore.dart';

// Shared helper(s) used across admin_* tabs

// Determine reservation status for an apartment given reservations list
String getReservationStatus(String apartmentId, List<QueryDocumentSnapshot> reservations) {
  final now = DateTime.now();
  for (var reservation in reservations) {
    final data = reservation.data() as Map<String, dynamic>;
    final reservationApartmentId = data['apartmentId'];
    if (reservationApartmentId == apartmentId) {
      final status = data['status'] ?? '';
      if (status == 'cancelled') continue;
      try {
        final checkOutDate = data['checkOut'];
        DateTime? checkOut;
        if (checkOutDate is Timestamp) {
          checkOut = checkOutDate.toDate();
        } else if (checkOutDate is String) {
          checkOut = DateTime.tryParse(checkOutDate);
        }
        if (checkOut != null && checkOut.isAfter(now.subtract(const Duration(days: 1)))) {
          return 'Reserved';
        }
      } catch (e) {
        if (status == 'confirmed' || status == 'active') {
          return 'Reserved';
        }
      }
    }
  }
  return 'Available';
}