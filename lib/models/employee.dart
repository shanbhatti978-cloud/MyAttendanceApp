/// Represents one row in the `employees` table.
class Employee {
  final int? id;
  final String employeeCode; // Company Employee ID (e.g. EMP-001)
  final String name;
  final String designation;
  final String shift; // Morning / Evening / Night
  final String weeklyRestDay; // e.g. "Sunday"
  final String joiningDate; // stored as yyyy-MM-dd
  final String status; // Active / Inactive
  final String remarks;

  Employee({
    this.id,
    required this.employeeCode,
    required this.name,
    required this.designation,
    required this.shift,
    required this.weeklyRestDay,
    required this.joiningDate,
    this.status = "Active",
    this.remarks = "",
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_code': employeeCode,
      'name': name,
      'designation': designation,
      'shift': shift,
      'weekly_rest_day': weeklyRestDay,
      'joining_date': joiningDate,
      'status': status,
      'remarks': remarks,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      employeeCode: map['employee_code'] as String,
      name: map['name'] as String,
      designation: map['designation'] as String,
      shift: map['shift'] as String,
      weeklyRestDay: map['weekly_rest_day'] as String,
      joiningDate: map['joining_date'] as String,
      status: map['status'] as String,
      remarks: map['remarks'] as String? ?? "",
    );
  }

  Employee copyWith({
    int? id,
    String? employeeCode,
    String? name,
    String? designation,
    String? shift,
    String? weeklyRestDay,
    String? joiningDate,
    String? status,
    String? remarks,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      shift: shift ?? this.shift,
      weeklyRestDay: weeklyRestDay ?? this.weeklyRestDay,
      joiningDate: joiningDate ?? this.joiningDate,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
    );
  }
}
