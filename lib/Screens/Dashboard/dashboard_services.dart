import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/notification_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';

class DashboardService {
  // Private constructor
  DashboardService._internal();

  // Singleton instance
  static final DashboardService instance = DashboardService._internal();

  List<StockModel> finalList = [];

  final String apiKey = 'ddjw8yq0ow1zd9ds';
  String accessToken = '';

  // Getter to extract tokens from utilities list
  List<String?> get symbols =>
      stocksList
          .where((stock) => stock.token != '#N/A')
          .map((stock) => stock.symbol)
          .toList();

  // Returns symbols in the required API format: NSE:RELIANCE&i=NSE:TCS
  String get formattedSymbols => symbols.map((s) => 'NSE:$s').join('&i=');

  Future<List<StockModel>> fetchQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token') ?? '';
    final int batchSize = 500;
    final List<String?> allSymbols = symbols.whereType<String>().toList();
    List<StockModel> allQuotes = [];
    for (int i = 0; i < allSymbols.length; i += batchSize) {
      final batch = allSymbols.skip(i).take(batchSize).toList();
      final String batchSymbols = batch.map((s) => 'NSE:$s').join('&i=');
      final String url = 'https://api.kite.trade/quote?$batchSymbols';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Kite-Version': '3',
          'Authorization': 'token $apiKey:$accessToken',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final quotesMap = data['data'] as Map<String, dynamic>;
          quotesMap.forEach((key, value) {
            allQuotes.add(
              StockModel.fromMap({
                'symbol': key,
                'name': value['tradable']?.toString() ?? '',
                'token': value['instrument_token'],
                'timestamp': value['timestamp'],
                'last_trade_time': value['last_trade_time'],
                'last_price': value['last_price'],
                'last_quantity': value['last_quantity'],
                'buy_quantity': value['buy_quantity'],
                'sell_quantity': value['sell_quantity'],
                'volume': value['volume'],
                'average_price': value['average_price'],
                'oi': value['oi'],
                'oi_day_high': value['oi_day_high'],
                'oi_day_low': value['oi_day_low'],
                'net_change': value['net_change'],
                'lower_circuit_limit': value['lower_circuit_limit'],
                'upper_circuit_limit': value['upper_circuit_limit'],
                'ohlc': value['ohlc'],
              }),
            );
          });
        }
        log("allQuotes : ${allQuotes.length}");
      } else {
        log('Error fetching batch: ${response.statusCode} ${response.body}');
      }
    }
    List<StockModel> quoteList =
        allQuotes.where((stock) {
          return FilterUtils.isTradable(stock);
        }).toList();
    log("Filtered Quotes Count: ${quoteList.length}");

    // Throttle historical data API calls: max 3/sec
    List<StockModel> enrichedQuoteList = [];
    const int maxCallsPerSecond = 12;
    for (int i = 0; i < quoteList.length; i += maxCallsPerSecond) {
      final batch = quoteList.skip(i).take(maxCallsPerSecond).toList();
      final batchResults = await Future.wait(
        batch.map((stock) async {
          final historyFiveMin = await fetchHistoricalData(
            int.tryParse(stock.token.toString()) ?? 0,
          );

          // -------------- Check On Multi Time Frame ----------------
          bool isPass = await FilterUtils.isPassAllTimeFrame(
            historyFiveMin,
            stock,
          );

          if (isPass) {
            return StockModel(
              symbol: stock.symbol?.replaceAll("NSE:", ""),
              name: stock.name,
              token: stock.token,
              sector: stock.sector,
              timestamp: stock.timestamp,
              lastTradeTime: stock.lastTradeTime,
              lastPrice: stock.lastPrice,
              lastQuantity: stock.lastQuantity,
              buyQuantity: stock.buyQuantity,
              sellQuantity: stock.sellQuantity,
              volume: stock.volume,
              averagePrice: stock.averagePrice,
              oi: stock.oi,
              oiDayHigh: stock.oiDayHigh,
              oiDayLow: stock.oiDayLow,
              netChange: stock.netChange,
              lowerCircuitLimit: stock.lowerCircuitLimit,
              upperCircuitLimit: stock.upperCircuitLimit,
              ohlc: stock.ohlc,
              historyFiveMin: historyFiveMin,
            );
          } else {
            return null;
          }
        }),
      );
      enrichedQuoteList.addAll(batchResults.whereType<StockModel>());
      if (i + maxCallsPerSecond < quoteList.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // Final filter: percent change >= 2%
    finalList =
        enrichedQuoteList.where((stock) {
          final percentChange =
              ((stock.lastPrice! - stock.ohlc!.open!) / stock.ohlc!.open!) *
              100;
          return percentChange >= 2.0;
        }).toList();

    // ------------Notification Process---------------

    List<NotificationModel> notificationsList =
        await SharedPreferenceHelper.instance.getNotificationList();

    List<String> newStockSymbols = [];
    for (var stock in finalList) {
      bool exists = notificationsList.any(
        (n) =>
            n.stocksNameList?.toUpperCase().contains(
              stock.symbol!.toUpperCase(),
            ) ??
            false,
      );
      if (!exists) {
        newStockSymbols.add(stock.symbol!);
      }
    }

    // Add new notifications
    if (newStockSymbols.isNotEmpty) {
      notificationsList.add(
        NotificationModel(
          stocksNameList: newStockSymbols.join(','),
          time: DateTime.now().toString(),
        ),
      );
    }
    // Save updated notifications list
    await SharedPreferenceHelper.instance.saveNotificationList(
      notificationsList,
    );
    return finalList;
  }

  Future<List<HistoricalDataModel>?> fetchHistoricalData(
    int instrumentToken,
  ) async {
    final String interval = "5minute";

    DateTime getLastWorkingDay(DateTime now) {
      // Saturday → Friday
      if (now.weekday == DateTime.saturday) {
        return now.subtract(const Duration(days: 1));
      }
      // Sunday → Friday
      else if (now.weekday == DateTime.sunday) {
        return now.subtract(const Duration(days: 2));
      }
      // Monday before 9:05 AM → Friday
      else if (now.weekday == DateTime.monday &&
          (now.hour < 9 || (now.hour == 9 && now.minute < 5))) {
        return now.subtract(const Duration(days: 3));
      }
      // Otherwise → same day
      else {
        return now;
      }
    }

    DateTime getBusinessDaysAgo(DateTime today, int businessDays) {
      DateTime date = today;
      int daysCounted = 0;
      while (daysCounted < businessDays) {
        date = date.subtract(const Duration(days: 1));
        if (date.weekday != DateTime.saturday &&
            date.weekday != DateTime.sunday) {
          daysCounted++;
        }
      }
      return date;
    }

    DateTime today = getLastWorkingDay(DateTime.now());
    final DateTime fromDate = getBusinessDaysAgo(today, 10);
    final String from =
        "${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}";
    final String to =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final url =
        "https://api.kite.trade/instruments/historical/$instrumentToken/$interval?from=$from&to=$to";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "token $apiKey:$accessToken",
        "X-Kite-Version": "3",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candles = data["data"]["candles"] as List<dynamic>?;
      if (candles == null) return null;
      List<HistoricalDataModel>? historyList =
          candles
              .map((e) => HistoricalDataModel.fromList(e as List<dynamic>))
              .toList();
      return historyList;
    } else {
      print("Error: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  /// Utility function to check if a stock is choppy
  /// /// Utility function to check if a stock is choppy (loose version)
  bool isChoppyStockLoose(
    List<double> highs,
    List<double> lows,
    List<double> closes, {
    double threshold = 0.06, // ATR % threshold (looser)
    int atrPeriod = 10, // last 10 candles
  }) {
    if (highs.length < atrPeriod ||
        lows.length < atrPeriod ||
        closes.length < atrPeriod) {
      return false; // not enough data to consider choppy
    }

    int start = closes.length - atrPeriod;
    final lastHighs = highs.sublist(start);
    final lastLows = lows.sublist(start);
    final lastCloses = closes.sublist(start);

    List<double> tr = [];
    for (int i = 1; i < lastCloses.length; i++) {
      double hL = lastHighs[i] - lastLows[i];
      double hC = (lastHighs[i] - lastCloses[i - 1]).abs();
      double lC = (lastLows[i] - lastCloses[i - 1]).abs();
      tr.add([hL, hC, lC].reduce((a, b) => a > b ? a : b));
    }

    double atr = tr.reduce((a, b) => a + b) / tr.length;
    double avgClose = lastCloses.reduce((a, b) => a + b) / lastCloses.length;
    double atrPct = atr / avgClose;

    // Loose filter: only exclude if ATR% is very tiny
    return atrPct < threshold;
  }
}
