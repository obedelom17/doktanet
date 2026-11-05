
create table users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  phone text,
  password_hash text not null,
  role text not null check (role in ('patient','doctor','pharmacy','admin')),
  full_name text not null,
  status text not null default 'active' check (status in ('active','pending','rejected')),
  consent_at timestamptz,
  created_at timestamptz not null default now()
);

create table patient_profiles (
  user_id uuid primary key references users(id) on delete cascade,
  birth_date text, allergies text, antecedents text
);

create table doctor_profiles (
  user_id uuid primary key references users(id) on delete cascade,
  order_number text not null,
  specialty text not null default 'Médecine générale',
  city text, fee int not null default 5000,
  experience_years int not null default 0,
  languages text not null default 'Français',
  bio text
);

create table doctor_availability (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references users(id) on delete cascade,
  weekday int not null check (weekday between 0 and 6),
  start_time time not null, end_time time not null
);

create table pharmacy_profiles (
  user_id uuid primary key references users(id) on delete cascade,
  name text not null, license_number text not null,
  city text, address text, phone text,
  lat double precision, lng double precision
);

create table pharmacy_stock (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid not null references users(id) on delete cascade,
  name text not null, quantity int not null default 0, price int not null default 0,
  updated_at timestamptz not null default now(),
  unique (pharmacy_id, name)
);

create table appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references users(id),
  doctor_id uuid not null references users(id),
  starts_at timestamptz not null,
  status text not null default 'scheduled' check (status in ('scheduled','in_progress','done','cancelled')),
  room_url text, notes text,
  created_at timestamptz not null default now()
);
create unique index appointments_slot_uq on appointments (doctor_id, starts_at) where status <> 'cancelled';

create table prescriptions (
  id uuid primary key,
  appointment_id uuid not null references appointments(id),
  doctor_id uuid not null references users(id),
  patient_id uuid not null references users(id),
  items jsonb not null, notes text,
  signature text not null, code text unique not null,
  created_at timestamptz not null
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references prescriptions(id),
  pharmacy_id uuid not null references users(id),
  patient_id uuid not null references users(id),
  status text not null default 'sent' check (status in ('sent','preparing','ready','delivered','cancelled')),
  total int not null default 0,
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','pending','paid')),
  payment_ref text, advice text,
  created_at timestamptz not null default now()
);

create table audit_logs (
  id bigserial primary key,
  user_id uuid, action text not null, target_type text, target_id text,
  created_at timestamptz not null default now()
);

-- Compte admin : inscrire un compte patient puis exécuter :
-- update users set role='admin', status='active' where email='VOTRE_EMAIL';

-- ---------- Assistant IA ----------
create table chat_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  title text, created_at timestamptz not null default now()
);
create table chat_messages (
  id bigserial primary key,
  conversation_id uuid not null references chat_conversations(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  content text not null, created_at timestamptz not null default now()
);
create table reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  medication text not null, times text[] not null, end_date date not null,
  created_at timestamptz not null default now()
);

-- ---------- Finalisation : 2FA, congés, messagerie, litiges ----------
alter table users add column totp_secret text, add column totp_enabled boolean not null default false;

create table doctor_blocks (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references users(id) on delete cascade,
  starts_at timestamptz not null, ends_at timestamptz not null, reason text,
  created_at timestamptz not null default now()
);
create table appointment_messages (
  id bigserial primary key,
  appointment_id uuid not null references appointments(id) on delete cascade,
  sender_id uuid not null references users(id),
  content text not null, created_at timestamptz not null default now()
);
create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references users(id) on delete cascade,
  reason text not null,
  status text not null default 'open' check (status in ('open','resolved')),
  admin_note text, created_at timestamptz not null default now()
);
