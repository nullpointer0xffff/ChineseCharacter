import { sql } from "@/lib/db";
import { ensureDatabaseSchema } from "@/lib/migrations";

export type AdminSearchParams = {
  email?: string;
};

export async function getAdminSummary(params: AdminSearchParams = {}) {
  await ensureDatabaseSchema();

  const email = params.email?.trim().toLowerCase() ?? "";
  const userFilter = email ? sql`where email ilike ${`%${email}%`}` : sql``;

  const [userRows, usageRows, creditRows, latencyRows, purchaseRows, revenueRows, recentUsage, users] = await Promise.all([
    sql<{ count: string }[]>`select count(*)::text as count from app_users`,
    sql<{ count: string }[]>`select count(*)::text as count from usage_events`,
    sql<{ remaining: string }[]>`
      select coalesce(sum(greatest(total_credits - used_credits, 0)), 0)::text as remaining
      from app_users
    `,
    sql<{ average_duration_ms: string | null }[]>`
      select round(avg(total_duration_ms))::text as average_duration_ms
      from usage_events
      where total_duration_ms is not null
    `,
    sql<{ count: string }[]>`select count(*)::text as count from purchase_events`,
    sql<{ cents: string }[]>`select coalesce(sum(price_cents), 0)::text as cents from purchase_events`,
    sql<{
      id: number;
      user_id: string;
      transcript: string | null;
      target_text: string | null;
      transcribe_duration_ms: number | null;
      extract_duration_ms: number | null;
      total_duration_ms: number | null;
      transcribe_model: string | null;
      text_model: string | null;
      created_at: Date;
    }[]>`
      select id, user_id, transcript, target_text, transcribe_duration_ms,
             extract_duration_ms, total_duration_ms, transcribe_model, text_model, created_at
      from usage_events
      order by created_at desc
      limit 20
    `,
    sql<{
      id: string;
      email: string | null;
      account_type: string;
      total_credits: number;
      used_credits: number;
      is_blocked: boolean;
      is_vip: boolean;
      login_count: number;
      total_usage_count: number;
      last_login_at: Date | null;
      last_login_country: string | null;
      last_login_city: string | null;
      last_used_at: Date | null;
      created_at: Date;
    }[]>`
      select id, email, account_type, total_credits, used_credits, is_blocked, is_vip,
             login_count, total_usage_count, last_login_at, last_login_country,
             last_login_city, last_used_at, created_at
      from app_users
      ${userFilter}
      order by coalesce(last_used_at, last_login_at, created_at) desc
      limit 100
    `
  ]);

  return {
    userCount: Number(userRows[0]?.count ?? 0),
    usageCount: Number(usageRows[0]?.count ?? 0),
    remainingCredits: Number(creditRows[0]?.remaining ?? 0),
    averageDurationMs: Number(latencyRows[0]?.average_duration_ms ?? 0),
    purchaseCount: Number(purchaseRows[0]?.count ?? 0),
    purchaseRevenueCents: Number(revenueRows[0]?.cents ?? 0),
    recentUsage: recentUsage.map((event) => ({
      id: event.id,
      userId: event.user_id,
      transcript: event.transcript ?? "",
      targetText: event.target_text ?? "",
      transcribeDurationMs: event.transcribe_duration_ms,
      extractDurationMs: event.extract_duration_ms,
      totalDurationMs: event.total_duration_ms,
      transcribeModel: event.transcribe_model,
      textModel: event.text_model,
      createdAt: event.created_at.toISOString()
    })),
    users: users.map((user) => ({
      id: user.id,
      email: user.email,
      accountType: user.account_type,
      totalCredits: user.total_credits,
      usedCredits: user.used_credits,
      remainingCredits: Math.max(0, user.total_credits - user.used_credits),
      isBlocked: user.is_blocked,
      isVip: user.is_vip,
      loginCount: user.login_count,
      totalUsageCount: user.total_usage_count,
      lastLoginAt: user.last_login_at?.toISOString() ?? null,
      lastLoginCountry: user.last_login_country,
      lastLoginCity: user.last_login_city,
      lastUsedAt: user.last_used_at?.toISOString() ?? null,
      createdAt: user.created_at.toISOString()
    }))
  };
}

export async function setUserFlags(params: {
  userID: string;
  isBlocked: boolean;
  isVip: boolean;
}) {
  await ensureDatabaseSchema();

  await sql`
    update app_users
    set is_blocked = ${params.isBlocked},
        is_vip = ${params.isVip},
        updated_at = now()
    where id = ${params.userID}
  `;
}

export async function addUserCredits(params: {
  userID: string;
  credits: number;
}) {
  await ensureDatabaseSchema();

  if (!Number.isInteger(params.credits) || params.credits <= 0 || params.credits > 10000) {
    throw new Error("额度必须是 1 到 10000 之间的整数。");
  }

  await sql`
    update app_users
    set total_credits = total_credits + ${params.credits},
        updated_at = now()
    where id = ${params.userID}
  `;
}
