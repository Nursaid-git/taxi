import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/app_button_widget.dart';
import 'package:taxi/feature/driver/bloc/driver_cubit.dart';

/// Главный экран ВОДИТЕЛЯ: карта, сводка заработка и панель статуса
/// (офлайн → на линии → входящий заказ → за клиентом → поездка).
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DriverCubit(),
      child: const _DriverHomeView(),
    );
  }
}

class _DriverHomeView extends StatelessWidget {
  const _DriverHomeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DriverCubit, DriverState>(
      builder: (context, state) {
        // Заказ виден на карте уже при входящем — оценить маршрут до принятия.
        final hasOrder = state.stage == DriverStage.incoming ||
            state.stage == DriverStage.toPickup ||
            state.stage == DriverStage.waiting ||
            state.stage == DriverStage.inProgress;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Stack(
            children: [
              Positioned.fill(
                child: _DriverMap(order: hasOrder ? state.order : null),
              ),

              // Компактная сводка сверху — и только когда нет заказа на карте.
              if (!hasOrder)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _EarningsBar(
                        earnings: state.todayEarnings,
                        rides: state.todayRides,
                      ),
                    ),
                  ),
                ),

              // Панель статуса снизу
              Align(
                alignment: Alignment.bottomCenter,
                child: _Sheet(child: _panel(context, state)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _panel(BuildContext context, DriverState state) {
    final cubit = context.read<DriverCubit>();
    switch (state.stage) {
      case DriverStage.offline:
        return _OfflinePanel(onGoOnline: cubit.goOnline);
      case DriverStage.online:
        return _OnlinePanel(onGoOffline: cubit.goOffline);
      case DriverStage.incoming:
        return _IncomingCard(
          key: ValueKey(state.order),
          order: state.order!,
          onAccept: cubit.accept,
          onDecline: cubit.decline,
        );
      case DriverStage.toPickup:
        return _ToPickupPanel(
          order: state.order!,
          onArrived: cubit.arrived,
          onCancel: cubit.decline,
        );
      case DriverStage.waiting:
        return _WaitingPanel(
          order: state.order!,
          onStart: cubit.startTrip,
          onCancel: cubit.decline,
        );
      case DriverStage.inProgress:
        return _InProgressPanel(
          order: state.order!,
          onComplete: cubit.complete,
        );
    }
  }
}

// ─────────────────────── Карта ───────────────────────

class _DriverMap extends StatefulWidget {
  final DriverOrder? order;
  const _DriverMap({required this.order});

  @override
  State<_DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<_DriverMap> {
  gmaps.GoogleMapController? _ctrl;
  static const _driver = LatLng(43.0030, 41.0270);

  gmaps.LatLng _g(LatLng p) => gmaps.LatLng(p.latitude, p.longitude);

  @override
  void didUpdateWidget(covariant _DriverMap old) {
    super.didUpdateWidget(old);
    if (widget.order != old.order) _fit();
  }

  // Подогнать камеру: показать весь маршрут или вернуться к водителю.
  void _fit() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final o = widget.order;
    if (o == null) {
      ctrl.animateCamera(gmaps.CameraUpdate.newLatLngZoom(_g(_driver), 15));
      return;
    }
    final bounds = _boundsOf([_g(_driver), _g(o.pickupPoint), _g(o.destPoint)]);
    ctrl.animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 60));
  }

  gmaps.LatLngBounds _boundsOf(List<gmaps.LatLng> pts) {
    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    return gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;

    final markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('driver'),
        position: _g(_driver),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueYellow),
      ),
    };
    final polylines = <gmaps.Polyline>{};

    if (o != null) {
      markers.add(gmaps.Marker(
        markerId: const gmaps.MarkerId('client'),
        position: _g(o.pickupPoint),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueGreen),
      ));
      markers.add(gmaps.Marker(
        markerId: const gmaps.MarkerId('destination'),
        position: _g(o.destPoint),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueRed),
      ));
      polylines.add(gmaps.Polyline(
        polylineId: const gmaps.PolylineId('pickup'),
        points: [_g(_driver), _g(o.pickupPoint)],
        color: AppColors.textSecondary,
        width: 4,
      ));
      polylines.add(gmaps.Polyline(
        polylineId: const gmaps.PolylineId('trip'),
        points: [_g(o.pickupPoint), _g(o.destPoint)],
        color: AppColors.primary,
        width: 5,
      ));
    }

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _g(const LatLng(43.0023, 41.0252)),
        zoom: 14.5,
      ),
      markers: markers,
      polylines: polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (c) {
        _ctrl = c;
        if (widget.order != null) _fit();
      },
    );
  }
}

// ─────────────────────── Сводка ───────────────────────

class _EarningsBar extends StatelessWidget {
  final int earnings;
  final int rides;
  const _EarningsBar({required this.earnings, required this.rides});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 14)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _item(Icons.account_balance_wallet_rounded, '$earnings ₽',
              AppColors.primary),
          _dot(),
          _item(Icons.local_taxi_rounded, '$rides', AppColors.textSecondary),
          _dot(),
          _item(Icons.star_rounded, '5.0', AppColors.warning),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _dot() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
            color: AppColors.textHint, shape: BoxShape.circle),
      );
}

