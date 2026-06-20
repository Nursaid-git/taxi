-- ============================================================================
-- Домен loyalty · Индексы
-- ----------------------------------------------------------------------------
-- Уже есть: loyalty_accounts.user_id (PK), loyalty_rewards.id (PK) + code (UNIQUE),
-- loyalty_redemptions.id (PK).
-- ============================================================================

-- История транзакций пользователя (экран «Мили» — лента начислений/списаний).
create index if not exists idx_loyalty_tx_user
  on public.loyalty_transactions (user_id, created_at desc);

-- История обменов пользователя.
create index if not exists idx_loyalty_redemptions_user
  on public.loyalty_redemptions (user_id, created_at desc);

-- Активный каталог наград.
create index if not exists idx_loyalty_rewards_active
  on public.loyalty_rewards (cost)
  where is_active;
