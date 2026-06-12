import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';

/// Поле ввода телефона с префиксом страны.
///
/// По умолчанию — Абхазия. Мобильные номера Абхазии в коде +7 940.
/// Префикс можно поменять одним значением [dialCode].
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String dialCode;
  final String flag;

  const PhoneField({
    super.key,
    required this.controller,
    this.dialCode = '+7 940',
    this.flag = '🇦🇧', // Абхазия
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      style: AppTextStyles.body,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      decoration: InputDecoration(
        hintText: '12 34 567',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                dialCode,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: AppColors.border),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}
