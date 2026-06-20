-- ============================================================================
-- Домен loyalty · Типы (enum)
-- ============================================================================

-- За что начислены/списаны мили.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'loyalty_reason') then
    create type public.loyalty_reason as enum (
      'trip',          -- за завершённую поездку
      'rating',        -- за оценку поездки
      'referral',      -- за приглашённого друга
      'signup_bonus',  -- бонус за регистрацию
      'redemption',    -- списание при обмене на награду
      'adjustment'     -- ручная корректировка (поддержка/админ)
    );
  end if;
end$$;

-- Вид награды.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'reward_kind') then
    create type public.reward_kind as enum ('discount', 'free_ride', 'upgrade');
  end if;
end$$;

-- Статус обмена.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'redemption_status') then
    create type public.redemption_status as enum ('active', 'used', 'expired');
  end if;
end$$;
