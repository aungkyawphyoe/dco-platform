# Theme sources

| Pair | Status | Purpose |
| --- | --- | --- |
| `garage-minimal-dark.json` / `garage-minimal-light.json` | Portal and site base tokens | Generated web CSS |
| `ascii-garage-dark.json` / `ascii-garage-light.json` | Mobile theme and marketing palette | Generated Flutter tokens and reference for site overrides |

The site imports generated `theme-tokens.css`, then site-scoped `marketing-tokens.css`, then layout rules in `marketing-theme.css`. The site palette overrides the baseline inside `.marketing-site`. Status and chart semantics remain inherited from the shared theme.

Run `node tools/generate-theme.mjs` after editing either pair. The site overrides in `marketing-tokens.css` are maintained separately. Keep the ASCII JSON and site palette aligned when changing brand colors.

Read [the implementation reference](ascii-garage-reference.md) for the mobile mapping and marketing layout rules.

Historical plans: [layout](../design-explorations/2026-11-19-marketing-layout-plan.md) and [implementation](../design-explorations/2026-11-19-marketing-implementation-plan.md).
