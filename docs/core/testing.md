# Testing — what is guaranteed, and what is not

**Last run: 2026-10-01.** Backend 23/23, app 30/30.

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
- 🔴 Stages 2 and 3 (delivery dates, extensions, change rounds, disputes, refunds) do not exist.

## Rule for new work

Every rule in a shareholder decision gets a test in the same commit as the code, named for the
rule. A behaviour that depends on Paystack's behaviour is tagged 🟢 with the page it came from, or
🟡 and listed above — never left implicit.
