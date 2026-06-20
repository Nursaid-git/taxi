-- ============================================================================
-- Домен places · Таблица saved_places (избранные адреса)
-- ============================================================================

create table if not exists public.saved_places (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,

  kind       public.place_kind not null default 'other',
  label      text,                       -- подпись («Мамин дом» и т.п.)
  address    text not null,
  lat        double precision not null,
  lng        double precision not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.saved_places is 'Сохранённые адреса пользователя (Дом, Работа, прочие).';

drop trigger if exists trg_saved_places_updated_at on public.saved_places;
create trigger trg_saved_places_updated_at
  before update on public.saved_places
  for each row execute function public.set_updated_at();

-- По одному «Дому» и одной «Работе» на пользователя. Для 'other' ограничения нет.
create unique index if not exists uq_saved_place_home_work
  on public.saved_places (user_id, kind)
  where kind in ('home', 'work');
