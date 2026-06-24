// lib/core/enums/ride_enums.dart
// ─────────────────────────────────────────────────────────────────────────────
// Все enum'ы строго совпадают с типами в Supabase (ride_status, ride_class,
// payment_method, ride_actor). Метод fromString / dbValue используются при
// сериализации/десериализации между Dart и Postgres.
// ─────────────────────────────────────────────────────────────────────────────

/// Статус заказа. Маппинг: searching→driverFound→arrived→inProgress→completed.
enum RideStatus {
  searching,
  accepted,
  arrived,
  inProgress,
  completed,
  cancelled,
  expired;

  /// Postgres → Dart
  static RideStatus fromString(String s) => switch (s) {
        'searching' => searching,
        'accepted' => accepted,
        'arrived' => arrived,
        'in_progress' => inProgress,
        'completed' => completed,
        'cancelled' => cancelled,
        'expired' => expired,
        _ => throw ArgumentError('Unknown ride_status: $s'),
      };

  /// Dart → Postgres
  String get dbValue => switch (this) {
        RideStatus.inProgress => 'in_progress',
        _ => name,
      };
}

/// Класс поездки (тариф). Индекс совпадает с позицией карточки в ленте тарифов.
enum RideClass {
  econom,   // index 0
  comfort,  // index 1
  business; // index 2

  static RideClass fromString(String s) => switch (s) {
        'econom' => econom,
        'comfort' => comfort,
        'business' => business,
        _ => econom,
      };

  /// Для передачи в RPC (строчное имя совпадает с enum в Postgres).
  String get dbValue => name;

  /// Маппинг индекса тарифа → RideClass.
  static RideClass fromTariffIndex(int i) => switch (i) {
        0 => econom,
        1 => comfort,
        2 => business,
        _ => econom,
      };
}

/// Способ оплаты.
enum PaymentMethod {
  cash,
  card;

  static PaymentMethod fromString(String s) => switch (s) {
        'cash' => cash,
        'card' => card,
        _ => cash,
      };

  String get dbValue => name;
}

/// Кто выполнил действие (для поля cancelled_by).
enum RideActor {
  client,
  driver,
  system;

  static RideActor fromString(String s) => switch (s) {
        'client' => client,
        'driver' => driver,
        'system' => system,
        _ => system,
      };
}
