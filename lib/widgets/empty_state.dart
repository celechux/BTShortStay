import 'package:flutter/material.dart';
import '../utils/constants.dart';

class EmptyStateWidget extends StatelessWidget {
  final String selectedFilter;

  const EmptyStateWidget({super.key, required this.selectedFilter});

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    IconData icon;

    switch (selectedFilter) {
      case 'pending':
        title = 'No Pending Reservations';
        subtitle = "You don't have any pending reservations at the moment";
        icon = Icons.schedule_rounded;
        break;
      case 'confirmed':
        title = 'No Confirmed Reservations';
        subtitle = "You don't have any confirmed reservations at the moment";
        icon = Icons.check_circle_rounded;
        break;
      case 'completed':
        title = 'No Completed Reservations';
        subtitle = "You don't have any completed reservations at the moment";
        icon = Icons.task_alt_rounded;
        break;
      case 'cancelled':
        title = 'No Cancelled Reservations';
        subtitle = "You don't have any cancelled reservations at the moment";
        icon = Icons.cancel_rounded;
        break;
      case 'all':
      default:
        title = 'No reservations yet';
        subtitle = 'Your reservations will appear here once you make a booking';
        icon = Icons.event_busy_rounded;
        break;
    }

    return Center(
      child: Card(
        elevation: kCardElevation,
        margin: const EdgeInsets.all(32),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: kAccentBlue, width: 2),
        ),
        shadowColor: kShadowBlue,
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 80,
                color: kPrimaryBlue,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kPrimaryBlue,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}