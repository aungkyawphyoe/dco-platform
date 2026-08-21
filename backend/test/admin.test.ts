import { describe, expect, it } from "vitest";
import { createTestApp, testEnv, uuid } from "./helpers.js";

describe("admin", () => {
  it("gates admin routes and lists users", async () => {
    const { app } = await createTestApp();
    const owner = await app.inject({
      method: "POST",
      url: "/v1/auth/signup",
      payload: { email: `o-${uuid()}@test.local`, password: "password1" },
    });
    const ownerTok = owner.json().access_token;
    const forbidden = await app.inject({
      method: "GET",
      url: "/v1/admin/dashboard",
      headers: { authorization: `Bearer ${ownerTok}` },
    });
    expect(forbidden.statusCode).toBe(403);

    const login = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: {
        email: testEnv.BOOTSTRAP_ADMIN_EMAIL,
        password: testEnv.BOOTSTRAP_ADMIN_PASSWORD,
      },
    });
    expect(login.statusCode).toBe(200);
    expect(login.json().user.role).toBe("admin");
    const dash = await app.inject({
      method: "GET",
      url: "/v1/admin/dashboard",
      headers: { authorization: `Bearer ${login.json().access_token}` },
    });
    expect(dash.statusCode).toBe(200);
    expect(dash.json().users_total).toBeGreaterThanOrEqual(2);
    await app.close();
  });
});
