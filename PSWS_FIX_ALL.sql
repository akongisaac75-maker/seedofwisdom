-- =====================================================================
-- PSWS LIVE  -  ONE-SHOT DATABASE FIX  (safe to run again and again)
-- Run ONCE in:  Supabase > SQL Editor > New query > paste all > Run
--
-- Fixes:
--   1. "new row violates row-level security policy for table ..."   (sessions, terms, weeks, classes ...)
--   2. "Could not find the table 'public.nursery_observations' ..."  (and every other missing table)
--   3. Missing columns the app expects (subjects.level, classes.section, weeks.term_id, term_scores.test1_manual ...)
--   4. Missing relationships the app uses to join tables (students -> classes, assessments -> weeks ...)
--   5. Missing unique keys the app needs for "save / update" (upserts)
--   6. Missing storage buckets (assignment files, exam inbox, daily story photos, report-card PDFs)
--
-- It never deletes or changes existing data.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Permissions: the app talks to Supabase with the public (anon) key
-- ---------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
alter default privileges in schema public grant all on tables    to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;
alter default privileges in schema public grant all on functions to anon, authenticated;

create extension if not exists pgcrypto;   -- gen_random_uuid()

-- ---------------------------------------------------------------------
-- 1. CORE TABLES (only created if they are missing)
-- ---------------------------------------------------------------------
create table if not exists public.sessions(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_active boolean default false,
  created_at timestamptz default now());

create table if not exists public.terms(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  session_id uuid,
  created_at timestamptz default now());

create table if not exists public.classes(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  section text,
  class_teacher_id text,
  created_at timestamptz default now());

create table if not exists public.subjects(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  level text,
  sections text[] not null default '{}',
  class_ids text[] not null default '{}',
  created_at timestamptz default now());

create table if not exists public.teachers(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  password text not null,
  role text not null default 'teacher',
  school_sections text[] default '{}',
  subject_id text,
  created_at timestamptz default now());

create table if not exists public.students(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  class_id uuid,
  student_login_id text,
  student_password text,
  parent_name text, parent_phone text, parent_email text,
  created_at timestamptz default now());

create table if not exists public.class_teachers(
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid,
  class_id uuid,
  created_at timestamptz default now());

create table if not exists public.teacher_subjects(
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid,
  subject_id uuid,
  created_at timestamptz default now());

create table if not exists public.weeks(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  start_date date, end_date date,
  term_id uuid, session_id uuid,
  created_at timestamptz default now());

create table if not exists public.assessments(
  id uuid primary key default gen_random_uuid(),
  student_id uuid,
  subject_id uuid,
  week_id uuid,
  teacher_id uuid,
  assignment_score numeric default 0,
  test_score numeric default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now());

create table if not exists public.midterm_assessments(
  id uuid primary key default gen_random_uuid(),
  student_id uuid,
  class_id uuid,
  subject_id uuid,
  term_id uuid, session_id uuid,
  teacher_id uuid,
  major_test_score numeric,
  created_at timestamptz default now(),
  updated_at timestamptz default now());

create table if not exists public.quizzes(
  id uuid primary key default gen_random_uuid(),
  title text not null,
  class_id uuid,
  subject_id uuid,
  week_id uuid,
  teacher_id uuid,
  duration_minutes int default 30,
  max_score numeric default 10,
  pass_score numeric default 5,
  status text default 'draft',
  shuffle_questions boolean default true,
  shuffle_options boolean default true,
  attempts_allowed int default 1,
  quiz_type text default 'weekly',
  term_id text, session_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now());

create table if not exists public.quiz_questions(
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid,
  question_no int,
  question_text text,
  option_a text, option_b text, option_c text, option_d text,
  correct_answer text,
  topic text,
  marks numeric default 1,
  created_at timestamptz default now());

create table if not exists public.quiz_attempts(
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid,
  student_id uuid,
  started_at timestamptz, submitted_at timestamptz,
  score numeric, percentage numeric,
  correct_count int, total_questions int,
  status text, answers jsonb,
  created_at timestamptz default now());

create table if not exists public.teacher_feedback(
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid,
  admin_id text,
  subject text, message text,
  status text default 'unread',
  reply text, replied_at timestamptz,
  created_at timestamptz default now());

-- ---------------------------------------------------------------------
-- 2. MISSING COLUMNS on tables that already exist
-- ---------------------------------------------------------------------
alter table public.students add column if not exists student_login_id text;
alter table public.students add column if not exists student_password text;
alter table public.students add column if not exists parent_name  text;
alter table public.students add column if not exists parent_phone text;
alter table public.students add column if not exists parent_email text;

alter table public.classes  add column if not exists section text;
alter table public.classes  add column if not exists class_teacher_id text;

alter table public.subjects add column if not exists level text;
alter table public.subjects add column if not exists sections  text[] not null default '{}';
alter table public.subjects add column if not exists class_ids text[] not null default '{}';

alter table public.teachers add column if not exists school_sections text[] default '{}';
alter table public.teachers add column if not exists subject_id text;

alter table public.weeks add column if not exists start_date date;
alter table public.weeks add column if not exists end_date date;
alter table public.weeks add column if not exists term_id uuid;
alter table public.weeks add column if not exists session_id uuid;

alter table public.sessions add column if not exists is_active boolean default false;
alter table public.terms    add column if not exists session_id uuid;

alter table public.quizzes add column if not exists quiz_type  text default 'weekly';
alter table public.quizzes add column if not exists term_id    text;
alter table public.quizzes add column if not exists session_id text;
alter table public.quizzes add column if not exists shuffle_questions boolean default true;
alter table public.quizzes add column if not exists shuffle_options   boolean default true;
alter table public.quizzes add column if not exists attempts_allowed  int default 1;
alter table public.quizzes add column if not exists duration_minutes  int default 30;
alter table public.quizzes add column if not exists max_score  numeric default 10;
alter table public.quizzes add column if not exists pass_score numeric default 5;
alter table public.quizzes add column if not exists status text default 'draft';

alter table public.quiz_questions add column if not exists question_no int;
alter table public.quiz_questions add column if not exists topic text;
alter table public.quiz_questions add column if not exists marks numeric default 1;

alter table public.quiz_attempts add column if not exists started_at timestamptz;
alter table public.quiz_attempts add column if not exists answers jsonb;
alter table public.quiz_attempts add column if not exists status text;
alter table public.quiz_attempts add column if not exists correct_count int;
alter table public.quiz_attempts add column if not exists total_questions int;
alter table public.quiz_attempts add column if not exists percentage numeric;

alter table public.assessments add column if not exists assignment_score numeric default 0;
alter table public.assessments add column if not exists test_score numeric default 0;

alter table public.midterm_assessments add column if not exists major_test_score numeric;
alter table public.midterm_assessments add column if not exists updated_at timestamptz default now();

alter table public.teacher_feedback add column if not exists reply text;
alter table public.teacher_feedback add column if not exists replied_at timestamptz;
alter table public.teacher_feedback add column if not exists status text default 'unread';

