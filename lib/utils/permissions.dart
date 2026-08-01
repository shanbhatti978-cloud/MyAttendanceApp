import 'constants.dart';

/// Single source of truth for role-based access control.
///
/// Role summary (per the app's access policy):
/// - Admin: full control — employees, users/roles, settings, security,
///   backup/restore, attendance data, everything.
/// - Supervisor: day-to-day operations — views everything, manages
///   leave entries, but cannot touch employees, users, or system/
///   security settings, and cannot edit finalized attendance directly
///   (attendance is generated automatically; leave is the one manual
///   lever supervisors get).
/// - Viewer: read-only everywhere — no add/edit/delete/leave/settings
///   of any kind.
class Permissions {
  final String role;
  const Permissions(this.role);

  bool get isAdmin => role == AppConstants.roleAdmin;
  bool get isSupervisor => role == AppConstants.roleSupervisor;
  bool get isViewer => role == AppConstants.roleViewer;

  // ---- Employee Master ----
  bool get canManageEmployees => isAdmin; // add/edit/delete
  bool get canViewEmployees => true; // everyone can see the directory

  // ---- Users & Roles ----
  bool get canManageUsers => isAdmin;

  // ---- Attendance ----
  // Attendance generation itself is automatic and untouched by role;
  // this only controls who may use the manual "Save All" override on
  // the Daily Attendance screen.
  bool get canEditAttendance => isAdmin;
  bool get canViewAttendance => true;

  // ---- Leave ----
  bool get canManageLeave => isAdmin || isSupervisor;

  // ---- Reports ----
  bool get canViewReports => true;
  bool get canExportReports => isAdmin || isSupervisor;

  // ---- Settings / Security / Backup ----
  bool get canManageAppSettings => isAdmin; // company info, system config
  bool get canAccessBackup => isAdmin;
  // Biometric on/off is a personal device convenience, not a system
  // security policy, so every role may manage their own.
  bool get canUseBiometricSettings => true;
  bool get canChangeOwnPassword => true;
}
