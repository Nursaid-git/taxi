-- ============================================================================
-- Домен notifications · Индексы
-- ----------------------------------------------------------------------------
-- Уже есть: PK обеих таблиц; push_devices.token (UNIQUE).
-- ============================================================================

-- Лента уведомлений пользователя (свежие сверху).
create index if not exists idx_notifications_user
  on public.notifications (user_id, created_at desc);

-- Счётчик непрочитанных (бейдж на колокольчике). Частичный — их мало.
create index if not exists idx_notifications_unread
  on public.notifications (user_id)
  where read_at is null;

-- Все устройства пользователя (кому слать пуш).
create index if not exists idx_push_devices_user
  on public.push_devices (user_id);
