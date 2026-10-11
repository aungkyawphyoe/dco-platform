# Auth provider marks

Identity marks for the Google and Apple sign-in buttons (login, signup, welcome, account connections).

| File | Provenance |
|------|------------|
| `google.svg` | Official Google "G" logo from the Google Brand Assets / Sign in with Google guidelines (multicolor, used as provided). |
| `apple.svg` | Apple logo path from Simple Icons (CC0 1.0 / simple-icons npm package), rendered monochrome via `ColorFilter` at usage sites. |

Both are vector recreations of the providers' identity marks and follow the providers' brand guidelines (clear space, no recoloring of the Google mark, no alteration of proportions). Do not edit the paths.

Rendered with `flutter_svg` in `lib/features/auth/presentation/widgets/social_buttons.dart`.
