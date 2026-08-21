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
