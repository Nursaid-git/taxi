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
