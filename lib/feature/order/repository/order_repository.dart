// lib/feature/order/repository/order_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Все вызовы Supabase, связанные с заказом:
//   • request_ride  — создать заказ (RPC)
//   • cancel_ride   — отменить заказ (RPC)
//   • rate_ride     — оценить поездку (RPC)
//   • driver_card   — карточка водителя (RPC)
//   • getActiveRide — найти активный заказ клиента
//   • watchRide     — Realtime Stream по id поездки
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taxi/core/enums/ride_enums.dart';
import 'package:taxi/feature/order/model/driver_card_model.dart';
import 'package:taxi/feature/order/model/ride_model.dart';

class OrderRepository {
  OrderRepository() : _db = Supabase.instance.client;

  final SupabaseClient _db;

  // ─────────────────── Активный заказ ───────────────────────────────────────

  /// Ищет незавершённый заказ текущего клиента.
  /// Вызывается при старте экрана, чтобы восстановить состояние.
  Future<RideModel?> getActiveRide() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;

    final data = await _db
        .from('rides')
        .select()
        .eq('client_id', uid)
        .inFilter('status', [
          'searching',
          'accepted',
          'arrived',
          'in_progress',
        ])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return RideModel.fromMap(data);
  }

  // ─────────────────── Создание заказа ──────────────────────────────────────

  /// Вызывает RPC request_ride и возвращает созданную поездку.
  ///
  /// [rideClass]      — выбранный тариф (econom/comfort/business)
  /// [paymentMethod]  — способ оплаты (cash/card)
  /// [pickupAddress]  — адрес подачи (текстовый)
  /// [pickupLat/Lng]  — координаты подачи
  /// [distanceKm]     — расстояние маршрута
  /// [durationMin]    — примерное время в пути
  /// [priceEstimated] — предварительная цена
  /// [stops]          — точки назначения: [{address, lat, lng}, ...]
  Future<RideModel> requestRide({
    required RideClass rideClass,
    required PaymentMethod paymentMethod,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required double distanceKm,
    required int durationMin,
    required int priceEstimated,
    required List<Map<String, dynamic>> stops,
  }) async {
    final result = await _db.rpc('request_ride', params: {
      'p_ride_class': rideClass.dbValue,
      'p_payment_method': paymentMethod.dbValue,
      'p_pickup_address': pickupAddress,
      'p_pickup_lat': pickupLat,
      'p_pickup_lng': pickupLng,
      'p_distance_km': distanceKm,
      'p_duration_min': durationMin,
      'p_price_estimated': priceEstimated,
      'p_stops': stops,
    });

    // RPC возвращает одну строку rides (не массив).
    if (result is Map<String, dynamic>) {
      return RideModel.fromMap(result);
    }
    if (result is List && result.isNotEmpty) {
      return RideModel.fromMap(result.first as Map<String, dynamic>);
    }
    throw StateError('request_ride вернул неожиданный формат: $result');
  }

  // ─────────────────── Отмена заказа ────────────────────────────────────────

  /// Отменяет заказ. Доступно клиенту и водителю на статусах
  /// searching / accepted / arrived.
  Future<RideModel> cancelRide(String rideId, {String? reason}) async {
    final result = await _db.rpc('cancel_ride', params: {
      'p_ride_id': rideId,
      if (reason != null) 'p_reason': reason,
    });

    if (result is Map<String, dynamic>) return RideModel.fromMap(result);
    if (result is List && result.isNotEmpty) {
      return RideModel.fromMap(result.first as Map<String, dynamic>);
    }
    throw StateError('cancel_ride вернул неожиданный формат');
  }

  // ─────────────────── Оценка поездки ───────────────────────────────────────

  /// Оценивает завершённую поездку. Клиент оценивает водителя.
  /// [stars]   — от 1 до 5
  /// [comment] — необязательный текст
  /// [tags]    — теги ('Чисто', 'Вежливый водитель', …)
  Future<void> rateRide({
    required String rideId,
    required int stars,
    String? comment,
    List<String> tags = const [],
  }) async {
    await _db.rpc('rate_ride', params: {
      'p_ride_id': rideId,
      'p_stars': stars,
      if (comment != null && comment.isNotEmpty) 'p_comment': comment,
      'p_tags': tags,
    });
  }

  // ─────────────────── Карточка водителя ────────────────────────────────────

  /// Загружает публичную карточку водителя: имя, рейтинг, авто.
  /// Вызывается после перехода в статус accepted (driver_id появился).
  Future<DriverCardModel?> getDriverCard(String driverId) async {
    final result = await _db.rpc('driver_card', params: {
      'p_driver_id': driverId,
    });

    if (result == null) return null;

    final map = result is Map<String, dynamic>
        ? result
        : (result as List?)?.first as Map<String, dynamic>?;

    if (map == null) return null;
    return DriverCardModel.fromMap(map);
  }

  // ─────────────────── Realtime подписка ────────────────────────────────────

  // Активный канал. Храним ссылку, чтобы отписаться при необходимости.
  RealtimeChannel? _rideChannel;

  /// Возвращает Stream обновлений конкретной поездки через Realtime.
  /// Каждый раз, когда статус меняется на стороне Postgres, приходит
  /// новый [RideModel].
  Stream<RideModel> watchRide(String rideId) {
    final controller = StreamController<RideModel>.broadcast();

    // Сначала сразу читаем текущее состояние, чтобы UI не ждал первого события.
    _db
        .from('rides')
        .select()
        .eq('id', rideId)
        .single()
        .then((data) {
          if (!controller.isClosed) {
            controller.add(RideModel.fromMap(data));
          }
        })
        .catchError((_) {});

    // Подписываемся на UPDATE через Realtime channel.
    _rideChannel = _db
        .channel('ride_watch_$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            if (!controller.isClosed) {
              try {
                controller.add(RideModel.fromMap(payload.newRecord));
              } catch (e) {
                controller.addError(e);
              }
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _rideChannel?.unsubscribe();
      _rideChannel = null;
    };

    return controller.stream;
  }

  /// Отписывается от Realtime. Вызывается при отмене/завершении поездки.
  Future<void> unsubscribeRide() async {
    await _rideChannel?.unsubscribe();
    _rideChannel = null;
  }

  // ─────────────────── Недавние адреса ──────────────────────────────────────

  /// Сохраняет адрес в recent_places (upsert по user_id + address).
  Future<void> upsertRecentPlace({
    required String address,
    required double lat,
    required double lng,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    await _db.from('recent_places').upsert(
      {
        'user_id': uid,
        'address': address,
        'lat': lat,
        'lng': lng,
        'last_used_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,address',
    );
  }
}
