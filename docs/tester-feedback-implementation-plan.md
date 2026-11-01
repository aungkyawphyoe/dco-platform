# Tester feedback implementation plan

Date: 1 November 2026
Status: Approved. Phase 0 investigation, Phase 1 client implementation, Phase 2 sign-out confirmation, and Phase 3 post-login tour are implemented; Phase 4 listing copy is drafted and awaiting review. See [baseline and acceptance record](tester-feedback-auth-baseline.md). The production Google login blocker is resolved and user-tested sign-in succeeds. Client hardening is committed locally; release of those changes and the broader acceptance matrix remain open.

## Purpose and evidence

Address the four main findings in the seven-page tester report at `/Users/akp/Downloads/autox_feedback.pdf`: Google login, logout confirmation, interactive onboarding, and Play Store description. Treat the report's additional recommendations as follow-up work, not automatic scope expansion.

Source inspection confirms immediate logout and an existing three-page skippable introduction. Google login is implemented but the reported failure has not been reproduced. The published description has not been reviewed. The report supplies no build number, device matrix, error details, or reproduction steps and contradicts its own “no bugs” summary.

Use `product/production-scope.md`, the auth FRD, `mobile/AGENTS.md`, and `docs/auth-provider-setup.md` as implementation constraints. Update relevant product specifications when new behavior is implemented. Preserve shared Personal/Driver screens, account isolation, offline records, and English/Burmese support.

## Phase 0 — Establish the tested baseline

- Record the tested Play version name/code, release commit, Android/device/browser versions, and account type. Compare with the current checkout (`pubspec.yaml` currently declares `1.0.0+2`; this does not prove the uploaded build).
- Capture the exact Google failure: starting screen, new/existing account, visible error, whether the browser opened, whether Google consent completed, whether control returned to AutoX, and approximate timestamp.
- Obtain the current Play short/full descriptions and screenshots for the listing work.
- Record a minimal reproduction checklist and sanitized evidence. If tester details are unavailable, reproduce with a Play-installed build and explicitly record that distinction.

Deliverable: baseline and reproducible cases. Logout and tutorial design can proceed while login evidence is collected.

## Phase 1 — Diagnose and resolve Google login

Priority: highest. Do not select a fix before locating the failing stage.

### Work

1. Trace the implemented flow: `/auth/social/google/start` → system browser → backend HTTPS callback → `dco-auth://callback` → `/auth/social/complete` → accepted session.
2. Inspect deployed provider configuration without exposing secrets: configuration presence, exact public callback URL, consent/audience settings, and backend callback/exchange errors. Repository setup notes are leads, not proof of deployed state.
3. Reproduce the Android browser return and account-choice/linking paths. This repository uses a backend web OAuth client; do not assume a native Google SDK/signing-fingerprint issue.
4. Fix the demonstrated failure in mobile, backend, or provider configuration as appropriate. Record any external configuration steps separately from code changes.
5. Improve localized feedback for actionable failure categories: connectivity, provider unavailable, expired/invalid flow, and recoverable server failure. Cancellation should return quietly to the login screen. Retrying must create a fresh flow.
6. Add narrowly scoped diagnostic events for stage, outcome, elapsed time, and a safe correlation identifier where supported. Never log tokens, flow secrets, authorization URLs/codes, or raw email addresses. Respect the existing analytics setting.
7. Preserve email/password access and existing identity-linking rules. Do not automatically link accounts solely because email addresses match.

### Primary touchpoints

- `mobile/lib/features/auth/data/repositories/account_security_repository_impl.dart`
- `mobile/lib/features/auth/presentation/widgets/social_buttons.dart`
- `mobile/lib/features/auth/presentation/widgets/auth_feedback.dart`
- `mobile/lib/features/auth/presentation/session_controller.dart`
- `mobile/android/app/src/main/AndroidManifest.xml` if reproduction implicates app return
- Backend social-auth handlers and provider configuration, located during diagnosis
- `docs/auth-provider-setup.md` and English/Burmese localization sources

### Acceptance

- A Play-installed build completes Google login for a new account and an existing linked account.
- Existing email-account linking does not create duplicate accounts or bypass authentication.
- Cancel, denied consent, network failure, expired flow, background/resume, and app termination/retry have defined recoverable outcomes.
- Email/password login still works. Shared social-auth changes receive Apple-flow regression coverage; real-provider acceptance is recorded separately from mocked tests.
- Automated tests cover the identified failure and error mapping; real-device acceptance proves the external provider flow.

## Phase 2 — Confirm intentional logout

### Work

- Add a localized confirmation dialog to the Settings sign-out action: “Sign out?” with Cancel and Sign out.
- Cancel, system Back, and dismiss leave the session unchanged. Confirm calls the existing sign-out operation once; prevent repeated submission while it runs.
- Preserve existing token cleanup, account transition, local records, queued writes, and appearance preference behavior.
- Explain that pending changes remain on this device if the dialog includes sync-related copy; do not promise cloud backup or force a network sync before logout.
- Apply confirmation to user-requested sign-out only. Session expiry and required security transitions must remain automatic.

Primary touchpoints: Settings screen, localized strings, and the existing session controller only if needed for submission state.

