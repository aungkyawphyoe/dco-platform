# Architecture

MVP system design. Product contract remains `product/mvp-scope.md`.

| Document | Contents |
|----------|----------|
| [system.md](system.md) | Surfaces, trust boundaries, JWT, offline vs online, media, Container Apps |
| [iam.md](iam.md) | Owner/admin IAM and future fleet/partner map |
| [iam-vehicle-sharing.md](iam-vehicle-sharing.md) | Vehicle sharing authorization model, permission gates, route guards |
| [data-model.md](data-model.md) | ERD (including share tables), mileage/archive rules, Autozis comparison |
| [data-model-vehicle-sharing.md](data-model-vehicle-sharing.md) | Share schema detail, access control matrix, query patterns, migration |
| [feature-gating.md](feature-gating.md) | Offline tier gating: signed Ed25519 license, clock-tamper guard, FeatureGate, limit enforcement |
| [api.md](api.md) | Pointer to the OpenAPI file |
| [openapi.yaml](openapi.yaml) | `/v1` REST contract for mobile and admin (includes vehicle sharing endpoints) |

As-built product guide (what the code does today): `docs/mvp-as-built.md`.

Related UX:

- Owner + admin navigation: `docs/app-shell.md`
- Dashboard FRD: `product/frd/dashboard.md`
- Admin wireframes: `wireframes/dco-mobile-wireframes.tldraw` (frames A1–A6)
- Secrets draft: `docs/environment-secrets.md`
