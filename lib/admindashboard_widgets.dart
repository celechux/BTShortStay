import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admindashboard_helpers.dart';
import 'admindashboard_dialogs.dart';

// ------------- DASHBOARD CARD -------------
class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final VoidCallback? onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: kCardElevation,
        shadowColor: kShadowBlue,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kAccentBlue, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 32, color: kPrimaryBlue),
                  if (onTap != null) const Icon(Icons.arrow_forward_ios, size: 16, color: kAccentBlue),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryBlue,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: kAccentBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------- APARTMENT SUMMARY CARD -------------
class ApartmentSummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const ApartmentSummaryCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: kCardElevation / 2,
      shadowColor: kShadowBlue,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kAccentBlue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: kPrimaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------- APARTMENT LIST TILE -------------
class ApartmentListTile extends StatelessWidget {
  final Map<String, dynamic> apartment;
  final String status;

  const ApartmentListTile({
    super.key,
    required this.apartment,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: kCardElevation / 2,
      shadowColor: kShadowBlue,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kAccentBlue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            apartment['imageUrls'] != null &&
                    (apartment['imageUrls'] as List).isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      apartment['imageUrls'][0],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home_work, size: 40, color: Colors.grey),
                      ),
                    ),
                  )
                : Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.home_work, size: 40, color: Colors.grey),
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    apartment['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: kPrimaryBlue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          apartment['address'] ?? 'No Address',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kTabLightBlue,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kAccentBlue),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on, size: 14, color: kPrimaryBlue),
                            const SizedBox(width: 4),
                            Text(
                              '₦${apartment['price'] ?? 'N/A'}',
                              style: TextStyle(
                                color: kPrimaryBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Icon(Icons.bed, size: 16, color: kAccentBlue),
                          const SizedBox(width: 4),
                          Text('${apartment['bedrooms'] ?? 0}', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 12),
                          Icon(Icons.bathtub, size: 16, color: kAccentBlue),
                          const SizedBox(width: 4),
                          Text('${apartment['bathrooms'] ?? 0}', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: apartment['status'] == 'active' ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    apartment['status'] ?? 'unknown',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'Available' ? Colors.green[600] : Colors.orange[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status == 'Available' ? Icons.check_circle : Icons.event_busy,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------- HOSTS LIST -------------
class HostsList extends StatelessWidget {
  final List<QueryDocumentSnapshot> hostDocs;
  final FirebaseFirestore firestore;

  const HostsList({
    super.key,
    required this.hostDocs,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        itemCount: hostDocs.length,
        itemBuilder: (context, index) {
          final hostDoc = hostDocs[index];
          final host = hostDoc.data() as Map<String, dynamic>;
          return InkWell(
            onTap: () async {
              final details = await firestore.collection('hosts').doc(hostDoc.id).get();
              showDialog(
                context: context,
                builder: (context) => HostDetailsDialog(
                  hostId: hostDoc.id,
                  hostData: details.data() ?? {},
                  firestore: firestore,
                  showActions: true,
                ),
              );
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: kCardElevation / 2,
              shadowColor: kShadowBlue,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: kAccentBlue, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    host['profileImageUrl'] != null
                        ? ClipOval(
                            child: Image.network(
                              host['profileImageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const CircleAvatar(child: Icon(Icons.person)),
                            ),
                          )
                        : const CircleAvatar(child: Icon(Icons.person)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(host['fullName'] ?? 'No Name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(host['email'] ?? 'No Email', overflow: TextOverflow.ellipsis),
                          Text(host['phone'] ?? 'No Phone', overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.home, size: 16, color: kAccentBlue),
                              Text(' ${host['totalProperties'] ?? 0} properties'),
                              const SizedBox(width: 16),
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              Text(' ${(host['rating'] ?? 0.0).toString()}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _pill(host['isActive'] == true ? 'Active' : 'Inactive',
                            color: host['isActive'] == true ? Colors.green : Colors.red),
                        const SizedBox(height: 8),
                        _pill(host['isIdVerified'] == true ? 'Verified' : 'Pending',
                            color: host['isIdVerified'] == true ? kPrimaryBlue : Colors.orange),
                        const SizedBox(height: 8),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------- GUESTS LIST -------------
class GuestsList extends StatelessWidget {
  final List<QueryDocumentSnapshot> guestDocs;
  final FirebaseFirestore firestore;

  const GuestsList({
    super.key,
    required this.guestDocs,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        itemCount: guestDocs.length,
        itemBuilder: (context, index) {
          final guestDoc = guestDocs[index];
          final guest = guestDoc.data() as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: kCardElevation / 2,
            shadowColor: kShadowBlue,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: kAccentBlue, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guest['guestName'] ?? guest['fullName'] ?? 'No Name',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guest['email'] ?? 'No Email',
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          guest['phoneNumber'] ?? guest['phone'] ?? 'No Phone',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: guest['isActive'] == true ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          guest['isActive'] == true ? 'Active' : 'Inactive',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: guest['emailVerified'] == true ? kPrimaryBlue : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          guest['emailVerified'] == true ? 'Verified' : 'Pending',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'suspend') {
                        await firestore.collection('guests').doc(guestDoc.id)
                            .update({'isActive': false});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Guest suspended.')),
                        );
                      } else if (value == 'delete') {
                        await firestore.collection('guests').doc(guestDoc.id).delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Guest deleted.')),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'suspend',
                        child: Row(
                          children: const [
                            Icon(Icons.pause_circle_filled, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Suspend'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------- RESERVATIONS LIST -------------
class ReservationsList extends StatelessWidget {
  final List<QueryDocumentSnapshot> reservationDocs;

  const ReservationsList({
    super.key,
    required this.reservationDocs,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        itemCount: reservationDocs.length,
        itemBuilder: (context, index) {
          final reservationDoc = reservationDocs[index];
          final reservation = reservationDoc.data() as Map<String, dynamic>;
          DateTime? checkIn;
          DateTime? checkOut;
          if (reservation['checkIn'] is Timestamp) {
            checkIn = (reservation['checkIn'] as Timestamp).toDate();
          } else if (reservation['checkIn'] is String) {
            checkIn = DateTime.tryParse(reservation['checkIn']);
          }
          if (reservation['checkOut'] is Timestamp) {
            checkOut = (reservation['checkOut'] as Timestamp).toDate();
          } else if (reservation['checkOut'] is String) {
            checkOut = DateTime.tryParse(reservation['checkOut']);
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: kCardElevation / 2,
            shadowColor: kShadowBlue,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: kAccentBlue, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: kPrimaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation['apartmentTitle'] ?? 'Apartment',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          reservation['guestName'] ?? reservation['guest'] ?? 'Guest',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.date_range, size: 16, color: kAccentBlue),
                            const SizedBox(width: 4),
                            Text(
                              '${checkIn != null ? formatDate(checkIn) : 'N/A'} - ${checkOut != null ? formatDate(checkOut) : 'N/A'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: getStatusColor(reservation['status']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          reservation['status'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: getPaymentStatusColor(reservation['paymentStatus']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          reservation['paymentStatus'] ?? 'Unpaid',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦${reservation['total'] ?? '0'}',
                        style: TextStyle(
                          color: kPrimaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------- PAYMENTS DASHBOARD & FINANCIAL REPORTS DASHBOARD -------------
// These are complex, so for brevity, you can move your cleaned-up logic from your main code here, or ask for detailed code for these widgets next.

Widget _pill(String text, {required Color color}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
  child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
);