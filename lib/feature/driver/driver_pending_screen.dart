import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/app_button_widget.dart';
import 'package:taxi/feature/home/driver_shell.dart';

/// Экран после отправки анкеты: заявка на модерации.
/// Показывает статусы; кнопка «На главный» — для демо (как будто одобрено).
class DriverPendingScreen extends StatelessWidget {
  const DriverPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                height: 120,
                width: 120,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 28),
              Text('Заявка на проверке',
                  textAlign: TextAlign.center, style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Мы проверяем ваши документы и автомобиль. '
                'Обычно это занимает до 24 часов — пришлём уведомление.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 32),
              const _Step(title: 'Анкета отправлена', done: true),
              const _Step(title: 'Проверка модератором', active: true),
              const _Step(title: 'Допуск на линию', done: false),
              const Spacer(),
              // Демо-переход (как будто заявку одобрили)
              AppButton(
                label: 'На главный экран (демо)',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const DriverShell()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Изменить анкету',
                outlined: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String title;
  final bool done;
  final bool active;
  const _Step({required this.title, this.done = false, this.active = false});

  @override
  Widget build(BuildContext context) {
    final Color color = done
        ? AppColors.success
        : active
            ? AppColors.primary
            : AppColors.border;
    final IconData icon = done
        ? Icons.check_circle_rounded
        : active
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              color: done || active
                  ? AppColors.textPrimary
                  : AppColors.textHint,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
