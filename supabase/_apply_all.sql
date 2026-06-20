-- Авто-сгенерировано: все домены в порядке зависимостей.


-- ===== [01] auth/tables/00_enums.sql =====
-- ============================================================================
-- Домен auth · Типы (enum)
-- ----------------------------------------------------------------------------
-- Почему enum, а не text: роль — это закрытый список значений. enum не даёт
-- записать опечатку ('driverr') или произвольную строку, и экономит место.
-- Минус enum — добавлять значения чуть сложнее (ALTER TYPE ... ADD VALUE),
-- но набор ролей меняется крайне редко, так что выгода перевешивает.
-- ============================================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type public.user_role as enum ('client', 'driver');
  end if;
end$$;

comment on type public.user_role is
  'Роль пользователя в приложении. Одно приложение — две роли.';


-- ===== [02] auth/tables/01_profiles.sql =====
-- ============================================================================
-- Домен auth · Таблица profiles (прикладной профиль пользователя)
-- ----------------------------------------------------------------------------
-- 1:1 к auth.users. Сюда складываем то, что нужно приложению (имя, фото,
-- телефон для отображения), не трогая системную auth.users.
-- ============================================================================

create table if not exists public.profiles (
  -- id == auth.users.id. on delete cascade: удалили аккаунт — удалился профиль.
  id          uuid primary key references auth.users (id) on delete cascade,

  -- Телефон дублируем сюда из auth.users.phone, чтобы приложение могло его
  -- читать/искать без доступа к схеме auth. unique — один аккаунт на номер.
  phone       text unique,

  full_name   text,
  avatar_url  text,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is
  'Прикладной профиль пользователя, 1:1 к auth.users.';
comment on column public.profiles.phone is
  'Копия auth.users.phone (формат E.164, Абхазия: +7940…). Для удобных запросов.';

-- ----------------------------------------------------------------------------
-- Триггер updated_at: время изменения проставляет БД, а не приложение.
-- Почему: клиент может прислать неверное время/часовой пояс или забыть его
-- обновить. Источник истины по времени — сервер.
-- search_path = '' + полные имена схем — рекомендация Supabase для безопасности
-- функций (защита от перехвата через подменённый search_path).
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- Автосоздание профиля при регистрации.
-- Supabase создаёт запись в auth.users после подтверждения OTP — на это вешаем
-- триггер, который создаёт профиль и (если роль передана при регистрации в
-- options.data) проставляет роль.
--
-- Почему через триггер security definer:
--  • профиль появится всегда, даже если приложение упадёт сразу после signup;
--  • функция обходит RLS контролируемо (обычному клиенту вставка роли запрещена).
--
-- Роль берём из raw_user_meta_data->>'role' (это то, что приложение кладёт в
-- supabase.auth.signUp(..., data: {role, full_name}) ). Самовыбор роли допустим:
-- 'driver' здесь = «зарегистрировался как водитель», а право брать заказы даёт
-- отдельная проверка/модерация (домен drivers), а не сама роль.
-- ----------------------------------------------------------------------------
-- Примечание: переменную роли держим как text (а не public.user_role), чтобы
-- функция СОЗДАВАЛАСЬ независимо от того, применён ли уже 00_enums.sql.
-- Тип проверяется при создании только у типизированных DECLARE; ссылки на
-- типы/таблицы внутри SQL-операторов проверяются в рантайме (к тому моменту
-- всё уже применено). Невалидную роль молча пропускаем.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := new.raw_user_meta_data ->> 'role';
begin
  insert into public.profiles (id, phone, full_name)
  values (
    new.id,
    new.phone,
    new.raw_user_meta_data ->> 'full_name'
  )
  on conflict (id) do nothing;

  if v_role is not null then
    begin
      insert into public.user_roles (user_id, role)
      values (new.id, v_role::public.user_role)
      on conflict (user_id, role) do nothing;
    exception when others then
      null;  -- роль не из enum / таблицы ещё нет — пропускаем
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ===== [03] auth/tables/02_user_roles.sql =====
-- ============================================================================
-- Домен auth · Таблица user_roles (роли пользователя) + функция has_role
-- ----------------------------------------------------------------------------
-- Связь «пользователь ↔ роль» вынесена в отдельную таблицу, потому что один
-- аккаунт может быть и клиентом, и водителем. Колонкой role в profiles это
-- не выразить.
-- ============================================================================

create table if not exists public.user_roles (
  user_id    uuid not null references auth.users (id) on delete cascade,
  role       public.user_role not null,
  created_at timestamptz not null default now(),

  -- Составной первичный ключ: одна и та же роль не может дублироваться у юзера,
  -- но ролей у него может быть несколько (разные строки).
  primary key (user_id, role)
);

comment on table public.user_roles is
  'Роли пользователя. Одна или обе из (client, driver).';

-- ----------------------------------------------------------------------------
-- has_role(uid, role): помощник для RLS других доменов.
-- Пример использования: «принимать заказ может только водитель».
--
-- security definer + stable:
--  • definer — функция читает user_roles в обход RLS этой таблицы, иначе
--    политики, которые сами обращаются к user_roles, зациклились бы/не сработали;
--  • stable — в пределах запроса результат не меняется, планировщик это учтёт.
-- search_path = '' — безопасность (полные имена схем ниже).
-- ----------------------------------------------------------------------------
create or replace function public.has_role(p_user_id uuid, p_role public.user_role)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = p_user_id
      and ur.role = p_role
  );
$$;

comment on function public.has_role(uuid, public.user_role) is
  'true, если у пользователя есть указанная роль. Для использования в RLS.';


-- ===== [04] auth/indexes/01_auth_indexes.sql =====
-- ============================================================================
-- Домен auth · Индексы
-- ----------------------------------------------------------------------------
-- Индекс ускоряет чтение, но замедляет запись и занимает место. Поэтому
-- добавляем только под реальные частые запросы, а не «на всякий случай».
--
-- Что уже проиндексировано автоматически (отдельный индекс НЕ нужен):
--  • profiles.id           — PRIMARY KEY;
--  • profiles.phone        — UNIQUE (unique-ограничение создаёт индекс);
--  • user_roles(user_id,…) — PRIMARY KEY (user_id, role); покрывает поиск по
--                            user_id и по паре (user_id, role).
-- ============================================================================

-- «Найти всех водителей» / выборка пользователей по роли.
-- В составном PK (user_id, role) колонка role идёт второй, поэтому поиск
-- ТОЛЬКО по role этим ключом не ускоряется — нужен отдельный индекс по role.
create index if not exists idx_user_roles_role
  on public.user_roles (role);

comment on index public.idx_user_roles_role is
  'Быстрая выборка пользователей по роли (например, список водителей).';


-- ===== [05] auth/rls/01_profiles_rls.sql =====
-- ============================================================================
-- Домен auth · RLS для profiles
-- ----------------------------------------------------------------------------
-- Напоминание: приложение ходит в БД напрямую. Без RLS таблица либо открыта
-- всем, либо недоступна. Поэтому RLS включаем обязательно и описываем доступ.
--
-- Базовый принцип здесь: пользователь видит и редактирует ТОЛЬКО свой профиль.
-- Кросс-доступ (водитель видит имя клиента во время поездки и наоборот) мы
-- НЕ открываем политикой «читать всех» — это утечка персональных данных.
-- Позже это решим точечно: SECURITY DEFINER функцией, которая отдаёт лишь
-- нужные поля участникам активной поездки (домен rides).
-- ============================================================================

alter table public.profiles enable row level security;

-- Чтение своего профиля.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles
  for select
  using (auth.uid() = id);

-- Обновление своего профиля (имя, фото). И using, и with check — чтобы нельзя
-- было «увести» строку на чужой id.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Вставку обычно делает триггер handle_new_user (security definer, в обход RLS).
-- Эта политика — подстраховка на случай, если приложение создаёт профиль само:
-- разрешаем вставить строку только со своим id.
drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
  on public.profiles
  for insert
  with check (auth.uid() = id);

-- DELETE намеренно НЕ разрешаем: профиль удаляется каскадом при удалении
-- аккаунта в auth.users, а не запросом из клиента.


