import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

part 'driver_state.dart';

/// Логика главного экрана водителя: смена статуса, входящие заказы,
/// поездка и заработок. Без перехода на другие экраны.
class DriverCubit extends Cubit<DriverState> {
  DriverCubit() : super(const DriverState());

  int _seq = 0;

  static const _orders = <DriverOrder>[
    DriverOrder('ул. Лакоба, 12', 'Аэропорт Сухум', 18, 25, 650, 'Алхас', 4.8,
        LatLng(43.0040, 41.0210), LatLng(43.0150, 41.0450)),
    DriverOrder('Набережная Махаджиров', 'Рынок', 4, 12, 280, 'Лана', 5.0,
        LatLng(42.9980, 41.0300), LatLng(43.0090, 41.0180)),
    DriverOrder('пр. Мира, 5', 'Новый Афон', 25, 35, 850, 'Дмитрий', 4.9,
        LatLng(43.0060, 41.0330), LatLng(43.0200, 41.0500)),
  ];

  /// Выйти на линию — начинаем ждать заказы.
  void goOnline() {
    emit(state.copyWith(stage: DriverStage.online, clearOrder: true));
    _scheduleIncoming();
  }

  /// Завершить смену.
  void goOffline() =>
      emit(state.copyWith(stage: DriverStage.offline, clearOrder: true));

  /// Через паузу присылаем входящий заказ (демо-логика).
  Future<void> _scheduleIncoming() async {
    await Future.delayed(const Duration(seconds: 3));
    if (isClosed || state.stage != DriverStage.online) return;
    final order = _orders[_seq % _orders.length];
    _seq++;
    emit(state.copyWith(stage: DriverStage.incoming, order: order));
  }

  /// Принять заказ — едем за клиентом.
  void accept() => emit(state.copyWith(stage: DriverStage.toPickup));

  /// Отклонить / отменить — снова на линии, ждём следующий.
  void decline() {
    emit(state.copyWith(stage: DriverStage.online, clearOrder: true));
    _scheduleIncoming();
  }

  /// Прибыл к клиенту — ждём, пока он сядет.
  void arrived() => emit(state.copyWith(stage: DriverStage.waiting));

  /// Начать поездку (платный режим).
  void startTrip() => emit(state.copyWith(stage: DriverStage.inProgress));

  /// Завершить поездку — плюсуем заработок, снова на линии.
  void complete() {
    final earn = state.order?.price ?? 0;
    emit(state.copyWith(
      stage: DriverStage.online,
      clearOrder: true,
      todayRides: state.todayRides + 1,
      todayEarnings: state.todayEarnings + earn,
    ));
    _scheduleIncoming();
  }
}
