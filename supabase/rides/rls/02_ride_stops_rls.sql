-- ============================================================================
-- Домен rides · RLS для ride_stops
-- ----------------------------------------------------------------------------
-- Точки видны тем же, кому виден сам заказ. Переиспользуем правило доступа к
-- rides через подзапрос: «есть ли заказ-родитель, который мне виден».
-- Записываются точки только функцией request_ride (вместе с заказом).
-- ============================================================================

alter table public.ride_stops enable row level security;

drop policy if exists "ride_stops_select_via_ride" on public.ride_stops;
create policy "ride_stops_select_via_ride"
  on public.ride_stops
  for select
  using (
    exists (
      select 1
      from public.rides r
      where r.id = ride_stops.ride_id
        and (
          auth.uid() = r.client_id
          or auth.uid() = r.driver_id
          or (r.status = 'searching' and public.has_role(auth.uid(), 'driver'))
        )
    )
  );

-- Запись (INSERT) — только через request_ride (SECURITY DEFINER). Прямой записи
-- клиенту не даём: иначе можно дописать точки в чужой/уже завершённый заказ.
