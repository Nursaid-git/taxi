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
