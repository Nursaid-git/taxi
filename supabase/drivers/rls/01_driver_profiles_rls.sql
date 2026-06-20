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
