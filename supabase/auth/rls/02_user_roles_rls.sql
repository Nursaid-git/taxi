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
