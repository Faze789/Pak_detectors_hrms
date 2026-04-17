// ─────────────────────────────────────────────────────────────
// DATA MODEL — EmployeeContact
// Add this to your models folder (e.g. employee_contact.dart)
// ─────────────────────────────────────────────────────────────

class EmployeeContact {
  final String uid;
  final String name;
  final String email;
  final String? fcmToken; // for push notification

  const EmployeeContact({
    required this.uid,
    required this.name,
    required this.email,
    this.fcmToken,
  });

  factory EmployeeContact.fromMap(String uid, Map<String, dynamic> m) =>
      EmployeeContact(
        uid:      uid,
        name:     m['name']     ?? '',
        email:    m['email']    ?? '',
        fcmToken: m['fcmToken'] as String?,
      );
}