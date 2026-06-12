import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/menu_tile_widget.dart';
import 'package:taxi/feature/role/role_selection_screen.dart';

/// Профиль ВОДИТЕЛЯ: рейтинг, бейдж «Проверен», авто, документы, статистика.
class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Шапка
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.person_rounded,
                      size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Иван Водитель', style: AppTextStyles.h2),
                    const SizedBox(width: 8),
                    const _VerifiedBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Text('+7 940 12 34 567', style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Статистика
          Row(
            children: [
              _stat('Рейтинг', '5.0 ★'),
              _statDivider(),
              _stat('Поездок', '0'),
              _statDivider(),
              _stat('Стаж', '0 дн.'),
            ],
          ),
          const SizedBox(height: 20),
          // Карточка авто
          _CarCard(),
          const SizedBox(height: 20),
          _section('Документы и авто'),
          MenuTile(
            icon: Icons.description_rounded,
            title: 'Документы',
            subtitle: 'Все проверены',
            trailing: const Icon(Icons.check_circle_rounded,
                color: AppColors.success),
            onTap: () {},
          ),
          const SizedBox(height: 8),
          MenuTile(
            icon: Icons.directions_car_rounded,
            title: 'Мой автомобиль',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          MenuTile(
            icon: Icons.bar_chart_rounded,
            title: 'Статистика',
            onTap: () {},
          ),
          const SizedBox(height: 20),
          _section('Прочее'),
          MenuTile(
              icon: Icons.support_agent_rounded,
              title: 'Поддержка',
              onTap: () {}),
          const SizedBox(height: 8),
          MenuTile(icon: Icons.settings_rounded, title: 'Настройки', onTap: () {}),
          const SizedBox(height: 8),
          MenuTile(
            icon: Icons.logout_rounded,
            title: 'Выйти',
            iconColor: AppColors.error,
            trailing: const SizedBox.shrink(),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.title.copyWith(color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      );

  Widget _statDivider() =>
      Container(width: 1, height: 32, color: AppColors.divider);

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(title, style: AppTextStyles.caption),
      );
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded,
              size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text('Проверен',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_car_rounded,
                color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Toyota Camry · Белый', style: AppTextStyles.body),
                const SizedBox(height: 2),
                Text('A 123 AB · 2021', style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