-- ===== [06] auth/rls/02_user_roles_rls.sql =====
-- ============================================================================
-- Домен auth · RLS для user_roles
-- ----------------------------------------------------------------------------
-- Самое важное правило безопасности всего домена:
--   пользователь может ЧИТАТЬ свои роли, но НЕ может их себе назначать.
--
-- Если бы мы дали клиенту INSERT/UPDATE/DELETE на user_roles, он смог бы выдать
-- себе любую роль. Поэтому здесь только SELECT своих строк. Назначение ролей —
-- через доверенный код:
--   • при регистрации — триггер handle_new_user (security definer);
--   • из бэкенда/админки — ключом service_role (он игнорирует RLS).
-- ============================================================================

alter table public.user_roles enable row level security;

-- Чтение только своих ролей (приложению нужно знать, кто ты: клиент/водитель).
drop policy if exists "user_roles_select_own" on public.user_roles;
create policy "user_roles_select_own"
  on public.user_roles
  for select
  using (auth.uid() = user_id);

-- INSERT / UPDATE / DELETE для роли authenticated НАМЕРЕННО отсутствуют.
-- Нет политики → действие запрещено. Изменения ролей идут только через
-- security definer функции или service_role.


-- ===== [07] rides/tables/00_enums.sql =====
-- ============================================================================
-- Домен rides · Типы (enum)
-- ----------------------------------------------------------------------------
-- Закрытые списки значений — через enum: защита от опечаток и компактность.
-- ============================================================================

-- Статус заказа (один на обе роли — это один и тот же объект).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'ride_status') then
    create type public.ride_status as enum (
      'searching',    -- ищем водителя (заказ создан, водителя нет)
      'accepted',     -- водитель принял, едет за клиентом
      'arrived',      -- водитель на месте, ждёт клиента
      'in_progress',  -- поездка идёт
      'completed',    -- завершена
      'cancelled',    -- отменена (клиентом или водителем)
      'expired'       -- никто не принял / таймаут
    );
  end if;
end$$;

-- Класс поездки (тариф).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'ride_class') then
    create type public.ride_class as enum ('econom', 'comfort', 'business');
  end if;
end$$;

-- Способ оплаты. В Абхазии по умолчанию наличные; карту закладываем на будущее.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'payment_method') then
    create type public.payment_method as enum ('cash', 'card');
  end if;
end$$;

-- Кто инициировал действие (для поля «кем отменён»).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'ride_actor') then
    create type public.ride_actor as enum ('client', 'driver', 'system');
  end if;
end$$;


-- ===== [08] rides/tables/01_rides.sql =====
-- ============================================================================
-- Домен rides · Таблица rides (заказ)
-- ============================================================================

create table if not exists public.rides (
  id              uuid primary key default gen_random_uuid(),

  -- Участники. client обязателен; driver появляется при принятии заказа.
  -- client удаляется каскадом со своими заказами; при удалении driver заказ
  -- остаётся (set null) — нужен в истории клиента и для отчётности.
  client_id       uuid not null references auth.users (id) on delete cascade,
  driver_id       uuid references auth.users (id) on delete set null,

  status          public.ride_status   not null default 'searching',
  ride_class      public.ride_class    not null,
  payment_method  public.payment_method not null default 'cash',

  -- Точка подачи («Моё местоположение»). Назначения — в ride_stops.
  pickup_address  text             not null,
  pickup_lat      double precision not null,
  pickup_lng      double precision not null,

  -- Оценка маршрута на момент заказа и итог по факту.
  distance_km     numeric(6, 1),
  duration_min    integer,
  price_estimated integer not null,          -- ₽, предварительно
  price_final     integer,                   -- ₽, по завершении

  -- Ожидание клиента: до этого времени бесплатно, дальше — платно.
  free_wait_until timestamptz,
  wait_charge     integer not null default 0,

  -- Отмена.
  cancelled_by    public.ride_actor,
  cancel_reason   text,

  -- Времена жизненного цикла (для истории и аналитики).
  created_at      timestamptz not null default now(),
  accepted_at     timestamptz,
  arrived_at      timestamptz,
  started_at      timestamptz,
  completed_at    timestamptz,
  cancelled_at    timestamptz,
  updated_at      timestamptz not null default now(),

  -- Инварианты, которые держим на уровне БД (а не надеемся на приложение):
  constraint rides_price_estimated_nonneg check (price_estimated >= 0),
  constraint rides_price_final_nonneg    check (price_final is null or price_final >= 0),
  constraint rides_distance_nonneg       check (distance_km is null or distance_km >= 0),
  -- Водитель обязателен на всех стадиях, кроме поиска/просрочки.
  constraint rides_driver_required check (
    driver_id is not null
    or status in ('searching', 'cancelled', 'expired')
  )
);

comment on table public.rides is 'Заказ такси: от создания до завершения и оценки.';
comment on column public.rides.free_wait_until is
  'До этого момента ожидание клиента бесплатное; позже включается платное.';

-- updated_at проставляет БД (функция из домена auth).
drop trigger if exists trg_rides_updated_at on public.rides;
create trigger trg_rides_updated_at
  before update on public.rides
  for each row execute function public.set_updated_at();


-- ===== [09] rides/tables/02_ride_stops.sql =====
-- ============================================================================
-- Домен rides · Таблица ride_stops (точки назначения)
-- ----------------------------------------------------------------------------
-- В приложении можно добавлять несколько адресов («+ адрес»). Поэтому назначения
-- — это не колонка, а отдельные строки, упорядоченные по position.
-- Почему отдельная таблица, а не массив/jsonb в rides:
--  • порядок и количество точек переменные;
--  • по точкам удобно строить запросы и проверять целостность (координаты).
-- ============================================================================

create table if not exists public.ride_stops (
  id         uuid primary key default gen_random_uuid(),
  ride_id    uuid not null references public.rides (id) on delete cascade,

  position   integer not null,          -- порядок: 1, 2, 3…
  address    text             not null,
  lat        double precision not null,
  lng        double precision not null,

  created_at timestamptz not null default now(),

  -- В рамках одного заказа порядковый номер уникален (нет двух «точек №1»).
  constraint ride_stops_position_positive check (position >= 1),
  constraint ride_stops_unique_position unique (ride_id, position)
);

comment on table public.ride_stops is
  'Точки назначения заказа по порядку (поддержка нескольких адресов).';


-- ===== [10] rides/tables/03_ride_ratings.sql =====
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


-- ===== [11] rides/indexes/01_rides_indexes.sql =====
-- ============================================================================
-- Домен rides · Индексы
-- ----------------------------------------------------------------------------
-- Уже проиндексировано автоматически:
--  • rides.id, ride_stops.id, ride_ratings.id — PRIMARY KEY;
--  • ride_stops(ride_id, position)            — UNIQUE;
--  • ride_ratings(ride_id, rater_id)          — UNIQUE.
-- ============================================================================

-- «Мои поездки» у клиента: история и активный заказ. Частый запрос.
create index if not exists idx_rides_client_id
  on public.rides (client_id, created_at desc);

-- «Мои поездки» у водителя.
create index if not exists idx_rides_driver_id
  on public.rides (driver_id, created_at desc);

-- Очередь свободных заявок для водителей: WHERE status = 'searching'.
-- Частичный индекс — только по нужным строкам: он маленький и быстрый, потому
-- что «searching» заказов в любой момент мало (большинство уже завершены).
create index if not exists idx_rides_searching
  on public.rides (created_at)
  where status = 'searching';

-- Точки конкретного заказа (по ride_id). UNIQUE(ride_id, position) тоже
-- покрывает это, но явный индекс по ride_id делает намерение очевидным
-- и помогает join'ам ride → stops.
create index if not exists idx_ride_stops_ride_id
  on public.ride_stops (ride_id);

-- Рейтинг водителя: «средняя оценка по ratee_id».
create index if not exists idx_ride_ratings_ratee_id
  on public.ride_ratings (ratee_id);


-- ===== [12] rides/rls/01_rides_rls.sql =====
-- ============================================================================
-- Домен rides · RLS для rides
-- ----------------------------------------------------------------------------
-- Принцип домена: ЧТЕНИЕ — через RLS по принадлежности; ЗАПИСЬ — через функции
-- (см. functions/). Поэтому здесь только политики SELECT. INSERT/UPDATE/DELETE
-- для обычных пользователей не открываем — иначе можно обойти переходы статуса.
-- ============================================================================

