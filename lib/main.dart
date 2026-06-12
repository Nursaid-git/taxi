import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taxi/core/theme/app_theme.dart';
import 'package:taxi/feature/auth/bloc/auth_cubit.dart';
import 'package:taxi/feature/auth/repository/auth_repository.dart';
import 'package:taxi/feature/auth/repository/auth_repository_impl.dart';
import 'package:taxi/feature/splash/splash_screen.dart';

void main() {
  runApp(
    DevicePreview(
      // Включаем превью только в debug — в релизе обычное приложение.
      enabled: !kReleaseMode,
      builder: (_) => const TaxiApp(),
    ),
  );
}

class TaxiApp extends StatelessWidget {
  const TaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AuthRepository>(
      create: (_) => AuthRepositoryImpl(firebase: ''),
      child: BlocProvider(
        create: (context) =>
            AuthCubit(authRepository: context.read<AuthRepository>()),
        child: MaterialApp(
          title: 'Taxi Абхазия',
          debugShowCheckedModeBanner: false,
          // Подключаем DevicePreview к MaterialApp.
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          theme: AppTheme.light,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
