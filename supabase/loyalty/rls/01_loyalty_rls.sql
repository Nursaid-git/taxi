-- ============================================================================
-- Домен loyalty · RLS
-- ----------------------------------------------------------------------------
-- Свой счёт/транзакции/обмены — только владельцу. Каталог — всем авторизованным.
-- Любая запись миль — через триггеры/функции/service_role, не прямым запросом.
-- ============================================================================

-- Счёт лояльности: только свой, только чтение.
alter table public.loyalty_accounts enable row level security;
drop policy if exists "loyalty_accounts_select_own" on public.loyalty_accounts;
create policy "loyalty_accounts_select_own"
  on public.loyalty_accounts
  for select
  using (auth.uid() = user_id);

-- Транзакции: только свои, только чтение. Вставка — триггерами/функциями.
alter table public.loyalty_transactions enable row level security;
drop policy if exists "loyalty_tx_select_own" on public.loyalty_transactions;
create policy "loyalty_tx_select_own"
  on public.loyalty_transactions
  for select
  using (auth.uid() = user_id);

-- Каталог наград: читают все авторизованные (это публичный список).
alter table public.loyalty_rewards enable row level security;
drop policy if exists "loyalty_rewards_select_all" on public.loyalty_rewards;
create policy "loyalty_rewards_select_all"
  on public.loyalty_rewards
  for select
  to authenticated
  using (true);

-- Обмены: только свои, только чтение. Создание — функцией redeem_reward.
alter table public.loyalty_redemptions enable row level security;
drop policy if exists "loyalty_redemptions_select_own" on public.loyalty_redemptions;
create policy "loyalty_redemptions_select_own"
  on public.loyalty_redemptions
  for select
  using (auth.uid() = user_id);
