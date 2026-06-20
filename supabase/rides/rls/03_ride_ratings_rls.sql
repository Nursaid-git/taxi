-- ============================================================================
-- Домен rides · RLS для ride_ratings
-- ----------------------------------------------------------------------------
-- Оценки видны участникам поездки. Создаются через функцию rate_ride, которая
-- проверяет, что поездка завершена и оценивающий — её участник.
-- ============================================================================

alter table public.ride_ratings enable row level security;

drop policy if exists "ride_ratings_select_via_ride" on public.ride_ratings;
create policy "ride_ratings_select_via_ride"
  on public.ride_ratings
  for select
  using (
    auth.uid() = rater_id
    or auth.uid() = ratee_id
  );

-- INSERT — только через rate_ride (SECURITY DEFINER), чтобы гарантировать:
--  • поездка существует и завершена;
--  • оценивающий действительно её участник;
--  • он не ставит оценку «за другого».
