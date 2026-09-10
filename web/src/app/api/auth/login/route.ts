import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { setAdminSessionCookies, setOwnerSessionCookies } from "@/lib/auth/cookies";
import { upstream, type UpstreamSession } from "@/lib/api/upstream";

const bodySchema = z.object({
  email: z.string().min(3),
  password: z.string().min(1),
});

export async function POST(request: NextRequest) {
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

  if (res.status !== 200) {
    const status = res.status === 401 ? 401 : 502;
    const message =
      res.status === 401
        ? "Invalid email or password"
        : "Authentication service unavailable";
    return NextResponse.json({ error: { code: "unauthorized", message } }, { status });
  }

  const session = (await res.json()) as UpstreamSession;

  // Check if admin or primary owner with family
  const isAdmin = session.user.role === "admin";
  const isOwnerWithFamily = session.user.role === "owner" && session.user.family_id;

  if (!isAdmin && !isOwnerWithFamily) {
    return NextResponse.json(
      { error: { code: "unauthorized", message: isAdmin ? "Admin access required" : "Family access required" } },
      { status: 403 },
    );
  }

  const redirectPath = isAdmin ? "/" : "/family";
  const out = NextResponse.json({
    user: session.user,
    access_token: session.access_token,
    redirect: redirectPath,
    role: isAdmin ? "admin" : "owner",
  });
  
  if (isAdmin) {
    setAdminSessionCookies(out, session.access_token, session.refresh_token);
  } else {
    setOwnerSessionCookies(out, session.access_token, session.refresh_token);
  }
  
  return out;
}
