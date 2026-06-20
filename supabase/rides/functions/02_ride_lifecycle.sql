-- ============================================================================
-- Домен rides · Переходы статуса заказа
-- ----------------------------------------------------------------------------
-- Каждая функция:
--  • проверяет, кто вызывает (auth.uid()) и его право;
--  • меняет статус ТОЛЬКО из допустимого предыдущего (через WHERE status = …);
--  • ставит соответствующее время.
-- Если перехода нет (заказ уже принят/отменён/чужой) — UPDATE не находит строку,
-- и мы кидаем понятную ошибку. Так состояние нельзя «перескочить».
-- ============================================================================

-- accept: searching → accepted. Принять может только АКТИВНЫЙ водитель
-- (проверенный + на линии). Функция is_active_driver определяется в домене
-- drivers, поэтому drivers применяется после rides. Гейт стоит именно здесь:
-- видеть свободные заявки RLS разрешает любому водителю, а вот принять —
-- только прошедшему модерацию.
create or replace function public.accept_ride(p_ride_id uuid)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if not public.is_active_driver(v_uid) then
    raise exception 'driver is not approved or not online';
  end if;

  update public.rides
     set driver_id = v_uid, status = 'accepted', accepted_at = now()
   where id = p_ride_id and status = 'searching' and driver_id is null
  returning * into v_ride;

  if v_ride.id is null then
    raise exception 'ride is no longer available';
  end if;
  return v_ride;
end;
$$;

-- arrived: accepted → arrived (назначенный водитель). Включает 4 мин бесплатного
-- ожидания: дальше начисляется платное ожидание.
create or replace function public.driver_arrived(p_ride_id uuid)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.rides
     set status = 'arrived',
         arrived_at = now(),
         free_wait_until = now() + interval '4 minutes'
   where id = p_ride_id and driver_id = v_uid and status = 'accepted'
  returning * into v_ride;

  if v_ride.id is null then raise exception 'invalid transition'; end if;
  return v_ride;
end;
$$;

-- start: arrived → in_progress (назначенный водитель).
create or replace function public.start_ride(p_ride_id uuid)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.rides
     set status = 'in_progress', started_at = now()
   where id = p_ride_id and driver_id = v_uid and status = 'arrived'
  returning * into v_ride;

  if v_ride.id is null then raise exception 'invalid transition'; end if;
  return v_ride;
end;
$$;

-- complete: in_progress → completed (назначенный водитель). Если итоговая цена
-- не передана — берём предварительную плюс платное ожидание.
create or replace function public.complete_ride(
  p_ride_id uuid,
  p_price_final integer default null
)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.rides
     set status = 'completed',
         completed_at = now(),
         price_final = coalesce(p_price_final, price_estimated + wait_charge)
   where id = p_ride_id and driver_id = v_uid and status = 'in_progress'
  returning * into v_ride;

  if v_ride.id is null then raise exception 'invalid transition'; end if;
  return v_ride;
end;
$$;

-- cancel: searching/accepted/arrived → cancelled (клиент или водитель заказа).
create or replace function public.cancel_ride(
  p_ride_id uuid,
  p_reason  text default null
)
returns public.rides
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.rides
     set status = 'cancelled',
         cancelled_at = now(),
         cancel_reason = p_reason,
         cancelled_by = case
           when client_id = v_uid then 'client'::public.ride_actor
           when driver_id = v_uid then 'driver'::public.ride_actor
         end
   where id = p_ride_id
     and (client_id = v_uid or driver_id = v_uid)
     and status in ('searching', 'accepted', 'arrived')
  returning * into v_ride;

  if v_ride.id is null then raise exception 'cannot cancel this ride'; end if;
  return v_ride;
end;
$$;

-- Доступ: только авторизованным.
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.accept_ride(uuid)',
    'public.driver_arrived(uuid)',
    'public.start_ride(uuid)',
    'public.complete_ride(uuid, integer)',
    'public.cancel_ride(uuid, text)'
  ] loop
    execute format('revoke all on function %s from public;', fn);
    execute format('grant execute on function %s to authenticated;', fn);
  end loop;
end$$;
