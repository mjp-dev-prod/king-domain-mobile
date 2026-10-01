# Payments — how money moves

**Status (2026-10-01):** built and tested on staging; not live. Production's database has the
payment columns, but NOT the timer columns (`payByAt`, `reviewDueAt`, …) or the `contract_events`
table: push the schema (additive) before this code ships. Going live is blocked on the King Domain Paystack business being activated and
upgraded to *Registered Business* (needs MJP Productions Limited's CAC certificate) — a
Starter Business cannot make the payouts in step 4.

Provider: **Paystack**. Platform fee: **10%**, charged to the client on top of the job budget
(shareholder decision "Set King Domain's platform fee on job payments", 2026-09-18). The talent
always receives the full posted budget.

## The flow

| # | Who | What happens | Contract status after |
|---|---|---|---|
| 0 | Talent | Adds a payout bank account. **Required before applying** (decision 2026-10-01) | — |
| 1 | Client | Awards one applicant. Fee is computed and frozen onto the contract. **24 hours to pay, or the award cancels** | `awaitingPayment` |
| 2 | Client | Pays budget + fee on Paystack's hosted checkout | `funded` once confirmed |
| 3 | Talent | Starts work, submits deliverable | `inProgress` → `submitted` |
| 4 | Client | Approves, **or does nothing for 3 days and payment releases automatically** (once switched on). Backend transfers the **budget only** to the talent's bank | `approved` |

There is no escrow product: between steps 2 and 4 the money sits in King Domain's own Paystack
balance. The fee simply never leaves it.

## The clocks (src/contractLifecycle.js)

Agreed in shareholder decision "How a job gets paid" (ledger `736051b0-…`, 2026-10-01). Every
clock is a **timestamp on the contract** (`payByAt`, `reviewDueAt`), never an in-memory timer, so a
restart or a sleeping server only delays a step. A tick runs every 5 minutes inside the server
(kept awake by the external health ping; `CONTRACT_SCHEDULER=off` disables it) and catches up on
anything overdue.

**24-hour payment window.** Award sets `payByAt = now + 24h`. Past it, the tick cancels the
award: the contract is deleted, the awarded and passed-over applicants return to `pending`, the job
reopens, and client and talent are emailed. Three guards stop a real payment being lost:
- every checkout the contract ever opened (`contract_events` type `checkout_started`) is verified
  with Paystack first — a paid one funds the contract instead of cancelling it;
- a checkout opened in the last 30 minutes is left alone (a bank transfer may be settling), and so
  is one Paystack still reports as `ongoing` / `pending` / `processing` — for at most 6 hours past
  the deadline (our own cap; Paystack doesn't say how long `ongoing` lasts);
- a *new* checkout after the deadline is refused.

A payment that still arrives after cancellation (matched by the contract id inside the reference)
logs `ORPHAN PAYMENT needs manual refund` and writes a `late_payment_after_void` event.

**3-day review window.** Submit sets `reviewDueAt = now + 3 days` and emails the client. When it
lapses the tick runs the **same** `releasePayment` the Approve button uses, so there is one payout
path; concurrent releases are safe because Paystack refuses a reused transfer reference (documented:
"Reference already exists on a transfer"; not yet observed live for transfers). A
refused transfer is retried hourly, up to 24 times, then left for an admin (`AUTO-RELEASE FAILED` /
`NEEDS ADMIN` in the logs).

**Auto-release is OFF by default** (`AUTO_RELEASE_ENABLED=true` turns it on). Paying the talent
when the client says nothing is only fair once the client can object, and change requests and
disputes (stages 2 and 3 of the decision) are not built yet. While it is off, `reviewDueAt` is not
sent to the apps and the review email makes no automatic-payment promise.

`contract_events` is an append-only trail per job (awarded, checkout_started, submitted, released,
award_voided, …) that survives the contract row and is the evidence base for disputes.

## Step 0 — payout account

`POST /users/me/bank-account/resolve` looks the account up with Paystack and returns the holder's
name **without saving**; the app shows it and the talent confirms it's theirs. Only then
`POST /users/me/bank-account` re-resolves (never trusts a name from the app), creates a Paystack
transfer recipient, and saves it. The app only ever sees bank name, holder name and last 4
digits; the full number and recipient code stay server-side.

`POST /jobs/:id/apply` returns 403 without a recipient code. The app mirrors this on the job
screen with a link to set one up.

## Step 2 — funding, and how it's confirmed

`POST /jobs/:id/contract/fund` initializes a Paystack transaction and returns its checkout URL.
The app opens it in the system in-app browser (Chrome Custom Tabs / SFSafariViewController), not
Paystack's Flutter SDK — the SDK takes cards only on mobile; the hosted checkout also offers bank
transfer and USSD.

A contract becomes `funded` through **one function**, `confirmFunding` in
`king-domain-backend/src/contractFunding.js`, reached three ways:

- **Webhook** — `POST /webhooks/paystack`, HMAC-SHA512 over the raw body, `charge.success`.
- **Verify** — `POST /jobs/:id/contract/verify-payment`: the app calls this when the client returns
  to it and every 6 s for up to 10 minutes while waiting; the server asks Paystack directly.
- **Fund pre-check** — if the client taps Pay again, the server first checks whether the previous
  checkout was actually paid, and records that instead of opening a second checkout.

`confirmFunding` checks the amount paid against budget + fee, is idempotent (only an
`awaitingPayment` contract changes), and logs both sides of every decision plus a read-back.

**References** are `kd_<contractId>_<8 hex>`. Each Pay tap mints a new one and overwrites the
stored reference, so a payment that completes on an *older* checkout (a slow bank transfer) is
matched by the contract id inside the reference, not the stored one.

**Paid twice** — a second successful charge on an already-funded contract is logged as
`DUPLICATE PAYMENT needs manual refund` and refunded by hand from the Paystack dashboard.

## Step 4 — payout

`POST /jobs/:id/contract/approve` calls Paystack `POST /transfer` from balance to the talent's
recipient. The contract is marked `approved` only if Paystack answers `success` or `pending`
(money on its way); anything else — notably `otp` — leaves it `submitted` and returns an error, so
nobody is told they've been paid when they haven't.

**Payout references** are `kd_payout_<contractId>_<n>`, one per attempt. Before sending, the server
looks earlier attempts up with Paystack: a live one (`success`/`pending`/`otp`/`received`) is
reused, never doubled; after a conclusive failure it moves to `n+1`. Two simultaneous approvals
compute the same next reference, so Paystack's duplicate-reference check blocks a double payout.

`pending` resolves later by webhook. `transfer.failed` / `transfer.reversed` (money returned to our
balance) is logged as `PAYOUT FAILED needs manual retry` — the contract already reads `approved`,
so re-sending is manual for now.

## Configuration

- `PAYSTACK_SECRET_KEY` — staging/local use the **test** key; production gets the King Domain
  business's **live** key, set only on Render, never in a file.
- Paystack dashboard webhook URL: `https://king-domain-backend-1.onrender.com/webhooks/paystack`.
- Paystack **Settings → Preferences**: turn off *Confirm transfers before sending* on the King
  Domain business. It's per-business; with it on, every payout stops at `otp`.
- Ship order: live key on Render → webhook URL → transfer OTP off → push backend → push app.
  Pushing the backend first breaks applying in production (the bank list can't load without a key).
- Bank-account lookup and save are rate limited per user (20 and 10 per 15 min) — the lookup
  returns real account holders' names.

## Tests

See [testing.md](./testing.md) for what is covered, what passed, and what is not guaranteed.

## Not built yet

- **Stages 2 and 3 of the decision** — delivery dates and extensions, change requests (max 2
  rounds), disputes with an admin ruling and split refunds. Auto-release must stay off until the
  client can object.
- **Refunds** — manual, from the Paystack dashboard.
- **Payout state on the contract** — a payout that fails after approval is only logged; the
  contract still reads `approved` and the talent's app says paid. Needs a schema change.
- **Background reconciliation** — a contract whose client never returns to the app *and* whose
  webhook never arrives stays `awaitingPayment` until the client reopens it.
- **Notifications** — the talent learns a contract is funded by opening the app.
