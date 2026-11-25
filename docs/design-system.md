# AutoX design system

The Flutter owner app uses ASCII Garage, including its mobile corner sizes. The admin and fleet portals use Garage Minimal. See [theme sources](theme/README.md) for both light and dark token pairs.

**Modes:** dark and light (default follows the system).  
**Garage Minimal:** gold `#FECA1F` on navy in dark mode. Light mode uses deep brass `#876800` accents on cool gray with white cards.

**Fixed-color exemptions (intentional, not drift):** QR codes stay dark modules on white in both modes (they do not scan otherwise); brand logo plates keep their white background in both modes.

---

## Garage Minimal dark palette

| Token | Value | Role |
|-------|--------|------|
| background.primary | `#101B22` | Screen / scaffold |
| background.secondary | `#1A2832` | Sections, sidebar |
| background.card | `#1E2D38` | Cards, sheets |
| text.primary | `#FFFFFF` | Titles, values |
| text.secondary | `#A8B6C1` | Supporting copy |
| text.tertiary | `#6C7D8A` | Icons, placeholders |
| text.accent | `#FECA1F` | Brand / active |
| button.primary | gold fill, navy text | Main action |
| button.secondary | card fill, light border | Secondary action |
| button.tertiary | text-only gold | Text button |
| icon active / inactive | gold / slate | Nav and tabs |

These values are kept. Contrast of white and secondary text on all three surfaces passes WCAG AA. Primary button text on gold is 9.6:1.

---

## Problems in the original set

1. **Tertiary text is not AA for small copy on cards** (`#6C7D8A` on `#1E2D38` is 3.3:1). Keep it for icons and placeholders. Use **caption** `#8A9BA8` for helper text on cards.
2. **Divider `#1E2D38` is the same as card.** A divider on a card disappears. Use **subtle** on the primary screen only; on cards use **divider** `#2A3C48` or **default** `#6C7D8A`.
3. **Secondary button border `#3A4D5C` on card is 1.6:1** — below the 3:1 UI-component floor. Default border is now `#6C7D8A` (same as inactive icons).
4. **No status colors.** Overdue, sync failed, and form errors cannot share the brand gold or they stop meaning “brand.” Added success / warning / danger / info.
5. **No hover, pressed, disabled, focus, overlay, or input field.** Both Flutter and web need those before implementation.
6. **Color only is not a theme.** Radius, space, type, and motion are in the JSON so both apps space and type the same way.

---

## Additions (required)

### Mobile cards — required for all new and redesigned features

Cards use **elevation and soft shadows, with no permanent border**. Use Flutter `DcoCard` (`mobile/lib/core/widgets/dco_card.dart`) for the shared `background.card` surface, `radius.lg` corners, and `shadows.card`; use `shadows.elevated` for a featured plan or other primary card. Default Flutter `Card` also has elevation and no outline. Selected cards use a filled surface and an explicit selection icon, not a border. Keep shadows outside clipping parents and leave enough spacing to see their depth in both themes.

This applies to future mobile feature implementations and to cards being redesigned. Borders on input controls, separators between rows, and keyboard-focus indicators are not card outlines and remain available for accessibility.

### Surfaces

- `input` `#16242D` — fields sit slightly darker than cards
- `nav` — same as primary (bottom bar / web top bar)
- `overlay` `#101B22B8` — modal scrim
- `skeleton` `#243441` — loading blocks

### Text

- `caption` — muted copy that still reads on cards
- `onAccent` / `inverse` — navy on gold
- `disabled`, `link`

### Buttons

Hover / pressed / disabled for primary, secondary, tertiary.  
**Destructive** is outline rust (`#E07A6C`), not a red fill — keeps the garage quiet.

### Status and product feedback

| Token | Hex | Use |
|-------|-----|-----|
| success / healthy | `#7CB89A` | Plan item OK, sync up to date |
| warning / due soon | `#E39A3C` | Due soon (not brand gold) |
| danger / overdue | `#E07A6C` | Overdue, form error, deactivate |
| info / queuedSync | `#7AA0B8` | Offline queued, informational |

