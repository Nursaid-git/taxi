import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';

/// Вкладка «Заработок» водителя — баланс, вывод, период, выплаты.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Заработок')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Баланс
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Баланс к выводу',
                    style: AppTextStyles.bodySecondary
                        .copyWith(color: Colors.white70)),
                const SizedBox(height: 6),
                const Text('0 ₽',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Вывести средства'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Период
          _PeriodStats(),
          const SizedBox(height: 24),
          Text('Последние выплаты', style: AppTextStyles.title),
          const SizedBox(height: 12),
          _EmptyPayouts(),
        ],
      ),
    );
  }
}

class _PeriodStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget card(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(label, style: AppTextStyles.caption),
              ],
            ),
          ),
        );
    return Row(
      children: [
        card('Сегодня', '0 ₽'),
        const SizedBox(width: 12),
        card('Неделя', '0 ₽'),
        const SizedBox(width: 12),
        card('Всего', '0 ₽'),
      ],
    );
  }
}

class _EmptyPayouts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('Выплат пока нет', style: AppTextStyles.bodySecondary),
    );
  }
}
