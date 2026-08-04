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
      // v2 added performance indexes; v3 added activity_log; v4 added
      // Department/Unit Number; v5 added Father Name/CNIC/Mobile Number,
      // leave_requests, notifications, and manpower_rules tables; v6
      // adds updated_at/is_synced columns used by cloud sync (Phase 8).
      // All migrations run automatically for anyone upgrading from an
      // earlier install — existing employees/attendance/settings are
      // never touched.
      version: 6,
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
    if (oldVersion < 4) {
      // ADD COLUMN with a default is non-destructive — every existing
      // employee simply gets an empty department/unit until edited.
      final cols = await db.rawQuery("PRAGMA table_info(employees)");
      final existingCols = cols.map((c) => c['name'] as String).toSet();
      if (!existingCols.contains('department')) {
        await db.execute("ALTER TABLE employees ADD COLUMN department TEXT NOT NULL DEFAULT ''");
      }
      if (!existingCols.contains('unit_number')) {
        await db.execute("ALTER TABLE employees ADD COLUMN unit_number TEXT NOT NULL DEFAULT ''");
      }
      await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_department ON employees (department)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_unit ON employees (unit_number)');
    }
    if (oldVersion < 5) {
      final cols = await db.rawQuery("PRAGMA table_info(employees)");
      final existingCols = cols.map((c) => c['name'] as String).toSet();
      if (!existingCols.contains('father_name')) {
        await db.execute("ALTER TABLE employees ADD COLUMN father_name TEXT NOT NULL DEFAULT ''");
      }
      if (!existingCols.contains('cnic')) {
        await db.execute("ALTER TABLE employees ADD COLUMN cnic TEXT NOT NULL DEFAULT ''");
      }
      if (!existingCols.contains('mobile_number')) {
        await db.execute("ALTER TABLE employees ADD COLUMN mobile_number TEXT NOT NULL DEFAULT ''");
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS leave_requests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL,
          leave_type TEXT NOT NULL,
          from_date TEXT NOT NULL,
          to_date TEXT NOT NULL,
          reason TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL DEFAULT 'Pending',
          applied_by TEXT NOT NULL DEFAULT '',
          applied_at TEXT NOT NULL,
          decided_by TEXT,
          decided_at TEXT,
          remarks TEXT NOT NULL DEFAULT '',
          FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_requests_status ON leave_requests (status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_requests_employee ON leave_requests (employee_id)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          message TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'info',
          related_id INTEGER,
          is_read INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications (created_at)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS manpower_rules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          designation TEXT UNIQUE NOT NULL,
          min_required INTEGER NOT NULL DEFAULT 0,
          max_required INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 6) {
      // updated_at + is_synced + cloud_id power the cloud sync layer:
      // updated_at is used for "last write wins" conflict resolution,
      // is_synced marks which local rows still need to be pushed to
      // Supabase, and cloud_id remembers the matching cloud row once a
      // local row has been pushed at least once (so later pushes UPDATE
      // instead of duplicating, and pulled-down cloud changes can be
      // matched back to the right local row). Every existing row is
      // treated as "not yet synced" so the very first sync after
      // upgrading uploads all of it.
      for (final table in ['employees', 'attendance', 'leave_requests', 'notifications', 'manpower_rules']) {
        final cols = await db.rawQuery("PRAGMA table_info($table)");
        final existingCols = cols.map((c) => c['name'] as String).toSet();
        if (!existingCols.contains('updated_at')) {
          await db.execute(
              "ALTER TABLE $table ADD COLUMN updated_at TEXT NOT NULL DEFAULT '${DateTime(2000).toIso8601String()}'");
        }
        if (!existingCols.contains('is_synced')) {
          await db.execute('ALTER TABLE $table ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
        }
        if (!existingCols.contains('cloud_id')) {
          await db.execute('ALTER TABLE $table ADD COLUMN cloud_id TEXT');
        }
      }
      await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_synced ON employees (is_synced)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_synced ON attendance (is_synced)');
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
        father_name TEXT NOT NULL DEFAULT '',
        cnic TEXT NOT NULL DEFAULT '',
        mobile_number TEXT NOT NULL DEFAULT '',
        designation TEXT NOT NULL,
        department TEXT NOT NULL DEFAULT '',
        unit_number TEXT NOT NULL DEFAULT '',
        shift TEXT NOT NULL,
        weekly_rest_day TEXT NOT NULL,
        joining_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Active',
        remarks TEXT DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT '',
        is_synced INTEGER NOT NULL DEFAULT 0,
        cloud_id TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_department ON employees (department)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_unit ON employees (unit_number)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_synced ON employees (is_synced)');

    await db.execute('''
      CREATE TABLE leave_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        leave_type TEXT NOT NULL,
        from_date TEXT NOT NULL,
        to_date TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'Pending',
        applied_by TEXT NOT NULL DEFAULT '',
        applied_at TEXT NOT NULL,
        decided_by TEXT,
        decided_at TEXT,
        remarks TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT '',
        is_synced INTEGER NOT NULL DEFAULT 0,
        cloud_id TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_requests_status ON leave_requests (status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_requests_employee ON leave_requests (employee_id)');

    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'info',
        related_id INTEGER,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT '',
        is_synced INTEGER NOT NULL DEFAULT 0,
        cloud_id TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications (created_at)');

    await db.execute('''
      CREATE TABLE manpower_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        designation TEXT UNIQUE NOT NULL,
        min_required INTEGER NOT NULL DEFAULT 0,
        max_required INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL DEFAULT '',
        is_synced INTEGER NOT NULL DEFAULT 0,
        cloud_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT '',
        is_synced INTEGER NOT NULL DEFAULT 0,
        cloud_id TEXT,
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

  // ---------------- USER MANAGEMENT (Admin only) ----------------

  /// All application users (id, username, role) — password hashes are
  /// never returned to the UI layer.
  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return db.query('users', columns: ['id', 'username', 'role'], orderBy: 'username ASC');
  }

  Future<int> countAdmins() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM users WHERE role = ?", [AppConstants.roleAdmin]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Creates a new user account. Returns an error message string on
  /// failure (e.g. duplicate username), or null on success.
  Future<String?> createUser(String username, String password, String role) async {
    final db = await database;
    try {
      await db.insert('users', {
        'username': username.trim(),
        'password_hash': _hash(password),
        'role': role,
      });
      await logActivity('Created user "$username" ($role)', iconType: 'employee');
      return null;
    } catch (e) {
      return 'Username "$username" is already taken.';
    }
  }

  /// Changes a user's role. Refuses if this would remove the very last
  /// Admin account, since that would permanently lock everyone out of
  /// user management and system settings.
  Future<String?> updateUserRole(int userId, String newRole) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return 'User not found.';
    final current = rows.first;

    if (current['role'] == AppConstants.roleAdmin && newRole != AppConstants.roleAdmin) {
      final adminCount = await countAdmins();
      if (adminCount <= 1) {
        return 'Cannot change this role — at least one Admin account must always remain.';
      }
    }

    await db.update('users', {'role': newRole}, where: 'id = ?', whereArgs: [userId]);
    await logActivity('Changed "${current['username']}" role to $newRole', iconType: 'employee');
    return null;
  }

  /// Admin-initiated password reset for another user (no old-password
  /// check needed, since Admin is trusted to manage all accounts).
  Future<void> resetUserPassword(int userId, String newPassword) async {
    final db = await database;
    await db.update('users', {'password_hash': _hash(newPassword)}, where: 'id = ?', whereArgs: [userId]);
  }

  /// Deletes a user account. Refuses if this is the last remaining Admin.
  Future<String?> deleteUser(int userId) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return 'User not found.';
    final user = rows.first;

    if (user['role'] == AppConstants.roleAdmin) {
      final adminCount = await countAdmins();
      if (adminCount <= 1) {
        return 'Cannot delete the last remaining Admin account.';
      }
    }

    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
    await logActivity('Removed user "${user['username']}"', iconType: 'employee');
    return null;
  }

  // ---------------- EMPLOYEES ----------------

  Future<int> insertEmployee(Employee e) async {
    final db = await database;
    final map = e.toMap()..remove('id');
    map['updated_at'] = DateTime.now().toIso8601String();
    map['is_synced'] = 0;
    final id = await db.insert('employees', map);
    await logActivity('Added employee "${e.name}" (${e.employeeCode})', iconType: 'employee');
    DataBus.instance.notifyChanged();
    return id;
  }

  Future<int> updateEmployee(Employee e) async {
    final db = await database;
    final map = e.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    map['is_synced'] = 0;
    final count = await db.update('employees', map, where: 'id = ?', whereArgs: [e.id]);
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

  Future<List<Employee>> getEmployees({
    String query = '',
    String statusFilter = 'All',
    String shiftFilter = 'All',
    String designationFilter = 'All',
    String departmentFilter = 'All',
    String unitFilter = 'All',
  }) async {
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
    if (designationFilter != 'All') {
      if (where.isNotEmpty) where += ' AND ';
      where += 'designation = ?';
      args.add(designationFilter);
    }
    if (departmentFilter != 'All') {
      if (where.isNotEmpty) where += ' AND ';
      where += 'department = ?';
      args.add(departmentFilter);
    }
    if (unitFilter != 'All') {
      if (where.isNotEmpty) where += ' AND ';
      where += 'unit_number = ?';
      args.add(unitFilter);
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

  /// Distinct departments in use (blank entries excluded) — powers the
  /// Department-Wise Report filter.
  Future<List<String>> getDistinctDepartments() async {
    final db = await database;
    final rows = await db.rawQuery(
        "SELECT DISTINCT department FROM employees WHERE department != '' ORDER BY department ASC");
    return rows.map((r) => r['department'] as String).toList();
  }

  /// Distinct unit numbers in use (blank entries excluded) — powers the
  /// Unit-Wise Report filter.
  Future<List<String>> getDistinctUnits() async {
    final db = await database;
    final rows = await db.rawQuery(
        "SELECT DISTINCT unit_number FROM employees WHERE unit_number != '' ORDER BY unit_number ASC");
    return rows.map((r) => r['unit_number'] as String).toList();
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
    final map = record.toMap()..remove('id');
    map['updated_at'] = DateTime.now().toIso8601String();
    map['is_synced'] = 0;
    await db.insert(
      'attendance',
      map,
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
    final now = DateTime.now().toIso8601String();
    for (final r in records) {
      final map = r.toMap()..remove('id');
      map['updated_at'] = now;
      map['is_synced'] = 0;
      batch.insert('attendance', map, conflictAlgorithm: ConflictAlgorithm.replace);
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

  /// Complete date-wise attendance history for ONE employee (the
  /// "Individual Employee History Report"), optionally bounded to a
  /// date range. Returns both the raw date-wise records and the
  /// summary totals (present/absent/leave/weekly rest/percentage) so
  /// the screen doesn't need a second query to show both.
  Future<Map<String, dynamic>> getEmployeeHistory(
    int employeeId, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await database;
    String where = 'employee_id = ?';
    final args = <Object?>[employeeId];
    if (fromDate != null) {
      where += ' AND date >= ?';
      args.add(fromDate);
    }
    if (toDate != null) {
      where += ' AND date <= ?';
      args.add(toDate);
    }

    final rows = await db.query('attendance', where: where, whereArgs: args, orderBy: 'date DESC');

    int present = 0, absent = 0, leaveCount = 0, rest = 0;
    for (final r in rows) {
      final status = r['status'] as String;
      if (status == AppConstants.present) present++;
      if (status == AppConstants.absent) absent++;
      if (status == AppConstants.leave) leaveCount++;
      if (status == AppConstants.weeklyRest) rest++;
    }
    final totalMarked = present + absent + leaveCount + rest;
    final workingDays = totalMarked - rest;
    final pct = workingDays > 0 ? (present / workingDays * 100) : 0.0;

    return {
      'records': rows.map((r) => {'date': r['date'] as String, 'status': r['status'] as String}).toList(),
      'totalMarked': totalMarked,
      'present': present,
      'absent': absent,
      'leave': leaveCount,
      'weeklyRest': rest,
      'percentage': pct,
    };
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
  Future<List<Map<String, dynamic>>> getMonthlyReport(
    int year,
    int month, {
    String shiftFilter = 'All',
    String designationFilter = 'All',
    String departmentFilter = 'All',
    String unitFilter = 'All',
  }) async {
    final db = await database;
    final monthStr = month.toString().padLeft(2, '0');
    final prefix = '$year-$monthStr';

    final employees = await getEmployees(
      statusFilter: 'Active',
      shiftFilter: shiftFilter,
      designationFilter: designationFilter,
      departmentFilter: departmentFilter,
      unitFilter: unitFilter,
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

  // ---------------- LEAVE REQUESTS (apply / approve / reject workflow) ----------------

  /// Submits a new leave request in "Pending" status. This is separate
  /// from the existing Advance Leave Entry (which marks attendance
  /// immediately) — this goes through an approval step first, and only
  /// updates attendance once Admin/Supervisor approves it.
  Future<void> createLeaveRequest({
    required int employeeId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String reason,
    required String appliedBy,
  }) async {
    final db = await database;
    await db.insert('leave_requests', {
      'employee_id': employeeId,
      'leave_type': leaveType,
      'from_date': fromDate,
      'to_date': toDate,
      'reason': reason,
      'status': 'Pending',
      'applied_by': appliedBy,
      'applied_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });

    final emp = await getEmployeeById(employeeId);
    await logActivity('Leave requested for ${emp?.name ?? 'employee'} ($leaveType)', iconType: 'leave');
    await createNotification(
      'New leave request: ${emp?.name ?? 'Employee'} ($leaveType, $fromDate to $toDate)',
      type: 'leave_request',
    );
    DataBus.instance.notifyChanged();
  }

  /// All leave requests, optionally filtered by status ("Pending",
  /// "Approved", "Rejected", or "All"), newest first, each joined with
  /// its employee record for display.
  Future<List<Map<String, dynamic>>> getLeaveRequests({String statusFilter = 'All'}) async {
    final db = await database;
    final rows = await db.query(
      'leave_requests',
      where: statusFilter == 'All' ? null : 'status = ?',
      whereArgs: statusFilter == 'All' ? null : [statusFilter],
      orderBy: 'applied_at DESC',
    );

    final List<Map<String, dynamic>> result = [];
    for (final r in rows) {
      final emp = await getEmployeeById(r['employee_id'] as int);
      result.add({...r, 'employee': emp});
    }
    return result;
  }

  Future<int> countPendingLeaveRequests() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as c FROM leave_requests WHERE status = 'Pending'");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Approves or rejects a pending leave request. On approval, attendance
  /// is automatically marked as "Leave" for every date in the range —
  /// this is the ONE place leave decisions touch attendance, keeping the
  /// existing attendance logic itself completely untouched.
  Future<void> decideLeaveRequest({
    required int requestId,
    required bool approve,
    required String decidedBy,
    String remarks = '',
  }) async {
    final db = await database;
    final rows = await db.query('leave_requests', where: 'id = ?', whereArgs: [requestId]);
    if (rows.isEmpty) return;
    final request = rows.first;

    final newStatus = approve ? 'Approved' : 'Rejected';
    await db.update(
      'leave_requests',
      {
        'status': newStatus,
        'decided_by': decidedBy,
        'decided_at': DateTime.now().toIso8601String(),
        'remarks': remarks,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [requestId],
    );

    final employeeId = request['employee_id'] as int;
    final emp = await getEmployeeById(employeeId);

    if (approve) {
      await _markLeaveRange(employeeId, request['from_date'] as String, request['to_date'] as String);
    }

    await logActivity(
      'Leave request for ${emp?.name ?? 'employee'} $newStatus by $decidedBy',
      iconType: 'leave',
    );
    await createNotification(
      'Leave request for ${emp?.name ?? 'employee'} was $newStatus',
      type: 'leave_decision',
      relatedId: requestId,
    );
    DataBus.instance.notifyChanged();
  }

  /// Marks every date in an inclusive range as "Leave" in one batch —
  /// used internally when a leave request is approved. Uses the same
  /// UNIQUE(employee_id, date) ON CONFLICT REPLACE guarantee as the rest
  /// of the app, so it can never create duplicate attendance rows.
  Future<void> _markLeaveRange(int employeeId, String fromDate, String toDate) async {
    final db = await database;
    final start = DateTime.parse(fromDate);
    final end = DateTime.parse(toDate);
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      batch.insert(
        'attendance',
        {
          'employee_id': employeeId,
          'date': dateStr,
          'status': AppConstants.leave,
          'updated_at': now,
          'is_synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ---------------- NOTIFICATIONS ----------------

  Future<void> createNotification(String message, {String type = 'info', int? relatedId}) async {
    final db = await database;
    await db.insert('notifications', {
      'message': message,
      'type': type,
      'related_id': relatedId,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 100}) async {
    final db = await database;
    return db.query('notifications', orderBy: 'created_at DESC', limit: limit);
  }

  Future<int> countUnreadNotifications() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM notifications WHERE is_read = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markNotificationRead(int id) async {
    final db = await database;
    await db.update('notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllNotificationsRead() async {
    final db = await database;
    await db.update('notifications', {'is_read': 1}, where: 'is_read = 0');
  }

  Future<void> deleteNotification(int id) async {
    final db = await database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- MANPOWER RULES (min/max staffing per designation) ----------------

  Future<List<Map<String, dynamic>>> getManpowerRules() async {
    final db = await database;
    return db.query('manpower_rules', orderBy: 'designation ASC');
  }

  /// Creates or updates the min/max rule for a designation.
  Future<void> setManpowerRule(String designation, int min, int max) async {
    final db = await database;
    await db.insert(
      'manpower_rules',
      {
        'designation': designation,
        'min_required': min,
        'max_required': max,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteManpowerRule(String designation) async {
    final db = await database;
    await db.delete('manpower_rules', where: 'designation = ?', whereArgs: [designation]);
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

  // ================================================================
  // CLOUD SYNC SUPPORT (Phase 8)
  // ================================================================
  // Everything below is read/written ONLY by SyncService. The rest of
  // the app never touches these directly — it just keeps using the
  // normal DBHelper methods above exactly as before, and those methods
  // already stamp updated_at/is_synced=0 on every write so SyncService
  // knows what still needs to go up to the cloud.

  Future<String> getLastSyncTime() => getSetting('last_sync_time', fallback: '');
  Future<void> setLastSyncTime(String iso8601) => setSetting('last_sync_time', iso8601);

  // ---- Unsynced rows (for pushing up) ----

  Future<List<Map<String, dynamic>>> getUnsyncedEmployees() async {
    final db = await database;
    return db.query('employees', where: 'is_synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAttendance() async {
    final db = await database;
    return db.rawQuery('''
      SELECT a.*, e.employee_code as employee_code FROM attendance a
      JOIN employees e ON e.id = a.employee_id
      WHERE a.is_synced = 0
    ''');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedLeaveRequests() async {
    final db = await database;
    return db.rawQuery('''
      SELECT lr.*, e.employee_code as employee_code FROM leave_requests lr
      JOIN employees e ON e.id = lr.employee_id
      WHERE lr.is_synced = 0
    ''');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedNotifications() async {
    final db = await database;
    return db.query('notifications', where: 'is_synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedManpowerRules() async {
    final db = await database;
    return db.query('manpower_rules', where: 'is_synced = 0');
  }

  // ---- Marking rows synced (after a successful push) ----

  Future<void> markSynced(String table, int localId, String cloudId) async {
    final db = await database;
    await db.update(table, {'is_synced': 1, 'cloud_id': cloudId}, where: 'id = ?', whereArgs: [localId]);
  }

  // ---- Applying pulled-down cloud rows locally ("last write wins") ----

  /// Inserts or updates a local employee from a cloud row, matched by
  /// employee_code (the natural key). Only overwrites the local copy if
  /// the cloud version is newer, so an offline edit already sitting in
  /// the local DB is never silently clobbered by a stale cloud pull.
  Future<void> upsertEmployeeFromCloud(Map<String, dynamic> cloud) async {
    final db = await database;
    final existing = await db.query('employees', where: 'employee_code = ?', whereArgs: [cloud['employee_code']]);
    final cloudUpdatedAt = DateTime.parse(cloud['updated_at'] as String);

    final map = {
      'employee_code': cloud['employee_code'],
      'name': cloud['name'],
      'father_name': cloud['father_name'] ?? '',
      'cnic': cloud['cnic'] ?? '',
      'mobile_number': cloud['mobile_number'] ?? '',
      'designation': cloud['designation'],
      'department': cloud['department'] ?? '',
      'unit_number': cloud['unit_number'] ?? '',
      'shift': cloud['shift'],
      'weekly_rest_day': cloud['weekly_rest_day'],
      'joining_date': cloud['joining_date'],
      'status': cloud['status'],
      'remarks': cloud['remarks'] ?? '',
      'updated_at': cloud['updated_at'],
      'is_synced': 1,
      'cloud_id': cloud['id'],
    };

    if (existing.isEmpty) {
      await db.insert('employees', map);
      DataBus.instance.notifyChanged();
    } else {
      final localUpdatedAtStr = existing.first['updated_at'] as String?;
      final localUpdatedAt =
          (localUpdatedAtStr == null || localUpdatedAtStr.isEmpty) ? DateTime(2000) : DateTime.parse(localUpdatedAtStr);
      if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
        await db.update('employees', map, where: 'id = ?', whereArgs: [existing.first['id']]);
        DataBus.instance.notifyChanged();
      }
    }
  }

  Future<void> upsertAttendanceFromCloud(Map<String, dynamic> cloud) async {
    final db = await database;
    final empRows = await db.query('employees', where: 'employee_code = ?', whereArgs: [cloud['employee_code']]);
    if (empRows.isEmpty) return; // employee not synced locally yet — will retry next sync
    final employeeId = empRows.first['id'] as int;

    final existing = await db.query('attendance', where: 'employee_id = ? AND date = ?', whereArgs: [employeeId, cloud['date']]);
    final cloudUpdatedAt = DateTime.parse(cloud['updated_at'] as String);

    final map = {
      'employee_id': employeeId,
      'date': cloud['date'],
      'status': cloud['status'],
      'updated_at': cloud['updated_at'],
      'is_synced': 1,
      'cloud_id': cloud['id'],
    };

    if (existing.isEmpty) {
      await db.insert('attendance', map);
      DataBus.instance.notifyChanged();
    } else {
      final localUpdatedAtStr = existing.first['updated_at'] as String?;
      final localUpdatedAt =
          (localUpdatedAtStr == null || localUpdatedAtStr.isEmpty) ? DateTime(2000) : DateTime.parse(localUpdatedAtStr);
      if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
        await db.update('attendance', map, where: 'id = ?', whereArgs: [existing.first['id']]);
        DataBus.instance.notifyChanged();
      }
    }
  }

  Future<void> upsertLeaveRequestFromCloud(Map<String, dynamic> cloud) async {
    final db = await database;
    final empRows = await db.query('employees', where: 'employee_code = ?', whereArgs: [cloud['employee_code']]);
    if (empRows.isEmpty) return;
    final employeeId = empRows.first['id'] as int;

    // Matched by cloud_id if we've seen this exact cloud row before;
    // otherwise fall back to the natural combination that identifies
    // "the same request" across devices.
    var existing = await db.query('leave_requests', where: 'cloud_id = ?', whereArgs: [cloud['id']]);
    if (existing.isEmpty) {
      existing = await db.query(
        'leave_requests',
        where: 'employee_id = ? AND leave_type = ? AND from_date = ? AND to_date = ? AND applied_at = ?',
        whereArgs: [employeeId, cloud['leave_type'], cloud['from_date'], cloud['to_date'], cloud['applied_at']],
      );
    }

    final cloudUpdatedAt = DateTime.parse(cloud['updated_at'] as String);
    final map = {
      'employee_id': employeeId,
      'leave_type': cloud['leave_type'],
      'from_date': cloud['from_date'],
      'to_date': cloud['to_date'],
      'reason': cloud['reason'] ?? '',
      'status': cloud['status'],
      'applied_by': cloud['applied_by'] ?? '',
      'applied_at': cloud['applied_at'],
      'decided_by': cloud['decided_by'],
      'decided_at': cloud['decided_at'],
      'remarks': cloud['remarks'] ?? '',
      'updated_at': cloud['updated_at'],
      'is_synced': 1,
      'cloud_id': cloud['id'],
    };

    if (existing.isEmpty) {
      await db.insert('leave_requests', map);
      DataBus.instance.notifyChanged();
    } else {
      final localUpdatedAtStr = existing.first['updated_at'] as String?;
      final localUpdatedAt =
          (localUpdatedAtStr == null || localUpdatedAtStr.isEmpty) ? DateTime(2000) : DateTime.parse(localUpdatedAtStr);
      if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
        await db.update('leave_requests', map, where: 'id = ?', whereArgs: [existing.first['id']]);
        DataBus.instance.notifyChanged();
      }
    }
  }

  Future<void> upsertManpowerRuleFromCloud(Map<String, dynamic> cloud) async {
    final db = await database;
    final existing = await db.query('manpower_rules', where: 'designation = ?', whereArgs: [cloud['designation']]);
    final cloudUpdatedAt = DateTime.parse(cloud['updated_at'] as String);

    final map = {
      'designation': cloud['designation'],
      'min_required': cloud['min_required'],
      'max_required': cloud['max_required'],
      'updated_at': cloud['updated_at'],
      'is_synced': 1,
      'cloud_id': cloud['id'],
    };

    if (existing.isEmpty) {
      await db.insert('manpower_rules', map);
    } else {
      final localUpdatedAtStr = existing.first['updated_at'] as String?;
      final localUpdatedAt =
          (localUpdatedAtStr == null || localUpdatedAtStr.isEmpty) ? DateTime(2000) : DateTime.parse(localUpdatedAtStr);
      if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
        await db.update('manpower_rules', map, where: 'id = ?', whereArgs: [existing.first['id']]);
      }
    }
  }
}
