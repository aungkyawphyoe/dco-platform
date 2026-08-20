# Feature Requirement Documents (FRDs)

This directory contains the functional specifications for every feature of the Digital Car Ownership Platform.

Each FRD is self-contained and serves as the primary source of truth for:

- Product Managers
- Designers
- Engineers
- QA Engineers
- AI Development Agents

Scope contract: `product/mvp-scope.md`. If an FRD disagrees with that file, the MVP scope wins and the FRD must be updated.

---

## Index (MVP)

| Module | File | Surface |
|--------|------|---------|
| Dashboard | [dashboard.md](dashboard.md) | Mobile (default after login) |
| Garage | [garage.md](garage.md) | Mobile |
| Auth | [auth.md](auth.md) | Mobile + API |
| Maintenance | [maintenance.md](maintenance.md) | Mobile + API |
| Documents | [documents.md](documents.md) | Mobile + API |
| Expenses | [expenses.md](expenses.md) | Mobile + API |
| Sync | [sync.md](sync.md) | Mobile + API |
| Notifications | [notifications.md](notifications.md) | Mobile + API |
| Parts | [parts.md](parts.md) | Mobile |
| Fuel | [fuel.md](fuel.md) | Mobile |
| Admin | [admin.md](admin.md) | Web portal + API |

Dashboard consumes Garage, Maintenance, Expenses, and Documents. Navigation: `docs/app-shell.md`. API: `architecture/openapi.yaml`.

---

## Purpose

Each FRD defines:

- Business objective
- User problems
- User stories
- Functional requirements
- Business rules
- Acceptance criteria
- Edge cases
- Non-functional requirements
- Dependencies
- Analytics
- Future enhancements

## FRD Template

Every feature follows the same structure:

1. Overview
2. Objectives
3. Scope
4. User Personas
5. User Stories
6. Functional Requirements
7. Business Rules
8. User Flow
9. Validation Rules
10. Error States
11. Non-Functional Requirements
12. Analytics Events
13. Success Metrics
14. Dependencies
15. Future Enhancements