Acceptance: dialog works offline; cancel does nothing; confirm signs out once; subsequent login to the same account retains its local pending work; another account cannot see or upload it. Add focused widget coverage for confirmation and reuse account-isolation regression tests.

## Phase 3 — Add a short, contextual app tour

### Proposed UX

Keep the existing pre-login introduction. Add an optional guided tour after authentication, once the dashboard has loaded and verification/first-vehicle prompts are resolved or skipped.

- Offer “Show me around” and “Not now” rather than immediately covering the screen.
- Explain four areas: active vehicle/garage selector, maintenance, expenses, and settings/sync.
- Use anchored hints on real UI controls with Next, Back, and Skip. Navigation between steps must preserve existing tab stacks.
- With no personal vehicle, explain Add vehicle first without requiring creation or creating sample records. For Drivers with no assignment, explain assignment status; never offer vehicle creation.
- Adapt wording and targets to actual Personal/Driver permissions. Skip unavailable targets safely.
- Persist dismissed/completed state locally per account and tour version. Do not restart on every launch, sign-out, or transient loading state. Interrupted tours may be replayed explicitly.
- Provide Settings → Help → Replay tour. A manual replay starts from a stable dashboard state.
- Handle small screens, large text, screen readers, reduced motion, English/Burmese, and both themes. Back exits or moves back predictably; overlays must never trap users.

### Implementation shape

Introduce a small onboarding/help feature with a tour-state repository backed by account-scoped local AppMeta, a Riverpod controller, and reusable overlay presentation. Use shared target identifiers/contracts instead of importing other features' presentation or data layers. No new backend or sync entity is required.

Primary integration points: app shell, dashboard, Settings, router, and localization. Update the auth/app-shell behavior documents to distinguish the introduction from the post-login tour.

### Acceptance

First eligible login offers the tour once; skip/completion survives restart; account switching does not share state; manual replay works. Empty garages, Driver assignments, delayed data, route changes, and interrupted tours do not crash or block normal use. Tests cover state transitions and representative target/navigation behavior; device checks cover accessibility and layout.

## Phase 4 — Review and improve the Play listing

**Status (1 November 2026):** English and Burmese copy drafted in
[`marketing/play-store/listing/`](../marketing/play-store/listing/README.md) with
a limit validator and a claim-to-source map. Nothing is published. Outstanding:
a diff against the live listing text, native Burmese review, and screenshot
regeneration from the release being shipped.

- Review the actual published text against features present in the tested release.
- Draft short and full descriptions using clear, natural phrases around vehicle maintenance, service reminders, expense tracking, and fuel logs.
- Explain offline use and synchronization accurately: authentication needs connectivity, and Notes remain local-only.
- Ensure screenshots and claims match the release, including any plan limits. Avoid unsupported security claims such as an encrypted document vault unless verified.
- Prepare English copy and Burmese copy if that listing locale is maintained. Check current Play metadata requirements at implementation time.
- Store reviewable copy under `marketing/play-store/`; publishing is a separate step after copy review.

Acceptance: claims checked against the release, current store limits validated, spelling/localization reviewed, and final copy ready for Play Console. Do not claim keyword ranking improvements without evidence.

## Phase 5 — Focused follow-up work

Include a small offline Help screen with the tour replay and FAQs for login, vehicle setup, maintenance, expenses, sync, and local-only Notes. Keep answers short and consistent with shipped behavior.

An in-app feedback entry is conditional on an agreed support destination. Prefer opening a user-reviewable email draft with optional app version/platform information, plus a copy fallback. Do not invent a support address or send diagnostics automatically. A ticket backend and attachment upload are separate scope.

Use Phase 1 diagnostics and existing sync status to establish evidence before selecting a broader crash/performance monitoring service. Review specific UI problems found during acceptance; a general redesign and a recurring update schedule are not part of this release.

## Validation and release sequence

1. Make independently reviewable changes for auth, logout, tour/help, and listing copy. Update specifications alongside behavioral changes.
2. Run Flutter analysis and affected tests, then the mobile regression suite before release. Test backend auth changes if present.
3. On real devices, cover the supported Android range, including Android 14–16, browser return, gesture/three-button navigation, English/Burmese, light/dark, and large text.
4. Exercise offline record creation → app restart → reconnect → synchronization; verify no lost or duplicated records. Repeat logout/account-switch checks with pending writes in Personal and Driver scopes.
5. Build a release bundle with production configuration and a version code above the latest Play upload. Record commit, version, test results, and known limitations.
6. Distribute through the existing testing track when release is authorized. Ask testers to repeat explicit login, logout, tour, and reconnect scenarios with version/device details.

Release exit criteria: Google login reproduced and resolved with real-provider evidence; confirmation and tour acceptance passed; offline/account-isolation regressions passed; listing copy accurate. If a provider or Play configuration dependency remains unresolved, report that gate explicitly rather than treating mocked test success as completion.

## Decisions and dependencies

- Required for login diagnosis: failing-build context and access to sanitized backend/provider evidence.
- Required for listing verification: current published copy or Play Console listing access.
- Proposed tour policy: offer once to existing and new accounts lacking this tour version, with dismissal persisted and replay available.
- Required only for feedback delivery: approved support email or destination.
- Broad crash monitoring, new support infrastructure, and general visual redesign remain separate follow-ups.
