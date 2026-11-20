-- Run once in Supabase > SQL Editor, then refresh the app (Ctrl+Shift+R).
create table if not exists public.term_info(
  term_id text primary key,
  closing_date date,
  next_term_begins date,
  next_term_fees text,
  fees_breakdown text,
  notes text,
  updated_at timestamptz default now());

alter table public.term_info enable row level security;
drop policy if exists psws_open_all on public.term_info;
create policy psws_open_all on public.term_info for all to anon, authenticated using (true) with check (true);
grant all on public.term_info to anon, authenticated;
notify pgrst, 'reload schema';
