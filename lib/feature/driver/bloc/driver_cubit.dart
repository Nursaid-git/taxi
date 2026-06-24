// lib/feature/driver/bloc/driver_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taxi/feature/driver/bloc/driver_state.dart';
import 'package:taxi/feature/driver/repository/driver_repository.dart';

import '../repository/driver_order.dart';

class DriverCubit extends Cubit<DriverState> {
  final DriverRepository _repo;

  RealtimeChannel? _searchingChannel;
  RealtimeChannel? _myRideChannel;

  DriverCubit({DriverRepository? repository})
      : _repo = repository ?? DriverRepository(),
        super(const DriverState()) {
    _init();
  }

  // ─────────────────────── Инициализация ───────────────────────

  Future<void> _init() async {
    emit(state.copyWith(isLoading: true));
    try {
      final profile = await _repo.fetchMyProfile();
      final isOnline = profile?['is_online'] as bool? ?? false;
      final today = await _repo.fetchTodayEarnings();

      DriverOrder? activeOrder;
      DriverStage initialStage = DriverStage.offline;

      if (isOnline) {
        activeOrder = await _repo.fetchActiveRide();
        if (activeOrder != null) {
          initialStage = DriverStage.toPickup;
          _subscribeToMyRide(activeOrder.id);
        } else {
          initialStage = DriverStage.online;
          _subscribeToSearchingRides();
        }
      }

      emit(state.copyWith(
        stage: initialStage,
        order: activeOrder,
        todayEarnings: today.earnings,
        todayRides: today.rides,
        ratingAvg: (profile?['rating_avg'] as num?)?.toDouble() ?? 5.0,
        isLoading: false,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Ошибка загрузки: $e',
      ));
    }
  }

  // ─────────────────────── Онлайн / офлайн ───────────────────────

  Future<void> goOnline() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repo.goOnline();
      _subscribeToSearchingRides();
      emit(state.copyWith(stage: DriverStage.online, isLoading: false));
    } on PostgrestException catch (e) {
      final msg = e.message.contains('not approved')
          ? 'Ваш профиль ещё не проверен'
          : 'Ошибка: ${e.message}';
      emit(state.copyWith(isLoading: false, errorMessage: msg));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Ошибка: $e'));
    }
  }

  Future<void> goOffline() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repo.goOffline();
      _cancelSearchingSubscription();
      emit(state.copyWith(
        stage: DriverStage.offline,
        clearOrder: true,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Ошибка: $e'));
    }
  }

  // ─────────────────────── Принять заказ ───────────────────────

  Future<void> accept() async {
    final rideId = state.order?.id;
    if (rideId == null) return;

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final order = await _repo.acceptRide(rideId);
      _cancelSearchingSubscription();
      _subscribeToMyRide(rideId);
      emit(state.copyWith(
        stage: DriverStage.toPickup,
        order: order,
        isLoading: false,
      ));
    } on PostgrestException catch (e) {
      final msg = e.message.contains('no longer available')
          ? 'Заказ уже занят'
          : 'Ошибка: ${e.message}';
      emit(state.copyWith(
        stage: DriverStage.online,
        clearOrder: true,
        isLoading: false,
        errorMessage: msg,
      ));
    } catch (e) {
      emit(state.copyWith(
        stage: DriverStage.online,
        clearOrder: true,
        isLoading: false,
        errorMessage: 'Ошибка: $e',
      ));
    }
  }

  Future<void> decline() async {
    final currentStage = state.stage;
    final rideId = state.order?.id;

    if ((currentStage == DriverStage.toPickup ||
            currentStage == DriverStage.waiting) &&
        rideId != null) {
      emit(state.copyWith(isLoading: true, clearError: true));
      try {
        await _repo.cancelRide(rideId, reason: 'Водитель отменил поездку');
        _cancelMyRideSubscription();
        _subscribeToSearchingRides();
        emit(state.copyWith(
          stage: DriverStage.online,
          clearOrder: true,
          isLoading: false,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, errorMessage: 'Ошибка: $e'));
      }
    } else {
      emit(state.copyWith(stage: DriverStage.online, clearOrder: true));
    }
  }

  // ─────────────────────── Я на месте ───────────────────────

  Future<void> arrived() async {
    final rideId = state.order?.id;
    if (rideId == null) return;

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repo.driverArrived(rideId);
      emit(state.copyWith(stage: DriverStage.waiting, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Ошибка: $e'));
    }
  }

  // ─────────────────────── Начать поездку ───────────────────────

  Future<void> startTrip() async {
    final rideId = state.order?.id;
    if (rideId == null) return;

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repo.startRide(rideId);
      emit(state.copyWith(stage: DriverStage.inProgress, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Ошибка: $e'));
    }
  }

  // ─────────────────────── Завершить поездку ───────────────────────

  Future<void> complete() async {
    final rideId = state.order?.id;
    if (rideId == null) return;

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repo.completeRide(rideId);
      _cancelMyRideSubscription();
      final today = await _repo.fetchTodayEarnings();
      _subscribeToSearchingRides();
      emit(state.copyWith(
        stage: DriverStage.online,
        clearOrder: true,
        todayEarnings: today.earnings,
        todayRides: today.rides,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Ошибка: $e'));
    }
  }

  // ─────────────────────── Очистить ошибку ───────────────────────

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  // ─────────────────────── Realtime ───────────────────────

  void _subscribeToSearchingRides() {
    _cancelSearchingSubscription();
    _searchingChannel = _repo.subscribeToSearchingRides(
      onNewRide: (order) {
        if (state.stage == DriverStage.online) {
          emit(state.copyWith(stage: DriverStage.incoming));
        }
      },
    );
  }

  void _subscribeToMyRide(String rideId) {
    _cancelMyRideSubscription();
    _myRideChannel = _repo.subscribeToMyRide(
      rideId: rideId,
      onStatusChange: (status, ride) {
        switch (status) {
          case 'accepted':
            emit(state.copyWith(stage: DriverStage.toPickup));
          case 'arrived':
            emit(state.copyWith(stage: DriverStage.waiting));
          case 'in_progress':
            emit(state.copyWith(stage: DriverStage.inProgress));
          case 'completed':
            _cancelMyRideSubscription();
            _subscribeToSearchingRides();
            emit(state.copyWith(stage: DriverStage.online, clearOrder: true));
          case 'cancelled':
            _cancelMyRideSubscription();
            _subscribeToSearchingRides();
            emit(state.copyWith(
              stage: DriverStage.online,
              clearOrder: true,
              errorMessage: 'Клиент отменил заказ',
            ));
        }
      },
    );
  }

  void _cancelSearchingSubscription() {
    _searchingChannel?.unsubscribe();
    _searchingChannel = null;
  }

  void _cancelMyRideSubscription() {
    _myRideChannel?.unsubscribe();
    _myRideChannel = null;
  }

  @override
  Future<void> close() async {
    _cancelSearchingSubscription();
    _cancelMyRideSubscription();
    return super.close();
  }
}
