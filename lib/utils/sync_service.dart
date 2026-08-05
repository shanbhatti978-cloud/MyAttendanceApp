import 'package:flutter/foundation.dart';

import '../db/db_helper.dart';
import 'supabase_config.dart';

enum SyncStatus { idle, syncing, success, offline, error }

/// Local-first cloud sync: the SQLite database is always the source of
/// truth the app reads/writes from directly (nothing about existing
/// screens or the attendance logic changes). This service only handles
/// moving data to/from Supabase in the background, best-effort:
///   - If there's no internet, every step fails silently and the app
///     just keeps working offline — nothing here can block or crash it.
///   - Push: any local row with is_synced=0 gets sent up.
///   - Pull: any cloud row updated since the last sync gets applied
///     locally, but only if it's actually newer than the local copy
///     ("last write wins", compared by updated_at).
class SyncService extends ChangeNotifier {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  SyncStatus status = SyncStatus.idle;
  String? lastError;
  DateTime? lastSyncedAt;

  Future<void> syncNow() async {
    status = SyncStatus.syncing;
    notifyListeners();

    try {
      // Retry initialization here too — not just once at app startup —
      // so a phone that had no internet on first launch still starts
      // syncing normally the moment it does get connectivity, instead
      // of being stuck reporting "No connection" forever.
      if (!SupabaseConfig.isReady) {
        await SupabaseConfig.initialize();
      }
      if (!SupabaseConfig.isReady) {
        throw Exception(SupabaseConfig.lastInitError ?? 'Could not connect to the cloud database.');
      }

      final client = SupabaseConfig.client;
      // A lightweight reachability check — if this throws, we're
      // offline (or the project is unreachable) and should bail out
      // quietly rather than attempt a half sync.
      await client.from('employees').select('id').limit(1);

      await _pushEmployees();
      await _pushAttendance();
      await _pushLeaveRequests();
      await _pushNotifications();
      await _pushManpowerRules();

      await _pullEmployees();
      await _pullAttendance();
      await _pullLeaveRequests();
      await _pullManpowerRules();

      final now = DateTime.now();
      await DBHelper.instance.setLastSyncTime(now.toIso8601String());
      lastSyncedAt = now;
      status = SyncStatus.success;
      lastError = null;
    } catch (e) {
      status = SyncStatus.offline;
      lastError = e.toString();
    }
    notifyListeners();
  }

  Future<void> loadLastSyncTime() async {
    final saved = await DBHelper.instance.getLastSyncTime();
    if (saved.isNotEmpty) {
      lastSyncedAt = DateTime.tryParse(saved);
      notifyListeners();
    }
  }

  // ---------------- PUSH ----------------

  Future<void> _pushEmployees() async {
    final rows = await DBHelper.instance.getUnsyncedEmployees();
    for (final row in rows) {
      final data = {
        'employee_code': row['employee_code'],
        'name': row['name'],
        'father_name': row['father_name'],
        'cnic': row['cnic'],
        'mobile_number': row['mobile_number'],
        'designation': row['designation'],
        'department': row['department'],
        'unit_number': row['unit_number'],
        'shift': row['shift'],
        'weekly_rest_day': row['weekly_rest_day'],
        'joining_date': row['joining_date'],
        'status': row['status'],
        'remarks': row['remarks'],
        'local_id': row['id'],
        'updated_at': row['updated_at'],
      };
      final cloudId = row['cloud_id'] as String?;
      final result = cloudId == null
          ? await SupabaseConfig.client.from('employees').upsert(data, onConflict: 'employee_code').select('id').single()
          : await SupabaseConfig.client.from('employees').update(data).eq('id', cloudId).select('id').single();
      await DBHelper.instance.markSynced('employees', row['id'] as int, result['id'] as String);
    }
  }

  Future<void> _pushAttendance() async {
    final rows = await DBHelper.instance.getUnsyncedAttendance();
    for (final row in rows) {
      final data = {
        'employee_code': row['employee_code'],
        'date': row['date'],
        'status': row['status'],
        'updated_at': row['updated_at'],
      };
      final cloudId = row['cloud_id'] as String?;
      final result = cloudId == null
          ? await SupabaseConfig.client
              .from('attendance')
              .upsert(data, onConflict: 'employee_code,date')
              .select('id')
              .single()
          : await SupabaseConfig.client.from('attendance').update(data).eq('id', cloudId).select('id').single();
      await DBHelper.instance.markSynced('attendance', row['id'] as int, result['id'] as String);
    }
  }

