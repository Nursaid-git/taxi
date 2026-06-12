import 'package:url_launcher/url_launcher.dart';

/// Открыть WhatsApp с номером телефона.
/// Телефон может быть в любом формате — лишние символы убираются.
Future<void> openWhatsApp(String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.parse('https://wa.me/$digits');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
