-- ============================================================================
-- ПОЛНЫЙ СБРОС СХЕМЫ public
-- ----------------------------------------------------------------------------
-- ⚠️ ОПАСНО И НЕОБРАТИМО: удаляет ВСЕ таблицы (вместе с данными), функции и
--    enum-типы в схеме public, плюс наш триггер на auth.users.
--
-- Что НЕ трогает:
--  • схему auth и таблицу auth.users (аккаунты остаются);
--  • схемы storage / extensions / прочие системные Supabase.
--
-- Применять, когда нужно начать с чистого листа. После — прогнать _apply_all.sql.
--
-- Если нужно убрать ещё и старые аккаунты — это отдельно:
--   Dashboard → Authentication → Users, либо `delete from auth.users;`
-- ============================================================================

-- 0) Снимаем наш триггер с auth.users (он вне public; CASCADE по public его не уберёт).
drop trigger if exists trg_on_auth_user_created on auth.users;

-- ВАЖНО: пропускаем объекты, принадлежащие расширениям (deptype = 'e'),
-- например таблицу spatial_ref_sys от PostGIS — её нельзя дропнуть напрямую.

-- 1) Удаляем ВСЕ наши таблицы в public (CASCADE заодно убирает их триггеры,
--    политики RLS, индексы и внешние ключи).
do $$
declare r record;
begin
  for r in (
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')        -- обычные и партиционированные таблицы
      and not exists (                    -- кроме таблиц расширений
        select 1 from pg_depend d
        where d.objid = c.oid and d.deptype = 'e'
      )
  ) loop
    execute format('drop table if exists public.%I cascade;', r.relname);
  end loop;
end$$;

-- 2) Удаляем наши функции в public (RPC, триггерные функции, помощники).
--    prokind = 'f' — только функции; объекты расширений пропускаем.
do $$
declare r record;
begin
  for r in (
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and not exists (
        select 1 from pg_depend d
        where d.objid = p.oid and d.deptype = 'e'
      )
  ) loop
    execute format('drop function if exists %s cascade;', r.sig);
  end loop;
end$$;

-- 3) Удаляем наши enum-типы в public (user_role, ride_status, … ).
--    typtype = 'e' — только перечисления; объекты расширений пропускаем.
do $$
declare r record;
begin
  for r in (
    select t.typname
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typtype = 'e'
      and not exists (
        select 1 from pg_depend d
        where d.objid = t.oid and d.deptype = 'e'
      )
  ) loop
    execute format('drop type if exists public.%I cascade;', r.typname);
  end loop;
end$$;

-- Готово: схема public пуста. Теперь можно применять _apply_all.sql заново.
