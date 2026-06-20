-- ============================================================================
-- Домен drivers · Таблица driver_documents (документы на проверку)
-- ----------------------------------------------------------------------------
-- Каждый документ — со своим статусом, чтобы модератор мог принять одни и
-- отклонить другие. Сами файлы лежат в Supabase Storage, здесь — только ссылки.
-- ============================================================================

create table if not exists public.driver_documents (
  id         uuid primary key default gen_random_uuid(),
  driver_id  uuid not null references auth.users (id) on delete cascade,

  type       public.document_type       not null,
  file_url   text                       not null,
  status     public.verification_status not null default 'pending',

  created_at timestamptz not null default now(),

  -- Один актуальный документ каждого типа на водителя (повторная загрузка
  -- заменяет прежний — см. add_driver_document с ON CONFLICT).
  constraint driver_documents_unique_type unique (driver_id, type)
);

comment on table public.driver_documents is
  'Документы водителя (ссылки на файлы в Storage) со статусом проверки.';