alter table public.rides enable row level security;

-- Кто может ВИДЕТЬ заказ:
--  • клиент — свой заказ;
--  • назначенный водитель — свой заказ;
--  • любой водитель — свободные заявки (status = 'searching'), чтобы их принять.
drop policy if exists "rides_select_participants_or_open" on public.rides;
create policy "rides_select_participants_or_open"
  on public.rides
  for select
  using (
    auth.uid() = client_id
    or auth.uid() = driver_id
    or (status = 'searching' and public.has_role(auth.uid(), 'driver'))
  );

-- INSERT/UPDATE/DELETE намеренно отсутствуют:
--  • создание заказа     → функция request_ride;
--  • переходы статуса    → accept_ride / driver_arrived / start_ride / complete_ride;
--  • отмена              → cancel_ride.
-- Все они SECURITY DEFINER и проверяют роль + допустимость перехода.


-- ===== [13] rides/rls/02_ride_stops_rls.sql =====
-- ============================================================================
-- Домен rides · RLS для ride_stops
-- ----------------------------------------------------------------------------
-- Точки видны тем же, кому виден сам заказ. Переиспользуем правило доступа к
-- rides через подзапрос: «есть ли заказ-родитель, который мне виден».
-- Записываются точки только функцией request_ride (вместе с заказом).
-- ============================================================================

alter table public.ride_stops enable row level security;

drop policy if exists "ride_stops_select_via_ride" on public.ride_stops;
create policy "ride_stops_select_via_ride"
  on public.ride_stops
  for select
  using (
    exists (
      select 1
      from public.rides r
      where r.id = ride_stops.ride_id
        and (
          auth.uid() = r.client_id
          or auth.uid() = r.driver_id
          or (r.status = 'searching' and public.has_role(auth.uid(), 'driver'))
        )
    )
  );

-- Запись (INSERT) — только через request_ride (SECURITY DEFINER). Прямой записи
-- клиенту не даём: иначе можно дописать точки в чужой/уже завершённый заказ.


-- ===== [14] rides/rls/03_ride_ratings_rls.sql =====
-- ============================================================================
-- Домен rides · RLS для ride_ratings
-- ----------------------------------------------------------------------------
-- Оценки видны участникам поездки. Создаются через функцию rate_ride, которая
-- проверяет, что поездка завершена и оценивающий — её участник.
-- ============================================================================

alter table public.ride_ratings enable row level security;

drop policy if exists "ride_ratings_select_via_ride" on public.ride_ratings;
create policy "ride_ratings_select_via_ride"
  on public.ride_ratings
  for select
  using (
    auth.uid() = rater_id
    or auth.uid() = ratee_id
  );

-- INSERT — только через rate_ride (SECURITY DEFINER), чтобы гарантировать:
--  • поездка существует и завершена;
--  • оценивающий действительно её участник;
--  • он не ставит оценку «за другого».


-- ===== [15] rides/functions/01_request_ride.sql =====
-- ============================================================================
-- Домен rides · Функция request_ride (создать заказ)
-- ----------------------------------------------------------------------------
-- Создаёт заказ и его точки назначения ОДНОЙ транзакцией. Если что-то упадёт —
-- не останется «полузаказа» без точек. Поэтому это функция, а не два INSERT'а
-- из приложения через RLS.
--
-- Роль 'client' здесь НЕ требуем: заказать такси может любой авторизованный
-- пользователь (в т.ч. водитель как пассажир). Ограничения по ролям важны на
-- стороне ВОДИТЕЛЯ (принять заказ может только driver) — см. 02_ride_lifecycle.
-- ============================================================================

create or replace function public.request_ride(
  p_ride_class      public.ride_class,
  p_payment_method  public.payment_method,
  p_pickup_address  text,
  p_pickup_lat      double precision,
  p_pickup_lng      double precision,
  p_distance_km     numeric,
  p_duration_min    integer,
  p_price_estimated integer,
  p_stops           jsonb              -- [{"address":..,"lat":..,"lng":..}, ...]
)
returns public.rides
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_stops is null or jsonb_array_length(p_stops) < 1 then
    raise exception 'at least one destination required';
  end if;

  insert into public.rides (
    client_id, status, ride_class, payment_method,
    pickup_address, pickup_lat, pickup_lng,
    distance_km, duration_min, price_estimated
  ) values (
    v_uid, 'searching', p_ride_class, p_payment_method,
    p_pickup_address, p_pickup_lat, p_pickup_lng,
    p_distance_km, p_duration_min, p_price_estimated
  )
  returning * into v_ride;

  insert into public.ride_stops (ride_id, position, address, lat, lng)
  select v_ride.id,
         ord::int,
         elem ->> 'address',
         (elem ->> 'lat')::double precision,
         (elem ->> 'lng')::double precision
  from jsonb_array_elements(p_stops) with ordinality as s(elem, ord);

  return v_ride;
end;
$$;

-- По умолчанию EXECUTE есть у PUBLIC — сужаем до авторизованных.
-- Сигнатура — все 9 типов параметров по порядку (два integer подряд:
-- duration_min и price_estimated).
revoke all on function public.request_ride(
  public.ride_class, public.payment_method, text,
  double precision, double precision, numeric, integer, integer, jsonb
) from public;
grant execute on function public.request_ride(
  public.ride_class, public.payment_method, text,
  double precision, double precision, numeric, integer, integer, jsonb
) to authenticated;


-- ===== [16] rides/functions/02_ride_lifecycle.sql =====
-- ============================================================================
-- Домен rides · Переходы статуса заказа
-- ----------------------------------------------------------------------------
-- Каждая функция:
--  • проверяет, кто вызывает (auth.uid()) и его право;
--  • меняет статус ТОЛЬКО из допустимого предыдущего (через WHERE status = …);
--  • ставит соответствующее время.
-- Если перехода нет (заказ уже принят/отменён/чужой) — UPDATE не находит строку,
-- и мы кидаем понятную ошибку. Так состояние нельзя «перескочить».
-- ============================================================================

-- accept: searching → accepted. Принять может только АКТИВНЫЙ водитель
-- (проверенный + на линии). Функция is_active_driver определяется в домене
-- drivers, поэтому drivers применяется после rides. Гейт стоит именно здесь:
-- видеть свободные заявки RLS разрешает любому водителю, а вот принять —
-- только прошедшему модерацию.
create or replace function public.accept_ride(p_ride_id uuid)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if not public.is_active_driver(v_uid) then
    raise exception 'driver is not approved or not online';
  end if;

  update public.rides
     set driver_id = v_uid, status = 'accepted', accepted_at = now()
   where id = p_ride_id and status = 'searching' and driver_id is null
  returning * into v_ride;

  if v_ride.id is null then
    raise exception 'ride is no longer available';
  end if;
  return v_ride;
end;
$$;

-- arrived: accepted → arrived (назначенный водитель). Включает 4 мин бесплатного
-- ожидания: дальше начисляется платное ожидание.
create or replace function public.driver_arrived(p_ride_id uuid)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.rides
     set status = 'arrived',
         arrived_at = now(),
         free_wait_until = now() + interval '4 minutes'
   where id = p_ride_id and driver_id = v_uid and status = 'accepted'
  returning * into v_ride;

  if v_ride.id is null then raise exception 'invalid transition'; end if;
  return v_ride;
end;
$$;

-- start: arrived → in_progress (назначенный водитель).
create or replace function public.start_ride(p_ride_id uuid)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.rides
     set status = 'in_progress', started_at = now()
   where id = p_ride_id and driver_id = v_uid and status = 'arrived'
  returning * into v_ride;

  if v_ride.id is null then raise exception 'invalid transition'; end if;
  return v_ride;
end;
$$;

-- complete: in_progress → completed (назначенный водитель). Если итоговая цена
-- не передана — берём предварительную плюс платное ожидание.
create or replace function public.complete_ride(
  p_ride_id uuid,
  p_price_final integer default null
)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.rides
     set status = 'completed',
         completed_at = now(),
         price_final = coalesce(p_price_final, price_estimated + wait_charge)
   where id = p_ride_id and driver_id = v_uid and status = 'in_progress'
  returning * into v_ride;

  if v_ride.id is null then raise exception 'invalid transition'; end if;
  return v_ride;
