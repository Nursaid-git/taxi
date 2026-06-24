// lib/feature/driver/repository/driver_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver_order.dart';

class DriverRepository {
  final SupabaseClient _db;

  DriverRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  // ─────────────────────── Профиль водителя ───────────────────────

  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;

    return await _db
        .from('driver_profiles')
        .select('is_online, rating_avg, trips_count, balance')
        .eq('id', uid)
        .maybeSingle();
  }

  // ─────────────────────── Онлайн / офлайн ───────────────────────

  Future<void> goOnline() async {
    await _db.rpc('set_driver_online', params: {'p_online': true});
  }

  Future<void> goOffline() async {
    await _db.rpc('set_driver_online', params: {'p_online': false});
  }

  // ─────────────────────── Активный заказ ───────────────────────

  Future<DriverOrder?> fetchActiveRide() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;

    final ride = await _db
        .from('rides')
        .select('*')
        .eq('driver_id', uid)
        .inFilter('status', ['accepted', 'arrived', 'in_progress'])
        .maybeSingle();

    if (ride == null) return null;
    return _buildOrder(ride);
  }

  // ─────────────────────── Lifecycle RPC ───────────────────────

  Future<DriverOrder> acceptRide(String rideId) async {
    final result = await _db.rpc(
      'accept_ride',
      params: {'p_ride_id': rideId},
    );
    return _buildOrder(result as Map<String, dynamic>);
  }

  Future<void> driverArrived(String rideId) async {
    await _db.rpc('driver_arrived', params: {'p_ride_id': rideId});
  }

  Future<void> startRide(String rideId) async {
    await _db.rpc('start_ride', params: {'p_ride_id': rideId});
  }

  Future<void> completeRide(String rideId) async {
    await _db.rpc('complete_ride', params: {'p_ride_id': rideId});
  }

  Future<void> cancelRide(String rideId, {String? reason}) async {
    await _db.rpc('cancel_ride', params: {
      'p_ride_id': rideId,
      'p_reason': reason,
    });
  }

  // ─────────────────────── Realtime ───────────────────────

  // ✅ Исправление в driver_repository.dart
  RealtimeChannel subscribeToSearchingRides({
    required void Function(DriverOrder order) onNewRide,
  }) {
    return _db
        .channel('driver_searching_rides')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'rides',
      // ← убираем filter совсем
      callback: (payload) async {
        final record = payload.newRecord;
        // ← фильтруем вручную
        if (record['status'] != 'searching') return;
        try {
          final order = await _buildOrder(record);
          onNewRide(order);
        } catch (_) {}
      },
    )
        .subscribe();
  }

  RealtimeChannel subscribeToMyRide({
    required String rideId,
    required void Function(String status, Map<String, dynamic> ride) onStatusChange,
  }) {
    return _db
        .channel('driver_ride_$rideId')
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
            final updated = payload.newRecord;
            final status = updated['status'] as String? ?? '';
            onStatusChange(status, updated);
          },
        )
        .subscribe();
  }

  // ─────────────────────── Заработок сегодня ───────────────────────

  Future<({int earnings, int rides})> fetchTodayEarnings() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return (earnings: 0, rides: 0);

    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day).toIso8601String();

    final rows = await _db
        .from('rides')
        .select('price_final, price_estimated')
        .eq('driver_id', uid)
        .eq('status', 'completed')
        .gte('completed_at', startOfDay);

    final list = rows as List<dynamic>;
    int total = 0;
    for (final r in list) {
      final m = r as Map<String, dynamic>;
      total +=
          (m['price_final'] as int?) ?? (m['price_estimated'] as int?) ?? 0;
    }
    return (earnings: total, rides: list.length);
  }

  // ─────────────────────── Helpers ───────────────────────

  Future<DriverOrder> _buildOrder(Map<String, dynamic> ride) async {
    final rideId = ride['id'] as String;
    final clientId = ride['client_id'] as String;

    final results = await Future.wait([
      _db
          .from('ride_stops')
          .select('*')
          .eq('ride_id', rideId)
          .order('position'),
      _db
          .from('profiles')
          .select('full_name')
          .eq('id', clientId)
          .maybeSingle(),
    ]);

    final stops = (results[0] as List<dynamic>)
        .map((s) => s as Map<String, dynamic>)
        .toList();

    final profile = (results[1] as Map<String, dynamic>?) ?? {};

    return DriverOrder.fromSupabase(
      ride: ride,
      stops: stops,
      profile: profile,
    );
  }
}
