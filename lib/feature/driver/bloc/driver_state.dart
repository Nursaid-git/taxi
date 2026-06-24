// lib/feature/driver/bloc/driver_state.dart

import 'package:equatable/equatable.dart';

import '../repository/driver_order.dart';

enum DriverStage {
  offline,
  online,
  incoming,
  toPickup,
  waiting,
  inProgress,
}

class DriverState extends Equatable {
  final DriverStage stage;
  final DriverOrder? order;
  final int todayEarnings;
  final int todayRides;
  final double ratingAvg;
  final bool isLoading;
  final String? errorMessage;

  const DriverState({
    this.stage = DriverStage.offline,
    this.order,
    this.todayEarnings = 0,
    this.todayRides = 0,
    this.ratingAvg = 5.0,
    this.isLoading = false,
    this.errorMessage,
  });

  DriverState copyWith({
    DriverStage? stage,
    DriverOrder? order,
    bool clearOrder = false,
    int? todayEarnings,
    int? todayRides,
    double? ratingAvg,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriverState(
      stage: stage ?? this.stage,
      order: clearOrder ? null : (order ?? this.order),
      todayEarnings: todayEarnings ?? this.todayEarnings,
      todayRides: todayRides ?? this.todayRides,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        stage, order, todayEarnings, todayRides,
        ratingAvg, isLoading, errorMessage,
      ];
}
