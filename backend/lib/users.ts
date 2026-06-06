import { sql } from "@/lib/db";
import { ensureDatabaseSchema } from "@/lib/migrations";

export type AppUser = {
  id: string;
  email: string | null;
  accountType: "guest" | "email";
  totalCredits: number;
  usedCredits: number;
  remainingCredits: number;
  isBlocked: boolean;
  isVip: boolean;
  loginCount: number;
  totalUsageCount: number;
};

export type UserIdentity = {
  id: string;
  email: string | null;
  accountType: "guest" | "email";
  initialCredits: number;
};

export function resolveIdentity(headers: Headers): UserIdentity {
  const deviceID = headers.get("x-device-id")?.trim();
  if (!deviceID || deviceID.length < 8) {
    throw new Error("缺少设备 ID。");
  }

  const email = normalizeEmail(headers.get("x-user-email"));
  if (email) {
    return {
      id: `email:${email}`,
      email,
      accountType: "email",
      initialCredits: 20
    };
  }

  return {
    id: deviceID,
    email: null,
    accountType: "guest",
    initialCredits: 10
  };
}

export function normalizeEmail(value: string | null | undefined) {
  const email = value?.trim().toLowerCase();
  if (!email) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error("邮箱格式不正确。");
  }
  return email;
}

export async function getOrCreateUser(identity: UserIdentity): Promise<AppUser> {
  await ensureDatabaseSchema();

  const rows = await sql<{
    id: string;
    email: string | null;
    account_type: "guest" | "email";
    total_credits: number;
    used_credits: number;
    is_blocked: boolean;
    is_vip: boolean;
    login_count: number;
    total_usage_count: number;
  }[]>`
    insert into app_users (id, email, account_type, total_credits, used_credits)
    values (${identity.id}, ${identity.email}, ${identity.accountType}, ${identity.initialCredits}, 0)
    on conflict (id) do update
      set email = coalesce(app_users.email, excluded.email),
          account_type = excluded.account_type,
          updated_at = now()
    returning id, email, account_type, total_credits, used_credits, is_blocked, is_vip, login_count, total_usage_count
  `;

  return mapUser(rows[0]);
}

export async function recordLogin(params: {
  identity: UserIdentity;
  country: string | null;
  city: string | null;
}) {
  const user = await getOrCreateUser(params.identity);
  const rows = await sql<{
    id: string;
    email: string | null;
    account_type: "guest" | "email";
    total_credits: number;
    used_credits: number;
    is_blocked: boolean;
    is_vip: boolean;
    login_count: number;
    total_usage_count: number;
  }[]>`
    update app_users
    set login_count = login_count + 1,
        last_login_at = now(),
        last_login_country = ${params.country},
        last_login_city = ${params.city},
        updated_at = now()
    where id = ${user.id}
    returning id, email, account_type, total_credits, used_credits, is_blocked, is_vip, login_count, total_usage_count
  `;
  return mapUser(rows[0]);
}

export async function assertNotBlocked(user: AppUser) {
  if (user.isBlocked) {
    throw new UserFacingError("账号已被暂停使用。", 403);
  }
}

export async function assertWithinThrottle(userID: string, route: string) {
  const rows = await sql<{ count: string }[]>`
    select count(*)::text as count
    from api_request_events
    where user_id = ${userID}
      and route = ${route}
      and created_at > now() - interval '5 seconds'
  `;
  const recentCount = Number(rows[0]?.count ?? 0);
  if (recentCount >= 10) {
    throw new UserFacingError("请求太频繁，请稍等几秒再试。", 429);
  }

  await sql`
    insert into api_request_events (user_id, route)
    values (${userID}, ${route})
  `;
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
      set used_credits = used_credits + ${params.cost},
          total_usage_count = total_usage_count + 1,
          last_used_at = now(),
          updated_at = now()
      where id = ${params.userID}
    `;
    await tx`
      insert into usage_events (user_id, action, cost, transcript, target_text)
      values (${params.userID}, 'voice_extract', ${params.cost}, ${params.transcript}, ${params.targetText})
    `;
  });

  return getUserByID(params.userID);
}

export async function getUserByID(id: string) {
  await ensureDatabaseSchema();

  const rows = await sql<{
    id: string;
    email: string | null;
    account_type: "guest" | "email";
    total_credits: number;
    used_credits: number;
    is_blocked: boolean;
    is_vip: boolean;
    login_count: number;
    total_usage_count: number;
  }[]>`
    select id, email, account_type, total_credits, used_credits, is_blocked, is_vip, login_count, total_usage_count
    from app_users
    where id = ${id}
  `;
  if (!rows[0]) {
    throw new Error("用户不存在。");
  }
  return mapUser(rows[0]);
}

function mapUser(user: {
  id: string;
  email: string | null;
  account_type: "guest" | "email";
  total_credits: number;
  used_credits: number;
  is_blocked: boolean;
  is_vip: boolean;
  login_count: number;
  total_usage_count: number;
}): AppUser {
  return {
    id: user.id,
    email: user.email,
    accountType: user.account_type,
    totalCredits: user.total_credits,
    usedCredits: user.used_credits,
    remainingCredits: Math.max(0, user.total_credits - user.used_credits),
    isBlocked: user.is_blocked,
    isVip: user.is_vip,
    loginCount: user.login_count,
    totalUsageCount: user.total_usage_count
  };
}

export function requestGeo(headers: Headers) {
  return {
    country: decodeHeader(headers.get("x-vercel-ip-country")),
    city: decodeHeader(headers.get("x-vercel-ip-city"))
  };
}

function decodeHeader(value: string | null) {
  if (!value) return null;
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

export class UserFacingError extends Error {
  constructor(message: string, public status = 400) {
    super(message);
  }
}
