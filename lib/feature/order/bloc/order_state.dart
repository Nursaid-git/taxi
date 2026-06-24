// lib/feature/order/bloc/order_state.dart
// ─────────────────────────────────────────────────────────────────────────────
// Полное состояние экрана клиента. Хранит как UI-стадию (OrderStage), так и
// данные из Supabase (rideId, driverCard, priceFinal, freeWaitUntil).
//
// Все поля immutable — OrderCubit создаёт новый экземпляр через copyWith.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:latlong2/latlong.dart';
import 'package:taxi/feature/order/model/driver_card_model.dart';
import 'package:taxi/feature/order/model/order_models.dart'; // Place, TariffData

// ─────────────────────────── OrderStage ──────────────────────────────────────

/// UI-стадии экрана клиента.
/// Маппинг на ride_status из Supabase:
///   searching    → searching
///   driverFound  → accepted
///   driverWaiting→ arrived
///   riding       → in_progress
///   rating       → completed
enum OrderStage {
  idle,          // главный экран (нет активного заказа)
  search,        // поисковая строка открыта
  mapPick,       // выбор точки на карте
  tariffs,       // экран выбора тарифа
  searching,     // ищем водителя (realtime активен)
  driverFound,   // водитель принял, едет (ride.status = accepted)
  driverWaiting, // водитель на месте (ride.status = arrived)
  riding,        // в пути (ride.status = in_progress)
  rating,        // поездка завершена, экран оценки (ride.status = completed)
}

// ─────────────────────────── OrderState ──────────────────────────────────────

class OrderState {
  // ── UI поля (не зависят от Supabase) ────────────────────────────────────
  final OrderStage stage;
  final List<Place> stops;          // выбранные точки назначения
  final LatLng? mapPoint;           // точка, выбранная на карте
  final int selectedTariff;         // индекс выбранной карточки тарифа
  final String searchQuery;         // текст в поисковой строке

  // ── Supabase данные ──────────────────────────────────────────────────────
  final String? rideId;             // UUID активной поездки
  final DriverCardModel? driverCard;// карточка водителя (после accepted)
  final int? priceFinal;            // итоговая цена (после completed)
  final DateTime? freeWaitUntil;    // бесплатное ожидание до (after arrived)

  // ── Статус загрузки ──────────────────────────────────────────────────────
  final bool isLoading;
  final String? error;

  const OrderState({
    this.stage = OrderStage.idle,
    this.stops = const [],
    this.mapPoint,
    this.selectedTariff = 0,
    this.searchQuery = '',
    this.rideId,
    this.driverCard,
    this.priceFinal,
    this.freeWaitUntil,
    this.isLoading = false,
    this.error,
  });

  // ── Вычисляемые свойства (для совместимости с экраном) ──────────────────

  bool get hasStops => stops.isNotEmpty;

  Place? get lastStop => stops.isEmpty ? null : stops.last;

  /// Базовое расстояние: сумма по всем выбранным точкам.
  int get totalBase => stops.fold(0, (s, p) => s + p.base);

  /// Общее расстояние в км.
  double get totalKm =>
      stops.fold(0.0, (s, p) => s + p.km);

  /// Общее время в минутах.
  int get totalMin => stops.fold(0, (s, p) => s + p.min);

  // ── copyWith ─────────────────────────────────────────────────────────────

  OrderState copyWith({
    OrderStage? stage,
    List<Place>? stops,
    LatLng? mapPoint,
    bool clearMapPoint = false,
    int? selectedTariff,
    String? searchQuery,
    String? rideId,
    bool clearRideId = false,
    DriverCardModel? driverCard,
    bool clearDriverCard = false,
    int? priceFinal,
    DateTime? freeWaitUntil,
    bool isLoading = false,
    String? error,
    bool clearError = false,
  }) {
    return OrderState(
      stage: stage ?? this.stage,
      stops: stops ?? this.stops,
      mapPoint: clearMapPoint ? null : (mapPoint ?? this.mapPoint),
      selectedTariff: selectedTariff ?? this.selectedTariff,
      searchQuery: searchQuery ?? this.searchQuery,
      rideId: clearRideId ? null : (rideId ?? this.rideId),
      driverCard:
      clearDriverCard ? null : (driverCard ?? this.driverCard),
      priceFinal: priceFinal ?? this.priceFinal,
      freeWaitUntil: freeWaitUntil ?? this.freeWaitUntil,
      isLoading: isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  // ── Сброс в начальное состояние ──────────────────────────────────────────

  OrderState get initial => const OrderState();
}
 