import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getOrCreateUser, resolveIdentity } from "@/lib/users";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const identity = resolveIdentity(request.headers);
    const user = await getOrCreateUser(identity);

    const body = (await request.json()) as { code?: string };
    const code = body.code?.trim().toUpperCase();
    if (!code) {
      return NextResponse.json({ error: "请输入 coupon code。" }, { status: 400 });
    }

    const result = await sql.begin(async (tx) => {
      const couponRows = await tx<{
        code: string;
        credits: number;
        max_redemptions: number;
        redeemed_count: number;
        disabled: boolean;
        expires_at: Date | null;
      }[]>`
        select code, credits, max_redemptions, redeemed_count, disabled, expires_at
        from coupons
        where code = ${code}
        for update
      `;

      const coupon = couponRows[0];
      if (!coupon || coupon.disabled) {
        throw new Error("coupon 不存在或已停用。");
      }
      if (coupon.expires_at && coupon.expires_at < new Date()) {
        throw new Error("coupon 已过期。");
      }
      if (coupon.redeemed_count >= coupon.max_redemptions) {
        throw new Error("coupon 已被使用完。");
      }

      await tx`
        insert into coupon_redemptions (user_id, code, credits)
        values (${user.id}, ${code}, ${coupon.credits})
      `;
      await tx`
        update coupons
        set redeemed_count = redeemed_count + 1
        where code = ${code}
      `;
      const userRows = await tx<{ remaining_credits: number }[]>`
        update app_users
        set total_credits = total_credits + ${coupon.credits}, updated_at = now()
        where id = ${user.id}
        returning greatest(total_credits - used_credits, 0) as remaining_credits
      `;

      return {
        addedCredits: coupon.credits,
        remainingCredits: userRows[0]?.remaining_credits ?? 0
      };
    });

    return NextResponse.json(result);
  } catch (error) {
    return NextResponse.json({ error: errorMessage(error) }, { status: 400 });
  }
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "兑换失败。";
}
