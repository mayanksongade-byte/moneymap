import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CurrencyProvider extends ChangeNotifier {
  String _selectedCurrency = 'INR';
  String _currencySymbol = '₹';

  String get selectedCurrency => _selectedCurrency;
  String get currencySymbol => _currencySymbol;

  final Map<String, String> _currencyMap = {
    'INR': '₹',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'CAD': r'C$',
    'AUD': r'A$',
  };

  CurrencyProvider() {
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedCurrency = prefs.getString('currency') ?? 'INR';
    _currencySymbol = _currencyMap[_selectedCurrency] ?? '₹';
    notifyListeners();
  }

  Future<void> setCurrency(String currencyCode) async {
    _selectedCurrency = currencyCode;
    _currencySymbol = _currencyMap[currencyCode] ?? '₹';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currencyCode);
    notifyListeners();
  }

  NumberFormat get formatter => NumberFormat.currency(
    symbol: '$_currencySymbol ',
    decimalDigits: 0,
  );

  NumberFormat get formatterWithDecimals => NumberFormat.currency(
    symbol: '$_currencySymbol ',
    decimalDigits: 2,
  );

  String format(num amount, {bool showDecimals = false}) {
    return showDecimals ? formatterWithDecimals.format(amount) : formatter.format(amount);
  }
}
