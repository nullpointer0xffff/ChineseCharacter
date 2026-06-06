"use server";

import { revalidatePath } from "next/cache";
import { addUserCredits, setUserFlags } from "@/lib/admin";

export async function updateUserFlags(formData: FormData) {
  const userID = String(formData.get("userID") ?? "");
  if (!userID) {
    throw new Error("缺少用户 ID。");
  }

  await setUserFlags({
    userID,
    isBlocked: formData.get("isBlocked") === "on",
    isVip: formData.get("isVip") === "on"
  });
  revalidatePath("/");
}

export async function grantCredits(formData: FormData) {
  const userID = String(formData.get("userID") ?? "");
  const credits = Number(formData.get("credits") ?? 0);
  if (!userID) {
    throw new Error("缺少用户 ID。");
  }

  await addUserCredits({ userID, credits });
  revalidatePath("/");
}
