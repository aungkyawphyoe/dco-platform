# Implementation readiness

What must exist before Flutter, web, or API code starts. Theme tokens are done (`docs/design-system.md`). Everything below is still a gap.

Contract for *what* to build remains `product/mvp-scope.md` and `product/frd/`.

---

## Must have (blockers)

| Document | Why |
|----------|-----|
| **Architecture overview** (`architecture/system.md`) | Surfaces, trust boundaries, offline vs online, where JWT lives, how media is stored. Empty `architecture/` folder today. |
| **Data model / ERD** | Users, vehicles, plan items, service records, documents, expenses, outbox, partners, plan field. Mileage monotonicity and archive rules live here. |
| **API contract** (OpenAPI or equivalent) | Versioned REST, auth, change-log/sync, media upload. Mobile and web cannot be coded against prose FRDs alone. |
| **App shell / navigation IA** | Bottom nav items, admin IA, which screen is default after login. Wireframes exist; they are not written as a nav spec. |
| **Dashboard FRD** | Ownership summary is specified in MVP scope but has no FRD. It is the first screen owners see. |
| **Web admin wireframes** | Only the mobile tldraw board exists. Admin list/detail/partner flows are FRD-only. |
| **Environment & secrets** | Dev/stage/prod, email provider, media bucket, who holds signing keys. |

## Should have (do before the first vertical slice)

| Document | Why |
|----------|-----|
| **Sync sequence** | Outbox → push → conflict → pull. `sync.md` is the product rule; engineering needs a sequence diagram and cursor format. |
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

---

## Suggested build order once docs above exist

1. Theme tokens in both apps (this design system)
2. Auth + app shell
3. Garage (active vehicle)
4. Sync outbox on those writes
5. Maintenance → Documents → Expenses
6. Notifications (local)
7. Admin portal against the same API
