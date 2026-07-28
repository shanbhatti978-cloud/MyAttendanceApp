import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/employee.dart';
import '../models/attendance.dart';
import '../utils/constants.dart';

/// Single source of truth for the local SQLite database.
/// Everything the app needs is stored on-device — nothing ever leaves
/// the phone, and no network connection is required at any point.
class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  /// Full path to the .db file — used by Backup/Restore screen.
  Future<String> get dbPath async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'rams_attendance.db');
  }

  Future<Database> _initDB() async {
    final path = await dbPath;
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        designation TEXT NOT NULL,
        shift TEXT NOT NULL,
        weekly_rest_day TEXT NOT NULL,
        joining_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Active',
        remarks TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
        UNIQUE (employee_id, date) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Default admin login: admin / admin123 (hashed, never stored in plain text)
    await db.insert('users', {
      'username': 'admin',
      'password_hash': _hash('admin123'),
      'role': AppConstants.roleAdmin,
    });

    // Default supervisor login: supervisor / super123
    await db.insert('users', {
      'username': 'supervisor',
      'password_hash': _hash('super123'),
      'role': AppConstants.roleSupervisor,
    });

    await db.insert('settings', {'key': 'company_name', 'value': 'My Company'});
    await db.insert('settings', {'key': 'company_address', 'value': ''});
    await db.insert('settings', {'key': 'company_phone', 'value': ''});
  }

  String _hash(String input) => sha256.convert(utf8.encode(input)).toString();

  // ---------------- AUTH ----------------

  /// Returns the matching user row (with role) if credentials are correct,
  /// otherwise null.
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, _hash(password)],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> changePassword(String username, String oldPassword, String newPassword) async {
    final db = await database;
    final user = await login(username, oldPassword);
    if (user == null) return false;
    final count = await db.update(
      'users',
      {'password_hash': _hash(newPassword)},
      where: 'username = ?',
      whereArgs: [username],
    );
    return count > 0;
  }

  // ---------------- EMPLOYEES ----------------

  Future<int> insertEmployee(Employee e) async {
    final db = await database;
    return db.insert('employees', e.toMap()..remove('id'));
  }

  Future<int> updateEmployee(Employee e) async {
    final db = await database;
    return db.update('employees', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<int> deleteEmployee(int id) async {
    final db = await database;
    return db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Employee>> getEmployees({String query = '', String statusFilter = 'All', String shiftFilter = 'All'}) async {
    final db = await database;
    String where = '';
    List<Object?> args = [];

    if (query.trim().isNotEmpty) {
      where += '(name LIKE ? OR employee_code LIKE ? OR designation LIKE ?)';
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }
    if (statusFilter != 'All') {
      if (where.isNotEmpty) where += ' AND ';
      where += 'status = ?';
      args.add(statusFilter);
    }
    if (shiftFilter != 'All') {
      if (where.isNotEmpty) where += ' AND ';
      where += 'shift = ?';
      args.add(shiftFilter);
    }

    final rows = await db.query(
      'employees',
      where: where.isEmpty ? null : where,
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return rows.map((r) => Employee.fromMap(r)).toList();
  }

  /// Distinct shift names currently in use — powers the Shift-Wise Report
  /// filter dropdown so it always reflects real data, including any
  /// custom shift names (not just the built-in Morning/Evening/Night).
  Future<List<String>> getDistinctShifts() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT DISTINCT shift FROM employees ORDER BY shift ASC');
    return rows.map((r) => r['shift'] as String).toList();
  }

  Future<Employee?> getEmployeeById(int id) async {
    final db = await database;
    final rows = await db.query('employees', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Employee.fromMap(rows.first);
  }

  Future<int> countEmployees({String status = 'Active'}) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM employees WHERE status = ?', [status]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------- ATTENDANCE ----------------

  /// Inserts or overwrites attendance for one employee on one date.
  /// The UNIQUE(employee_id, date) constraint (ON CONFLICT REPLACE)
  /// guarantees no duplicate rows are ever created — this is the
  /// "duplicate attendance protection" requirement.
  Future<void> upsertAttendance(AttendanceRecord record) async {
    final db = await database;
    await db.insert(
      'attendance',
      record.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAllAttendance(List<AttendanceRecord> records) async {
    final db = await database;
    final batch = db.batch();
    for (final r in records) {
      batch.insert('attendance', r.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Returns existing attendance for a given date, keyed by employee_id.
  Future<Map<int, String>> getAttendanceForDate(String date) async {
    final db = await database;
    final rows = await db.query('attendance', where: 'date = ?', whereArgs: [date]);
    return {for (final r in rows) r['employee_id'] as int: r['status'] as String};
  }

  /// Per-employee attendance status for one specific date — powers the
  /// Daily Attendance Report. Employees with no record yet for that date
  /// are reported as "Not Marked" rather than silently omitted.
  Future<List<Map<String, dynamic>>> getDailyReport(String date, {String shiftFilter = 'All'}) async {
    final employees = await getEmployees(statusFilter: 'Active', shiftFilter: shiftFilter);
    final existing = await getAttendanceForDate(date);
    return employees
        .map((e) => {
              'employee': e,
              'status': existing[e.id] ?? 'Not Marked',
            })
        .toList();
  }

  Future<Map<String, int>> getTodaySummary(String date) async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT status, COUNT(*) as c FROM attendance WHERE date = ? GROUP BY status', [date]);
    final map = <String, int>{
      AppConstants.present: 0,
      AppConstants.absent: 0,
      AppConstants.leave: 0,
      AppConstants.weeklyRest: 0,
    };
    for (final r in rows) {
      map[r['status'] as String] = r['c'] as int;
    }
    return map;
  }

  /// Monthly report: per-employee counts of each status + attendance %.
  /// Optionally restrict to a single shift for the Shift-Wise Report.
  Future<List<Map<String, dynamic>>> getMonthlyReport(int year, int month, {String shiftFilter = 'All'}) async {
    final db = await database;
    final monthStr = month.toString().padLeft(2, '0');
    final prefix = '$year-$monthStr';

    final employees = await getEmployees(
      statusFilter: 'Active',
      shiftFilter: shiftFilter,
    );
    final List<Map<String, dynamic>> report = [];

    for (final emp in employees) {
      final rows = await db.rawQuery('''
        SELECT status, COUNT(*) as c FROM attendance
        WHERE employee_id = ? AND date LIKE ?
        GROUP BY status
      ''', [emp.id, '$prefix%']);

      int present = 0, absent = 0, leaveCount = 0, rest = 0;
      for (final r in rows) {
        final s = r['status'] as String;
        final c = r['c'] as int;
        if (s == AppConstants.present) present = c;
        if (s == AppConstants.absent) absent = c;
        if (s == AppConstants.leave) leaveCount = c;
        if (s == AppConstants.weeklyRest) rest = c;
      }
      final totalMarked = present + absent + leaveCount + rest;
      final workingDays = totalMarked - rest; // exclude rest days from % base
      final pct = workingDays > 0 ? (present / workingDays * 100) : 0.0;

      report.add({
        'employee': emp,
        'present': present,
        'absent': absent,
        'leave': leaveCount,
        'weeklyRest': rest,
        'percentage': pct,
      });
    }
    return report;
  }

  // ---------------- SETTINGS ----------------

  Future<String> getSetting(String key, {String fallback = ''}) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return fallback;
    return rows.first['value'] as String? ?? fallback;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------- BIOMETRIC LOGIN ----------------

  /// Whether biometric (fingerprint/face) unlock is currently turned on.
  Future<bool> isBiometricEnabled() async {
    final v = await getSetting('biometric_enabled', fallback: 'false');
    return v == 'true';
  }

  /// Turns biometric unlock on and remembers WHICH account it should log
  /// in as (fingerprint unlock still needs to know which user/role to
  /// resume as — there's no password entry to identify them otherwise).
  Future<void> enableBiometric(String username, String role) async {
    await setSetting('biometric_enabled', 'true');
    await setSetting('biometric_username', username);
    await setSetting('biometric_role', role);
  }

  Future<void> disableBiometric() async {
    await setSetting('biometric_enabled', 'false');
  }

  /// The account that biometric unlock will resume as, or null if
  /// biometric login has never been set up.
  Future<Map<String, String>?> getBiometricAccount() async {
    final username = await getSetting('biometric_username');
    final role = await getSetting('biometric_role');
    if (username.isEmpty || role.isEmpty) return null;
    return {'username': username, 'role': role};
  }

  // ---------------- BACKUP / RESTORE ----------------

  /// Closes the DB handle so the raw file can be safely copied.
  Future<String> prepareBackupFile() async {
    final path = await dbPath;
    await _db?.close();
    _db = null;
    return path;
  }

  /// Copies a chosen backup file over the live database and reopens it.
  Future<void> restoreFromFile(String sourcePath) async {
    final target = await dbPath;
    await _db?.close();
    _db = null;
    final sourceFile = File(sourcePath);
    await sourceFile.copy(target);
    _db = await _initDB();
  }
}
