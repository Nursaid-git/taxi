import 'package:flutter/material.dart';

/// ВСЕ цвета приложения в одном месте.
///
/// Стиль — Yandex Go: жёлтый акцент + чёрный UI.
/// • [accent] (жёлтый) — главная кнопка и выделение выбора.
/// • [primary] (чёрный) — иконки, важный текст, пины, выделенные границы.
/// Меняешь эти два значения — меняется весь характер приложения.
class AppColors {
  AppColors._();

  // ─────────────── АКЦЕНТ (жёлтый) ───────────────
  static const Color accent = Color(0xFFFFCC00); // жёлтый — CTA, выбор
  static const Color accentDark = Color(0xFFF5B800); // нажатие
  static const Color accentLight = Color(0xFFFFF6D6); // светлый фон выделения

  // ─────────────── ОСНОВНОЙ UI (чёрный) ───────────────
  static const Color primary = Color(0xFF1A1A1A); // иконки, акцентный текст
  static const Color primaryDark = Color(0xFF000000);
  static const Color primaryLight = Color(0xFFF1F2F4); // нейтральная плашка

  // ─────────────── ФОН И ПОВЕРХНОСТИ ───────────────
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  // ─────────────── ТЕКСТ ───────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFF1A1A1A); // текст на жёлтой кнопке

  // ─────────────── ГРАНИЦЫ / ПОЛЯ ВВОДА ───────────────
  static const Color border = Color(0xFFE6E8EB);
  static const Color divider = Color(0xFFEFF1F3);
  static const Color inputFill = Color(0xFFF1F2F4);

  // ─────────────── СТАТУСЫ ───────────────
  static const Color success = Color(0xFF1FA463);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFF5A623);

  // ─────────────── ПРОЧЕЕ ───────────────
  static const Color shadow = Color(0x14000000);
  static const Color disabled = Color(0xFFD1D5DB);

  static const Color whatsapp = Color(0xFF25D366);
}
