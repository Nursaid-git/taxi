-- ============================================================================
-- Домен drivers · RLS для driver_documents
-- ----------------------------------------------------------------------------
-- Документы — чувствительные данные. Их видит ТОЛЬКО владелец. Модератор читает
-- через service_role (обходит RLS). Запись — функцией add_driver_document.
-- ============================================================================

alter table public.driver_documents enable row level security;

drop policy if exists "driver_documents_select_own" on public.driver_documents;
create policy "driver_documents_select_own"
  on public.driver_documents
  for select
  using (auth.uid() = driver_id);
