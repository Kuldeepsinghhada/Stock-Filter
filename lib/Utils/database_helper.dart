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
      version: 1,
      onCreate: _createDB,
    );
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
        UNIQUE(symbol, timestamp)
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_symbol_timestamp ON candles (symbol, timestamp)
    ''');
  }

  Future<void> insertCandles(String symbol, List<HistoricalDataModel> candles) async {
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _pruneCandles(symbol);
  }

  Future<void> _pruneCandles(String symbol) async {
    final db = await instance.database;
    
    // Check if more than 1000 candles exist for this symbol
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM candles WHERE symbol = ?',
      [symbol],
    );
    
    int count = result.first['count'] as int;
    
    if (count > 1000) {
      int toDelete = count - 1000;
      await db.rawDelete('''
        DELETE FROM candles 
        WHERE id IN (
          SELECT id FROM candles 
          WHERE symbol = ? 
          ORDER BY timestamp ASC 
          LIMIT ?
        )
      ''', [symbol, toDelete]);
    }
  }

  Future<List<HistoricalDataModel>> getCandles(String symbol) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'candles',
      where: 'symbol = ?',
      whereArgs: [symbol],
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