-- ---------------------------------------------------------------------
-- 2b. COMPLETE ANY TABLE THAT ALREADY EXISTS WITH FEWER COLUMNS
--     (auto-generated: every column the app needs, added only if missing)
-- ---------------------------------------------------------------------
alter table if exists public.sessions add column if not exists id uuid default gen_random_uuid();
alter table if exists public.sessions add column if not exists name text;
alter table if exists public.sessions add column if not exists is_active boolean default false;
alter table if exists public.sessions add column if not exists created_at timestamptz default now();
alter table if exists public.terms add column if not exists id uuid default gen_random_uuid();
alter table if exists public.terms add column if not exists name text;
alter table if exists public.terms add column if not exists session_id uuid;
alter table if exists public.terms add column if not exists created_at timestamptz default now();
alter table if exists public.classes add column if not exists id uuid default gen_random_uuid();
alter table if exists public.classes add column if not exists name text;
alter table if exists public.classes add column if not exists section text;
alter table if exists public.classes add column if not exists class_teacher_id text;
alter table if exists public.classes add column if not exists created_at timestamptz default now();
alter table if exists public.subjects add column if not exists id uuid default gen_random_uuid();
alter table if exists public.subjects add column if not exists name text;
alter table if exists public.subjects add column if not exists level text;
alter table if exists public.subjects add column if not exists sections text[] default '{}';
alter table if exists public.subjects add column if not exists class_ids text[] default '{}';
alter table if exists public.subjects add column if not exists created_at timestamptz default now();
alter table if exists public.teachers add column if not exists id uuid default gen_random_uuid();
alter table if exists public.teachers add column if not exists name text;
alter table if exists public.teachers add column if not exists email text;
alter table if exists public.teachers add column if not exists password text;
alter table if exists public.teachers add column if not exists role text default 'teacher';
alter table if exists public.teachers add column if not exists school_sections text[] default '{}';
alter table if exists public.teachers add column if not exists subject_id text;
alter table if exists public.teachers add column if not exists created_at timestamptz default now();
alter table if exists public.students add column if not exists id uuid default gen_random_uuid();
alter table if exists public.students add column if not exists name text;
alter table if exists public.students add column if not exists class_id uuid;
alter table if exists public.students add column if not exists student_login_id text;
alter table if exists public.students add column if not exists student_password text;
alter table if exists public.students add column if not exists parent_name text;
alter table if exists public.students add column if not exists parent_phone text;
alter table if exists public.students add column if not exists parent_email text;
alter table if exists public.students add column if not exists created_at timestamptz default now();
alter table if exists public.class_teachers add column if not exists id uuid default gen_random_uuid();
alter table if exists public.class_teachers add column if not exists teacher_id uuid;
alter table if exists public.class_teachers add column if not exists class_id uuid;
alter table if exists public.class_teachers add column if not exists created_at timestamptz default now();
alter table if exists public.teacher_subjects add column if not exists id uuid default gen_random_uuid();
alter table if exists public.teacher_subjects add column if not exists teacher_id uuid;
alter table if exists public.teacher_subjects add column if not exists subject_id uuid;
alter table if exists public.teacher_subjects add column if not exists created_at timestamptz default now();
alter table if exists public.weeks add column if not exists id uuid default gen_random_uuid();
alter table if exists public.weeks add column if not exists name text;
alter table if exists public.weeks add column if not exists start_date date;
alter table if exists public.weeks add column if not exists end_date date;
alter table if exists public.weeks add column if not exists term_id uuid;
alter table if exists public.weeks add column if not exists session_id uuid;
alter table if exists public.weeks add column if not exists created_at timestamptz default now();
alter table if exists public.assessments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.assessments add column if not exists student_id uuid;
alter table if exists public.assessments add column if not exists subject_id uuid;
alter table if exists public.assessments add column if not exists week_id uuid;
alter table if exists public.assessments add column if not exists teacher_id uuid;
alter table if exists public.assessments add column if not exists assignment_score numeric default 0;
alter table if exists public.assessments add column if not exists test_score numeric default 0;
alter table if exists public.assessments add column if not exists created_at timestamptz default now();
alter table if exists public.assessments add column if not exists updated_at timestamptz default now();
alter table if exists public.midterm_assessments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.midterm_assessments add column if not exists student_id uuid;
alter table if exists public.midterm_assessments add column if not exists class_id uuid;
alter table if exists public.midterm_assessments add column if not exists subject_id uuid;
alter table if exists public.midterm_assessments add column if not exists term_id uuid;
alter table if exists public.midterm_assessments add column if not exists session_id uuid;
alter table if exists public.midterm_assessments add column if not exists teacher_id uuid;
alter table if exists public.midterm_assessments add column if not exists major_test_score numeric;
alter table if exists public.midterm_assessments add column if not exists created_at timestamptz default now();
alter table if exists public.midterm_assessments add column if not exists updated_at timestamptz default now();
alter table if exists public.quizzes add column if not exists id uuid default gen_random_uuid();
alter table if exists public.quizzes add column if not exists title text;
alter table if exists public.quizzes add column if not exists class_id uuid;
alter table if exists public.quizzes add column if not exists subject_id uuid;
alter table if exists public.quizzes add column if not exists week_id uuid;
alter table if exists public.quizzes add column if not exists teacher_id uuid;
alter table if exists public.quizzes add column if not exists duration_minutes int default 30;
alter table if exists public.quizzes add column if not exists max_score numeric default 10;
alter table if exists public.quizzes add column if not exists pass_score numeric default 5;
alter table if exists public.quizzes add column if not exists status text default 'draft';
alter table if exists public.quizzes add column if not exists shuffle_questions boolean default true;
alter table if exists public.quizzes add column if not exists shuffle_options boolean default true;
alter table if exists public.quizzes add column if not exists attempts_allowed int default 1;
alter table if exists public.quizzes add column if not exists quiz_type text default 'weekly';
alter table if exists public.quizzes add column if not exists term_id text;
alter table if exists public.quizzes add column if not exists session_id text;
alter table if exists public.quizzes add column if not exists created_at timestamptz default now();
alter table if exists public.quizzes add column if not exists updated_at timestamptz default now();
alter table if exists public.quiz_questions add column if not exists id uuid default gen_random_uuid();
alter table if exists public.quiz_questions add column if not exists quiz_id uuid;
alter table if exists public.quiz_questions add column if not exists question_no int;
alter table if exists public.quiz_questions add column if not exists question_text text;
alter table if exists public.quiz_questions add column if not exists option_a text;
alter table if exists public.quiz_questions add column if not exists option_b text;
alter table if exists public.quiz_questions add column if not exists option_c text;
alter table if exists public.quiz_questions add column if not exists option_d text;
alter table if exists public.quiz_questions add column if not exists correct_answer text;
alter table if exists public.quiz_questions add column if not exists topic text;
alter table if exists public.quiz_questions add column if not exists marks numeric default 1;
alter table if exists public.quiz_questions add column if not exists created_at timestamptz default now();
alter table if exists public.quiz_attempts add column if not exists id uuid default gen_random_uuid();
alter table if exists public.quiz_attempts add column if not exists quiz_id uuid;
alter table if exists public.quiz_attempts add column if not exists student_id uuid;
alter table if exists public.quiz_attempts add column if not exists started_at timestamptz;
alter table if exists public.quiz_attempts add column if not exists submitted_at timestamptz;
alter table if exists public.quiz_attempts add column if not exists score numeric;
alter table if exists public.quiz_attempts add column if not exists percentage numeric;
alter table if exists public.quiz_attempts add column if not exists correct_count int;
alter table if exists public.quiz_attempts add column if not exists total_questions int;
alter table if exists public.quiz_attempts add column if not exists status text;
alter table if exists public.quiz_attempts add column if not exists answers jsonb;
alter table if exists public.quiz_attempts add column if not exists created_at timestamptz default now();
alter table if exists public.teacher_feedback add column if not exists id uuid default gen_random_uuid();
alter table if exists public.teacher_feedback add column if not exists teacher_id uuid;
alter table if exists public.teacher_feedback add column if not exists admin_id text;
alter table if exists public.teacher_feedback add column if not exists subject text;
alter table if exists public.teacher_feedback add column if not exists message text;
alter table if exists public.teacher_feedback add column if not exists status text default 'unread';
alter table if exists public.teacher_feedback add column if not exists reply text;
alter table if exists public.teacher_feedback add column if not exists replied_at timestamptz;
alter table if exists public.teacher_feedback add column if not exists created_at timestamptz default now();
alter table if exists public.nursery_observations add column if not exists id uuid default gen_random_uuid();
alter table if exists public.nursery_observations add column if not exists class_id text;
alter table if exists public.nursery_observations add column if not exists student_id text;
alter table if exists public.nursery_observations add column if not exists subject_id text;
alter table if exists public.nursery_observations add column if not exists week_id text;
alter table if exists public.nursery_observations add column if not exists session_id text;
alter table if exists public.nursery_observations add column if not exists topics text;
alter table if exists public.nursery_observations add column if not exists materials text;
alter table if exists public.nursery_observations add column if not exists engagement text;
alter table if exists public.nursery_observations add column if not exists observation text;
alter table if exists public.nursery_observations add column if not exists teacher_id text;
alter table if exists public.nursery_observations add column if not exists created_at timestamptz default now();
alter table if exists public.nursery_observations add column if not exists updated_at timestamptz default now();
alter table if exists public.nursery_week_notes add column if not exists id uuid default gen_random_uuid();
alter table if exists public.nursery_week_notes add column if not exists student_id text;
alter table if exists public.nursery_week_notes add column if not exists week_id text;
alter table if exists public.nursery_week_notes add column if not exists class_id text;
alter table if exists public.nursery_week_notes add column if not exists session_id text;
alter table if exists public.nursery_week_notes add column if not exists teacher_id text;
alter table if exists public.nursery_week_notes add column if not exists age text;
alter table if exists public.nursery_week_notes add column if not exists general_notes text;
alter table if exists public.nursery_week_notes add column if not exists next_steps text;
alter table if exists public.nursery_week_notes add column if not exists created_at timestamptz default now();
alter table if exists public.nursery_week_notes add column if not exists updated_at timestamptz default now();
alter table if exists public.weekly_topics add column if not exists id uuid default gen_random_uuid();
alter table if exists public.weekly_topics add column if not exists class_id text;
alter table if exists public.weekly_topics add column if not exists week_id text;
alter table if exists public.weekly_topics add column if not exists subject_id text;
alter table if exists public.weekly_topics add column if not exists topic text;
alter table if exists public.weekly_topics add column if not exists teacher_id text;
alter table if exists public.weekly_topics add column if not exists updated_at timestamptz default now();
alter table if exists public.weekly_topics add column if not exists created_at timestamptz default now();
alter table if exists public.weekly_comments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.weekly_comments add column if not exists student_id text;
alter table if exists public.weekly_comments add column if not exists week_id text;
alter table if exists public.weekly_comments add column if not exists comment text;
alter table if exists public.weekly_comments add column if not exists teacher_id text;
alter table if exists public.weekly_comments add column if not exists created_at timestamptz default now();
alter table if exists public.weekly_comments add column if not exists updated_at timestamptz default now();
alter table if exists public.term_scores add column if not exists id uuid default gen_random_uuid();
alter table if exists public.term_scores add column if not exists student_id text;
alter table if exists public.term_scores add column if not exists class_id text;
alter table if exists public.term_scores add column if not exists subject_id text;
alter table if exists public.term_scores add column if not exists term_id text;
alter table if exists public.term_scores add column if not exists session_id text;
alter table if exists public.term_scores add column if not exists test1 numeric;
alter table if exists public.term_scores add column if not exists test1_manual numeric;
alter table if exists public.term_scores add column if not exists test2 numeric;
alter table if exists public.term_scores add column if not exists project numeric;
alter table if exists public.term_scores add column if not exists assignment_manual numeric;
alter table if exists public.term_scores add column if not exists assignment_auto numeric;
alter table if exists public.term_scores add column if not exists exam numeric;
alter table if exists public.term_scores add column if not exists teacher_id text;
alter table if exists public.term_scores add column if not exists updated_at timestamptz default now();
alter table if exists public.term_scores add column if not exists created_at timestamptz default now();
alter table if exists public.result_publications add column if not exists id uuid default gen_random_uuid();
alter table if exists public.result_publications add column if not exists class_id text;
alter table if exists public.result_publications add column if not exists term_id text;
alter table if exists public.result_publications add column if not exists session_id text;
alter table if exists public.result_publications add column if not exists is_published boolean default false;
alter table if exists public.result_publications add column if not exists published_at timestamptz;
alter table if exists public.result_publications add column if not exists published_by text;
alter table if exists public.result_publications add column if not exists updated_at timestamptz default now();
alter table if exists public.result_blocks add column if not exists student_id text;
alter table if exists public.result_blocks add column if not exists is_blocked boolean default true;
alter table if exists public.result_blocks add column if not exists reason text;
alter table if exists public.result_blocks add column if not exists blocked_by text;
alter table if exists public.result_blocks add column if not exists updated_at timestamptz default now();
alter table if exists public.ca_records add column if not exists id uuid default gen_random_uuid();
alter table if exists public.ca_records add column if not exists student_id text;
alter table if exists public.ca_records add column if not exists class_id text;
alter table if exists public.ca_records add column if not exists subject_id text;
alter table if exists public.ca_records add column if not exists term_id text;
alter table if exists public.ca_records add column if not exists session_id text;
alter table if exists public.ca_records add column if not exists test numeric;
alter table if exists public.ca_records add column if not exists takehome numeric;
alter table if exists public.ca_records add column if not exists quiz numeric;
alter table if exists public.ca_records add column if not exists debate numeric;
alter table if exists public.ca_records add column if not exists project numeric;
alter table if exists public.ca_records add column if not exists attendance numeric;
alter table if exists public.ca_records add column if not exists appearance numeric;
alter table if exists public.ca_records add column if not exists honesty numeric;
alter table if exists public.ca_records add column if not exists punctuality numeric;
alter table if exists public.ca_records add column if not exists relationship numeric;
alter table if exists public.ca_records add column if not exists notecopying numeric;
alter table if exists public.ca_records add column if not exists practical numeric;
alter table if exists public.ca_records add column if not exists exam numeric;
alter table if exists public.ca_records add column if not exists test2 numeric;
alter table if exists public.ca_records add column if not exists assignproject numeric;
alter table if exists public.ca_records add column if not exists teacher_id text;
alter table if exists public.ca_records add column if not exists updated_at timestamptz default now();
alter table if exists public.midterm_remarks add column if not exists id uuid default gen_random_uuid();
alter table if exists public.midterm_remarks add column if not exists student_id text;
alter table if exists public.midterm_remarks add column if not exists class_id text;
alter table if exists public.midterm_remarks add column if not exists term_id text;
alter table if exists public.midterm_remarks add column if not exists session_id text;
alter table if exists public.midterm_remarks add column if not exists general_observation text;
alter table if exists public.midterm_remarks add column if not exists recommendation text;
alter table if exists public.midterm_remarks add column if not exists teacher_id text;
alter table if exists public.midterm_remarks add column if not exists updated_at timestamptz default now();
alter table if exists public.midterm_remarks add column if not exists created_at timestamptz default now();
alter table if exists public.early_midterm_reports add column if not exists id uuid default gen_random_uuid();
alter table if exists public.early_midterm_reports add column if not exists student_id text;
alter table if exists public.early_midterm_reports add column if not exists class_id text;
alter table if exists public.early_midterm_reports add column if not exists session_id text;
alter table if exists public.early_midterm_reports add column if not exists term_id text;
alter table if exists public.early_midterm_reports add column if not exists teacher_id text;
alter table if exists public.early_midterm_reports add column if not exists class_teacher text;
alter table if exists public.early_midterm_reports add column if not exists report_date date;
alter table if exists public.early_midterm_reports add column if not exists ratings jsonb;
alter table if exists public.early_midterm_reports add column if not exists strengths text;
alter table if exists public.early_midterm_reports add column if not exists improvements text;
alter table if exists public.early_midterm_reports add column if not exists strategies text;
alter table if exists public.early_midterm_reports add column if not exists comment text;
alter table if exists public.early_midterm_reports add column if not exists updated_at timestamptz default now();
alter table if exists public.early_midterm_reports add column if not exists created_at timestamptz default now();
alter table if exists public.assignments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.assignments add column if not exists title text;
alter table if exists public.assignments add column if not exists instructions text;
alter table if exists public.assignments add column if not exists assignment_type text default 'file';
alter table if exists public.assignments add column if not exists quiz_id text;
alter table if exists public.assignments add column if not exists class_id text;
alter table if exists public.assignments add column if not exists class_name text;
alter table if exists public.assignments add column if not exists subject_id text;
alter table if exists public.assignments add column if not exists subject_name text;
alter table if exists public.assignments add column if not exists week_id text;
alter table if exists public.assignments add column if not exists week_name text;
alter table if exists public.assignments add column if not exists teacher_id text;
alter table if exists public.assignments add column if not exists teacher_name text;
alter table if exists public.assignments add column if not exists due_date timestamptz;
alter table if exists public.assignments add column if not exists max_score numeric default 10;
alter table if exists public.assignments add column if not exists attachments jsonb default '[]'::jsonb;
alter table if exists public.assignments add column if not exists created_at timestamptz default now();
alter table if exists public.assignment_submissions add column if not exists id uuid default gen_random_uuid();
alter table if exists public.assignment_submissions add column if not exists assignment_id text;
alter table if exists public.assignment_submissions add column if not exists student_id text;
alter table if exists public.assignment_submissions add column if not exists student_name text;
alter table if exists public.assignment_submissions add column if not exists class_name text;
alter table if exists public.assignment_submissions add column if not exists note text;
alter table if exists public.assignment_submissions add column if not exists files jsonb default '[]'::jsonb;
alter table if exists public.assignment_submissions add column if not exists status text default 'submitted';
alter table if exists public.assignment_submissions add column if not exists is_late boolean default false;
alter table if exists public.assignment_submissions add column if not exists score numeric;
alter table if exists public.assignment_submissions add column if not exists feedback text;
alter table if exists public.assignment_submissions add column if not exists graded_by text;
alter table if exists public.assignment_submissions add column if not exists graded_at timestamptz;
alter table if exists public.assignment_submissions add column if not exists submitted_at timestamptz default now();
alter table if exists public.daily_story_class add column if not exists id uuid default gen_random_uuid();
alter table if exists public.daily_story_class add column if not exists class_id text;
alter table if exists public.daily_story_class add column if not exists story_date date;
alter table if exists public.daily_story_class add column if not exists teacher_id text;
alter table if exists public.daily_story_class add column if not exists teacher_name text;
alter table if exists public.daily_story_class add column if not exists subjects jsonb default '[]'::jsonb;
alter table if exists public.daily_story_class add column if not exists activity text;
alter table if exists public.daily_story_class add column if not exists media jsonb default '[]'::jsonb;
alter table if exists public.daily_story_class add column if not exists media_note text;
alter table if exists public.daily_story_class add column if not exists homework text;
alter table if exists public.daily_story_class add column if not exists homework_due date;
alter table if exists public.daily_story_class add column if not exists class_message text;
alter table if exists public.daily_story_class add column if not exists published boolean default false;
alter table if exists public.daily_story_class add column if not exists published_at timestamptz;
alter table if exists public.daily_story_class add column if not exists updated_at timestamptz default now();
alter table if exists public.daily_story_class add column if not exists created_at timestamptz default now();
alter table if exists public.daily_story_student add column if not exists id uuid default gen_random_uuid();
alter table if exists public.daily_story_student add column if not exists student_id text;
alter table if exists public.daily_story_student add column if not exists class_id text;
alter table if exists public.daily_story_student add column if not exists story_date date;
alter table if exists public.daily_story_student add column if not exists attendance text;
alter table if exists public.daily_story_student add column if not exists participation text;
alter table if exists public.daily_story_student add column if not exists behaviour text;
alter table if exists public.daily_story_student add column if not exists wellbeing text;
alter table if exists public.daily_story_student add column if not exists skills jsonb default '[]'::jsonb;
alter table if exists public.daily_story_student add column if not exists achievements jsonb default '[]'::jsonb;
alter table if exists public.daily_story_student add column if not exists teacher_message text;
alter table if exists public.daily_story_student add column if not exists teacher_reply text;
alter table if exists public.daily_story_student add column if not exists replied_at timestamptz;
alter table if exists public.daily_story_student add column if not exists montessori jsonb default '{}'::jsonb;
alter table if exists public.daily_story_student add column if not exists parent_feedback text;
alter table if exists public.daily_story_student add column if not exists parent_feedback_at timestamptz;
alter table if exists public.daily_story_student add column if not exists updated_at timestamptz default now();
alter table if exists public.daily_story_student add column if not exists created_at timestamptz default now();
alter table if exists public.exam_inbox add column if not exists id uuid default gen_random_uuid();
alter table if exists public.exam_inbox add column if not exists teacher_id text;
alter table if exists public.exam_inbox add column if not exists teacher_name text;
alter table if exists public.exam_inbox add column if not exists sender_role text;
alter table if exists public.exam_inbox add column if not exists message_type text;
alter table if exists public.exam_inbox add column if not exists title text;
alter table if exists public.exam_inbox add column if not exists class_level text;
alter table if exists public.exam_inbox add column if not exists note text;
alter table if exists public.exam_inbox add column if not exists parent_id text;
alter table if exists public.exam_inbox add column if not exists created_at timestamptz default now();
alter table if exists public.exam_inbox_files add column if not exists id uuid default gen_random_uuid();
alter table if exists public.exam_inbox_files add column if not exists message_id text;
alter table if exists public.exam_inbox_files add column if not exists teacher_id text;
alter table if exists public.exam_inbox_files add column if not exists file_path text;
alter table if exists public.exam_inbox_files add column if not exists file_name text;
alter table if exists public.exam_inbox_files add column if not exists file_size bigint;
alter table if exists public.exam_inbox_files add column if not exists created_at timestamptz default now();
alter table if exists public.enotes add column if not exists id uuid default gen_random_uuid();
alter table if exists public.enotes add column if not exists title text;
alter table if exists public.enotes add column if not exists class_id text;
alter table if exists public.enotes add column if not exists subject_id text;
alter table if exists public.enotes add column if not exists subject_name text;
alter table if exists public.enotes add column if not exists teacher_id text;
alter table if exists public.enotes add column if not exists teacher_name text;
alter table if exists public.enotes add column if not exists content text;
alter table if exists public.enotes add column if not exists video_url text;
alter table if exists public.enotes add column if not exists link_url text;
alter table if exists public.enotes add column if not exists live_url text;
alter table if exists public.enotes add column if not exists live_time text;
alter table if exists public.enotes add column if not exists attachments jsonb default '[]'::jsonb;
alter table if exists public.enotes add column if not exists published boolean default true;
alter table if exists public.enotes add column if not exists created_at timestamptz default now();
alter table if exists public.enotes add column if not exists updated_at timestamptz default now();
alter table if exists public.enote_comments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.enote_comments add column if not exists note_id text;
alter table if exists public.enote_comments add column if not exists author_id text;
alter table if exists public.enote_comments add column if not exists author_name text;
alter table if exists public.enote_comments add column if not exists author_role text;
alter table if exists public.enote_comments add column if not exists body text;
alter table if exists public.enote_comments add column if not exists created_at timestamptz default now();
alter table if exists public.enote_reads add column if not exists note_id text;
alter table if exists public.enote_reads add column if not exists student_id text;
alter table if exists public.enote_reads add column if not exists student_name text;
alter table if exists public.enote_reads add column if not exists understood boolean default false;
alter table if exists public.enote_reads add column if not exists read_at timestamptz default now();
alter table if exists public.lesson_plans add column if not exists id uuid default gen_random_uuid();
alter table if exists public.lesson_plans add column if not exists teacher_id text;
alter table if exists public.lesson_plans add column if not exists teacher_name text;
alter table if exists public.lesson_plans add column if not exists class_id text;
alter table if exists public.lesson_plans add column if not exists class_name text;
alter table if exists public.lesson_plans add column if not exists subject_id text;
alter table if exists public.lesson_plans add column if not exists subject_name text;
alter table if exists public.lesson_plans add column if not exists week_id text;
alter table if exists public.lesson_plans add column if not exists week_name text;
alter table if exists public.lesson_plans add column if not exists plan_date text;
alter table if exists public.lesson_plans add column if not exists duration text;
alter table if exists public.lesson_plans add column if not exists topic text;
alter table if exists public.lesson_plans add column if not exists objectives text;
alter table if exists public.lesson_plans add column if not exists prior text;
alter table if exists public.lesson_plans add column if not exists materials text;
alter table if exists public.lesson_plans add column if not exists introduction text;
alter table if exists public.lesson_plans add column if not exists development text;
alter table if exists public.lesson_plans add column if not exists evaluation text;
alter table if exists public.lesson_plans add column if not exists assignment text;
alter table if exists public.lesson_plans add column if not exists link_url text;
alter table if exists public.lesson_plans add column if not exists status text default 'draft';
alter table if exists public.lesson_plans add column if not exists teacher_seen boolean default true;
alter table if exists public.lesson_plans add column if not exists admin_seen boolean default false;
alter table if exists public.lesson_plans add column if not exists submitted_at timestamptz;
alter table if exists public.lesson_plans add column if not exists reviewed_at timestamptz;
alter table if exists public.lesson_plans add column if not exists created_at timestamptz default now();
alter table if exists public.lesson_plans add column if not exists updated_at timestamptz default now();
alter table if exists public.lesson_plan_comments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.lesson_plan_comments add column if not exists plan_id text;
alter table if exists public.lesson_plan_comments add column if not exists field text default 'general';
alter table if exists public.lesson_plan_comments add column if not exists author_id text;
alter table if exists public.lesson_plan_comments add column if not exists author_name text;
alter table if exists public.lesson_plan_comments add column if not exists author_role text;
alter table if exists public.lesson_plan_comments add column if not exists body text;
alter table if exists public.lesson_plan_comments add column if not exists resolved boolean default false;
alter table if exists public.lesson_plan_comments add column if not exists created_at timestamptz default now();
alter table if exists public.lesson_plan_files add column if not exists plan_id text;
alter table if exists public.lesson_plan_files add column if not exists teacher_id text;
alter table if exists public.lesson_plan_files add column if not exists file_name text;
alter table if exists public.lesson_plan_files add column if not exists file_type text;
alter table if exists public.lesson_plan_files add column if not exists file_data text;
alter table if exists public.lesson_plan_files add column if not exists updated_at timestamptz default now();
alter table if exists public.departments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.departments add column if not exists name text;
alter table if exists public.departments add column if not exists hod_id text;
alter table if exists public.departments add column if not exists hod_name text;
alter table if exists public.departments add column if not exists created_at timestamptz default now();
alter table if exists public.department_members add column if not exists id uuid default gen_random_uuid();
alter table if exists public.department_members add column if not exists department_id text;
alter table if exists public.department_members add column if not exists teacher_id text;
alter table if exists public.department_members add column if not exists teacher_name text;
alter table if exists public.department_members add column if not exists created_at timestamptz default now();
alter table if exists public.register_attendance add column if not exists id uuid default gen_random_uuid();
alter table if exists public.register_attendance add column if not exists student_id text;
alter table if exists public.register_attendance add column if not exists class_id text;
alter table if exists public.register_attendance add column if not exists week_id text;
alter table if exists public.register_attendance add column if not exists term_id text;
alter table if exists public.register_attendance add column if not exists session_id text;
alter table if exists public.register_attendance add column if not exists marks text default '----------';
alter table if exists public.register_attendance add column if not exists marked_by text;
alter table if exists public.register_attendance add column if not exists updated_at timestamptz default now();
alter table if exists public.register_week_meta add column if not exists class_id text;
alter table if exists public.register_week_meta add column if not exists week_id text;
alter table if exists public.register_week_meta add column if not exists closed text default '00000';
alter table if exists public.register_week_meta add column if not exists signed_by text;
alter table if exists public.register_week_meta add column if not exists signed_at timestamptz;
alter table if exists public.register_week_meta add column if not exists locked boolean default false;
alter table if exists public.register_students add column if not exists student_id text;
alter table if exists public.register_students add column if not exists gender text;
alter table if exists public.mgmt_users add column if not exists id uuid default gen_random_uuid();
alter table if exists public.mgmt_users add column if not exists name text;
alter table if exists public.mgmt_users add column if not exists email text;
alter table if exists public.mgmt_users add column if not exists password text;
alter table if exists public.mgmt_users add column if not exists position text;
alter table if exists public.mgmt_users add column if not exists phone text;
alter table if exists public.mgmt_users add column if not exists perms jsonb default '{}'::jsonb;
alter table if exists public.mgmt_users add column if not exists active boolean default true;
alter table if exists public.mgmt_users add column if not exists created_at timestamptz default now();
alter table if exists public.mgmt_users add column if not exists last_login timestamptz;
alter table if exists public.mgmt_data add column if not exists id uuid default gen_random_uuid();
alter table if exists public.mgmt_data add column if not exists term_label text;
alter table if exists public.mgmt_data add column if not exists module text;
alter table if exists public.mgmt_data add column if not exists row_key text;
alter table if exists public.mgmt_data add column if not exists data jsonb default '{}'::jsonb;
alter table if exists public.mgmt_data add column if not exists updated_by text;
alter table if exists public.mgmt_data add column if not exists updated_at timestamptz default now();
alter table if exists public.mgmt_data add column if not exists created_at timestamptz default now();
alter table if exists public.announcements add column if not exists title text;
alter table if exists public.announcements add column if not exists body text;
alter table if exists public.announcements add column if not exists audience text default 'parents';
alter table if exists public.announcements add column if not exists class_id text;
alter table if exists public.announcements add column if not exists created_by text;
alter table if exists public.announcements add column if not exists created_by_name text;
alter table if exists public.announcements add column if not exists expires_at date;
alter table if exists public.announcements add column if not exists created_at timestamptz default now();
alter table if exists public.notification_log add column if not exists kind text;
alter table if exists public.notification_log add column if not exists channel text;
alter table if exists public.notification_log add column if not exists student_id text;
alter table if exists public.notification_log add column if not exists recipient text;
alter table if exists public.notification_log add column if not exists subject text;
alter table if exists public.notification_log add column if not exists message text;
alter table if exists public.notification_log add column if not exists status text default 'queued';
alter table if exists public.notification_log add column if not exists error text;
alter table if exists public.notification_log add column if not exists created_by text;
alter table if exists public.notification_log add column if not exists created_at timestamptz default now();
alter table if exists public.notification_log add column if not exists sent_at timestamptz;
alter table if exists public.parent_feedback add column if not exists id uuid default gen_random_uuid();
alter table if exists public.parent_feedback add column if not exists student_id text;
alter table if exists public.parent_feedback add column if not exists student_login_id text;
alter table if exists public.parent_feedback add column if not exists student_name text;
alter table if exists public.parent_feedback add column if not exists parent_name text;
alter table if exists public.parent_feedback add column if not exists parent_contact text;
alter table if exists public.parent_feedback add column if not exists message text;
alter table if exists public.parent_feedback add column if not exists week_id text;
alter table if exists public.parent_feedback add column if not exists status text default 'unread';
alter table if exists public.parent_feedback add column if not exists reply text;
alter table if exists public.parent_feedback add column if not exists created_at timestamptz default now();
alter table if exists public.staff_sessions add column if not exists session_key text;
alter table if exists public.staff_sessions add column if not exists user_uid text;
alter table if exists public.staff_sessions add column if not exists name text;
alter table if exists public.staff_sessions add column if not exists role text;
alter table if exists public.staff_sessions add column if not exists position text;
alter table if exists public.staff_sessions add column if not exists sections text;
alter table if exists public.staff_sessions add column if not exists login_at timestamptz default now();
alter table if exists public.staff_sessions add column if not exists last_seen timestamptz default now();
alter table if exists public.staff_sessions add column if not exists logout_at timestamptz;
alter table if exists public.staff_sessions add column if not exists last_page text;
alter table if exists public.staff_sessions add column if not exists device text;
alter table if exists public.form_submissions add column if not exists kind text;
alter table if exists public.form_submissions add column if not exists title text;
alter table if exists public.form_submissions add column if not exists data jsonb;
alter table if exists public.form_submissions add column if not exists submitted_by text;
alter table if exists public.form_submissions add column if not exists submitted_by_name text;
alter table if exists public.form_submissions add column if not exists submitted_by_role text;
alter table if exists public.form_submissions add column if not exists created_at timestamptz default now();
alter table if exists public.form_submissions add column if not exists updated_at timestamptz;
alter table if exists public.teacher_applications add column if not exists id uuid default gen_random_uuid();
alter table if exists public.teacher_applications add column if not exists reference text;
alter table if exists public.teacher_applications add column if not exists full_name text;
alter table if exists public.teacher_applications add column if not exists gender text;
alter table if exists public.teacher_applications add column if not exists phone text;
alter table if exists public.teacher_applications add column if not exists email text;
alter table if exists public.teacher_applications add column if not exists address text;
alter table if exists public.teacher_applications add column if not exists sections text[] default '{}';
alter table if exists public.teacher_applications add column if not exists subjects text;
alter table if exists public.teacher_applications add column if not exists class_ids text[] default '{}';
alter table if exists public.teacher_applications add column if not exists class_names text;
alter table if exists public.teacher_applications add column if not exists password text;
alter table if exists public.teacher_applications add column if not exists experience_years numeric;
alter table if exists public.teacher_applications add column if not exists status text default 'pending';
alter table if exists public.teacher_applications add column if not exists review_note text;
alter table if exists public.teacher_applications add column if not exists reviewed_at timestamptz;
alter table if exists public.teacher_applications add column if not exists created_at timestamptz default now();

