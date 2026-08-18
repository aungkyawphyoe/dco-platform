# Design system — Garage Minimal Dark

Shared visual language for the **Flutter owner app** and the **web admin portal**. Tokens live in [`garage-minimal-dark.json`](theme/garage-minimal-dark.json). Do not invent extra hexes in UI code.

**Mode:** dark only for MVP.  
**Signature:** brass bay-light (`#EEB757`) on painted-steel navy. Gold is for primary actions and the active vehicle — not for large fills, not for overdue.

---

## What you supplied

| Token | Value | Role |
|-------|--------|------|
| background.primary | `#101B22` | Screen / scaffold |
| background.secondary | `#1A2832` | Sections, sidebar |
| background.card | `#1E2D38` | Cards, sheets |
| text.primary | `#FFFFFF` | Titles, values |
| text.secondary | `#A8B6C1` | Supporting copy |
| text.tertiary | `#6C7D8A` | Icons, placeholders |
| text.accent | `#EEB757` | Brand / active |
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

### Flutter

Map into `ColorScheme` + a `ThemeExtension<DcoTokens>` that exposes the JSON 1:1 (status, radius, space).  
`ThemeData`:

- `scaffoldBackgroundColor` → background.primary
- `cardColor` → background.card
- `colorScheme.primary` → text.accent
- `colorScheme.onPrimary` → text.onAccent
- `colorScheme.error` → status.danger.fg
- `navigationBarTheme` icons → icon.active / icon.inactive

No Material 3 default purple. Seed from this file only.

### Web (admin)

CSS variables on `:root` from the same JSON (build step or copied once). Example:

```css
:root {
  --bg-primary: #101B22;
  --bg-card: #1E2D38;
  --text-primary: #ffffff;
  --accent: #eeb757;
  --radius-md: 8px;
}
```

Admin uses the same dark shell. Tables sit on `background.card`; sticky header on `background.secondary`.

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
2. [`docs/theme/garage-minimal-dark.json`](theme/garage-minimal-dark.json) for values  

If a screen needs a new color, add it here first. Do not one-off hex in widgets.
