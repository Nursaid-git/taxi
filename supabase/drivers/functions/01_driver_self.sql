-- ============================================================================
-- Домен drivers · Функции водителя (своя анкета и статус)
-- ============================================================================

-- is_active_driver: проверенный И на линии. Используется в accept_ride (rides).
create or replace function public.is_active_driver(p_user_id uuid)
returns boolean
language sql security definer stable set search_path = ''
as $$
  select exists (
    select 1 from public.driver_profiles d
    where d.id = p_user_id
      and d.status = 'approved'
      and d.is_online
  );
$$;

-- save_driver_profile: создать/обновить анкету. ЛЮБОЕ изменение анкеты ставит
-- status = 'pending' (нужна повторная модерация) — водитель не одобряет себя сам.
create or replace function public.save_driver_profile(
  p_first_name     text,
  p_last_name      text,
  p_birth_date     date,
  p_city           text,
  p_photo_url      text,
  p_license_number text,
  p_license_expiry date
)
returns public.driver_profiles
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_d   public.driver_profiles;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  insert into public.driver_profiles as d (
    id, first_name, last_name, birth_date, city, photo_url,
    license_number, license_expiry, status, approved_at, rejection_reason
  ) values (
    v_uid, p_first_name, p_last_name, p_birth_date, p_city, p_photo_url,
    p_license_number, p_license_expiry, 'pending', null, null
  )
  on conflict (id) do update set
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    birth_date = excluded.birth_date,
    city = excluded.city,
    photo_url = excluded.photo_url,
    license_number = excluded.license_number,
    license_expiry = excluded.license_expiry,
    status = 'pending',
    approved_at = null,
    rejection_reason = null
  returning * into v_d;

  return v_d;
end;
$$;

-- set_driver_vehicle: сделать переданную машину активной (прежнюю — неактивной).
create or replace function public.set_driver_vehicle(
  p_brand     text,
  p_model     text,
  p_year      integer,
  p_color     text,
  p_plate     text,
  p_photo_url text
)
returns public.driver_vehicles
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_v   public.driver_vehicles;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  update public.driver_vehicles
     set is_active = false
   where driver_id = v_uid and is_active;

  insert into public.driver_vehicles (
    driver_id, brand, model, year, color, plate, photo_url, is_active
  ) values (
    v_uid, p_brand, p_model, p_year, p_color, p_plate, p_photo_url, true
  )
  returning * into v_v;

  return v_v;
end;
$$;

-- add_driver_document: загрузить/заменить документ (ставит pending).
create or replace function public.add_driver_document(
  p_type     public.document_type,
  p_file_url text
)
returns public.driver_documents
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_doc public.driver_documents;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  insert into public.driver_documents (driver_id, type, file_url, status)
  values (v_uid, p_type, p_file_url, 'pending')
  on conflict (driver_id, type) do update set
    file_url = excluded.file_url,
    status = 'pending'
  returning * into v_doc;

  return v_doc;
end;
$$;

-- set_driver_online: выйти/уйти с линии. На линию — только при status='approved'.
create or replace function public.set_driver_online(p_online boolean)
returns public.driver_profiles
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_d   public.driver_profiles;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  if p_online then
    update public.driver_profiles
       set is_online = true
     where id = v_uid and status = 'approved'
    returning * into v_d;
    if v_d.id is null then
      raise exception 'driver is not approved';
    end if;
  else
    update public.driver_profiles
       set is_online = false
     where id = v_uid
    returning * into v_d;
    if v_d.id is null then
      raise exception 'driver profile not found';
    end if;
  end if;

  return v_d;
end;
$$;

-- driver_card: безопасная публичная карточка водителя для показа клиенту
-- (имя, рейтинг, авто). Только по одобренному водителю. Отдаёт лишь то, что и
-- так видно клиенту во время поездки — без документов и контактов.
create or replace function public.driver_card(p_driver_id uuid)
returns jsonb
language sql security definer stable set search_path = ''
as $$
  select jsonb_build_object(
    'driver_id',   d.id,
    'full_name',   p.full_name,
    'rating_avg',  d.rating_avg,
    'rating_count',d.rating_count,
    'trips_count', d.trips_count,
    'vehicle', (
      select jsonb_build_object(
        'brand', v.brand, 'model', v.model, 'color', v.color, 'plate', v.plate
      )
      from public.driver_vehicles v
      where v.driver_id = d.id and v.is_active
      limit 1
    )
  )
  from public.driver_profiles d
  join public.profiles p on p.id = d.id
  where d.id = p_driver_id and d.status = 'approved';
$$;

-- Доступ: всё перечисленное — авторизованным.
do $$
declare fn text;
begin
  foreach fn in array array[
    'public.is_active_driver(uuid)',
    'public.save_driver_profile(text, text, date, text, text, text, date)',
    'public.set_driver_vehicle(text, text, integer, text, text, text)',
    'public.add_driver_document(public.document_type, text)',
    'public.set_driver_online(boolean)',
    'public.driver_card(uuid)'
  ] loop
    execute format('revoke all on function %s from public;', fn);
    execute format('grant execute on function %s to authenticated;', fn);
  end loop;
end$$;