// ─────────────────────── Панели статуса ───────────────────────

class _OfflinePanel extends StatelessWidget {
  final VoidCallback onGoOnline;
  const _OfflinePanel({required this.onGoOnline});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Вы офлайн', style: AppTextStyles.h2),
        const SizedBox(height: 6),
        Text('Выйдите на линию, чтобы получать заказы',
            style: AppTextStyles.bodySecondary),
        const SizedBox(height: 16),
        AppButton(
          label: 'Выйти на линию',
          icon: Icons.power_settings_new_rounded,
          onPressed: onGoOnline,
        ),
      ],
    );
  }
}

class _OnlinePanel extends StatelessWidget {
  final VoidCallback onGoOffline;
  const _OnlinePanel({required this.onGoOffline});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PulseDot(),
            const SizedBox(width: 10),
            Text('Вы на линии · ищем заказы…', style: AppTextStyles.title),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(
            label: 'Завершить смену',
            outlined: true,
            onPressed: onGoOffline),
      ],
    );
  }
}

class _ToPickupPanel extends StatelessWidget {
  final DriverOrder order;
  final VoidCallback onArrived;
  final VoidCallback onCancel;
  const _ToPickupPanel(
      {required this.order, required this.onArrived, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(text: 'Забрать клиента', color: AppColors.accentLight),
        const SizedBox(height: 14),
        _ClientRow(order: order),
        const SizedBox(height: 12),
        _AddrRow(
            icon: Icons.my_location_rounded,
            color: AppColors.primary,
            text: order.pickup),
        const SizedBox(height: 16),
        AppButton(label: 'Я на месте', onPressed: onArrived),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: onCancel,
            child: Text('Отменить',
                style: AppTextStyles.body.copyWith(color: AppColors.error)),
          ),
        ),
      ],
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  final DriverOrder order;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  const _WaitingPanel(
      {required this.order, required this.onStart, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(text: 'Ожидание клиента', color: AppColors.accentLight),
        const SizedBox(height: 14),
        _ClientRow(order: order),
        const SizedBox(height: 12),
        _AddrRow(
            icon: Icons.my_location_rounded,
            color: AppColors.primary,
            text: order.pickup),
        const SizedBox(height: 16),
        AppButton(
            label: 'Начать поездку',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: onCancel,
            child: Text('Отменить',
                style: AppTextStyles.body.copyWith(color: AppColors.error)),
          ),
        ),
      ],
    );
  }
}

class _InProgressPanel extends StatelessWidget {
  final DriverOrder order;
  final VoidCallback onComplete;
  const _InProgressPanel({required this.order, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(text: 'Поездка', color: AppColors.primaryLight),
        const SizedBox(height: 14),
        _AddrRow(
            icon: Icons.place_rounded,
            color: AppColors.error,
            text: order.destination),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.route_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('≈ ${order.km} км · ${order.min} мин · ${order.price} ₽',
                style: AppTextStyles.bodySecondary),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(label: 'Завершить поездку', onPressed: onComplete),
      ],
    );
  }
}

// ─────────────────────── Входящий заказ ───────────────────────

class _IncomingCard extends StatefulWidget {
  final DriverOrder order;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _IncomingCard(
      {super.key,
      required this.order,
      required this.onAccept,
      required this.onDecline});

  @override
  State<_IncomingCard> createState() => _IncomingCardState();
}

class _IncomingCardState extends State<_IncomingCard>
    with SingleTickerProviderStateMixin {
  static const _seconds = 15;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _seconds),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDecline();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${o.price} ₽', style: AppTextStyles.h1),
            const SizedBox(width: 10),
            Expanded(
              child: Text('≈ ${o.km} км · ${o.min} мин',
                  style: AppTextStyles.bodySecondary),
            ),
            // Таймер
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final left = (_seconds * (1 - _c.value)).ceil();
                return SizedBox(
                  height: 40,
                  width: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 1 - _c.value,
                        strokeWidth: 3,
                        backgroundColor: AppColors.border,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.accentDark),
                      ),
                      Text('$left',
                          style: AppTextStyles.bodySecondary
                              .copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Маршрут одной строкой (детали — на карте)
        Row(
          children: [
            const Icon(Icons.alt_route_rounded,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${o.pickup} → ${o.destination}',
                  style: AppTextStyles.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: widget.onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Отклонить'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppButton(label: 'Принять', onPressed: widget.onAccept),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────── Мелкие виджеты ───────────────────────

class _ClientRow extends StatelessWidget {
  final DriverOrder order;
  const _ClientRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.person_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.clientName, style: AppTextStyles.title),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 15, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text('${order.clientRating}',
                      style: AppTextStyles.bodySecondary),
                ],
              ),
            ],
          ),
        ),
        Text('${order.price} ₽', style: AppTextStyles.title),
      ],
    );
  }
}

class _AddrRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AddrRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
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
