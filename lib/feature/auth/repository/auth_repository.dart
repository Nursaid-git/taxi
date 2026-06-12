


abstract class AuthRepository {
  Future<void> login({ required String phone, required bool rememberMe});
  Future<void> register({ required String phone});
  Future<void> logout();

  Future<void> verify({ required String code});

}