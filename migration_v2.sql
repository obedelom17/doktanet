-- Migration v2 : sécurité, paiements consultation, avis, documents, notifications. Idempotente.
alter table users add column if not exists token_version int not null default 0;
alter table users add column if not exists deleted_at timestamptz;
alter table users add column if not exists consent_version text;
do $$ begin if not exists (select 1 from pg_constraint where conname = 'users_status_check_v2') then alter table users drop constraint if exists users_status_check; alter table users add constraint users_status_check_v2 check (status in ('active','pending','rejected','deleted')); end if; end $$;
alter table appointments add column if not exists payment_status text not null default 'unpaid';
alter table appointments add column if not exists payment_ref text;
alter table appointments add column if not exists amount int;
alter table appointments add column if not exists reminded_at timestamptz;
alter table appointments add column if not exists reschedule_count int not null default 0;
create table if not exists reviews (id uuid primary key default gen_random_uuid(), appointment_id uuid not null unique references appointments(id) on delete cascade, doctor_id uuid not null references users(id), patient_id uuid not null references users(id), rating int not null check (rating between 1 and 5), comment text, created_at timestamptz not null default now());
create index if not exists reviews_doctor_idx on reviews (doctor_id);
create table if not exists patient_documents (id uuid primary key default gen_random_uuid(), patient_id uuid not null references users(id) on delete cascade, name text not null, mime text not null, size int not null, data text not null, created_at timestamptz not null default now());
create index if not exists patient_documents_idx on patient_documents (patient_id);
create table if not exists notifications (id bigserial primary key, user_id uuid not null references users(id) on delete cascade, title text not null, body text, created_at timestamptz not null default now(), read_at timestamptz);
create index if not exists notifications_user_idx on notifications (user_id, id desc);
create table if not exists password_resets (token_hash text primary key, user_id uuid not null references users(id) on delete cascade, expires_at timestamptz not null, used_at timestamptz);
create table if not exists login_attempts (id bigserial primary key, ident text not null, created_at timestamptz not null default now());
create index if not exists login_attempts_idx on login_attempts (ident, created_at);
