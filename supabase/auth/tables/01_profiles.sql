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
