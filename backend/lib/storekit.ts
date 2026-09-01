import { APP_BUNDLE_ID, purchaseProducts } from "@/lib/products";
import { X509Certificate, createVerify } from "crypto";

const appleRootCAG3PEM = `-----BEGIN CERTIFICATE-----
MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS
QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u
IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN
MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS
b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y
aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49
AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf
TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517
IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySr
MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gA
MGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4
at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM
6BgD56KyKA==
-----END CERTIFICATE-----`;

const appleRootCAG3 = new X509Certificate(appleRootCAG3PEM);

export type StoreKitTransaction = {
  transactionId: string;
  originalTransactionId: string | null;
  productId: string;
  bundleId: string;
  environment: string | null;
  purchaseDate: number | null;
};

export function decodeStoreKitTransaction(jws: string): StoreKitTransaction {
  const parts = jws.split(".");
  if (parts.length !== 3) {
    throw new Error("购买凭证格式不正确。");
  }

  verifyStoreKitJWS(parts);

  const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as {
    transactionId?: string;
    originalTransactionId?: string;
    productId?: string;
    bundleId?: string;
    environment?: string;
    purchaseDate?: number;
    revocationDate?: number;
  };

  if (!payload.transactionId || !payload.productId || !payload.bundleId) {
    throw new Error("购买凭证缺少必要字段。");
  }
  if (payload.bundleId !== APP_BUNDLE_ID) {
    throw new Error("购买凭证不属于当前 App。");
  }
  if (!purchaseProducts[payload.productId]) {
    throw new Error("暂不支持这个购买项目。");
  }
  if (payload.revocationDate) {
    throw new Error("这笔购买已经被撤销。");
  }

  return {
    transactionId: payload.transactionId,
    originalTransactionId: payload.originalTransactionId ?? null,
    productId: payload.productId,
    bundleId: payload.bundleId,
    environment: payload.environment ?? null,
    purchaseDate: payload.purchaseDate ?? null
  };
}

function verifyStoreKitJWS(parts: string[]) {
  const header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8")) as {
    alg?: string;
    x5c?: string[];
  };

  if (header.alg !== "ES256") {
    throw new Error("购买凭证签名算法不正确。");
  }
  if (!Array.isArray(header.x5c) || header.x5c.length < 2) {
    throw new Error("购买凭证缺少 Apple 证书链。");
  }

  const certs = header.x5c.map((cert) => new X509Certificate(Buffer.from(cert, "base64")));
  const chain = [...certs, appleRootCAG3];
  const now = Date.now();

  for (const cert of chain) {
    if (cert.validFromDate.getTime() > now || cert.validToDate.getTime() < now) {
      throw new Error("购买凭证证书不在有效期内。");
    }
  }

  for (let index = 0; index < chain.length - 1; index += 1) {
    const subject = chain[index];
    const issuer = chain[index + 1];
    if (!subject.checkIssued(issuer) || !subject.verify(issuer.publicKey)) {
      throw new Error("购买凭证证书链无效。");
    }
  }

  const verifier = createVerify("SHA256");
  verifier.update(`${parts[0]}.${parts[1]}`);
  verifier.end();

  const signature = Buffer.from(parts[2], "base64url");
  if (signature.length !== 64 || !verifier.verify(certs[0].publicKey, joseSignatureToDER(signature))) {
    throw new Error("购买凭证签名无效。");
  }
}

function joseSignatureToDER(signature: Buffer) {
  const r = derInteger(signature.subarray(0, 32));
  const s = derInteger(signature.subarray(32));
  return Buffer.concat([
    Buffer.from([0x30]),
    derLength(r.length + s.length),
    r,
    s
  ]);
}

function derInteger(bytes: Buffer) {
  let value = bytes;
  while (value.length > 1 && value[0] === 0) {
    value = value.subarray(1);
  }
  if (value[0] & 0x80) {
    value = Buffer.concat([Buffer.from([0]), value]);
  }
  return Buffer.concat([Buffer.from([0x02]), derLength(value.length), value]);
}

function derLength(length: number) {
  if (length < 128) return Buffer.from([length]);
  const bytes: number[] = [];
  let remaining = length;
  while (remaining > 0) {
    bytes.unshift(remaining & 0xff);
    remaining >>= 8;
  }
  return Buffer.from([0x80 | bytes.length, ...bytes]);
}
