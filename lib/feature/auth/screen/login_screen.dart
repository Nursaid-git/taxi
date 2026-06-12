import 'package:flutter/material.dart';
import 'package:taxi/core/enums/user_role.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/app_button_widget.dart';
import 'package:taxi/feature/auth/screen/otp_screen.dart';
import 'package:taxi/feature/auth/screen/register_screen.dart';
import 'package:taxi/feature/auth/widget/phone_field_widget.dart';
import 'package:taxi/feature/auth/widget/social_button_widget.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          role: widget.role,
          phone: '+7 940 ${_phone.text}',
          isRegister: false,
        ),
      ),
    );
  }

  void _toRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RegisterScreen(role: widget.role)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: _continue,
              ),
              const SizedBox(height: 24),
              const _OrDivider(),
              const SizedBox(height: 24),
              SocialButton(
                label: 'Продолжить с Google',
                icon: const Text('G',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
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
                    TextButton(
                      onPressed: _toRegister,
                      child: const Text('Регистрация'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
