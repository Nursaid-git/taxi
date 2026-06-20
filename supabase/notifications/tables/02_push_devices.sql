-- ============================================================================
-- Домен notifications · Таблица push_devices (токены устройств)
-- ============================================================================

create table if not exists public.push_devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,

  token        text not null unique,          -- FCM / APNs / web push токен
  platform     public.device_platform not null,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

comment on table public.push_devices is 'Токены устройств пользователя для пуш-уведомлений.';

drop trigger if exists trg_push_devices_updated_at on public.push_devices;
create trigger trg_push_devices_updated_at
  before update on public.push_devices
  for each row execute function public.set_updated_at();
