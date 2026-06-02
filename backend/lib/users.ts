import { sql } from "@/lib/db";

export type AppUser = {
  id: string;
  totalCredits: number;
  usedCredits: number;
  remainingCredits: number;
};

export function deviceIDFromHeaders(headers: Headers) {
  const deviceID = headers.get("x-device-id")?.trim();
  if (!deviceID || deviceID.length < 8) {
    throw new Error("缺少设备 ID。");
  }
  return deviceID;
}

export async function getOrCreateUser(id: string): Promise<AppUser> {
  const rows = await sql<{
    id: string;
    total_credits: number;
    used_credits: number;
  }[]>`
    insert into app_users (id, total_credits, used_credits)
    values (${id}, 10, 0)
    on conflict (id) do update set updated_at = now()
    returning id, total_credits, used_credits
  `;

  const user = rows[0];
  return {
    id: user.id,
    totalCredits: user.total_credits,
    usedCredits: user.used_credits,
    remainingCredits: Math.max(0, user.total_credits - user.used_credits)
  };
}

export async function recordUsage(params: {
  userID: string;
  transcript: string;
  targetText: string;
  cost: number;
}) {
  await sql.begin(async (tx) => {
    await tx`
      update app_users
      set used_credits = used_credits + ${params.cost}, updated_at = now()
      where id = ${params.userID}
    `;
    await tx`
      insert into usage_events (user_id, action, cost, transcript, target_text)
      values (${params.userID}, 'voice_extract', ${params.cost}, ${params.transcript}, ${params.targetText})
    `;
  });

  return getOrCreateUser(params.userID);
}
