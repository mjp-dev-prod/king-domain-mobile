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
| **S2 Proving a skill** | Done | Done (authenticity queue, blind review page) | Done (skills hub, builder, results) | Same, plus a fake private bucket in tests |

All three slices are built. "Done" means built and tested as described below, not looked at on a phone.

## What was verified, and what was not

Verified by running it:
- Backend: the whole suite, 318 tests, all passing (run once the three slices were complete; one S2 file rule was tightened afterwards and its suite re-run: 16 route tests plus the account-deletion addition pass).
- Admin dashboard: `npm run build` (TypeScript) passes; the new files lint clean. 12 lint errors that were
  already in older pages (Decisions, Entries, Ledger, auth and others) are untouched.
- App: `flutter analyze` clean; the whole suite passes (323 tests); existing tests that render the profile tab were
  updated to stub the new server-backed providers (see "Things you might trip over").

**Not verified (cannot be from here):**
- Nothing was run on a phone or in a browser. The screens are tested with widget tests only; look at them.
- No real Slack, email, Paystack, identity provider or R2 was contacted. Slack, email and storage are faked in tests.
- Camera and video capture (`image_picker`) and the new `file_picker` are untested beyond compiling.
- A real upload from a phone to a real R2 bucket, and a reviewer playing a real R2 video in the dashboard, have not
  happened. The signed link, the headers and the checksum were checked against a local fake that behaves like S3 (and
  that check found a real bug, below), but only R2 itself can confirm it.

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

## S2: proving a skill (what was built)

**The journey.** Profile > Your skills > a skill > Start. The person builds a draft: 2 or 3 pieces of real work, each
with the brief, their role, when it was made, the finished work (or a live link), and for at least one piece working
files and drafts; then one 2 to 3 minute walkthrough video, and a declaration that it is their own work (plus a note if
they used AI). A checklist says exactly what is left. Sending asks for confirmation because it cannot be changed after.

Then, in order: (1) a **checker** confirms it is really theirs (walkthrough, working files, drafts, nothing found
published elsewhere); (2) **two reviewers** who hold the skill score it against the rubric, 1 to 4 per line, **blind to
each other and to who made it**; if they disagree a **third** decides; (3) the person gets the result with **reasons**:
the lines that fell short, what good looks like for each, and the reviewers' own words, never who they were. Every
attempt stays in a visible history.

**Rules from your answers (D5 to D9).**
- A pass is refused if any line is "below the standard"; a Not yet must say what to fix.
- Before sending again after a Not yet, the person must accept the terms (shown in the app).
- Sending the **same finished files again** is detected by file fingerprint (R2's ETag). The system only **flags** it;
  the checker decides. Penalise = 2 months out of that skill, then 3. Changed work is never a repeat.
- Stolen work or hidden AI = the checker can **ban** the person from that skill. Stop = send back with a reason, no penalty.
- A verified result also creates the old "verified proof item" in that skill's category, so the existing apply gate
  keeps working untouched.
- Files go from the phone straight to a **private R2 bucket** through a presigned link; the server never carries the video.
- Account deletion deletes submissions, restrictions and the files in the bucket.

**Admin dashboard.** New pages: Authenticity (checker) and Skill reviews (reviewer), both in the inbox with targets,
median / 90th percentile and overdue counts, and in the Slack and email overdue alerts. Every action is audited.

**A bug the fake bucket caught.** The AWS SDK, by default, bakes the checksum of an *empty* body into a presigned upload
link, so every real upload from a phone would have failed. Fixed (`requestChecksumCalculation: "WHEN_REQUIRED"`) and
the link is tested to carry no checksum.

## S2: setup you owe

- Create a **private** Cloudflare R2 bucket and set `R2_PRIVATE_BUCKET` on Render (the existing `R2_ACCOUNT_ID`,
  `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` are reused; the key must be able to write to the new bucket). Without it,
  uploads answer "not available" and the hub says so.
- Push the schema to staging (S2 adds five tables; additive).
- Reviewers: you need **two different people** holding the skill (Team page > Reviewer + skills), or nothing can ever
  be decided. Owners can review every skill, but one person cannot review the same submission twice, so with only you
  as owner a submission would wait forever for a second reviewer.
- A Checker for the authenticity step.

## S2: things I decided or could not decide (please read)

1. **Rubrics are drafts.** All five (video, design, social, writing, web) are marked draft in the API, the app and the
   reviewer page. Only video came from the research; the rest I wrote without a practitioner. Each needs a working
   session with someone who does the work (PRD open item).
2. **Reviewers do not see the person's name or email**, only the work. That is my choice to reduce bias; the checker
   does see who it is. Say if you want reviewers to see the name.
3. **The ban is per skill**, not account-wide. Whether stolen work should end the whole account is a policy call I left open.
4. **The reply promise ("within 4 days")** is a constant in the app, from the queue targets (24 h check + 72 h review).
   Those targets are provisional until real handling times exist; change the wording when you set them.
5. **Repeat detection only catches identical files.** A re-exported or re-encoded video has a new fingerprint and will
   not be flagged; the checker's judgement covers that.
6. **The old apply gate is per category, not per skill.** Verifying "Graphic design" unlocks all "Design & creative"
   jobs, because that is how the old gate works. Whether the gate should become per skill is a product decision.
7. **The old single-file proof upload still exists** in the app and the proof-review page, so there are now two ways to
   get verified. I did not remove it (it is how staging works today). Recommend retiring it once you accept S2.
8. **No push notification on a result yet**, only email. The push system exists for contracts; wiring skill results
   into it is a small follow-up.
9. **Data cost.** Walkthrough videos are capped at 300 MB and finished files at 500 MB, and the app does not compress.
   On mobile data that is expensive for the person. The app should warn about size and ideally compress; not done.
10. **Any reviewer holding the skill can pick up any submission** (no assignment, no conflict-of-interest check). The
    blindness is the only protection against reviewing a friend's work.
11. **New app dependency `file_picker` 11.0.3** (for PDFs, documents and project files, which the gallery picker
    cannot choose). It is a native plugin and I could not build the Android app here. If the next phone build fails,
    suspect this first; if so, the writing and web skills lose document upload until it is sorted.

## Not in S2 (cut or left, so nothing is silently missing)

- Reviewer **rubric editing** from the dashboard (rubrics live in `src/rubrics.js`).
- A talent **viewing their own uploaded files** after sending (they see names and sizes, not a preview).
- **Withdrawing** a submission that is in review.
- Reviewer **payment or credit** tracking (a PRD admin-tools item; nothing about it was decided).
