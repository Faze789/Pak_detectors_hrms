class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String department;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.department = '',
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'employee',
      department: map['department'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'department': department,
    };
  }
}
