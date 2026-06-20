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
