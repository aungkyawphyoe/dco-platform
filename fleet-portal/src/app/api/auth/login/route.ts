import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { setFleetSessionCookies } from "@/lib/auth/cookies";
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
    body: JSON.stringify({ ...parsed.data, surface: "fleet" }),
  });

  if (res.status !== 200) {
    const body = (await res.json().catch(() => null)) as
      | { error?: { code?: string; message?: string } }
      | null;
    const code = body?.error?.code;
    if (res.status === 403) {
      const message =
        code === "fleet_access_required"
          ? "An active Enterprise organization membership is required"
          : code === "portal_access_restricted"
            ? "Drivers do not use the Fleet Portal. Sign in on the mobile app instead."
            : (body?.error?.message ?? "Access denied for this account");
      return NextResponse.json({ error: { code: code ?? "forbidden", message } }, { status: 403 });
    }
    if (res.status === 401) {
      return NextResponse.json(
        { error: { code: "unauthorized", message: "Invalid email or password" } },
        { status: 401 },
      );
    }
    return NextResponse.json(
      { error: { code: "unauthorized", message: "Authentication service unavailable" } },
      { status: 502 },
    );
  }

  const session = (await res.json()) as UpstreamSession;
  const out = NextResponse.json({
    user: session.user,
    access_token: session.access_token,
    redirect: "/",
  });
  setFleetSessionCookies(out, session.access_token, session.refresh_token);
  return out;
}