end;
$$;

-- cancel: searching/accepted/arrived → cancelled (клиент или водитель заказа).
create or replace function public.cancel_ride(
  p_ride_id uuid,
  p_reason  text default null
)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.rides
     set status = 'cancelled',
         cancelled_at = now(),
         cancel_reason = p_reason,
         cancelled_by = case
           when client_id = v_uid then 'client'::public.ride_actor
           when driver_id = v_uid then 'driver'::public.ride_actor
         end
   where id = p_ride_id
     and (client_id = v_uid or driver_id = v_uid)
     and status in ('searching', 'accepted', 'arrived')
  returning * into v_ride;

  if v_ride.id is null then raise exception 'cannot cancel this ride'; end if;
  return v_ride;
end;
$$;

-- Доступ: только авторизованным.
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.accept_ride(uuid)',
    'public.driver_arrived(uuid)',
    'public.start_ride(uuid)',
    'public.complete_ride(uuid, integer)',
    'public.cancel_ride(uuid, text)'
  ] loop
    execute format('revoke all on function %s from public;', fn);
    execute format('grant execute on function %s to authenticated;', fn);
  end loop;
end$$;


-- ===== [17] rides/functions/03_rate_ride.sql =====
-- ============================================================================
-- Домен rides · Функция rate_ride (оценить поездку)
-- ----------------------------------------------------------------------------
-- Гарантирует то, что RLS-вставкой нормально не выразить:
--  • поездка существует и ЗАВЕРШЕНА;
--  • оценивающий — её участник;
--  • оценивают вторую сторону (клиент → водитель или наоборот);
--  • повтор не пройдёт (UNIQUE(ride_id, rater_id)), диапазон звёзд (CHECK 1..5).
-- ============================================================================

create or replace function public.rate_ride(
  p_ride_id uuid,
  p_stars   integer,
  p_comment text   default null,
  p_tags    text[] default '{}'
)
returns public.ride_ratings
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_ride   public.rides;
  v_ratee  uuid;
  v_rating public.ride_ratings;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select * into v_ride from public.rides where id = p_ride_id;
  if v_ride.id is null then raise exception 'ride not found'; end if;
  if v_ride.status <> 'completed' then raise exception 'ride is not completed'; end if;
  if v_uid <> v_ride.client_id and v_uid <> v_ride.driver_id then
    raise exception 'not a participant of this ride';
  end if;

  -- Оцениваем вторую сторону.
  v_ratee := case
    when v_uid = v_ride.client_id then v_ride.driver_id
    else v_ride.client_id
  end;
  if v_ratee is null then raise exception 'no counterpart to rate'; end if;

  insert into public.ride_ratings (ride_id, rater_id, ratee_id, stars, comment, tags)
  values (p_ride_id, v_uid, v_ratee, p_stars, p_comment, coalesce(p_tags, '{}'))
  returning * into v_rating;

  return v_rating;
end;
$$;

revoke all on function public.rate_ride(uuid, integer, text, text[]) from public;
grant execute on function public.rate_ride(uuid, integer, text, text[]) to authenticated;


-- ===== [18] drivers/tables/00_enums.sql =====
-- ============================================================================
-- Домен drivers · Типы (enum)
-- ============================================================================

-- Статус проверки. Используется и для водителя в целом, и для каждого документа.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'verification_status') then
    create type public.verification_status as enum ('pending', 'approved', 'rejected');
  end if;
end$$;

-- Типы документов, которые водитель загружает на проверку.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'document_type') then
    create type public.document_type as enum (
      'license',              -- водительское удостоверение
      'selfie',               -- селфи для верификации личности
      'passport',             -- паспорт
      'vehicle_registration'  -- свидетельство о регистрации авто
    );
  end if;
end$$;


-- ===== [19] drivers/tables/01_driver_profiles.sql =====
-- ============================================================================
-- Домен drivers · Таблица driver_profiles
-- ----------------------------------------------------------------------------
-- 1:1 к auth.users — но существует только у тех, кто прошёл анкету водителя.
-- Создаётся функцией save_driver_profile (см. functions/), не триггером auth,
-- потому что появляется не при регистрации, а при заполнении анкеты.
-- ============================================================================

create table if not exists public.driver_profiles (
  id              uuid primary key references auth.users (id) on delete cascade,

  -- Анкета (шаг «Личные данные»).
  first_name      text,
  last_name       text,
  birth_date      date,
  city            text,
  photo_url       text,

  -- Документ-удостоверение (шаг «Документы»). Файлы — в driver_documents.
  license_number  text,
  license_expiry  date,

  -- Проверка.
  status          public.verification_status not null default 'pending',
  rejection_reason text,
  approved_at     timestamptz,

  -- Доступность.
  is_online       boolean not null default false,

  -- Агрегаты (денормализация ради скорости; считаются триггерами).
  rating_avg      numeric(3, 2) not null default 5.00,
  rating_count    integer       not null default 0,
  trips_count     integer       not null default 0,
  balance         integer       not null default 0,   -- ₽ к выводу

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint driver_balance_nonneg check (balance >= 0),
  constraint driver_rating_range  check (rating_avg between 0 and 5)
);

comment on table public.driver_profiles is
  'Профиль водителя: анкета, статус проверки, рейтинг, баланс, онлайн.';

drop trigger if exists trg_driver_profiles_updated_at on public.driver_profiles;
create trigger trg_driver_profiles_updated_at
  before update on public.driver_profiles
  for each row execute function public.set_updated_at();


-- ===== [20] drivers/tables/02_driver_vehicles.sql =====
-- ============================================================================
-- Домен drivers · Таблица driver_vehicles (автомобили)
-- ----------------------------------------------------------------------------
-- Отдельная таблица, а не колонки в driver_profiles: машина может меняться,
-- и удобно хранить историю. В каждый момент активна одна машина.
-- ============================================================================

create table if not exists public.driver_vehicles (
  id         uuid primary key default gen_random_uuid(),
  driver_id  uuid not null references auth.users (id) on delete cascade,

  brand      text not null,
  model      text not null,
  year       integer,
  color      text,
  plate      text not null,        -- госномер
  photo_url  text,

  is_active  boolean not null default true,
  created_at timestamptz not null default now(),

  constraint vehicle_year_sane check (year is null or year between 1950 and 2100)
);

comment on table public.driver_vehicles is 'Автомобили водителя (активна одна).';

-- Ровно одна активная машина на водителя. Частичный уникальный индекс — самый
-- чистый способ выразить «не более одной строки с is_active = true на driver_id».
create unique index if not exists uq_driver_active_vehicle
  on public.driver_vehicles (driver_id)
  where is_active;


-- ===== [21] drivers/tables/03_driver_documents.sql =====
-- ============================================================================
-- Домен drivers · Таблица driver_documents (документы на проверку)
-- ----------------------------------------------------------------------------
-- Каждый документ — со своим статусом, чтобы модератор мог принять одни и
-- отклонить другие. Сами файлы лежат в Supabase Storage, здесь — только ссылки.
-- ============================================================================

create table if not exists public.driver_documents (
  id         uuid primary key default gen_random_uuid(),
  driver_id  uuid not null references auth.users (id) on delete cascade,

  type       public.document_type       not null,
  file_url   text                       not null,
  status     public.verification_status not null default 'pending',

  created_at timestamptz not null default now(),

  -- Один актуальный документ каждого типа на водителя (повторная загрузка
  -- заменяет прежний — см. add_driver_document с ON CONFLICT).
  constraint driver_documents_unique_type unique (driver_id, type)
);

comment on table public.driver_documents is
  'Документы водителя (ссылки на файлы в Storage) со статусом проверки.';


