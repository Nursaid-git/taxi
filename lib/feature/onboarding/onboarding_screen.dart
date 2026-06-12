import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/app_button_widget.dart';
import 'package:taxi/feature/role/role_selection_screen.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Slide(this.icon, this.title, this.subtitle);
}

const _slides = <_Slide>[
  _Slide(
    Icons.location_on_rounded,
    'Поездки по всей Абхазии',
    'Закажи такси за пару касаний — от Гагры до Сухума.',
  ),
  _Slide(
    Icons.payments_rounded,
    'Честная цена заранее',
    'Стоимость поездки видна до заказа. Без сюрпризов.',
  ),
  _Slide(
    Icons.verified_user_rounded,
    'Проверенные водители',
    'Каждый водитель проходит модерацию перед выходом на линию.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Пропустить'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 160,
                          width: 160,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon,
                              size: 80, color: AppColors.primary),
                        ),
                        const SizedBox(height: 40),
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h1),
                        const SizedBox(height: 12),
                        Text(s.subtitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySecondary),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 24 : 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AppButton(
                label: isLast ? 'Начать' : 'Далее',
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
