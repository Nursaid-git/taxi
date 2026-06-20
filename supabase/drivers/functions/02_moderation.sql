-- ============================================================================
-- Домен drivers · Модерация (только для бэкенда/админки)
-- ----------------------------------------------------------------------------
-- review_driver одобряет или отклоняет водителя. НЕ выдаётся обычным
-- пользователям: право выполнять есть только у service_role (серверный ключ).
-- Так водитель никак не может сам себя одобрить.
-- ============================================================================

create or replace function public.review_driver(
  p_driver_id uuid,
  p_approved  boolean,
  p_reason    text default null
)
returns public.driver_profiles
language plpgsql security definer set search_path = ''
as $$
declare
  v_d public.driver_profiles;
begin
  update public.driver_profiles
     set status = case when p_approved
                       then 'approved'::public.verification_status
                       else 'rejected'::public.verification_status end,
         approved_at = case when p_approved then now() else null end,
         rejection_reason = case when p_approved then null else p_reason end,
         -- Отклонённого/снятого с проверки убираем с линии.
         is_online = case when p_approved then is_online else false end
   where id = p_driver_id
  returning * into v_d;

  if v_d.id is null then raise exception 'driver not found'; end if;
  return v_d;
end;
$$;

-- Никому из клиентских ролей не даём. Только серверный service_role.
revoke all on function public.review_driver(uuid, boolean, text) from public;
grant execute on function public.review_driver(uuid, boolean, text) to service_role;
