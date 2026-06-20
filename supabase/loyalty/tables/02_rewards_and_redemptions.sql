-- ============================================================================
-- Домен loyalty · Каталог наград и обмены
-- ============================================================================

-- Каталог наград. Управляется админом/бэкендом; клиент только читает.
create table if not exists public.loyalty_rewards (
  id         uuid primary key default gen_random_uuid(),
  code       text unique not null,            -- стабильный идентификатор
  title      text not null,
  kind       public.reward_kind not null,
  cost       integer not null,                -- цена в милях
  value      integer,                         -- польза: ₽ скидки / класс и т.п.
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),

  constraint reward_cost_positive check (cost > 0)
);

comment on table public.loyalty_rewards is 'Каталог наград за мили.';

-- Обмены: история того, что пользователь забрал за мили.
create table if not exists public.loyalty_redemptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  reward_id  uuid not null references public.loyalty_rewards (id),
  cost       integer not null,                -- сколько списали (фиксируем на момент обмена)
  status     public.redemption_status not null default 'active',
  created_at timestamptz not null default now(),
  used_at    timestamptz
);

comment on table public.loyalty_redemptions is 'История обменов миль на награды.';

-- ----------------------------------------------------------------------------
-- Примеры наград (как на экране «Мили»). on conflict — чтобы повторный прогон
-- файла не падал и не плодил дубли.
-- ----------------------------------------------------------------------------
insert into public.loyalty_rewards (code, title, kind, cost, value) values
  ('discount_100',  'Скидка 100 ₽',          'discount',  500,  100),
  ('discount_250',  'Скидка 250 ₽',          'discount', 1000,  250),
  ('upgrade_comfort','Повышение до Комфорт',  'upgrade',   800,  null),
  ('free_ride',     'Бесплатная поездка',     'free_ride',2000,  null)
on conflict (code) do nothing;
