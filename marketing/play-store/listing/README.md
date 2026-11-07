# Play Store listing copy

Reviewable copy for the Google Play listing. **Nothing here is published** — the
Play Console update is a separate, manual step after review.

Source of truth for what the app does: [`product/production-scope.md`](../../../product/production-scope.md).
Source of truth for plan limits: `backend/src/lib/plans.ts` (mirrored in
[`docs/pricing.md`](../../../docs/pricing.md)).

## Files

```text
listing/
  en-US/title.txt                app title
  en-US/short-description.txt    80-character limit
  en-US/full-description.txt     4000-character limit
  my-MM/…                        Burmese equivalents
  validate.mjs                   limit check
```

Edit the `.txt` files directly; Play Console takes plain text.

## Validate

```bash
node marketing/play-store/listing/validate.mjs
```

Checks title ≤ 30, short description ≤ 80, full description ≤ 4000 characters
(counted as Unicode code points), no trailing whitespace, and no triple blank
lines. Current state:

| Locale | Title | Short | Full |
|--------|-------|-------|------|
| en-US | 22 / 30 | 75 / 80 | 2147 / 4000 |
| my-MM | 19 / 30 | 77 / 80 | 2737 / 4000 |

## Claims and evidence

Every claim in the copy maps to shipped behavior. Check the row before changing
a sentence.

| Claim in the listing | Evidence |
|----------------------|----------|
| Garage, active vehicle switching, archive instead of delete | `product/frd/garage.md`, `architecture/data-model.md` (archive-not-delete) |
| Maintenance plan, suggested items, service history with cost/parts/notes | `product/frd/maintenance.md` |
| Reminders by date and by mileage | `product/frd/notifications.md` (local scheduling) |
| Refuel and charge logs with litres/kWh, price, odometer | `product/frd/fuel.md` |
| Fuel Stats: consumption, cost trend, cost per distance | `product/frd/stats.md` (status: Done) |
| Expenses by category with monthly totals | `product/frd/expenses.md` |
| Parts list per vehicle | `product/frd/parts.md` |
| Documents, photos and PDFs per vehicle | `product/frd/documents.md` (15 MB cap after compression) |
| Notes are device-only and never uploaded | `product/production-scope.md` — Notes has no outbox and no server API |
| Vehicle sharing with removable access | `product/frd/vehicle-sharing.md` |
| Offline records, sync when back online, sign-in needs a connection | `mobile/AGENTS.md` data-flow rules; auth is online-only |
| Fleet drivers sign in with an admin-created account | `product/frd/fleet-management.md` |
| English and Burmese; light/dark/system | `mobile/lib/l10n/`, `docs/design-system.md` |
| Free 1 vehicle / 1 share / 50 MB; Lite 3/3/150 MB; Standard 10/unlimited/500 MB; Fleet unlimited/unlimited/5 GB | `backend/src/lib/plans.ts` |

### Deliberately not claimed

These appear in older planning documents but are **not shipped**, so the listing
must not mention them: AI vehicle assistant, PDF/CSV reports, receipt scanning
or OCR, trip logs, insurance policy tracking, data import/export, API access, an
"encrypted document vault", or any security certification.

`docs/pricing.md` still carries the original feature matrix with some of these
rows. It is authoritative for plan names, prices, and numeric limits only.

## Offline wording

The app is offline-first for records, but authentication is online-only, and
Notes never leave the device. The copy therefore says:

- "Garage, maintenance, expenses, fuel logs, documents and notes work without a
  connection"
- "Changes sync when you are back online; signing in needs a connection"

Do not shorten this to "fully offline" or imply notes sync between devices.

## Plans

Plan limits are included so the "every vehicle" and "sharing" claims are not read
as unlimited on the free tier. Prices are not in the listing copy — Play shows
the store price and regional pricing is provider-controlled
([`docs/google-play-subscriptions.md`](../../../docs/google-play-subscriptions.md)).
If the release being published has Play billing disabled, keep the limits (they
are real) but do not add purchase calls to action.

## Screenshots and feature graphic

Assets in [`../out/`](../out) — regenerate with `../render.sh` and
`../render-sub-icons.sh`.

| Asset | Size | Requirement | Status |
|-------|------|-------------|--------|
| `feature-graphic.png` | 1024 × 500 | 1024 × 500 | ok |
| `play-store-1-dashboard.png` | 1080 × 1920 | 320–3840 px, 9:16 | ok |
| `play-store-2-maintenance.png` | 1080 × 1920 | same | ok |
| `play-store-3-expenses.png` | 1080 × 1920 | same | ok |
| `play-store-4-refuel.png` | 1080 × 1920 | same | ok |
| `play-store-5-garage.png` | 1080 × 1920 | same | ok |

`render.sh` renders all six files from the numbered Android captures in
[`../assets/`](../assets) and re-encodes them as 24-bit PNGs at the exact sizes.

Caption check (from [`../index.html`](../index.html)):

| Caption | Accurate? |
|---------|-----------|
| "Quick actions" / "Works offline" | Yes — offline records, dashboard quick actions |
| "Date & km alerts" / "Service log" | Yes |
| "Category totals" / "Monthly totals" | Yes — expenses summary and category breakdown |
| "Litres & cost" / "Month filter" | Yes — refuel list with "This month" filter |
| "Multi-vehicle" / "Full history" | Yes — multi-vehicle is a paid-plan capability, disclosed under Plans |

Regenerate the phone frames from a build that matches the release you publish.
Consider a Burmese screenshot set as well; Play shows per-language images.

## Before publishing

1. Compare against the currently published text. The Play listing URL could not
   be retrieved and no copy is stored in this repository, so a diff against
   production has **not** been done. Paste the live text into
   `listing/published-baseline.txt` (or share it) to close this item.
2. Have a native Burmese speaker review `my-MM/` — the translation is drafted,
   not professionally reviewed.
3. Confirm the release being published contains every claimed feature and that
   `mobile/pubspec.yaml`'s version code is above the last upload.
4. In Play Console, add the `my-MM` listing locale if it is not already present.
5. Update the store listing only after the copy is approved; this folder does
   not publish anything.

## Related

- [`docs/tester-feedback-implementation-plan.md`](../../../docs/tester-feedback-implementation-plan.md) — Phase 4 scope
- [`docs/tester-feedback-auth-baseline.md`](../../../docs/tester-feedback-auth-baseline.md) — baseline gaps
- [`product/production-scope.md`](../../../product/production-scope.md) — shipped feature set
