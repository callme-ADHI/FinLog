import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finlog.db');
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

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        merchant TEXT NOT NULL,
        utr TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        hash TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'SMS',
        description TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE transactions ADD COLUMN source TEXT NOT NULL DEFAULT 'SMS'");
      await db.execute("ALTER TABLE transactions ADD COLUMN description TEXT");
    }
  }

  Future<int> create(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
  }

  Future<List<Map<String, dynamic>>> readAll() async {
    final db = await instance.database;
    return await db.query('transactions', orderBy: 'timestamp DESC');
  }

  Future<int> update(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('transactions', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, Object?>?> readByUtr(String utr) async {
    final db = await instance.database;
    final maps = await db.query(
      'transactions',
      where: 'utr = ?',
      whereArgs: [utr],
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }
  
  // For deduplication checking
  Future<List<Map<String, dynamic>>> readRecent(int timestamp, int windowSeconds) async {
    final db = await instance.database;
    final start = timestamp - (windowSeconds * 1000);
    final end = timestamp + (windowSeconds * 1000);
    return await db.query(
      'transactions', 
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start, end]
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
