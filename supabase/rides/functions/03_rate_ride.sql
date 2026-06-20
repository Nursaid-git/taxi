-- ============================================================================
-- Домен rides · Функция rate_ride (оценить поездку)
-- ----------------------------------------------------------------------------
-- Гарантирует то, что RLS-вставкой нормально не выразить:
--  • поездка существует и ЗАВЕРШЕНА;
--  • оценивающий — её участник;
--  • оценивают вторую сторону (клиент → водитель или наоборот);
--  • повтор не пройдёт (UNIQUE(ride_id, rater_id)), диапазон звёзд (CHECK 1..5).
-- ============================================================================

create or replace function public.rate_ride(
  p_ride_id uuid,
  p_stars   integer,
  p_comment text   default null,
  p_tags    text[] default '{}'
)
returns public.ride_ratings
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_ride   public.rides;
  v_ratee  uuid;
  v_rating public.ride_ratings;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select * into v_ride from public.rides where id = p_ride_id;
  if v_ride.id is null then raise exception 'ride not found'; end if;
  if v_ride.status <> 'completed' then raise exception 'ride is not completed'; end if;
  if v_uid <> v_ride.client_id and v_uid <> v_ride.driver_id then
    raise exception 'not a participant of this ride';
  end if;

  -- Оцениваем вторую сторону.
  v_ratee := case
    when v_uid = v_ride.client_id then v_ride.driver_id
    else v_ride.client_id
  end;
  if v_ratee is null then raise exception 'no counterpart to rate'; end if;

  insert into public.ride_ratings (ride_id, rater_id, ratee_id, stars, comment, tags)
  values (p_ride_id, v_uid, v_ratee, p_stars, p_comment, coalesce(p_tags, '{}'))
  returning * into v_rating;

  return v_rating;
end;
$$;

revoke all on function public.rate_ride(uuid, integer, text, text[]) from public;
grant execute on function public.rate_ride(uuid, integer, text, text[]) to authenticated;
