# PSWS Live - Prestigious Seed of Wisdom School

## 1. Supabase is already connected (tejdmkcqgicabdjsyhpq). To change it later, edit SCHOOL_CONFIG in index.html.
1. Supabase dashboard > **Project Settings > API**. Copy the **Project URL** and the **anon public** key.
2. Open `index.html` in any text editor. Near the top, find `SCHOOL_CONFIG` and paste both values:
   `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Save. (Only the anon/public key - never the service_role key.)

## 2. Build the database in the new project (Supabase > SQL Editor)
The original zip only contained the *add-on* SQL files, not the base tables, so the structure must be copied once:
1. Run `export_schema_from_old_project.sql` in the **old** (NGIS) project. Copy the `schema_sql` result,
   and the `constraints_sql` rows, and run them in the **new** project. This copies structure only - no NGIS student data.
2. Then run these in the new project, in this order:
   `notifications_setup.sql`, `class_teacher_setup.sql`, `staff_activity_setup.sql`, `v10_setup.sql`, `parent_feedback_setup.sql`
   (each is safe to re-run).
3. Create the first administrator row in the `teachers` table (role = `admin`) so you can log in.

## 3. Host it
Upload ALL of these together to your host (Netlify etc.): `index.html`, `sw.js`, `manifest.json`, the three `icon-*.png` files.

## What changed from the NGIS app
- School name, logo, app icons, report-card headers, motto ("Confidence - Courtesy") and contact number (08149510662).
- Green theme -> navy blue to match the logo. Student IDs now look like `PSWS/01/2026`.
- Supabase address/key moved into one `SCHOOL_CONFIG` block.
- Parent Feedback used a private NGIS server; it now uses your own `parent_feedback` table.
- Removed: NGIS campus photo on the login page, the NGIS CA record spreadsheet, the 2nd phone number.

## Not changed (check if needed)
- The two Word templates embedded for the Incident and Observation forms may still carry NGIS wording inside the .docx.
- "SAGE" lesson-observation wording and class sections (Nursery / Primary / Junior & Senior Secondary) are kept as-is.
- Edge Function (optional auto-SMS/email) still needs your own Termii/Resend/WhatsApp keys.
