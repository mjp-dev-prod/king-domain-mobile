# Testing — what is guaranteed, and what is not

**Last full run: 2026-10-22 (after profile photos).** Backend 189/189, app 223/223, `flutter analyze` clean. (Before the work gaps: backend 108, app 83.) The backend 189 came from two runs: 174 in the full run, then `jobsRoutes.test.js` (15) re-run alone after its server failed to start twice within the 60 s wait on a slow Neon branch; it passed 15/15 and the wait is now 150 s.

Evidence tags: 🟢 documented by Paystack (source named) · 🔵 observed in this repo's tests ·
🟡 assumed, not yet seen against the real service · 🔴 not covered.

## Running them

| Repo | Command | Needs |
|---|---|---|
| `king-domain-backend` | `npm test` | `TEST_DATABASE_URL` in `.env.test` (git-ignored). Missing = the run **fails loudly**, it never skips. Refuses any URL containing `supabase`. |
| `king-domain-mobile` | `flutter test` | nothing |

The backend suite writes real rows, so it points at its own Neon branch, `test` (a child of `staging`,
project `floral-leaf-16911101`), never at the database used for phone testing. It only creates and
deletes rows of its own (users `testsuite-*@example.com`, jobs titled `TestSuite …`), and the tick
tests are handed a client that can only see those jobs. To refresh its schema after a schema change:
`neonctl branches reset test --parent`.

The HTTP tests start the real server, and the real `src/paystack.js` client, against a small fake
Paystack served locally (`PAYSTACK_BASE_URL` is read only so the suite can do this). No real money,
no real email (`BREVO_API_KEY` is forced empty).

## Backend ledger — `test/lifecycle.test.js`

