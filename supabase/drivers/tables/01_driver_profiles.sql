-- ============================================================================
-- Домен drivers · Таблица driver_profiles
-- ----------------------------------------------------------------------------
-- 1:1 к auth.users — но существует только у тех, кто прошёл анкету водителя.
-- Создаётся функцией save_driver_profile (см. functions/), не триггером auth,
-- потому что появляется не при регистрации, а при заполнении анкеты.
-- ============================================================================

create table if not exists public.driver_profiles (
  id              uuid primary key references auth.users (id) on delete cascade,

  -- Анкета (шаг «Личные данные»).
  first_name      text,
  last_name       text,
  birth_date      date,
  city            text,
  photo_url       text,

  -- Документ-удостоверение (шаг «Документы»). Файлы — в driver_documents.
  license_number  text,
  license_expiry  date,

  -- Проверка.
  status          public.verification_status not null default 'pending',
  rejection_reason text,
  approved_at     timestamptz,

  -- Доступность.
  is_online       boolean not null default false,

  -- Агрегаты (денормализация ради скорости; считаются триггерами).
  rating_avg      numeric(3, 2) not null default 5.00,
  rating_count    integer       not null default 0,
  trips_count     integer       not null default 0,
  balance         integer       not null default 0,   -- ₽ к выводу

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint driver_balance_nonneg check (balance >= 0),
  constraint driver_rating_range  check (rating_avg between 0 and 5)
);

comment on table public.driver_profiles is
  'Профиль водителя: анкета, статус проверки, рейтинг, баланс, онлайн.';

drop trigger if exists trg_driver_profiles_updated_at on public.driver_profiles;
create trigger trg_driver_profiles_updated_at
  before update on public.driver_profiles
  for each row execute function public.set_updated_at();
