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
    print(allSymbols.length);
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
          final lastPrice = stock.lastPrice;
          final lowerLimit = stock.lowerCircuitLimit;
          final upperLimit = stock.upperCircuitLimit;
          final ohlc = stock.ohlc;
          final close = ohlc?.close;
          double? percentChange = 0;
          if (stock.ohlc != null &&
              stock.ohlc!.open != null &&
              stock.ohlc!.open != 0 &&
              stock.lastPrice != null) {
            percentChange =
                ((stock.lastPrice! - stock.ohlc!.open!) / stock.ohlc!.open!) *
                100;
          }

          print(
            "Filtered Stock: ${stock.symbol}, Last Price: $lastPrice, Volume: ${stock.volume}, Percent Change: $percentChange",
          );

          return lastPrice != null &&
              lastPrice > 95 &&
              lastPrice < 1500 &&
              lowerLimit != null &&
              upperLimit != null &&
              lastPrice > lowerLimit &&
              lastPrice < upperLimit &&
              close != null &&
              lastPrice > close &&
              percentChange > 1.0 &&
              stock.volume != null;
          //stock.volume! > 1000
        }).toList();
    log("Filtered Quotes Count: ${quoteList.length}");

    // Throttle historical data API calls: max 3/sec
    List<StockModel> enrichedQuoteList = [];
    const int maxCallsPerSecond = 12;
    for (int i = 0; i < quoteList.length; i += maxCallsPerSecond) {
      final batch = quoteList.skip(i).take(maxCallsPerSecond).toList();
      final batchResults = await Future.wait(
        batch.map((stock) async {
          final historicalData = await fetchHistoricalData(
            int.tryParse(stock.token.toString()) ?? 0,
          );
          // Parse highs, lows, closes, volumes from historicalData
          List<double> highs =
              historicalData?.map((e) => e.high).toList() ?? [];
          List<double> lows = historicalData?.map((e) => e.low).toList() ?? [];
          List<double> closes =
              historicalData?.map((e) => e.close).toList() ?? [];
          List<int> volumes =
              historicalData?.map((e) => e.volume).toList() ?? [];
          bool isPass = FilterUtils.passesFilter(
            highs,
            lows,
            closes,
            volumes,
            stock.token.toString(),
          );

          if (isPass) {
            if (stock.token == 5138177) {
              log("Historical Data URL: ${stock.symbol}");
            }
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
              historicalData: historicalData,
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

    List<NotificationModel> notificationsList =
        await SharedPreferenceHelper.instance.getNotificationList();

    List<String> newStockSymbols = [];
    for (var stock in finalList) {
      bool exists = notificationsList.any(
        (n) => n.stocksNameList?.toUpperCase().contains(stock.symbol!.toUpperCase()) ?? false,
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

    DateTime getLastWorkingDay(DateTime today) {
      if (today.weekday == DateTime.saturday) {
        return today.subtract(const Duration(days: 1)); // Friday
      } else if (today.weekday == DateTime.sunday) {
        return today.subtract(const Duration(days: 2)); // Friday
      } else {
        return today; // Weekday
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

    DateTime today = DateTime.now();
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
