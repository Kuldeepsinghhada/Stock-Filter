import 'dart:developer';
import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/final_stock_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';

class DashboardService {
  DashboardService._internal();
  static final DashboardService instance = DashboardService._internal();

  final List<StockModel> _finalList = [];

  /// Fetch live quotes, apply filters and historical data checks
  Future<List<FinalStockModel>> fetchQuotes() async {
    await Utilities.loadStocksList();
    _finalList.clear();
    // Filter valid symbols
    final symbols =
        DataManager.instance.stocksList
            .where((s) => s.token != '#N/A')
            .map((s) => s.symbol)
            .whereType<String>()
            .toList();

    final allQuotes = await _fetchLiveDataInBatches(symbols, batchSize: 500);

    // Filter tradable stocks
    final quoteList = allQuotes.where(FilterUtils.isTradable).toList();
    log("First Filter Count: ${quoteList.length}");

    // Fetch historical data in throttled batches
    await _fetchHistoricalDataWithFilter(quoteList, maxCallsPerSecond: 12);

    Utilities.addAndShowNotification(_finalList);

    log(
      "Final Filtered Stocks Count: ${_finalList.length} \n${_finalList.map((e) => e.symbol).join(", ")}",
    );

    return _finalList.map((s) {
      final refStock = DataManager.instance.stocksList.indexWhere((obj) {
        return obj.token == s.token;
      });
      print(refStock);
      return FinalStockModel(
        dateTime: Utilities.formatDDMMMHHMMDateTime(DateTime.now()),
        stockSymbol: s.symbol,
        token: s.token,
        name: "",
        link: "",
        lastPrice: s.lastPrice,
        open: s.ohlc?.open,
        close: s.ohlc?.close,
      );
    }).toList();
  }

  /// Fetch live data in batches to reduce API calls
  Future<List<StockModel>> _fetchLiveDataInBatches(
    List<String> symbols, {
    int batchSize = 500,
  }) async {
    final allQuotes = <StockModel>[];

    for (var i = 0; i < symbols.length; i += batchSize) {
      final batch = symbols.skip(i).take(batchSize).toList();
      final batchSymbols = batch.map((s) => 'NSE:$s').join('&i=');

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
    List<StockModel> quoteList, {
    int maxCallsPerSecond = 12,
  }) async {
    List<StockModel> preFilteredList =
        []; // 👈 new list for only history != null

    for (var i = 0; i < quoteList.length; i += maxCallsPerSecond) {
      final batch = quoteList.skip(i).take(maxCallsPerSecond).toList();

      final batchResults = await Future.wait(
        batch.map((stock) async {
          try {
            final history = await fetchHistoricalData(
              int.tryParse(stock.token.toString()) ?? 0,
            );
            if (history != null) {
              // Add to preFilteredList 👈
              preFilteredList.add(
                stock.copyWith(
                  symbol: stock.symbol?.replaceAll("NSE:", ""),
                  historyFiveMin: history,
                ),
              );
              // Apply final filter check
              if (await FilterUtils.isPassAllTimeFrame(history, stock)) {
                return stock.copyWith(
                  symbol: stock.symbol?.replaceAll("NSE:", ""),
                  historyFiveMin: history,
                );
              }
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
  ) async {
    final interval = "5minute";
    final today = Utilities.getLastWorkingDay(DateTime.now());
    final from = Utilities.getBusinessDaysAgo(today, 20);
    final to =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final response = await ApiService.instance.apiCall(
      "${APIEndPoint.getHistoricalData}$instrumentToken/$interval?from=$from&to=$to",
      HttpRequestType.get,
      null,
    );

    if (response.status) {
      final candles =
          (response.data["data"]["candles"] as List<dynamic>?) ?? [];
      return candles
          .map((e) => HistoricalDataModel.fromList(e as List<dynamic>))
          .toList();
    } else {
      log("Error fetching historical data: ${response.error}");
      return null;
    }
  }

  /// Choppy stock utility (loose filter)
  bool isChoppyStockLoose(
    List<double> highs,
    List<double> lows,
    List<double> closes, {
    double threshold = 0.06,
    int atrPeriod = 10,
  }) {
    if (highs.length < atrPeriod ||
        lows.length < atrPeriod ||
        closes.length < atrPeriod) {
      return false;
    }

    final lastHighs = highs.sublist(highs.length - atrPeriod);
    final lastLows = lows.sublist(lows.length - atrPeriod);
    final lastCloses = closes.sublist(closes.length - atrPeriod);

    final tr = List.generate(lastCloses.length - 1, (i) {
      final hL = lastHighs[i + 1] - lastLows[i + 1];
      final hC = (lastHighs[i + 1] - lastCloses[i]).abs();
      final lC = (lastLows[i + 1] - lastCloses[i]).abs();
      return [hL, hC, lC].reduce((a, b) => a > b ? a : b);
    });

    final atr = tr.reduce((a, b) => a + b) / tr.length;
    final avgClose = lastCloses.reduce((a, b) => a + b) / lastCloses.length;
    return (atr / avgClose) < threshold;
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
