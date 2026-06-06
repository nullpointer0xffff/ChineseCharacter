import { NextResponse } from "next/server";
import { extractTargetText, transcribeAudio } from "@/lib/openai";
import {
  UserFacingError,
  assertNotBlocked,
  assertWithinThrottle,
  getOrCreateUser,
  recordUsage,
  resolveIdentity
} from "@/lib/users";

export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(request: Request) {
  try {
    const identity = resolveIdentity(request.headers);
    const user = await getOrCreateUser(identity);
    await assertNotBlocked(user);
    await assertWithinThrottle(user.id, "voice_extract");

    if (user.remainingCredits <= 0) {
      return NextResponse.json({ error: "免费次数已用完，请兑换 coupon 或购买更多次数。" }, { status: 402 });
    }

    const form = await request.formData();
    const audio = form.get("audio");
    if (!(audio instanceof File)) {
      return NextResponse.json({ error: "请上传 audio 文件。" }, { status: 400 });
    }

    const transcript = await transcribeAudio(audio);
    if (!transcript) {
      return NextResponse.json({ error: "这段录音没有识别出文字，请再试一次。" }, { status: 400 });
    }

    const targetText = await extractTargetText(transcript);
    const updatedUser = await recordUsage({
      userID: user.id,
      transcript,
      targetText,
      cost: 1
    });

    return NextResponse.json({
      transcript,
      targetText,
      remainingCredits: updatedUser.remainingCredits,
      accountType: updatedUser.accountType,
      isVip: updatedUser.isVip
    });
  } catch (error) {
    const status = error instanceof UserFacingError ? error.status : 500;
    return NextResponse.json({ error: errorMessage(error) }, { status });
  }
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "识别失败。";
}
