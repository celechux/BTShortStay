import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class FilterTabsWithBadges extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final Stream<QuerySnapshot> reservationsStream;

  const FilterTabsWithBadges({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.reservationsStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: reservationsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final allCount = docs.length;
        final pendingCount = docs.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'pending').length;
        final confirmedCount = docs.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'confirmed').length;
        final completedCount = docs.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'completed').length;
        final cancelledCount = docs.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'cancelled').length;

        Widget buildTab(String value, String label, int count, IconData icon) {
          final isSelected = selectedFilter == value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: isSelected ? Colors.white : kPrimaryBlue),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : kPrimaryBlue,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : kPrimaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected ? kPrimaryBlue : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          color: kTabLightBlue,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicWidth(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'all',
                      label: buildTab('all', 'All', allCount, Icons.list_rounded),
                    ),
                    ButtonSegment(
                      value: 'pending',
                      label: buildTab('pending', 'Pending', pendingCount, Icons.schedule_rounded),
                    ),
                    ButtonSegment(
                      value: 'confirmed',
                      label: buildTab('confirmed', 'Confirmed', confirmedCount, Icons.check_circle_rounded),
                    ),
                    ButtonSegment(
                      value: 'completed',
                      label: buildTab('completed', 'Completed', completedCount, Icons.task_alt_rounded),
                    ),
                    ButtonSegment(
                      value: 'cancelled',
                      label: buildTab('cancelled', 'Cancelled', cancelledCount, Icons.cancel_rounded),
                    ),
                  ],
                  selected: {selectedFilter},
                  onSelectionChanged: (value) {
                    if (value.isNotEmpty) onFilterChanged(value.first);
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: kPrimaryBlue,
                    selectedForegroundColor: Colors.white,
                    backgroundColor: Colors.white,
                    foregroundColor: kPrimaryBlue,
                    side: const BorderSide(color: kPrimaryBlue, width: 1.5),
                    elevation: kCardElevation / 3,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}