-- ===== [22] drivers/tables/04_driver_aggregates.sql =====
-- ============================================================================
-- Домен drivers · Агрегаты (триггеры)
-- ----------------------------------------------------------------------------
-- Денормализованные поля driver_profiles (rating_avg/count, trips_count, balance)
-- пересчитываются автоматически при изменении фактов в домене rides.
-- Триггерные функции — SECURITY DEFINER, чтобы обновлять driver_profiles в обход
-- RLS (RLS не разрешает обычному пользователю писать в чужой/свой профиль напрямую).
-- ============================================================================

-- 1) Новая оценка → пересчёт рейтинга водителя.
-- Если оцениваемый не водитель (нет строки в driver_profiles) — UPDATE просто
-- затронет 0 строк, и это нормально.
create or replace function public.recalc_driver_rating()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.driver_profiles d
     set rating_count = agg.cnt,
         rating_avg   = round(agg.avg_stars, 2)
  from (
    select count(*)::int as cnt, avg(stars)::numeric as avg_stars
    from public.ride_ratings
    where ratee_id = new.ratee_id
  ) agg
  where d.id = new.ratee_id;
  return new;
end;
$$;

drop trigger if exists trg_recalc_driver_rating on public.ride_ratings;
create trigger trg_recalc_driver_rating
  after insert on public.ride_ratings
  for each row execute function public.recalc_driver_rating();

-- 2) Поездка завершена → +1 к поездкам и +цена к балансу.
-- Срабатывает строго на переходе в 'completed' (а не на любом UPDATE), чтобы
-- не начислить дважды.
create or replace function public.on_ride_completed()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'completed'
     and (old.status is distinct from 'completed')
     and new.driver_id is not null then
    update public.driver_profiles
       set trips_count = trips_count + 1,
           balance     = balance + coalesce(new.price_final, 0)
     where id = new.driver_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_on_ride_completed on public.rides;
create trigger trg_on_ride_completed
  after update on public.rides
  for each row execute function public.on_ride_completed();


-- ===== [23] drivers/indexes/01_drivers_indexes.sql =====
-- ============================================================================
-- Домен drivers · Индексы
-- ----------------------------------------------------------------------------
-- Уже проиндексировано: driver_profiles.id (PK), driver_vehicles.id (PK) и
-- частичный уникальный uq_driver_active_vehicle, driver_documents(driver_id,type)
-- (UNIQUE — покрывает поиск по driver_id).
-- ============================================================================

-- Очередь модерации: «показать всех на проверке».
create index if not exists idx_driver_profiles_status
  on public.driver_profiles (status);

-- Доступные водители (на линии и проверенные), отсортированные по рейтингу —
-- основа для матчинга «кому предложить заказ». Частичный индекс: строк мало.
create index if not exists idx_drivers_available
  on public.driver_profiles (rating_avg desc)
  where is_online and status = 'approved';

-- Все машины конкретного водителя (история).
create index if not exists idx_driver_vehicles_driver_id
  on public.driver_vehicles (driver_id);


-- ===== [24] drivers/rls/01_driver_profiles_rls.sql =====
-- ============================================================================
-- Домен drivers · RLS для driver_profiles
-- ----------------------------------------------------------------------------
-- Водитель видит ТОЛЬКО свой профиль. Запись — через функции (анкета ставит
-- pending; статус меняет только review_driver под service_role). Прямого UPDATE
-- нет специально: иначе водитель мог бы сам поставить себе status='approved'.
-- Клиенту имя/рейтинг/авто водителя отдаёт функция driver_card (не прямой SELECT).
-- ============================================================================

alter table public.driver_profiles enable row level security;

drop policy if exists "driver_profiles_select_own" on public.driver_profiles;
create policy "driver_profiles_select_own"
  on public.driver_profiles
  for select
  using (auth.uid() = id);

-- INSERT/UPDATE/DELETE для authenticated отсутствуют (только функции / service_role).


-- ===== [25] drivers/rls/02_driver_vehicles_rls.sql =====
-- ============================================================================
-- Домен drivers · RLS для driver_vehicles
-- ----------------------------------------------------------------------------
-- Водитель видит свои машины. Запись — через set_driver_vehicle. Чужому клиенту
-- актуальная машина приходит в составе driver_card (функция).
-- ============================================================================

alter table public.driver_vehicles enable row level security;

drop policy if exists "driver_vehicles_select_own" on public.driver_vehicles;
create policy "driver_vehicles_select_own"
  on public.driver_vehicles
  for select
  using (auth.uid() = driver_id);


-- ===== [26] drivers/rls/03_driver_documents_rls.sql =====
-- ============================================================================
-- Домен drivers · RLS для driver_documents
-- ----------------------------------------------------------------------------
-- Документы — чувствительные данные. Их видит ТОЛЬКО владелец. Модератор читает
-- через service_role (обходит RLS). Запись — функцией add_driver_document.
-- ============================================================================

alter table public.driver_documents enable row level security;

drop policy if exists "driver_documents_select_own" on public.driver_documents;
create policy "driver_documents_select_own"
  on public.driver_documents
  for select
  using (auth.uid() = driver_id);


-- ===== [27] drivers/functions/01_driver_self.sql =====
-- ============================================================================
-- Домен drivers · Функции водителя (своя анкета и статус)
-- ============================================================================

-- is_active_driver: проверенный И на линии. Используется в accept_ride (rides).
create or replace function public.is_active_driver(p_user_id uuid)
returns boolean
language sql security definer stable set search_path = ''
as $$
  select exists (
    select 1 from public.driver_profiles d
    where d.id = p_user_id
      and d.status = 'approved'
      and d.is_online
  );
$$;

-- save_driver_profile: создать/обновить анкету. ЛЮБОЕ изменение анкеты ставит
-- status = 'pending' (нужна повторная модерация) — водитель не одобряет себя сам.
create or replace function public.save_driver_profile(
  p_first_name     text,
  p_last_name      text,
  p_birth_date     date,
  p_city           text,
  p_photo_url      text,
  p_license_number text,
  p_license_expiry date
)
returns public.driver_profiles
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_d   public.driver_profiles;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  insert into public.driver_profiles as d (
    id, first_name, last_name, birth_date, city, photo_url,
    license_number, license_expiry, status, approved_at, rejection_reason
  ) values (
    v_uid, p_first_name, p_last_name, p_birth_date, p_city, p_photo_url,
    p_license_number, p_license_expiry, 'pending', null, null
  )
  on conflict (id) do update set
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    birth_date = excluded.birth_date,
    city = excluded.city,
    photo_url = excluded.photo_url,
    license_number = excluded.license_number,
    license_expiry = excluded.license_expiry,
    status = 'pending',
    approved_at = null,
    rejection_reason = null
  returning * into v_d;

  return v_d;
end;
$$;

-- set_driver_vehicle: сделать переданную машину активной (прежнюю — неактивной).
create or replace function public.set_driver_vehicle(
  p_brand     text,
  p_model     text,
  p_year      integer,
  p_color     text,
  p_plate     text,
  p_photo_url text
)
returns public.driver_vehicles
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_v   public.driver_vehicles;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.driver_vehicles
     set is_active = false
   where driver_id = v_uid and is_active;

  insert into public.driver_vehicles (
    driver_id, brand, model, year, color, plate, photo_url, is_active
  ) values (
    v_uid, p_brand, p_model, p_year, p_color, p_plate, p_photo_url, true
  )
  returning * into v_v;

  return v_v;
end;
$$;

-- add_driver_document: загрузить/заменить документ (ставит pending).
create or replace function public.add_driver_document(
  p_type     public.document_type,
  p_file_url text
)
returns public.driver_documents
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_doc public.driver_documents;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  insert into public.driver_documents (driver_id, type, file_url, status)
  values (v_uid, p_type, p_file_url, 'pending')
  on conflict (driver_id, type) do update set
    file_url = excluded.file_url,
    status = 'pending'
  returning * into v_doc;

  return v_doc;
end;
$$;

-- set_driver_online: выйти/уйти с линии. На линию — только при status='approved'.
create or replace function public.set_driver_online(p_online boolean)
returns public.driver_profiles
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_d   public.driver_profiles;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  if p_online then
    update public.driver_profiles
       set is_online = true
     where id = v_uid and status = 'approved'
    returning * into v_d;
    if v_d.id is null then
      raise exception 'driver is not approved';
    end if;
  else
    update public.driver_profiles
       set is_online = false
     where id = v_uid
    returning * into v_d;
    if v_d.id is null then
      raise exception 'driver profile not found';
    end if;
  end if;

  return v_d;
