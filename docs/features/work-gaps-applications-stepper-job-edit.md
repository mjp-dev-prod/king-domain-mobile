# Work gaps: my applications, lifecycle stepper, edit or close a job

**Status: planned (design approved by Victor 2026-10-22; not built).**
Scope is everything here except money: no payment, refund, payout or cancel-after-award
behaviour changes. Brand v1 applies (amber = waiting, green = done, red = missed, gold = money
only; no emoji, no decorative gradients, no glow).

Found in Victor's first phone walkthrough (items 1 and 2, logged in `pending_next_build`) and in the
2026-10-22 gap audit (item 3: the backend has no edit or delete job route and the app has no UI).

## 1. My applications (talent, app only)

The job feed already carries the viewer's own status on every job (`myApplicationStatus`), so no
server change is needed beyond item 3's `closedAt`.

The Work tab gets two segments, **Awarded** (today's contracts) and **Applied**. Counts show on
the segment labels. A job is in **Applied** when the viewer applied and the application is not
the selected one: `pending` or `notSelected`. A selected application is a contract, so it shows
under Awarded (existing `WorkTab.mine`).

| Application | Job state | Status line | Tone |
|---|---|---|---|
| pending | open | Waiting for {client name} to pick | amber (waiting) |
| notSelected | awarded to someone else | Not picked | neutral |
| notSelected | closed by the client | Closed by the client | neutral |

Rows show title, client, budget (gold) and the status line, and open the job detail. Order: waiting
first, then newest first. Empty state (Applied): says why and links to Browse jobs. Loading uses the
existing skeleton; an error shows Retry. Pull to refresh refreshes the shared feed.

## 2. Lifecycle stepper (both contract screens, app only)

Five steps, from `prototypes/palette-explorer.html`: **Awarded, Payment secured, Working on it,
Client reviews, Paid.** Derived only from existing contract status and dates. It changes no
payment logic. It does not say where money is held (Paystack lists escrow services as ineligible,
see `payments_rollout`); copy says what happened: "Client has paid", "Paid to your payout account".

| Contract status | Done | Current | Later |
|---|---|---|---|
| awaitingPayment | 1 | 2 (amber, waiting) | 3 4 5 |
| funded | 1 2 | 3 | 4 5 |
| inProgress | 1 2 | 3 (red subtitle when `overdue`) | 4 5 |
| submitted | 1 2 3 | 4 (amber, waiting) | 5 |
| changesRequested | 1 2 | 3, subtitle "Changes requested, round N of 2" | 4 5 |
| disputed | 1 2 3 | 4 (red, "With an admin") | 5 |
| approved | 1 2 3 4 5 | none | none |

Subtitles use real data (pay-by, delivery date, review clock when auto-release is on) and differ by
viewer ("Pay within 23h" for the client, "Waiting for the client to pay" for the talent). Each step
announces "Step N of 5, name, done/current/later" to screen readers. A waiting current step pulses
(existing `PulseDot`); with reduced motion it does not.

## 3. Edit or close an open job (backend and app)

### Rules
- Only the job's client, and only **before an award** (no contract). Cancelling after an award is the
  refund path and is not part of this work.
- **Edit only until the first applicant applies.** After that the terms are locked: the client closes
  the job and posts a new one. Same field rules as posting (title, category, description, budget,
  delivery days).
- **Close** is final. It hides the job from the feed, marks every pending application `notSelected`,
  and applicants see "Closed by the client". No reopen.
- Closed jobs cannot be applied to or awarded.

### Schema (additive, nullable or defaulted: plain `db push`, no data loss)
`Job.closedAt DateTime?`, `Job.revision Int @default(0)`, `Job.lastAppliedAt DateTime?`.

### Endpoints
- `PATCH /jobs/:id`, owner only. Body as for create. 200 with the job.
  403 not your job; 404; 409 `awarded` | `closed` | `has_applicants`; 400 validation.
- `POST /jobs/:id/close`, owner only. 200 with the job. 403; 404; 409 `awarded` | `closed`.
- `POST /jobs/:id/apply` accepts an optional `revision`. If present and different from the job's
  current revision: 409 `terms_changed`. Absent (older app builds): accepted, as today.
- The feed (`GET /jobs`) returns a job to a talent unless it is closed and they never applied;
  the owner always sees their own. `serializeJob` adds `closedAt` and `revision`.

### Why `revision` and `lastAppliedAt` (races)
Without them, a talent who loaded the job before an edit could apply to terms they never saw, and an
edit could slip in while an application was being written. The guards are single conditional UPDATEs
on the job row, so concurrent requests serialise on the row lock and re-check its columns:
- apply: `updateMany where {id, closedAt: null, awardedApplicationId: null, revision: expected}`
  sets `lastAppliedAt`, then inserts the application in the same transaction.
- edit: `updateMany where {id, clientId, closedAt: null, awardedApplicationId: null,
  lastAppliedAt: null, applications: none}` bumps `revision`. (`applications: none` covers jobs that
  were applied to before the column existed.)
- close: `updateMany where {id, clientId, closedAt: null, awardedApplicationId: null}`, then marks
  pending applications `notSelected` in the same transaction.
- award: today it reads the job, then writes. It becomes an interactive transaction that claims the
  job with `updateMany where {id, awardedApplicationId: null, closedAt: null}` first.

### App
- `Job` gains `closedAt`, `revision`. `PostJobScreen` gets an edit mode (prefilled, "Save changes").
- `ContractHeader` gets an optional trailing slot. `ApplicantsScreen` uses it for a menu sheet:
  **Edit job** (disabled with the reason once anyone has applied) and **Close job** (confirmation sheet
  naming how many applicants will be told).
- Closed jobs: the client's list shows a "Closed" pill, sorted last, and the applicants screen is
  read-only. The talent's job detail has no Apply button and says the client closed it.
- Apply sends `revision`. On `terms_changed` the app refreshes, closes the sheet, and says the job was
  just edited so the talent can read the new terms.

## Tests (each written before its code, watched failing)
Backend (real HTTP and database, the existing harness, `barrierPrisma` for races): edit rules and
errors, close effects, feed visibility, apply on closed, stale revision, award on closed, and the
races (edit vs apply, close vs apply, close vs award). App: Applied segment (all three lines, empty,
error, ordering), the stepper for every status and viewer, edit mode, the menu and its disabled state,
the close confirmation, closed-job views, `terms_changed` handling.

## Not in this work
Cancel or refund after an award, notifying applicants by push (Firebase is last), reopening a closed
job, search or sort on the feed.
