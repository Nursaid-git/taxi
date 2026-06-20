part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Идёт отправка кода или проверка.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Код отправлен — переходим на экран ввода кода.
final class AuthCodeSent extends AuthState {
  final String phone; // нормализованный E.164
  const AuthCodeSent(this.phone);

  @override
  List<Object?> get props => [phone];
}

/// Код подтверждён, пользователь авторизован.
final class AuthSuccess extends AuthState {
  const AuthSuccess();
}

/// Ошибка (показываем сообщение).
final class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
