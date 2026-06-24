import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/utils/launchers.dart';
import 'package:taxi/core/widgets/app_button_widget.dart';
import 'package:taxi/feature/chat/chat_screen.dart';
import 'package:taxi/feature/order/bloc/order_cubit.dart';
import 'package:taxi/feature/order/model/order_models.dart';

// Данные найденного водителя (демо).
String _driverName(OrderState s) =>
    s.driverCard?.fullName ?? 'Водитель';

String _driverCar(OrderState s) =>
    s.driverCard?.carLabel ?? '—';

String _driverPlate(OrderState s) =>
    s.driverCard?.plateLabel ?? '—';

String _driverRating(OrderState s) =>
    s.driverCard != null
        ? s.driverCard!.ratingAvg.toStringAsFixed(1)
        : '5.0';
String get _driverPhone => '+7 940 000 00 00';

/// Главный экран КЛИЕНТА. Весь заказ происходит ЗДЕСЬ, в нижней шторке —
/// без перехода на другие экраны (таб-бар остаётся видимым). Логика — [OrderCubit].
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrderCubit(),
      child: const _ClientHomeView(),
    );
  }
}

// Чипы быстрых адресов → конкретные места.
const _chips = <(IconData, Place)>[
  (Icons.home_rounded, Place('Дом', 'ул. Лакоба, 12', 4, 12, 280)),
  (Icons.work_rounded, Place('Офис', 'пр. Мира, 5', 6, 16, 340)),
  (Icons.apartment_rounded, Place('Квартира', 'ул. Аидгылара, 3', 3, 10, 250)),
  (Icons.favorite_rounded, Place('Мамин дом', 'Новый район', 8, 20, 420)),
];

const _defaultTo = LatLng(43.0145, 41.0440);

/// Фаза машины на карте у клиента.
enum _CarPhase { none, approaching, waiting, riding, arrived }

_CarPhase _phaseFor(OrderStage s) {
  switch (s) {
    case OrderStage.driverFound:
      return _CarPhase.approaching;
    case OrderStage.driverWaiting:
      return _CarPhase.waiting;
    case OrderStage.riding:
      return _CarPhase.riding;
    case OrderStage.rating:
      return _CarPhase.arrived;
    default:
      return _CarPhase.none;
  }
}

class _ClientHomeView extends StatefulWidget {
  const _ClientHomeView();

  @override
  State<_ClientHomeView> createState() => _ClientHomeViewState();
}

class _ClientHomeViewState extends State<_ClientHomeView> {
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();

  // Состояние экрана оценки поездки
  int _ratingStars = 5;
  final _commentCtrl = TextEditingController();

  OrderCubit get _cubit => context.read<OrderCubit>();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focus.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _openSearch() {
    _searchCtrl.clear();
    _cubit.openSearch();
    _focus.requestFocus();
  }

  void _addStop() {
    _searchCtrl.clear();
    _cubit.addStopSearch();
    _focus.requestFocus();
  }

  void _removeStop(int i) => _cubit.removeStop(i);

  void _enterMapPick() {
    _focus.unfocus();
    _cubit.enterMapPick();
  }

  void _pick(Place p) {
    _focus.unfocus();
    _cubit.pickPlace(p);
  }

  void _back() {
    _focus.unfocus();
    _searchCtrl.clear();
    _cubit.reset();
  }

