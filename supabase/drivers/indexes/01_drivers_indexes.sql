-- ============================================================================
-- Домен drivers · Индексы
-- ----------------------------------------------------------------------------
-- Уже проиндексировано: driver_profiles.id (PK), driver_vehicles.id (PK) и
-- частичный уникальный uq_driver_active_vehicle, driver_documents(driver_id,type)
-- (UNIQUE — покрывает поиск по driver_id).
-- ============================================================================

-- Очередь модерации: «показать всех на проверке».
create index if not exists idx_driver_profiles_status
  on public.driver_profiles (status);

-- Доступные водители (на линии и проверенные), отсортированные по рейтингу —
-- основа для матчинга «кому предложить заказ». Частичный индекс: строк мало.
create index if not exists idx_drivers_available
  on public.driver_profiles (rating_avg desc)
  where is_online and status = 'approved';

-- Все машины конкретного водителя (история).
create index if not exists idx_driver_vehicles_driver_id
  on public.driver_vehicles (driver_id);
