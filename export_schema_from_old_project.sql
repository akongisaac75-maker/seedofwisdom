-- STEP 1 of copying the database STRUCTURE (no student data) to the new school.
-- Run this in the OLD project's Supabase > SQL Editor. It prints one big block of CREATE TABLE
-- statements in a single cell. Copy that cell's value, then paste and run it in the NEW project.
select string_agg(ddl, E'\n\n' order by tbl) as schema_sql from (
  select c.relname as tbl,
    'create table if not exists public.' || quote_ident(c.relname) || E'(\n  ' ||
    string_agg(quote_ident(a.attname) || ' ' || format_type(a.atttypid, a.atttypmod) ||
      case when a.attnotnull then ' not null' else '' end ||
      case when d.adbin is not null then ' default ' || pg_get_expr(d.adbin, d.adrelid) else '' end,
      E',\n  ' order by a.attnum) || E'\n);' as ddl
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
  left join pg_attrdef d on d.adrelid = c.oid and d.adnum = a.attnum
  where c.relkind = 'r'
  group by c.relname
) t;

-- STEP 2 (also in the OLD project): list primary keys / unique constraints to re-add in the new one.
select 'alter table public.' || quote_ident(conrelid::regclass::text) || ' add ' || pg_get_constraintdef(oid) || ';' as constraints_sql
from pg_constraint
where connamespace = 'public'::regnamespace and contype in ('p','u')
order by conrelid::regclass::text;
