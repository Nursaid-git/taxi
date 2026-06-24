// lib/feature/order/bloc/order_cubit.dart
// ─────────────────────────────────────────────────────────────────────────────
// Центральный кубит заказа клиента.
//
// Отвечает за:
//   1. UI-переходы между стадиями экрана (idle → search → tariffs → ...)
//   2. Вызов Supabase RPC (request_ride, cancel_ride, rate_ride)
//   3. Realtime-подписку на таблицу rides → автообновление стадии
//   4. Загрузку карточки водителя через driver_card()
//   5. Восстановление активного заказа при открытии экрана
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi/core/enums/ride_enums.dart';
import 'package:taxi/feature/order/bloc/order_state.dart';
import 'package:taxi/feature/order/model/ride_model.dart';
import 'package:taxi/feature/order/model/order_models.dart';
import 'package:taxi/feature/order/repository/order_repository.dart';

export 'order_state.dart'; // экран импортирует OrderStage и OrderState отсюда

// ─────────────────── Константы ───────────────────────────────────────────────

/// Адрес подачи по умолчанию (пока нет геолокации).
/// TODO: заменить на реальное местоположение через geolocator.
const _defaultPickupAddress = 'Моё местоположение';
const _defaultPickupLat = 43.0042;
const _defaultPickupLng = 41.0148;

/// Координаты точки по умолчанию, если в Place нет lat/lng.
/// TODO: после добавления lat/lng в Place — удалить эту заглушку.
const _fallbackLat = 43.0145;
const _fallbackLng = 41.0440;

// ─────────────────────────────────────────────────────────────────────────────

class OrderCubit extends Cubit<OrderState> {
  OrderCubit({OrderRepository? repository})
      : _repo = repository ?? OrderRepository(),
        super(const OrderState()) {
    _init();
  }

  final OrderRepository _repo;
  StreamSubscription<RideModel>? _rideSub;

  // ─────────────────── Инициализация ───────────────────────────────────────

  /// Вызывается при создании кубита.
  /// Проверяет, есть ли незавершённый заказ → восстанавливает состояние.
  Future<void> _init() async {
    try {
      final activeRide = await _repo.getActiveRide();
      if (activeRide != null) {
        _applyRide(activeRide);
        _subscribeToRide(activeRide.id);
      }
    } catch (_) {
      // Нет сети или нет сессии — стартуем с idle, не падаем.
    }
  }

  // ─────────────────── UI навигация (без Supabase) ─────────────────────────

  void openSearch() => emit(state.copyWith(stage: OrderStage.search));

  void addStopSearch() => emit(state.copyWith(stage: OrderStage.search));

  void setQuery(String q) => emit(state.copyWith(searchQuery: q));

  void enterMapPick() =>
      emit(state.copyWith(stage: OrderStage.mapPick, clearMapPoint: true));

  void setMapPoint(LatLng ll) => emit(state.copyWith(mapPoint: ll));

  void confirmMapPoint() {
    if (state.mapPoint == null) return;
    // Создаём Place из точки на карте с fallback-данными.
    final mp = state.mapPoint!;
    final place = Place(
      'Точка на карте',
      '${mp.latitude.toStringAsFixed(4)}, ${mp.longitude.toStringAsFixed(4)}',
      10,   // durationMin — примерное (TODO: реальный маршрут)
      5,    // distanceKm
      200,  // price — примерное
    );
    _addStop(place);
  }

  void pickPlace(Place place) {
    _focus();
    _addStop(place);
    // Сохраняем в recent_places (fire-and-forget).
    _repo.upsertRecentPlace(
      address: place.subtitle,
      lat: _fallbackLat, // TODO: Place.lat когда добавите поле
      lng: _fallbackLng, // TODO: Place.lng когда добавите поле
    ).catchError((_) {});
  }

  void removeStop(int index) {
    final stops = List<Place>.from(state.stops)..removeAt(index);
    if (stops.isEmpty) {
      emit(state.copyWith(stops: stops, stage: OrderStage.search));
    } else {
      emit(state.copyWith(stops: stops));
    }
  }

  void selectTariff(int i) => emit(state.copyWith(selectedTariff: i));

  void _addStop(Place place) {
    final stops = [...state.stops, place];
    emit(state.copyWith(
      stops: stops,
      stage: OrderStage.tariffs,
      clearMapPoint: true,
    ));
  }

  void _focus() {}

  // ─────────────────── Создание заказа ─────────────────────────────────────

