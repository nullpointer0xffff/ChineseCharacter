import { sql } from "@/lib/db";

declare global {
  var chineseCharacterSchemaReady: Promise<void> | undefined;
}

export function ensureDatabaseSchema() {
  globalThis.chineseCharacterSchemaReady ??= runMigrations();
  return globalThis.chineseCharacterSchemaReady;
}

async function runMigrations() {
  await sql`
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
    )
  `;

  await sql`alter table app_users add column if not exists email text`;
  await sql`alter table app_users add column if not exists account_type text not null default 'guest'`;
  await sql`alter table app_users add column if not exists is_blocked boolean not null default false`;
  await sql`alter table app_users add column if not exists is_vip boolean not null default false`;
  await sql`alter table app_users add column if not exists login_count integer not null default 0`;
  await sql`alter table app_users add column if not exists total_usage_count integer not null default 0`;
  await sql`alter table app_users add column if not exists last_login_at timestamptz`;
  await sql`alter table app_users add column if not exists last_login_country text`;
  await sql`alter table app_users add column if not exists last_login_city text`;
  await sql`alter table app_users add column if not exists last_used_at timestamptz`;

  await sql`
    create table if not exists usage_events (
      id bigserial primary key,
      user_id text not null references app_users(id),
      action text not null,
      cost integer not null,
      transcript text,
      target_text text,
      created_at timestamptz not null default now()
    )
  `;

  await sql`alter table usage_events add column if not exists transcribe_duration_ms integer`;
  await sql`alter table usage_events add column if not exists extract_duration_ms integer`;
  await sql`alter table usage_events add column if not exists total_duration_ms integer`;
  await sql`alter table usage_events add column if not exists transcribe_model text`;
  await sql`alter table usage_events add column if not exists text_model text`;

  await sql`
    create table if not exists api_request_events (
      id bigserial primary key,
      user_id text not null references app_users(id),
      route text not null,
      created_at timestamptz not null default now()
    )
  `;

  await sql`create unique index if not exists app_users_email_unique_idx on app_users(email) where email is not null`;
  await sql`create index if not exists app_users_email_idx on app_users(email)`;
  await sql`create index if not exists usage_events_user_created_idx on usage_events(user_id, created_at desc)`;
  await sql`create index if not exists api_request_events_user_route_created_idx on api_request_events(user_id, route, created_at desc)`;

  await sql`
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
    )
  `;

  await sql`create index if not exists purchase_events_user_created_idx on purchase_events(user_id, created_at desc)`;
}
