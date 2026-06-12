part of 'order_cubit.dart';

/// Стадии заказа — всё в пределах одного экрана.
enum OrderStage {
  idle, // главная: «Куда едем?» + чипы + недавние
  search, // ввод/поиск адреса (поле развёрнуто, список подсказок)
  mapPick, // выбор точки на карте (шторка скрыта, тапаем по карте)
  tariffs, // адреса выбраны — выбор модели и цена
  searching, // ищем водителя (анимация)
  driverFound, // водитель найден, едет к вам
  driverWaiting, // водитель приехал, ждёт вас
  riding, // поездка идёт (платный режим)
  rating, // приехали — оцените поездку
}

class OrderState extends Equatable {
  final OrderStage stage;
  final List<Place> stops; // точки назначения (можно несколько)
  final bool addingStop; // поиск открыт для ДОБАВЛЕНИЯ остановки
  final int selectedTariff;
  final String query;
  final LatLng? mapPoint;

  const OrderState({
    this.stage = OrderStage.idle,
    this.stops = const [],
    this.addingStop = false,
    this.selectedTariff = 0,
    this.query = '',
    this.mapPoint,
  });

  bool get hasStops => stops.isNotEmpty;
  Place? get lastStop => stops.isEmpty ? null : stops.last;
  int get totalBase => stops.fold(0, (s, p) => s + p.base);
  int get totalKm => stops.fold(0, (s, p) => s + p.km);
  int get totalMin => stops.fold(0, (s, p) => s + p.min);

  OrderState copyWith({
    OrderStage? stage,
    List<Place>? stops,
    bool clearStops = false,
    bool? addingStop,
    int? selectedTariff,
    String? query,
    LatLng? mapPoint,
    bool clearMapPoint = false,
  }) {
    return OrderState(
      stage: stage ?? this.stage,
      stops: clearStops ? const [] : (stops ?? this.stops),
      addingStop: addingStop ?? this.addingStop,
      selectedTariff: selectedTariff ?? this.selectedTariff,
      query: query ?? this.query,
      mapPoint: clearMapPoint ? null : (mapPoint ?? this.mapPoint),
    );
  }

  @override
  List<Object?> get props =>
      [stage, stops, addingStop, selectedTariff, query, mapPoint];
}
