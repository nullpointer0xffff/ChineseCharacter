create table if not exists app_users (
  id text primary key,
  total_credits integer not null default 10,
  used_credits integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists usage_events (
  id bigserial primary key,
  user_id text not null references app_users(id),
  action text not null,
  cost integer not null,
  transcript text,
  target_text text,
  created_at timestamptz not null default now()
);

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
