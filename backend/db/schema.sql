create table if not exists app_users (
  id text primary key,
  email text unique,
  account_type text not null default 'guest',
  total_credits integer not null default 10,
  used_credits integer not null default 0,
  is_blocked boolean not null default false,
  is_vip boolean not null default false,
  login_count integer not null default 0,
  total_usage_count integer not null default 0,
  last_login_at timestamptz,
  last_login_country text,
  last_login_city text,
  last_used_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table app_users add column if not exists email text unique;
alter table app_users add column if not exists account_type text not null default 'guest';
alter table app_users add column if not exists is_blocked boolean not null default false;
alter table app_users add column if not exists is_vip boolean not null default false;
alter table app_users add column if not exists login_count integer not null default 0;
alter table app_users add column if not exists total_usage_count integer not null default 0;
alter table app_users add column if not exists last_login_at timestamptz;
alter table app_users add column if not exists last_login_country text;
alter table app_users add column if not exists last_login_city text;
alter table app_users add column if not exists last_used_at timestamptz;

create table if not exists usage_events (
  id bigserial primary key,
  user_id text not null references app_users(id),
  action text not null,
  cost integer not null,
  transcript text,
  target_text text,
  transcribe_duration_ms integer,
  extract_duration_ms integer,
  total_duration_ms integer,
  transcribe_model text,
  text_model text,
  created_at timestamptz not null default now()
);

alter table usage_events add column if not exists transcribe_duration_ms integer;
alter table usage_events add column if not exists extract_duration_ms integer;
alter table usage_events add column if not exists total_duration_ms integer;
alter table usage_events add column if not exists transcribe_model text;
alter table usage_events add column if not exists text_model text;

create table if not exists api_request_events (
  id bigserial primary key,
  user_id text not null references app_users(id),
  route text not null,
  created_at timestamptz not null default now()
);

create index if not exists app_users_email_idx on app_users(email);
create index if not exists usage_events_user_created_idx on usage_events(user_id, created_at desc);
create index if not exists api_request_events_user_route_created_idx on api_request_events(user_id, route, created_at desc);

create table if not exists purchase_events (
  id bigserial primary key,
  user_id text not null references app_users(id),
  transaction_id text not null unique,
  original_transaction_id text,
  product_id text not null,
  credits integer not null,
  price_cents integer not null,
  currency text not null default 'USD',
  environment text,
  signed_transaction text not null,
  created_at timestamptz not null default now()
);

create index if not exists purchase_events_user_created_idx on purchase_events(user_id, created_at desc);

create table if not exists coupons (
  code text primary key,
  credits integer not null,
  max_redemptions integer not null default 1,
  redeemed_count integer not null default 0,
  disabled boolean not null default false,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists coupon_redemptions (
  id bigserial primary key,
  user_id text not null references app_users(id),
  code text not null references coupons(code),
  credits integer not null,
  created_at timestamptz not null default now(),
  unique (user_id, code)
);
