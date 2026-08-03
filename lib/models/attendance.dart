/// Represents one row in the `attendance` table.
/// A single (employee_id, date) pair is unique — enforced at the DB level
/// so duplicate attendance for the same employee on the same day is
/// impossible (it's an UPSERT instead).
class AttendanceRecord {
  final int? id;
  final int employeeId;
  final String date; // yyyy-MM-dd
  final String status; // Present / Absent / Leave / Weekly Rest

  AttendanceRecord({
    this.id,
    required this.employeeId,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'date': date,
      'status': status,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      date: map['date'] as String,
      status: map['status'] as String,
    );
  }
}
