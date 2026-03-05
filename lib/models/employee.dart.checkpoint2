class Employee {
  final String id;
  final String name;
  final String? employeeCode;
  // nfc_uid nullable: employees can be created before assigning a card
  final String? nfcUid;
  final String? homeOutletId;
  final String? photoUrl;
  final String? position;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const Employee({
    required this.id,
    required this.name,
    this.employeeCode,
    this.nfcUid,
    this.homeOutletId,
    this.photoUrl,
    this.position,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        name: json['name'] as String,
        employeeCode: json['employee_code'] as String?,
        nfcUid: json['nfc_uid'] as String?,
        homeOutletId: json['home_outlet_id'] as String?,
        photoUrl: json['photo_url'] as String?,
        position: json['position'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'employee_code': employeeCode,
        'nfc_uid': nfcUid,
        'home_outlet_id': homeOutletId,
        'photo_url': photoUrl,
        'position': position,
        'is_active': isActive,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Employee copyWith({
    String? nfcUid,
    bool? isActive,
    String? position,
    String? homeOutletId,
  }) =>
      Employee(
        id: id,
        name: name,
        employeeCode: employeeCode,
        nfcUid: nfcUid ?? this.nfcUid,
        homeOutletId: homeOutletId ?? this.homeOutletId,
        photoUrl: photoUrl,
        position: position ?? this.position,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Returns the first letter of the name, uppercased — used for avatar placeholders
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}
