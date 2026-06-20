-- ============================================================================
-- Домен loyalty · Начисление миль за поездку
-- ----------------------------------------------------------------------------
-- Поездка стала 'completed' → клиенту начисляем мили (1 миля за 10 ₽).
-- Делаем это записью в журнал loyalty_transactions — баланс обновит триггер
-- apply_loyalty_transaction. Срабатывает строго на переходе в completed.
-- ============================================================================

create or replace function public.earn_miles_on_ride()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_miles integer;
begin
  if new.status = 'completed'
     and (old.status is distinct from 'completed')
     and new.client_id is not null then

    v_miles := floor(coalesce(new.price_final, new.price_estimated) / 10.0);

    if v_miles > 0 then
      insert into public.loyalty_transactions (user_id, amount, reason, ride_id)
      values (new.client_id, v_miles, 'trip', new.id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_earn_miles_on_ride on public.rides;
create trigger trg_earn_miles_on_ride
  after update on public.rides
  for each row execute function public.earn_miles_on_ride();
