import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../model/historical_data_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('stocks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE candles ADD COLUMN interval TEXT DEFAULT "day"');
      // Update existing index to include interval
      await db.execute('DROP INDEX IF EXISTS idx_symbol_timestamp');
      await db.execute('CREATE INDEX idx_symbol_timestamp_interval ON candles (symbol, timestamp, interval)');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE candles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        symbol TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        open REAL NOT NULL,
        high REAL NOT NULL,
        low REAL NOT NULL,
        close REAL NOT NULL,
        volume REAL NOT NULL,
        interval TEXT DEFAULT "day",
        UNIQUE(symbol, timestamp, interval)
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_symbol_timestamp_interval ON candles (symbol, timestamp, interval)
    ''');
  }

  Future<void> insertCandles(String symbol, List<HistoricalDataModel> candles, {String interval = "day"}) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var candle in candles) {
      batch.insert(
        'candles',
        {
          'symbol': symbol,
          'timestamp': candle.timestamp.toIso8601String(),
          'open': candle.open,
          'high': candle.high,
          'low': candle.low,
          'close': candle.close,
          'volume': candle.volume.toDouble(),
          'interval': interval,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _pruneCandles(symbol, interval);
  }

  Future<void> _pruneCandles(String symbol, String interval) async {
    final db = await instance.database;
    
    // Check count for this specific symbol and interval
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM candles WHERE symbol = ? AND interval = ?',
      [symbol, interval],
    );
    
    int count = result.first['count'] as int;
    int limit = (interval == "day") ? 1000 : 5000; // Intraday might need more candles for 10 days
    
    if (count > limit) {
      int toDelete = count - limit;
      await db.rawDelete('''
        DELETE FROM candles 
        WHERE id IN (
          SELECT id FROM candles 
          WHERE symbol = ? AND interval = ? 
          ORDER BY timestamp ASC 
          LIMIT ?
        )
      ''', [symbol, interval, toDelete]);
    }
  }

  Future<List<HistoricalDataModel>> getCandles(String symbol, {String interval = "day"}) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'candles',
      where: 'symbol = ? AND interval = ?',
      whereArgs: [symbol, interval],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return HistoricalDataModel(
        timestamp: DateTime.parse(maps[i]['timestamp']),
        open: maps[i]['open'],
        high: maps[i]['high'],
        low: maps[i]['low'],
        close: maps[i]['close'],
        volume: maps[i]['volume'].toInt(),
      );
    });
  }

  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete('candles');
  }
}
