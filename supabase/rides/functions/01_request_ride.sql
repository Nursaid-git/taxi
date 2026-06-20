-- ============================================================================
-- Домен rides · Функция request_ride (создать заказ)
-- ----------------------------------------------------------------------------
-- Создаёт заказ и его точки назначения ОДНОЙ транзакцией. Если что-то упадёт —
-- не останется «полузаказа» без точек. Поэтому это функция, а не два INSERT'а
-- из приложения через RLS.
--
-- Роль 'client' здесь НЕ требуем: заказать такси может любой авторизованный
-- пользователь (в т.ч. водитель как пассажир). Ограничения по ролям важны на
-- стороне ВОДИТЕЛЯ (принять заказ может только driver) — см. 02_ride_lifecycle.
-- ============================================================================

create or replace function public.request_ride(
  p_ride_class      public.ride_class,
  p_payment_method  public.payment_method,
  p_pickup_address  text,
  p_pickup_lat      double precision,
  p_pickup_lng      double precision,
  p_distance_km     numeric,
  p_duration_min    integer,
  p_price_estimated integer,
  p_stops           jsonb              -- [{"address":..,"lat":..,"lng":..}, ...]
)
returns public.rides
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_stops is null or jsonb_array_length(p_stops) < 1 then
    raise exception 'at least one destination required';
  end if;

  insert into public.rides (
    client_id, status, ride_class, payment_method,
    pickup_address, pickup_lat, pickup_lng,
    distance_km, duration_min, price_estimated
  ) values (
    v_uid, 'searching', p_ride_class, p_payment_method,
    p_pickup_address, p_pickup_lat, p_pickup_lng,
    p_distance_km, p_duration_min, p_price_estimated
  )
  returning * into v_ride;

  insert into public.ride_stops (ride_id, position, address, lat, lng)
  select v_ride.id,
         ord::int,
         elem ->> 'address',
         (elem ->> 'lat')::double precision,
         (elem ->> 'lng')::double precision
  from jsonb_array_elements(p_stops) with ordinality as s(elem, ord);

  return v_ride;
end;
$$;

-- По умолчанию EXECUTE есть у PUBLIC — сужаем до авторизованных.
-- Сигнатура — все 9 типов параметров по порядку (два integer подряд:
-- duration_min и price_estimated).
revoke all on function public.request_ride(
  public.ride_class, public.payment_method, text,
  double precision, double precision, numeric, integer, integer, jsonb
) from public;
grant execute on function public.request_ride(
  public.ride_class, public.payment_method, text,
  double precision, double precision, numeric, integer, integer, jsonb
) to authenticated;
