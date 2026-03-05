import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('coffee_ratings_v1.db');
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
      onConfigure: (db) async {
        // WAL mode prevents data loss on crash / incomplete writes
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.rawQuery('PRAGMA synchronous=NORMAL');
      },
    );
  }

  // ── FRESH INSTALL (v2) ──────────────────────────────────────────────
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE home_coffee (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shot TEXT NOT NULL,
        brand TEXT,
        blend TEXT,
        review TEXT,
        rating REAL NOT NULL DEFAULT 3.0,
        date TEXT,
        weight_in REAL,
        weight_out REAL,
        ratio REAL,
        roast_id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE external_coffee (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        blend TEXT,
        cafe TEXT,
        city TEXT,
        country TEXT,
        notes TEXT,
        rating REAL,
        date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE roasts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        brand TEXT,
        blend TEXT,
        rating REAL,
        notes TEXT,
        date TEXT,
        total_weight REAL,
        remaining_weight REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // ── MIGRATION v1 → v2 ──────────────────────────────────────────────
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE home_coffee ADD COLUMN weight_in REAL');
      await db.execute('ALTER TABLE home_coffee ADD COLUMN weight_out REAL');
      await db.execute('ALTER TABLE home_coffee ADD COLUMN ratio REAL');
      await db.execute('ALTER TABLE home_coffee ADD COLUMN roast_id INTEGER');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS roasts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          brand TEXT,
          blend TEXT,
          rating REAL,
          notes TEXT,
          date TEXT,
          total_weight REAL,
          remaining_weight REAL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }
  }

  // ── HOME COFFEE ─────────────────────────────────────────────────────
  Future<int> insertHome(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('home_coffee', row);
  }

  Future<List<Map<String, dynamic>>> getHomeLogs() async {
    final db = await instance.database;
    return await db.query('home_coffee', orderBy: 'date DESC');
  }

  Future<Map<String, dynamic>?> getHomeEntry(int id) async {
    final db = await instance.database;
    final r = await db.query('home_coffee', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  // ── EXTERNAL COFFEE ─────────────────────────────────────────────────
  Future<int> insertExternal(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('external_coffee', row);
  }

  Future<List<Map<String, dynamic>>> getExternalLogs() async {
    final db = await instance.database;
    return await db.query('external_coffee', orderBy: 'date DESC');
  }

  // ── ROASTS ──────────────────────────────────────────────────────────
  Future<int> insertRoast(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('roasts', row);
  }

  Future<List<Map<String, dynamic>>> getRoasts() async {
    final db = await instance.database;
    return await db.query('roasts', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getActiveRoasts() async {
    final db = await instance.database;
    return await db.query('roasts',
        where: 'remaining_weight > 0', orderBy: 'date DESC');
  }

  Future<int> updateRoastRating(int roastId, double newRating) async {
    final db = await instance.database;
    return await db.update(
      'roasts',
      {'rating': newRating},
      where: 'id = ?',
      whereArgs: [roastId],
    );
  }

  Future<int> updateRoastWeight(int roastId, double deduction) async {
    final db = await instance.database;
    return await db.rawUpdate(
      'UPDATE roasts SET remaining_weight = MAX(remaining_weight - ?, 0) WHERE id = ?',
      [deduction, roastId],
    );
  }

  Future<int> restoreRoastWeight(int roastId, double amount) async {
    final db = await instance.database;
    return await db.rawUpdate(
      'UPDATE roasts SET remaining_weight = MIN(remaining_weight + ?, total_weight) WHERE id = ?',
      [amount, roastId],
    );
  }

  Future<int> deleteRoast(int id) async {
    final db = await instance.database;
    return await db.delete('roasts', where: 'id = ?', whereArgs: [id]);
  }

  // ── DELETE ──────────────────────────────────────────────────────────
  Future<int> deleteItem(int id, String tableName) async {
    final db = await instance.database;
    return await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  // ── COUNT ───────────────────────────────────────────────────────────
  Future<int> getHomeCount() async {
    final db = await instance.database;
    var x = await db.rawQuery('SELECT COUNT(*) from home_coffee');
    return Sqflite.firstIntValue(x) ?? 0;
  }

  // ── SETTINGS ────────────────────────────────────────────────────────
  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final r = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return r.isNotEmpty ? r.first['value'] as String? : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── DISTINCT VALUES (for dashboard filters) ────────────────────────
  Future<List<String>> getDistinctHomeValues(String column) async {
    final db = await instance.database;
    final r = await db.rawQuery(
      "SELECT DISTINCT $column FROM home_coffee WHERE $column IS NOT NULL AND $column != '' ORDER BY $column",
    );
    return r.map((row) => row[column] as String).toList();
  }

  Future<List<String>> getDistinctExternalValues(String column) async {
    final db = await instance.database;
    final r = await db.rawQuery(
      "SELECT DISTINCT $column FROM external_coffee WHERE $column IS NOT NULL AND $column != '' ORDER BY $column",
    );
    return r.map((row) => row[column] as String).toList();
  }

  // ── FILTERED DASHBOARD QUERIES ─────────────────────────────────────
  Future<Map<String, dynamic>> getHomeStats({
    String? brand,
    String? blend,
    String? shot,
  }) async {
    final db = await instance.database;
    final where = <String>[];
    final args = <dynamic>[];
    if (brand != null && brand.isNotEmpty) {
      where.add("brand = ?");
      args.add(brand);
    }
    if (blend != null && blend.isNotEmpty) {
      where.add("blend = ?");
      args.add(blend);
    }
    if (shot != null && shot.isNotEmpty) {
      where.add("shot = ?");
      args.add(shot);
    }
    final wc = where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';
    final and = wc.isEmpty ? 'WHERE' : '$wc AND';

    final total = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM home_coffee $wc', args)) ??
        0;
    final avgR =
        await db.rawQuery('SELECT AVG(rating) as v FROM home_coffee $wc', args);
    final avgRating = (avgR.first['v'] as num?)?.toDouble() ?? 0.0;

    final bestBlendR = await db.rawQuery(
      "SELECT blend, AVG(rating) as avg_r FROM home_coffee $and blend IS NOT NULL AND blend != '' GROUP BY blend ORDER BY avg_r DESC LIMIT 1",
      args,
    );
    final bestBrandR = await db.rawQuery(
      "SELECT brand, AVG(rating) as avg_r FROM home_coffee $and brand IS NOT NULL AND brand != '' GROUP BY brand ORDER BY avg_r DESC LIMIT 1",
      args,
    );
    final ratioR = await db.rawQuery(
      'SELECT AVG(ratio) as v FROM home_coffee $and ratio IS NOT NULL',
      args,
    );

    return {
      'total': total,
      'avgRating': avgRating,
      'bestBlend': bestBlendR.isNotEmpty ? bestBlendR.first['blend'] : null,
      'bestBlendRating': bestBlendR.isNotEmpty
          ? (bestBlendR.first['avg_r'] as num?)?.toDouble()
          : null,
      'bestBrand': bestBrandR.isNotEmpty ? bestBrandR.first['brand'] : null,
      'bestBrandRating': bestBrandR.isNotEmpty
          ? (bestBrandR.first['avg_r'] as num?)?.toDouble()
          : null,
      'avgRatio': (ratioR.first['v'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<Map<String, dynamic>> getExternalStats({
    String? city,
    String? country,
  }) async {
    final db = await instance.database;
    final where = <String>[];
    final args = <dynamic>[];
    if (city != null && city.isNotEmpty) {
      where.add("city = ?");
      args.add(city);
    }
    if (country != null && country.isNotEmpty) {
      where.add("country = ?");
      args.add(country);
    }
    final wc = where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';
    final and = wc.isEmpty ? 'WHERE' : '$wc AND';

    final total = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM external_coffee $wc', args)) ??
        0;
    final avgR = await db.rawQuery(
        'SELECT AVG(rating) as v FROM external_coffee $wc', args);
    final avgRating = (avgR.first['v'] as num?)?.toDouble() ?? 0.0;

    final bestCafeR = await db.rawQuery(
      "SELECT cafe, AVG(rating) as avg_r FROM external_coffee $and cafe IS NOT NULL AND cafe != '' GROUP BY cafe ORDER BY avg_r DESC LIMIT 1",
      args,
    );
    final bestCityR = await db.rawQuery(
      "SELECT city, AVG(rating) as avg_r FROM external_coffee $and city IS NOT NULL AND city != '' GROUP BY city ORDER BY avg_r DESC LIMIT 1",
      args,
    );
    final cityRatings = await db.rawQuery(
      "SELECT city, AVG(rating) as avg_r, COUNT(*) as cnt FROM external_coffee $and city IS NOT NULL AND city != '' GROUP BY city ORDER BY avg_r DESC",
      args,
    );

    return {
      'total': total,
      'avgRating': avgRating,
      'bestCafe': bestCafeR.isNotEmpty ? bestCafeR.first['cafe'] : null,
      'bestCafeRating': bestCafeR.isNotEmpty
          ? (bestCafeR.first['avg_r'] as num?)?.toDouble()
          : null,
      'bestCity': bestCityR.isNotEmpty ? bestCityR.first['city'] : null,
      'bestCityRating': bestCityR.isNotEmpty
          ? (bestCityR.first['avg_r'] as num?)?.toDouble()
          : null,
      'cityRatings': cityRatings,
    };
  }
}
