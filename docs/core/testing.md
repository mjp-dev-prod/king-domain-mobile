# Testing — what is guaranteed, and what is not

**Last run: 2026-10-01.** Backend 93/93, app 30/30.

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

## App ledger — `flutter test` (30)

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
- 🔴 **Stage 2 in the apps.** The backend exists; no app screen calls it yet. The current app's
  post-job form fails against this backend (it doesn't send `deliveryDays`).
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
