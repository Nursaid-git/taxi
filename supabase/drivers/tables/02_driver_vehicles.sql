-- ============================================================================
-- Домен drivers · Таблица driver_vehicles (автомобили)
-- ----------------------------------------------------------------------------
-- Отдельная таблица, а не колонки в driver_profiles: машина может меняться,
-- и удобно хранить историю. В каждый момент активна одна машина.
-- ============================================================================

create table if not exists public.driver_vehicles (
  id         uuid primary key default gen_random_uuid(),
  driver_id  uuid not null references auth.users (id) on delete cascade,

  brand      text not null,
  model      text not null,
  year       integer,
  color      text,
  plate      text not null,        -- госномер
  photo_url  text,

  is_active  boolean not null default true,
  created_at timestamptz not null default now(),

  constraint vehicle_year_sane check (year is null or year between 1950 and 2100)
);

comment on table public.driver_vehicles is 'Автомобили водителя (активна одна).';

-- Ровно одна активная машина на водителя. Частичный уникальный индекс — самый
-- чистый способ выразить «не более одной строки с is_active = true на driver_id».
create unique index if not exists uq_driver_active_vehicle
  on public.driver_vehicles (driver_id)
  where is_active;
