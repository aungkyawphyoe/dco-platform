# Theme sources

| Pair | Status | Purpose |
| --- | --- | --- |
| `garage-minimal-dark.json` / `garage-minimal-light.json` | Active | Current shared mobile, admin, fleet portal and marketing tokens |
| `ascii-garage-dark.json` / `ascii-garage-light.json` | Candidate | Black/amber marketing direction, prepared for later mobile and portal migration |

The candidate pair keeps the existing semantic token structure and adds a matching `marketing` group for the footer, framed grid, poster and reveal specification. Both files have identical keys. Brand amber is `#FFA31A`; light-mode text uses deep amber `#965100`. Status/feedback/chart colors retain their current meanings.

`tools/generate-theme.mjs` still reads the active `garage-minimal-*` files. Adding these candidate files does not change any generated CSS or Dart tokens. Do not overwrite the active files or run a broad migration as part of a marketing-only revamp.

When adopting the candidate, explicitly select its pair in the generator, map any added values needed by the target, and validate the affected platform. Core type sizes remain application-scale; larger marketing sizes live in `marketing.typography`. Marketing reveals and poster settings do not belong in routine product interactions. Review square component geometry against the current mobile-card and accessibility requirements before migrating mobile/portal.

Current plans: [layout](../design-explorations/2026-11-19-marketing-layout-plan.md) and [implementation](../design-explorations/2026-11-19-marketing-implementation-plan.md). Candidate JSON is the future theme source; the isolated preview has not yet been connected to the shared token generator.
