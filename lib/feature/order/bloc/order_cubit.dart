import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi/feature/order/order_models.dart';

part 'order_state.dart';

/// Управляет всем процессом заказа в пределах главного экрана —
/// без перехода на другие экраны.
class OrderCubit extends Cubit<OrderState> {
  OrderCubit() : super(const OrderState());

  static const _pickup = LatLng(43.0015, 41.0234); // моё местоположение

  /// Тапнули по полю адреса — новый поиск (сбрасываем точки).
  void openSearch() => emit(state.copyWith(
        stage: OrderStage.search,
        clearStops: true,
        addingStop: false,
        query: '',
      ));

  /// Добавить ещё одну точку — поиск в режиме добавления (точки сохраняются).
  void addStopSearch() => emit(state.copyWith(
        stage: OrderStage.search,
        addingStop: true,
        query: '',
      ));

  /// Ввод текста в поле адреса.
  void setQuery(String q) =>
      emit(state.copyWith(stage: OrderStage.search, query: q));

  /// Выбрали адрес — добавляем точку (или начинаем новый список).
  void pickPlace(Place p) {
    final stops = state.addingStop ? [...state.stops, p] : [p];
    emit(state.copyWith(
      stage: OrderStage.tariffs,
      stops: stops,
      addingStop: false,
      query: '',
      clearMapPoint: true,
    ));
  }

  /// Убрать точку. Если не осталось ни одной — на главную.
  void removeStop(int index) {
    final stops = [...state.stops]..removeAt(index);
    if (stops.isEmpty) {
      emit(const OrderState());
    } else {
      emit(state.copyWith(stage: OrderStage.tariffs, stops: stops));
    }
  }

  /// Режим выбора точки на карте (шторка прячется).
  void enterMapPick() =>
      emit(state.copyWith(stage: OrderStage.mapPick, clearMapPoint: true));

  void setMapPoint(LatLng p) => emit(state.copyWith(mapPoint: p));

  /// Подтвердили точку на карте — считаем расстояние/цену, добавляем точку.
  void confirmMapPoint() {
    final p = state.mapPoint;
    if (p == null) return;
    final km = const Distance()
        .as(LengthUnit.Kilometer, _pickup, p)
        .round()
        .clamp(1, 200);
    final min = (km * 1.6).round().clamp(3, 200);
    final base = ((km * 40 + 150) / 10).round() * 10;
    final place = Place('Точка на карте', 'Выбрано на карте', km, min, base);
    final stops = state.addingStop ? [...state.stops, place] : [place];
    emit(state.copyWith(
      stage: OrderStage.tariffs,
      stops: stops,
      addingStop: false,
      query: '',
    ));
  }

  void selectTariff(int i) => emit(state.copyWith(selectedTariff: i));

  /// Заказать — демо-логика: ищем → водитель едет → ждёт вас.
  /// Дальше поездку запускает [startRiding] (после ожидания).
  Future<void> confirm() async {
    emit(state.copyWith(stage: OrderStage.searching));
    if (await _wait(3500, OrderStage.searching)) return;
    emit(state.copyWith(stage: OrderStage.driverFound));
    if (await _wait(4000, OrderStage.driverFound)) return;
    emit(state.copyWith(stage: OrderStage.driverWaiting));
  }

  /// Начать поездку (после ожидания) → едем → приехали (оценка).
  Future<void> startRiding() async {
    emit(state.copyWith(stage: OrderStage.riding));
    if (await _wait(4500, OrderStage.riding)) return;
    emit(state.copyWith(stage: OrderStage.rating));
  }

  /// Пауза. Возвращает true, если стадия сменилась (пользователь отменил) —
  /// тогда цепочку нужно прервать.
  Future<bool> _wait(int ms, OrderStage expected) async {
    await Future.delayed(Duration(milliseconds: ms));
    return isClosed || state.stage != expected;
  }

  /// Оценка поездки завершена — возвращаемся на главную.
  void submitRating() => emit(const OrderState());

  /// Отмена / возврат к началу.
  void reset() => emit(const OrderState());
}
