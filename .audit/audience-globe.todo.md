- [x] Trace the affected subsystem.
- [x] architect for the shape.
  Data shape: static multiline globe string in existing GarageArt registry.
  Options: reuse GarageArt or add a separate renderer. Reuse preserves theme, responsive sizing and hydration handling.
- [x] Write the throughput checkpoint as four todo items.
  Blocking first steps: inspect renderer and audience section.
  Independent workstreams: n/a, single illustration and placement.
  Shared mutable state: delegate returns text without filesystem writes.
  Smallest safe decomposition: one art delegate, parent integrates and reviews.
- [x] Delegate code-writing to a subagent.
- [x] Verify on the matching surface. Inspected rendered desktop and mobile screenshots. No browser errors or overflow.
- [ ] Rebase into small, ordered commits. Stack follow-ups.
  skip: user requested a local UI edit, no commit or branch work.
- [ ] If the design is contested, interrogate before shipping.
  skip: reference and placement specified by user.
- [ ] Run Opening a PR.
  skip: local preview work only.
