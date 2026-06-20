import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taxi/core/enums/user_role.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/app_button_widget.dart';
import 'package:taxi/feature/auth/bloc/auth_cubit.dart';
import 'package:taxi/feature/auth/screen/login_screen.dart';
import 'package:taxi/feature/auth/screen/otp_screen.dart';
import 'package:taxi/feature/auth/widget/phone_field_widget.dart';

class RegisterScreen extends StatefulWidget {
  final UserRole role;
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _agree = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _continue() {
    if (_phone.text.trim().isEmpty || !_agree) return;
    context.read<AuthCubit>().sendOtp(
          phone: '+7 940 ${_phone.text.trim()}',
          role: widget.role,
          fullName: _name.text,
        );
  }

  void _toLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(role: widget.role)),
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
                isRegister: true,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final loading = state is AuthLoading;
        return Scaffold(
          appBar: AppBar(title: Text('Регистрация · ${widget.role.titleRu}')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text('Создать аккаунт', style: AppTextStyles.h1),
                  const SizedBox(height: 8),
                  Text(
                    widget.role.isDriver
                        ? 'После подтверждения номера заполните анкету водителя.'
                        : 'Это займёт меньше минуты.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 28),
                  Text('Как вас зовут', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Имя'),
                  ),
                  const SizedBox(height: 16),
                  Text('Номер телефона', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 8),
                  PhoneField(controller: _phone),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agree,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _agree = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Я принимаю условия использования и политику конфиденциальности',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Получить код',
                    icon: Icons.chat_rounded,
                    loading: loading,
                    onPressed: loading ? null : _continue,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Уже есть аккаунт?', style: AppTextStyles.bodySecondary),
                        TextButton(onPressed: _toLogin, child: const Text('Войти')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
