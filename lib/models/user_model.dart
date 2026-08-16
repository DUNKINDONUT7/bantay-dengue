/// Values stored in `public.profiles.role`.
///
/// Legacy aliases remain accepted so existing rows keep working while the
/// database migration uses the canonical `waste_personnel` role.
enum UserRole { civilian, doctor, wastePersonnel, admin }

UserRole userRoleFromString(String? value) {
  switch (value) {
    case 'resident':
    case 'civilian':
      return UserRole.civilian;
    case 'health_worker':
    case 'doctor':
      return UserRole.doctor;
    case 'waste_staff':
    case 'waste_management':
    case 'waste_personnel':
      return UserRole.wastePersonnel;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.civilian;
  }
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.civilian:
      return 'resident';
    case UserRole.doctor:
      return 'health_worker';
    case UserRole.wastePersonnel:
      return 'waste_personnel';
    case UserRole.admin:
      return 'admin';
  }
}

String roleHomePath(UserRole role) {
  switch (role) {
    case UserRole.civilian:
      return '/civilian/home';
    case UserRole.doctor:
      return '/doctor';
    case UserRole.wastePersonnel:
      return '/waste-management';
    case UserRole.admin:
      return '/admin';
  }
}

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final UserRole role;
  final String? barangay;
  final String? photoUrl;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.barangay,
    this.photoUrl,
    this.isActive = true,
  });

  String get roleLabel {
    switch (role) {
      case UserRole.civilian:
        return 'Resident';
      case UserRole.doctor:
        return 'Barangay Health Worker';
      case UserRole.wastePersonnel:
        return 'Waste Personnel';
      case UserRole.admin:
        return 'Administrator';
    }
  }

  factory UserModel.fromProfile(Map<String, dynamic> row) {
    return UserModel(
      id: row['id'] as String,
      fullName: (row['full_name'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      phone: row['phone'] as String?,
      role: userRoleFromString(row['role'] as String?),
      barangay: row['barangay'] as String?,
      photoUrl: row['photo_url'] as String?,
      // The existing live table does not have this column yet; absence means
      // active so the migration is backward compatible.
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}
