part of 'driver_cubit.dart';

/// Стадии работы водителя на главном экране.
enum DriverStage {
  offline, // не на линии
  online, // на линии, ждём заказ
  incoming, // пришёл заказ (таймер на принятие)
  toPickup, // принял, едет за клиентом
  waiting, // на месте, ждём клиента (до старта поездки)
  inProgress, // поездка идёт
}

/// Входящий заказ для водителя.
class DriverOrder {
  final String pickup;
  final String destination;
  final int km;
  final int min;
  final int price;
  final String clientName;
  final double clientRating;
  final LatLng pickupPoint;
  final LatLng destPoint;
  const DriverOrder(
    this.pickup,
    this.destination,
    this.km,
    this.min,
    this.price,
    this.clientName,
    this.clientRating,
    this.pickupPoint,
    this.destPoint,
  );
}

class DriverState extends Equatable {
  final DriverStage stage;
  final DriverOrder? order;
  final int todayRides;
  final int todayEarnings;

  const DriverState({
    this.stage = DriverStage.offline,
    this.order,
    this.todayRides = 0,
    this.todayEarnings = 0,
  });

  DriverState copyWith({
    DriverStage? stage,
    DriverOrder? order,
    bool clearOrder = false,
    int? todayRides,
    int? todayEarnings,
  }) {
    return DriverState(
      stage: stage ?? this.stage,
      order: clearOrder ? null : (order ?? this.order),
      todayRides: todayRides ?? this.todayRides,
      todayEarnings: todayEarnings ?? this.todayEarnings,
    );
  }

  @override
  List<Object?> get props => [stage, order, todayRides, todayEarnings];
}