  /// Вызывается кнопкой «Заказать» на экране тарифов.
  /// Создаёт заказ через RPC request_ride → переходит в stage searching.
  Future<void> confirm() async {
    if (!state.hasStops) return;
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final tariffs = tariffsFor(state.totalBase);
      final selectedTariff = tariffs[state.selectedTariff];
      final rideClass = RideClass.fromTariffIndex(state.selectedTariff);

      // Формируем массив stops для RPC.
      final stops = state.stops.map((p) => {
        'address': p.subtitle,
        'lat': _fallbackLat,  // TODO: заменить на p.lat когда добавите поле
        'lng': _fallbackLng,  // TODO: заменить на p.lng когда добавите поле
      }).toList();

      final ride = await _repo.requestRide(
        rideClass: rideClass,
        paymentMethod: PaymentMethod.cash,
        pickupAddress: _defaultPickupAddress,
        pickupLat: _defaultPickupLat,
        pickupLng: _defaultPickupLng,
        distanceKm: state.totalKm,
        durationMin: state.totalMin,
        priceEstimated: selectedTariff.price,
        stops: stops,
      );

      emit(state.copyWith(
        stage: OrderStage.searching,
        rideId: ride.id,
        isLoading: false,
      ));

      // Запускаем Realtime-подписку.
      _subscribeToRide(ride.id);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: _humanError(e),
      ));
    }
  }

  // ─────────────────── Отмена заказа ───────────────────────────────────────

  /// Сброс: если есть активная поездка — отменяем в Supabase.
  /// Иначе просто возвращаемся на idle.
  Future<void> reset() async {
    final rideId = state.rideId;

    // Отписываемся от Realtime немедленно.
    await _rideSub?.cancel();
    _rideSub = null;
    await _repo.unsubscribeRide();

    if (rideId != null &&
        (state.stage == OrderStage.searching ||
            state.stage == OrderStage.driverFound ||
            state.stage == OrderStage.driverWaiting)) {
      // Отменяем в Supabase (fire-and-forget, UI уже вернулся на idle).
      _repo.cancelRide(rideId).catchError((_) {});
    }

    emit(state.initial);
  }

  // ─────────────────── Демо-метод (только UI) ──────────────────────────────

  /// В реальном приложении поездку начинает ВОДИТЕЛЬ (start_ride).
  /// Этот метод существует только для тестирования демо-таймера в WaitingPanel.
  void startRiding() {
    emit(state.copyWith(stage: OrderStage.riding));
  }

  // ─────────────────── Оценка поездки ──────────────────────────────────────

  /// Отправляет оценку через rate_ride → возвращает на idle.
  Future<void> submitRating({
    int stars = 5,
    String? comment,
    List<String> tags = const [],
  }) async {
    final rideId = state.rideId;
    if (rideId == null) {
      emit(state.initial);
      return;
    }

    try {
      await _repo.rateRide(
        rideId: rideId,
        stars: stars,
        comment: comment,
        tags: tags,
      );
    } catch (_) {
      // Ошибка оценки не критична — всё равно сбрасываем экран.
    } finally {
      await _rideSub?.cancel();
      _rideSub = null;
      await _repo.unsubscribeRide();
      emit(state.initial);
    }
  }

  // ─────────────────── Realtime ─────────────────────────────────────────────

  void _subscribeToRide(String rideId) {
    _rideSub?.cancel();
    _rideSub = _repo.watchRide(rideId).listen(
          (ride) => _applyRide(ride),
      onError: (_) {/* сетевые ошибки — молча */},
    );
  }

  /// Маппит ride_status → OrderStage и обновляет кубит.
  void _applyRide(RideModel ride) {
    final stage = _stageFromStatus(ride.status);
    if (stage == null) return; // completed/cancelled/expired обработаны ниже

    // Терминальные статусы
    if (ride.status == RideStatus.completed) {
      emit(state.copyWith(
        stage: OrderStage.rating,
        rideId: ride.id,
        priceFinal: ride.priceFinal ?? ride.priceEstimated,
        isLoading: false,
      ));
      return;
    }

    if (ride.status == RideStatus.cancelled ||
        ride.status == RideStatus.expired) {
      _rideSub?.cancel();
      _rideSub = null;
      emit(state.initial);
      return;
    }

    // Загружаем карточку водителя при первом появлении driver_id.
    if (ride.driverId != null && state.driverCard == null) {
      _loadDriverCard(ride.driverId!);
    }

    emit(state.copyWith(
      stage: stage,
      rideId: ride.id,
      freeWaitUntil: ride.freeWaitUntil,
      isLoading: false,
      clearError: true,
    ));
  }

  /// Конвертирует ride_status в OrderStage. null = не нужно менять стадию.
  OrderStage? _stageFromStatus(RideStatus status) => switch (status) {
    RideStatus.searching => OrderStage.searching,
    RideStatus.accepted => OrderStage.driverFound,
    RideStatus.arrived => OrderStage.driverWaiting,
    RideStatus.inProgress => OrderStage.riding,
    _ => null,
  };

  // ─────────────────── Карточка водителя ───────────────────────────────────

  Future<void> _loadDriverCard(String driverId) async {
    try {
      final card = await _repo.getDriverCard(driverId);
      if (card != null) {
        emit(state.copyWith(driverCard: card));
      }
    } catch (_) {/* некритично */}
  }

  // ─────────────────── Вспомогательные методы ──────────────────────────────

  String _humanError(Object e) {
    final msg = e.toString();
    if (msg.contains('auth required')) return 'Требуется авторизация';
    if (msg.contains('at least one destination')) return 'Укажите адрес назначения';
    return 'Что-то пошло не так. Попробуйте ещё раз.';
  }

  // ─────────────────── Закрытие ─────────────────────────────────────────────

  @override
  Future<void> close() async {
    await _rideSub?.cancel();
    await _repo.unsubscribeRide();
    return super.close();
  }
}