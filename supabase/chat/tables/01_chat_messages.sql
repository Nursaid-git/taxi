-- ============================================================================
-- Домен chat · Таблица chat_messages
-- ============================================================================

create table if not exists public.chat_messages (
  id         uuid primary key default gen_random_uuid(),
  ride_id    uuid not null references public.rides (id) on delete cascade,
  sender_id  uuid not null references auth.users (id) on delete cascade,

  body       text not null,
  read_at    timestamptz,                 -- когда собеседник прочитал
  created_at timestamptz not null default now(),

  constraint chat_body_not_blank check (length(btrim(body)) > 0)
);

comment on table public.chat_messages is 'Сообщения чата в рамках поездки.';
