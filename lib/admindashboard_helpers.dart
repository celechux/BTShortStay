import 'package:flutter/material.dart';

/// ---- Theme Colors ----
const kPrimaryBlue = Color(0xFF1565C0);
const kAccentBlue = Color(0xFF42A5F5);
const kShadowBlue = Color(0x3342A5F5);
const kCardElevation = 4.0;
const kTabLightBlue = Color(0xFFBBDEFB);

/// ---- Formatting Helpers ----
String formatCurrency(double amount) {
  if (amount >= 1000000) {
    return "${(amount / 1000000).toStringAsFixed(1)}M";
  } else if (amount >= 1000) {
    return "${(amount / 1000).toStringAsFixed(1)}K";
  } else {
    return amount.toStringAsFixed(0);
  }
}

String formatDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';

String formatJoinDate(dynamic joinDate) {
  if (joinDate == null) return 'Unknown';
  try {
    if (joinDate is DateTime) {
      return '${joinDate.day}/${joinDate.month}/${joinDate.year}';
    }
    if (joinDate is String) {
      final d = DateTime.tryParse(joinDate);
      if (d != null) return '${d.day}/${d.month}/${d.year}';
    }
    return joinDate.toString();
  } catch (_) {
    return 'Unknown';
  }
}

/// ---- Status Color Helpers ----
Color getStatusColor(String? status) {
  switch (status) {
    case 'confirmed':
      return Colors.green;
    case 'pending':
      return Colors.orange;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

Color getPaymentStatusColor(String? status) {
  switch (status?.toLowerCase()) {
    case 'completed':
    case 'paid':
      return Colors.green;
    case 'pending':
      return Colors.orange;
    case 'failed':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

IconData getPaymentIcon(String? status) {
  switch (status?.toLowerCase()) {
    case 'completed':
    case 'paid':
      return Icons.check_circle;
    case 'pending':
      return Icons.hourglass_bottom;
    case 'failed':
      return Icons.cancel;
    default:
      return Icons.help_outline;
  }
}

/// ---- Money Formatting ----
double toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}

String str(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

String fmt(double n) =>
    n.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
