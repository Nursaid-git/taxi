-- ============================================================================
-- Домен chat · Индексы
-- ============================================================================

-- Загрузка переписки поездки по порядку — самый частый запрос.
create index if not exists idx_chat_messages_ride
  on public.chat_messages (ride_id, created_at);

-- Счётчик непрочитанных. Частичный индекс — только по непрочитанным (их мало).
create index if not exists idx_chat_messages_unread
  on public.chat_messages (ride_id)
  where read_at is null;
