-- ============================================================================
-- Домен rides · Индексы
-- ----------------------------------------------------------------------------
-- Уже проиндексировано автоматически:
--  • rides.id, ride_stops.id, ride_ratings.id — PRIMARY KEY;
--  • ride_stops(ride_id, position)            — UNIQUE;
--  • ride_ratings(ride_id, rater_id)          — UNIQUE.
-- ============================================================================

-- «Мои поездки» у клиента: история и активный заказ. Частый запрос.
create index if not exists idx_rides_client_id
  on public.rides (client_id, created_at desc);

-- «Мои поездки» у водителя.
create index if not exists idx_rides_driver_id
  on public.rides (driver_id, created_at desc);

-- Очередь свободных заявок для водителей: WHERE status = 'searching'.
-- Частичный индекс — только по нужным строкам: он маленький и быстрый, потому
-- что «searching» заказов в любой момент мало (большинство уже завершены).
create index if not exists idx_rides_searching
  on public.rides (created_at)
  where status = 'searching';

-- Точки конкретного заказа (по ride_id). UNIQUE(ride_id, position) тоже
-- покрывает это, но явный индекс по ride_id делает намерение очевидным
-- и помогает join'ам ride → stops.
create index if not exists idx_ride_stops_ride_id
  on public.ride_stops (ride_id);

-- Рейтинг водителя: «средняя оценка по ratee_id».
create index if not exists idx_ride_ratings_ratee_id
  on public.ride_ratings (ratee_id);
