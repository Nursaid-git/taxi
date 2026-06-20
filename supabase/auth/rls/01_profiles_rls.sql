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
