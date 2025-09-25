import 'dart:developer';
import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/api_response.dart';
import 'package:stock_demo/model/final_stock_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';

class DashboardService {
  // Private constructor
  DashboardService._internal();

  // Singleton instance
  static final DashboardService instance = DashboardService._internal();

  List<StockModel> finalList = [];

  Future<List<FinalStockModel>> fetchQuotes() async {
    // Getter to extract tokens from utilities list
    await Utilities.loadStocksList();

    List<String?> symbols =
        DataManager.instance.stocksList
            .where((stock) => stock.token != '#N/A')
            .map((stock) => stock.symbol)
            .toList();

    final int batchSize = 500;
    final List<String?> allSymbols = symbols.whereType<String>().toList();
    List<StockModel> allQuotes = [];

    // Fetch live data in batches of 500
    for (int i = 0; i < allSymbols.length; i += batchSize) {
      final batch = allSymbols.skip(i).take(batchSize).toList();
      final String batchSymbols = batch.map((s) => 'NSE:$s').join('&i=');
      APIResponse response = await ApiService.instance.apiCall(
        APIEndPoint.getLiveStocksData + batchSymbols,
        HttpRequestType.get,
        null,
      );
      if (response.status) {
        var data = response.data;
        if (data is Map && data.containsKey('data')) {
          final quotesMap = data['data'] as Map<String, dynamic>;
          allQuotes.addAll(Utilities.convertDataToStockModel(quotesMap));
        }
        log("allQuotes : ${allQuotes.length}");
      } else {
        log('Error fetching batch: ${response.error}');
      }
    }

    // Filter tradable stocks with Live Data
    List<StockModel> quoteList =
        allQuotes.where((stock) {
          return FilterUtils.isTradable(stock);
        }).toList();
    log("Filtered Quotes Count: ${quoteList.length}");

    // Throttle historical data API calls: max 3/sec
    const int maxCallsPerSecond = 12;
    for (int i = 0; i < quoteList.length; i += maxCallsPerSecond) {
      final batch = quoteList.skip(i).take(maxCallsPerSecond).toList();
      final batchResults = await Future.wait(
        batch.map((stock) async {
          final historyFiveMin = await fetchHistoricalData(
            int.tryParse(stock.token.toString()) ?? 0,
          );

          // -------------- Indicator Filter with History Data ----------------
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
      finalList.addAll(batchResults.whereType<StockModel>());
      if (i + maxCallsPerSecond < quoteList.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    Utilities.addAndShowNotification(finalList);
    log(
      "Final Filtered Stocks Count: ${finalList.length} \n${finalList.map((e) => e.symbol).join(", ")}",
    );
    return finalList.map((s) {
      return FinalStockModel(
        dateTime: DateTime.now().toString(),
        stockSymbol: s.symbol,
        token: s.token,
        lastPrice: s.lastPrice,
        open: s.ohlc?.open,
        close: s.ohlc?.close,
      );
    }).toList();
  }

  // Fetch historical data for a given instrument token
  Future<List<HistoricalDataModel>?> fetchHistoricalData(
    int instrumentToken,
  ) async {
    final String interval = "5minute";
    DateTime today = Utilities.getLastWorkingDay(DateTime.now());
    final String from = Utilities.getBusinessDaysAgo(today, 20);
    final String to =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    APIResponse response = await ApiService.instance.apiCall(
      "${APIEndPoint.getHistoricalData}$instrumentToken/$interval?from=$from&to=$to",
      HttpRequestType.get,
      null,
    );

    if (response.status) {
      final candles = response.data["data"]["candles"] as List<dynamic>?;
      if (candles == null) return null;
      List<HistoricalDataModel>? historyList =
          candles
              .map((e) => HistoricalDataModel.fromList(e as List<dynamic>))
              .toList();
      return historyList;
    } else {
      log("Error: ${response.error}");
      return null;
    }
  }

  /// Utility function to check if a stock is choppy
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
