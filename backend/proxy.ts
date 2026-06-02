import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function proxy(request: NextRequest) {
  if (request.nextUrl.pathname.startsWith("/api")) {
    return NextResponse.next();
  }

  const token = process.env.ADMIN_TOKEN;
  if (!token) {
    return NextResponse.next();
  }

  const authorization = request.headers.get("authorization");
  if (isAuthorized(authorization, token)) {
    return NextResponse.next();
  }

  return new NextResponse("Authentication required.", {
    status: 401,
    headers: {
      "WWW-Authenticate": 'Basic realm="Chinese Character Admin"'
    }
  });
}

function isAuthorized(authorization: string | null, token: string) {
  if (!authorization?.startsWith("Basic ")) {
    return false;
  }

  const encoded = authorization.slice("Basic ".length);
  const decoded = atob(encoded);
  const separatorIndex = decoded.indexOf(":");
  if (separatorIndex < 0) {
    return false;
  }

  const username = decoded.slice(0, separatorIndex);
  const password = decoded.slice(separatorIndex + 1);
  return username === "admin" && password === token;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"]
};
