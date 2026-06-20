import 'package:taxi/core/enums/user_role.dart';

/// Авторизация по телефону + одноразовый код (OTP).
/// Доставка кода (WhatsApp/SMS) настраивается на стороне Supabase (Auth Hook),
/// со стороны приложения флоу одинаковый.
abstract class AuthRepository {
  /// Отправить код на телефон. Для регистрации передаём [role] и [fullName] —
  /// они уйдут в метаданные и проставятся триггером handle_new_user.
  Future<void> sendOtp({
    required String phone,
    UserRole? role,
    String? fullName,
  });

  /// Проверить код и войти.
  Future<void> verifyOtp({required String phone, required String code});

  /// Выйти.
  Future<void> signOut();

  /// Есть ли активная сессия (для автологина при старте).
  bool get hasSession;
}
