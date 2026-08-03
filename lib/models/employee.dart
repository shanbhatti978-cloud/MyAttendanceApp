/// Represents one row in the `employees` table.
class Employee {
  final int? id;
  final String employeeCode; // Company Employee ID (e.g. EMP-001)
  final String name;
  final String fatherName;
  final String cnic; // optional national ID number
  final String mobileNumber;
  final String designation;
  final String department;
  final String unitNumber;
  final String shift; // Morning / Evening / Night / custom
  final String weeklyRestDay; // e.g. "Sunday"
  final String joiningDate; // stored as yyyy-MM-dd
  final String status; // Active / Inactive
  final String remarks;

  Employee({
    this.id,
    required this.employeeCode,
    required this.name,
    this.fatherName = "",
    this.cnic = "",
    this.mobileNumber = "",
    required this.designation,
    this.department = "",
    this.unitNumber = "",
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
      'father_name': fatherName,
      'cnic': cnic,
      'mobile_number': mobileNumber,
      'designation': designation,
      'department': department,
      'unit_number': unitNumber,
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
      fatherName: map['father_name'] as String? ?? "",
      cnic: map['cnic'] as String? ?? "",
      mobileNumber: map['mobile_number'] as String? ?? "",
      designation: map['designation'] as String,
      department: map['department'] as String? ?? "",
      unitNumber: map['unit_number'] as String? ?? "",
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
    String? fatherName,
    String? cnic,
    String? mobileNumber,
    String? designation,
    String? department,
    String? unitNumber,
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
      fatherName: fatherName ?? this.fatherName,
      cnic: cnic ?? this.cnic,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      unitNumber: unitNumber ?? this.unitNumber,
      shift: shift ?? this.shift,
      weeklyRestDay: weeklyRestDay ?? this.weeklyRestDay,
      joiningDate: joiningDate ?? this.joiningDate,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
    );
  }
}
