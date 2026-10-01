# Payments — how money moves

**Status (2026-10-01):** built and tested on staging; production database schema is in place;
not live. Going live is blocked on the King Domain Paystack business being activated and
upgraded to *Registered Business* (needs MJP Productions Limited's CAC certificate) — a
Starter Business cannot make the payouts in step 4.

Provider: **Paystack**. Platform fee: **10%**, charged to the client on top of the job budget
(shareholder decision "Set King Domain's platform fee on job payments", 2026-09-18). The talent
always receives the full posted budget.

## The flow

| # | Who | What happens | Contract status after |
|---|---|---|---|
| 0 | Talent | Adds a payout bank account. **Required before applying** (decision 2026-10-01) | — |
| 1 | Client | Awards one applicant. Fee is computed and frozen onto the contract | `awaitingPayment` |
| 2 | Client | Pays budget + fee on Paystack's hosted checkout | `funded` once confirmed |
| 3 | Talent | Starts work, submits deliverable | `inProgress` → `submitted` |
| 4 | Client | Approves. Backend transfers the **budget only** to the talent's bank | `approved` |

There is no escrow product: between steps 2 and 4 the money sits in King Domain's own Paystack
balance. The fee simply never leaves it.

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

## Not built yet

- **Disputes / non-delivery** — no rule for money held when a client never approves or a talent
  never delivers. Open product decision.
- **Refunds** — manual, from the Paystack dashboard.
- **Payout state on the contract** — a payout that fails after approval is only logged; the
  contract still reads `approved` and the talent's app says paid. Needs a schema change.
- **Background reconciliation** — a contract whose client never returns to the app *and* whose
  webhook never arrives stays `awaitingPayment` until the client reopens it.
- **Notifications** — the talent learns a contract is funded by opening the app.
