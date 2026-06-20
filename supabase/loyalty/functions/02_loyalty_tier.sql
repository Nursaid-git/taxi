-- ============================================================================
-- Домен loyalty · Функция loyalty_tier (уровень по сумме начисленного)
-- ----------------------------------------------------------------------------
-- Уровень — производное от lifetime_earned, поэтому не храним его, а вычисляем.
-- Так нечему рассинхронизироваться. Пороги можно менять в одном месте.
-- ============================================================================

create or replace function public.loyalty_tier(p_user_id uuid)
returns text
language sql stable security definer set search_path = ''
as $$
  select case
    when coalesce(a.lifetime_earned, 0) >= 5000 then 'Платина'
    when coalesce(a.lifetime_earned, 0) >= 2000 then 'Золото'
    when coalesce(a.lifetime_earned, 0) >= 1000 then 'Серебро'
    else 'Бронза'
  end
  from public.loyalty_accounts a
  where a.user_id = p_user_id
  -- если счёта нет — вернётся NULL; приложение покажет «Бронза» по умолчанию.
$$;

revoke all on function public.loyalty_tier(uuid) from public;
grant execute on function public.loyalty_tier(uuid) to authenticated;
