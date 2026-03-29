import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class FormatUtils {
  static final _dotFmt = NumberFormat('#,###', 'vi_VN');

  static int parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Hiển thị số tiền: 20.000.000 đ
  static String formatAmount(double amount, {bool showSign = false}) {
    final abs = _dotFmt.format(amount.abs());
    if (showSign) {
      return amount >= 0 ? '+$abs đ' : '-$abs đ';
    }
    return '$abs đ';
  }

  /// Compact: 1.5M, 500K
  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);
    if (txDate == today) return 'Hôm nay';
    if (txDate == yesterday) return 'Hôm qua';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateLong(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'vi_VN').format(date);
  }

  static String formatMonth(DateTime date) {
    return DateFormat('MMMM yyyy', 'vi_VN').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format số thuần (chỉ digit) thành "20.000.000" cho hiển thị trong TextField
  static String formatInputNumber(String rawDigits) {
    if (rawDigits.isEmpty) return '';
    final number = int.tryParse(rawDigits) ?? 0;
    return _dotFmt.format(number);
  }

  /// TextInputFormatter thêm dấu . tự động khi nhập số trong TextField
  static TextInputFormatter get moneyInputFormatter => _MoneyInputFormatter();
}

class _MoneyInputFormatter extends TextInputFormatter {
  static final _dotFmt = NumberFormat('#,###', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Chỉ giữ lại chữ số
    final rawDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawDigits.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final formatted = _dotFmt.format(int.parse(rawDigits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
