import 'package:flutter/material.dart';
import 'package:taxi/core/theme/app_colors.dart';
import 'package:taxi/core/theme/app_text_styles.dart';

class _Reward {
  final IconData icon;
  final String title;
  final int cost;
  const _Reward(this.icon, this.title, this.cost);
}

const _rewards = <_Reward>[
  _Reward(Icons.percent_rounded, 'Скидка 100 ₽', 500),
  _Reward(Icons.percent_rounded, 'Скидка 250 ₽', 1000),
  _Reward(Icons.upgrade_rounded, 'Повышение до Комфорт', 800),
  _Reward(Icons.card_giftcard_rounded, 'Бесплатная поездка', 2000),
];

const _earnRules = <(IconData, String, String)>[
  (Icons.directions_car_rounded, 'За каждые 10 ₽ поездки', '+1 миля'),
  (Icons.star_rounded, 'За оценку поездки', '+20 миль'),
  (Icons.group_add_rounded, 'За приглашённого друга', '+500 миль'),
];

class _Tx {
  final String title;
  final String when;
  final int amount; // + начисление, − списание
  const _Tx(this.title, this.when, this.amount);
}

const _history = <_Tx>[
  _Tx('Поездка · Аэропорт Сухум', 'Сегодня', 55),
  _Tx('Поездка · Набережная', 'Вчера', 25),
  _Tx('Скидка на поездку', '5 июня', -500),
  _Tx('Бонус за регистрацию', '1 июня', 1000),
];

/// Программа лояльности: мили как у авиакомпаний — копишь и тратишь.
class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  int _miles = 1250;
  static const _goal = 2000; // мили до следующего уровня (Золото)

  void _redeem(_Reward r) {
    final messenger = ScaffoldMessenger.of(context);
    if (_miles < r.cost) {
      messenger.showSnackBar(SnackBar(
        content: Text('Не хватает ${r.cost - _miles} миль'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _miles -= r.cost);
    messenger.showSnackBar(SnackBar(
      content: Text('Списано ${r.cost} миль · ${r.title}'),
      backgroundColor: AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_miles / _goal).clamp(0.0, 1.0);
    final left = (_goal - _miles).clamp(0, _goal);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Мили и бонусы'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _BalanceCard(miles: _miles, progress: progress, milesLeft: left),
          const SizedBox(height: 24),
          Text('Потратить мили', style: AppTextStyles.title),
          const SizedBox(height: 12),
          ..._rewards.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RewardCard(
                  reward: r,
                  enough: _miles >= r.cost,
                  onRedeem: () => _redeem(r),
                ),
              )),
          const SizedBox(height: 14),
          Text('Как копить мили', style: AppTextStyles.title),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (var i = 0; i < _earnRules.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.divider),
                  _EarnRow(
                    icon: _earnRules[i].$1,
                    text: _earnRules[i].$2,
                    amount: _earnRules[i].$3,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('История', style: AppTextStyles.title),
          const SizedBox(height: 8),
          ..._history.map((t) => _HistoryRow(tx: t)),
        ],
      ),
    );
  }
}

// ─────────────────────── Баланс ───────────────────────

class _BalanceCard extends StatelessWidget {
  final int miles;
  final double progress;
  final int milesLeft;
  const _BalanceCard(
      {required this.miles, required this.progress, required this.milesLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Ваши мили',
                  style: AppTextStyles.body.copyWith(color: Colors.white70)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        size: 16, color: AppColors.primaryDark),
                    const SizedBox(width: 4),
                    Text('Серебро',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$miles',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 40,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text('миль',
                  style: AppTextStyles.body.copyWith(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            milesLeft == 0
                ? 'Уровень Золото достигнут!'
                : 'До уровня Золото осталось $milesLeft миль',
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Награда ───────────────────────

class _RewardCard extends StatelessWidget {
  final _Reward reward;
  final bool enough;
  final VoidCallback onRedeem;
  const _RewardCard(
      {required this.reward, required this.enough, required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(reward.icon, color: AppColors.primaryDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${reward.cost} миль', style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRedeem,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: enough ? AppColors.accent : AppColors.disabled,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Обменять',
                  style: AppTextStyles.bodySecondary.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String amount;
  const _EarnRow(
      {required this.icon, required this.text, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: AppTextStyles.body)),
          Text(amount,
              style: AppTextStyles.body.copyWith(
                  color: AppColors.success, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final _Tx tx;
  const _HistoryRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: (positive ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              positive ? Icons.add_rounded : Icons.remove_rounded,
              color: positive ? AppColors.success : AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(tx.when, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}${tx.amount}',
            style: AppTextStyles.title.copyWith(
              fontSize: 16,
              color: positive ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
