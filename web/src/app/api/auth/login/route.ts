import { rejectCrossOrigin } from "@/lib/auth/request-origin";
import { authBackoffResponse } from "@/lib/auth/backoff-response";
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { clearSessionCookies, setAdminSessionCookies, setOwnerSessionCookies } from "@/lib/auth/cookies";
import { upstream, type UpstreamSession } from "@/lib/api/upstream";

const bodySchema = z.object({
  email: z.string().min(3),
  password: z.string().min(1),
});

export async function POST(request: NextRequest) {
  const rejected = rejectCrossOrigin(request);
  if (rejected) return rejected;
  const parsed = bodySchema.safeParse(await request.json().catch(() => ({})));
  if (!parsed.success) {
    return NextResponse.json(
      { error: { code: "validation", message: "Email and password are required" } },
      { status: 422 },
    );
  }

  const res = await upstream("/auth/login", {
    method: "POST",
    body: JSON.stringify(parsed.data),
  });

  const backoff = authBackoffResponse(res);
  if (backoff) return backoff;

  if (res.status !== 200) {
    const status = res.status === 401 ? 401 : 502;
    const message =
      res.status === 401
        ? "Invalid email or password"
        : "Authentication service unavailable";
    return NextResponse.json({ error: { code: "unauthorized", message } }, { status });
  }

  const session = (await res.json()) as UpstreamSession;

  // Admins land on the staff portal, owners on vehicle sharing.
  const isAdmin = session.user.role === "admin";
  const isOwner = session.user.role === "owner";

  if (!isAdmin && !isOwner) {
    return NextResponse.json(
      { error: { code: "unauthorized", message: "Account has no portal access" } },
      { status: 403 },
    );
  }

  const redirectPath = isAdmin ? "/" : "/vehicles";
  const out = NextResponse.json({
    user: session.user,
    authenticated: true,
    redirect: redirectPath,
    role: isAdmin ? "admin" : "owner",
  });
  
  clearSessionCookies(out);
  if (isAdmin) {
    setAdminSessionCookies(out, session.access_token, session.refresh_token);
  } else {
    setOwnerSessionCookies(out, session.access_token, session.refresh_token);
  }
  
  return out;
}
