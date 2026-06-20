import 'dart:developer' as dev;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taxi/core/enums/user_role.dart';
import 'package:taxi/feature/auth/repository/auth_repository.dart';

class AppLogger {
  static const String _tag = '🚗 TAXI_APP';

  static void debug(String message) => dev.log('🟢 [DEBUG] $message', name: _tag);
  static void info(String message) => dev.log('🔵 [INFO] $message', name: _tag);
  static void warning(String message) => dev.log('🟡 [WARNING] $message', name: _tag);
  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      dev.log('🔴 [ERROR] $message', name: _tag, error: error, stackTrace: stackTrace);
}

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;
  AuthRepositoryImpl(this._client);

  GoTrueClient get _auth => _client.auth;

  @override
  Future<void> sendOtp({
    required String phone,
    UserRole? role,
    String? fullName,
  }) async {
    AppLogger.info('sendOtp -> $phone (role: ${role?.name})');
    // data применяется только при создании нового пользователя — для регистрации.
    final data = <String, dynamic>{
      if (role != null) 'role': role.name,
      if (fullName != null && fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
    };
    await _auth.signInWithOtp(
      phone: phone,
      data: data.isEmpty ? null : data,
    );
  }

  @override
  Future<void> verifyOtp({required String phone, required String code}) async {
    AppLogger.info('verifyOtp -> $phone');
    await _auth.verifyOTP(
      phone: phone,
      token: code,
      type: OtpType.sms, // тип для phone-OTP (канал доставки не важен)
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  bool get hasSession => _auth.currentSession != null;
}
