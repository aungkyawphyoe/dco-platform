# AutoX owner app (Flutter)

Offline-first digital garage. Agent contract: [AGENTS.md](AGENTS.md).

## Run

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
flutter test
```

Auth talks to `API_BASE_URL` (default `http://localhost:8080/v1`). Until the API exists, debug builds use **mock auth** (`DCO_MOCK_AUTH` defaults to true, forced off in release).

### Quick start (local dev — mock auth)

```bash
flutter run
```

### Pointing at prod

Config files live in `config/`. Pass them with one flag — no need to repeat defines every build:

```bash
flutter run --dart-define-from-file=config/prod.json
flutter build apk --dart-define-from-file=config/prod.json
```

The file sets both `API_BASE_URL` and `DCO_MOCK_AUTH=false` so release builds always hit prod.

Any valid email + 8-character password signs in when mock auth is on.

### Android edge-to-edge release check

The app explicitly enables Flutter's edge-to-edge mode before startup. The
shared `DcoSystemUi` paints the system-bar background and consumes bottom/side
safe insets once; app bars and full-screen layouts retain responsibility for
the top inset. Overlay styles request icon brightness only. Android 15+ splash
themes use the `always` display-cutout mode.

Before uploading the next bundle, check Android 14, 15 and 16 with gesture and
three-button navigation, light/dark themes, portrait/landscape, and an open
keyboard. Exercise login, the floating tab bar, a long form's save button,
bottom sheets, photo cropping and browser sign-in. Check Burmese and English.

Build with a version code higher than the latest Play upload (the screenshot
shows code 2):

```sh
flutter build appbundle --release --dart-define-from-file=config/prod.json --build-number=3
```

Play's deprecated-API finding can include Flutter embedding and plugin code,
even after app-owned color setters are removed. Expand that finding in Play
Console and inspect its method/class list if it remains after uploading. Do
not claim it is cleared until Play has processed the new bundle. See
[Flutter's migration guide](https://docs.flutter.dev/release/breaking-changes/default-systemuimode-edge-to-edge).
