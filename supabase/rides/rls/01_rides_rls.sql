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
