import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';

enum _TripStatus { done, cancelled }

class _Trip {
  final String group; // Сегодня / Вчера / Ранее
  final String to;
  final String from;
  final String when;
  final String tariff;
  final int price;
  final _TripStatus status;
  final int rating; // 0 = без оценки
  const _Trip(this.group, this.to, this.from, this.when, this.tariff,
      this.price, this.status, this.rating);
}

const _trips = <_Trip>[
  _Trip('Сегодня', 'Аэропорт Сухум', 'Моё местоположение', 'Сегодня, 14:30',
      'Комфорт', 550, _TripStatus.done, 5),
  _Trip('Сегодня', 'Набережная Махаджиров', 'ул. Лакоба, 12', 'Сегодня, 09:15',
      'Эконом', 250, _TripStatus.done, 4),
  _Trip('Вчера', 'Гагра, центр', 'Сухум, центр', 'Вчера, 18:40', 'Бизнес',
      1900, _TripStatus.done, 5),
  _Trip('Ранее', 'Рынок', 'Дом', '8 июня, 11:00', 'Эконом', 280,
      _TripStatus.cancelled, 0),
  _Trip('Ранее', 'Новый Афон', 'Аэропорт Сухум', '5 июня, 16:20', 'Комфорт',
      850, _TripStatus.done, 5),
];

/// Вкладка «Поездки» — белый экран с историей поездок и фильтром.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  // 0 — все, 1 — завершённые, 2 — отменённые
  int _filter = 0;

  List<_Trip> get _list {
    switch (_filter) {
      case 1:
        return _trips.where((t) => t.status == _TripStatus.done).toList();
      case 2:
        return _trips.where((t) => t.status == _TripStatus.cancelled).toList();
      default:
        return _trips;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Поездки'),
      ),
      body: Column(
        children: [
          // Фильтр
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                _FilterChip(
                    label: 'Все',
                    selected: _filter == 0,
                    onTap: () => setState(() => _filter = 0)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Завершённые',
                    selected: _filter == 1,
                    onTap: () => setState(() => _filter = 1)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Отменённые',
                    selected: _filter == 2,
                    onTap: () => setState(() => _filter = 2)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty ? const _Empty() : _TripList(trips: list),
          ),
        ],
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  final List<_Trip> trips;
  const _TripList({required this.trips});

  @override
  Widget build(BuildContext context) {
    // Группировка по разделам (Сегодня / Вчера / Ранее) с сохранением порядка.
    final items = <Widget>[];
    String? lastGroup;
    for (final t in trips) {
      if (t.group != lastGroup) {
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(20, items.isEmpty ? 4 : 18, 20, 8),
          child: Text(t.group, style: AppTextStyles.caption),
        ));
        lastGroup = t.group;
      }
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: _TripCard(trip: t),
      ));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: items);
  }
}

class _TripCard extends StatelessWidget {
  final _Trip trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final cancelled = trip.status == _TripStatus.cancelled;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Иконка статуса
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: cancelled
                  ? AppColors.error.withValues(alpha: 0.10)
                  : AppColors.accentLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              cancelled ? Icons.close_rounded : Icons.local_taxi_rounded,
              color: cancelled ? AppColors.error : AppColors.primaryDark,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Маршрут + дата
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.to,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('от ${trip.from}',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${trip.when} · ${trip.tariff}',
                        style: AppTextStyles.caption),
                    if (!cancelled && trip.rating > 0) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star_rounded,
                          size: 13, color: AppColors.warning),
                      Text('${trip.rating}',
                          style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Цена + статус
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${trip.price} ₽',
                style: AppTextStyles.title.copyWith(
                  fontSize: 16,
                  color: cancelled ? AppColors.textHint : AppColors.textPrimary,
                  decoration:
                      cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cancelled ? 'Отменена' : 'Завершена',
                style: AppTextStyles.caption.copyWith(
                  color: cancelled ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySecondary.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 110,
              width: 110,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('Поездок нет', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Здесь будет история ваших поездок.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}
