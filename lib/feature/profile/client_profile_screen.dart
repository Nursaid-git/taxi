import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/menu_tile_widget.dart';
import 'package:taxi/feature/role/role_selection_screen.dart';

/// Профиль КЛИЕНТА. Базовые данные + меню (оплата, адреса, история).
class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key});

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
          Row(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.person_rounded,
                    size: 36, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Гость', style: AppTextStyles.h2),
                    const SizedBox(height: 2),
                    Text('+7 940 12 34 567',
                        style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text('5.0', style: AppTextStyles.bodySecondary),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _section('Аккаунт'),
          MenuTile(
            icon: Icons.credit_card_rounded,
            title: 'Способы оплаты',
            subtitle: 'Наличные',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          MenuTile(
            icon: Icons.bookmark_rounded,
            title: 'Избранные адреса',
            subtitle: 'Дом, Работа',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          MenuTile(
            icon: Icons.local_offer_rounded,
            title: 'Промокоды',
            onTap: () {},
          ),
          const SizedBox(height: 20),
          _section('Прочее'),
          MenuTile(
            icon: Icons.support_agent_rounded,
            title: 'Поддержка',
            onTap: () {},
          ),
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

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(title, style: AppTextStyles.caption),
      );
}
