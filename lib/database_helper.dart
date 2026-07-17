import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _dbName = 'seismograf.db';
  static const int _dbVersion = 1;

  static const String tableMonitoringSessions = 'monitoring_sessions';
  static const String tableVibrationLogs = 'vibration_logs';

  // Columns for monitoring_sessions
  static const String colSessionId = 'id';
  static const String colStartTime = 'start_time';
  static const String colEndTime = 'end_time';
  static const String colMaxVibration = 'max_vibration';
  static const String colAvgVibration = 'avg_vibration';

  // Columns for vibration_logs
  static const String colLogId = 'id';
  static const String colSessionFk = 'session_id';
  static const String colTimestamp = 'timestamp';
  static const String colMagnitude = 'magnitude';
  static const String colIsManual = 'is_manual';

  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create monitoring_sessions table
    await db.execute('''
      CREATE TABLE $tableMonitoringSessions (
        $colSessionId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colStartTime TEXT NOT NULL,
        $colEndTime TEXT,
        $colMaxVibration REAL NOT NULL,
        $colAvgVibration REAL NOT NULL
      )
      ''');

    // Create vibration_logs table
    await db.execute('''
      CREATE TABLE $tableVibrationLogs (
        $colLogId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colSessionFk INTEGER NOT NULL,
        $colTimestamp TEXT NOT NULL,
        $colMagnitude REAL NOT NULL,
        $colIsManual INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY ($colSessionFk) REFERENCES $tableMonitoringSessions ($colSessionId) ON DELETE CASCADE
      )
      ''');

    // Create indexes for performance optimization
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_session_id ON $tableVibrationLogs ($colSessionFk);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_timestamp ON $tableVibrationLogs ($colTimestamp);',
    );
  }

  // ===== Session Operations =====

  /// Create a new monitoring session and return its ID
  Future<int> createSession(String startTime) async {
    final db = await database;
    return await db.insert(tableMonitoringSessions, {
      colStartTime: startTime,
      colMaxVibration: 0.0,
      colAvgVibration: 0.0,
    });
  }

  /// End a session with final calculations
  Future<void> endSession(
    int sessionId,
    String endTime,
    double maxVibration,
    double avgVibration,
  ) async {
    final db = await database;
    await db.update(
      tableMonitoringSessions,
      {
        colEndTime: endTime,
        colMaxVibration: maxVibration,
        colAvgVibration: avgVibration,
      },
      where: '$colSessionId = ?',
      whereArgs: [sessionId],
    );
  }

  /// Fetch all sessions, ordered by start_time DESC
  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final db = await database;
    return await db.query(
      tableMonitoringSessions,
      orderBy: '$colStartTime DESC',
    );
  }

  /// Fetch sessions filtered by start and end date.
  Future<List<Map<String, dynamic>>> getSessionsBetweenDates({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await database;

    if (start == null && end == null) {
      return getAllSessions();
    }

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (start != null) {
      whereClauses.add('$colStartTime >= ?');
      whereArgs.add(start.toIso8601String());
    }

    if (end != null) {
      final endInclusive = end
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      whereClauses.add('$colStartTime <= ?');
      whereArgs.add(endInclusive.toIso8601String());
    }

    return await db.query(
      tableMonitoringSessions,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: '$colStartTime DESC',
    );
  }

  /// Fetch a specific session by ID
  Future<Map<String, dynamic>?> getSession(int sessionId) async {
    final db = await database;
    final result = await db.query(
      tableMonitoringSessions,
      where: '$colSessionId = ?',
      whereArgs: [sessionId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Delete a session (cascades to vibration_logs)
  Future<int> deleteSession(int sessionId) async {
    final db = await database;
    return await db.delete(
      tableMonitoringSessions,
      where: '$colSessionId = ?',
      whereArgs: [sessionId],
    );
  }

  // ===== Vibration Log Operations =====

  /// Insert a vibration log entry
  Future<int> insertVibrationLog(
    int sessionId,
    String timestamp,
    double magnitude,
    int isManual,
  ) async {
    final db = await database;
    return await db.insert(tableVibrationLogs, {
      colSessionFk: sessionId,
      colTimestamp: timestamp,
      colMagnitude: magnitude,
      colIsManual: isManual,
    });
  }

  /// Fetch all logs for a session
  Future<List<Map<String, dynamic>>> getSessionLogs(int sessionId) async {
    final db = await database;
    return await db.query(
      tableVibrationLogs,
      where: '$colSessionFk = ?',
      whereArgs: [sessionId],
      orderBy: '$colTimestamp ASC',
    );
  }

  /// Fetch logs with automatic downsampling for large datasets
  Future<List<Map<String, dynamic>>> getSessionLogsWithDownsampling(
    int sessionId, {
    int maxPoints = 150,
  }) async {
    final db = await database;
    final allLogs = await db.query(
      tableVibrationLogs,
      where: '$colSessionFk = ?',
      whereArgs: [sessionId],
      orderBy: '$colTimestamp ASC',
    );

    if (allLogs.length <= maxPoints) {
      return allLogs;
    }

    // LTTB-inspired downsampling: take every Nth point
    final downSamplingFactor = (allLogs.length / maxPoints).ceil();
    final downSampledLogs = <Map<String, dynamic>>[];

    for (int i = 0; i < allLogs.length; i += downSamplingFactor) {
      downSampledLogs.add(allLogs[i]);
    }

    // Always include the last point for accurate max value
    if (downSampledLogs.last != allLogs.last) {
      downSampledLogs.add(allLogs.last);
    }

    return downSampledLogs;
  }

  /// Calculate stats for a session
  Future<Map<String, dynamic>> calculateSessionStats(int sessionId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        MAX($colMagnitude) as max_mag,
        AVG($colMagnitude) as avg_mag,
        COUNT(*) as count
      FROM $tableVibrationLogs
      WHERE $colSessionFk = ?
      ''',
      [sessionId],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return {'max_mag': 0.0, 'avg_mag': 0.0, 'count': 0};
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