-- ---------------------------------------------------------------------
-- 3. FEATURE TABLES (all ids stored as text, so they work with any id type)
-- ---------------------------------------------------------------------

-- ---- Nursery observations (the table named in your error) ----
create table if not exists public.nursery_observations(
  id uuid primary key default gen_random_uuid(),
  class_id text, student_id text, subject_id text, week_id text, session_id text,
  topics text, materials text, engagement text, observation text,
  teacher_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now());
do $$ begin create index if not exists nursery_obs_student_week_idx on public.nursery_observations(student_id, week_id); exception when others then raise notice 'index skipped: %', sqlerrm; end $$;
do $$ begin create index if not exists nursery_obs_class_idx        on public.nursery_observations(class_id); exception when others then raise notice 'index skipped: %', sqlerrm; end $$;

create table if not exists public.nursery_week_notes(
  id uuid primary key default gen_random_uuid(),
  student_id text, week_id text, class_id text, session_id text, teacher_id text,
  age text, general_notes text, next_steps text,
  created_at timestamptz default now(),
  updated_at timestamptz default now());
do $$ begin create index if not exists nursery_notes_student_week_idx on public.nursery_week_notes(student_id, week_id); exception when others then raise notice 'index skipped: %', sqlerrm; end $$;

-- ---- Weekly topics + comments ----
create table if not exists public.weekly_topics(
  id uuid primary key default gen_random_uuid(),
  class_id text, week_id text, subject_id text, topic text, teacher_id text,
  updated_at timestamptz default now(), created_at timestamptz default now());

