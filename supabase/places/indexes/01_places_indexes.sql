-- ============================================================================
-- Домен places · Индексы
-- ----------------------------------------------------------------------------
-- Уже есть: PK обеих таблиц; uq_saved_place_home_work; recent_places UNIQUE
-- (user_id, address) — покрывает поиск по user_id и upsert по адресу.
-- ============================================================================

-- Список избранных адресов пользователя.
create index if not exists idx_saved_places_user
  on public.saved_places (user_id);

-- Недавние пользователя по свежести (на главном показываем последние).
create index if not exists idx_recent_places_user
  on public.recent_places (user_id, last_used_at desc);
