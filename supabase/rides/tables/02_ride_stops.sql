-- ============================================================================
-- Домен rides · Таблица ride_stops (точки назначения)
-- ----------------------------------------------------------------------------
-- В приложении можно добавлять несколько адресов («+ адрес»). Поэтому назначения
-- — это не колонка, а отдельные строки, упорядоченные по position.
-- Почему отдельная таблица, а не массив/jsonb в rides:
--  • порядок и количество точек переменные;
--  • по точкам удобно строить запросы и проверять целостность (координаты).
-- ============================================================================

create table if not exists public.ride_stops (
  id         uuid primary key default gen_random_uuid(),
  ride_id    uuid not null references public.rides (id) on delete cascade,

  position   integer not null,          -- порядок: 1, 2, 3…
  address    text             not null,
  lat        double precision not null,
  lng        double precision not null,

  created_at timestamptz not null default now(),

  -- В рамках одного заказа порядковый номер уникален (нет двух «точек №1»).
  constraint ride_stops_position_positive check (position >= 1),
  constraint ride_stops_unique_position unique (ride_id, position)
);

comment on table public.ride_stops is
  'Точки назначения заказа по порядку (поддержка нескольких адресов).';