create table if not exists public.weekly_comments(
  id uuid primary key default gen_random_uuid(),
  student_id text, week_id text, comment text, teacher_id text,
  created_at timestamptz default now(), updated_at timestamptz default now());

-- ---- Termly report card ----
create table if not exists public.term_scores(
  id uuid primary key default gen_random_uuid(),
  student_id text, class_id text, subject_id text, term_id text, session_id text,
  test1 numeric, test1_manual numeric, test2 numeric, project numeric,
  assignment_manual numeric, assignment_auto numeric, exam numeric,
  teacher_id text,
  updated_at timestamptz default now(), created_at timestamptz default now());
alter table public.term_scores add column if not exists test1_manual numeric;
alter table public.term_scores add column if not exists assignment_manual numeric;
alter table public.term_scores add column if not exists assignment_auto numeric;
alter table public.term_scores add column if not exists test1 numeric;
alter table public.term_scores add column if not exists test2 numeric;
alter table public.term_scores add column if not exists project numeric;
alter table public.term_scores add column if not exists exam numeric;
alter table public.term_scores add column if not exists teacher_id text;
alter table public.term_scores add column if not exists class_id text;

create table if not exists public.result_publications(
  id uuid primary key default gen_random_uuid(),
  class_id text, term_id text, session_id text,
  is_published boolean default false,
  published_at timestamptz, published_by text,
  updated_at timestamptz default now());

create table if not exists public.result_blocks(
  student_id text primary key,
  is_blocked boolean not null default true,
  reason text, blocked_by text,
  updated_at timestamptz default now());

create table if not exists public.ca_records(
  id uuid primary key default gen_random_uuid(),
  student_id text not null, class_id text,
  subject_id text not null, term_id text not null, session_id text not null,
  test numeric, takehome numeric, quiz numeric, debate numeric, project numeric,
  attendance numeric, appearance numeric, honesty numeric, punctuality numeric, relationship numeric,
  notecopying numeric, practical numeric, exam numeric,
  test2 numeric, assignproject numeric,
  teacher_id text, updated_at timestamptz default now());
alter table public.ca_records add column if not exists test2 numeric;
alter table public.ca_records add column if not exists assignproject numeric;

-- ---- Mid-term ----
create table if not exists public.midterm_remarks(
  id uuid primary key default gen_random_uuid(),
  student_id text, class_id text, term_id text, session_id text,
  general_observation text, recommendation text, teacher_id text,
  updated_at timestamptz default now(), created_at timestamptz default now());

create table if not exists public.early_midterm_reports(
  id uuid primary key default gen_random_uuid(),
  student_id text, class_id text, session_id text, term_id text, teacher_id text,
  class_teacher text, report_date date, ratings jsonb,
  strengths text, improvements text, strategies text, comment text,
  updated_at timestamptz default now(), created_at timestamptz default now());

-- ---- Assignments ----
create table if not exists public.assignments(
  id uuid primary key default gen_random_uuid(),
  title text, instructions text,
  assignment_type text default 'file',
  quiz_id text,
  class_id text, class_name text,
  subject_id text, subject_name text,
  week_id text, week_name text,
  teacher_id text, teacher_name text,
  due_date timestamptz, max_score numeric default 10,
  attachments jsonb default '[]'::jsonb,
  created_at timestamptz default now());

create table if not exists public.assignment_submissions(
  id uuid primary key default gen_random_uuid(),
  assignment_id text, student_id text, student_name text, class_name text,
  note text, files jsonb default '[]'::jsonb,
  status text default 'submitted', is_late boolean default false,
  score numeric, feedback text, graded_by text, graded_at timestamptz,
  submitted_at timestamptz default now());

-- ---- Daily story ----
create table if not exists public.daily_story_class(
  id uuid primary key default gen_random_uuid(),
  class_id text, story_date date,
  teacher_id text, teacher_name text,
  subjects jsonb default '[]'::jsonb, activity text,
  media jsonb default '[]'::jsonb, media_note text,
  homework text, homework_due date, class_message text,
  published boolean default false, published_at timestamptz,
  updated_at timestamptz default now(), created_at timestamptz default now());

create table if not exists public.daily_story_student(
  id uuid primary key default gen_random_uuid(),
  student_id text, class_id text, story_date date,
  attendance text, participation text, behaviour text, wellbeing text,
  skills jsonb default '[]'::jsonb, achievements jsonb default '[]'::jsonb,
  teacher_message text, teacher_reply text, replied_at timestamptz,
  montessori jsonb default '{}'::jsonb,
  parent_feedback text, parent_feedback_at timestamptz,
  updated_at timestamptz default now(), created_at timestamptz default now());

-- ---- Exam inbox ----
create table if not exists public.exam_inbox(
  id uuid primary key default gen_random_uuid(),
  teacher_id text, teacher_name text, sender_role text, message_type text,
  title text, class_level text, note text, parent_id text,
  created_at timestamptz default now());

create table if not exists public.exam_inbox_files(
  id uuid primary key default gen_random_uuid(),
  message_id text, teacher_id text,
  file_path text, file_name text, file_size bigint,
  created_at timestamptz default now());

-- ---- E-notes ----
create table if not exists public.enotes(
  id uuid primary key default gen_random_uuid(),
  title text not null, class_id text not null, subject_id text, subject_name text,
  teacher_id text, teacher_name text, content text, video_url text, link_url text,
  live_url text, live_time text, attachments jsonb default '[]'::jsonb, published boolean default true,
  created_at timestamptz default now(), updated_at timestamptz default now());
alter table public.enotes add column if not exists attachments jsonb default '[]'::jsonb;

create table if not exists public.enote_comments(
  id uuid primary key default gen_random_uuid(),
  note_id text not null, author_id text, author_name text, author_role text,
  body text not null, created_at timestamptz default now());

create table if not exists public.enote_reads(
  note_id text not null, student_id text not null, student_name text,
  understood boolean default false, read_at timestamptz default now(),
  primary key(note_id, student_id));

