# Stage 2 — delivery dates, extensions, change rounds

**Status (2026-10-01):** backend built and tested on staging (93/93, see [testing.md](../core/testing.md));
UI not built. Implementation notes beyond the design: the history list is its own endpoint
(`GET /contract/history`), not part of every contract; delivering withdraws an open extension
request; review reminders only go out while auto-release is on; payouts claim the contract first
(release claim) so a change request can't cross a payout.
Implements stage 2 of shareholder decision "How a job gets paid" (ledger `736051b0-a968-43cd-b9f5-ecbb1b442197`).
Stage 1 (24 h payment window, 3-day auto-release) is described in [payments.md](../core/payments.md).
Stage 3 (disputes, admin screen, cancel and refund) is not part of this.

## Rules decided in the ledger text

Delivery date on every job; up to 2 extensions with 48 h for the client to answer each; 3-day review
with silence = approval; at most 2 change rounds, each with a 3-day clock, then an admin; delivery
date missed by 3 days with nothing delivered and no agreed extension = client may cancel for a full
budget refund (**cancel and refund are not built in this stage**).

## Clarifications made while designing (not in the ledger text — show the other shareholder)

| Gap | Decision (Victor, 2026-10-01) |
|---|---|
| Who sets the delivery date, and when | The client sets a **number of days** (1–60) when posting. The date is fixed at **funding**: `deliverByAt = fundedAt + deliveryDays`. Jobs posted before this existed have no deadline features. |
| Client silent for 48 h on an extension | **Granted automatically.** (Same as Fiverr; follows "neither side can stall the other".) |
| How long an extension can be | The talent chooses N extra days, **up to the job's original duration**. Days are added to the delivery date. |
| Extension limits | 2 **requests** per contract (a declined one counts), one open at a time, only before delivery and before the overdue flag. A pending request pauses the overdue flag. |
| Talent doesn't resubmit within their 3-day change clock | **Goes to an admin** as a dispute. |
| After round 2, client still unhappy | No round 3: the client's action becomes "escalate to an admin" with a written reason required. |
| Auto-release | Stays **off** through stage 2; switch on only once stage 3 can resolve escalated contracts. |
| Cancel / refund | **Not built** (Victor: nobody is hired until Paystack is open). The overdue state is recorded and the client emailed; no cancel action, no money moves. |
| Reminders | Email + in-app countdown/banner now; **push notifications are the next stage**, before Paystack opens. |

Evidence (Fiverr help centre, checked 2026-10-01): an unanswered extension request is auto-accepted
after 48 h; extra time is added to the original date; a client can cancel without approval 24 h past
an un-extended date; delivery auto-completes after 3 days of silence; delivery time runs from the
order starting, not a calendar date.

## States

New `ContractStatus` values: `changesRequested` (talent owes a resubmit) and `disputed` (parked for
an admin; stage 2 only ever *enters* it, stage 3 resolves it).

```
awaitingPayment → funded → inProgress → submitted → approved
                                  ↑          │
                                  │          ├─ client asks for changes ─→ changesRequested
                                  └──────────┴──── talent resubmits ←──────┘
 submitted / changesRequested ──(round 2 still rejected, or talent misses the clock)──→ disputed
```

## Clocks

Each is a timestamp; the 5-minute tick enforces it and catches up after downtime.

| Clock | Starts | If nobody acts |
|---|---|---|
| Delivery date (`deliverByAt`) | funding | +3 days: flagged overdue, client emailed |
| Extension answer (`answerDueAt`, 48 h) | talent asks | auto-granted |
| Review (`reviewDueAt`, 3 days) | each delivery | approved and paid (only when auto-release is on) |
| Change resubmit (`changeDueAt`, 3 days) | client asks | escalated to an admin |

**Race rule.** Every transition is a conditional update from the expected state; the loser gets a
clear "someone just did that". An action that reaches the server *before the tick has committed* is
honoured even a few minutes past the clock; once the tick commits, it is final.

## Data (additive)

- `Job.deliveryDays Int?`
- `Contract`: `deliverByAt`, `extensionsUsed`, `changeRounds`, `changeDueAt`, `overdueFlaggedAt`
- `ContractExtension`: contractId, requestedDays, reason, status (`pending|granted|declined|autoGranted`), requestedAt, answerDueAt, resolvedAt, resolvedBy
- `ChangeRequest`: contractId, round (1|2), reason, requestedAt, resubmitDueAt, resubmittedAt
- `ContractDelivery`: contractId, version, note, url, filePath, submittedAt — **immutable**; the existing `deliverable*` contract fields keep mirroring the latest so the apps keep working. Uploaded files already have unique timestamped paths and are never overwritten.
- `ContractReminder`: unique (contractId, key). Inserted *before* the email is sent so a restart or two overlapping ticks can never send twice; removed if the send fails so it retries.
- Enum additions `changesRequested`, `disputed`.

## Code

`contractLifecycle.js` stays the orchestrator (its tick calls each module's sweep). New:
`contractExtensions.js` (request, answer, auto-grant), `contractChanges.js` (request, resubmit,
escalate, 3-day escalation), `contractReminders.js` (declarative schedule + guarded send).

## API (under `/jobs/:id/contract/`)

`POST extension` (talent: days, reason) · `POST extension/:extId/answer` (client: grant|decline) ·
`POST request-changes` (client: reason; after round 2 it escalates instead) · `POST submit` now also
from `changesRequested`, creating a new version · `POST /jobs` now requires `deliveryDays`.
The contract JSON gains the delivery date, the open extension, change round, deadlines and version list.

## Reminders

Each clock gets the same three messages. The first is sent by the action itself; the tick sends the rest.

| Clock | Who | Messages |
|---|---|---|
| Extension answer (48 h) | client | on request, 24 h left, 6 h left |
| Review (3 days) | client | on delivery, 24 h left, 6 h left |
| Change resubmit (3 days) | talent | when asked (with the client's reasons), 24 h left, 6 h left |
| Delivery date | talent | 24 h before, and when it passes |
| Delivery date missed | client | when it passes, and at +3 days (overdue) |

Plus one email to everyone affected when a clock resolves. After downtime a stale reminder is
skipped when the next threshold has also passed.

## Not in this stage

Cancel and refund; the Dispute record, admin screen and rulings (stage 3); push notifications (next
stage); the Flutter flows — delivery days on the post-job form, extension ask and answer, change
request, version history, countdown banners, escalated state.

**Compatibility note.** The current app maps any status it doesn't know to "no contract", which the
payment screen reads as "this award was cancelled". An old build would misreport a contract in
`changesRequested`/`disputed`. Accepted: nobody is hired until Paystack opens, and the screens ship
with this work.

## Build order (each step ships with its tests; ledger in [testing.md](../core/testing.md))

1. Schema, `deliveryDays`, `deliverByAt` at funding, delivery versions, resubmission.
2. Extensions and the 48 h auto-grant.
3. Change rounds and escalation.
4. Overdue flagging.
5. Reminders and emails.
6. Ledger and docs, then push to staging; production schema push before any production deploy.
