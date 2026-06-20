-- ============================================================================
-- Домен notifications · Уведомления по смене статуса поездки (триггер)
-- ----------------------------------------------------------------------------
-- На каждый переход статуса заказа кладём уведомление нужному участнику.
-- security definer: пишем в notifications в обход RLS (создаёт система).
-- ============================================================================

create or replace function public.notify_on_ride_status()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_user  uuid;
  v_title text;
  v_body  text;
begin
  -- Интересует только реальная смена статуса.
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'accepted' then
    v_user := new.client_id;
    v_title := 'Водитель найден';
    v_body := 'Водитель принял заказ и едет к вам';
  elsif new.status = 'arrived' then
    v_user := new.client_id;
    v_title := 'Водитель ждёт вас';
    v_body := 'Машина на месте — выходите';
  elsif new.status = 'in_progress' then
    v_user := new.client_id;
    v_title := 'Поездка началась';
  elsif new.status = 'completed' then
    v_user := new.client_id;
    v_title := 'Поездка завершена';
    v_body := 'Оцените поездку';
  elsif new.status = 'cancelled' then
    -- Уведомляем вторую сторону.
    if new.cancelled_by = 'client' then
      v_user := new.driver_id;
      v_title := 'Заказ отменён клиентом';
    else
      v_user := new.client_id;
      v_title := 'Поездка отменена';
    end if;
  else
    return new;
  end if;

  if v_user is not null then
    insert into public.notifications (user_id, type, title, body, ride_id)
    values (v_user, 'ride_update', v_title, v_body, new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_on_ride_status on public.rides;
create trigger trg_notify_on_ride_status
  after update on public.rides
  for each row execute function public.notify_on_ride_status();
