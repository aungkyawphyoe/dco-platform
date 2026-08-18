# Implementation readiness

What must exist before Flutter, web, or API code starts. Theme tokens are done (`docs/design-system.md`). **Must-have docs below are written.** Remaining items are should-have ADRs and engineering catalogs.

Contract for *what* to build remains `product/mvp-scope.md` and `product/frd/`.

---

## Must have (blockers) — done

| Document | Location |
|----------|----------|
| **Architecture overview** | [`architecture/system.md`](../architecture/system.md) — surfaces, trust boundaries, JWT, offline vs online, media. Azure VPS is planned, not provisioned. |
| **Data model / ERD** | [`architecture/data-model.md`](../architecture/data-model.md) — entities, mileage/archive, Autozis compare |
| **API contract** | [`architecture/openapi.yaml`](../architecture/openapi.yaml) (index: [`architecture/api.md`](../architecture/api.md)) |
| **App shell / navigation IA** | [`docs/app-shell.md`](app-shell.md) — four-tab owner shell; admin A1–A6 |
| **Dashboard FRD** | [`product/frd/dashboard.md`](../product/frd/dashboard.md) |
| **Web admin wireframes** | [`wireframes/dco-mobile-wireframes.tldraw`](../wireframes/dco-mobile-wireframes.tldraw) frames **A1–A6** (WEB ADMIN cluster) |
| **Environment & secrets** | [`docs/environment-secrets.md`](environment-secrets.md) — **draft** (placeholders; VPS setup later) |

## Should have (do before the first vertical slice)

| Document | Why |
|----------|-----|
| **Sync sequence** | Outbox → push → conflict → pull. `product/frd/sync.md` is the product rule; cursor format is sketched in OpenAPI (`GET /v1/sync/changes`). A sequence diagram is still worth adding. |
| **Error, empty, and loading catalog** | Copy and layout for the states already named in FRDs. Fits the design system. |
| **Privacy / retention** | What is stored locally vs server, how delete-account will work later, document file retention. Principle 5 is otherwise unimplemented. |
| **Test strategy** | Domain tests for mileage, due dates, sync idempotency; what CI runs on mobile vs API vs web. |
| **Web stack ADR** | Mobile is Flutter. Backend is REST + JWT. **Web framework is not chosen.** Pick one before `web/` scaffolding. |
| **Backend stack ADR** | Language, DB, migration tool. Same: not chosen. |

## Can wait until after the first slice

- Component Storybook / widget catalog (build from the theme as screens land)
- Push provider runbook (register token now; send later)
- Marketing site and store listing copy
- Light theme
- Localization plan beyond one locale
- Azure VPS runbook (env map exists; provisioning deferred)

---

## Suggested build order

1. Theme tokens in both apps (this design system)
2. Auth + app shell (Dashboard as default after login)
3. Garage (active vehicle)
4. Sync outbox on those writes
5. Maintenance → Documents → Expenses
6. Notifications (local)
7. Admin portal against the same API