end;
$$;

-- driver_card: безопасная публичная карточка водителя для показа клиенту
-- (имя, рейтинг, авто). Только по одобренному водителю. Отдаёт лишь то, что и
-- так видно клиенту во время поездки — без документов и контактов.
create or replace function public.driver_card(p_driver_id uuid)
returns jsonb
language sql security definer stable set search_path = ''
as $$
  select jsonb_build_object(
    'driver_id',   d.id,
    'full_name',   p.full_name,
    'rating_avg',  d.rating_avg,
    'rating_count',d.rating_count,
    'trips_count', d.trips_count,
    'vehicle', (
      select jsonb_build_object(
        'brand', v.brand, 'model', v.model, 'color', v.color, 'plate', v.plate
      )
      from public.driver_vehicles v
      where v.driver_id = d.id and v.is_active
      limit 1
    )
  )
  from public.driver_profiles d
  join public.profiles p on p.id = d.id
  where d.id = p_driver_id and d.status = 'approved';
$$;

-- Доступ: всё перечисленное — авторизованным.
do $$
declare fn text;
begin
  foreach fn in array array[
    'public.is_active_driver(uuid)',
    'public.save_driver_profile(text, text, date, text, text, text, date)',
    'public.set_driver_vehicle(text, text, integer, text, text, text)',
    'public.add_driver_document(public.document_type, text)',
    'public.set_driver_online(boolean)',
    'public.driver_card(uuid)'
  ] loop
    execute format('revoke all on function %s from public;', fn);
    execute format('grant execute on function %s to authenticated;', fn);
  end loop;
end$$;


-- ===== [28] drivers/functions/02_moderation.sql =====
-- ============================================================================
-- Домен drivers · Модерация (только для бэкенда/админки)
-- ----------------------------------------------------------------------------
-- review_driver одобряет или отклоняет водителя. НЕ выдаётся обычным
-- пользователям: право выполнять есть только у service_role (серверный ключ).
-- Так водитель никак не может сам себя одобрить.
-- ============================================================================

create or replace function public.review_driver(
  p_driver_id uuid,
  p_approved  boolean,
  p_reason    text default null
)
returns public.driver_profiles
language plpgsql security definer set search_path = ''
as $$
declare
  v_d public.driver_profiles;
begin
  update public.driver_profiles
     set status = case when p_approved
                       then 'approved'::public.verification_status
                       else 'rejected'::public.verification_status end,
         approved_at = case when p_approved then now() else null end,
         rejection_reason = case when p_approved then null else p_reason end,
         -- Отклонённого/снятого с проверки убираем с линии.
         is_online = case when p_approved then is_online else false end
   where id = p_driver_id
  returning * into v_d;

  if v_d.id is null then raise exception 'driver not found'; end if;
  return v_d;
end;
$$;

-- Никому из клиентских ролей не даём. Только серверный service_role.
revoke all on function public.review_driver(uuid, boolean, text) from public;
grant execute on function public.review_driver(uuid, boolean, text) to service_role;


-- ===== [29] chat/tables/01_chat_messages.sql =====
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


-- ===== [30] chat/indexes/01_chat_indexes.sql =====
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


-- ===== [31] chat/rls/01_chat_messages_rls.sql =====
-- ============================================================================
-- Домен chat · RLS для chat_messages
-- ----------------------------------------------------------------------------
-- Доступ берём из самого заказа: участник видит и пишет, остальные — нет.
-- ============================================================================

alter table public.chat_messages enable row level security;

-- Вспомогалка: я участник этой поездки?
-- (inline-подзапрос, чтобы не плодить функций; ride виден через RLS rides).
-- Читать сообщения может клиент или назначенный водитель поездки.
drop policy if exists "chat_select_participant" on public.chat_messages;
create policy "chat_select_participant"
  on public.chat_messages
  for select
  using (
    exists (
      select 1 from public.rides r
      where r.id = chat_messages.ride_id
        and (auth.uid() = r.client_id or auth.uid() = r.driver_id)
    )
  );

-- Писать: я отправитель (sender_id = я), я участник, и поездка АКТИВНА.
-- Это не переход состояния, а простая вставка — допускаем через RLS.
drop policy if exists "chat_insert_participant_active" on public.chat_messages;
create policy "chat_insert_participant_active"
  on public.chat_messages
  for insert
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.rides r
      where r.id = chat_messages.ride_id
        and (auth.uid() = r.client_id or auth.uid() = r.driver_id)
        and r.status in ('accepted', 'arrived', 'in_progress')
    )
  );

-- UPDATE/DELETE напрямую не разрешаем. Отметка о прочтении — функцией
-- mark_ride_messages_read (нельзя дать клиенту менять чужой текст/время).


-- ===== [32] chat/functions/01_mark_read.sql =====
-- ============================================================================
-- Домен chat · Функция mark_ride_messages_read
-- ----------------------------------------------------------------------------
-- Помечает прочитанными сообщения СОБЕСЕДНИКА в данной поездке. Свои сообщения
-- не трогаем. Доступно только участнику поездки.
-- ============================================================================

create or replace function public.mark_ride_messages_read(p_ride_id uuid)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cnt integer;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  -- Проверяем, что вызывающий — участник поездки.
  if not exists (
    select 1 from public.rides r
    where r.id = p_ride_id
      and (r.client_id = v_uid or r.driver_id = v_uid)
  ) then
    raise exception 'not a participant of this ride';
  end if;

  update public.chat_messages
     set read_at = now()
   where ride_id = p_ride_id
     and sender_id <> v_uid     -- только сообщения собеседника
     and read_at is null;

  get diagnostics v_cnt = row_count;
  return v_cnt;  -- сколько отметили прочитанными
end;
$$;

revoke all on function public.mark_ride_messages_read(uuid) from public;
grant execute on function public.mark_ride_messages_read(uuid) to authenticated;


-- ===== [33] loyalty/tables/00_enums.sql =====
-- ============================================================================
-- Домен loyalty · Типы (enum)
-- ============================================================================

-- За что начислены/списаны мили.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'loyalty_reason') then
    create type public.loyalty_reason as enum (
      'trip',          -- за завершённую поездку
      'rating',        -- за оценку поездки
      'referral',      -- за приглашённого друга
      'signup_bonus',  -- бонус за регистрацию
      'redemption',    -- списание при обмене на награду
      'adjustment'     -- ручная корректировка (поддержка/админ)
    );
  end if;
end$$;

-- Вид награды.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'reward_kind') then
    create type public.reward_kind as enum ('discount', 'free_ride', 'upgrade');
  end if;
end$$;

-- Статус обмена.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'redemption_status') then
    create type public.redemption_status as enum ('active', 'used', 'expired');
  end if;
end$$;


-- ===== [34] loyalty/tables/01_accounts_and_transactions.sql =====
-- ============================================================================
-- Домен loyalty · Счета и журнал транзакций
-- ============================================================================

-- Счёт лояльности 1:1 к пользователю.
create table if not exists public.loyalty_accounts (
  user_id         uuid primary key references auth.users (id) on delete cascade,
  balance         integer not null default 0,   -- текущие мили
  lifetime_earned integer not null default 0,    -- начислено за всё время (для уровня)
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint loyalty_balance_nonneg check (balance >= 0)
);

comment on table public.loyalty_accounts is 'Счёт миль пользователя.';

drop trigger if exists trg_loyalty_accounts_updated_at on public.loyalty_accounts;
create trigger trg_loyalty_accounts_updated_at
  before update on public.loyalty_accounts
  for each row execute function public.set_updated_at();

-- Журнал — источник истины. Баланс считается из него.
create table if not exists public.loyalty_transactions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  amount     integer not null,              -- +начисление / −списание (не 0)
  reason     public.loyalty_reason not null,
  ride_id    uuid references public.rides (id) on delete set null,
  note       text,
  created_at timestamptz not null default now(),

  constraint loyalty_amount_nonzero check (amount <> 0)
);

comment on table public.loyalty_transactions is
  'Журнал начислений/списаний миль. Источник истины по балансу.';

