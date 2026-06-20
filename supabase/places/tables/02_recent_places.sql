-- ============================================================================
-- Домен places · Таблица recent_places (недавние адреса)
-- ----------------------------------------------------------------------------
-- История выбранных адресов для быстрого повтора. Дедуп по адресу: повторный
-- выбор не плодит строки, а обновляет last_used_at (upsert из приложения).
-- ============================================================================

create table if not exists public.recent_places (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,

  address      text not null,
  lat          double precision not null,
  lng          double precision not null,
  last_used_at timestamptz not null default now(),

  -- Один и тот же адрес у пользователя — одна строка.
  constraint recent_places_unique unique (user_id, address)
);

comment on table public.recent_places is 'Недавние адреса пользователя (история выбора).';
