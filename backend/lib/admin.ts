import { sql } from "@/lib/db";

export async function getAdminSummary() {
  const [userRows, usageRows, creditRows, recentUsage] = await Promise.all([
    sql<{ count: string }[]>`select count(*)::text as count from app_users`,
    sql<{ count: string }[]>`select count(*)::text as count from usage_events`,
    sql<{ remaining: string }[]>`
      select coalesce(sum(greatest(total_credits - used_credits, 0)), 0)::text as remaining
      from app_users
    `,
    sql<{
      id: number;
      user_id: string;
      transcript: string | null;
      target_text: string | null;
      created_at: Date;
    }[]>`
      select id, user_id, transcript, target_text, created_at
      from usage_events
      order by created_at desc
      limit 20
    `
  ]);

  return {
    userCount: Number(userRows[0]?.count ?? 0),
    usageCount: Number(usageRows[0]?.count ?? 0),
    remainingCredits: Number(creditRows[0]?.remaining ?? 0),
    recentUsage: recentUsage.map((event) => ({
      id: event.id,
      userId: event.user_id,
      transcript: event.transcript ?? "",
      targetText: event.target_text ?? "",
      createdAt: event.created_at.toISOString()
    }))
  };
}
