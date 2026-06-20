-- ============================================================================
-- Домен notifications · Таблица notifications
-- ============================================================================

create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,

  type       public.notification_type not null,
  title      text not null,
  body       text,
  ride_id    uuid references public.rides (id) on delete set null,  -- если про поездку
  data       jsonb not null default '{}',                            -- произвольная нагрузка
  read_at    timestamptz,

  created_at timestamptz not null default now()
);

comment on table public.notifications is 'Уведомления пользователя (лента + пуш).';
