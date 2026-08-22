import { describe, expect, it } from "vitest";
import { createTestApp, uuid } from "./helpers.js";

describe("health", () => {
  it("returns ok and ready", async () => {
    const { app } = await createTestApp();
    const health = await app.inject({ method: "GET", url: "/v1/health" });
    expect(health.statusCode).toBe(200);
    expect(health.json()).toEqual({ status: "ok" });
    const ready = await app.inject({ method: "GET", url: "/v1/ready" });
    expect(ready.statusCode).toBe(200);
    await app.close();
  });
});

describe("auth", () => {
  it("signs up, logs in, and rejects a second email", async () => {
    const { app } = await createTestApp();
    const email = `owner-${uuid()}@test.local`;
    const signup = await app.inject({
      method: "POST",
      url: "/v1/auth/signup",
      payload: { email, password: "password1", display_name: "Ada" },
    });
    expect(signup.statusCode).toBe(201);
    const session = signup.json();
    expect(session.access_token).toBeTruthy();
    expect(session.user.role).toBe("owner");
    expect(session.user.plan).toBe("free");

    const dup = await app.inject({
      method: "POST",
      url: "/v1/auth/signup",
      payload: { email, password: "password1" },
    });
    expect(dup.statusCode).toBe(409);

    const login = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email, password: "password1" },
    });
    expect(login.statusCode).toBe(200);

    const me = await app.inject({
      method: "GET",
      url: "/v1/me",
      headers: { authorization: `Bearer ${session.access_token}` },
    });
    expect(me.statusCode).toBe(200);
    expect(me.json().email).toBe(email);
    await app.close();
  });
});

describe("logout", () => {
  async function loginAs(
    app: Awaited<ReturnType<typeof createTestApp>>["app"],
    email: string,
  ) {
    const res = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email, password: "password1" },
    });
    expect(res.statusCode).toBe(200);
    return res.json() as { access_token: string; refresh_token: string };
  }

  async function signupOwner(app: Awaited<ReturnType<typeof createTestApp>>["app"]) {
    const email = `owner-${uuid()}@test.local`;
    const signup = await app.inject({
      method: "POST",
      url: "/v1/auth/signup",
      payload: { email, password: "password1" },
    });
    expect(signup.statusCode).toBe(201);
    return email;
  }

  it("accepts a refresh token without a bearer and revokes only that family", async () => {
    const { app } = await createTestApp();
    const email = await signupOwner(app);
    const first = await loginAs(app, email);
    const second = await loginAs(app, email);

    const out = await app.inject({
      method: "POST",
      url: "/v1/auth/logout",
      payload: { refresh_token: first.refresh_token },
    });
    expect(out.statusCode).toBe(204);

    const revokedFamily = await app.inject({
      method: "POST",
      url: "/v1/auth/refresh",
      payload: { refresh_token: first.refresh_token },
    });
    expect(revokedFamily.statusCode).toBe(401);

    const otherFamily = await app.inject({
      method: "POST",
      url: "/v1/auth/refresh",
      payload: { refresh_token: second.refresh_token },
    });
    expect(otherFamily.statusCode).toBe(200);
    await app.close();
  });

  it("with a bearer token revokes every family and rejects missing or bad credentials", async () => {
    const { app } = await createTestApp();
    const email = await signupOwner(app);
    const first = await loginAs(app, email);
    const second = await loginAs(app, email);

    const out = await app.inject({
      method: "POST",
      url: "/v1/auth/logout",
      headers: { authorization: `Bearer ${first.access_token}` },
    });
    expect(out.statusCode).toBe(204);

    for (const refresh of [first.refresh_token, second.refresh_token]) {
      const attempt = await app.inject({
        method: "POST",
        url: "/v1/auth/refresh",
        payload: { refresh_token: refresh },
      });
      expect(attempt.statusCode).toBe(401);
    }

    const neither = await app.inject({ method: "POST", url: "/v1/auth/logout" });
    expect(neither.statusCode).toBe(401);

    const badRefresh = await app.inject({
      method: "POST",
      url: "/v1/auth/logout",
      payload: { refresh_token: "not-a-token" },
    });
    expect(badRefresh.statusCode).toBe(401);
    await app.close();
  });
});
