import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:taxi/core/enums/user_role.dart';
import 'package:taxi/feature/auth/repository/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthInitial());

  /// Отправить код. Для регистрации передаём роль и имя.
  Future<void> sendOtp({
    required String phone,
    UserRole? role,
    String? fullName,
  }) async {
    final normalized = _normalize(phone);
    emit(const AuthLoading());
    try {
      await _authRepository.sendOtp(
        phone: normalized,
        role: role,
        fullName: fullName,
      );
      emit(AuthCodeSent(normalized));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  /// Проверить код.
  Future<void> verify({required String phone, required String code}) async {
    emit(const AuthLoading());
    try {
      await _authRepository.verifyOtp(phone: _normalize(phone), code: code);
      emit(const AuthSuccess());
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  Future<void> logout() async {
    await _authRepository.signOut();
    emit(const AuthInitial());
  }

  /// E.164: убираем пробелы (+7 940 12 → +794012).
  String _normalize(String phone) => phone.replaceAll(RegExp(r'\s+'), '');

  String _message(Object e) {
    if (e is AuthException) return e.message;
    return 'Не удалось выполнить. Проверьте номер и попробуйте снова.';
  }
}