-- ---- Lesson plans / departments ----
create table if not exists public.lesson_plans(
  id uuid primary key default gen_random_uuid(),
  teacher_id text not null, teacher_name text,
  class_id text, class_name text, subject_id text, subject_name text,
  week_id text, week_name text, plan_date text, duration text,
  topic text, objectives text, prior text, materials text, introduction text,
  development text, evaluation text, assignment text, link_url text,
  status text default 'draft', teacher_seen boolean default true, admin_seen boolean default false,
  submitted_at timestamptz, reviewed_at timestamptz,
  created_at timestamptz default now(), updated_at timestamptz default now());
alter table public.lesson_plans add column if not exists hod_checked boolean default false;
alter table public.lesson_plans add column if not exists hod_checked_by text;
alter table public.lesson_plans add column if not exists hod_checked_at timestamptz;
alter table public.lesson_plans add column if not exists hod_seen boolean default false;
alter table public.lesson_plans add column if not exists reviewed_by text;
alter table public.lesson_plans add column if not exists reviewed_role text;

create table if not exists public.lesson_plan_comments(
  id uuid primary key default gen_random_uuid(),
  plan_id text not null, field text default 'general',
  author_id text, author_name text, author_role text,
  body text not null, resolved boolean default false,
  created_at timestamptz default now());

create table if not exists public.lesson_plan_files(
  plan_id text primary key, teacher_id text,
  file_name text, file_type text, file_data text,
  updated_at timestamptz default now());

create table if not exists public.departments(
  id uuid primary key default gen_random_uuid(),
  name text not null, hod_id text, hod_name text,
  created_at timestamptz default now());

create table if not exists public.department_members(
  id uuid primary key default gen_random_uuid(),
  department_id text not null, teacher_id text not null, teacher_name text,
  created_at timestamptz default now(),
  unique(department_id, teacher_id));

do $$ begin create index if not exists idx_lp_teacher  on public.lesson_plans(teacher_id); exception when others then raise notice 'index skipped: %', sqlerrm; end $$;
do $$ begin create index if not exists idx_lp_status   on public.lesson_plans(status); exception when others then raise notice 'index skipped: %', sqlerrm; end $$;
do $$ begin create index if not exists idx_lpc_plan    on public.lesson_plan_comments(plan_id); exception when others then raise notice 'index skipped: %', sqlerrm; end $$;

-- ---- Attendance register ----
create table if not exists public.register_attendance(
  id uuid primary key default gen_random_uuid(),
  student_id text not null, class_id text, week_id text not null,
  term_id text, session_id text,
  marks text not null default '----------',
  marked_by text, updated_at timestamptz default now(),
  unique(student_id, week_id));

create table if not exists public.register_week_meta(
  class_id text not null, week_id text not null,
  closed text default '00000', signed_by text, signed_at timestamptz,
  locked boolean default false, primary key(class_id, week_id));

create table if not exists public.register_students(
  student_id text primary key, gender text);

-- ---- Management portal ----
create table if not exists public.mgmt_users(
  id uuid primary key default gen_random_uuid(),
  name text not null, email text not null unique, password text not null,
  position text, phone text, perms jsonb default '{}'::jsonb,
  active boolean default true, created_at timestamptz default now(), last_login timestamptz);

create table if not exists public.mgmt_data(
  id uuid primary key default gen_random_uuid(),
  term_label text not null, module text not null, row_key text not null,
  data jsonb default '{}'::jsonb, updated_by text,
  updated_at timestamptz default now(), created_at timestamptz default now(),
  unique(term_label, module, row_key));

-- ---- Notices, alerts, parent feedback, staff activity, saved forms ----
create table if not exists public.announcements(
  id bigint generated by default as identity primary key,
  title text, body text not null,
  audience text not null default 'parents',
  class_id text, created_by text, created_by_name text,
  expires_at date, created_at timestamptz default now());

create table if not exists public.notification_log(
  id bigint generated by default as identity primary key,
  kind text, channel text, student_id text, recipient text,
  subject text, message text, status text default 'queued',
  error text, created_by text,
  created_at timestamptz default now(), sent_at timestamptz);
alter table public.notification_log add column if not exists attachment_url text;

create table if not exists public.parent_feedback(
  id uuid primary key default gen_random_uuid(),
  student_id text, student_login_id text, student_name text,
  parent_name text, parent_contact text, message text, week_id text,
  status text default 'unread', reply text,
  created_at timestamptz default now());

create table if not exists public.staff_sessions(
  id bigint generated by default as identity primary key,
  session_key text not null unique,
  user_uid text not null, name text, role text, position text, sections text,
  login_at timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  logout_at timestamptz, last_page text, device text);
do $$ begin create index if not exists staff_sessions_login_idx on public.staff_sessions(login_at desc); exception when others then raise notice 'index skipped: %', sqlerrm; end $$;

create table if not exists public.form_submissions(
  id bigint generated by default as identity primary key,
  kind text not null, title text, data jsonb not null,
  submitted_by text, submitted_by_name text, submitted_by_role text,
  created_at timestamptz default now(), updated_at timestamptz);

-- ---- Teacher applications ----
create table if not exists public.teacher_applications(
  id uuid primary key default gen_random_uuid(),
  reference text, full_name text not null, gender text, phone text,
  email text not null, address text,
  sections text[] not null default '{}', subjects text,
  class_ids text[] not null default '{}', class_names text,
  password text, experience_years numeric,
  status text not null default 'pending',
  review_note text, reviewed_at timestamptz,
  created_at timestamptz not null default now());
alter table public.teacher_applications add column if not exists class_ids text[] not null default '{}';
alter table public.teacher_applications add column if not exists class_names text;
alter table public.teacher_applications add column if not exists password text;