  void _handleBack(OrderStage stage) {
    if (stage == OrderStage.mapPick) {
      _cubit.openSearch();
      _focus.requestFocus();
    } else {
      _back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderCubit, OrderState>(
      builder: (context, state) {
        final stage = state.stage;
        final isMapPick = stage == OrderStage.mapPick;
        final hasRoute = (stage == OrderStage.tariffs ||
                stage == OrderStage.driverFound ||
                stage == OrderStage.driverWaiting ||
                stage == OrderStage.riding ||
                stage == OrderStage.rating) &&
            state.hasStops;
        final LatLng? routeTo = isMapPick
            ? state.mapPoint
            : (hasRoute ? (state.mapPoint ?? _defaultTo) : null);
        final phase = _phaseFor(stage);
        final showBack = stage != OrderStage.idle &&
            stage != OrderStage.riding &&
            stage != OrderStage.rating;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Stack(
            children: [
              Positioned.fill(
                child: _MapView(
                  showRoute: hasRoute,
                  phase: phase,
                  routeTo: routeTo,
                  onTap: isMapPick ? (ll) => _cubit.setMapPoint(ll) : null,
                ),
              ),

              // Радар при поиске водителя
              if (stage == OrderStage.searching)
                const Align(
                  alignment: Alignment(0, -0.35),
                  child: _Radar(),
                ),

              // Режим выбора на карте: подсказка + подтверждение (без поисковика)
              if (isMapPick) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Center(child: const _MapHint()),
                    ),
                  ),
                ),
                if (state.mapPoint != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _Sheet(child: _pad(_mapConfirmPanel())),
                  ),
              ] else
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _Sheet(child: _panel(state)),
                ),

              // Кнопка «назад» (когда не на главной и не в платной поездке)
              if (showBack)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: _CircleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => _handleBack(stage),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _panel(OrderState state) {
    switch (state.stage) {
      case OrderStage.idle:
        return _pad(_idlePanel());
      case OrderStage.search:
        return _pad(_searchPanel(state));
      case OrderStage.tariffs:
        return _tariffsPanel(state); // паддинг задаётся внутри (лента full-bleed)
      case OrderStage.searching:
        return _pad(_searchingPanel(state));
      case OrderStage.driverFound:
        return _pad(_driverPanel(state));
      case OrderStage.driverWaiting:
        return _pad(_WaitingPanel(
          state: state,
          onTripStart: () => _cubit.startRiding(),
          onCancel: _back,
        ));
      case OrderStage.riding:
        return _pad(_ridingPanel(state));
      case OrderStage.rating:
        return _pad(_ratingPanel(state));
      case OrderStage.mapPick:
        return const SizedBox.shrink();
    }
  }

  Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);

