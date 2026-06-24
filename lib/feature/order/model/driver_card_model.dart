// lib/feature/order/model/driver_card_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Модель ответа функции public.driver_card(p_driver_id).
// RPC возвращает JSONB: имя, рейтинг, авто водителя.
// Используется для отображения данных водителя в панелях driverFound,
// driverWaiting и riding.
// ─────────────────────────────────────────────────────────────────────────────

class DriverCardModel {
  final String driverId;
  final String fullName;
  final double ratingAvg;
  final int ratingCount;
  final int tripsCount;
  final VehicleInfo? vehicle;

  const DriverCardModel({
    required this.driverId,
    required this.fullName,
    required this.ratingAvg,
    required this.ratingCount,
    required this.tripsCount,
    this.vehicle,
  });

  factory DriverCardModel.fromMap(Map<String, dynamic> m) {
    final v = m['vehicle'] as Map<String, dynamic>?;
    return DriverCardModel(
      driverId: m['driver_id'] as String,
      fullName: m['full_name'] as String? ?? 'Водитель',
      ratingAvg: (m['rating_avg'] as num?)?.toDouble() ?? 5.0,
      ratingCount: m['rating_count'] as int? ?? 0,
      tripsCount: m['trips_count'] as int? ?? 0,
      vehicle: v != null ? VehicleInfo.fromMap(v) : null,
    );
  }

  /// Строка «Toyota Camry, белый» для показа под именем.
  String get carLabel {
    if (vehicle == null) return '';
    final parts = [
      vehicle!.brand,
      vehicle!.model,
      if (vehicle!.color != null) vehicle!.color!,
    ];
    return parts.join(' ');
  }

  /// Номер для отображения в карточке.
  String get plateLabel => vehicle?.plate ?? '';
}

class VehicleInfo {
  final String brand;
  final String model;
  final String? color;
  final String plate;

  const VehicleInfo({
    required this.brand,
    required this.model,
    this.color,
    required this.plate,
  });

  factory VehicleInfo.fromMap(Map<String, dynamic> m) => VehicleInfo(
        brand: m['brand'] as String? ?? '',
        model: m['model'] as String? ?? '',
        color: m['color'] as String?,
        plate: m['plate'] as String? ?? '',
      );
}
