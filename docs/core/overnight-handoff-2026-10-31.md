# Overnight build: handoff (2026-10-31)

Written for Victor, to read first thing. Everything below is on **local branches, committed, not pushed, not on
staging, not on production**. Nothing here has been run on a phone.

## What you asked for

Three slices from the PRD (S0, S1, S2), built unattended, inline (no subagents).

## Where each branch is

| Repo | Branch | Based on |
|---|---|---|
| king-domain-mobile | `s0-foundations` | `prd` (the PRD, research and plan commit) |
| king-domain-backend | `s0-foundations` | `profile-photos` |
| king-domain-admin | `s0-foundations` | `master` |

## Status by slice

| Slice | Backend | Admin dashboard | App | Verified how |
|---|---|---|---|---|
| **S0 Foundations** | Done | Done | Done | Backend tests, admin build/lint, app tests (below) |
| **S1 Accounts and identity** | Done | Done (checker queue) | Done | Same |
| **S2 Proving a skill** | See "S2" below | See below | See below | See below |

(This table is updated at the end of the night; if S2 rows still say "See below" something stopped early.)

## What was verified, and what was not

Verified by running it:
- Backend: the whole suite (265 tests) passed except one that depended on code I had just changed; after the
  schema was pushed to the **test** database that test passed, and the new suites passed too (counts at the end).
- Admin dashboard: `npm run build` (TypeScript) passes; the new files lint clean. 12 lint errors that were
  already in older pages (Decisions, Entries, Ledger, auth and others) are untouched.
- App: `flutter analyze` clean; new tests pass; existing tests that render the profile tab were updated to stub the
  two new server-backed providers (see "Things you might trip over").

**Not verified (cannot be from here):**
- Nothing was run on a phone or in a browser. The screens are tested with widget tests only; look at them.
- No real Slack, email, Paystack, identity provider or R2 was contacted. Slack, email and storage are faked in tests.
- Camera and video capture (`image_picker`) are untested beyond compiling.

## Decisions I made without you (all easy to change)

1. **Minimum age 16** to use the app (`IDENTITY_MIN_AGE`, default 16). The PRD left age open; 16 matches university
   admission. Under 18 needs the guardian step.
2. **`IDENTITY_REQUIRED` is off by default.** The gate on apply / post / award exists and is tested, but staging keeps
   working as it is until you set `IDENTITY_REQUIRED=true`.
3. Proof review (the existing admin screen) now **needs the Reviewer role**. Nobody has it yet except owners, so
   after this reaches staging, give Balogun and Debbie roles on the Team page or they will see "no access".
4. The guardian's confirmation page is served by the backend itself (`/guardian/confirm`), so the emailed link always
   lands on a real page. It needs `PUBLIC_API_URL` set to the backend's public address.
5. Identity documents and videos go to a new **private** storage bucket `identity-docs` (created on first use).
6. Payout accounts: once someone is verified, the bank account name must match their verified name; unverified people
   are not blocked (nothing to compare with yet).
7. Account deletion now also deletes identity checks, guardian records, identity files and the region / education
   / identity fields.

## Setup you owe before staging can use this

- Slack: an incoming webhook for a new `#alerts` channel → Render env `OPS_SLACK_WEBHOOK_URL`. Also `ADMIN_DASHBOARD_URL`
  and `PUBLIC_API_URL`. Never paste the webhook into chat or git.
- Push the schema to **staging** (additive; I only pushed to the test branch): `DIRECT_URL=<staging direct url> npm run db:push`.
- Give people roles on the Team page (Reviewer + skills, Checker, Shareholder).

## Things you might trip over

- Tests that render the profile tab (`shell_tabs`, `sign_out`, `photo_usage`, `push_ui`, `delete_account`) needed the
  new providers stubbed and a scroll to reach Sign out, because the profile tab has two more rows now. That is a test
  change, but it also means the account rows sit lower on a short phone screen.
- The first backend `db:push` against the Neon test branch failed once with "can't reach database" (the branch had
  scaled to zero) and worked on retry. Same may happen on staging.
- Source files in these repos use Windows line endings; scripted edits must handle `\r\n`.

(Sections for S2 and the final test counts are added below as they are finished.)
