-- ============================================================================
-- Домен places · Типы (enum)
-- ============================================================================

-- Тип сохранённого адреса. home/work — особые слоты (по одному), other — любые.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'place_kind') then
    create type public.place_kind as enum ('home', 'work', 'other');
  end if;
end$$;
