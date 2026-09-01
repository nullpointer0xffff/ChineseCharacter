export const CREDIT_PACK_PRODUCT_ID = "com.jiehu.ChineseCharacter.credits100";
export const APP_BUNDLE_ID = "com.jiehu.ChineseCharacter";

export const purchaseProducts: Record<
  string,
  {
    credits: number;
    priceCents: number;
    currency: string;
  }
> = {
  [CREDIT_PACK_PRODUCT_ID]: {
    credits: 100,
    priceCents: 99,
    currency: "USD"
  }
};
