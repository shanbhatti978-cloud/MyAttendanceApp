import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/employee.dart';
import '../models/attendance.dart';
import '../utils/constants.dart';
import '../utils/data_bus.dart';

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
      // v2 added performance indexes; v3 adds the activity_log table
      // used by the Dashboard's Recent Activities feed. Both migrations
      // run automatically for anyone upgrading from an earlier install.
      version: 3,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  /// Runs for anyone updating from an earlier installed version of the
  /// app. Only additive, non-destructive changes belong here — existing
  /// employees/attendance/settings must never be touched or lost.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance (date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_employee ON attendance (employee_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_shift ON employees (shift)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_designation ON employees (designation)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_status ON employees (status)');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          description TEXT NOT NULL,
          icon_type TEXT NOT NULL DEFAULT 'info'
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_log (timestamp)');
    }
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

    // Indexes matter a lot here: attendance is filtered by date constantly
    // (Daily/Shift/Planning reports) and joined against employee_id on
    // every lookup. Without these, a factory with thousands of employees
    // and years of history would slow to a crawl as the table grows.
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance (date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_employee ON attendance (employee_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_shift ON employees (shift)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_designation ON employees (designation)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_status ON employees (status)');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_type TEXT NOT NULL DEFAULT 'info'
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_log (timestamp)');

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
    final id = await db.insert('employees', e.toMap()..remove('id'));
    await logActivity('Added employee "${e.name}" (${e.employeeCode})', iconType: 'employee');
    DataBus.instance.notifyChanged();
    return id;
  }

  Future<int> updateEmployee(Employee e) async {
    final db = await database;
    final count = await db.update('employees', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
    await logActivity('Updated employee "${e.name}" (${e.employeeCode})', iconType: 'employee');
    DataBus.instance.notifyChanged();
    return count;
  }

  Future<int> deleteEmployee(int id) async {
    final db = await database;
    final existing = await getEmployeeById(id);
    final count = await db.delete('employees', where: 'id = ?', whereArgs: [id]);
    await logActivity(
      'Removed employee "${existing?.name ?? '#$id'}"',
      iconType: 'employee',
    );
    DataBus.instance.notifyChanged();
    return count;
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

  /// Distinct designations currently in use — powers the designation
  /// filter on the Shift Planning report.
  Future<List<String>> getDistinctDesignations() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT DISTINCT designation FROM employees ORDER BY designation ASC');
    return rows.map((r) => r['designation'] as String).toList();
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
    final emp = await getEmployeeById(record.employeeId);
    final iconType = record.status == AppConstants.leave ? 'leave' : 'attendance';
    await logActivity(
      'Marked "${record.status}" for ${emp?.name ?? 'employee #${record.employeeId}'} on ${record.date}',
      iconType: iconType,
    );
    DataBus.instance.notifyChanged();
  }

  Future<void> saveAllAttendance(List<AttendanceRecord> records) async {
    final db = await database;
    final batch = db.batch();
    for (final r in records) {
      batch.insert('attendance', r.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    if (records.isNotEmpty) {
      await logActivity(
        'Saved attendance for ${records.length} employee(s) on ${records.first.date}',
        iconType: 'attendance',
      );
    }
    DataBus.instance.notifyChanged();
  }

  /// Deletes a single attendance/leave record (e.g. "undo" a leave entry
  /// that was marked by mistake), restoring the employee to "Not Marked"
  /// for that date.
  Future<void> deleteAttendance(int employeeId, String date) async {
    final db = await database;
    await db.delete('attendance', where: 'employee_id = ? AND date = ?', whereArgs: [employeeId, date]);
    final emp = await getEmployeeById(employeeId);
    await logActivity('Cleared attendance for ${emp?.name ?? 'employee #$employeeId'} on $date', iconType: 'attendance');
    DataBus.instance.notifyChanged();
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

  /// Live Shift Attendance Planning Report — tells a supervisor, BEFORE
  /// or DURING a shift, how much manpower is actually available:
  ///   - total employees assigned to the shift
  ///   - how many are on Leave / Weekly Rest (known in advance)
  ///   - how many are expected to be Present (total minus the above)
  ///   - how many are marked Absent / Present once attendance is finalized
  ///   - overall "available manpower" for production planning
  /// Also returns the same breakdown grouped by designation, and the
  /// per-employee list (so the screen can offer a name/employee filter
  /// without a second database round-trip).
  ///
  /// Employees with no attendance record yet for this date are NOT
  /// treated as absent — they're counted as part of "expected present"
  /// (unless it happens to be their weekly rest day), since attendance
  /// for a future or in-progress shift is often not finalized yet.
  Future<Map<String, dynamic>> getShiftPlanningReport(
    String date, {
    String shiftFilter = 'All',
    String designationFilter = 'All',
  }) async {
    final employees = await getEmployees(statusFilter: 'Active', shiftFilter: shiftFilter);
    final filtered = designationFilter == 'All'
        ? employees
        : employees.where((e) => e.designation == designationFilter).toList();
    final attendanceMap = await getAttendanceForDate(date);
    final weekday = AppConstants.weekdays[DateTime.parse(date).weekday - 1];

    final Map<String, Map<String, int>> byDesignation = {};
    int total = 0, leave = 0, weeklyRest = 0, present = 0, absent = 0, notMarked = 0;
    final List<Map<String, dynamic>> employeeRows = [];

    for (final e in filtered) {
      total++;
      final recorded = attendanceMap[e.id];
      final isRestDay = e.weeklyRestDay == weekday;
      String bucket;
      String displayStatus;

      if (recorded == AppConstants.leave) {
        leave++;
        bucket = 'leave';
        displayStatus = AppConstants.leave;
      } else if (recorded == AppConstants.weeklyRest) {
        weeklyRest++;
        bucket = 'weeklyRest';
        displayStatus = AppConstants.weeklyRest;
      } else if (recorded == AppConstants.absent) {
        absent++;
        bucket = 'absent';
        displayStatus = AppConstants.absent;
      } else if (recorded == AppConstants.present) {
        present++;
        bucket = 'present';
        displayStatus = AppConstants.present;
      } else if (isRestDay) {
        weeklyRest++;
        bucket = 'weeklyRest';
        displayStatus = AppConstants.weeklyRest;
      } else {
        notMarked++;
        bucket = 'notMarked';
        displayStatus = 'Expected Present';
      }

      employeeRows.add({'employee': e, 'status': displayStatus});

      final d = byDesignation.putIfAbsent(
          e.designation, () => {'total': 0, 'leave': 0, 'weeklyRest': 0, 'present': 0, 'absent': 0, 'notMarked': 0});
      d['total'] = d['total']! + 1;
      d[bucket] = (d[bucket] ?? 0) + 1;
    }

    final expectedPresent = total - leave - weeklyRest;
    final availableManpower = present + notMarked;

    final designationBreakdown = byDesignation.entries.map((entry) {
      final d = entry.value;
      final dTotal = d['total']!;
      final dLeave = d['leave'] ?? 0;
      final dRest = d['weeklyRest'] ?? 0;
      final dPresent = d['present'] ?? 0;
      final dAbsent = d['absent'] ?? 0;
      final dNotMarked = d['notMarked'] ?? 0;
      return {
        'designation': entry.key,
        'total': dTotal,
        'leave': dLeave,
        'weeklyRest': dRest,
        'present': dPresent,
        'absent': dAbsent,
        'expectedPresent': dTotal - dLeave - dRest,
        'availableManpower': dPresent + dNotMarked,
      };
    }).toList()
      ..sort((a, b) => (a['designation'] as String).compareTo(b['designation'] as String));

    return {
      'total': total,
      'leave': leave,
      'weeklyRest': weeklyRest,
      'present': present,
      'absent': absent,
      'notMarked': notMarked,
      'expectedPresent': expectedPresent,
      'availableManpower': availableManpower,
      'byDesignation': designationBreakdown,
      'employees': employeeRows,
    };
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

  /// Powers BOTH Dashboard charts (Monthly Attendance Chart and Leave
  /// Trend Chart) with a SINGLE grouped query across the requested date
  /// range — not one query per day — so it stays fast no matter how
  /// many days are requested or how much attendance history exists.
  /// Returns a map keyed by date (yyyy-MM-dd), each value itself a map
  /// of status -> count for that day.
  Future<Map<String, Map<String, int>>> getTrendData(DateTime start, DateTime end) async {
    final db = await database;
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    final rows = await db.rawQuery('''
      SELECT date, status, COUNT(*) as c FROM attendance
      WHERE date >= ? AND date <= ?
      GROUP BY date, status
    ''', [startStr, endStr]);

    final Map<String, Map<String, int>> result = {};
    for (final r in rows) {
      final date = r['date'] as String;
      final status = r['status'] as String;
      final count = r['c'] as int;
      result.putIfAbsent(date, () => {})[status] = count;
    }
    return result;
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

    // Single grouped query for the WHOLE month, regardless of how many
    // employees exist — this is the key fix for staying fast with
    // thousands of employees and years of history: no per-employee
    // round-trip to the database.
    final rows = await db.rawQuery('''
      SELECT employee_id, status, COUNT(*) as c FROM attendance
      WHERE date LIKE ?
      GROUP BY employee_id, status
    ''', ['$prefix%']);

    // employee_id -> {status: count}
    final Map<int, Map<String, int>> statusByEmployee = {};
    for (final r in rows) {
      final empId = r['employee_id'] as int;
      final status = r['status'] as String;
      final count = r['c'] as int;
      statusByEmployee.putIfAbsent(empId, () => {})[status] = count;
    }

    final List<Map<String, dynamic>> report = [];
    for (final emp in employees) {
      final counts = statusByEmployee[emp.id] ?? const {};
      final present = counts[AppConstants.present] ?? 0;
      final absent = counts[AppConstants.absent] ?? 0;
      final leaveCount = counts[AppConstants.leave] ?? 0;
      final rest = counts[AppConstants.weeklyRest] ?? 0;

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

  // ---------------- ACTIVITY LOG ----------------

  /// Records one line for the Dashboard's Recent Activities feed.
  /// [iconType] picks which icon the feed shows: employee, attendance,
  /// leave, backup, or info (default).
  Future<void> logActivity(String description, {String iconType = 'info'}) async {
    final db = await database;
    await db.insert('activity_log', {
      'timestamp': DateTime.now().toIso8601String(),
      'description': description,
      'icon_type': iconType,
    });
    // Keep the log from growing forever — only the most recent 200
    // entries are useful for a "recent activity" feed.
    await db.rawDelete('''
      DELETE FROM activity_log WHERE id NOT IN (
        SELECT id FROM activity_log ORDER BY timestamp DESC LIMIT 200
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getRecentActivities({int limit = 8}) async {
    final db = await database;
    return db.query('activity_log', orderBy: 'timestamp DESC', limit: limit);
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
    await logActivity('Database restored from backup', iconType: 'backup');
    DataBus.instance.notifyChanged();
  }
}
