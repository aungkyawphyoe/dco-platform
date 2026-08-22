import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { setSessionCookies } from "@/lib/auth/cookies";
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
  if (session.user.role !== "admin") {
    return NextResponse.json(
      { error: { code: "unauthorized", message: "Invalid email or password" } },
      { status: 401 },
    );
  }

  const out = NextResponse.json({
    user: session.user,
    access_token: session.access_token,
  });
  setSessionCookies(out, session.access_token, session.refresh_token);
  return out;
}
