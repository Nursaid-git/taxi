import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/feature/home/client_home_screen.dart';
import 'package:taxi/feature/loyalty/loyalty_screen.dart';
import 'package:taxi/feature/profile/client_profile_screen.dart';
import 'package:taxi/feature/trips/trips_screen.dart';

/// Оболочка КЛИЕНТА. Изогнутый bottom nav с плавающим жёлтым кружком,
/// который перепрыгивает на выбранную вкладку. «Поездки» — по центру.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;

  static const _tabs = [
    ClientHomeScreen(),
    TripsScreen(),
    LoyaltyScreen(),
    ClientProfileScreen(),
  ];

  static const _icons = [
    Icons.home_rounded,
    Icons.receipt_long_rounded,
    Icons.workspace_premium_rounded,
    Icons.person_rounded,
  ];

  static const _labels = ['Главная', 'Поездки', 'Мили', 'Профиль'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Фон = цвет шторки, чтобы в выемке бара не просвечивал шов.
      backgroundColor: AppColors.surface,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: CurvedNavigationBar(
        index: _index,
        height: 64,
        // Цвет за выемкой = цвет шторки (без шва). color = цвет панели.
        backgroundColor: AppColors.surface,
        color: AppColors.primary,
        buttonBackgroundColor: AppColors.accent,
        animationCurve: Curves.easeOutCubic,
        animationDuration: const Duration(milliseconds: 350),
        items: [
          for (var i = 0; i < _icons.length; i++)
            navItem(_icons[i], _labels[i], i == _index),
        ],
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Элемент изогнутого nav: выбранный — только иконка (в кружке),
/// остальные — иконка + название на панели.
Widget navItem(IconData icon, String label, bool selected) {
  if (selected) {
    return Icon(icon, size: 26, color: AppColors.primaryDark);
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 22, color: Colors.white),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    ],
  );
}
