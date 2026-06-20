-- ============================================================================
-- Домен drivers · Типы (enum)
-- ============================================================================

-- Статус проверки. Используется и для водителя в целом, и для каждого документа.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'verification_status') then
    create type public.verification_status as enum ('pending', 'approved', 'rejected');
  end if;
end$$;

-- Типы документов, которые водитель загружает на проверку.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'document_type') then
    create type public.document_type as enum (
      'license',              -- водительское удостоверение
      'selfie',               -- селфи для верификации личности
      'passport',             -- паспорт
      'vehicle_registration'  -- свидетельство о регистрации авто
    );
  end if;
end$$;
