import { describe, expect, it } from "vitest";
import { createTestApp, uuid } from "./helpers.js";
import { eq } from "drizzle-orm";
import { users } from "../src/db/schema.js";

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

describe("username login", () => {
  it("logs in with username or email, case-insensitively", async () => {
    const { app, db } = await createTestApp();
    const email = `ada-${uuid()}@test.local`;
    const signup = await app.inject({
      method: "POST",
      url: "/v1/auth/signup",
      payload: { email, password: "password1", display_name: "Ada" },
    });
    expect(signup.statusCode).toBe(201);
    const username = signup.json().user.username;
    expect(username).toBeTruthy();

    const loginByUsername = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: username, password: "password1" },
    });
    expect(loginByUsername.statusCode).toBe(200);

    const loginByUpperUsername = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: username.toUpperCase(), password: "password1" },
    });
    expect(loginByUpperUsername.statusCode).toBe(200);

    const loginByEmail = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email, password: "password1" },
    });
    expect(loginByEmail.statusCode).toBe(200);

    const badPassword = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: username, password: "wrong" },
    });
    expect(badPassword.statusCode).toBe(401);

    const unknown = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: "nouser", password: "password1" },
    });
    expect(unknown.statusCode).toBe(401);
    await app.close();
  });
});

describe("change password", () => {
  it("requires current password, clears must_change_password, revokes refresh tokens", async () => {
    const { app, db } = await createTestApp();
    const email = `owner-${uuid()}@test.local`;
    const signup = await app.inject({
      method: "POST",
      url: "/v1/auth/signup",
      payload: { email, password: "password1" },
    });
    expect(signup.statusCode).toBe(201);
    const session = signup.json();
    const userId = session.user.id;

    const wrongCurrent = await app.inject({
      method: "POST",
      url: "/v1/auth/change-password",
      headers: { authorization: `Bearer ${session.access_token}` },
      payload: { current_password: "wrong", new_password: "password2" },
    });
    expect(wrongCurrent.statusCode).toBe(401);
    expect(wrongCurrent.json().error.code).toBe("invalid_password");

    const shortNew = await app.inject({
      method: "POST",
      url: "/v1/auth/change-password",
      headers: { authorization: `Bearer ${session.access_token}` },
      payload: { current_password: "password1", new_password: "short" },
    });
    expect(shortNew.statusCode).toBe(422);

    const changed = await app.inject({
      method: "POST",
      url: "/v1/auth/change-password",
      headers: { authorization: `Bearer ${session.access_token}` },
      payload: { current_password: "password1", new_password: "password2" },
    });
    expect(changed.statusCode).toBe(204);

    const oldRefresh = await app.inject({
      method: "POST",
      url: "/v1/auth/refresh",
      payload: { refresh_token: session.refresh_token },
    });
    expect(oldRefresh.statusCode).toBe(401);

    const loginOld = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email, password: "password1" },
    });
    expect(loginOld.statusCode).toBe(401);

    const loginNew = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email, password: "password2" },
    });
    expect(loginNew.statusCode).toBe(200);

    const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
    expect(user?.mustChangePassword).toBe(false);
    await app.close();
  });
});

describe("must_change_password guard", () => {
  it("blocks fleet API calls, allows personal routes and change-password", async () => {
    const { app, db } = await createTestApp();
    const email = `owner-${uuid()}@test.local`;
    const signup = await app.inject({
      method: "POST",
      url: "/v1/auth/signup",
      payload: { email, password: "password1" },
    });
    expect(signup.statusCode).toBe(201);
    const session = signup.json();
    const userId = session.user.id;

    await db.update(users).set({ mustChangePassword: true }).where(eq(users.id, userId));

    const fleetCall = await app.inject({
      method: "GET",
      url: "/v1/drivers/my-vehicle",
      headers: { authorization: `Bearer ${session.access_token}` },
    });
    expect(fleetCall.statusCode).toBe(403);
    expect(fleetCall.json().error.code).toBe("password_change_required");

    const personalCall = await app.inject({
      method: "GET",
      url: "/v1/vehicles",
      headers: { authorization: `Bearer ${session.access_token}` },
    });
    expect(personalCall.statusCode).toBe(200);

    const changePw = await app.inject({
      method: "POST",
      url: "/v1/auth/change-password",
      headers: { authorization: `Bearer ${session.access_token}` },
      payload: { current_password: "password1", new_password: "password2" },
    });
    expect(changePw.statusCode).toBe(204);

    const afterFleetCall = await app.inject({
      method: "GET",
      url: "/v1/drivers/my-vehicle",
      headers: { authorization: `Bearer ${session.access_token}` },
    });
    expect(afterFleetCall.statusCode).toBe(403);
    expect(afterFleetCall.json().error.code).toBe("driver_mode_required");
    await app.close();
  });
});