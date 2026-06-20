-- ============================================================================
-- Домен rides · Типы (enum)
-- ----------------------------------------------------------------------------
-- Закрытые списки значений — через enum: защита от опечаток и компактность.
-- ============================================================================

-- Статус заказа (один на обе роли — это один и тот же объект).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'ride_status') then
    create type public.ride_status as enum (
      'searching',    -- ищем водителя (заказ создан, водителя нет)
      'accepted',     -- водитель принял, едет за клиентом
      'arrived',      -- водитель на месте, ждёт клиента
      'in_progress',  -- поездка идёт
      'completed',    -- завершена
      'cancelled',    -- отменена (клиентом или водителем)
      'expired'       -- никто не принял / таймаут
    );
  end if;
end$$;

-- Класс поездки (тариф).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'ride_class') then
    create type public.ride_class as enum ('econom', 'comfort', 'business');
  end if;
end$$;

-- Способ оплаты. В Абхазии по умолчанию наличные; карту закладываем на будущее.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'payment_method') then
    create type public.payment_method as enum ('cash', 'card');
  end if;
end$$;

-- Кто инициировал действие (для поля «кем отменён»).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'ride_actor') then
    create type public.ride_actor as enum ('client', 'driver', 'system');
  end if;
end$$;