-- ---------------------------------------------------------------------
-- 2c. COMPLETE ANY TABLE THAT ALREADY EXISTS WITH FEWER COLUMNS
--     (auto-generated: every column the app needs, added only if missing)
-- ---------------------------------------------------------------------
alter table if exists public.sessions add column if not exists id uuid default gen_random_uuid();
alter table if exists public.sessions add column if not exists name text;
alter table if exists public.sessions add column if not exists is_active boolean default false;
alter table if exists public.sessions add column if not exists created_at timestamptz default now();
alter table if exists public.terms add column if not exists id uuid default gen_random_uuid();
alter table if exists public.terms add column if not exists name text;
alter table if exists public.terms add column if not exists session_id uuid;
alter table if exists public.terms add column if not exists created_at timestamptz default now();
alter table if exists public.classes add column if not exists id uuid default gen_random_uuid();
alter table if exists public.classes add column if not exists name text;
alter table if exists public.classes add column if not exists section text;
alter table if exists public.classes add column if not exists class_teacher_id text;
alter table if exists public.classes add column if not exists created_at timestamptz default now();
alter table if exists public.subjects add column if not exists id uuid default gen_random_uuid();
alter table if exists public.subjects add column if not exists name text;
alter table if exists public.subjects add column if not exists level text;
alter table if exists public.subjects add column if not exists sections text[] default '{}';
alter table if exists public.subjects add column if not exists class_ids text[] default '{}';
alter table if exists public.subjects add column if not exists created_at timestamptz default now();
alter table if exists public.teachers add column if not exists id uuid default gen_random_uuid();
alter table if exists public.teachers add column if not exists name text;
alter table if exists public.teachers add column if not exists email text;
alter table if exists public.teachers add column if not exists password text;
alter table if exists public.teachers add column if not exists role text default 'teacher';
alter table if exists public.teachers add column if not exists school_sections text[] default '{}';
alter table if exists public.teachers add column if not exists subject_id text;
alter table if exists public.teachers add column if not exists created_at timestamptz default now();
alter table if exists public.students add column if not exists id uuid default gen_random_uuid();
alter table if exists public.students add column if not exists name text;
alter table if exists public.students add column if not exists class_id uuid;
alter table if exists public.students add column if not exists student_login_id text;
alter table if exists public.students add column if not exists student_password text;
alter table if exists public.students add column if not exists parent_name text;
alter table if exists public.students add column if not exists parent_phone text;
alter table if exists public.students add column if not exists parent_email text;
alter table if exists public.students add column if not exists created_at timestamptz default now();
alter table if exists public.class_teachers add column if not exists id uuid default gen_random_uuid();
alter table if exists public.class_teachers add column if not exists teacher_id uuid;
alter table if exists public.class_teachers add column if not exists class_id uuid;
alter table if exists public.class_teachers add column if not exists created_at timestamptz default now();
alter table if exists public.teacher_subjects add column if not exists id uuid default gen_random_uuid();
alter table if exists public.teacher_subjects add column if not exists teacher_id uuid;
alter table if exists public.teacher_subjects add column if not exists subject_id uuid;
alter table if exists public.teacher_subjects add column if not exists created_at timestamptz default now();
alter table if exists public.weeks add column if not exists id uuid default gen_random_uuid();
alter table if exists public.weeks add column if not exists name text;
alter table if exists public.weeks add column if not exists start_date date;
alter table if exists public.weeks add column if not exists end_date date;
alter table if exists public.weeks add column if not exists term_id uuid;
alter table if exists public.weeks add column if not exists session_id uuid;
alter table if exists public.weeks add column if not exists created_at timestamptz default now();
alter table if exists public.assessments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.assessments add column if not exists student_id uuid;
alter table if exists public.assessments add column if not exists subject_id uuid;
alter table if exists public.assessments add column if not exists week_id uuid;
alter table if exists public.assessments add column if not exists teacher_id uuid;
alter table if exists public.assessments add column if not exists assignment_score numeric default 0;
alter table if exists public.assessments add column if not exists test_score numeric default 0;
alter table if exists public.assessments add column if not exists created_at timestamptz default now();
alter table if exists public.assessments add column if not exists updated_at timestamptz default now();
alter table if exists public.midterm_assessments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.midterm_assessments add column if not exists student_id uuid;
alter table if exists public.midterm_assessments add column if not exists class_id uuid;
alter table if exists public.midterm_assessments add column if not exists subject_id uuid;
alter table if exists public.midterm_assessments add column if not exists term_id uuid;
alter table if exists public.midterm_assessments add column if not exists session_id uuid;
alter table if exists public.midterm_assessments add column if not exists teacher_id uuid;
alter table if exists public.midterm_assessments add column if not exists major_test_score numeric;
alter table if exists public.midterm_assessments add column if not exists created_at timestamptz default now();
alter table if exists public.midterm_assessments add column if not exists updated_at timestamptz default now();
alter table if exists public.quizzes add column if not exists id uuid default gen_random_uuid();
alter table if exists public.quizzes add column if not exists title text;
alter table if exists public.quizzes add column if not exists class_id uuid;
alter table if exists public.quizzes add column if not exists subject_id uuid;
alter table if exists public.quizzes add column if not exists week_id uuid;
alter table if exists public.quizzes add column if not exists teacher_id uuid;
alter table if exists public.quizzes add column if not exists duration_minutes int default 30;
alter table if exists public.quizzes add column if not exists max_score numeric default 10;
alter table if exists public.quizzes add column if not exists pass_score numeric default 5;
alter table if exists public.quizzes add column if not exists status text default 'draft';
alter table if exists public.quizzes add column if not exists shuffle_questions boolean default true;
alter table if exists public.quizzes add column if not exists shuffle_options boolean default true;
alter table if exists public.quizzes add column if not exists attempts_allowed int default 1;
alter table if exists public.quizzes add column if not exists quiz_type text default 'weekly';
alter table if exists public.quizzes add column if not exists term_id text;
alter table if exists public.quizzes add column if not exists session_id text;
alter table if exists public.quizzes add column if not exists created_at timestamptz default now();
alter table if exists public.quizzes add column if not exists updated_at timestamptz default now();
alter table if exists public.quiz_questions add column if not exists id uuid default gen_random_uuid();
alter table if exists public.quiz_questions add column if not exists quiz_id uuid;
alter table if exists public.quiz_questions add column if not exists question_no int;
alter table if exists public.quiz_questions add column if not exists question_text text;
alter table if exists public.quiz_questions add column if not exists option_a text;
alter table if exists public.quiz_questions add column if not exists option_b text;
alter table if exists public.quiz_questions add column if not exists option_c text;
alter table if exists public.quiz_questions add column if not exists option_d text;
alter table if exists public.quiz_questions add column if not exists correct_answer text;
alter table if exists public.quiz_questions add column if not exists topic text;
alter table if exists public.quiz_questions add column if not exists marks numeric default 1;
alter table if exists public.quiz_questions add column if not exists created_at timestamptz default now();
alter table if exists public.quiz_attempts add column if not exists id uuid default gen_random_uuid();
alter table if exists public.quiz_attempts add column if not exists quiz_id uuid;
alter table if exists public.quiz_attempts add column if not exists student_id uuid;
alter table if exists public.quiz_attempts add column if not exists started_at timestamptz;
alter table if exists public.quiz_attempts add column if not exists submitted_at timestamptz;
alter table if exists public.quiz_attempts add column if not exists score numeric;
alter table if exists public.quiz_attempts add column if not exists percentage numeric;
alter table if exists public.quiz_attempts add column if not exists correct_count int;
alter table if exists public.quiz_attempts add column if not exists total_questions int;
alter table if exists public.quiz_attempts add column if not exists status text;
alter table if exists public.quiz_attempts add column if not exists answers jsonb;
alter table if exists public.quiz_attempts add column if not exists created_at timestamptz default now();
alter table if exists public.teacher_feedback add column if not exists id uuid default gen_random_uuid();
alter table if exists public.teacher_feedback add column if not exists teacher_id uuid;
alter table if exists public.teacher_feedback add column if not exists admin_id text;
alter table if exists public.teacher_feedback add column if not exists subject text;
alter table if exists public.teacher_feedback add column if not exists message text;
alter table if exists public.teacher_feedback add column if not exists status text default 'unread';
alter table if exists public.teacher_feedback add column if not exists reply text;
alter table if exists public.teacher_feedback add column if not exists replied_at timestamptz;
alter table if exists public.teacher_feedback add column if not exists created_at timestamptz default now();
alter table if exists public.nursery_observations add column if not exists id uuid default gen_random_uuid();
alter table if exists public.nursery_observations add column if not exists class_id text;
alter table if exists public.nursery_observations add column if not exists student_id text;
alter table if exists public.nursery_observations add column if not exists subject_id text;
alter table if exists public.nursery_observations add column if not exists week_id text;
alter table if exists public.nursery_observations add column if not exists session_id text;
alter table if exists public.nursery_observations add column if not exists topics text;
alter table if exists public.nursery_observations add column if not exists materials text;
alter table if exists public.nursery_observations add column if not exists engagement text;
alter table if exists public.nursery_observations add column if not exists observation text;
alter table if exists public.nursery_observations add column if not exists teacher_id text;
alter table if exists public.nursery_observations add column if not exists created_at timestamptz default now();
alter table if exists public.nursery_observations add column if not exists updated_at timestamptz default now();
alter table if exists public.nursery_week_notes add column if not exists id uuid default gen_random_uuid();
alter table if exists public.nursery_week_notes add column if not exists student_id text;
alter table if exists public.nursery_week_notes add column if not exists week_id text;
alter table if exists public.nursery_week_notes add column if not exists class_id text;
alter table if exists public.nursery_week_notes add column if not exists session_id text;
alter table if exists public.nursery_week_notes add column if not exists teacher_id text;
alter table if exists public.nursery_week_notes add column if not exists age text;
alter table if exists public.nursery_week_notes add column if not exists general_notes text;
alter table if exists public.nursery_week_notes add column if not exists next_steps text;
alter table if exists public.nursery_week_notes add column if not exists created_at timestamptz default now();
alter table if exists public.nursery_week_notes add column if not exists updated_at timestamptz default now();
alter table if exists public.weekly_topics add column if not exists id uuid default gen_random_uuid();
alter table if exists public.weekly_topics add column if not exists class_id text;
alter table if exists public.weekly_topics add column if not exists week_id text;
alter table if exists public.weekly_topics add column if not exists subject_id text;
alter table if exists public.weekly_topics add column if not exists topic text;
alter table if exists public.weekly_topics add column if not exists teacher_id text;
alter table if exists public.weekly_topics add column if not exists updated_at timestamptz default now();
alter table if exists public.weekly_topics add column if not exists created_at timestamptz default now();
alter table if exists public.weekly_comments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.weekly_comments add column if not exists student_id text;
alter table if exists public.weekly_comments add column if not exists week_id text;
alter table if exists public.weekly_comments add column if not exists comment text;
alter table if exists public.weekly_comments add column if not exists teacher_id text;
alter table if exists public.weekly_comments add column if not exists created_at timestamptz default now();
alter table if exists public.weekly_comments add column if not exists updated_at timestamptz default now();
alter table if exists public.term_scores add column if not exists id uuid default gen_random_uuid();
alter table if exists public.term_scores add column if not exists student_id text;
alter table if exists public.term_scores add column if not exists class_id text;
alter table if exists public.term_scores add column if not exists subject_id text;
alter table if exists public.term_scores add column if not exists term_id text;
alter table if exists public.term_scores add column if not exists session_id text;
alter table if exists public.term_scores add column if not exists test1 numeric;
alter table if exists public.term_scores add column if not exists test1_manual numeric;
alter table if exists public.term_scores add column if not exists test2 numeric;
alter table if exists public.term_scores add column if not exists project numeric;
alter table if exists public.term_scores add column if not exists assignment_manual numeric;
alter table if exists public.term_scores add column if not exists assignment_auto numeric;
alter table if exists public.term_scores add column if not exists exam numeric;
alter table if exists public.term_scores add column if not exists teacher_id text;
alter table if exists public.term_scores add column if not exists updated_at timestamptz default now();
alter table if exists public.term_scores add column if not exists created_at timestamptz default now();
alter table if exists public.result_publications add column if not exists id uuid default gen_random_uuid();
alter table if exists public.result_publications add column if not exists class_id text;
alter table if exists public.result_publications add column if not exists term_id text;
alter table if exists public.result_publications add column if not exists session_id text;
alter table if exists public.result_publications add column if not exists is_published boolean default false;
alter table if exists public.result_publications add column if not exists published_at timestamptz;
alter table if exists public.result_publications add column if not exists published_by text;
alter table if exists public.result_publications add column if not exists updated_at timestamptz default now();
alter table if exists public.result_blocks add column if not exists student_id text;
alter table if exists public.result_blocks add column if not exists is_blocked boolean default true;
alter table if exists public.result_blocks add column if not exists reason text;
alter table if exists public.result_blocks add column if not exists blocked_by text;
alter table if exists public.result_blocks add column if not exists updated_at timestamptz default now();
alter table if exists public.ca_records add column if not exists id uuid default gen_random_uuid();
alter table if exists public.ca_records add column if not exists student_id text;
alter table if exists public.ca_records add column if not exists class_id text;
alter table if exists public.ca_records add column if not exists subject_id text;
alter table if exists public.ca_records add column if not exists term_id text;
alter table if exists public.ca_records add column if not exists session_id text;
alter table if exists public.ca_records add column if not exists test numeric;
alter table if exists public.ca_records add column if not exists takehome numeric;
alter table if exists public.ca_records add column if not exists quiz numeric;
alter table if exists public.ca_records add column if not exists debate numeric;
alter table if exists public.ca_records add column if not exists project numeric;
alter table if exists public.ca_records add column if not exists attendance numeric;
alter table if exists public.ca_records add column if not exists appearance numeric;
alter table if exists public.ca_records add column if not exists honesty numeric;
alter table if exists public.ca_records add column if not exists punctuality numeric;
alter table if exists public.ca_records add column if not exists relationship numeric;
alter table if exists public.ca_records add column if not exists notecopying numeric;
alter table if exists public.ca_records add column if not exists practical numeric;
alter table if exists public.ca_records add column if not exists exam numeric;
alter table if exists public.ca_records add column if not exists test2 numeric;
alter table if exists public.ca_records add column if not exists assignproject numeric;
alter table if exists public.ca_records add column if not exists teacher_id text;
alter table if exists public.ca_records add column if not exists updated_at timestamptz default now();
alter table if exists public.midterm_remarks add column if not exists id uuid default gen_random_uuid();
alter table if exists public.midterm_remarks add column if not exists student_id text;
alter table if exists public.midterm_remarks add column if not exists class_id text;
alter table if exists public.midterm_remarks add column if not exists term_id text;
alter table if exists public.midterm_remarks add column if not exists session_id text;
alter table if exists public.midterm_remarks add column if not exists general_observation text;
alter table if exists public.midterm_remarks add column if not exists recommendation text;
alter table if exists public.midterm_remarks add column if not exists teacher_id text;
alter table if exists public.midterm_remarks add column if not exists updated_at timestamptz default now();
alter table if exists public.midterm_remarks add column if not exists created_at timestamptz default now();
alter table if exists public.early_midterm_reports add column if not exists id uuid default gen_random_uuid();
alter table if exists public.early_midterm_reports add column if not exists student_id text;
alter table if exists public.early_midterm_reports add column if not exists class_id text;
alter table if exists public.early_midterm_reports add column if not exists session_id text;
alter table if exists public.early_midterm_reports add column if not exists term_id text;
alter table if exists public.early_midterm_reports add column if not exists teacher_id text;
alter table if exists public.early_midterm_reports add column if not exists class_teacher text;
alter table if exists public.early_midterm_reports add column if not exists report_date date;
alter table if exists public.early_midterm_reports add column if not exists ratings jsonb;
alter table if exists public.early_midterm_reports add column if not exists strengths text;
alter table if exists public.early_midterm_reports add column if not exists improvements text;
alter table if exists public.early_midterm_reports add column if not exists strategies text;
alter table if exists public.early_midterm_reports add column if not exists comment text;
alter table if exists public.early_midterm_reports add column if not exists updated_at timestamptz default now();
alter table if exists public.early_midterm_reports add column if not exists created_at timestamptz default now();
alter table if exists public.assignments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.assignments add column if not exists title text;
alter table if exists public.assignments add column if not exists instructions text;
alter table if exists public.assignments add column if not exists assignment_type text default 'file';
alter table if exists public.assignments add column if not exists quiz_id text;
alter table if exists public.assignments add column if not exists class_id text;
alter table if exists public.assignments add column if not exists class_name text;
alter table if exists public.assignments add column if not exists subject_id text;
alter table if exists public.assignments add column if not exists subject_name text;
alter table if exists public.assignments add column if not exists week_id text;
alter table if exists public.assignments add column if not exists week_name text;
alter table if exists public.assignments add column if not exists teacher_id text;
alter table if exists public.assignments add column if not exists teacher_name text;
alter table if exists public.assignments add column if not exists due_date timestamptz;
alter table if exists public.assignments add column if not exists max_score numeric default 10;
alter table if exists public.assignments add column if not exists attachments jsonb default '[]'::jsonb;
alter table if exists public.assignments add column if not exists created_at timestamptz default now();
alter table if exists public.assignment_submissions add column if not exists id uuid default gen_random_uuid();
alter table if exists public.assignment_submissions add column if not exists assignment_id text;
alter table if exists public.assignment_submissions add column if not exists student_id text;
alter table if exists public.assignment_submissions add column if not exists student_name text;
alter table if exists public.assignment_submissions add column if not exists class_name text;
alter table if exists public.assignment_submissions add column if not exists note text;
alter table if exists public.assignment_submissions add column if not exists files jsonb default '[]'::jsonb;
alter table if exists public.assignment_submissions add column if not exists status text default 'submitted';
alter table if exists public.assignment_submissions add column if not exists is_late boolean default false;
alter table if exists public.assignment_submissions add column if not exists score numeric;
alter table if exists public.assignment_submissions add column if not exists feedback text;
alter table if exists public.assignment_submissions add column if not exists graded_by text;
alter table if exists public.assignment_submissions add column if not exists graded_at timestamptz;
alter table if exists public.assignment_submissions add column if not exists submitted_at timestamptz default now();
alter table if exists public.daily_story_class add column if not exists id uuid default gen_random_uuid();
alter table if exists public.daily_story_class add column if not exists class_id text;
alter table if exists public.daily_story_class add column if not exists story_date date;
alter table if exists public.daily_story_class add column if not exists teacher_id text;
alter table if exists public.daily_story_class add column if not exists teacher_name text;
alter table if exists public.daily_story_class add column if not exists subjects jsonb default '[]'::jsonb;
alter table if exists public.daily_story_class add column if not exists activity text;
alter table if exists public.daily_story_class add column if not exists media jsonb default '[]'::jsonb;
alter table if exists public.daily_story_class add column if not exists media_note text;
alter table if exists public.daily_story_class add column if not exists homework text;
alter table if exists public.daily_story_class add column if not exists homework_due date;
alter table if exists public.daily_story_class add column if not exists class_message text;
alter table if exists public.daily_story_class add column if not exists published boolean default false;
alter table if exists public.daily_story_class add column if not exists published_at timestamptz;
alter table if exists public.daily_story_class add column if not exists updated_at timestamptz default now();
alter table if exists public.daily_story_class add column if not exists created_at timestamptz default now();
alter table if exists public.daily_story_student add column if not exists id uuid default gen_random_uuid();
alter table if exists public.daily_story_student add column if not exists student_id text;
alter table if exists public.daily_story_student add column if not exists class_id text;
alter table if exists public.daily_story_student add column if not exists story_date date;
alter table if exists public.daily_story_student add column if not exists attendance text;
alter table if exists public.daily_story_student add column if not exists participation text;
alter table if exists public.daily_story_student add column if not exists behaviour text;
alter table if exists public.daily_story_student add column if not exists wellbeing text;
alter table if exists public.daily_story_student add column if not exists skills jsonb default '[]'::jsonb;
alter table if exists public.daily_story_student add column if not exists achievements jsonb default '[]'::jsonb;
alter table if exists public.daily_story_student add column if not exists teacher_message text;
alter table if exists public.daily_story_student add column if not exists teacher_reply text;
alter table if exists public.daily_story_student add column if not exists replied_at timestamptz;
alter table if exists public.daily_story_student add column if not exists montessori jsonb default '{}'::jsonb;
alter table if exists public.daily_story_student add column if not exists parent_feedback text;
alter table if exists public.daily_story_student add column if not exists parent_feedback_at timestamptz;
alter table if exists public.daily_story_student add column if not exists updated_at timestamptz default now();
alter table if exists public.daily_story_student add column if not exists created_at timestamptz default now();
alter table if exists public.exam_inbox add column if not exists id uuid default gen_random_uuid();
alter table if exists public.exam_inbox add column if not exists teacher_id text;
alter table if exists public.exam_inbox add column if not exists teacher_name text;
alter table if exists public.exam_inbox add column if not exists sender_role text;
alter table if exists public.exam_inbox add column if not exists message_type text;
alter table if exists public.exam_inbox add column if not exists title text;
alter table if exists public.exam_inbox add column if not exists class_level text;
alter table if exists public.exam_inbox add column if not exists note text;
alter table if exists public.exam_inbox add column if not exists parent_id text;
alter table if exists public.exam_inbox add column if not exists created_at timestamptz default now();
alter table if exists public.exam_inbox_files add column if not exists id uuid default gen_random_uuid();
alter table if exists public.exam_inbox_files add column if not exists message_id text;
alter table if exists public.exam_inbox_files add column if not exists teacher_id text;
alter table if exists public.exam_inbox_files add column if not exists file_path text;
alter table if exists public.exam_inbox_files add column if not exists file_name text;
alter table if exists public.exam_inbox_files add column if not exists file_size bigint;
alter table if exists public.exam_inbox_files add column if not exists created_at timestamptz default now();
alter table if exists public.enotes add column if not exists id uuid default gen_random_uuid();
alter table if exists public.enotes add column if not exists title text;
alter table if exists public.enotes add column if not exists class_id text;
alter table if exists public.enotes add column if not exists subject_id text;
alter table if exists public.enotes add column if not exists subject_name text;
alter table if exists public.enotes add column if not exists teacher_id text;
alter table if exists public.enotes add column if not exists teacher_name text;
alter table if exists public.enotes add column if not exists content text;
alter table if exists public.enotes add column if not exists video_url text;
alter table if exists public.enotes add column if not exists link_url text;
alter table if exists public.enotes add column if not exists live_url text;
alter table if exists public.enotes add column if not exists live_time text;
alter table if exists public.enotes add column if not exists attachments jsonb default '[]'::jsonb;
alter table if exists public.enotes add column if not exists published boolean default true;
alter table if exists public.enotes add column if not exists created_at timestamptz default now();
alter table if exists public.enotes add column if not exists updated_at timestamptz default now();
alter table if exists public.enote_comments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.enote_comments add column if not exists note_id text;
alter table if exists public.enote_comments add column if not exists author_id text;
alter table if exists public.enote_comments add column if not exists author_name text;
alter table if exists public.enote_comments add column if not exists author_role text;
alter table if exists public.enote_comments add column if not exists body text;
alter table if exists public.enote_comments add column if not exists created_at timestamptz default now();
alter table if exists public.enote_reads add column if not exists note_id text;
alter table if exists public.enote_reads add column if not exists student_id text;
alter table if exists public.enote_reads add column if not exists student_name text;
alter table if exists public.enote_reads add column if not exists understood boolean default false;
alter table if exists public.enote_reads add column if not exists read_at timestamptz default now();
alter table if exists public.lesson_plans add column if not exists id uuid default gen_random_uuid();
alter table if exists public.lesson_plans add column if not exists teacher_id text;
alter table if exists public.lesson_plans add column if not exists teacher_name text;
alter table if exists public.lesson_plans add column if not exists class_id text;
alter table if exists public.lesson_plans add column if not exists class_name text;
alter table if exists public.lesson_plans add column if not exists subject_id text;
alter table if exists public.lesson_plans add column if not exists subject_name text;
alter table if exists public.lesson_plans add column if not exists week_id text;
alter table if exists public.lesson_plans add column if not exists week_name text;
alter table if exists public.lesson_plans add column if not exists plan_date text;
alter table if exists public.lesson_plans add column if not exists duration text;
alter table if exists public.lesson_plans add column if not exists topic text;
alter table if exists public.lesson_plans add column if not exists objectives text;
alter table if exists public.lesson_plans add column if not exists prior text;
alter table if exists public.lesson_plans add column if not exists materials text;
alter table if exists public.lesson_plans add column if not exists introduction text;
alter table if exists public.lesson_plans add column if not exists development text;
alter table if exists public.lesson_plans add column if not exists evaluation text;
alter table if exists public.lesson_plans add column if not exists assignment text;
alter table if exists public.lesson_plans add column if not exists link_url text;
alter table if exists public.lesson_plans add column if not exists status text default 'draft';
alter table if exists public.lesson_plans add column if not exists teacher_seen boolean default true;
alter table if exists public.lesson_plans add column if not exists admin_seen boolean default false;
alter table if exists public.lesson_plans add column if not exists submitted_at timestamptz;
alter table if exists public.lesson_plans add column if not exists reviewed_at timestamptz;
alter table if exists public.lesson_plans add column if not exists created_at timestamptz default now();
alter table if exists public.lesson_plans add column if not exists updated_at timestamptz default now();
alter table if exists public.lesson_plan_comments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.lesson_plan_comments add column if not exists plan_id text;
alter table if exists public.lesson_plan_comments add column if not exists field text default 'general';
alter table if exists public.lesson_plan_comments add column if not exists author_id text;
alter table if exists public.lesson_plan_comments add column if not exists author_name text;
alter table if exists public.lesson_plan_comments add column if not exists author_role text;
alter table if exists public.lesson_plan_comments add column if not exists body text;
alter table if exists public.lesson_plan_comments add column if not exists resolved boolean default false;
alter table if exists public.lesson_plan_comments add column if not exists created_at timestamptz default now();
alter table if exists public.lesson_plan_files add column if not exists plan_id text;
alter table if exists public.lesson_plan_files add column if not exists teacher_id text;
alter table if exists public.lesson_plan_files add column if not exists file_name text;
alter table if exists public.lesson_plan_files add column if not exists file_type text;
alter table if exists public.lesson_plan_files add column if not exists file_data text;
alter table if exists public.lesson_plan_files add column if not exists updated_at timestamptz default now();
alter table if exists public.departments add column if not exists id uuid default gen_random_uuid();
alter table if exists public.departments add column if not exists name text;
alter table if exists public.departments add column if not exists hod_id text;
alter table if exists public.departments add column if not exists hod_name text;
alter table if exists public.departments add column if not exists created_at timestamptz default now();
alter table if exists public.department_members add column if not exists id uuid default gen_random_uuid();
alter table if exists public.department_members add column if not exists department_id text;
alter table if exists public.department_members add column if not exists teacher_id text;
alter table if exists public.department_members add column if not exists teacher_name text;
alter table if exists public.department_members add column if not exists created_at timestamptz default now();
alter table if exists public.register_attendance add column if not exists id uuid default gen_random_uuid();
alter table if exists public.register_attendance add column if not exists student_id text;
alter table if exists public.register_attendance add column if not exists class_id text;
alter table if exists public.register_attendance add column if not exists week_id text;
alter table if exists public.register_attendance add column if not exists term_id text;
alter table if exists public.register_attendance add column if not exists session_id text;
alter table if exists public.register_attendance add column if not exists marks text default '----------';
alter table if exists public.register_attendance add column if not exists marked_by text;
alter table if exists public.register_attendance add column if not exists updated_at timestamptz default now();
alter table if exists public.register_week_meta add column if not exists class_id text;
alter table if exists public.register_week_meta add column if not exists week_id text;
alter table if exists public.register_week_meta add column if not exists closed text default '00000';
alter table if exists public.register_week_meta add column if not exists signed_by text;
alter table if exists public.register_week_meta add column if not exists signed_at timestamptz;
alter table if exists public.register_week_meta add column if not exists locked boolean default false;
alter table if exists public.register_students add column if not exists student_id text;
alter table if exists public.register_students add column if not exists gender text;
alter table if exists public.mgmt_users add column if not exists id uuid default gen_random_uuid();
alter table if exists public.mgmt_users add column if not exists name text;
alter table if exists public.mgmt_users add column if not exists email text;
alter table if exists public.mgmt_users add column if not exists password text;
alter table if exists public.mgmt_users add column if not exists position text;
alter table if exists public.mgmt_users add column if not exists phone text;
alter table if exists public.mgmt_users add column if not exists perms jsonb default '{}'::jsonb;
alter table if exists public.mgmt_users add column if not exists active boolean default true;
alter table if exists public.mgmt_users add column if not exists created_at timestamptz default now();
alter table if exists public.mgmt_users add column if not exists last_login timestamptz;
alter table if exists public.mgmt_data add column if not exists id uuid default gen_random_uuid();
alter table if exists public.mgmt_data add column if not exists term_label text;
alter table if exists public.mgmt_data add column if not exists module text;
alter table if exists public.mgmt_data add column if not exists row_key text;
alter table if exists public.mgmt_data add column if not exists data jsonb default '{}'::jsonb;
alter table if exists public.mgmt_data add column if not exists updated_by text;
alter table if exists public.mgmt_data add column if not exists updated_at timestamptz default now();
alter table if exists public.mgmt_data add column if not exists created_at timestamptz default now();
alter table if exists public.announcements add column if not exists title text;
alter table if exists public.announcements add column if not exists body text;
alter table if exists public.announcements add column if not exists audience text default 'parents';
alter table if exists public.announcements add column if not exists class_id text;
alter table if exists public.announcements add column if not exists created_by text;
alter table if exists public.announcements add column if not exists created_by_name text;
alter table if exists public.announcements add column if not exists expires_at date;
alter table if exists public.announcements add column if not exists created_at timestamptz default now();
alter table if exists public.notification_log add column if not exists kind text;
alter table if exists public.notification_log add column if not exists channel text;
alter table if exists public.notification_log add column if not exists student_id text;
alter table if exists public.notification_log add column if not exists recipient text;
alter table if exists public.notification_log add column if not exists subject text;
alter table if exists public.notification_log add column if not exists message text;
alter table if exists public.notification_log add column if not exists status text default 'queued';
alter table if exists public.notification_log add column if not exists error text;
alter table if exists public.notification_log add column if not exists created_by text;
alter table if exists public.notification_log add column if not exists created_at timestamptz default now();
alter table if exists public.notification_log add column if not exists sent_at timestamptz;
alter table if exists public.parent_feedback add column if not exists id uuid default gen_random_uuid();
alter table if exists public.parent_feedback add column if not exists student_id text;
alter table if exists public.parent_feedback add column if not exists student_login_id text;
alter table if exists public.parent_feedback add column if not exists student_name text;
alter table if exists public.parent_feedback add column if not exists parent_name text;
alter table if exists public.parent_feedback add column if not exists parent_contact text;
alter table if exists public.parent_feedback add column if not exists message text;
alter table if exists public.parent_feedback add column if not exists week_id text;
alter table if exists public.parent_feedback add column if not exists status text default 'unread';
alter table if exists public.parent_feedback add column if not exists reply text;
alter table if exists public.parent_feedback add column if not exists created_at timestamptz default now();
alter table if exists public.staff_sessions add column if not exists session_key text;
alter table if exists public.staff_sessions add column if not exists user_uid text;
alter table if exists public.staff_sessions add column if not exists name text;
alter table if exists public.staff_sessions add column if not exists role text;
alter table if exists public.staff_sessions add column if not exists position text;
alter table if exists public.staff_sessions add column if not exists sections text;
alter table if exists public.staff_sessions add column if not exists login_at timestamptz default now();
alter table if exists public.staff_sessions add column if not exists last_seen timestamptz default now();
alter table if exists public.staff_sessions add column if not exists logout_at timestamptz;
alter table if exists public.staff_sessions add column if not exists last_page text;
alter table if exists public.staff_sessions add column if not exists device text;
alter table if exists public.form_submissions add column if not exists kind text;
alter table if exists public.form_submissions add column if not exists title text;
alter table if exists public.form_submissions add column if not exists data jsonb;
alter table if exists public.form_submissions add column if not exists submitted_by text;
alter table if exists public.form_submissions add column if not exists submitted_by_name text;
alter table if exists public.form_submissions add column if not exists submitted_by_role text;
alter table if exists public.form_submissions add column if not exists created_at timestamptz default now();
alter table if exists public.form_submissions add column if not exists updated_at timestamptz;
alter table if exists public.teacher_applications add column if not exists id uuid default gen_random_uuid();
alter table if exists public.teacher_applications add column if not exists reference text;
alter table if exists public.teacher_applications add column if not exists full_name text;
alter table if exists public.teacher_applications add column if not exists gender text;
alter table if exists public.teacher_applications add column if not exists phone text;
alter table if exists public.teacher_applications add column if not exists email text;
alter table if exists public.teacher_applications add column if not exists address text;
alter table if exists public.teacher_applications add column if not exists sections text[] default '{}';
alter table if exists public.teacher_applications add column if not exists subjects text;
alter table if exists public.teacher_applications add column if not exists class_ids text[] default '{}';
alter table if exists public.teacher_applications add column if not exists class_names text;
alter table if exists public.teacher_applications add column if not exists password text;
alter table if exists public.teacher_applications add column if not exists experience_years numeric;
alter table if exists public.teacher_applications add column if not exists status text default 'pending';
alter table if exists public.teacher_applications add column if not exists review_note text;
alter table if exists public.teacher_applications add column if not exists reviewed_at timestamptz;
alter table if exists public.teacher_applications add column if not exists created_at timestamptz default now();

