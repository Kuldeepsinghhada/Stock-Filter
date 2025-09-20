import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import '../model/stock_model.dart';

String formatIndianNumber(num value) {
  final isInteger = value == value.roundToDouble();
  final formatter = NumberFormat.decimalPattern('en_IN');
  return isInteger
      ? formatter.format(value)
      : NumberFormat.currency(
        locale: 'en_IN',
        symbol: '',
        decimalDigits: 2,
      ).format(value).trim();
}

List<StockModel> stocksList = [];

Future<void> loadStocksList() async {
  final String jsonString = await rootBundle.loadString('assets/main.json');
  final List<dynamic> jsonData = json.decode(jsonString);
  stocksList = jsonData.map((item) {
    return StockModel(
      symbol: item['tradingsymbol']?.toString(),
      name: item['name']?.toString(),
      token: item['instrument_token']?.toString(),
      sector: item['sector']?.toString(), // If sector is missing, will be null
    );
  }).toList();
}
