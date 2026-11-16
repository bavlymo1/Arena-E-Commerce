import '../models/app_user.dart';

abstract interface class CustomerAuthRepository {
  Stream<AppUser?> authChanges();
  Future<void> register(String email, String password);
  Future<void> login(String email, String password);
  Future<void> logout();
}