| # | Guarantee | Status |
|---|---|---|
| — | Windows are 24 h to pay, 3 days to review; auto-release off unless `AUTO_RELEASE_ENABLED=true` exactly | 🔵 |
| — | Every payout reference we generate fits Paystack's format (lowercase `a-z0-9_-`, 16–50 chars) | 🟢 format rule (paystack.com/docs/transfers/single-transfers) · 🔵 ours satisfies it |
| A | Unpaid past 24 h: award cancelled, job reopened, selected and passed-over applicants back to pending, client and talent emailed, cancellation survives as an event | 🔵 |
| B | Paid on an *older* checkout: funded, not cancelled | 🔵 |
| C | Checkout opened 5 min ago: left alone | 🔵 |
| D | Inside the 24 h: untouched | 🔵 |
| E | A payment landing after cancellation is flagged `late_payment_after_void` and logged for manual refund | 🔵 |
| M | Paystack reports `ongoing` / `pending` / `processing` for a checkout: cancellation waits | 🔵 · statuses 🟢 (paystack.com/docs/payments/verify-payments) |
| M2 | Latest checkout still `ongoing` but an earlier one was paid: funded, not left waiting (found in review; fails under the old ordering) | 🔵 |
| N | …but only until 6 h past the deadline | 🔵 · the 6 h is **our** number, 🟡 (Paystack doesn't say how long `ongoing` lasts) |
| — | Paystack unreachable while checking: award is **not** cancelled | 🔵 |
| F | Silence for 3 days: one payout, budget only (no fee), both sides emailed, event says `auto_release`; a second tick pays nothing | 🔵 |
| G | Auto-release off: nothing is sent however overdue | 🔵 |
| H | Not yet due: untouched | 🔵 |
| I | Paystack refuses: stays `submitted`, retried hourly (not every tick), paid once it works | 🔵 |
| J | Client Approve and auto-release at the same instant: one transfer | 🔵 against the fake · 🟢 that Paystack refuses a reused transfer reference ("Reference already exists on a transfer", paystack.com/docs/api/errors/transfer) · 🟡 that it does so under true simultaneity |
| O | Transfer answered `otp`: not marked paid, nobody told they were paid | 🔵 · statuses 🟢 (paystack.com/docs/transfers/how-transfers-work) |
| P | Earlier payout failed conclusively: retry uses a **new** reference (`_2`) | 🔵 · 🟢 "conclusive status → new request" |
| Q | Earlier payout still live (`pending`): reused, never doubled | 🔵 |
| K | Award sets `payByAt = now + 24 h`; a *new* checkout after it is refused and nothing is sent to Paystack | 🔵 over real HTTP |
| L | Signed webhook funds the contract → start → submit sets `reviewDueAt = now + 3 days`; event trail `awarded, checkout_started, submitted` | 🔵 over real HTTP |
| — | Webhook with a bad signature is rejected | 🔵 |

**Do the tests bite?** A test that passes against broken code is worthless, so four deliberate
breakages of `contractLifecycle.js` were tried and each was caught by the named test: removing the
in-flight wait (M), ignoring the auto-release switch (G), treating `otp` as paid (O), removing the
6 h cap (N). Removing the conditional delete that commits a cancellation is *not* testable here (it is a race), so that guard has no test. The first attempt at the `otp` breakage was *not* caught — the code has two guards and
only one was broken; breaking both failed the test as it should.

## Backend ledger — stage 2 (delivery dates, extensions, change rounds)

Files: `deliveryDates`, `deliveries`, `extensions`, `changes`, `overdue`, `reminders`,
`mailer`, `stage2Routes` (all `test/*.test.js`). Rules from
[the stage 2 spec](../features/stage-2-delivery-and-changes.md). All 🔵 unless marked.

| Area | Guarantee |
|---|---|
| Delivery date | Funding fixes `deliverByAt = fundedAt + deliveryDays`; jobs without days get none. `POST /jobs` refuses missing, 0, 61, fractional or non-numeric days. |
| Versions | First delivery is version 1 with a 3-day review clock; empty deliveries refused; can't deliver from funded/submitted/approved/disputed; a resubmission is version 2 and version 1 is untouched; **two simultaneous deliveries record exactly one version**. |
| History | `GET /contract/history`: client and awarded talent only (403 for anyone else). |
| Extensions | Pending + counted + 48 h answer + client emailed; days 1..original duration; reason 10–1000 chars; one open at a time; **two simultaneous requests create one**; a declined request counts (no third); refused after delivery, on legacy jobs, and 3+ days past the date; grant adds the days, decline keeps the date; answering twice refused; a foreign extension id is not found; a grant that moves the date clears an overdue flag; delivering withdraws an open request. |
| 48 h auto-grant | Granted once, date moved, both told; not before 48 h; a client answer that lands before the tick stands; the tick runs it. |
| Change rounds | Round 1 sets `changesRequested` + 3-day clock and stops the review clock, talent gets the reason; reason required; only delivered work; **two simultaneous requests open one round**; after round 2 the same action escalates (`disputed`, no round 3, both told, reason recorded). |
| Resubmit clock | Missed → `disputed`; not due → untouched; a late resubmission that lands before the tick stands; **a sweep holding a stale read can't escalate a fresh round**; the tick runs it. |
| Money vs changes | A disputed contract is never auto-released; **a change request while a payout is in flight is refused and the contract ends approved with one transfer**; a failed payout releases the claim. |
| Overdue | Flagged once at date + 3 days, client emailed, event recorded; not before; paused by a pending extension; never on delivered work or legacy jobs; the tick runs it. |
| Reminders | 24 h / 6 h windows (pure function, incl. stale skip); sent once and **never twice, even from two simultaneous sweeps**; extension reminder to the client; delivery-date-passed to both, and a moved date gets fresh reminders; review reminders only while auto-release is on; a failed send is retried. |
| Emails | Every stage 2 template escapes user text and states the date; an unknown reminder kind throws. |

**Deliberate breakages (stage 2).** Each guard was removed and the named test failed, then passed
once restored:

- the extension-count compare-and-swap ("two requests at the same instant")
- the delivery status compare-and-swap ("two simultaneous deliveries")
- the release-claim guard in `requestChanges` ("payout is in flight")
- the clock guard on escalation ("stale read")
- the pending-extension pause on the overdue flag ("pauses it")
- insert-before-send in reminders ("never twice" and "same instant")

Two tests passed with their guards removed the first time, and were fixed. Both race tests had been
running their two calls one after the other, so a barrier now holds racing calls until both arrive.
The "late resubmission" test was found not to exercise the clock guard at all (the status condition
covers that case), so the "stale read" test was added for the case the clock guard actually protects.

## Backend ledger — work gaps (edit, close, apply, award)

Files: `jobs.test.js` (service level) and `jobsRoutes.test.js` (real HTTP, port 4613). Design:
[work-gaps spec](../features/work-gaps-applications-stepper-job-edit.md). All 🔵.

| Area | Guarantee |
|---|---|
| Input | `validateJobInput` trims and refuses each bad field with its own message (the same messages `POST /jobs` always gave). |
| Edit | Owner only; changes every field and bumps `revision`; refused with a code once anyone applied (`has_applicants`, including applications that pre-date `lastAppliedAt`), once awarded (`awarded`), once closed (`closed`); invalid input changes nothing. |
| Close | Owner only; final; marks every pending application `notSelected`; refused once awarded or closed. A closed job leaves other talents' feeds and stays for its owner and for talents who applied. |
| Apply | Stamps `lastAppliedAt`; accepts a missing `revision` (older app builds); a stale revision is `terms_changed` and creates nothing; closed is 409 `closed`, awarded is 400 `awarded`; a second application is 409 `already_applied`. Verified-in-category is still 403. |
| Award | Behaviour unchanged for an open job (characterised over HTTP before the refactor: selected, others not selected, contract `awaitingPayment`, fee frozen, 24 h pay window, `awarded` event); a closed job can't be awarded and no contract is made. |
| Races | Edit vs apply: exactly one wins and an application never lands on edited terms. Close vs apply: the job ends closed with no pending application, whichever runs first. Close vs award: exactly one wins, never both. Two edits at once both land and the revision counts both. Each uses `barrierPrisma` and runs 6 rounds, because the winner is decided by timing. |

**Deliberate breakages.** Each guard was removed and the named race test failed in round 0, then
passed once restored: the edit guard (`lastAppliedAt: null`, `applications: none`), the apply claim's
`closedAt: null`, and the award claim's `closedAt: null`. The close transaction's sweep of pending
applications is exercised by "close vs apply" but was not separately broken.

**Not guaranteed:** the races are modelled in one process against one Postgres, not load-tested
across several server instances. 🟡 The guards rely on Postgres re-checking a row's columns after
waiting for its row lock (READ COMMITTED), which is documented behaviour and is what the race tests
observe, but a different isolation setting would change it.

## App ledger — work gaps

`job_model_test` (closedAt, revision, `ApiException.code`), `work_applied_test` (Applied segment:
filter, order, status lines, empty, error, open), `lifecycle_stepper_test` (every status for both
viewers, tone, subtitles incl. no wording about where money is held, accessibility labels, pulse and
reduced motion), `edit_close_job_test` (manage menu and its locked state, close confirmation and
refusal, closed views, edit mode, closed tile and order), `job_detail_closed_test` (closed job, the
revision sent with an application, `terms_changed`, the feed). Existing `stage2_screens_test` gained
the stepper on both screens; four of its assertions were made precise (see below). 🔵 all.

Changes to existing tests, so nothing is silently weaker: the overdue tests now look for the notice
specifically (the stepper repeats the same words); two client extension tests scroll to the button
as a user would (the stepper made the screen taller).

## App ledger — `flutter test` (30, before the work gaps)

`payments_test` (10: payout account and funding screens), `password_reset_test` (5),
`environment_banner_test` (3), `payment_timers_test` (deadline text; the 24 h and 3-day screens,
including no automatic-payment promise while auto-release is off), `widget_test`. 🔵 all.

## What is NOT guaranteed

- 🔴 **A real payout.** The King Domain Paystack business is a Starter Business and cannot send
  transfers, and the test key cannot either. The success path (`success` / `pending` → paid) is
  verified only against the fake. First real proof comes after the Registered upgrade.
- 🟡 **Duplicate transfer reference under a true race.** Documented, never observed live
  (only the duplicate *charge* reference was seen live).
- 🟡 **Whether `abandoned` can later become `success`.** Paystack's docs don't say. Our protection
  is the all-checkouts verify, the `ongoing` wait and the orphan alarm, not a guarantee.
- 🔴 **Webhook delivery in production**, the live webhook URL, and transfer-OTP being off.
- 🔴 **Production.** Stage 1 is not deployed and the production database does not yet have its
  columns. Nothing here says it works on Render + Supabase.
- 🔴 **The scheduler under load / several instances.** One in-process tick on one instance. The
  conditional `updateMany`/`deleteMany` commit points make a second instance safe in principle
  (no test removes them and races them).
- 🔴 **No CI.** The suites run when someone runs them. Nothing blocks a push.
- 🟡 **Stage 2 in the apps.** The screens exist and are widget-tested against a fake provider; they
  have been walked on a phone against staging only by hand (2026-10-03), not by an automated test.
- 🔴 **Push notifications** don't exist. Stage 2 reminders are email plus in-app countdowns only.
- 🔴 **Admin handling of escalations.** `disputed` is a parking state; the only admin signal is an
  email to owner admins. Stage 3 builds the screen.
- 🟡 **The release claim's 10-minute takeover** after a crashed payout is reasoned, not tested
  against a real crash.
- 🔴 Stage 3 (disputes, rulings, cancel and refund) does not exist.

## Rule for new work

Every rule in a shareholder decision gets a test in the same commit as the code, named for the
rule. A behaviour that depends on Paystack's behaviour is tagged 🟢 with the page it came from, or
🟡 and listed above — never left implicit.
