import 'dart:developer';
import 'package:intl/intl.dart';
import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/Utils/candle_utils.dart';
import 'package:stock_demo/model/historical_data_model.dart';

class IntradayService {
  // Private constructor for singleton
  IntradayService._internal();
  static final IntradayService instance = IntradayService._internal();

  /// Fetches 5-minute historical data and calculates volume averages for Today vs Yesterday.
  /// [token] The instrument token of the stock.
  /// [effectiveDateTime] The reference date and time (History date or Current time).
  Future<Map<String, dynamic>> calculateIntradayVolumeData({
    required String token,
    required DateTime effectiveDateTime,
  }) async {
    try {
      // 1. Prepare time range: Fetch 5 days to ensure we have enough candles for Yesterday + today
      final interval = "5minute";
      final from = Utilities.getBusinessDaysAgo(effectiveDateTime, 5);
      final to = DateFormat('yyyy-MM-dd HH:mm:ss').format(effectiveDateTime);

      // 2. API Call
      final response = await ApiService.instance.apiCall(
        "${APIEndPoint.getHistoricalData}$token/$interval?from=$from&to=$to",
        HttpRequestType.get,
        null,
      );

      if (response.status) {
        final List<dynamic> candlesRaw = response.data["data"]["candles"] ?? [];
        final List<HistoricalDataModel> candles = candlesRaw
            .map((e) => HistoricalDataModel.fromList(e as List<dynamic>))
            .toList();

        if (candles.isEmpty) {
          return {'error': 'No data returned from API'};
        }

        // 3. Group candles by date to identify "Today" and "Yesterday"
        final grouped = CandleUtils.groupByDate(candles);
        final sortedDates = grouped.keys.toList()..sort();

        if (sortedDates.length < 2) {
          return {'error': 'Insufficient historical days for comparison'};
        }

        // Identify 'Today' as the date of effectiveDateTime (regardless of whether it's the absolute last in API)
        final DateTime targetTodayDate = DateTime(effectiveDateTime.year,
            effectiveDateTime.month, effectiveDateTime.day);

        // Find the index of targetTodayDate in sorted dates
        int todayIndex =
            sortedDates.indexWhere((d) => d.isAtSameMomentAs(targetTodayDate));

        // If the exact selected date isn't in the data, find the closest one that is NOT after it
        if (todayIndex == -1) {
          todayIndex =
              sortedDates.lastIndexWhere((d) => d.isBefore(targetTodayDate));
        }

        if (todayIndex < 1) {
          return {
            'error': 'Insufficient history found before the selected date'
          };
        }

        final todayDate = sortedDates[todayIndex];
        final lastWorkDayDate = sortedDates[todayIndex - 1];

        final yesterdayCandles = grouped[lastWorkDayDate] ?? [];

        // Today's candles filtered by the target time within that SPECIFIC todayDate
        final todayCandles = (grouped[todayDate] ?? []).where((c) {
          // 1. Must be on the correct date (avoids picking later days if API returned more)
          final isSameDay = c.timestamp.year == todayDate.year &&
              c.timestamp.month == todayDate.month &&
              c.timestamp.day == todayDate.day;

          if (!isSameDay) return false;

          // 2. Must not be after the selected time (buffer of 1s to include the exact minute)
          return !c.timestamp
              .isAfter(effectiveDateTime.add(const Duration(seconds: 1)));
        }).toList();

        // --- CALCULATION LOGGING ---
        log("[INTRADAY CALC] Token: $token");
        log("[INTRADAY CALC] Yesterday (${DateFormat('dd-MM-yyyy').format(lastWorkDayDate)}): ${yesterdayCandles.length} candles used.");
        if (yesterdayCandles.isNotEmpty) {
          log("[INTRADAY CALC] Yesterday Range: ${DateFormat('HH:mm').format(yesterdayCandles.first.timestamp)} to ${DateFormat('HH:mm').format(yesterdayCandles.last.timestamp)}");
        }
        log("[INTRADAY CALC] Today (${DateFormat('dd-MM-yyyy').format(todayDate)}): ${todayCandles.length} candles used (Filter up to ${DateFormat('HH:mm').format(effectiveDateTime)}).");
        if (todayCandles.isNotEmpty) {
          log("[INTRADAY CALC] Today Range: ${DateFormat('HH:mm').format(todayCandles.first.timestamp)} to ${DateFormat('HH:mm').format(todayCandles.last.timestamp)}");
        }
        // ---------------------------

        // 4. Calculate Averages
        double yestAvgVol = 0;
        double todayAvgVol = 0;
        double lastPrice = 0;

        if (yesterdayCandles.isNotEmpty) {
          yestAvgVol =
              yesterdayCandles.map((c) => c.volume).reduce((a, b) => a + b) /
                  yesterdayCandles.length;
        }

        if (todayCandles.isNotEmpty) {
          todayAvgVol =
              todayCandles.map((c) => c.volume).reduce((a, b) => a + b) /
                  todayCandles.length;
          lastPrice = todayCandles.last.close;
        }

        // 5. Volume % Calculation
        double volPercent =
            (yestAvgVol > 0) ? (todayAvgVol / yestAvgVol) * 100 : 0;

        return {
          'yesterdayAvgVolume': yestAvgVol,
          'todayAvgVolume': todayAvgVol,
          'volumePercent': volPercent,
          'lastPrice': lastPrice,
          'error': null,
        };
      } else {
        return {'error': response.error};
      }
    } catch (e) {
      log("IntradayService Error: $e");
      return {'error': e.toString()};
    }
  }
}
