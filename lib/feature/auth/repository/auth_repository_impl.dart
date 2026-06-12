


import 'package:taxi/feature/auth/repository/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository{
  final String firebase;
  AuthRepositoryImpl({required this.firebase});


  @override
  Future<void> login({required String phone, required bool rememberMe}) {
    // TODO: implement login
    throw UnimplementedError();
  }

  @override
  Future<void> logout() {
    // TODO: implement logout
    throw UnimplementedError();
  }

  @override
  Future<void> register({required String phone}) {
    // TODO: implement register
    throw UnimplementedError();
  }

  @override
  Future<void> verify({required String code}) {
    // TODO: implement verify
    throw UnimplementedError();
  }
  
}