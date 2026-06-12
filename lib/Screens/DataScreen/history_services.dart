import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/Utils/database_helper.dart';

class HistoryServices {
  HistoryServices._internal();
  static final HistoryServices instance = HistoryServices._internal();

  final List<StockModel> _finalList = [];

  int lastLocalCount = 0;
  int lastApiCount = 0;
  List<String> lastUnavailableList = [];

  /// Fetch live quotes, apply filters and historical data checks
  Future<List<StockModel>> fetchQuotes(
    DateTime toDate,
    List<String> symbols, {
    bool isRefresh = false,
  }) async {
    lastLocalCount = 0;
    lastApiCount = 0;
    lastUnavailableList.clear();

    await Utilities.loadStocksList();
    _finalList.clear();
    symbols.removeWhere((item) => (item.contains("ETF") ||
        item.contains("SILVER") ||
        item.contains("BEES")));
    final allQuotes = await _fetchLiveDataInBatches(symbols, batchSize: 90);

    final quoteList = allQuotes.where(FilterUtils.isDayTradable).toList();
    await _fetchHistoricalDataWithFilter(
      quoteList,
      toDate,
      isRefresh: isRefresh,
      maxCallsPerSecond: 12,
    );

    Utilities.addAndShowNotification(_finalList);

    return _finalList;
  }

  /// Fetch live data in batches to reduce API calls
  Future<List<StockModel>> _fetchLiveDataInBatches(
    List<String> symbols, {
    int batchSize = 400,
  }) async {
    final allQuotes = <StockModel>[];

    for (var i = 0; i < symbols.length; i += batchSize) {
      final batch = symbols.skip(i).take(batchSize).toList();
      final instruments = batch.map((s) => 'NSE:$s').toList();
      final uri = Uri.https(
        "api.kite.trade",
        "/quote",
        {"i": instruments},
      );
      final response = await ApiService.instance.apiCallUri(
        uri,
        HttpRequestType.get,
        null,
      );

      if (response.status) {
        final data = response.data;
        if (data is Map && data.containsKey('data')) {
          allQuotes.addAll(
            Utilities.convertDataToStockModel(
              data['data'] as Map<String, dynamic>,
            ),
          );
        }
      } else {
        log('Error fetching batch: ${response.error}');
      }
    }

    log("All Quotes Count: ${allQuotes.length}");
    return allQuotes;
  }

  /// Fetch historical data in batches with throttling and apply indicator filters
  Future<void> _fetchHistoricalDataWithFilter(
    List<StockModel> quoteList,
    DateTime toDate, {
    bool isRefresh = false,
    int maxCallsPerSecond = 12,
  }) async {
    List<StockModel> preFilteredList = [];

    final connectivityResult = await (Connectivity().checkConnectivity());
    final bool hasInternet =
        !connectivityResult.contains(ConnectivityResult.none);

    for (var i = 0; i < quoteList.length; i += maxCallsPerSecond) {
      final batch = quoteList.skip(i).take(maxCallsPerSecond).toList();
      bool didAPICall = false;

      final batchResults = await Future.wait(
        batch.map((stock) async {
          try {
            final cleanedSymbol = stock.symbol?.replaceAll("NSE:", "");
            if (cleanedSymbol == null) return null;

            List<HistoricalDataModel>? history;

            // Fetch from database
            final localData =
                await DatabaseHelper.instance.getCandles(cleanedSymbol);

            if (localData.isNotEmpty) {
              final lastDate = localData.last.timestamp;
              final today = DateTime.now();
              final isTodayFetched = lastDate.year == today.year &&
                  lastDate.month == today.month &&
                  lastDate.day == today.day;

              if (isRefresh && hasInternet && !isTodayFetched) {
                // Fetch missing days
                final fetchFromDate = lastDate.add(const Duration(days: 1));

                didAPICall = true;
                final newHistory = await fetchHistoricalData(
                  int.tryParse(stock.token.toString()) ?? 0,
                  toDate,
                  fromDate: fetchFromDate,
                  symbols: [cleanedSymbol],
                );

                if (newHistory != null && newHistory.isNotEmpty) {
                  // Merge and Save to DB (DatabaseHelper handles merging via ConflictAlgorithm.replace)
                  await DatabaseHelper.instance
                      .insertCandles(cleanedSymbol, newHistory);
                  history =
                      await DatabaseHelper.instance.getCandles(cleanedSymbol);
                  lastApiCount++;
                } else {
                  history = localData;
                  lastLocalCount++;
                }
              } else {
                // Up to date or offline
                history = localData;
                lastLocalCount++;
              }
            } else {
              // No local data, fetch full
              if (!hasInternet) {
                lastUnavailableList.add(cleanedSymbol);
              } else {
                didAPICall = true;
                history = await fetchHistoricalData(
                  int.tryParse(stock.token.toString()) ?? 0,
                  toDate,
                  symbols: [cleanedSymbol],
                );
                if (history != null && history.isNotEmpty) {
                  await DatabaseHelper.instance
                      .insertCandles(cleanedSymbol, history);
                  lastApiCount++;
                } else {
                  lastUnavailableList.add(cleanedSymbol);
                }
              }
            }

            if (history != null) {
              return stock.copyWith(
                symbol: cleanedSymbol,
                historyFiveMin: history,
              );
            }
          } catch (e) {
            log("Error processing ${stock.symbol} : ${stock.token}: $e");
          }
          return null;
        }),
      );

      _finalList.addAll(batchResults.whereType<StockModel>());

      if (didAPICall && i + maxCallsPerSecond < quoteList.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    DataManager.instance.preFilteredStocksList = preFilteredList;
  }

  /// Fetches data for a specific stock and interval, with local DB fallback and pruning.
  Future<List<HistoricalDataModel>> fetchIntervalData(
    StockModel stock,
    String interval, {
    bool forceRefresh = false,
  }) async {
    final cleanedSymbol = stock.symbol?.replaceAll("NSE:", "");
    if (cleanedSymbol == null) return [];

    // 1. Try local data first
    List<HistoricalDataModel> localData = await DatabaseHelper.instance
        .getCandles(cleanedSymbol, interval: interval);

    // Standard Zerodha/Kite intervals: 5minute, 15minute, 60minute, day
    String apiInterval = interval;
    if (interval == "5m") apiInterval = "5minute";
    if (interval == "15m") apiInterval = "15minute";
    if (interval == "1h") apiInterval = "60minute";
    if (interval == "D") apiInterval = "day";

    final now = DateTime.now();
    bool needsFetch = localData.isEmpty || forceRefresh;

    // For intraday, if last candle is from a previous day, we should refresh to get recent data
    if (localData.isNotEmpty && interval != "D") {
      final lastTimestamp = localData.last.timestamp;
      if (lastTimestamp.isBefore(now.subtract(const Duration(hours: 1)))) {
        needsFetch = true;
      }
    }

    if (needsFetch) {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none))
        return localData;

      // Calculate 'from' date based on requirement (10 days for intraday, 1000 for day)
      DateTime fromDate;
      if (interval == "D") {
        fromDate = now.subtract(const Duration(days: 1000));
      } else {
        fromDate = now.subtract(const Duration(days: 10));
      }

      final newHistory = await fetchHistoricalData(
        int.tryParse(stock.token.toString()) ?? 0,
        now,
        fromDate: fromDate,
        interval: apiInterval,
      );

      if (newHistory != null && newHistory.isNotEmpty) {
        await DatabaseHelper.instance
            .insertCandles(cleanedSymbol, newHistory, interval: interval);
        localData = await DatabaseHelper.instance
            .getCandles(cleanedSymbol, interval: interval);
      }
    }

    return localData;
  }

