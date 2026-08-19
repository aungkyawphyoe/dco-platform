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

Auth talks to `API_BASE_URL` (default `http://localhost:8080/v1`). Until the API exists, debug builds use **mock auth** (`DCO_MOCK_AUTH` defaults to true, forced off in release):

```bash
flutter run --dart-define=DCO_MOCK_AUTH=true
flutter run --dart-define=DCO_MOCK_AUTH=false --dart-define=API_BASE_URL=http://localhost:8080/v1
```

Any valid email + 8-character password signs in when mock auth is on.
