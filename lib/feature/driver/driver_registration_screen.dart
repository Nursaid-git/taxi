import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';
import 'package:taxi/core/widgets/app_button_widget.dart';
import 'package:taxi/feature/driver/driver_pending_screen.dart';

/// Анкета водителя из 4 шагов. Заполняется сразу после подтверждения номера.
/// Дизайн-прототип: поля визуальные, данные не сохраняются.
class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _controller = PageController();
  int _step = 0;
  static const _total = 4;

  static const _titles = [
    'Личные данные',
    'Документы',
    'Автомобиль',
    'Проверка данных',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _total - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DriverPendingScreen()),
      );
    }
  }

  void _back() {
    if (_step > 0) {
      _controller.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_step]),
        leading: IconButton(
            onPressed: _back, icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Прогресс по шагам
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: List.generate(_total, (i) {
                  final done = i <= _step;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      decoration: BoxDecoration(
                        color: done ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: const [
                  _StepPersonal(),
                  _StepDocuments(),
                  _StepCar(),
                  _StepReview(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: AppButton(
                label: _step == _total - 1 ? 'Отправить на проверку' : 'Далее',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Шаги ───────────────────────

class _StepPersonal extends StatelessWidget {
  const _StepPersonal();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const Center(child: _PhotoUpload(label: 'Фото профиля', circle: true)),
        const SizedBox(height: 24),
        const _Field(label: 'Имя', hint: 'Иван'),
        const _Field(label: 'Фамилия', hint: 'Иванов'),
        const _Field(label: 'Дата рождения', hint: '01.01.1990'),
        const _Field(label: 'Город', hint: 'Сухум'),
      ],
    );
  }
}

class _StepDocuments extends StatelessWidget {
  const _StepDocuments();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: const [
        _Field(label: 'Номер вод. удостоверения', hint: '99 99 999999'),
        _Field(label: 'Срок действия', hint: '01.01.2030'),
        SizedBox(height: 8),
        _PhotoUpload(label: 'Фото вод. удостоверения'),
        SizedBox(height: 16),
        _PhotoUpload(label: 'Селфи для верификации'),
      ],
    );
  }
}

class _StepCar extends StatelessWidget {
  const _StepCar();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: const [
        _Field(label: 'Марка', hint: 'Toyota'),
        _Field(label: 'Модель', hint: 'Camry'),
        Row(
          children: [
            Expanded(child: _Field(label: 'Год', hint: '2021')),
            SizedBox(width: 12),
            Expanded(child: _Field(label: 'Цвет', hint: 'Белый')),
          ],
        ),
        _Field(label: 'Госномер', hint: 'A 123 AB'),
        SizedBox(height: 8),
        _PhotoUpload(label: 'Фото автомобиля'),
      ],
    );
  }
}

class _StepReview extends StatelessWidget {
  const _StepReview();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Проверьте данные. После отправки заявка уйдёт на модерацию — '
                  'обычно это занимает до 24 часов.',
                  style: AppTextStyles.bodySecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _reviewRow('Имя', 'Иван Иванов'),
        _reviewRow('Город', 'Сухум'),
        _reviewRow('Документы', 'Загружены'),
        _reviewRow('Автомобиль', 'Toyota Camry, Белый'),
        _reviewRow('Госномер', 'A 123 AB'),
      ],
    );
  }

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodySecondary),
            Text(value,
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ─────────────────────── Вспомогательные ───────────────────────

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  const _Field({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodySecondary),
          const SizedBox(height: 8),
          TextFormField(decoration: InputDecoration(hintText: hint)),
        ],
      ),
    );
  }
}

class _PhotoUpload extends StatelessWidget {
  final String label;
  final bool circle;
  const _PhotoUpload({required this.label, this.circle = false});

  @override
  Widget build(BuildContext context) {
    if (circle) {
      return Column(
        children: [
          Container(
            height: 96,
            width: 96,
            decoration: const BoxDecoration(
              color: AppColors.inputFill,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_a_photo_rounded,
                color: AppColors.textHint, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.caption),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
          style: BorderStyle.solid,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_rounded, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
          const Icon(Icons.add, color: AppColors.primary),
        ],
      ),
    );
  }
}
