import { NextResponse } from "next/server";
import { recordLogin, requestGeo, resolveIdentity } from "@/lib/users";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const identity = resolveIdentity(request.headers);
    const geo = requestGeo(request.headers);
    const user = await recordLogin({
      identity,
      country: geo.country,
      city: geo.city
    });

    return NextResponse.json({
      email: user.email,
      accountType: user.accountType,
      remainingCredits: user.remainingCredits,
      isVip: user.isVip,
      isBlocked: user.isBlocked,
      loginCount: user.loginCount,
      totalUsageCount: user.totalUsageCount
    });
  } catch (error) {
    return NextResponse.json({ error: errorMessage(error) }, { status: 400 });
  }
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "登录失败。";
}
