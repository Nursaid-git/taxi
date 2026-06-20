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
