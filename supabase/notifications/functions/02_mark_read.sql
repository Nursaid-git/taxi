-- ============================================================================
-- Домен notifications · Функция mark_notifications_read
-- ----------------------------------------------------------------------------
-- Помечает уведомления прочитанными. Без аргумента — все непрочитанные; со
-- списком id — только их. Работает строго со своими уведомлениями.
-- ============================================================================

create or replace function public.mark_notifications_read(p_ids uuid[] default null)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cnt integer;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.notifications
     set read_at = now()
   where user_id = v_uid
     and read_at is null
     and (p_ids is null or id = any (p_ids));

  get diagnostics v_cnt = row_count;
  return v_cnt;
end;
$$;

revoke all on function public.mark_notifications_read(uuid[]) from public;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;
