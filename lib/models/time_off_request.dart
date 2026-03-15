/// Model untuk request libur/cuti karyawan
class TimeOffRequest {
  final String id;
  final String employeeId;
  final String outletId;
  final DateTime requestDate;
  final String reason;
  final TimeOffStatus status;
  final String? requestedBy;
  final DateTime? requestedAt;
  final String? approvedBy;
  final DateTime? approvedAt;

  TimeOffRequest({
    required this.id,
    required this.employeeId,
    required this.outletId,
    required this.requestDate,
    required this.reason,
    this.status = TimeOffStatus.pending,
    this.requestedBy,
    this.requestedAt,
    this.approvedBy,
    this.approvedAt,
  });

  factory TimeOffRequest.fromJson(Map<String, dynamic> json) => TimeOffRequest(
    id: json['id'] as String,
    employeeId: json['employee_id'] as String,
    outletId: json['outlet_id'] as String,
    requestDate: DateTime.parse(json['request_date'] as String),
    reason: json['reason'] as String,
    status: TimeOffStatus.values.firstWhere(
      (e) => e.name == (json['status'] as String),
      orElse: () => TimeOffStatus.pending,
    ),
    requestedBy: json['requested_by'] as String?,
    requestedAt: json['requested_at'] != null 
        ? DateTime.parse(json['requested_at'] as String) 
        : null,
    approvedBy: json['approved_by'] as String?,
    approvedAt: json['approved_at'] != null 
        ? DateTime.parse(json['approved_at'] as String) 
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_id': employeeId,
    'outlet_id': outletId,
    'request_date': requestDate.toIso8601String(),
    'reason': reason,
    'status': status.name,
    'requested_by': requestedBy,
    'requested_at': requestedAt?.toIso8601String(),
    'approved_by': approvedBy,
    'approved_at': approvedAt?.toIso8601String(),
  };

  TimeOffRequest copyWith({
    String? id,
    String? employeeId,
    String? outletId,
    DateTime? requestDate,
    String? reason,
    TimeOffStatus? status,
    String? requestedBy,
    DateTime? requestedAt,
    String? approvedBy,
    DateTime? approvedAt,
  }) => TimeOffRequest(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    outletId: outletId ?? this.outletId,
    requestDate: requestDate ?? this.requestDate,
    reason: reason ?? this.reason,
    status: status ?? this.status,
    requestedBy: requestedBy ?? this.requestedBy,
    requestedAt: requestedAt ?? this.requestedAt,
    approvedBy: approvedBy ?? this.approvedBy,
    approvedAt: approvedAt ?? this.approvedAt,
  );
}

enum TimeOffStatus { pending, approved, rejected }

/// Model untuk tracking sisa/carry over libur karyawan
class EmployeeLeaveBalance {
  final String employeeId;
  final int carryOverDays; // Libur yang ditampung dari minggu lalu
  final DateTime lastUpdated;

  EmployeeLeaveBalance({
    required this.employeeId,
    this.carryOverDays = 0,
    required this.lastUpdated,
  });

  /// Hitung total hari libur yang tersedia (1 wajib + carry over)
  int get totalLeaveDays => 1 + carryOverDays;

  factory EmployeeLeaveBalance.fromJson(Map<String, dynamic> json) => EmployeeLeaveBalance(
    employeeId: json['employee_id'] as String,
    carryOverDays: json['carry_over_days'] as int? ?? 0,
    lastUpdated: DateTime.parse(json['last_updated'] as String),
  );

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'carry_over_days': carryOverDays,
    'last_updated': lastUpdated.toIso8601String(),
  };
}
