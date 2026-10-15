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

  it("creates users with a temporary password and a verified email (no email sent)", async () => {
    const { app } = await createTestApp();
    const login = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: {
        email: testEnv.BOOTSTRAP_ADMIN_EMAIL,
        password: testEnv.BOOTSTRAP_ADMIN_PASSWORD,
      },
    });
    expect(login.statusCode).toBe(200);
    const token = login.json().access_token as string;

    const email = `provisioned-${uuid()}@test.local`;
    const created = await app.inject({
      method: "POST",
      url: "/v1/admin/users",
      headers: { authorization: `Bearer ${token}` },
      payload: { email, temporary_password: "TempUser123!", display_name: "Provisioned User" },
    });
    expect(created.statusCode).toBe(201);
    expect(created.json().email_verified).toBe(true);
    expect(created.json().must_change_password).toBe(true);

    const userLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email, password: "TempUser123!" },
    });
    expect(userLogin.statusCode).toBe(200);
    expect(userLogin.json().user.email_verified).toBe(true);

    const duplicate = await app.inject({
      method: "POST",
      url: "/v1/admin/users",
      headers: { authorization: `Bearer ${token}` },
      payload: { email, temporary_password: "TempUser123!" },
    });
    expect(duplicate.statusCode).toBe(409);
    expect(duplicate.json().error.code).toBe("email_taken");
    await app.close();
  });
});