-- ---------------------------------------------------------------------
-- 4. HELPERS: unique keys (for save/update) and relationships (for joins)
--    Each one is wrapped so a problem on one item never stops the rest.
-- ---------------------------------------------------------------------
create or replace function public.psws_uniq(t text, cols text[]) returns void
language plpgsql as $f$
declare reg regclass := to_regclass('public.' || quote_ident(t));
begin
  if reg is null then return; end if;
  if exists (
    select 1 from pg_index i
    where i.indrelid = reg and i.indisunique and i.indpred is null
      and (select array_agg(a.attname::text order by a.attname::text)
             from pg_attribute a where a.attrelid = i.indrelid and a.attnum = any(i.indkey))
        = (select array_agg(x order by x) from unnest(cols) x)
  ) then return; end if;
  execute format('create unique index if not exists %I on public.%I (%s)',
    'psws_uq_' || left(t, 30) || '_' || substr(md5(array_to_string(cols, ',')), 1, 8),
    t, (select string_agg(quote_ident(c), ',') from unnest(cols) c));
exception when others then
  raise notice 'Unique key on %(%) skipped: %  (remove duplicate rows, then run this script again)', t, array_to_string(cols, ','), sqlerrm;
end $f$;

create or replace function public.psws_fk(t text, c text, rt text, del text default 'no action') returns void
language plpgsql as $f$
declare reg regclass := to_regclass('public.' || quote_ident(t));
        rreg regclass := to_regclass('public.' || quote_ident(rt));