-- ----------------------------------------------------------------------------
-- Триггер: запись в журнал → пересчёт счёта.
-- balance += amount; при начислении (amount > 0) растёт и lifetime_earned.
-- Если счёта ещё нет — создаём. Если баланс ушёл бы в минус — CHECK на
-- loyalty_accounts откатит транзакцию (защита от списания «в долг»).
-- security definer: триггер пишет в счёт в обход RLS.
-- ----------------------------------------------------------------------------
create or replace function public.apply_loyalty_transaction()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.loyalty_accounts (user_id, balance, lifetime_earned)
  values (
    new.user_id,
    new.amount,
    greatest(new.amount, 0)
  )
  on conflict (user_id) do update set
    balance = public.loyalty_accounts.balance + new.amount,
    lifetime_earned = public.loyalty_accounts.lifetime_earned
                      + greatest(new.amount, 0);
  return new;
end;
$$;

drop trigger if exists trg_apply_loyalty_transaction on public.loyalty_transactions;
create trigger trg_apply_loyalty_transaction
  after insert on public.loyalty_transactions
  for each row execute function public.apply_loyalty_transaction();

-- ----------------------------------------------------------------------------
-- Автосоздание счёта при появлении профиля (чтобы у каждого клиента был счёт).
-- ----------------------------------------------------------------------------
create or replace function public.create_loyalty_account()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.loyalty_accounts (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_create_loyalty_account on public.profiles;
create trigger trg_create_loyalty_account
  after insert on public.profiles
  for each row execute function public.create_loyalty_account();


-- ===== [35] loyalty/tables/02_rewards_and_redemptions.sql =====
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


-- ===== [36] loyalty/tables/03_earn_on_ride.sql =====
-- ============================================================================
-- Домен loyalty · Начисление миль за поездку
-- ----------------------------------------------------------------------------
-- Поездка стала 'completed' → клиенту начисляем мили (1 миля за 10 ₽).
-- Делаем это записью в журнал loyalty_transactions — баланс обновит триггер
-- apply_loyalty_transaction. Срабатывает строго на переходе в completed.
-- ============================================================================

create or replace function public.earn_miles_on_ride()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_miles integer;
begin
  if new.status = 'completed'
     and (old.status is distinct from 'completed')
     and new.client_id is not null then

    v_miles := floor(coalesce(new.price_final, new.price_estimated) / 10.0);

    if v_miles > 0 then
      insert into public.loyalty_transactions (user_id, amount, reason, ride_id)
      values (new.client_id, v_miles, 'trip', new.id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_earn_miles_on_ride on public.rides;
create trigger trg_earn_miles_on_ride
  after update on public.rides
  for each row execute function public.earn_miles_on_ride();


-- ===== [37] loyalty/indexes/01_loyalty_indexes.sql =====
-- ============================================================================
-- Домен loyalty · Индексы
-- ----------------------------------------------------------------------------
-- Уже есть: loyalty_accounts.user_id (PK), loyalty_rewards.id (PK) + code (UNIQUE),
-- loyalty_redemptions.id (PK).
-- ============================================================================

-- История транзакций пользователя (экран «Мили» — лента начислений/списаний).
create index if not exists idx_loyalty_tx_user
  on public.loyalty_transactions (user_id, created_at desc);

-- История обменов пользователя.
create index if not exists idx_loyalty_redemptions_user
  on public.loyalty_redemptions (user_id, created_at desc);

-- Активный каталог наград.
create index if not exists idx_loyalty_rewards_active
  on public.loyalty_rewards (cost)
  where is_active;


-- ===== [38] loyalty/rls/01_loyalty_rls.sql =====
-- ============================================================================
-- Домен loyalty · RLS
-- ----------------------------------------------------------------------------
-- Свой счёт/транзакции/обмены — только владельцу. Каталог — всем авторизованным.
-- Любая запись миль — через триггеры/функции/service_role, не прямым запросом.
-- ============================================================================

-- Счёт лояльности: только свой, только чтение.
alter table public.loyalty_accounts enable row level security;
drop policy if exists "loyalty_accounts_select_own" on public.loyalty_accounts;
create policy "loyalty_accounts_select_own"
  on public.loyalty_accounts
  for select
  using (auth.uid() = user_id);

-- Транзакции: только свои, только чтение. Вставка — триггерами/функциями.
alter table public.loyalty_transactions enable row level security;
drop policy if exists "loyalty_tx_select_own" on public.loyalty_transactions;
create policy "loyalty_tx_select_own"
  on public.loyalty_transactions
  for select
  using (auth.uid() = user_id);

-- Каталог наград: читают все авторизованные (это публичный список).
alter table public.loyalty_rewards enable row level security;
drop policy if exists "loyalty_rewards_select_all" on public.loyalty_rewards;
create policy "loyalty_rewards_select_all"
  on public.loyalty_rewards
  for select
  to authenticated
  using (true);

-- Обмены: только свои, только чтение. Создание — функцией redeem_reward.
alter table public.loyalty_redemptions enable row level security;
drop policy if exists "loyalty_redemptions_select_own" on public.loyalty_redemptions;
create policy "loyalty_redemptions_select_own"
  on public.loyalty_redemptions
  for select
  using (auth.uid() = user_id);


-- ===== [39] loyalty/functions/01_redeem_reward.sql =====
-- ============================================================================
-- Домен loyalty · Функция redeem_reward (обменять мили на награду)
-- ----------------------------------------------------------------------------
-- Списание идёт через журнал: вставляем отрицательную транзакцию и запись
-- обмена. Баланс уменьшит триггер apply_loyalty_transaction; уйти в минус не
-- даст CHECK (balance >= 0). Цену награды фиксируем на момент обмена.
-- ============================================================================

create or replace function public.redeem_reward(p_reward_id uuid)
returns public.loyalty_redemptions
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_reward  public.loyalty_rewards;
  v_balance integer;
  v_red     public.loyalty_redemptions;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select * into v_reward
  from public.loyalty_rewards
  where id = p_reward_id and is_active;
  if v_reward.id is null then raise exception 'reward not available'; end if;

  -- Текущий баланс (со счёта). Если счёта нет — считаем 0.
  select coalesce(balance, 0) into v_balance
  from public.loyalty_accounts where user_id = v_uid;

  if coalesce(v_balance, 0) < v_reward.cost then
    raise exception 'not enough miles';
  end if;

  -- Списание милей (журнал → баланс обновит триггер).
  insert into public.loyalty_transactions (user_id, amount, reason, note)
  values (v_uid, -v_reward.cost, 'redemption', v_reward.code);

  -- Запись обмена.
  insert into public.loyalty_redemptions (user_id, reward_id, cost, status)
  values (v_uid, v_reward.id, v_reward.cost, 'active')
  returning * into v_red;

  return v_red;
end;
$$;

revoke all on function public.redeem_reward(uuid) from public;
grant execute on function public.redeem_reward(uuid) to authenticated;


-- ===== [40] loyalty/functions/02_loyalty_tier.sql =====
-- ============================================================================
-- Домен loyalty · Функция loyalty_tier (уровень по сумме начисленного)
-- ----------------------------------------------------------------------------
-- Уровень — производное от lifetime_earned, поэтому не храним его, а вычисляем.
-- Так нечему рассинхронизироваться. Пороги можно менять в одном месте.
-- ============================================================================

create or replace function public.loyalty_tier(p_user_id uuid)
returns text
language sql stable security definer set search_path = ''
as $$
  select case
    when coalesce(a.lifetime_earned, 0) >= 5000 then 'Платина'
    when coalesce(a.lifetime_earned, 0) >= 2000 then 'Золото'
    when coalesce(a.lifetime_earned, 0) >= 1000 then 'Серебро'
    else 'Бронза'
  end
  from public.loyalty_accounts a
  where a.user_id = p_user_id
  -- если счёта нет — вернётся NULL; приложение покажет «Бронза» по умолчанию.
$$;

revoke all on function public.loyalty_tier(uuid) from public;
grant execute on function public.loyalty_tier(uuid) to authenticated;


-- ===== [41] places/tables/00_enums.sql =====
-- ============================================================================
-- Домен places · Типы (enum)
-- ============================================================================

-- Тип сохранённого адреса. home/work — особые слоты (по одному), other — любые.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'place_kind') then
    create type public.place_kind as enum ('home', 'work', 'other');
  end if;
end$$;


-- ===== [42] places/tables/01_saved_places.sql =====
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


-- ===== [43] places/tables/02_recent_places.sql =====
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


-- ===== [44] places/indexes/01_places_indexes.sql =====
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


-- ===== [45] places/rls/01_places_rls.sql =====
-- ============================================================================
-- Домен places · RLS
-- ----------------------------------------------------------------------------
-- Личные данные без машины состояний → даём пользователю ПОЛНЫЙ CRUD по своим
-- строкам прямо через RLS. Это и есть случай, когда функции не нужны.
--
-- В политиках:
--  • using (...)     — какие строки видит/трогает (только свои);
--  • with check (...) — что разрешено вставить/получить после изменения
--                       (нельзя записать строку на чужой user_id).
-- ============================================================================

-- ---- saved_places ----
alter table public.saved_places enable row level security;

drop policy if exists "saved_places_select_own" on public.saved_places;
create policy "saved_places_select_own"
  on public.saved_places for select
  using (auth.uid() = user_id);

drop policy if exists "saved_places_insert_own" on public.saved_places;
create policy "saved_places_insert_own"
  on public.saved_places for insert
  with check (auth.uid() = user_id);

drop policy if exists "saved_places_update_own" on public.saved_places;
create policy "saved_places_update_own"
  on public.saved_places for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "saved_places_delete_own" on public.saved_places;
create policy "saved_places_delete_own"
  on public.saved_places for delete
  using (auth.uid() = user_id);

-- ---- recent_places ----
alter table public.recent_places enable row level security;

drop policy if exists "recent_places_select_own" on public.recent_places;
create policy "recent_places_select_own"
  on public.recent_places for select
  using (auth.uid() = user_id);

drop policy if exists "recent_places_insert_own" on public.recent_places;
create policy "recent_places_insert_own"
  on public.recent_places for insert
  with check (auth.uid() = user_id);

drop policy if exists "recent_places_update_own" on public.recent_places;
create policy "recent_places_update_own"
  on public.recent_places for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "recent_places_delete_own" on public.recent_places;
create policy "recent_places_delete_own"
  on public.recent_places for delete
  using (auth.uid() = user_id);


-- ===== [46] notifications/tables/00_enums.sql =====
-- ============================================================================
-- Домен notifications · Типы (enum)
-- ============================================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'notification_type') then
    create type public.notification_type as enum (
      'ride_update',  -- смена статуса поездки
      'new_order',    -- новый заказ для водителя
      'promo',        -- акции/мили
      'system'        -- системное
    );
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'device_platform') then
    create type public.device_platform as enum ('ios', 'android', 'web');
  end if;
