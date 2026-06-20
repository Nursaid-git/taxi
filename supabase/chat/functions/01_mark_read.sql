-- ============================================================================
-- Домен chat · Функция mark_ride_messages_read
-- ----------------------------------------------------------------------------
-- Помечает прочитанными сообщения СОБЕСЕДНИКА в данной поездке. Свои сообщения
-- не трогаем. Доступно только участнику поездки.
-- ============================================================================

create or replace function public.mark_ride_messages_read(p_ride_id uuid)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cnt integer;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  -- Проверяем, что вызывающий — участник поездки.
  if not exists (
    select 1 from public.rides r
    where r.id = p_ride_id
      and (r.client_id = v_uid or r.driver_id = v_uid)
  ) then
    raise exception 'not a participant of this ride';
  end if;

  update public.chat_messages
     set read_at = now()
   where ride_id = p_ride_id
     and sender_id <> v_uid     -- только сообщения собеседника
     and read_at is null;

  get diagnostics v_cnt = row_count;
  return v_cnt;  -- сколько отметили прочитанными
end;
$$;

revoke all on function public.mark_ride_messages_read(uuid) from public;
grant execute on function public.mark_ride_messages_read(uuid) to authenticated;
