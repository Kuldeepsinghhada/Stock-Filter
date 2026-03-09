import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';

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
    final allQuotes = await _fetchLiveDataInBatches(symbols, batchSize: 500);
    // Fetch historical data in throttled batches

    final quoteList = allQuotes.where(FilterUtils.isDayTradable).toList();
    await _fetchHistoricalDataWithFilter(
      quoteList,
      toDate,
      isRefresh: isRefresh,
      maxCallsPerSecond: 12,
    );

    Utilities.addAndShowNotification(_finalList);

    log(
      "Final Filtered Stocks Count: ${_finalList.length} \n${_finalList.map((e) => e.symbol).join(", ")}",
    );

    return _finalList;
  }

  /// Fetch live data in batches to reduce API calls
  Future<List<StockModel>> _fetchLiveDataInBatches(
    List<String> symbols, {
    int batchSize = 500,
  }) async {
    final allQuotes = <StockModel>[];

    for (var i = 0; i < symbols.length; i += batchSize) {
      final batch = symbols.skip(i).take(batchSize).toList();
      final batchSymbols = batch.map((s) => 'i=NSE:$s').join('&');
      final response = await ApiService.instance.apiCall(
        APIEndPoint.getLiveStocksData + batchSymbols,
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
    List<StockModel> preFilteredList =
        []; // 👈 new list for only history != null

    // Check connectivity for offline mode strategy
    final connectivityResult = await (Connectivity().checkConnectivity());
    final bool hasInternet =
        !connectivityResult.contains(ConnectivityResult.none);

    for (var i = 0; i < quoteList.length; i += maxCallsPerSecond) {
      final batch = quoteList.skip(i).take(maxCallsPerSecond).toList();
      bool didAPICall = false;

      final batchResults = await Future.wait(
        batch.map((stock) async {
          try {
            // prepare cleaned symbol
            final cleanedSymbol = stock.symbol?.replaceAll("NSE:", "");
            if (cleanedSymbol == null) return null;

            List<HistoricalDataModel>? history;

            if (isRefresh) {
              // Read local data first
              final localData = await _readLocalHistory(cleanedSymbol);
              if (localData != null && localData.isNotEmpty) {
                final lastDate = localData.last.timestamp;
                final today = DateTime.now();

                if (lastDate.isBefore(
                        DateTime(today.year, today.month, today.day)) ||
                    (lastDate.year == today.year &&
                        lastDate.month == today.month &&
                        lastDate.day == today.day)) {
                  if (!hasInternet) {
                    history = localData;
                    lastLocalCount++;
                  } else {
                    final fetchFromDate = (lastDate.year == today.year &&
                            lastDate.month == today.month &&
                            lastDate.day == today.day)
                        ? lastDate
                        : lastDate.add(const Duration(days: 1));

                    didAPICall = true;
                    final newHistory = await fetchHistoricalData(
                      int.tryParse(stock.token.toString()) ?? 0,
                      toDate,
                      fromDate: fetchFromDate,
                      symbols: [cleanedSymbol],
                    );

                    if (newHistory != null && newHistory.isNotEmpty) {
                      localData.addAll(newHistory);
                      final Map<String, HistoricalDataModel> mapDistinct = {};
                      for (var d in localData) {
                        final dateKey =
                            "${d.timestamp.year}-${d.timestamp.month.toString().padLeft(2, '0')}-${d.timestamp.day.toString().padLeft(2, '0')}";
                        mapDistinct[dateKey] = d;
                      }
                      history = mapDistinct.values.toList()
                        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                      await _writeLocalHistory(cleanedSymbol, history);
                      lastApiCount++; // We updated from API
                    } else {
                      history = localData;
                      lastLocalCount++;
                    }
                  }
                } else {
                  // Up to date
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
                    await _writeLocalHistory(cleanedSymbol, history);
                    lastApiCount++;
                  } else {
                    lastUnavailableList.add(cleanedSymbol);
                  }
                }
              }
            } else {
              // Not refresh, just read local. If no local, fetch full & save.
              history = await _readLocalHistory(cleanedSymbol);
              if (history != null && history.isNotEmpty) {
                lastLocalCount++;
              } else {
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
                    await _writeLocalHistory(cleanedSymbol, history);
                    lastApiCount++;
                  } else {
                    lastUnavailableList.add(cleanedSymbol);
                  }
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
    log("PreFiltered List Count: ${preFilteredList.length}");
    log("Final Filtered List Count: ${_finalList.length}");
  }

  /// Fetch historical data for a given instrument token
  Future<List<HistoricalDataModel>?> fetchHistoricalData(
    int instrumentToken,
    DateTime toDate, {
    DateTime? fromDate,
    List<String>? symbols,
  }) async {
    final interval = "day";

    final from = fromDate != null
        ? "${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}"
        : Utilities.getBusinessDaysAgo(toDate, 1000);
    final toDateFinal = DateTime.now();
    final to =
        "${toDateFinal.year}-${toDateFinal.month.toString().padLeft(2, '0')}-${toDateFinal.day.toString().padLeft(2, '0')}";

    // Log useful debugging information including optional symbols list
    log(
      'Fetching history for token: $instrumentToken,from: $from to: $to, symbols: ${symbols?.join(',') ?? 'N/A'}',
    );

    final response = await ApiService.instance.apiCall(
      "${APIEndPoint.getHistoricalData}$instrumentToken/$interval?from=$from&to=$to",
      HttpRequestType.get,
      null,
    );

    if (response.status) {
      // Be defensive: ensure the response structure is as expected before casting
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

  Future<File> _getLocalFile(String symbol) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/history_$symbol.json');
  }

  Future<List<HistoricalDataModel>?> _readLocalHistory(String symbol) async {
    try {
      final file = await _getLocalFile(symbol);
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        return jsonList
            .map((e) => HistoricalDataModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      log('Error reading local history for $symbol: $e');
    }
    return null;
  }

  Future<void> _writeLocalHistory(
      String symbol, List<HistoricalDataModel> data) async {
    try {
      final file = await _getLocalFile(symbol);
      final List<dynamic> jsonList = data.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      log('Error writing local history for $symbol: $e');
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
