# Push notifications

**Status (2026-10-24): built and tested on local branches; nothing deployed and no push has reached a real phone
yet.** Firebase projects exist (staging `king-domain-staging`, production `king-domain-8878e`, made by Victor). Android
only. Research behind the choices: Firebase docs on FCM Flutter setup, HTTP v1 sending, token management and error
codes (read 2026-10-24).

## What Victor sets up before it works (nothing here is in git)

1. **Render, per environment** (staging backend with the staging project's key, production with production's):
   `FCM_SERVICE_ACCOUNT_JSON` = the service-account key JSON (Firebase console, Project settings, Service
   accounts, Generate new private key; paste the whole JSON as the value). Also `SUPPORT_EMAIL=kingdomainapp@gmail.com`
   (used in the account-deleted email). Without the key, the backend starts, stores tokens, and sends nothing.
2. **Codemagic**, encrypted variables: `GOOGLE_SERVICES_STAGING_B64` (group `king_domain_staging`) and
   `GOOGLE_SERVICES_PRODUCTION_B64` (group `king_domain_backend`): each the project's `google-services.json`,
   base64-encoded (PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("<file>")) | Set-Clipboard`).
   Both workflows stop early, with the reason, if one is missing or is for the wrong app.
3. Schema push (additive): `DeviceToken` and `ContractEvent.pushedAt`, on each database, before the backend deploys.
4. Local builds: the two JSON files sit in `android/app/src/staging/` and `android/app/src/production/`
   (git-ignored; already copied on Victor's machine).

## First test on a phone (staging)

Install the KD Staging build, sign in, tap Turn on. Then have a second account pick the first for a job: the
"You were picked" push should arrive within about 5 seconds, also with the app closed. Check the staging backend log
for `[push] user=... devices=1 sent=1` (and `removed`/`failed` counts if not).

## What a person gets

A push is a short, plain line about a job, sent when something needs them or something they waited for happened.
No amounts, no marketing, no "come back" nudges.

| When | To | Title | Line |
|---|---|---|---|
| Client picks a talent | Talent | You were picked | The client picked you for "X". Work starts when they pay. |
| Client's payment confirmed | Talent | Payment received | "X" is paid for. You can start work now. |
| Talent delivers / resubmits | Client | Work delivered / updated | "X" was delivered. Review it within 3 days. |
| Client asks for changes | Talent | Changes requested | The client asked for changes to "X". |
| Talent asks for more time | Client | More time requested | The talent asked for more time on "X". Please answer within 48 hours. |
| Client answers | Talent | More time granted / Extension declined | |
| Client does not answer in time | Both | Extension granted automatically | |
| Payment released | Talent | You've been paid | Your payout for "X" has been sent. |
| Payment released by the 3-day rule | Client | Payment released | The review window for "X" passed, so payment was released. |
| Unpaid award cancelled (24 h) | Both | Award cancelled | |
| Delivery date passed, nothing delivered | Both | Delivery is late | |
| Sent to our team (disputes) | Both | Sent to our team | |
| Reminders (24 h / 6 h before a deadline, and at it) | The person whose silence triggers it | Same clocks as the reminder emails | |

Tapping a push opens the app (to the job when it is for a job). With the app open, the same line shows as an
in-app toast instead. A person who says no to notifications loses nothing else; the Profile offers it again.

## How it is built

**Outbox, not wiring.** Every meaningful change already writes a `ContractEvent`, after its transaction commits.
A small dispatcher reads events that have no `pushedAt`, claims each with one conditional update (so two
dispatchers can't both send), and sends the push. It never touches the money code, a rolled-back transaction can't
produce a push, and a crash loses at most the push in flight. Only events from the last 15 minutes are considered,
so switching it on never replays history. The one new event is `funded` (written by `confirmFunding`, also a
better audit trail). Reminders have their own path (`ContractReminder`), where the push is sent once after the
reminder is recorded.

**Tokens.** `DeviceToken(userId, token unique, lastSeenAt)`. The app registers its token at every start and when
FCM rotates it (`PUT /users/me/device`); a token seen on another account moves to it. Logout removes it
(`DELETE /users/me/device`) and deletes it from FCM, so the next person on a shared phone never receives the last
person's pushes. FCM answers `UNREGISTERED` (or "not a valid registration token") for dead tokens: those rows are
deleted at once; tokens unseen for 60 days are pruned. Account deletion deletes every token.

**Sending.** FCM HTTP v1 (`POST /v1/projects/<id>/messages:send`) with an access token from the service account in
`FCM_SERVICE_ACCOUNT_JSON` (Google's `google-auth-library`). Priority high, channel `kd_updates` ("Job updates").
Throttled or unavailable (429, 5xx): retried twice with backoff, then logged and dropped. A push is best-effort: its
failure never fails a request, and the email still goes out. With no key configured, nothing is sent and nothing
polls the database.

**Logging** names what decided the outcome: per send, the user, the last 8 characters of each token, FCM's answer,
and whether the token was removed; per dispatch, how many events were claimed and sent.

## App

`firebase_core` + `firebase_messaging`; a `PushGateway` seam (fake in tests, like the photo picker). Per flavor
`google-services.json` (staging project for the `.staging` app, production for the real one). A one-time
explanation sheet after sign-in and email verification ("Get told when you are picked, paid or asked for
something") with Turn on / Not now; Turn on triggers Android's permission prompt. Profile has a Notifications row to
turn it on later (opens the phone's settings if it was refused).

## Keeping secrets out

The mobile repo is **public** on GitHub. `google-services.json` is not committed: Codemagic writes it at build time
from encrypted variables (`GOOGLE_SERVICES_PRODUCTION_B64`, `GOOGLE_SERVICES_STAGING_B64`) and the local copies are
git-ignored. The service-account key lives only in Render's environment, per environment (the staging backend gets
the staging project's key).

## Verified, and what is not

Backend (real database, fake FCM over HTTP): 30 tests in `test/push.test.js`: token rules, the exact v1 request,
dead-token removal, retries, a 401 refresh, the exactly-once claim (a mutation that removed it failed its test),
every message and its recipient, the funded event, reminders. The existing funding, reminder, lifecycle and
account-deletion tests still pass (the event trail gained `funded`). App: 11 service tests, 11 UI tests, the manifest
guards. **The Android build was compiled** (resources for both flavors and Kotlin) with the Google-services plugin
4.5.0.

**Not verified, because it needs a phone and the keys:** a real FCM send; Google's access-token exchange
(`google-auth-library`, used as documented but only stubbed in tests); Android's permission prompt; the look of
the notification icon (a simple KD shape, single colour); tapping a push from a closed app.

## Follow-ups

- **Installation IDs.** Firebase marks `getToken`/`onTokenRefresh`/`deleteToken` deprecated in favour of Installation
  IDs (`register`/`onRegistered`, a manifest opt-in, and the `fid` field when sending). The token path still works and
  FCM's `token` field accepts both during the migration, so this is a planned swap, not a blocker. The gateway is the
  only app code that changes; on the server, one field name in `messageBody`.
- Per-type switches, iOS, and a quiet-hours rule are not built. The phone's own channel settings cover muting.

## Not in this work

iOS, topics or broadcasts, pushes for admin events, rich images.