begin
  if reg is null or rreg is null then return; end if;
  if exists (
    select 1 from pg_constraint k
    join pg_attribute a on a.attrelid = k.conrelid and a.attnum = any(k.conkey)
    where k.contype = 'f' and k.conrelid = reg and k.confrelid = rreg and a.attname = c
  ) then return; end if;
  execute format('alter table public.%I add constraint %I foreign key (%I) references public.%I(id) on delete %s not valid',
    t, left('psws_fk_' || t || '_' || c, 60), c, rt, del);
exception when others then
  raise notice 'Relationship %.% -> % skipped: %', t, c, rt, sqlerrm;
end $f$;

-- Unique keys the app relies on when it "saves or updates"
select public.psws_uniq('assignment_submissions', array['assignment_id','student_id']);
select public.psws_uniq('ca_records',             array['student_id','subject_id','term_id','session_id']);
select public.psws_uniq('term_scores',            array['student_id','subject_id','term_id','session_id']);
select public.psws_uniq('result_publications',    array['class_id','term_id','session_id']);
select public.psws_uniq('midterm_remarks',        array['student_id','term_id','session_id']);
select public.psws_uniq('weekly_topics',          array['class_id','week_id','subject_id']);
select public.psws_uniq('weekly_comments',        array['student_id','week_id']);
select public.psws_uniq('assessments',            array['student_id','subject_id','week_id']);
select public.psws_uniq('daily_story_class',      array['class_id','story_date']);
select public.psws_uniq('daily_story_student',    array['student_id','story_date']);
select public.psws_uniq('lesson_plan_files',      array['plan_id']);
select public.psws_uniq('register_attendance',    array['student_id','week_id']);
select public.psws_uniq('students',               array['student_login_id']);
select public.psws_uniq('teachers',               array['email']);

-- Relationships the app uses to show names next to records
select public.psws_fk('students',            'class_id',   'classes');
select public.psws_fk('terms',               'session_id', 'sessions', 'set null');
select public.psws_fk('assessments',         'student_id', 'students', 'cascade');
select public.psws_fk('assessments',         'subject_id', 'subjects');
select public.psws_fk('assessments',         'week_id',    'weeks');
select public.psws_fk('assessments',         'teacher_id', 'teachers', 'set null');
select public.psws_fk('midterm_assessments', 'subject_id', 'subjects');
select public.psws_fk('midterm_assessments', 'teacher_id', 'teachers', 'set null');
select public.psws_fk('quizzes',             'class_id',   'classes');
select public.psws_fk('quizzes',             'subject_id', 'subjects');
select public.psws_fk('quizzes',             'week_id',    'weeks');
select public.psws_fk('quizzes',             'teacher_id', 'teachers', 'set null');
select public.psws_fk('quiz_questions',      'quiz_id',    'quizzes',  'cascade');
select public.psws_fk('quiz_attempts',       'quiz_id',    'quizzes',  'cascade');
select public.psws_fk('quiz_attempts',       'student_id', 'students', 'cascade');
select public.psws_fk('teacher_feedback',    'teacher_id', 'teachers', 'cascade');
select public.psws_fk('class_teachers',      'class_id',   'classes',  'cascade');
select public.psws_fk('class_teachers',      'teacher_id', 'teachers', 'cascade');
select public.psws_fk('teacher_subjects',    'teacher_id', 'teachers', 'cascade');
select public.psws_fk('teacher_subjects',    'subject_id', 'subjects', 'cascade');

-- One class teacher per class, and one live teacher application per email / phone.
-- (Each is guarded: if old duplicate rows exist it just prints a notice instead of stopping.)
do $$ begin
  create unique index if not exists classes_one_class_per_teacher
    on public.classes (class_teacher_id) where class_teacher_id is not null;
exception when others then raise notice 'classes_one_class_per_teacher skipped: %', sqlerrm; end $$;

do $$ begin
  create unique index if not exists ta_unique_email on public.teacher_applications (lower(btrim(email)))
    where status in ('pending','approved');
exception when others then raise notice 'ta_unique_email skipped: %', sqlerrm; end $$;

do $$ begin
  create unique index if not exists ta_unique_phone on public.teacher_applications
    (right(regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g'), 10))
    where status in ('pending','approved') and length(regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g')) >= 7;
exception when others then raise notice 'ta_unique_phone skipped: %', sqlerrm; end $$;

create or replace function public.ta_before_insert() returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.email := lower(btrim(new.email));
  if exists (select 1 from public.teachers t where lower(btrim(t.email)) = new.email) then
    raise exception 'ALREADY_TEACHER: a teacher account with this email already exists' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists ta_before_insert_trg on public.teacher_applications;
create trigger ta_before_insert_trg before insert on public.teacher_applications
  for each row execute function public.ta_before_insert();

drop function if exists public.psws_uniq(text, text[]);
drop function if exists public.psws_fk(text, text, text, text);

-- ---------------------------------------------------------------------
-- 5. ROW-LEVEL SECURITY  (the cause of: "new row violates row-level security policy")
--    The app signs people in itself and uses the public key, so every table
--    needs an open policy for the anon + authenticated roles. This loop covers
--    EVERY table in the project, including any you add later when you re-run it.
-- ---------------------------------------------------------------------
do $$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', r.tablename);
    execute format('drop policy if exists psws_open_all on public.%I', r.tablename);
    execute format('create policy psws_open_all on public.%I for all to anon, authenticated using (true) with check (true)', r.tablename);
  end loop;
end $$;

grant all on all tables    in schema public to anon, authenticated;
grant all on all sequences in schema public to anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. STORAGE BUCKETS (file uploads)
-- ---------------------------------------------------------------------
-- Buckets: newer Supabase projects do NOT let SQL create buckets, so this step is optional.
-- If it prints a notice, create the 4 buckets by hand (Storage > New bucket) - see the steps after the script.
do $$ begin
  insert into storage.buckets (id, name, public) values
    ('report-cards',      'report-cards',      true),
    ('assignment-files',  'assignment-files',  false),
    ('teacher-exams',     'teacher-exams',     false),
    ('daily-story-media', 'daily-story-media', false)
  on conflict (id) do nothing;
exception when others then
  raise notice 'Buckets not created by SQL (%). Create them in Storage > New bucket instead.', sqlerrm;
end $$;

-- Permission rule so the app can upload / read / delete files in those 4 buckets
do $$ begin
  drop policy if exists "rc_upload"      on storage.objects;
  drop policy if exists "psws_files_all" on storage.objects;
  create policy "psws_files_all" on storage.objects
    for all to anon, authenticated
    using      (bucket_id in ('report-cards','assignment-files','teacher-exams','daily-story-media'))
    with check (bucket_id in ('report-cards','assignment-files','teacher-exams','daily-story-media'));
exception when others then
  raise notice 'Storage policy not created by SQL (%). Add it in Storage > Policies instead.', sqlerrm;
end $$;

-- ---------------------------------------------------------------------
-- 7. Make the new tables visible to the app immediately
-- ---------------------------------------------------------------------
notify pgrst, 'reload schema';

-- Done. Refresh the app (Ctrl+Shift+R) and try again.