  Future<void> _pushLeaveRequests() async {
    final rows = await DBHelper.instance.getUnsyncedLeaveRequests();
    for (final row in rows) {
      final data = {
        'employee_code': row['employee_code'],
        'leave_type': row['leave_type'],
        'from_date': row['from_date'],
        'to_date': row['to_date'],
        'reason': row['reason'],
        'status': row['status'],
        'applied_by': row['applied_by'],
        'applied_at': row['applied_at'],
        'decided_by': row['decided_by'],
        'decided_at': row['decided_at'],
        'remarks': row['remarks'],
        'updated_at': row['updated_at'],
      };
      final cloudId = row['cloud_id'] as String?;
      final result = cloudId == null
          ? await SupabaseConfig.client.from('leave_requests').insert(data).select('id').single()
          : await SupabaseConfig.client.from('leave_requests').update(data).eq('id', cloudId).select('id').single();
      await DBHelper.instance.markSynced('leave_requests', row['id'] as int, result['id'] as String);
    }
  }

  /// Notifications are push-only (device-local read/unread state isn't
  /// meaningful to merge across phones) — this just keeps a shared
  /// activity record in the cloud for the future web dashboard.
  Future<void> _pushNotifications() async {
    final rows = await DBHelper.instance.getUnsyncedNotifications();
    for (final row in rows) {
      final data = {
        'message': row['message'],
        'type': row['type'],
        'related_id': row['related_id']?.toString(),
        'is_read': row['is_read'] == 1,
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
      };
      final cloudId = row['cloud_id'] as String?;
      final result = cloudId == null
          ? await SupabaseConfig.client.from('notifications').insert(data).select('id').single()
          : await SupabaseConfig.client.from('notifications').update(data).eq('id', cloudId).select('id').single();
      await DBHelper.instance.markSynced('notifications', row['id'] as int, result['id'] as String);
    }
  }

  Future<void> _pushManpowerRules() async {
    final rows = await DBHelper.instance.getUnsyncedManpowerRules();
    for (final row in rows) {
      final data = {
        'designation': row['designation'],
        'min_required': row['min_required'],
        'max_required': row['max_required'],
        'updated_at': row['updated_at'],
      };
      final cloudId = row['cloud_id'] as String?;
      final result = cloudId == null
          ? await SupabaseConfig.client
              .from('manpower_rules')
              .upsert(data, onConflict: 'designation')
              .select('id')
              .single()
          : await SupabaseConfig.client.from('manpower_rules').update(data).eq('id', cloudId).select('id').single();
      await DBHelper.instance.markSynced('manpower_rules', row['id'] as int, result['id'] as String);
    }
  }

  // ---------------- PULL ----------------

  Future<String> _sinceTimestamp() async {
    final last = await DBHelper.instance.getLastSyncTime();
    return last.isNotEmpty ? last : DateTime(2000).toIso8601String();
  }

  Future<void> _pullEmployees() async {
    final since = await _sinceTimestamp();
    final rows = await SupabaseConfig.client.from('employees').select().gt('updated_at', since);
    for (final row in rows) {
      await DBHelper.instance.upsertEmployeeFromCloud(row);
    }
  }

  Future<void> _pullAttendance() async {
    final since = await _sinceTimestamp();
    final rows = await SupabaseConfig.client.from('attendance').select().gt('updated_at', since);
    for (final row in rows) {
      await DBHelper.instance.upsertAttendanceFromCloud(row);
    }
  }

  Future<void> _pullLeaveRequests() async {
    final since = await _sinceTimestamp();
    final rows = await SupabaseConfig.client.from('leave_requests').select().gt('updated_at', since);
    for (final row in rows) {
      await DBHelper.instance.upsertLeaveRequestFromCloud(row);
    }
  }

  Future<void> _pullManpowerRules() async {
    final since = await _sinceTimestamp();
    final rows = await SupabaseConfig.client.from('manpower_rules').select().gt('updated_at', since);
    for (final row in rows) {
      await DBHelper.instance.upsertManpowerRuleFromCloud(row);
    }
  }
}
