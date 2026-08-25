# DCO owner app (Flutter)

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
