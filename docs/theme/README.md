# Theme sources

| Pair | Status | Purpose |
| --- | --- | --- |
| `garage-minimal-dark.json` / `garage-minimal-light.json` | Shared baseline | Generated mobile, admin and fleet portal tokens; site base tokens |
| `ascii-garage-dark.json` / `ascii-garage-light.json` | Active site reference | Marketing palette and future module migration reference |

The site imports generated `theme-tokens.css`, then site-scoped `marketing-tokens.css`, then layout rules in `marketing-theme.css`. The site palette overrides the baseline inside `.marketing-site`. Status and chart semantics remain inherited from the shared theme.

`tools/generate-theme.mjs` still reads `garage-minimal-*`. Running it does not regenerate the ASCII overrides. Keep the ASCII JSON and site palette aligned when changing brand colors. Both reference JSON files have matching keys; their application-scale values are migration proposals, not a claim that other modules have adopted them.

Read [the implementation reference](ascii-garage-reference.md) before revamping another module. Select target-specific mappings and verify that platform before changing the shared generator. Do not replace all modules' tokens as a side effect of a site update.

Historical plans: [layout](../design-explorations/2026-11-19-marketing-layout-plan.md) and [implementation](../design-explorations/2026-11-19-marketing-implementation-plan.md).
