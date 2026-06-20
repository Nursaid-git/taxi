-- ============================================================================
-- Домен loyalty · Функция redeem_reward (обменять мили на награду)
-- ----------------------------------------------------------------------------
-- Списание идёт через журнал: вставляем отрицательную транзакцию и запись
-- обмена. Баланс уменьшит триггер apply_loyalty_transaction; уйти в минус не
-- даст CHECK (balance >= 0). Цену награды фиксируем на момент обмена.
-- ============================================================================

create or replace function public.redeem_reward(p_reward_id uuid)
returns public.loyalty_redemptions
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_reward  public.loyalty_rewards;
  v_balance integer;
  v_red     public.loyalty_redemptions;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select * into v_reward
  from public.loyalty_rewards
  where id = p_reward_id and is_active;
  if v_reward.id is null then raise exception 'reward not available'; end if;

  -- Текущий баланс (со счёта). Если счёта нет — считаем 0.
  select coalesce(balance, 0) into v_balance
  from public.loyalty_accounts where user_id = v_uid;

  if coalesce(v_balance, 0) < v_reward.cost then
    raise exception 'not enough miles';
  end if;

  -- Списание милей (журнал → баланс обновит триггер).
  insert into public.loyalty_transactions (user_id, amount, reason, note)
  values (v_uid, -v_reward.cost, 'redemption', v_reward.code);

  -- Запись обмена.
  insert into public.loyalty_redemptions (user_id, reward_id, cost, status)
  values (v_uid, v_reward.id, v_reward.cost, 'active')
  returning * into v_red;

  return v_red;
end;
$$;

revoke all on function public.redeem_reward(uuid) from public;
grant execute on function public.redeem_reward(uuid) to authenticated;
