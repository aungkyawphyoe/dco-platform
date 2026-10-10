# Onboarding illustrations

One illustration per introduction screen, in order:

| File | Screen | Localized copy |
|------|--------|----------------|
| `01-car-home.svg` | Digital garage and documents | `introGarageTitle` / `introGarageBody` |
| `02-service-reminders.svg` | Maintenance history and reminders | `introMaintenanceTitle` / `introMaintenanceBody` |
| `03-spending.svg` | Fuel, expenses, and stats | `introExpensesTitle` / `introExpensesBody` |

`01-car-home.svg` is also used by the optional first-vehicle screen after signup.

## Technical notes

- Registered in `pubspec.yaml` under `assets: - assets/onboarding/` and rendered with
  `flutter_svg` (`AuthIllustration` in `lib/features/auth/presentation/widgets/auth_illustration.dart`).
- Each file is an SVG wrapper (724×520 viewport, transparent background) around one panel of a
  shared 2172×724 PNG strip; the wrapper's `x` offset and `clipPath` select the panel.
- Artwork carries no copy. Headlines and captions stay in `lib/l10n/app_en.arb` /
  `app_my.arb`; the SVG `<title>` element is English-only metadata and is excluded from
  semantics by `AuthIllustration`.
- In dark mode the art renders on a `background.card` stage so the light vehicle stays
  legible; light mode renders it on the transparent scaffold.

## Provenance

- Supplied for the October 2026 onboarding revamp (10 October 2026); internal product asset,
  no third-party stock-license dependency.
- The embedded PNG carries C2PA content credentials (manifest `urn:c2pa:abd2575b-0243-45ba-bfa4-e6a5a26535cf`).
- Palette matches the Garage Minimal tokens (navy `#123`-family, gold `#FECA1F`, light greys).
