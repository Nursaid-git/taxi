-- ============================================================================
-- Домен rides · Таблица ride_ratings (оценка и комментарий)
-- ----------------------------------------------------------------------------
-- После завершения поездки участник ставит оценку. Сделано «двусторонне»
-- (rater → ratee), чтобы в будущем и водитель мог оценить клиента, без новой
-- таблицы. Сейчас приложение использует только сторону «клиент оценивает водителя».
-- ============================================================================

create table if not exists public.ride_ratings (
  id         uuid primary key default gen_random_uuid(),
  ride_id    uuid not null references public.rides (id) on delete cascade,

  rater_id   uuid not null references auth.users (id) on delete cascade, -- кто оценивает
  ratee_id   uuid not null references auth.users (id) on delete cascade, -- кого оценивают

  stars      integer not null,
  comment    text,
  tags       text[] not null default '{}',  -- быстрые теги: «Чисто», «Вежливый водитель»…

  created_at timestamptz not null default now(),

  constraint ride_ratings_stars_range check (stars between 1 and 5),
  -- Один участник оценивает конкретную поездку только один раз.
  constraint ride_ratings_unique_per_rater unique (ride_id, rater_id)
);

comment on table public.ride_ratings is
  'Оценка (1–5), комментарий и теги по завершённой поездке.';
