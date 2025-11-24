import 'dart:developer';
import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/APIService/fundamental_service.dart';
import 'package:stock_demo/Screens/Dashboard/dashboard_services.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/Utils/filter_utils.dart';
import 'package:stock_demo/Utils/investment_utils.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/final_stock_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'package:stock_demo/model/historical_data_model.dart';

class InvestmentService {
  InvestmentService._internal();

  static final InvestmentService instance = InvestmentService._internal();

  final List<StockModel> _finalList = [];

  /// Fetch live quotes, apply filters and historical data checks
  Future<List<FinalStockModel>> fetchQuotes([DateTime? selectedDate]) async {
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
    final quoteList =
        allQuotes.where(FilterUtils.isReadyForInvestment).toList();
    log("First Filter Count: ${quoteList.length}");

    // Fetch historical data in throttled batches
    await _fetchHistoricalDataWithFilter(quoteList, 12, selectedDate);

    Utilities.addAndShowNotification(_finalList);

    log(
      "Final Filtered Stocks Count: ${_finalList.length} \n${_finalList.map((e) => e.symbol).join(", ")}",
    );

    return _finalList.map((s) {
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
    List<StockModel> quoteList,
    int maxCallsPerSecond, [
    DateTime? selectedDate,
  ]) async {
    List<StockModel> preFilteredList =
        []; // 👈 new list for only history != null

    for (var i = 0; i < quoteList.length; i += maxCallsPerSecond) {
      final batch = quoteList.skip(i).take(maxCallsPerSecond).toList();

      final batchResults = await Future.wait(
        batch.map((stock) async {
          try {
            final history = await fetchHistoricalData(
              int.tryParse(stock.token.toString()) ?? 0,
              selectedDate,
            );
            if (history != null) {
              // Apply final filter check
              if (InvestmentFilterModule.isInvestmentCandidate(history, stock)) {
                if (true) {
                  return stock.copyWith(
                    symbol: stock.symbol?.replaceAll("NSE:", ""),
                    historyFiveMin: history,
                  );
                } else {
                  log("❌ Stock Failed Supertrend Check: ${stock.symbol}");
                }
              }
            } else {
              log("❌ No historical data for ${stock.symbol}");
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
    int instrumentToken, [
    DateTime? selectedDate,
  ]) async {
    final interval = "15minute";
    // Use selectedDate if provided, otherwise use now
    final target = Utilities.getLastWorkingDay(selectedDate ?? DateTime.now());
    final from = Utilities.getBusinessDaysAgo(target, 60);
    final to =
        "${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}";

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

  /// Fetch live quotes, apply filters and historical data checks
  Future<List<FinalStockModel>> fetchFundamentalQuotes() async {
    await Utilities.loadStocksList();
    _finalList.clear();
    // Filter valid symbols
    final symbols =
        DataManager.instance.stocksList
            .where((s) => s.token != '#N/A')
            .map((s) => s.symbol)
            .whereType<String>()
            .toList();

    // for (int i = 0; i < symbols.length; i += 40) {
    //   final batch = symbols.skip(i).take(40).toList();
    final limitedSymbols = symbols.take(8).toList();
    final data = await FundamentalService.instance.fetchFundamentals(
      limitedSymbols,
    );
    print("FM DATA: $data");
    //await Future.delayed(Duration(milliseconds: 500)); // avoid rate limit
    //  }

    print("All fundamentals synced!");

    return [];
  }
}
