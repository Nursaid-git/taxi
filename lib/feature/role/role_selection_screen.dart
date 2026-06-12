import 'package:flutter/material.dart';
import 'package:taxi/core/enums/user_role.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/feature/auth/screen/login_screen.dart';

/// Первый интерактивный экран: выбор роли.
/// Пользователь выбирает, как он входит — как клиент или как водитель.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _select(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text('Кто вы?', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Выберите, как хотите пользоваться приложением. '
                'Роль можно сменить позже.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'Я клиент',
                subtitle: 'Заказывать поездки',
                onTap: () => _select(context, UserRole.client),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.local_taxi_rounded,
                title: 'Я водитель',
                subtitle: 'Принимать заказы и зарабатывать',
                onTap: () => _select(context, UserRole.driver),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.bodySecondary),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
