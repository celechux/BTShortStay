import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedPeriod {
  final DateTime startDate;
  final DateTime endDate;
  final String type;
  final String? notes;
  final DateTime createdAt;
  final String createdBy;

  BlockedPeriod({
    required this.startDate,
    required this.endDate,
    required this.type,
    this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'type': type,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory BlockedPeriod.fromMap(Map<String, dynamic> map) {
    return BlockedPeriod(
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      type: map['type'] ?? 'personal-use',
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }
}

class DateBlockingUtils {
  /// Parse blocked periods from Firestore data
  static List<BlockedPeriod> parseBlockedPeriods(dynamic blockedPeriodsData) {
    if (blockedPeriodsData == null) return [];
    
    if (blockedPeriodsData is! List) return [];
    
    final now = DateTime.now();
    final List<BlockedPeriod> periods = [];
    
    for (var item in blockedPeriodsData) {
      try {
        if (item is Map<String, dynamic>) {
          final period = BlockedPeriod.fromMap(item);
          
          // Filter out expired periods (end date is in the past)
          if (period.endDate.isAfter(now) || 
              period.endDate.year == now.year && 
              period.endDate.month == now.month && 
              period.endDate.day == now.day) {
            periods.add(period);
          }
        }
      } catch (e) {
        print('Error parsing blocked period: $e');
      }
    }
    
    return periods;
  }

  /// Check if a specific date is blocked
  static bool isDateBlocked(List<BlockedPeriod> blockedPeriods, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    for (var period in blockedPeriods) {
      final startOnly = DateTime(period.startDate.year, period.startDate.month, period.startDate.day);
      final endOnly = DateTime(period.endDate.year, period.endDate.month, period.endDate.day);
      
      if ((dateOnly.isAfter(startOnly) || dateOnly.isAtSameMomentAs(startOnly)) &&
          (dateOnly.isBefore(endOnly) || dateOnly.isAtSameMomentAs(endOnly))) {
        return true;
      }
    }
    
    return false;
  }

  /// Check if a date range is blocked (any overlap with blocked periods)
  static bool isDateRangeBlocked(List<BlockedPeriod> blockedPeriods, DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    for (var period in blockedPeriods) {
      final blockStart = DateTime(period.startDate.year, period.startDate.month, period.startDate.day);
      final blockEnd = DateTime(period.endDate.year, period.endDate.month, period.endDate.day);
      
      // Check for any overlap
      if (!(end.isBefore(blockStart) || start.isAfter(blockEnd))) {
        return true;
      }
    }
    
    return false;
  }

  /// Get the next available date after checking blocked periods
  static DateTime? getNextAvailableDate(List<BlockedPeriod> blockedPeriods, DateTime fromDate) {
    if (blockedPeriods.isEmpty) return fromDate;
    
    // Sort periods by start date
    final sortedPeriods = List<BlockedPeriod>.from(blockedPeriods)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    
    DateTime checkDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
    
    // Find the first available date
    for (var period in sortedPeriods) {
      final blockStart = DateTime(period.startDate.year, period.startDate.month, period.startDate.day);
      final blockEnd = DateTime(period.endDate.year, period.endDate.month, period.endDate.day);
      
      if (checkDate.isBefore(blockStart)) {
        return checkDate; // Found a gap
      } else if (checkDate.isAtSameMomentAs(blockStart) || 
                 (checkDate.isAfter(blockStart) && checkDate.isBefore(blockEnd)) ||
                 checkDate.isAtSameMomentAs(blockEnd)) {
        // Move to the day after this block ends
        checkDate = blockEnd.add(const Duration(days: 1));
      }
    }
    
    return checkDate;
  }

  /// Get all blocked dates in a month for calendar display
  static Set<DateTime> getBlockedDatesInMonth(List<BlockedPeriod> blockedPeriods, int year, int month) {
    final blockedDates = <DateTime>{};
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    
    for (var period in blockedPeriods) {
      DateTime current = period.startDate.isBefore(firstDay) ? firstDay : period.startDate;
      final end = period.endDate.isAfter(lastDay) ? lastDay : period.endDate;
      
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        if (current.month == month) {
          blockedDates.add(DateTime(current.year, current.month, current.day));
        }
        current = current.add(const Duration(days: 1));
      }
    }
    
    return blockedDates;
  }

  /// Validate if a date range is available for booking
  static String? validateDateRange(List<BlockedPeriod> blockedPeriods, DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) {
      return 'Please select both check-in and check-out dates';
    }
    
    if (endDate.isBefore(startDate) || endDate.isAtSameMomentAs(startDate)) {
      return 'Check-out date must be after check-in date';
    }
    
    if (isDateRangeBlocked(blockedPeriods, startDate, endDate)) {
      return 'Selected dates are not available. Please choose different dates.';
    }
    
    return null; // Valid
  }

  /// Get human-readable type label
  static String getTypeLabel(String type) {
    switch (type) {
      case 'offline-booking':
        return 'Offline Booking';
      case 'maintenance':
        return 'Maintenance';
      case 'personal-use':
        return 'Personal Use';
      default:
        return type;
    }
  }
}