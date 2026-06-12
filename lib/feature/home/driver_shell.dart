import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/feature/home/client_shell.dart' show navItem;
import 'package:taxi/feature/earnings/earnings_screen.dart';
import 'package:taxi/feature/home/driver_home_screen.dart';
import 'package:taxi/feature/profile/driver_profile_screen.dart';
import 'package:taxi/feature/trips/trips_screen.dart';

/// Оболочка ВОДИТЕЛЯ. Изогнутый bottom nav: 4 вкладки, жёлтый кружок
/// перепрыгивает на выбранную.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  static const _tabs = [
    DriverHomeScreen(),
    TripsScreen(),
    EarningsScreen(),
    DriverProfileScreen(),
  ];

  static const _icons = [
    Icons.home_rounded,
    Icons.receipt_long_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.person_rounded,
  ];

  static const _labels = ['Главная', 'Поездки', 'Заработок', 'Профиль'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: CurvedNavigationBar(
        index: _index,
        height: 64,
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
