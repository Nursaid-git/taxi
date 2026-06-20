-- ============================================================================
-- Домен loyalty · Счета и журнал транзакций
-- ============================================================================

-- Счёт лояльности 1:1 к пользователю.
create table if not exists public.loyalty_accounts (
  user_id         uuid primary key references auth.users (id) on delete cascade,
  balance         integer not null default 0,   -- текущие мили
  lifetime_earned integer not null default 0,    -- начислено за всё время (для уровня)
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint loyalty_balance_nonneg check (balance >= 0)
);

comment on table public.loyalty_accounts is 'Счёт миль пользователя.';

drop trigger if exists trg_loyalty_accounts_updated_at on public.loyalty_accounts;
create trigger trg_loyalty_accounts_updated_at
  before update on public.loyalty_accounts
  for each row execute function public.set_updated_at();

-- Журнал — источник истины. Баланс считается из него.
create table if not exists public.loyalty_transactions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  amount     integer not null,              -- +начисление / −списание (не 0)
  reason     public.loyalty_reason not null,
  ride_id    uuid references public.rides (id) on delete set null,
  note       text,
  created_at timestamptz not null default now(),

  constraint loyalty_amount_nonzero check (amount <> 0)
);

comment on table public.loyalty_transactions is
  'Журнал начислений/списаний миль. Источник истины по балансу.';

-- ----------------------------------------------------------------------------
-- Триггер: запись в журнал → пересчёт счёта.
-- balance += amount; при начислении (amount > 0) растёт и lifetime_earned.
-- Если счёта ещё нет — создаём. Если баланс ушёл бы в минус — CHECK на
-- loyalty_accounts откатит транзакцию (защита от списания «в долг»).
-- security definer: триггер пишет в счёт в обход RLS.
-- ----------------------------------------------------------------------------
create or replace function public.apply_loyalty_transaction()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.loyalty_accounts (user_id, balance, lifetime_earned)
  values (
    new.user_id,
    new.amount,
    greatest(new.amount, 0)
  )
  on conflict (user_id) do update set
    balance = public.loyalty_accounts.balance + new.amount,
    lifetime_earned = public.loyalty_accounts.lifetime_earned
                      + greatest(new.amount, 0);
  return new;
end;
$$;

drop trigger if exists trg_apply_loyalty_transaction on public.loyalty_transactions;
create trigger trg_apply_loyalty_transaction
  after insert on public.loyalty_transactions
  for each row execute function public.apply_loyalty_transaction();

-- ----------------------------------------------------------------------------
-- Автосоздание счёта при появлении профиля (чтобы у каждого клиента был счёт).
-- ----------------------------------------------------------------------------
create or replace function public.create_loyalty_account()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.loyalty_accounts (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_create_loyalty_account on public.profiles;
create trigger trg_create_loyalty_account
  after insert on public.profiles
  for each row execute function public.create_loyalty_account();