end$$;


-- ===== [47] notifications/tables/01_notifications.sql =====
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


-- ===== [48] notifications/tables/02_push_devices.sql =====
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


-- ===== [49] notifications/tables/03_ride_notifications.sql =====
-- ============================================================================
-- Домен notifications · Уведомления по смене статуса поездки (триггер)
-- ----------------------------------------------------------------------------
-- На каждый переход статуса заказа кладём уведомление нужному участнику.
-- security definer: пишем в notifications в обход RLS (создаёт система).
-- ============================================================================

create or replace function public.notify_on_ride_status()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_user  uuid;
  v_title text;
  v_body  text;
begin
  -- Интересует только реальная смена статуса.
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'accepted' then
    v_user := new.client_id;
    v_title := 'Водитель найден';
    v_body := 'Водитель принял заказ и едет к вам';
  elsif new.status = 'arrived' then
    v_user := new.client_id;
    v_title := 'Водитель ждёт вас';
    v_body := 'Машина на месте — выходите';
  elsif new.status = 'in_progress' then
    v_user := new.client_id;
    v_title := 'Поездка началась';
  elsif new.status = 'completed' then
    v_user := new.client_id;
    v_title := 'Поездка завершена';
    v_body := 'Оцените поездку';
  elsif new.status = 'cancelled' then
    -- Уведомляем вторую сторону.
    if new.cancelled_by = 'client' then
      v_user := new.driver_id;
      v_title := 'Заказ отменён клиентом';
    else
      v_user := new.client_id;
      v_title := 'Поездка отменена';
    end if;
  else
    return new;
  end if;

  if v_user is not null then
    insert into public.notifications (user_id, type, title, body, ride_id)
    values (v_user, 'ride_update', v_title, v_body, new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_on_ride_status on public.rides;
create trigger trg_notify_on_ride_status
  after update on public.rides
  for each row execute function public.notify_on_ride_status();


-- ===== [50] notifications/indexes/01_notifications_indexes.sql =====
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


-- ===== [51] notifications/rls/01_notifications_rls.sql =====
-- ============================================================================
-- Домен notifications · RLS для notifications
-- ----------------------------------------------------------------------------
-- Пользователь только ЧИТАЕТ свои уведомления. Создаёт их система (триггеры /
-- service_role), отметку о прочтении ставит функция mark_notifications_read.
-- ============================================================================

alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
  on public.notifications
  for select
  using (auth.uid() = user_id);

-- INSERT/UPDATE/DELETE для authenticated отсутствуют намеренно.


-- ===== [52] notifications/rls/02_push_devices_rls.sql =====
-- ============================================================================
-- Домен notifications · RLS для push_devices
-- ----------------------------------------------------------------------------
-- Токены устройств — «свои данные»: пользователь регистрирует/обновляет/удаляет
-- их сам → полный CRUD по своим строкам через RLS.
-- ============================================================================

alter table public.push_devices enable row level security;

drop policy if exists "push_devices_select_own" on public.push_devices;
create policy "push_devices_select_own"
  on public.push_devices for select
  using (auth.uid() = user_id);

drop policy if exists "push_devices_insert_own" on public.push_devices;
create policy "push_devices_insert_own"
  on public.push_devices for insert
  with check (auth.uid() = user_id);

drop policy if exists "push_devices_update_own" on public.push_devices;
create policy "push_devices_update_own"
  on public.push_devices for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "push_devices_delete_own" on public.push_devices;
create policy "push_devices_delete_own"
  on public.push_devices for delete
  using (auth.uid() = user_id);


-- ===== [53] notifications/functions/01_create_notification.sql =====
-- ============================================================================
-- Домен notifications · Функция create_notification (для бэкенда)
-- ----------------------------------------------------------------------------
-- Программное создание уведомления из доверенного кода (service_role).
-- Клиентским ролям не выдаётся — иначе можно слать уведомления кому угодно.
-- ============================================================================

create or replace function public.create_notification(
  p_user_id uuid,
  p_type    public.notification_type,
  p_title   text,
  p_body    text  default null,
  p_ride_id uuid  default null,
  p_data    jsonb default '{}'
)
returns public.notifications
language plpgsql security definer set search_path = ''
as $$
declare
  v_n public.notifications;
begin
  insert into public.notifications (user_id, type, title, body, ride_id, data)
  values (p_user_id, p_type, p_title, p_body, p_ride_id, coalesce(p_data, '{}'))
  returning * into v_n;
  return v_n;
end;
$$;

revoke all on function public.create_notification(
  uuid, public.notification_type, text, text, uuid, jsonb
) from public;
grant execute on function public.create_notification(
  uuid, public.notification_type, text, text, uuid, jsonb
) to service_role;


-- ===== [54] notifications/functions/02_mark_read.sql =====
-- ============================================================================
-- Домен notifications · Функция mark_notifications_read
-- ----------------------------------------------------------------------------
-- Помечает уведомления прочитанными. Без аргумента — все непрочитанные; со
-- списком id — только их. Работает строго со своими уведомлениями.
-- ============================================================================

create or replace function public.mark_notifications_read(p_ids uuid[] default null)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cnt integer;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.notifications
     set read_at = now()
   where user_id = v_uid
     and read_at is null
     and (p_ids is null or id = any (p_ids));

  get diagnostics v_cnt = row_count;
  return v_cnt;
end;
$$;

revoke all on function public.mark_notifications_read(uuid[]) from public;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;

