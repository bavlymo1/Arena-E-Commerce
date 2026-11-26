final class AppUser {
  AppUser({required this.uid, required this.email}) {
    if (uid.trim().isEmpty || email.trim().isEmpty) {
      throw ArgumentError('User UID and email are required');
    }
  }

  final String uid;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is AppUser && (uid, email) == (other.uid, other.email);

  @override
  int get hashCode => Object.hash(uid, email);
}
