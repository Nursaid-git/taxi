// lib/feature/order/model/ride_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Dart-модель таблицы public.rides.
// fromMap принимает ответ Supabase (Map<String, dynamic>) и превращает в объект.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:taxi/core/enums/ride_enums.dart';

class RideModel {
  final String id;
  final String clientId;
  final String? driverId;
  final RideStatus status;
  final RideClass rideClass;
  final PaymentMethod paymentMethod;

  // Точка подачи
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;

  // Маршрут и цена
  final double? distanceKm;
  final int? durationMin;
  final int priceEstimated;
  final int? priceFinal;

  // Ожидание
  final DateTime? freeWaitUntil;
  final int waitCharge;

  // Отмена
  final RideActor? cancelledBy;
  final String? cancelReason;

  // Временные метки
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime updatedAt;

  const RideModel({
    required this.id,
    required this.clientId,
    this.driverId,
    required this.status,
    required this.rideClass,
    required this.paymentMethod,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    this.distanceKm,
    this.durationMin,
    required this.priceEstimated,
    this.priceFinal,
    this.freeWaitUntil,
    this.waitCharge = 0,
    this.cancelledBy,
    this.cancelReason,
    required this.createdAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    required this.updatedAt,
  });

  factory RideModel.fromMap(Map<String, dynamic> m) {
    return RideModel(
      id: m['id'] as String,
      clientId: m['client_id'] as String,
      driverId: m['driver_id'] as String?,
      status: RideStatus.fromString(m['status'] as String),
      rideClass: RideClass.fromString(m['ride_class'] as String),
      paymentMethod: PaymentMethod.fromString(m['payment_method'] as String),
      pickupAddress: m['pickup_address'] as String,
      pickupLat: (m['pickup_lat'] as num).toDouble(),
      pickupLng: (m['pickup_lng'] as num).toDouble(),
      distanceKm: (m['distance_km'] as num?)?.toDouble(),
      durationMin: m['duration_min'] as int?,
      priceEstimated: m['price_estimated'] as int,
      priceFinal: m['price_final'] as int?,
      freeWaitUntil: m['free_wait_until'] != null
          ? DateTime.parse(m['free_wait_until'] as String)
          : null,
      waitCharge: m['wait_charge'] as int? ?? 0,
      cancelledBy: m['cancelled_by'] != null
          ? RideActor.fromString(m['cancelled_by'] as String)
          : null,
      cancelReason: m['cancel_reason'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      acceptedAt: m['accepted_at'] != null
          ? DateTime.parse(m['accepted_at'] as String)
          : null,
      arrivedAt: m['arrived_at'] != null
          ? DateTime.parse(m['arrived_at'] as String)
          : null,
      startedAt: m['started_at'] != null
          ? DateTime.parse(m['started_at'] as String)
          : null,
      completedAt: m['completed_at'] != null
          ? DateTime.parse(m['completed_at'] as String)
          : null,
      cancelledAt: m['cancelled_at'] != null
          ? DateTime.parse(m['cancelled_at'] as String)
          : null,
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  /// Возвращает true, если поездка считается «активной» (нельзя создать новую).
  bool get isActive => switch (status) {
        RideStatus.searching ||
        RideStatus.accepted ||
        RideStatus.arrived ||
        RideStatus.inProgress =>
          true,
        _ => false,
      };
}
