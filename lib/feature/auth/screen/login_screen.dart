import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taxi/core/enums/user_role.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/app_button_widget.dart';
import 'package:taxi/feature/auth/bloc/auth_cubit.dart';
import 'package:taxi/feature/auth/screen/otp_screen.dart';
import 'package:taxi/feature/auth/screen/register_screen.dart';
import 'package:taxi/feature/auth/widget/phone_field_widget.dart';
import 'package:taxi/feature/auth/widget/social_button_widget.dart';
import 'package:taxi/feature/home/client_shell.dart';
import 'package:taxi/feature/home/driver_shell.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _continue() {
    if (_phone.text.trim().isEmpty) return;
    context.read<AuthCubit>().sendOtp(phone: '+7 940 ${_phone.text.trim()}');
  }

  void _toRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RegisterScreen(role: widget.role)),
    );
  }

  // Только для отладки: пропустить вход и сразу попасть на экран с картой.
  void _devSkip() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            widget.role.isDriver ? const DriverShell() : const ClientShell(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (_, s) => s is AuthCodeSent || s is AuthFailure,
      listener: (context, state) {
        if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        } else if (state is AuthCodeSent) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                role: widget.role,
                phone: state.phone,
                isRegister: false,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final loading = state is AuthLoading;
        return Scaffold(
          appBar: AppBar(title: Text('Вход · ${widget.role.titleRu}')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text('С возвращением 👋', style: AppTextStyles.h1),
                  const SizedBox(height: 8),
                  Text(
                    'Введите номер телефона — пришлём код подтверждения в WhatsApp.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 28),
                  Text('Номер телефона', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 8),
                  PhoneField(controller: _phone),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Получить код',
                    icon: Icons.chat_rounded,
                    loading: loading,
                    onPressed: loading ? null : _continue,
                  ),
                  const SizedBox(height: 24),
                  const _OrDivider(),
                  const SizedBox(height: 24),
                  SocialButton(
                    label: 'Продолжить с Google',
                    icon: const Text('G',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    onPressed: () {},
                  ),
                  const SizedBox(height: 12),
                  SocialButton(
                    label: 'Продолжить с Apple',
                    icon: const Icon(Icons.apple, size: 24),
                    onPressed: () {},
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Нет аккаунта?', style: AppTextStyles.bodySecondary),
                        TextButton(onPressed: _toRegister, child: const Text('Регистрация')),
                      ],
                    ),
                  ),
                  // DEBUG: пропустить вход, чтобы протестировать карту/экраны.
                  if (!kReleaseMode) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _devSkip,
                      icon: const Icon(Icons.bug_report_rounded),
                      label: const Text('Тест: войти без кода'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('или', style: AppTextStyles.caption),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
