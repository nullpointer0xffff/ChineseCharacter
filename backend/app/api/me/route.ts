import { NextResponse } from "next/server";
import { deviceIDFromHeaders, getOrCreateUser } from "@/lib/users";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const deviceID = deviceIDFromHeaders(request.headers);
    const user = await getOrCreateUser(deviceID);
    return NextResponse.json({ remainingCredits: user.remainingCredits });
  } catch (error) {
    return NextResponse.json({ error: errorMessage(error) }, { status: 400 });
  }
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "请求失败。";
}