### Input

Background, default border, focus = gold, error = danger, placeholder = tertiary.

### Expense chart hues

Separate from brand gold so a fuel *expense* slice does not look like a selected nav item.

### Radius, space, type, motion

- 4px grid (`space.1` … `space.7`)
- Cards `radius.md` 8; pills `radius.full`
- **Barlow** for titles (condensed workshop signage)
- **IBM Plex Sans** for body (spec-sheet, readable)
- **IBM Plex Mono** for VIN, plates, amounts
- Motion 120–180ms; honor reduced-motion

Load on mobile via `google_fonts`. Load on web via Google Fonts or self-host the same families. Do not substitute Inter / Roboto without updating this file.

---

## How to use gold

Allowed: primary button, active icon, focus ring, selected vehicle chip, text links.

Not allowed: screen backgrounds, overdue badges, chart-only decoration, large hero blocks.

---

## Platform mapping

After editing a theme JSON file, run `node tools/generate-theme.mjs` from the repo root. The generator checks that the dark and light keys match within each pair. `mobile/build.yaml` excludes the Node-generated Flutter theme from Dart `build_runner`. Run `dart run build_runner build` from `mobile/` to generate other Dart models.

### Flutter

`buildDcoTheme(Brightness)` picks `DcoTokens.asciiGarageDark` or `DcoTokens.asciiGarageLight`. The app applies the mode selected in Settings → Appearance. A device-wide copy (`entry.theme`) supplies the preference for the introduction and auth screens when signed out.

Dark mode uses a black page, charcoal cards, and amber `#FFA31A` accents. Light mode uses a warm white page `#F7F7F5`, white cards, and deep amber `#965100` for accent text, icons, and focus rings. Both modes use black text on amber primary buttons.

`ThemeData`:

- `scaffoldBackgroundColor` → background.primary
- `cardColor` → background.card
- `colorScheme.primary` → text.accent
- `colorScheme.onPrimary` → text.onAccent
- `colorScheme.error` → status.danger.fg
- `navigationBarTheme` icons → icon.active / icon.inactive

No Material 3 default purple. Seed from these files only.

### Web (admin + fleet)

Generated `theme-tokens.css` defines the CSS variables under `:root, html.light` (light values) and `html.dark` (dark values). The `dco_theme` cookie carries the user's Light / Dark / System choice; SSR renders the class and a pre-paint inline script resolves `system` via `prefers-color-scheme` (no flash). Example:

```css
html.light {
  --bg-primary: #f4f6f8;
  --bg-card: #ffffff;
  --text-primary: #101b22;
  --accent: #876800;
  --radius-md: 8px;
}
```

The shell is the same in both modes. Tables sit on `background.card`; sticky header on `background.secondary`.

### Garage Minimal light mode notes

- **Gold splits in two:** bright `#FECA1F` stays as button/chip **fill** (with `text.onAccent`); accent **text**, links, focus rings, and active icons use deep brass `#876800` (AA on white and on the gray page).
- Status and chart hues are darkened variants (all ≥ 3:1 on white; status text ≥ 4.5:1).
- Cards are pure white on a `#F4F6F8` page.

---

## Accessibility

- Body and titles: primary or secondary text only
- Helper text on cards: caption, not tertiary
- Focus visible: `border.focus` 2px, never remove outlines
- Do not convey overdue by color alone — keep the word “Overdue” / icon
- Hit targets 44×44 on mobile; 32px min on admin tables with padding

---

## Source of truth

1. This document for rules  
2. [Theme sources](theme/README.md) for values

If a screen needs a new color, add it here first. Do not one-off hex in widgets.

### Marketing website

The public AutoX site uses ASCII Garage in a site-local CSS layer. Plex Sans carries headings and text. Square panels and shared vertical rails frame real product captures. The highway on the homepage uses square-cell animation, and supporting garage illustrations use static characters. The footer and closing invitations use a full amber ground with black ink. These choices apply to the marketing and legal routes in `site/`.
