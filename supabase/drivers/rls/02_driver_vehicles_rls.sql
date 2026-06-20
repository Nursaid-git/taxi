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
