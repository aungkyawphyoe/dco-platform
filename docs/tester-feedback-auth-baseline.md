# Tester feedback: Phase 0 baseline and Phase 1 investigation

Date: 1 November 2026 (Asia/Rangoon).

## Verified baseline

- Source baseline: `fd004e0` on `main`; implementation branch: `codex/tester-feedback-auth`.
- Mobile declared version: `1.0.0+2`. Uploaded Play version/code and corresponding commit are not yet verified. A build-number override can differ from pubspec.
- Production mobile API: `https://api.autoxmm.com/v1`; mock auth disabled by production config and always disabled in release.
- Report contains no build/device/browser versions, failure time, screenshots, or concrete reproduction steps. User confirms no screenshots are available.
- Play listing URL could not be retrieved through the web tool. Published short/full description and screenshots remain unverified; do not infer that the listing is unavailable to testers.
- Running Azure backend when inspected: image `dcoacr24739.azurecr.io/dco-api:v1.7.19`, ready revision `dco-api-24739--0000045`. Image tag alone does not establish its source commit.

## Reproduced production blocker

A single unauthenticated POST to `/v1/auth/social/google/start` with an empty JSON object returned:

```json
{"error":{"code":"provider_not_configured","message":"This sign-in provider is not configured yet","details":{}}}
```

No flow, exchange secret, or authorization URL was returned. Google was never reached. Read-only Azure inspection of environment names and secret references confirmed that the running backend has neither `GOOGLE_CLIENT_ID` nor `GOOGLE_CLIENT_SECRET` configured. Secret values were not retrieved or printed.

This is a confirmed current production configuration failure. Without the tester's historical build/time, it is not proof of the exact failure they encountered. Mobile callback/signing changes would not resolve this failure.

## Implemented client work

- Retain the existing localized provider-unavailable explanation and email sign-in option.
- Map expired/invalid flows to explicit restart guidance in English/Burmese.
- Distinguish server responses with malformed/unstructured errors from network transport failures; malformed error payloads no longer trigger unsafe indexing/casts.
- Validate start response fields before launching the browser.
- Prevent duplicate social-button submission; each new authorization attempt requests a fresh flow.
- Add `auth_social_stage` events for provider start, browser return, completion, and linking, recording only fixed stage/outcome categories and elapsed milliseconds. Existing analytics configuration/opt-out applies. No URL, email, token, flow secret, raw error, or new persistent identifier is emitted. These stages do not claim that session installation succeeded.
- Add injectable browser boundary and regression coverage for Google/Apple cancellation/retry, invalid callbacks, missing configuration, malformed responses, and localized failure messages.

## Production resolution — verified 1 November 2026

- Google Auth Platform was initially unconfigured in `autox-512507`. The user completed setup and created a web OAuth client with the exact redirect `https://api.autoxmm.com/v1/auth/social/google/callback`.
- Downloaded client JSON metadata was validated without displaying its secret.
- Automatic approval review rejected the agent's proposed production update because authorization to transmit the secret was not explicit. No agent production mutation occurred. The user chose to configure Azure directly and confirmed completion.
- Read-only verification confirms `GOOGLE_CLIENT_ID` is present and `GOOGLE_CLIENT_SECRET` references Azure secret `google-client-secret`.
- Revision `dco-api-24739--0000046` is both latest and ready, provisioning `Succeeded`, running status `Running`. Image remains `dcoacr24739.azurecr.io/dco-api:v1.7.19`.
- `/v1/health` and `/v1/ready` return HTTP 200.
- `/v1/auth/social/google/start` now returns HTTP 200 with provider host `accounts.google.com`, the exact registered callback, `openid email profile` scopes, and PKCE `S256`. Flow and exchange-secret presence were checked without printing their values.
- The original missing-configuration blocker is cleared. Successful start does not verify client-secret validity during token exchange or completion of real-user sign-in. The user subsequently confirmed “Sign in with google is working” on 1 November 2026 after being asked to test the Play-installed app. This establishes user-reported success for the tested path; account type, build, and device details were not supplied. The broader acceptance matrix remains open.

## Acceptance evidence

Record build name/code, source commit, device/Android/browser versions, account scenario, timestamp with timezone, visible result, and sanitized stage outcome for each case:

| Case | Required outcome | Status |
| --- | --- | --- |
| Google start in current production | Provider configured, correct redirect | Passed: HTTP 200, correct redirect and PKCE |
| Google sign-in, account type unspecified | Successful sign-in | Passed: user confirmation, 1 November 2026 |
| New Google account | Explicit account choice then dashboard/setup | Pending |
| Existing linked Google account | Existing account/session, no duplicate | Pending |
| Existing email account | Explicit authentication/linking | Pending |
| Cancel browser / deny consent | Recoverable return, retry possible | Device check pending |
| Offline / server unavailable | Specific feedback, email UI retained | Device check pending |
| Expired flow / background-resume / killed app | Recoverable fresh sign-in | Device check pending |
| Apple and email/password regression | Existing behavior preserved | Real-provider check pending |

Local automated tests are evidence for client behavior only, not real-provider acceptance. Device inspection initially could not start ADB inside the sandbox; the agent did not exercise a Play-installed app directly. The user later reported successful Google sign-in. Phase 0 is documented with unresolved historical evidence; Phase 1 client hardening is implemented, production activation and the user-tested Google sign-in path are verified. The reported login blocker is resolved; broader device scenarios remain open. Client hardening is committed locally and has not been included in a new Play release.

## Local validation

- Authentication, analytics, and session regression run: **43 tests passed**. Existing UI tests printed missing bundled-font warnings but passed.
- Full Flutter analysis: 43 findings initially, including one new constructor-style info that was corrected; the other 42 findings are in unchanged files.
- Targeted analysis of changed Dart sources/tests: no issues found.
- Production configuration was inspected read-only; the user performed the deployment. OAuth JSON metadata was validated without displaying credentials.
