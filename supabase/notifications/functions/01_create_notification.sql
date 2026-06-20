-- ============================================================================
-- Домен notifications · Функция create_notification (для бэкенда)
-- ----------------------------------------------------------------------------
-- Программное создание уведомления из доверенного кода (service_role).
-- Клиентским ролям не выдаётся — иначе можно слать уведомления кому угодно.
-- ============================================================================

create or replace function public.create_notification(
  p_user_id uuid,
  p_type    public.notification_type,
  p_title   text,
  p_body    text  default null,
  p_ride_id uuid  default null,
  p_data    jsonb default '{}'
)
returns public.notifications
language plpgsql security definer set search_path = ''
as $$
declare
  v_n public.notifications;
begin
  insert into public.notifications (user_id, type, title, body, ride_id, data)
  values (p_user_id, p_type, p_title, p_body, p_ride_id, coalesce(p_data, '{}'))
  returning * into v_n;
  return v_n;
end;
$$;

revoke all on function public.create_notification(
  uuid, public.notification_type, text, text, uuid, jsonb
) from public;
grant execute on function public.create_notification(
  uuid, public.notification_type, text, text, uuid, jsonb
) to service_role;
