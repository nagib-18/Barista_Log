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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Table 1: Home Coffee
    await db.execute('''
    CREATE TABLE home_coffee (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      shot TEXT,
      brand TEXT,
      blend TEXT,
      review TEXT,
      rating INTEGER,
      date TEXT
    )
    ''');

    // Table 2: External Coffee (Cafe visits)
    await db.execute('''
    CREATE TABLE external_coffee (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      blend TEXT,
      cafe TEXT,
      city TEXT,
      country TEXT,
      notes TEXT,
      rating INTEGER,
      date TEXT
    )
    ''');
  }

  // --- HOME COFFEE FUNCTIONS ---
  Future<int> insertHome(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('home_coffee', row);
  }

  Future<List<Map<String, dynamic>>> getHomeLogs() async {
    final db = await instance.database;
    return await db.query('home_coffee', orderBy: 'date DESC');
  }

  // --- EXTERNAL COFFEE FUNCTIONS ---
  Future<int> insertExternal(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('external_coffee', row);
  }

  Future<List<Map<String, dynamic>>> getExternalLogs() async {
    final db = await instance.database;
    return await db.query('external_coffee', orderBy: 'date DESC');
  }

  // --- DELETE FUNCTION ---
  Future<int> deleteItem(int id, String tableName) async {
    final db = await instance.database;
    return await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  // --- COUNT ---
  Future<int> getHomeCount() async {
    final db = await instance.database;
    var x = await db.rawQuery('SELECT COUNT (*) from home_coffee');
    int? count = Sqflite.firstIntValue(x);
    return count ?? 0;
  }
}
