import { NextResponse } from "next/server";
import { purchaseProducts } from "@/lib/products";
import { decodeStoreKitTransaction } from "@/lib/storekit";
import { UserFacingError, getOrCreateUser, redeemPurchase, resolveIdentity } from "@/lib/users";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const identity = resolveIdentity(request.headers);
    const user = await getOrCreateUser(identity);
    const body = (await request.json()) as {
      productID?: string;
      transactionJWS?: string;
    };

    const productID = body.productID?.trim();
    const transactionJWS = body.transactionJWS?.trim();
    if (!productID || !transactionJWS) {
      return NextResponse.json({ error: "缺少购买凭证。" }, { status: 400 });
    }

    const transaction = decodeStoreKitTransaction(transactionJWS);
    if (transaction.productId !== productID) {
      return NextResponse.json({ error: "购买项目和凭证不匹配。" }, { status: 400 });
    }

    const product = purchaseProducts[productID];
    const result = await redeemPurchase({
      userID: user.id,
      transactionID: transaction.transactionId,
      originalTransactionID: transaction.originalTransactionId,
      productID,
      credits: product.credits,
      priceCents: product.priceCents,
      currency: product.currency,
      environment: transaction.environment,
      signedTransaction: transactionJWS
    });

    return NextResponse.json({
      productID,
      transactionID: transaction.transactionId,
      addedCredits: result.addedCredits,
      remainingCredits: result.remainingCredits
    });
  } catch (error) {
    const status = error instanceof UserFacingError ? error.status : 400;
    return NextResponse.json({ error: errorMessage(error) }, { status });
  }
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "购买兑换失败。";
}
