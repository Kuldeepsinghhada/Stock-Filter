import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:stock_demo/Services/notification_service.dart';
import 'package:stock_demo/Utils/candle_utils.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/history_model.dart';
import 'package:stock_demo/model/notification_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'filter_utils.dart';

class Utilities {
  static String formatIndianNumber(num value) {
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

  // --------Load stocks list from local JSON file--------
  static Future<void> loadStocksList() async {
    final String jsonString = await rootBundle.loadString('assets/main.json');
    final List<dynamic> jsonData = json.decode(jsonString);
    DataManager.instance.stocksList =
        jsonData.map((item) {
          return StockModel(
            symbol: item['tradingsymbol']?.toString(),
            name: item['name']?.toString(),
            token: item['instrument_token']?.toString(),
            sector:
                item['sector']
                    ?.toString(), // If sector is missing, will be null
          );
        }).toList();
  }

  // -----------Convert Live Data to StockModel-------------
  static List<StockModel> convertDataToStockModel(
    Map<String, dynamic> stockMap,
  ) {
    List<StockModel> stockList = [];
    stockMap.forEach((key, value) {
      final symbol = key.split(":").last;
      stockList.add(
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
    return stockList;
  }

  // ------------Notification Process---------------
  static Future<void> addAndShowNotification(List<StockModel> finalList) async {
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
        newStockSymbols.add("${stock.symbol!} - ${stock.lastPrice ?? ''}");
      }
    }

    // Add new notifications
    if (newStockSymbols.isNotEmpty) {
      notificationsList.add(
        NotificationModel(
          stocksNameList: newStockSymbols.join(','),
          time: Utilities.formatDDMMMHHMMDateTime(DateTime.now()),
        ),
      );
      // Show notification
      if (Platform.isAndroid) {
        await NotificationService.showNotification(
          title: "Stock Alert",
          body:
              "${newStockSymbols.join(', ')} \n ${Utilities.formatDDMMMHHMMDateTime(DateTime.now())}",
        );
      } else {
        final player = AudioPlayer();
        await player.play(AssetSource('not.wav'));
      }
      log(
        "Notification triggered at ${Utilities.formatDDMMMHHMMDateTime(DateTime.now())}",
      );
    }

    await SharedPreferenceHelper.instance.saveNotificationList(
      notificationsList,
    );
  }

  // -----------GET END DATE FOR HISTORICAL DATA -----------
  static DateTime getLastWorkingDay(DateTime now) {
    // --- Define market holidays for 2025 & 2026 ---
    final List<DateTime> holidays = [
      // ------- 2026 HOLIDAYS -------
      DateTime(2026, 1, 26), // Republic Day
      DateTime(2026, 3, 2), // Mahashivratri
      DateTime(2026, 3, 19), // Holi
      DateTime(2026, 3, 30), // Eid-ul-Fitr
      DateTime(2026, 4, 2), // Ram Navami
      DateTime(2026, 4, 14), // Dr. Ambedkar Jayanti
      DateTime(2026, 4, 17), // Good Friday
      DateTime(2026, 5, 1), // Maharashtra Day
      DateTime(2026, 8, 15), // Independence Day
      DateTime(2026, 8, 28), // Ganesh Chaturthi
      DateTime(2026, 10, 19), // Diwali (Laxmi Pujan)
      DateTime(2026, 10, 20), // Diwali (Balipratipada)
      DateTime(2026, 11, 24), // Gurunanak Jayanti
      DateTime(2026, 12, 25), // Christmas
    ];

    DateTime date = now;

    // --- Weekend adjustment ---
    if (date.weekday == DateTime.saturday) {
      date = date.subtract(const Duration(days: 1)); // Saturday → Friday
    } else if (date.weekday == DateTime.sunday) {
      date = date.subtract(const Duration(days: 2)); // Sunday → Friday
    } else if (date.weekday == DateTime.monday &&
        (date.hour < 9 || (date.hour == 9 && date.minute < 5))) {
      date = date.subtract(
        const Duration(days: 3),
      ); // Monday before 9:05 → Friday
    }

    // --- Check for holiday (loop backward until working day) ---
    while (holidays.any(
      (h) => h.year == date.year && h.month == date.month && h.day == date.day,
    )) {
      date = date.subtract(const Duration(days: 1));
      // If holiday falls on Monday, also skip weekend behind
      if (date.weekday == DateTime.sunday) {
        date = date.subtract(const Duration(days: 2));
      } else if (date.weekday == DateTime.saturday) {
        date = date.subtract(const Duration(days: 1));
      }
    }

    return date;
  }

  // -----------GET START DATE FOR HISTORICAL DATA -----------
  static String getBusinessDaysAgo(DateTime today, int businessDays) {
    DateTime date = today;
    int daysCounted = 0;
    while (daysCounted < businessDays) {
      date = date.subtract(const Duration(days: 1));
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        daysCounted++;
      }
    }
    final String fromDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return fromDate;
  }

  static List<HistoricalDataModel> resampleCandles(
    List<HistoricalDataModel> candles,
    Duration interval,
  ) {
    if (candles.isEmpty) return [];

    List<HistoricalDataModel> result = [];
    List<HistoricalDataModel> bucket = [];
    DateTime? bucketStart;

    for (var candle in candles) {
      final marketOpen = DateTime(
        candle.timestamp.year,
        candle.timestamp.month,
        candle.timestamp.day,
        9,
        15,
      );
      final marketClose = DateTime(
        candle.timestamp.year,
        candle.timestamp.month,
        candle.timestamp.day,
        15,
        30,
      );

      // skip anything outside market hours
      if (candle.timestamp.isBefore(marketOpen) ||
          candle.timestamp.isAfter(marketClose)) {
        continue;
      }

      // reset bucket start if it's a new day
      if (bucketStart == null || candle.timestamp.day != bucketStart.day) {
        // flush old bucket
        if (bucket.isNotEmpty) {
          result.add(_aggregate(bucket, bucketStart!));
          bucket.clear();
        }

        bucketStart = marketOpen;
      }

      // move bucketStart forward until candle fits
      while (candle.timestamp.isAfter(bucketStart!.add(interval))) {
        if (bucket.isNotEmpty) {
          result.add(_aggregate(bucket, bucketStart));
          bucket.clear();
        }
        bucketStart = bucketStart.add(interval);

        // stop creating buckets beyond market close
        if (bucketStart.isAfter(marketClose)) break;
      }

      // add candle to current bucket
      if (bucketStart.isBefore(marketClose.add(Duration(seconds: 1)))) {
        bucket.add(candle);
      }
    }

    // last bucket
    if (bucket.isNotEmpty && bucketStart != null) {
      result.add(_aggregate(bucket, bucketStart));
    }

    return result;
  }

  static HistoricalDataModel _aggregate(
    List<HistoricalDataModel> bucket,
    DateTime start,
  ) {
    return HistoricalDataModel(
      timestamp: start,
      open: bucket.first.open,
      high: bucket.map((c) => c.high).reduce((a, b) => a > b ? a : b),
      low: bucket.map((c) => c.low).reduce((a, b) => a < b ? a : b),
      close: bucket.last.close,
      volume: bucket.map((c) => c.volume).reduce((a, b) => a + b),
    );
  }

  /// Convert 5-min candles → Daily candles using `_aggregate`
  static List<HistoricalDataModel> convertToDaily(
    List<HistoricalDataModel> fiveMinCandles,
  ) {
    if (fiveMinCandles.isEmpty) return [];

    final Map<String, List<HistoricalDataModel>> grouped = {};

    for (var c in fiveMinCandles) {
      final dayKey =
          "${c.timestamp.year}-${c.timestamp.month}-${c.timestamp.day}";
      grouped.putIfAbsent(dayKey, () => []).add(c);
    }

    final daily = <HistoricalDataModel>[];
    for (var entry in grouped.entries) {
      final candles = entry.value;
      candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // mark bucket start as market open
      final bucketStart = DateTime(
        candles.first.timestamp.year,
        candles.first.timestamp.month,
        candles.first.timestamp.day,
        9,
        15,
      );
      // use existing aggregate
      daily.add(_aggregate(candles, bucketStart));
    }
    daily.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return daily;
  }

  static String formatDDMMMHHMMDateTime(DateTime dateTime) {
    final DateFormat formatter = DateFormat('dd MMM HH:mm');
    return formatter.format(dateTime);
  }

  static String timeKey(DateTime ts) {
    return "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";
  }

  /// Builds intraday scan history using
  /// last 20 trading days + today's candles till current time
  static Future<List<HistoryModel>> buildTodayHistory(
    List<HistoricalDataModel> candles,
    StockModel model,
  ) async {
    // 1️⃣ Sort candles
    candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final now = DateTime.now();
    final lastWorkingDay = getLastWorkingDay(now);

    final todayDate = DateTime(
      lastWorkingDay.year,
      lastWorkingDay.month,
      lastWorkingDay.day,
    );

    // 2️⃣ Group candles by date
    final groupedByDate = CandleUtils.groupByDate(candles);
    final tradingDates = groupedByDate.keys.toList()..sort();

    // 3️⃣ Get last 20 trading days (including today)
    final last20Dates =
        tradingDates
            .where((d) => !d.isAfter(todayDate))
            .toList()
            .reversed
            .take(20)
            .toList()
            .reversed
            .toList();

    // 4️⃣ Collect base history (full candles of last 20 days except today)
    final baseHistory = <HistoricalDataModel>[];
    for (final d in last20Dates) {
      if (d.isBefore(todayDate)) {
        baseHistory.addAll(groupedByDate[d]!);
      }
    }

    // 5️⃣ Today's candles only
    final todayCandles = groupedByDate[todayDate] ?? [];

    final List<HistoryModel> result = [];

    // 6️⃣ Iterate candle-by-candle for today
    for (final current in todayCandles) {
      // History till current candle (NO future candles)
      final historySoFar = [
        ...baseHistory,
        ...todayCandles.where((c) => !c.timestamp.isAfter(current.timestamp)),
      ];

      try {
        // final passed = await IndicatorUtils.isNearEMA20OrSupertrendAuto(
        //   historySoFar,
        // );

        final passed = await FilterUtils.isPassAllTimeFrame(
          historySoFar,
          model,
        );

        if (passed) {
          result.add(
            HistoryModel(
              dateTime: current.timestamp,
              price: current.close,
              isPassed: true,
            ),
          );
        }
      } catch (e, s) {
        log("Scanner error: $e");
        log(s.toString());
      }
    }

    return result;
  }

  static bool candleTillCandle(
    HistoricalDataModel candle,
    List<HistoricalDataModel> historySoFar,
  ) {
    if (historySoFar.isEmpty) return false;

    double lastHigh = historySoFar
        .map((c) => c.high)
        .fold<double>(-double.infinity, (a, b) => a > b ? a : b);

    return candle.close > lastHigh; // breakout
  }

  // LARGE CAP STOCKS
  // static const List<String> blockedSymbols = [
  //   "KALYANKJIL",
  //   "INDIANB",
  //   "SOLARINDS",
  //   "TATASTEEL",
  //   "POWERGRID",
  //   "WAAREEENER",
  //   "NATIONALUM",
  //   "MRF",
  //   "HINDPETRO",
  //   "OFSS",
  //   "DIVISLAB",
  //   "PREMIERENE",
  //   "TATAELXSI",
  //   "TATATECH",
  //   "AUBANK",
  //   "PERSISTENT",
  //   "ADANIENSOL",
  //   "HEROMOTOCO",
  //   "CUMMINSIND",
  //   "HINDZINC",
  //   "BHEL",
  //   "UPL",
  //   "HINDALCO",
  //   "SBICARD",
  //   "AXISBANK",
  //   "ABFRL",
  //   "PAGEIND",
  //   "KOTAKBANK",
  //   "CANBK",
  //   "LT",
  //   "MPHASIS",
  //   "TIINDIA",
  //   "PAYTM",
  //   "BANKBARODA",
  //   "BIOCON",
  //   "PETRONET",
  //   "PNB",
  //   "GAIL",
  //   "BHARTIARTL",
  //   "BEL",
  //   "BANDHANBNK",
  //   "POLICYBZR",
  //   "JUBLFOOD",
  //   "LTF",
  //   "SONACOMS",
  //   "MAZDOCK",
  //   "HAL",
  //   "ABCAPITAL",
  //   "SIEMENS",
  //   "JSWSTEEL",
  //   "TITAN",
  //   "CONCOR",
  //   "MARICO",
  //   "VEDL",
  //   "PATANJALI",
  //   "BDL",
  //   "NMDC",
  //   "MOTILALOFS",
  //   "UNITDSPR",
  //   "APOLLOTYRE",
  //   "ACC",
  //   "JINDALSTEL",
  //   "GLENMARK",
  //   "CGPOWER",
  //   "MAHABANK",
  //   "PIDILITIND",
  //   "DLF",
  //   "TATAPOWER",
  //   "ASIANPAINT",
  //   "PIIND",
  //   "IREDA",
  //   "INDIGO",
  //   "AMBUJACEM",
  //   "M&MFIN",
  //   "DIXON",
  //   "OIL",
  //   "VMM",
  //   "BOSCHLTD",
  //   "COFORGE",
  //   "RVNL",
  //   "EXIDEIND",
  //   "ICICIPRULI",
  //   "RECLTD",
  //   "MUTHOOTFIN",
  //   "BANKINDIA",
  //   "AUROPHARMA",
  //   "NHPC",
  //   "HDFCAMC",
  //   "JSWENERGY",
  //   "MOTHERSON",
  //   "BAJAJ-AUTO",
  //   "OBEROIRLTY",
  //   "BSE",
  //   "POLYCAB",
  //   "INDUSINDBK",
  //   "HUDCO",
  //   "SJVN",
  //   "JIOFIN",
  //   "BPCL",
  //   "ADANIGREEN",
  //   "ASTRAL",
  //   "VOLTAS",
  //   "NTPC",
  //   "SUPREMEIND",
  //   "IOC",
  //   "BRITANNIA",
  //   "SRF",
  //   "ICICIGI",
  //   "TORNTPOWER",
  //   "APLAPOLLO",
  //   "KPITTECH",
  //   "SBIN",
  //   "HINDUNILVR",
  //   "MANKIND",
  //   "CIPLA",
  //   "NESTLEIND",
  //   "INDUSTOWER",
  //   "HCLTECH",
  //   "DRREDDY",
  //   "PFC",
  //   "ONGC",
  //   "IRFC",
  //   "LICHSGFIN",
  //   "DABUR",
  //   "BAJFINANCE",
  //   "HAVELLS",
  //   "IRCTC",
  //   "INDHOTEL",
  //   "GODREJPROP",
  //   "LICI",
  //   "APOLLOHOSP",
  //   "VBL",
  //   "GRASIM",
  //   "INFY",
  //   "BHARATFORG",
  //   "TATACOMM",
  //   "BAJAJHFL",
  //   "GODREJCP",
  //   "SAIL",
  //   "IDFCFIRSTB",
  //   "IGL",
  //   "COCHINSHIP",
  //   "HDFCBANK",
  //   "M&M",
  //   "WIPRO",
  //   "TVSMOTOR",
  //   "LTIM",
  //   "GMRAIRPORT",
  //   "PHOENIXLTD",
  //   "ADANIENT",
  //   "ETERNAL",
  //   "ADANIPORTS",
  //   "ZYDUSLIFE",
  //   "ABB",
  //   "BAJAJFINSV",
  //   "SUNPHARMA",
  //   "TATAMOTORS",
  //   "ALKEM",
  //   "ITC",
  //   "TRENT",
  //   "NAUKRI",
  //   "SHREECEM",
  //   "LUPIN",
  //   "RELIANCE",
  //   "TCS",
  //   "SHRIRAMFIN",
  //   "COLPAL",
  //   "ICICIBANK",
  //   "NTPCGREEN",
  //   "ATGL",
  //   "NYKAA",
  //   "ULTRACEMCO",
  //   "HDFCLIFE",
  //   "TATACONSUM",
  //   "DMART",
  //   "FEDERALBNK",
  //   "UNIONBANK",
  //   "PRESTIGE",
  //   "SBILIFE",
  //   "SWIGGY",
  //   "MARUTI",
  //   "ASHOKLEY",
  //   "TECHM",
  //   "MFSL",
  //   "EICHERMOT",
  //   "HYUNDAI",
  //   "SUZLON",
  //   "BHARTIHEXA",
  //   "COALINDIA",
  //   "TORNTPHARM",
  //   "BAJAJHLDNG",
  //   "ESCORTS",
  //   "CHOLAFIN",
  //   "LODHA",
  //   "OLAELEC",
  //   "ADANIPOWER",
  //   "MAXHEALTH",
  // ];
}