  // ─────────── Подтверждение точки на карте ───────────
  Widget _mapConfirmPanel() {
    return Column(
      key: const ValueKey('mapConfirm'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.place_rounded, color: AppColors.error, size: 22),
            const SizedBox(width: 8),
            Text('Точка на карте',
                style: AppTextStyles.title),
          ],
        ),
        const SizedBox(height: 4),
        Text('Подтвердите точку назначения', style: AppTextStyles.bodySecondary),
        const SizedBox(height: 16),
        AppButton(
          label: 'Подтвердить точку',
          onPressed: () => _cubit.confirmMapPoint(),
        ),
      ],
    );
  }

  // ─────────── IDLE ───────────
  Widget _idlePanel() {
    return Column(
      key: const ValueKey('idle'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Куда едем?', style: AppTextStyles.h1),
        const SizedBox(height: 16),
        _FakeField(onTap: _openSearch),
        const SizedBox(height: 14),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _Chip(
              icon: _chips[i].$1,
              label: _chips[i].$2.title,
              onTap: () => _pick(_chips[i].$2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: AppColors.divider),
        _RecentRow(place: kPlaces[1], onTap: () => _pick(kPlaces[1])),
        _RecentRow(place: kPlaces[0], onTap: () => _pick(kPlaces[0])),
      ],
    );
  }

  // ─────────── SEARCH ───────────
  Widget _searchPanel(OrderState state) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = q.isEmpty
        ? kPlaces
        : kPlaces
            .where((p) =>
                p.title.toLowerCase().contains(q) ||
                p.subtitle.toLowerCase().contains(q))
            .toList();

    return Column(
      key: const ValueKey('search'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _AddressCard(
          controller: _searchCtrl,
          focusNode: _focus,
          onChanged: (v) => _cubit.setQuery(v),
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.map_rounded,
          label: 'Указать точку на карте',
          onTap: _enterMapPick,
        ),
        const Divider(height: 1, color: AppColors.divider),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.40),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 4),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.only(left: 52),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            itemBuilder: (_, i) => _SuggestionRow(
              place: list[i],
              onTap: () => _pick(list[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────── TARIFFS ───────────
  Widget _tariffsPanel(OrderState state) {
    final tariffs = tariffsFor(state.totalBase);
    final t = tariffs[state.selectedTariff];

    return Column(
      key: const ValueKey('tariffs'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Список точек: моё местоположение → остановки + «Добавить адрес»
        _pad(_RouteList(
          stops: state.stops,
          onAdd: _addStop,
          onRemove: _removeStop,
        )),
        const SizedBox(height: 8),
        _pad(Row(
          children: [
            const Icon(Icons.route_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('≈ ${state.totalKm} км · ${state.totalMin} мин',
                style: AppTextStyles.bodySecondary),
          ],
        )),
        const SizedBox(height: 14),
        // Лента тарифов уходит до правого края экрана.
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
            itemCount: tariffs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _TariffCard(
              data: tariffs[i],
              selected: i == state.selectedTariff,
              onTap: () => _cubit.selectTariff(i),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _pad(Row(
          children: [
            const Icon(Icons.payments_rounded,
                size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('Наличные', style: AppTextStyles.body),
            const Spacer(),
            Text('Изменить',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ],
        )),
        const SizedBox(height: 14),
        _pad(AppButton(
          label: 'Заказать ${t.name} · ${t.price} ₽',
          onPressed: () => _cubit.confirm(),
        )),
      ],
    );
  }

  // ─────────── SEARCHING ───────────
  Widget _searchingPanel(OrderState state) {
    final t = tariffsFor(state.totalBase)[state.selectedTariff];
    return Column(
      key: const ValueKey('searching'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Ищем ближайшего водителя…', style: AppTextStyles.h2),
        const SizedBox(height: 6),
        Text('${t.name} · ${t.price} ₽', style: AppTextStyles.bodySecondary),
        const SizedBox(height: 18),
        AppButton(label: 'Отменить', outlined: true, onPressed: _back),
      ],
    );
  }

  // ─────────── ВОДИТЕЛЬ В ПУТИ ───────────
  Widget _driverPanel(OrderState state) {
    final dest = state.lastStop!;
    final t = tariffsFor(state.totalBase)[state.selectedTariff];
    return Column(
      key: const ValueKey('found'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text('Водитель в пути · 3 мин',
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person_rounded,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_driverName(state), style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 15, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text('${_driverRating(state)} · ${_driverCar(state)}', style: AppTextStyles.bodySecondary),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(_driverPlate(state),
                  style: AppTextStyles.title.copyWith(fontSize: 16)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.call_rounded,
                label: 'Позвонить',
                onTap: () => openWhatsApp(_driverPhone),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.chat_bubble_rounded,
                label: 'Чат',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      name: _driverName(state),
                      phone: _driverPhone,
                      subtitle: '${_driverCar(state)} · ${_driverPlate(state)}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.place_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(dest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySecondary),
            ),
            Text('${t.price} ₽', style: AppTextStyles.title),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _back,
            child: Text('Отменить поездку',
                style: AppTextStyles.body.copyWith(color: AppColors.error)),
          ),
        ),
      ],
    );
  }

  // ─────────── ПОЕЗДКА ───────────
  Widget _ridingPanel(OrderState state) {
    final dest = state.lastStop!;
    final t = tariffsFor(state.totalBase)[state.selectedTariff];
    return Column(
      key: const ValueKey('riding'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.navigation_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('В пути · едем к месту',
                  style: AppTextStyles.body.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.place_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(dest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
            Text('${t.price} ₽', style: AppTextStyles.title),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.route_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('≈ ${state.totalKm} км · ${state.totalMin} мин',
                style: AppTextStyles.bodySecondary),
          ],
        ),
      ],
    );
  }

  // ─────────── ОЦЕНКА ПОЕЗДКИ ───────────
  Widget _ratingPanel(OrderState state) {
    final t = tariffsFor(state.totalBase)[state.selectedTariff];
    return Column(
      key: const ValueKey('rating'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Text('Вы приехали', style: AppTextStyles.h2)),
        const SizedBox(height: 4),
        Center(
          child: Text('Поездка завершена · ${t.price} ₽',
              style: AppTextStyles.bodySecondary),
        ),
        const SizedBox(height: 16),
        Center(child: Text('Оцените поездку', style: AppTextStyles.title)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _ratingStars;
            return GestureDetector(
              onTap: () => setState(() => _ratingStars = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 40,
                  color: filled ? AppColors.warning : AppColors.border,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        // Быстрые теги-комментарии
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in const [
              'Чисто',
              'Вежливый водитель',
              'Быстро доехали',
              'Аккуратная езда',
            ])
              _CommentTag(
                label: tag,
                onTap: () {
                  final cur = _commentCtrl.text.trim();
                  setState(() {
                    _commentCtrl.text =
                        cur.isEmpty ? tag : '$cur, $tag';
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Комментарий (необязательно)',
          ),
        ),
        const SizedBox(height: 16),
        AppButton(label: 'Готово', onPressed: _submitRating),
      ],
    );
  }

  void _submitRating() {
    _cubit.submitRating();
    setState(() {
      _ratingStars = 5;
      _commentCtrl.clear();
    });
  }
}

/// Тег-подсказка для комментария к поездке.
class _CommentTag extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CommentTag({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: AppTextStyles.bodySecondary),
      ),
    );
  }
}

// ─────────────────────── Ожидание водителя ───────────────────────

/// Водитель приехал и ждёт: сначала бесплатно (4 мин), затем платное
/// ожидание, после чего автоматически начинается поездка.
/// Длительности здесь демо-сжатые (реально бесплатно 4 минуты).
class _WaitingPanel extends StatefulWidget {
  final OrderState state;
  final VoidCallback onTripStart;
  final VoidCallback onCancel;
  const _WaitingPanel({
    required this.state,
    required this.onTripStart,
    required this.onCancel,
  });

  @override
  State<_WaitingPanel> createState() => _WaitingPanelState();
}

class _WaitingPanelState extends State<_WaitingPanel> {
  Timer? _timer;
  int _elapsed = 0;

  static const _freeSecs = 12; // бесплатное ожидание (демо; реально 240 = 4 мин)
  static const _tripSecs = 22; // когда стартует поездка (демо)

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _elapsed++);
      if (_elapsed >= _tripSecs) {
        t.cancel();
        widget.onTripStart();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _mmss(int s) {
    final m = s ~/ 60;
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final paid = _elapsed >= _freeSecs;
    final freeLeft = (_freeSecs - _elapsed).clamp(0, _freeSecs);
    final paidCost = ((_elapsed - _freeSecs).clamp(0, 9999)) * 3; // демо ₽

    return Column(
      key: const ValueKey('waiting'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Статус ожидания: бесплатно → платно
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: paid
                ? AppColors.error.withValues(alpha: 0.10)
                : AppColors.accentLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(paid ? Icons.timer_rounded : Icons.check_circle_rounded,
                  size: 18,
                  color: paid ? AppColors.error : AppColors.primaryDark),
              const SizedBox(width: 8),
              Text(
                paid
                    ? 'Платное ожидание · +$paidCost ₽'
                    : 'Водитель ждёт вас · бесплатно ${_mmss(freeLeft)}',
                style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: paid ? AppColors.error : AppColors.primaryDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Водитель
        Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person_rounded,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_driverName(widget.state), style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 15, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text('${_driverRating(widget.state)} · ${_driverCar(widget.state)}', style: AppTextStyles.bodySecondary),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(_driverPlate(widget.state),
                  style: AppTextStyles.title.copyWith(fontSize: 16)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.call_rounded,
                label: 'Позвонить',
                onTap: () => openWhatsApp(_driverPhone),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.chat_bubble_rounded,
                label: 'Чат',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      name: _driverName(widget.state),
                      phone: _driverPhone,
                      subtitle: '${_driverCar(widget.state)} · ${_driverPlate(widget.state)}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: widget.onCancel,
            child: Text('Отменить поездку',
                style: AppTextStyles.body.copyWith(color: AppColors.error)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── Карта с анимацией машины ───────────────────────

class _MapView extends StatefulWidget {
  final bool showRoute;
  final _CarPhase phase;
  final LatLng? routeTo;
  final ValueChanged<LatLng>? onTap;

  const _MapView({
    required this.showRoute,
    required this.phase,
    required this.routeTo,
    required this.onTap,
  });

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _car;

  static const _pickup = LatLng(43.0015, 41.0234);
  // Путь подъезда машины к клиенту.
  static const _approachRoute = [
    LatLng(43.0058, 41.0312),
    LatLng(43.0040, 41.0268),
    _pickup,
  ];

  bool get _moving =>
      widget.phase == _CarPhase.approaching || widget.phase == _CarPhase.riding;

  @override
  void initState() {
    super.initState();
    _car = AnimationController(
        vsync: this, duration: const Duration(seconds: 5));
    if (_moving) _car.repeat();
  }

  @override
  void didUpdateWidget(covariant _MapView old) {
    super.didUpdateWidget(old);
    if (_moving && !_car.isAnimating) {
      _car.repeat();
    } else if (!_moving && _car.isAnimating) {
      _car.stop();
      _car.value = 0;
    }
  }

  @override
  void dispose() {
    _car.dispose();
    super.dispose();
  }

  gmaps.LatLng _g(LatLng p) => gmaps.LatLng(p.latitude, p.longitude);

  LatLng _along(List<LatLng> pts, double t) {
    if (t <= 0) return pts.first;
    if (t >= 1) return pts.last;
    final n = pts.length - 1;
    final scaled = t * n;
    final i = scaled.floor();
    final f = scaled - i;
    final a = pts[i];
    final b = pts[i + 1];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * f,
      a.longitude + (b.longitude - a.longitude) * f,
    );
  }

  // Где сейчас машина в зависимости от фазы.
  LatLng? _carPos() {
    switch (widget.phase) {
      case _CarPhase.none:
        return null;
      case _CarPhase.approaching:
        return _along(_approachRoute, _car.value);
      case _CarPhase.waiting:
        return _pickup;
      case _CarPhase.riding:
        return _along([_pickup, widget.routeTo ?? _pickup], _car.value);
      case _CarPhase.arrived:
        return widget.routeTo;
    }
  }

  Set<gmaps.Marker> _markers(LatLng? carPos) {
    final markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('pickup'),
        position: _g(_pickup),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueGreen),
      ),
    };
    if (widget.routeTo != null) {
      markers.add(gmaps.Marker(
        markerId: const gmaps.MarkerId('destination'),
        position: _g(widget.routeTo!),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueRed),
      ));
    }
    if (carPos != null) {
      markers.add(gmaps.Marker(
        markerId: const gmaps.MarkerId('car'),
        position: _g(carPos),
        flat: true,
        anchor: const Offset(0.5, 0.5),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueOrange),
      ));
    }
    return markers;
  }

  Set<gmaps.Polyline> _polylines() {
    if (widget.showRoute && widget.routeTo != null) {
      return {
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route'),
          points: [_g(_pickup), _g(widget.routeTo!)],
          color: AppColors.primary,
          width: 5,
        ),
      };
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _car,
      builder: (context, _) {
        final carPos = _carPos();
        return gmaps.GoogleMap(
          initialCameraPosition: gmaps.CameraPosition(
            target: _g(const LatLng(43.006, 41.030)),
            zoom: 13.5,
          ),
          markers: _markers(carPos),
          polylines: _polylines(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onTap: widget.onTap == null
              ? null
              : (pos) => widget.onTap!(LatLng(pos.latitude, pos.longitude)),
        );
      },
    );
  }
}

// ─────────────────────── Шторка ───────────────────────

class _Sheet extends StatelessWidget {
  final Widget child;
  const _Sheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 28)],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // Без горизонтального паддинга — отступы задаёт каждый блок сам,
          // чтобы лента тарифов могла уходить до правого края экрана.
          padding: const EdgeInsets.only(top: 12, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Подсказка выбора на карте ───────────────────────

class _MapHint extends StatelessWidget {
  const _MapHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Нажмите на карту, чтобы выбрать точку',
              style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}

// ─────────────────────── Мелкие виджеты ───────────────────────

class _FakeField extends StatelessWidget {
  final VoidCallback onTap;
  const _FakeField({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.textHint),
            const SizedBox(width: 12),
            Text('Введите адрес',
                style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _AddressCard({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        height: 100,
        child: Row(
          children: [
            Column(
              children: [
                const SizedBox(height: 22),
                const _Dot(),
                Expanded(child: Container(width: 2, color: AppColors.border)),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(height: 22),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Моё местоположение',
                          style: AppTextStyles.body),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'Куда едем?',
                        filled: false,
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Список точек маршрута: «Моё местоположение» → остановки + «Добавить адрес».
class _RouteList extends StatelessWidget {
  final List<Place> stops;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  const _RouteList(
      {required this.stops, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _RoutePointRow(
            marker: const _Dot(),
            title: 'Моё местоположение',
            subtitle: null,
          ),
          for (var i = 0; i < stops.length; i++) ...[
            const Divider(height: 1, color: AppColors.divider),
            _RoutePointRow(
              marker: const _Square(),
              title: stops[i].title,
              subtitle: stops[i].subtitle,
              onRemove: () => onRemove(i),
            ),
          ],
          const Divider(height: 1, color: AppColors.divider),
          InkWell(
            onTap: onAdd,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 16, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 14),
                  Text('Добавить адрес',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePointRow extends StatelessWidget {
  final Widget marker;
  final String title;
  final String? subtitle;
  final VoidCallback? onRemove;
  const _RoutePointRow({
    required this.marker,
    required this.title,
    required this.subtitle,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 22, child: Center(child: marker)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textHint),
              ),
            ),
        ],
      ),
    );
  }
}

class _Square extends StatelessWidget {
  const _Square();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;
  const _SuggestionRow({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.title,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(place.subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Text('${place.km} км',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 22),
            ),
            const SizedBox(width: 12),
            Text(label,
                style:
                    AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TariffCard extends StatelessWidget {
  final Tariff data;
  final bool selected;
  final VoidCallback onTap;
  const _TariffCard(
      {required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 110,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [BoxShadow(color: AppColors.shadow, blurRadius: 8)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : AppColors.inputFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon,
                    size: 28, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 10),
              Text(data.name,
                  style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: 2),
              Text('${data.price} ₽',
                  style: AppTextStyles.title.copyWith(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Center(child: Text(label, style: AppTextStyles.body)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;
  const _RecentRow({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: AppColors.textHint),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.title,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(place.subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.north_west_rounded,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          width: 48,
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────── Радар поиска ───────────────────────

class _Radar extends StatefulWidget {
  const _Radar();

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ring(0.0),
              _ring(0.5),
              Container(
                height: 60,
                width: 60,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_taxi_rounded,
                    color: AppColors.primaryDark, size: 30),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring(double offset) {
    final t = (_c.value + offset) % 1.0;
    return Opacity(
      opacity: (1 - t).clamp(0.0, 1.0) * 0.35,
      child: Container(
        width: 70 + t * 130,
        height: 70 + t * 130,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
