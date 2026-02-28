import 'dart:developer';
import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';

class HistoryServices {
  HistoryServices._internal();
  static final HistoryServices instance = HistoryServices._internal();

  final List<StockModel> _finalList = [];

  /// Fetch live quotes, apply filters and historical data checks
  Future<List<StockModel>> fetchQuotes(
    DateTime toDate,
    List<String> symbols,
  ) async {
    await Utilities.loadStocksList();
    _finalList.clear();
    symbols.removeWhere((item) => (item.contains("ETF") || item.contains("SILVER") || item.contains("BEES")));
    final allQuotes = await _fetchLiveDataInBatches(symbols, batchSize: 500);
    // Fetch historical data in throttled batches
    await _fetchHistoricalDataWithFilter(
      allQuotes,
      toDate,
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
    int maxCallsPerSecond = 12,
  }) async {
    List<StockModel> preFilteredList =
        []; // 👈 new list for only history != null

    for (var i = 0; i < quoteList.length; i += maxCallsPerSecond) {
      final batch = quoteList.skip(i).take(maxCallsPerSecond).toList();

      final batchResults = await Future.wait(
        batch.map((stock) async {
          try {
            // prepare cleaned symbol
            final cleanedSymbol = stock.symbol?.replaceAll("NSE:", "");
            final history = await fetchHistoricalData(
              int.tryParse(stock.token.toString()) ?? 0,
              toDate,
              symbols: cleanedSymbol != null ? [cleanedSymbol] : null,
            );
            if (history != null) {
              return stock.copyWith(
                symbol: stock.symbol?.replaceAll("NSE:", ""),
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

      if (i + maxCallsPerSecond < quoteList.length) {
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
    List<String>? symbols,
  }) async {
    final interval = "day";

    final from = Utilities.getBusinessDaysAgo(toDate, 1000);
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
}

extension StockModelCopy on StockModel {
  StockModel copyWith({
    String? symbol,
    List<HistoricalDataModel>? historyFiveMin,
  }) => StockModel(
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
