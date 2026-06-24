// lib/feature/driver/model/driver_order.dart

import 'package:latlong2/latlong.dart';

class DriverOrder {
  /// rides.id — UUID заказа в Supabase. Нужен для всех RPC вызовов.
  final String id;

  final String clientName;
  final double clientRating;
  final String pickup;
  final String destination;
  final LatLng pickupPoint;
  final LatLng destPoint;
  final int price;
  final double km;
  final int min;

  const DriverOrder({
    required this.id,
    required this.clientName,
    required this.clientRating,
    required this.pickup,
    required this.destination,
    required this.pickupPoint,
    required this.destPoint,
    required this.price,
    required this.km,
    required this.min,
  });

  factory DriverOrder.fromSupabase({
    required Map<String, dynamic> ride,
    required List<Map<String, dynamic>> stops,
    required Map<String, dynamic> profile,
  }) {
    final firstStop = stops.isNotEmpty ? stops[0] : <String, dynamic>{};

    return DriverOrder(
      id: ride['id'] as String,
      clientName: (profile['full_name'] as String?) ?? 'Клиент',
      clientRating: 5.0,
      pickup: ride['pickup_address'] as String? ?? '',
      destination: firstStop['address'] as String? ?? '',
      pickupPoint: LatLng(
        (ride['pickup_lat'] as num).toDouble(),
        (ride['pickup_lng'] as num).toDouble(),
      ),
      destPoint: LatLng(
        (firstStop['lat'] as num?)?.toDouble() ?? 0.0,
        (firstStop['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      price: (ride['price_estimated'] as int?) ?? 0,
      km: (ride['distance_km'] as num?)?.toDouble() ?? 0.0,
      min: (ride['duration_min'] as int?) ?? 0,
    );
  }
}
