-- ============================================================================
-- Домен drivers · Агрегаты (триггеры)
-- ----------------------------------------------------------------------------
-- Денормализованные поля driver_profiles (rating_avg/count, trips_count, balance)
-- пересчитываются автоматически при изменении фактов в домене rides.
-- Триггерные функции — SECURITY DEFINER, чтобы обновлять driver_profiles в обход
-- RLS (RLS не разрешает обычному пользователю писать в чужой/свой профиль напрямую).
-- ============================================================================

-- 1) Новая оценка → пересчёт рейтинга водителя.
-- Если оцениваемый не водитель (нет строки в driver_profiles) — UPDATE просто
-- затронет 0 строк, и это нормально.
create or replace function public.recalc_driver_rating()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.driver_profiles d
     set rating_count = agg.cnt,
         rating_avg   = round(agg.avg_stars, 2)
  from (
    select count(*)::int as cnt, avg(stars)::numeric as avg_stars
    from public.ride_ratings
    where ratee_id = new.ratee_id
  ) agg
  where d.id = new.ratee_id;
  return new;
end;
$$;

drop trigger if exists trg_recalc_driver_rating on public.ride_ratings;
create trigger trg_recalc_driver_rating
  after insert on public.ride_ratings
  for each row execute function public.recalc_driver_rating();

-- 2) Поездка завершена → +1 к поездкам и +цена к балансу.
-- Срабатывает строго на переходе в 'completed' (а не на любом UPDATE), чтобы
-- не начислить дважды.
create or replace function public.on_ride_completed()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'completed'
     and (old.status is distinct from 'completed')
     and new.driver_id is not null then
    update public.driver_profiles
       set trips_count = trips_count + 1,
           balance     = balance + coalesce(new.price_final, 0)
     where id = new.driver_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_on_ride_completed on public.rides;
create trigger trg_on_ride_completed
  after update on public.rides
  for each row execute function public.on_ride_completed();