  /// Fetch historical data for a given instrument token
  Future<List<HistoricalDataModel>?> fetchHistoricalData(
    int instrumentToken,
    DateTime toDate, {
    DateTime? fromDate,
    List<String>? symbols,
    String interval = "day",
  }) async {
    final from = fromDate != null
        ? "${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}"
        : Utilities.getBusinessDaysAgo(toDate, 1000);
    final toDateFinal = DateTime.now();
    final to =
        "${toDateFinal.year}-${toDateFinal.month.toString().padLeft(2, '0')}-${toDateFinal.day.toString().padLeft(2, '0')}";

    log(
      'Fetching history for token: $instrumentToken, interval: $interval, from: $from to: $to',
    );

    final response = await ApiService.instance.apiCall(
      "${APIEndPoint.getHistoricalData}$instrumentToken/$interval?from=$from&to=$to",
      HttpRequestType.get,
      null,
    );

    if (response.status) {
      List<dynamic> candlesList = [];
      final respData = response.data;
      if (respData is Map && respData.containsKey('data')) {
        final dataSection = respData['data'];
        if (dataSection is Map && dataSection['candles'] is List) {
          candlesList = dataSection['candles'] as List<dynamic>;
        }
      }

      return candlesList
          .map((e) => HistoricalDataModel.fromList(e as List<dynamic>))
          .toList();
    } else {
      log("Error fetching historical data: ${response.error}");
      return null;
    }
  }
}

extension StockModelCopy on StockModel {
  StockModel copyWith({
    String? symbol,
    List<HistoricalDataModel>? historyFiveMin,
  }) =>
      StockModel(
        symbol: symbol ?? this.symbol,
        name: name,
        token: token,
        sector: sector,
        timestamp: timestamp,
        lastTradeTime: lastTradeTime,
        lastPrice: lastPrice,
        lastQuantity: lastQuantity,
        buyQuantity: buyQuantity,
        sellQuantity: sellQuantity,
        volume: volume,
        averagePrice: averagePrice,
        oi: oi,
        oiDayHigh: oiDayHigh,
        oiDayLow: oiDayLow,
        netChange: netChange,
        lowerCircuitLimit: lowerCircuitLimit,
        upperCircuitLimit: upperCircuitLimit,
        ohlc: ohlc,
        historyFiveMin: historyFiveMin ?? this.historyFiveMin,
      );
}
