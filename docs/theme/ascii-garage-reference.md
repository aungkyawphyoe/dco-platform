# ASCII Garage implementation reference

The marketing site is the reference implementation. Admin, fleet portal and mobile retain their existing theme until each module has its own migration.

## Sources and ownership

- `ascii-garage-dark.json` and `ascii-garage-light.json` describe the palette and proposed semantic mappings.
- `site/src/app/marketing-tokens.css` contains the active site palette. It overrides generated base tokens only within `.marketing-site`.
- `site/src/app/marketing-theme.css` owns site geometry, typography, responsive layouts and amber feature bands.
- `site/src/components/marketing` holds the current section, screenshot, navigation and ASCII components. `art/` contains deterministic text scenes selected by the typed `GarageArt` registry.

## Visual rules

Use IBM Plex Sans for headings, body and controls; use IBM Plex Mono for section labels and artwork. Keep locale fallbacks and Myanmar line-height rules. Headings use weight 600 and tight English leading. Use `HighlightedTitle` with dictionary `titleHighlight` or `headingHighlight` values to color a phrase without a background rectangle.

Dark surfaces use black, off-white text and brand amber `#FFA31A`. Light surfaces use warm white and black text; small accent text and links use deep amber `#965100`. Keep semantic warning, error, success and chart colors distinct from branding.

The service-history band and footer stay amber with black ink in both themes. Their contrast must not depend on the selected theme. Use square controls with visible borders and at least 44px interaction height. Preserve visible keyboard focus.

The content rail is at most 1280px. Its width is `min(1280px, calc(100% - clamp(24px, 4.5vw, 64px)))`; section gutters use `clamp(20px, 3.5vw, 48px)`. Section dividers extend across the viewport. Rail intersections show a small plus except at yellow sections and the footer. The header divider stays plain.

## Artwork and motion

ASCII scenes use character density, restrained amber details and a common monospace grid. Keep scenes relevant to nearby copy. The service-history scene represents records retained offline and synchronized later; the audience globe and personal-page question mark support their respective sections.

Keep artwork decorative (`aria-hidden`) when nearby text communicates its meaning. Preserve the inner span in the ASCII `pre` renderer so HTML parsing does not strip a leading newline and cause hydration differences. Use deterministic artwork on server and client.

The hero scene owns its animation lifecycle and reduced-motion behavior. Do not copy marketing animation into routine product forms. The mobile hero art uses a 390/340 aspect ratio, with headline sizing starting at 44px; it has no fixed 750px mobile height.

## Reuse in another module

1. Map semantic palette values to the module's existing token system. Keep the current shared generator unchanged until migration scope is explicit.
2. Adopt fonts and controls with that platform's accessibility and localization requirements. Marketing heading sizes are not form defaults.
3. Reuse palette semantics and artwork conventions. Adapt rails, full-width sections and dense ASCII to the module's actual layout.
4. Verify light/dark themes, keyboard focus, reduced motion, Myanmar content and narrow screens. Check amber bands independently of theme toggles.

## Wrap-up analysis

The current design has one marketing palette, one layout stylesheet and one ASCII scene registry. Unused card-grid components, the static theme-lab prototype, old Barlow fonts, the previous footer logo image, unused full-screen captures and the superseded road scene have been removed. Active screenshot crops, reusable section components and shared product themes remain.

The palette extraction preserves values and cascade order. Existing route text is the refactor baseline. Download corrections are intentional behavior changes: configured stores appear separately, absent stores are hidden, and pricing falls back to Personal when Play Store is unavailable. Docker builds now accept both store URLs at build time. See [deployment configuration](../deployment.md#marketing-store-links).

This reference does not certify production configuration or migrate the other applications. Confirm the production build receives the intended store URLs before deployment.
