import { sql } from "@/lib/db";

declare global {
  var chineseCharacterSchemaReady: Promise<void> | undefined;
}

export function ensureDatabaseSchema() {
  globalThis.chineseCharacterSchemaReady ??= runMigrations();
  return globalThis.chineseCharacterSchemaReady;
}

async function runMigrations() {
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
}
