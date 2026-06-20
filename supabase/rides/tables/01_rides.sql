-- ============================================================================
-- Домен rides · Таблица rides (заказ)
-- ============================================================================

create table if not exists public.rides (
  id              uuid primary key default gen_random_uuid(),

  -- Участники. client обязателен; driver появляется при принятии заказа.
  -- client удаляется каскадом со своими заказами; при удалении driver заказ
  -- остаётся (set null) — нужен в истории клиента и для отчётности.
  client_id       uuid not null references auth.users (id) on delete cascade,
  driver_id       uuid references auth.users (id) on delete set null,

  status          public.ride_status   not null default 'searching',
  ride_class      public.ride_class    not null,
  payment_method  public.payment_method not null default 'cash',

  -- Точка подачи («Моё местоположение»). Назначения — в ride_stops.
  pickup_address  text             not null,
  pickup_lat      double precision not null,
  pickup_lng      double precision not null,

  -- Оценка маршрута на момент заказа и итог по факту.
  distance_km     numeric(6, 1),
  duration_min    integer,
  price_estimated integer not null,          -- ₽, предварительно
  price_final     integer,                   -- ₽, по завершении

  -- Ожидание клиента: до этого времени бесплатно, дальше — платно.
  free_wait_until timestamptz,
  wait_charge     integer not null default 0,

  -- Отмена.
  cancelled_by    public.ride_actor,
  cancel_reason   text,

  -- Времена жизненного цикла (для истории и аналитики).
  created_at      timestamptz not null default now(),
  accepted_at     timestamptz,
  arrived_at      timestamptz,
  started_at      timestamptz,
  completed_at    timestamptz,
  cancelled_at    timestamptz,
  updated_at      timestamptz not null default now(),

  -- Инварианты, которые держим на уровне БД (а не надеемся на приложение):
  constraint rides_price_estimated_nonneg check (price_estimated >= 0),
  constraint rides_price_final_nonneg    check (price_final is null or price_final >= 0),
  constraint rides_distance_nonneg       check (distance_km is null or distance_km >= 0),
  -- Водитель обязателен на всех стадиях, кроме поиска/просрочки.
  constraint rides_driver_required check (
    driver_id is not null
    or status in ('searching', 'cancelled', 'expired')
  )
);

comment on table public.rides is 'Заказ такси: от создания до завершения и оценки.';
comment on column public.rides.free_wait_until is
  'До этого момента ожидание клиента бесплатное; позже включается платное.';

-- updated_at проставляет БД (функция из домена auth).
drop trigger if exists trg_rides_updated_at on public.rides;
create trigger trg_rides_updated_at
  before update on public.rides
  for each row execute function public.set_updated_at();
