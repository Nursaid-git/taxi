-- ============================================================================
-- Домен notifications · Типы (enum)
-- ============================================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'notification_type') then
    create type public.notification_type as enum (
      'ride_update',  -- смена статуса поездки
      'new_order',    -- новый заказ для водителя
      'promo',        -- акции/мили
      'system'        -- системное
    );
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'device_platform') then
    create type public.device_platform as enum ('ios', 'android', 'web');
  end if;
end$$;
