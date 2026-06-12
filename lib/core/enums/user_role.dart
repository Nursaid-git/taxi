/// Роль пользователя в приложении. Одно приложение — две роли.
enum UserRole {
  client,
  driver;

  bool get isClient => this == UserRole.client;
  bool get isDriver => this == UserRole.driver;

  String get titleRu => switch (this) {
        UserRole.client => 'Клиент',
        UserRole.driver => 'Водитель',
      };
}
