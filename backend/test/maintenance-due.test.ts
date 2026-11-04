import { describe, expect, it } from "vitest";
import { dueFrom } from "../src/lib/catalog.js";

describe("maintenance next due calculation", () => {
  it("uses calendar months and years at month ends and leap days", () => {
    expect(dueFrom(null, null, 0, "2026-01-31", 1, "months").nextDueOn).toBe("2026-02-28");
    expect(dueFrom(null, null, 0, "2028-02-29", 1, "years").nextDueOn).toBe("2029-02-28");
    expect(dueFrom(null, null, 0, "2026-01-15", 6, "months").nextDueOn).toBe("2026-07-15");
  });
  it("anchors a backdated service to its actual date and odometer", () => {
    expect(dueFrom(30, 5000, 32800, "2026-01-15")).toEqual({
      nextDueOn: "2026-02-14",
      nextDueMileage: 37800,
    });
  });

  it("handles leap days without changing the service date's timezone", () => {
    expect(dueFrom(1, null, 0, "2028-02-28")).toEqual({
      nextDueOn: "2028-02-29",
      nextDueMileage: null,
    });
  });

  it("calculates distance-only reminders without adding a date", () => {
    expect(dueFrom(null, 5000, 33000, "2026-01-15")).toEqual({
      nextDueOn: null,
      nextDueMileage: 38000,
    });
  });
});
