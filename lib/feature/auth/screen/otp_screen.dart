import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taxi/core/enums/user_role.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/app_button_widget.dart';
import 'package:taxi/feature/auth/bloc/auth_cubit.dart';
import 'package:taxi/feature/driver/driver_registration_screen.dart';
import 'package:taxi/feature/home/client_shell.dart';
import 'package:taxi/feature/home/driver_shell.dart';

class OtpScreen extends StatefulWidget {
  final UserRole role;
  final String phone;
  final bool isRegister;

  const OtpScreen({
    super.key,
    required this.role,
    required this.phone,
    required this.isRegister,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _len = 6;
  final List<TextEditingController> _controllers =
      List.generate(_len, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(_len, (_) => FocusNode());

  String get _code => _controllers.map((c) => c.text).join();
  bool get _complete => _code.length == _len;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onChanged(int i, String value) {
    if (value.isNotEmpty && i < _len - 1) {
      _nodes[i + 1].requestFocus();
    } else if (value.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
    }
    setState(() {});
  }

  void _submit() {
    context.read<AuthCubit>().verify(phone: widget.phone, code: _code);
  }

  void _resend() {
    context.read<AuthCubit>().sendOtp(phone: widget.phone);
  }

  // Куда идём после успешного входа.
  // Водитель: регистрация → анкета; вход → приложение. Клиент → приложение.
  void _navigateNext() {
    final Widget next;
    if (widget.role.isDriver) {
      next = widget.isRegister
          ? const DriverRegistrationScreen()
          : const DriverShell();
    } else {
      next = const ClientShell();
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
    );
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (_, s) => s is AuthSuccess || s is AuthFailure,
      listener: (context, state) {
        if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
        if (state is AuthSuccess) {
          _navigateNext();
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
          _clearCode();
        }
      },
      builder: (context, state) {
        final loading = state is AuthLoading;
        return Scaffold(
          appBar: AppBar(title: const Text('Подтверждение')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: AppColors.whatsapp.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.chat_rounded,
                        color: AppColors.whatsapp, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text('Введите код из WhatsApp', style: AppTextStyles.h1),
                  const SizedBox(height: 8),
                  Text(
                    'Мы отправили 6-значный код на номер\n${widget.phone}',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_len, (i) => _OtpBox(
                          controller: _controllers[i],
                          node: _nodes[i],
                          onChanged: (v) => _onChanged(i, v),
                        )),
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: 'Подтвердить',
                    loading: loading,
                    onPressed: (_complete && !loading) ? _submit : null,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: loading ? null : _resend,
                      child: const Text('Отправить код повторно'),
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

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode node;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.node,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: node,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: AppTextStyles.h2,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: filled ? AppColors.primaryLight : AppColors.inputFill,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: filled ? AppColors.primary : AppColors.inputFill),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
