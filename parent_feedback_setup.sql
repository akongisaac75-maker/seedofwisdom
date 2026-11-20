-- PSWS: Parent feedback table. Run ONCE in Supabase > SQL Editor.
-- (The old app sent parent feedback to a private server; this app keeps it in your own database.)
create table if not exists public.parent_feedback(
  id uuid primary key default gen_random_uuid(),
  student_id text,
  student_login_id text,
  student_name text,
  parent_name text,
  parent_contact text,
  message text,
  week_id text,
  status text default 'unread',     -- unread | read
  reply text,
  created_at timestamptz default now()
);
alter table public.parent_feedback enable row level security;
drop policy if exists "pf_all" on public.parent_feedback;
create policy "pf_all" on public.parent_feedback for all using (true) with check (true);
notify pgrst, 'reload schema';
