# Authentication and First-Run Onboarding

**Status:** Implemented in the working tree; production configuration and real-device acceptance pending.
**Updated:** 10 October 2026.
**Scope:** [Production scope](../production-scope.md).
**Execution plan:** [Implementation specification and task list](../../docs/onboarding-auth-implementation.md).

Existing email/password login and sessions remain the baseline. Verification token endpoints and an email adapter exist, but the emailed URL does not complete a browser verification flow. The new browser-based Google/Apple and code flows are implemented; do not describe them as shipped until live configuration and device acceptance pass.

## First launch and language

- Preselect a supported device language, otherwise English. The introduction opens directly on the illustrated screens; language is switched before login from the app-bar menu (and later in Settings), not from a dedicated first screen.
- Apply the selected language immediately to onboarding, authentication, validation, and recovery copy. Remember it locally before a session exists.
- The introduction is three swipeable illustrated screens: digital garage and documents; maintenance history and reminders; fuel, expenses, and stats. Each screen shows one illustration.
- Each screen has a short headline and caption, uses existing light/dark tokens, and supports accessible text scaling and illustration semantics. Motion is scroll-linked parallax with a staggered entrance and a Skip / page-indicator / Continue row; reduced-motion settings disable animation. The illustration sits on a soft stage in dark mode.
- The introduction is skippable; Skip and Get started both land on the Welcome screen, which offers Sign in and account creation. Completing, skipping, or choosing Sign in marks introduction handled for this installation; logout does not reset it. No repeated tour on upgrades. Reinstallation behavior must account for OS backup restoration.
- After login, use the existing user's saved language preference when available; otherwise retain the pre-login choice. New users inherit the selected language. Language switching remains available before login and in Settings.
- Fleet drivers use Sign in and existing role-based routing. There is no public Owner/Driver registration selector.

## Account creation and first vehicle

- Email signup requires email, password, and confirmation; display name is optional. Keep current password minimum of eight characters until a separately approved policy replaces it.
- Phone, address, and driving-license information are not signup prerequisites.
- Establish an account/session, then show the six-digit verification screen with **Do this later**.
- Verify or skip, then offer Add your first vehicle with **Do this later**. Existing users retain their normal destination; invitations and fleet routing must not be lost to first-vehicle setup.
- Personal garage functionality remains available to unverified email accounts, including offline use after session establishment.

## Email verification and correction

- Use a six-digit email code. Resend and code submission require server-side abuse controls.
- Proposed engineering defaults: ten-minute expiry, five failed attempts per challenge, sixty-second resend cooldown. These are implementation defaults, not additional user interview decisions.
- Resending invalidates the previous challenge. Store no plaintext codes. Verification and password recovery are separate purposes.
- Include expired, incorrect, exhausted, delivery-failure, offline, and resend-wait states. Preserve leading zeroes.
- Allow correction of an unverified email following recent authentication. Invalidate challenges for the old address and verify the new address. Never merge with an existing account automatically.
- A collision directs the user to authenticate or recover their existing account. Do not discard the current account's local records or queued writes.
- Verification refreshes the user's state without requiring logout. Do not mark an email verified from a client claim alone.

## Collaboration policy

- Backend enforcement is authoritative, including direct requests and applicable sync paths.
- Unverified users cannot create new shares or accept invitations, including code/QR acceptance.
- Existing shares remain usable. Do not revoke existing grants when enabling the new policy.
- Keep personal features accessible. Allow revocation/declining for safety; a verification gate must not prevent reducing access.
- Existing unverified users receive a dismissible prompt after login and a mandatory verification step when attempting a gated action. Resume the intended action after success.
- Email-less fleet drivers retain their provisioned role behavior; do not apply owner email onboarding to them indiscriminately.

## Google and Apple

- Offer Google and Apple on both Android and iOS, using the existing backend to issue DCO sessions.
- Validate provider authentication on the server. Key identities by provider and stable subject, never by email alone.
- A provider-confirmed email, validated by the backend, satisfies verification. If absent, collect and verify an address before collaboration; personal access remains available.
- Before creating an account for an unknown provider identity, offer **Create a new account** and **I already have an account**.
- Linking to an existing account requires authenticating that account. A matching email alone never authorizes linking; email collisions cannot create duplicate email accounts.
- Include Connect Google / Apple in account settings with recent authentication. Linking must preserve vehicles, shares, plan, and history.
- Support Apple hidden-email identities without assuming their relay address matches an existing address. Cancellation returns to the previous screen without creating an account.
- Public social signup creates owner accounts only, with no administrative or fleet-role escalation.

## Password recovery and sessions

- Recovery: enter email → six-digit recovery code → enter and confirm new password → return to sign-in.
- Use a generic request response regardless of account existence or password availability. Give general provider-login guidance without exposing whether a submitted address is social-only.
- Recovery applies only to accounts that already have a password; it cannot create a first password for social-only users.
- Adding a first password is a separate Settings action after recent provider authentication and verified email control.
- Successful reset invalidates all existing sessions. Implementation must handle both refresh tokens and already-issued access tokens.
- Bind reset authorization to the account and recovery purpose; consume it atomically with password replacement.
- Existing secure token storage, refresh rotation, account-scoped offline queues, and provisioned driver password flows remain in force.

## Acceptance and scope boundaries

- Both platforms pass real Google/Apple sign-in, linking, cancellation, and relaunch tests.
- Both languages cover the entire new flow; existing saved preferences and theme choices survive account transitions.
- Expired/replayed/wrong-purpose codes and unverified collaboration attempts are rejected by the API.
- Existing unverified users retain existing shares; concurrent identity linking and email correction cannot steal or merge accounts.
- Existing owner, driver, fleet, admin, and workshop authentication regressions pass.
- No authentication provider migration, account merging, billing, passkeys, or MFA in this release.
- HTTP shapes are implemented in OpenAPI alongside backend changes; the implementation plan contains proposals, not currently callable endpoints.
