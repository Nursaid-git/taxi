-- ============================================================================
-- Домен chat · RLS для chat_messages
-- ----------------------------------------------------------------------------
-- Доступ берём из самого заказа: участник видит и пишет, остальные — нет.
-- ============================================================================

alter table public.chat_messages enable row level security;

-- Вспомогалка: я участник этой поездки?
-- (inline-подзапрос, чтобы не плодить функций; ride виден через RLS rides).
-- Читать сообщения может клиент или назначенный водитель поездки.
drop policy if exists "chat_select_participant" on public.chat_messages;
create policy "chat_select_participant"
  on public.chat_messages
  for select
  using (
    exists (
      select 1 from public.rides r
      where r.id = chat_messages.ride_id
        and (auth.uid() = r.client_id or auth.uid() = r.driver_id)
    )
  );

-- Писать: я отправитель (sender_id = я), я участник, и поездка АКТИВНА.
-- Это не переход состояния, а простая вставка — допускаем через RLS.
drop policy if exists "chat_insert_participant_active" on public.chat_messages;
create policy "chat_insert_participant_active"
  on public.chat_messages
  for insert
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.rides r
      where r.id = chat_messages.ride_id
        and (auth.uid() = r.client_id or auth.uid() = r.driver_id)
        and r.status in ('accepted', 'arrived', 'in_progress')
    )
  );

-- UPDATE/DELETE напрямую не разрешаем. Отметка о прочтении — функцией
-- mark_ride_messages_read (нельзя дать клиенту менять чужой текст/время).
