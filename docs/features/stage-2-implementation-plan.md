# Stage 2 — Delivery Dates, Extensions, Change Rounds: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the backend for stage 2 of "How a job gets paid": a delivery date on every funded
contract, up to 2 extension requests (48 h answer, silence = granted), up to 2 change rounds (3-day
resubmit clock, then an admin), overdue flagging, immutable delivery versions, and reminders.

**Architecture:** Every clock is a timestamp on a row; the existing 5-minute tick in
`contractLifecycle.js` calls one sweep per module. Every state change is a conditional
`updateMany` (compare-and-swap) so races resolve to exactly one winner. Pure rules and shared helpers
live in a new `contractCore.js` so the new modules and the lifecycle orchestrator don't require each
other.

**Tech Stack:** Node 24 (CommonJS), Express 5, Prisma 7 with `@prisma/adapter-pg`, Postgres (Neon),
`node:test` + `node:assert/strict`, Brevo HTTP email.

**Spec:** [stage-2-delivery-and-changes.md](./stage-2-delivery-and-changes.md). Read it first.

## Global Constraints

- Repo: `C:\mobile-projects\flutter\kings domain\king-domain-backend` (abbreviated `backend/` below). Docs live in the mobile repo.
- Numbers (verbatim from the spec): delivery days **1–60**; **2** extension requests per contract, a declined one counts; extension answer window **48 h**, silence = granted; extension length **1 to the job's original `deliveryDays`**; **2** change rounds; resubmit clock **3 days**; review **3 days**; overdue flag at delivery date **+ 3 days**.
- Reminders: thresholds **24 h left** and **6 h left**; stale reminders are skipped; at most once per (contract, key).
- Auto-release stays **off** (`AUTO_RELEASE_ENABLED` unset). Review reminders only go out when it is on.
- **No cancel, no refund, no money movement** is added in this stage.
- Reasons (extension, change request): **10–1000** characters after trimming.
- Tests: `npm test` runs `test/*.test.js` against `TEST_DATABASE_URL` (Neon `test` branch, in git-ignored `.env.test`). Never point anything at production (Supabase). Each rule gets a named test in the same commit.
- Code style: match the surrounding files — CommonJS, double quotes, `// why` comments, log lines that show **both sides** of every decision (CLAUDE.md hard rule 1).
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Each commit is gated by the pre-commit-review skill (`node "C:\Users\USER\.claude\hooks\mark-reviewed.js" MERGE` after a MERGE verdict).
- Known consequence (accepted): once Task 1 lands, the current app's post-job form fails (it doesn't send `deliveryDays`) until the UI stage adds the field. Old app builds also misreport `changesRequested`/`disputed` contracts.

## File structure

| File | Responsibility |
|---|---|
| `backend/src/contractCore.js` (new) | `RULES`, `HOUR`/`DAY`, `baseDeps`, `recordEvent`, `refuse`, `validReason`, `parties`, `autoReleaseEnabled` |
| `backend/src/contractChanges.js` (new) | `submitDelivery` (versions), `requestChanges`, `escalateContract`, `sweepChanges` |
| `backend/src/contractExtensions.js` (new) | delivery date: `requestExtension`, `answerExtension`, `sweepExtensions`, `sweepOverdue` |
| `backend/src/contractReminders.js` (new) | `SCHEDULE`, `currentReminder`, `sendOnce`, `sweepReminders` |
| `backend/src/contractLifecycle.js` | uses `contractCore`; release claim in `releasePayment`; tick calls the stage-2 sweeps |
| `backend/src/contractFunding.js` | sets `deliverByAt` at funding |
| `backend/src/user/jobsRoutes.js` | `deliveryDays` on POST /jobs; new contract routes; thin wrappers over the modules |
| `backend/src/admin/mailer.js` | new templates |
| `backend/prisma/schema.prisma` | new fields, enums, 4 tables |
| `backend/test/helpers.js` | Proxy spy mailer, seeding helpers |
| `backend/test/*.test.js` | one file per module + one HTTP file |

---

### Task 1: Schema, shared core, delivery days and the delivery date

**Files:**
- Modify: `backend/prisma/schema.prisma`
- Create: `backend/src/contractCore.js`
- Modify: `backend/src/contractLifecycle.js` (import from core)
- Modify: `backend/src/contractFunding.js`
- Modify: `backend/src/user/jobsRoutes.js` (POST /jobs, serializeJob, serializeContract, requireContractStatus)
- Modify: `backend/test/helpers.js`, `backend/test/lifecycle.test.js` (K, L)
- Create: `backend/test/deliveryDates.test.js`, `backend/test/stage2Routes.test.js`

**Interfaces:**
- Produces: `contractCore` exports `{ HOUR, DAY, RULES, baseDeps(deps) -> {prisma, mailer, now}, recordEvent(db, {jobId, contractId, type, meta}), refuse(status, code, error) -> {ok:false,status,code,error}, validReason(reason) -> boolean, parties(prisma, contract) -> {job, client, talent}, autoReleaseEnabled() }`.
- Produces: helpers `spyMailer()` (records **any** method), `seedAward(ctx, {budget, contract, job})`, `seedWorking(ctx, {deliveryDays, status, deliverByAt, contract})`, `seedSubmitted(ctx, {changeRounds, contract})`.
- Produces: `requireContractStatus(statusOrArray)` in jobsRoutes.

- [ ] **Step 1: Schema.** Use the Edit tool (the file may be CRLF). In `enum ContractStatus`, between `submitted` and `approved`, add:

```prisma
  /// The client asked for changes; the talent owes a resubmit by changeDueAt.
  changesRequested
  /// Parked for an admin: round 2 still rejected, or the talent missed the
  /// resubmit clock. Stage 2 only enters it; stage 3 builds the screen that
  /// resolves it.
  disputed
```

In `model Job`, after `budget`:

```prisma
  /// Days the talent has to deliver, counted from funding (1–60). The
  /// contract's deliverByAt is fixed from this when it is funded. Null on
  /// jobs posted before delivery dates existed: no deadline features.
  deliveryDays Int?
```

In `model Contract`, after `lastAutoReleaseAttemptAt`:

```prisma
  /// fundedAt + Job.deliveryDays; granted extensions add their days.
  deliverByAt         DateTime?
  /// Extension REQUESTS made (a declined one counts). Max 2.
  extensionsUsed      Int       @default(0)
  /// Change rounds the client has opened. Max 2; after that, escalation.
  changeRounds        Int       @default(0)
  /// While changesRequested: the talent must resubmit by this or it goes to an admin.
  changeDueAt         DateTime?
  /// Set once by the tick when deliverByAt + 3 days passes with nothing delivered.
  overdueFlaggedAt    DateTime?
  /// Set while a payout is in flight (releasePayment), so a change request
  /// can't slip in between the transfer and the status update.
  releaseClaimedAt    DateTime?
  extensions          ContractExtension[]
  changeRequests      ChangeRequest[]
  deliveries          ContractDelivery[]
  reminders           ContractReminder[]
```

After `model ContractEvent`, add:

```prisma
enum ExtensionStatus {
  pending
  granted
  declined
  autoGranted
  /// The talent delivered while the request was still open.
  withdrawn
}

/// One extension request. Stage 2 of "How a job gets paid".
model ContractExtension {
  id            String          @id @default(uuid())
  contractId    String
  contract      Contract        @relation(fields: [contractId], references: [id], onDelete: Cascade)
  requestedDays Int
  reason        String
  status        ExtensionStatus @default(pending)
  requestedAt   DateTime        @default(now())
  answerDueAt   DateTime
  resolvedAt    DateTime?
  /// The client's user id; null when auto-granted or withdrawn.
  resolvedById  String?

  @@index([contractId, status])
  @@index([status, answerDueAt])
  @@map("contract_extensions")
}

/// One change round opened by the client.
model ChangeRequest {
  id            String    @id @default(uuid())
  contractId    String
  contract      Contract  @relation(fields: [contractId], references: [id], onDelete: Cascade)
  round         Int
  reason        String
  requestedAt   DateTime  @default(now())
  resubmitDueAt DateTime
  resubmittedAt DateTime?

  @@unique([contractId, round])
  @@map("change_requests")
}

/// Every delivery, immutable. Contract.deliverable* mirror the latest one.
model ContractDelivery {
  id          String   @id @default(uuid())
  contractId  String
  contract    Contract @relation(fields: [contractId], references: [id], onDelete: Cascade)
  version     Int
  note        String?
  url         String?
  /// Supabase Storage path (private bucket), never a URL.
  filePath    String?
  submittedAt DateTime @default(now())

  @@unique([contractId, version])
  @@map("contract_deliveries")
}

/// A reminder that was sent. Inserted BEFORE the email so a restart or two
/// overlapping ticks can never send the same one twice.
model ContractReminder {
  id         String   @id @default(uuid())
  contractId String
  contract   Contract @relation(fields: [contractId], references: [id], onDelete: Cascade)
  key        String
  sentAt     DateTime @default(now())

  @@unique([contractId, key])
  @@map("contract_reminders")
}
```

- [ ] **Step 2: Push the schema to the test branch, then staging.** Additive only. If Prisma mentions data loss or asks to confirm, STOP and report; do not pass `--accept-data-loss`.

```bash
cd "C:/mobile-projects/flutter/kings domain/king-domain-backend"
set -a; . ./.env.test; set +a
DIRECT_URL="${TEST_DATABASE_URL/-pooler/}" npm run db:push   # test branch
npm run db:push                                                # .env = Neon staging
```

Expected: "Your database is now in sync with your Prisma schema" twice, then "Generated Prisma Client".

- [ ] **Step 3: Create `backend/src/contractCore.js`:**

```js
// Shared by the contract modules: the agreed numbers, the event trail and
// injectable dependencies. Kept apart from contractLifecycle.js so the
// stage 2 modules and the lifecycle orchestrator can all use it without a
// circular require.
const { prisma: realPrisma } = require("./db");
const realMailer = require("./admin/mailer");

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

/** Shareholder decision "How a job gets paid" (ledger 736051b0), stage 2. */
const RULES = {
  reviewMs: 3 * DAY,
  deliveryDays: { min: 1, max: 60 },
  maxExtensionRequests: 2,
  extensionAnswerMs: 48 * HOUR,
  maxChangeRounds: 2,
  changeResubmitMs: 3 * DAY,
  overdueGraceMs: 3 * DAY,
  reasonLength: { min: 10, max: 1000 },
  // A release that crashed mid-way stops blocking after this; the next
  // release still reuses any transfer the crash left live.
  releaseClaimStaleMs: 10 * 60 * 1000,
};

/**
 * Auto-release pays the talent when the client says nothing. Only fair once
 * the client can object AND an objection can be resolved (stage 3), so it
 * stays off until switched on deliberately.
 */
function autoReleaseEnabled() {
  return process.env.AUTO_RELEASE_ENABLED === "true";
}

function baseDeps(deps = {}) {
  return {
    prisma: deps.prisma ?? realPrisma,
    mailer: deps.mailer ?? realMailer,
    now: deps.now ?? (() => new Date()),
  };
}

function recordEvent(db, { jobId, contractId, type, meta }) {
  return db.contractEvent.create({ data: { jobId, contractId, type, meta: meta ?? undefined } });
}

/** A refused action or a lost race, in the shape the routes return. */
function refuse(status, code, error) {
  return { ok: false, status, code, error };
}

function validReason(reason) {
  if (typeof reason !== "string") return false;
  const length = reason.trim().length;
  return length >= RULES.reasonLength.min && length <= RULES.reasonLength.max;
}

/** The job, its client and the awarded talent (for emails). */
async function parties(prisma, contract) {
  const job = contract.job ?? (await prisma.job.findUnique({ where: { id: contract.jobId } }));
  const [client, application] = await Promise.all([
    prisma.user.findUnique({ where: { id: job.clientId } }),
    job.awardedApplicationId
      ? prisma.application.findUnique({ where: { id: job.awardedApplicationId }, include: { talent: true } })
      : null,
  ]);
  return { job, client, talent: application?.talent ?? null };
}

module.exports = { HOUR, DAY, RULES, autoReleaseEnabled, baseDeps, recordEvent, refuse, validReason, parties };
```

- [ ] **Step 4: Point `contractLifecycle.js` at the core.** Replace its local `HOUR`, `autoReleaseEnabled` and `recordEvent` definitions (and the comment block above `autoReleaseEnabled`) with:

```js
const { HOUR, RULES, autoReleaseEnabled, recordEvent } = require("./contractCore");
```

and change `reviewMs: 3 * 24 * HOUR,` in `WINDOWS` to `reviewMs: RULES.reviewMs,`. Keep exporting `autoReleaseEnabled` and `recordEvent` from `contractLifecycle.js` (routes and tests use them).

- [ ] **Step 5: Helpers.** In `backend/test/helpers.js` replace `spyMailer` with:

```js
/** Records every email the code tries to send, whatever the template. */
function spyMailer() {
  const sent = [];
  return new Proxy(
    {},
    {
      get(_, key) {
        if (key === "sent") return sent;
        if (key === "then") return undefined; // not a promise
        return async (args = {}) => {
          sent.push({ k: key, to: args.to, args });
          return { sent: true };
        };
      },
    },
  );
}
```

Change `seedAward` to accept job overrides (`{ budget = 1000, contract = {}, job = {} } = {}`, spreading `...job` into `prisma.job.create`'s `data`), and add after it:

```js
const DAY_MS = 24 * 3_600_000;

/** Funded and being worked on, with a delivery date. */
function seedWorking(ctx, { deliveryDays = 5, status = "inProgress", deliverByAt, contract = {} } = {}) {
  return seedAward(ctx, {
    job: { deliveryDays },
    contract: { status, payByAt: null, fundedAt: new Date(), deliverByAt: deliverByAt ?? new Date(Date.now() + deliveryDays * DAY_MS), ...contract },
  });
}

/** Delivered (version 1 exists) and awaiting review. */
async function seedSubmitted(ctx, { changeRounds = 0, contract = {} } = {}) {
  const s = await seedWorking(ctx, {
    status: "submitted",
    contract: { submittedAt: new Date(), reviewDueAt: new Date(Date.now() + 3 * DAY_MS), deliverableNote: "v1", changeRounds, ...contract },
  });
  await prisma.contractDelivery.create({ data: { contractId: s.c.id, version: 1, note: "v1" } });
  return s;
}
```

Export `seedWorking`, `seedSubmitted`, `DAY_MS`.

- [ ] **Step 6: Write the failing tests.** Create `backend/test/deliveryDates.test.js`:

```js
// Stage 2: the delivery date. The client sets days when posting; the date
// is fixed when the contract is funded (decision clarification, 2026-10-01).
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;
const { confirmFunding } = require("../src/contractFunding");

let ctx;
before(async () => { ctx = await h.fixtures(); });
after(async () => {
  await prisma.job.deleteMany({ where: { title: { startsWith: h.TITLE_PREFIX } } });
  await prisma.$disconnect();
});

describe("delivery date", () => {
  it("funding fixes deliverByAt = fundedAt + the job's delivery days", async () => {
    const s = await h.seedAward(ctx, { job: { deliveryDays: 5 }, contract: { payByAt: h.future() } });
    const r = await confirmFunding({ reference: `kd_${s.c.id}_aaaaaaaa`, amountKobo: 110000, source: "suite" });
    assert.equal(r.outcome, "funded");
    const c = await prisma.contract.findUnique({ where: { id: s.c.id } });
    assert.equal(c.deliverByAt.getTime() - c.fundedAt.getTime(), 5 * h.DAY_MS);
  });

  it("a job posted before delivery dates existed gets no delivery date", async () => {
    const s = await h.seedAward(ctx, { contract: { payByAt: h.future() } });
    await confirmFunding({ reference: `kd_${s.c.id}_bbbbbbbb`, amountKobo: 110000, source: "suite" });
    assert.equal((await prisma.contract.findUnique({ where: { id: s.c.id } })).deliverByAt, null);
  });
});
```

Create `backend/test/stage2Routes.test.js`:

```js
// Stage 2 over real HTTP: the real server against the test database.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;

let ctx, fake, server, ct, tt, tb;
before(async () => {
  ctx = await h.fixtures();
  fake = await h.serveFakeProvider(h.fakeProvider());
  server = await h.startServer({ port: 4612, paystackUrl: fake.url, autoRelease: false });
  [ct, tt, tb] = await Promise.all([h.tokenFor(ctx.client), h.tokenFor(ctx.talentA), h.tokenFor(ctx.talentB)]);
});
after(async () => {
  server?.stop();
  fake?.server.close();
  await prisma.job.deleteMany({ where: { title: { startsWith: h.TITLE_PREFIX } } });
  await prisma.$disconnect();
});

const post = (tok, p, body) => h.call(server.base, tok, "POST", p, body);
const jobBody = (deliveryDays) => ({ title: `${h.TITLE_PREFIX}routes`, category: h.CATEGORY, description: "suite", budget: 1000, deliveryDays });

describe("POST /jobs delivery days", () => {
  it("is required, a whole number from 1 to 60", async () => {
    for (const bad of [undefined, 0, 61, 2.5, "x"]) {
      const r = await post(ct, "/jobs", jobBody(bad));
      assert.equal(r.status, 400, `deliveryDays=${bad}`);
    }
    const ok = await post(ct, "/jobs", jobBody(7));
    assert.equal(ok.status, 201);
    assert.equal(ok.json.job.deliveryDays, 7);
  });
});
```

- [ ] **Step 7: Run them and watch them fail.** `npm test`. Expected: the two delivery-date tests fail (`deliverByAt` is null), the route test fails (POST without `deliveryDays` returns 201), and `lifecycle.test.js` K/L still pass.

- [ ] **Step 8: Implement.** In `contractFunding.js` add `const { DAY } = require("./contractCore");` and replace the funding `updateMany` with:

```js
  const fundedAt = new Date();
  // The delivery clock starts at funding, not at posting: a date chosen when
  // the job was posted could run out before anyone was committed to it.
  const deliverByAt = contract.job.deliveryDays ? new Date(fundedAt.getTime() + contract.job.deliveryDays * DAY) : null;
  const { count } = await prisma.contract.updateMany({
    where: { id: contract.id, status: "awaitingPayment" },
    data: { status: "funded", fundedAt, deliverByAt, paystackReference: reference, paymentFailed: false },
  });
```

and add `deliverByAt=${readBack.deliverByAt?.toISOString() ?? "none"}` to the existing read-back log line.

In `jobsRoutes.js`: `const { RULES } = require("../contractCore");`. In `POST /`, read `deliveryDays` from the body and, after the budget check:

```js
  const days = Number(deliveryDays);
  if (!Number.isInteger(days) || days < RULES.deliveryDays.min || days > RULES.deliveryDays.max) {
    return res.status(400).json({
      error: `deliveryDays must be a whole number of days from ${RULES.deliveryDays.min} to ${RULES.deliveryDays.max}.`,
    });
  }
```

Pass `deliveryDays: days` into `prisma.job.create`. In `serializeJob` add `deliveryDays: job.deliveryDays ?? null,`. In `serializeContract`, after `reviewDueAt`, add:

```js
    deliverByAt: contract.deliverByAt ?? null,
    extensionsUsed: contract.extensionsUsed ?? 0,
    changeRounds: contract.changeRounds ?? 0,
    changeDueAt: contract.changeDueAt ?? null,
    overdue: Boolean(contract.overdueFlaggedAt),
```

Replace `requireContractStatus` with:

```js
function requireContractStatus(statuses) {
  const allowed = Array.isArray(statuses) ? statuses : [statuses];
  return (req, res, next) => {
    if (!allowed.includes(req.contract.status)) {
      return res.status(400).json({
        error: `Contract must be '${allowed.join("' or '")}' for this action (currently '${req.contract.status}').`,
      });
    }
    next();
  };
}
```

In `lifecycle.test.js` K, add `deliveryDays: 7` to the `POST /jobs` body; in L, after the funded assertion add:

```js
    const funded = await prisma.contract.findUnique({ where: { id: contractId } });
    assert.equal(funded.deliverByAt.getTime() - funded.fundedAt.getTime(), 7 * h.DAY_MS, "delivery date fixed at funding");
```

- [ ] **Step 9: Run.** `npm test` — expected all pass (previous 23 + 3 new).

- [ ] **Step 10: Review and commit.** Run the pre-commit-review skill; on MERGE:

```bash
git add prisma/schema.prisma src/contractCore.js src/contractLifecycle.js src/contractFunding.js src/user/jobsRoutes.js test/
git commit -m "Stage 2: delivery days on jobs and a delivery date fixed at funding

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Immutable delivery versions and resubmission

**Files:**
- Create: `backend/src/contractChanges.js`
- Modify: `backend/src/user/jobsRoutes.js` (submit route, new history route, `requireParty`)
- Modify: `backend/src/admin/mailer.js` (`sendDeliveryAwaitingReview` gains `version`)
- Create: `backend/test/deliveries.test.js`; Modify: `backend/test/stage2Routes.test.js`

**Interfaces:**
- Consumes: `contractCore` (Task 1).
- Produces: `submitDelivery({contractId, note, url, filePath}, deps) -> {ok:true, contract, version, resubmission} | refuse`. Route `GET /jobs/:id/contract/history -> {deliveries:[{version,note,url,fileUrl,submittedAt}], extensions:[...], changeRequests:[...]}`.

- [ ] **Step 1: Failing tests.** Create `backend/test/deliveries.test.js`:

```js
// Every delivery is an immutable version; resubmission makes a new one.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;
const changes = require("../src/contractChanges");

let ctx;
before(async () => { ctx = await h.fixtures(); });
after(async () => {
  await prisma.job.deleteMany({ where: { title: { startsWith: h.TITLE_PREFIX } } });
  await prisma.$disconnect();
});

describe("delivery versions", () => {
  it("first delivery: version 1, submitted, 3-day review clock, contract mirrors it", async () => {
    const s = await h.seedWorking(ctx);
    const at = new Date();
    const r = await changes.submitDelivery({ contractId: s.c.id, note: "first cut", url: "https://example.com/a" }, { now: () => at });
    assert.equal(r.ok, true);
    assert.equal(r.version, 1);
    const c = await prisma.contract.findUnique({ where: { id: s.c.id } });
    assert.equal(c.status, "submitted");
    assert.equal(c.reviewDueAt.getTime(), at.getTime() + 3 * h.DAY_MS);
    assert.equal(c.deliverableNote, "first cut");
    const v = await prisma.contractDelivery.findMany({ where: { contractId: s.c.id } });
    assert.deepEqual(v.map((d) => [d.version, d.note, d.url]), [[1, "first cut", "https://example.com/a"]]);
  });

  it("an empty delivery is refused", async () => {
    const s = await h.seedWorking(ctx);
    const r = await changes.submitDelivery({ contractId: s.c.id, note: "   " });
    assert.equal(r.ok, false);
    assert.equal(r.code, "empty_delivery");
  });

  it("can't deliver before starting or after delivering", async () => {
    for (const status of ["funded", "submitted", "approved", "disputed"]) {
      const s = await h.seedWorking(ctx, { status });
      const r = await changes.submitDelivery({ contractId: s.c.id, note: "x" });
      assert.equal(r.code, "not_deliverable", status);
    }
  });

  it("two simultaneous deliveries: exactly one version is recorded", async () => {
    const s = await h.seedWorking(ctx);
    const results = await Promise.all([
      changes.submitDelivery({ contractId: s.c.id, note: "a" }),
      changes.submitDelivery({ contractId: s.c.id, note: "b" }),
    ]);
    assert.equal(results.filter((r) => r.ok).length, 1);
    assert.equal(await prisma.contractDelivery.count({ where: { contractId: s.c.id } }), 1);
  });

  it("resubmission after a change request: version 2, version 1 untouched, round marked resubmitted, review clock restarts", async () => {
    const s = await h.seedSubmitted(ctx, { changeRounds: 1, contract: { status: "changesRequested", reviewDueAt: null, changeDueAt: h.future() } });
    await prisma.changeRequest.create({ data: { contractId: s.c.id, round: 1, reason: "Please fix the colours", resubmitDueAt: h.future() } });
    const at = new Date();
    const r = await changes.submitDelivery({ contractId: s.c.id, note: "v2" }, { now: () => at });
    assert.equal(r.ok, true);
    assert.equal(r.version, 2);
    assert.equal(r.resubmission, true);
    const versions = await prisma.contractDelivery.findMany({ where: { contractId: s.c.id }, orderBy: { version: "asc" } });
    assert.deepEqual(versions.map((d) => d.note), ["v1", "v2"]);
    const c = await prisma.contract.findUnique({ where: { id: s.c.id } });
    assert.equal(c.status, "submitted");
    assert.equal(c.changeDueAt, null);
    assert.equal(c.reviewDueAt.getTime(), at.getTime() + 3 * h.DAY_MS);
    const round = await prisma.changeRequest.findFirst({ where: { contractId: s.c.id, round: 1 } });
    assert.equal(round.resubmittedAt.getTime(), at.getTime());
  });
});
```

Append to `stage2Routes.test.js`:

```js
describe("contract history", () => {
  it("client and awarded talent can read it; anyone else gets 403", async () => {
    const s = await h.seedSubmitted(ctx);
    const path = `/jobs/${s.job.id}/contract/history`;
    const asClient = await h.call(server.base, ct, "GET", path);
    assert.equal(asClient.status, 200);
    assert.deepEqual(asClient.json.deliveries.map((d) => d.version), [1]);
    assert.equal((await h.call(server.base, tt, "GET", path)).status, 200);
    assert.equal((await h.call(server.base, tb, "GET", path)).status, 403);
  });

  it("a talent can resubmit over HTTP from changesRequested", async () => {
    const s = await h.seedSubmitted(ctx, { changeRounds: 1, contract: { status: "changesRequested", reviewDueAt: null, changeDueAt: h.future() } });
    const r = await post(tt, `/jobs/${s.job.id}/contract/submit`, { deliverableNote: "v2" });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.equal(r.json.contract.status, "submitted");
  });
});
```

- [ ] **Step 2: Run, expect failure** (`Cannot find module '../src/contractChanges'`).

- [ ] **Step 3: Create `backend/src/contractChanges.js`:**

```js
// Delivery versions and change rounds — stage 2 of "How a job gets paid"
// (docs/features/stage-2-delivery-and-changes.md). Every delivery is an
// immutable ContractDelivery row; the contract's deliverable* fields only
// mirror the latest one for the apps.
const { RULES, baseDeps, recordEvent, refuse } = require("./contractCore");

const DELIVERABLE_STATUSES = ["inProgress", "changesRequested"];

/**
 * The talent delivers (first time, or after a change request). The status
 * update is the commit point — conditional on the status we read — so two
 * simultaneous deliveries, or a delivery racing the escalation sweep,
 * resolve to exactly one winner.
 */
async function submitDelivery({ contractId, note, url, filePath }, deps) {
  const { prisma, now } = baseDeps(deps);
  const at = now();
  const cleanNote = typeof note === "string" && note.trim() ? note.trim() : null;
  const cleanUrl = typeof url === "string" && url.trim() ? url.trim() : null;
  if (!cleanNote && !cleanUrl && !filePath) {
    return refuse(400, "empty_delivery", "Add a note, a link or a file to deliver.");
  }

  const contract = await prisma.contract.findUnique({ where: { id: contractId } });
  if (!contract) return refuse(404, "not_found", "Contract not found.");
  if (!DELIVERABLE_STATUSES.includes(contract.status)) {
    return refuse(400, "not_deliverable", `Work can't be delivered while the contract is '${contract.status}'.`);
  }
  const resubmission = contract.status === "changesRequested";
  const reviewDueAt = new Date(at.getTime() + RULES.reviewMs);

  const version = await prisma.$transaction(async (trx) => {
    const { count } = await trx.contract.updateMany({
      where: { id: contract.id, status: contract.status },
      data: {
        status: "submitted",
        deliverableNote: cleanNote,
        deliverableUrl: cleanUrl,
        deliverableFilePath: filePath ?? null,
        submittedAt: at,
        reviewDueAt,
        changeDueAt: null,
        autoReleaseAttempts: 0,
        lastAutoReleaseAttemptAt: null,
      },
    });
    if (count === 0) return null;
    const next = (await trx.contractDelivery.count({ where: { contractId: contract.id } })) + 1;
    await trx.contractDelivery.create({
      data: { contractId: contract.id, version: next, note: cleanNote, url: cleanUrl, filePath: filePath ?? null, submittedAt: at },
    });
    if (resubmission) {
      await trx.changeRequest.updateMany({
        where: { contractId: contract.id, round: contract.changeRounds, resubmittedAt: null },
        data: { resubmittedAt: at },
      });
    }
    await recordEvent(trx, {
      jobId: contract.jobId,
      contractId: contract.id,
      type: resubmission ? "resubmitted" : "submitted",
      meta: { version: next, reviewDueAt, hasFile: Boolean(filePath), hasLink: Boolean(cleanUrl) },
    });
    return next;
  });

  console.log(
    `delivery: contract=${contract.id} from=${contract.status} committed=${version !== null} version=${version ?? "-"} reviewDueAt=${reviewDueAt.toISOString()}`,
  );
  if (version === null) return refuse(409, "conflict", "This contract just changed. Refresh and try again.");
  return { ok: true, contract: await prisma.contract.findUnique({ where: { id: contract.id } }), version, resubmission };
}

module.exports = { submitDelivery };
```

- [ ] **Step 4: Wire the routes.** In `jobsRoutes.js` add `const changes = require("../contractChanges");`. Replace the body of the submit route with (keeping `loadContractForJob, requireAwardedTalent`, changing the status gate and keeping `upload.single("file")`):

```js
router.post(
  "/:id/contract/submit",
  loadContractForJob,
  requireAwardedTalent,
  requireContractStatus(["inProgress", "changesRequested"]),
  upload.single("file"),
  async (req, res) => {
    const { deliverableNote, deliverableUrl } = req.body ?? {};
    let filePath = null;
    if (req.file) {
      filePath = await uploadDeliverableFile({
        contractId: req.contract.id,
        buffer: req.file.buffer,
        originalName: req.file.originalname,
        contentType: req.file.mimetype,
      });
    }

    const result = await changes.submitDelivery({ contractId: req.contract.id, note: deliverableNote, url: deliverableUrl, filePath });
    if (!result.ok) return res.status(result.status).json({ error: result.error });

    // Tell the client what was delivered and exactly how long they have.
    const client = await prisma.user.findUnique({ where: { id: req.job.clientId } });
    if (client) {
      mailer
        .sendDeliveryAwaitingReview({
          to: client.email,
          jobTitle: req.job.title,
          reviewDueAt: result.contract.reviewDueAt,
          autoRelease: lifecycle.autoReleaseEnabled(),
          version: result.version,
        })
        .catch((err) => console.error("submit: failed to email the client:", err));
    }

    return res.json({ contract: await serializeContract(result.contract) });
  },
);
```

Add, after `requireAwardedTalent`:

```js
/** The job's client or its awarded talent — nobody else sees a contract's history. */
async function requireParty(req, res, next) {
  if (req.job.clientId === req.user.id) return next();
  const application = req.job.awardedApplicationId
    ? await prisma.application.findUnique({ where: { id: req.job.awardedApplicationId } })
    : null;
  if (application?.talentId === req.user.id) return next();
  return res.status(403).json({ error: "Only the client and the awarded talent can see this contract's history." });
}
```

and the route (before `module.exports`):

```js
/** Every delivery version, extension request and change round, oldest first. */
router.get("/:id/contract/history", loadContractForJob, requireParty, async (req, res) => {
  const contractId = req.contract.id;
  const [deliveries, extensions, changeRequests] = await Promise.all([
    prisma.contractDelivery.findMany({ where: { contractId }, orderBy: { version: "asc" } }),
    prisma.contractExtension.findMany({ where: { contractId }, orderBy: { requestedAt: "asc" } }),
    prisma.changeRequest.findMany({ where: { contractId }, orderBy: { round: "asc" } }),
  ]);
  return res.json({
    deliveries: await Promise.all(
      deliveries.map(async (d) => ({
        version: d.version,
        note: d.note,
        url: d.url,
        fileUrl: d.filePath ? await getDeliverableFileSignedUrl(d.filePath) : null,
        submittedAt: d.submittedAt,
      })),
    ),
    extensions: extensions.map(serializeExtension),
    changeRequests: changeRequests.map((c) => ({
      round: c.round,
      reason: c.reason,
      requestedAt: c.requestedAt,
      resubmitDueAt: c.resubmitDueAt,
      resubmittedAt: c.resubmittedAt,
    })),
  });
});
```

with, next to `serializeApplication`:

```js
function serializeExtension(e) {
  return {
    id: e.id,
    requestedDays: e.requestedDays,
    reason: e.reason,
    status: e.status,
    requestedAt: e.requestedAt,
    answerDueAt: e.answerDueAt,
    resolvedAt: e.resolvedAt,
  };
}
```

In `mailer.js`, change `sendDeliveryAwaitingReview` to take `version` and use, as the subject, `version > 1 ? \`Revised work delivered on "${jobTitle}" (version ${version}): please review\` : \`Work delivered on "${jobTitle}": please review\``.

- [ ] **Step 5: Run.** `npm test` → all pass.
- [ ] **Step 6: Review and commit** (`Stage 2: immutable delivery versions and resubmission`).

---

### Task 3: Extensions and the 48-hour auto-grant

**Files:**
- Create: `backend/src/contractExtensions.js`
- Modify: `backend/src/contractChanges.js` (withdraw a pending extension on delivery)
- Modify: `backend/src/contractLifecycle.js` (tick calls `sweepExtensions`)
- Modify: `backend/src/user/jobsRoutes.js` (2 routes), `backend/src/admin/mailer.js` (3 templates)
- Create: `backend/test/extensions.test.js`; Modify: `backend/test/stage2Routes.test.js`

**Interfaces:**
- Consumes: `contractCore`; `serializeExtension` (Task 2).
- Produces: `requestExtension({contractId, days, reason}, deps) -> {ok, extension} | refuse`; `answerExtension({contractId, extensionId, clientId, grant}, deps) -> {ok, deliverByAt, contract} | refuse`; `sweepExtensions(deps) -> {autoGranted}`; mailer `sendExtensionRequested`, `sendExtensionAnswered({to, jobTitle, outcome: 'granted'|'declined'|'autoGranted', deliverByAt})`, `sendExtensionAutoGrantedToClient`. In lifecycle: `STAGE2_SWEEPS` array of `[name, fn]`.

- [ ] **Step 1: Failing tests.** Create `backend/test/extensions.test.js`:

```js
// Extensions: up to 2 requests (a declined one counts), one open at a time,
// up to the job's original duration, 48 h to answer, silence = granted.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;
const ext = require("../src/contractExtensions");
const changes = require("../src/contractChanges");
const life = require("../src/contractLifecycle");

const REASON = "The client changed the brief on day 2.";
let ctx;
before(async () => { ctx = await h.fixtures(); });
after(async () => {
  await prisma.job.deleteMany({ where: { title: { startsWith: h.TITLE_PREFIX } } });
  await prisma.$disconnect();
});
const contractOf = (s) => prisma.contract.findUnique({ where: { id: s.c.id } });

describe("requesting an extension", () => {
  it("valid request: pending, counted, 48 h to answer, client emailed", async () => {
    const s = await h.seedWorking(ctx, { deliveryDays: 5 });
    const mailer = h.spyMailer();
    const at = new Date();
    const r = await ext.requestExtension({ contractId: s.c.id, days: 3, reason: REASON }, { mailer, now: () => at });
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.equal(r.extension.status, "pending");
    assert.equal(r.extension.answerDueAt.getTime(), at.getTime() + 48 * 3_600_000);
    assert.equal((await contractOf(s)).extensionsUsed, 1);
    assert.deepEqual(mailer.sent.map((m) => [m.k, m.to]), [["sendExtensionRequested", ctx.client.email]]);
  });

  it("days must be 1 to the job's original duration; a reason is required", async () => {
    const s = await h.seedWorking(ctx, { deliveryDays: 5 });
    for (const days of [0, 6, 2.5, NaN]) {
      assert.equal((await ext.requestExtension({ contractId: s.c.id, days, reason: REASON }, { mailer: h.spyMailer() })).code, "bad_days", String(days));
    }
    assert.equal((await ext.requestExtension({ contractId: s.c.id, days: 2, reason: "short" }, { mailer: h.spyMailer() })).code, "bad_reason");
    assert.equal((await contractOf(s)).extensionsUsed, 0, "refused requests don't count");
  });

  it("only one open at a time", async () => {
    const s = await h.seedWorking(ctx);
    await ext.requestExtension({ contractId: s.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() });
    assert.equal((await ext.requestExtension({ contractId: s.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() })).code, "already_pending");
  });

  it("two requests at the same instant: exactly one is created", async () => {
    const s = await h.seedWorking(ctx);
    const rs = await Promise.all([1, 2].map((days) => ext.requestExtension({ contractId: s.c.id, days, reason: REASON }, { mailer: h.spyMailer() })));
    assert.equal(rs.filter((r) => r.ok).length, 1);
    assert.equal(await prisma.contractExtension.count({ where: { contractId: s.c.id } }), 1);
    assert.equal((await contractOf(s)).extensionsUsed, 1);
  });

  it("a declined request counts: after 2 requests there are none left", async () => {
    const s = await h.seedWorking(ctx);
    for (let i = 0; i < 2; i++) {
      const r = await ext.requestExtension({ contractId: s.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() });
      await ext.answerExtension({ contractId: s.c.id, extensionId: r.extension.id, clientId: ctx.client.id, grant: false }, { mailer: h.spyMailer() });
    }
    assert.equal((await ext.requestExtension({ contractId: s.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() })).code, "no_requests_left");
  });

  it("refused after delivery, on a legacy job, and 3+ days past the date", async () => {
    const delivered = await h.seedSubmitted(ctx);
    assert.equal((await ext.requestExtension({ contractId: delivered.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() })).code, "not_open");
    const legacy = await h.seedAward(ctx, { contract: { status: "inProgress", payByAt: null } });
    assert.equal((await ext.requestExtension({ contractId: legacy.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() })).code, "no_delivery_date");
    const late = await h.seedWorking(ctx, { deliverByAt: h.past(3 * h.DAY_MS + 60_000) });
    assert.equal((await ext.requestExtension({ contractId: late.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() })).code, "too_late");
  });
});

describe("answering", () => {
  const open = async (days = 3) => {
    const s = await h.seedWorking(ctx, { deliveryDays: 5 });
    const r = await ext.requestExtension({ contractId: s.c.id, days, reason: REASON }, { mailer: h.spyMailer() });
    return { s, e: r.extension, before: (await contractOf(s)).deliverByAt };
  };

  it("grant: the days are added to the delivery date and the talent is told", async () => {
    const { s, e, before } = await open(3);
    const mailer = h.spyMailer();
    const r = await ext.answerExtension({ contractId: s.c.id, extensionId: e.id, clientId: ctx.client.id, grant: true }, { mailer });
    assert.equal(r.ok, true);
    assert.equal((await contractOf(s)).deliverByAt.getTime(), before.getTime() + 3 * h.DAY_MS);
    assert.deepEqual(mailer.sent.map((m) => [m.k, m.args.outcome]), [["sendExtensionAnswered", "granted"]]);
  });

  it("decline: the date stays", async () => {
    const { s, e, before } = await open();
    await ext.answerExtension({ contractId: s.c.id, extensionId: e.id, clientId: ctx.client.id, grant: false }, { mailer: h.spyMailer() });
    assert.equal((await contractOf(s)).deliverByAt.getTime(), before.getTime());
  });

  it("answering twice: the second is refused", async () => {
    const { s, e } = await open();
    await ext.answerExtension({ contractId: s.c.id, extensionId: e.id, clientId: ctx.client.id, grant: false }, { mailer: h.spyMailer() });
    const again = await ext.answerExtension({ contractId: s.c.id, extensionId: e.id, clientId: ctx.client.id, grant: true }, { mailer: h.spyMailer() });
    assert.equal(again.code, "already_answered");
  });

  it("an extension id from another contract is not found", async () => {
    const a = await open();
    const b = await h.seedWorking(ctx);
    assert.equal((await ext.answerExtension({ contractId: b.c.id, extensionId: a.e.id, clientId: ctx.client.id, grant: true })).code, "not_found");
  });

  it("a grant that moves the date clears the overdue flag", async () => {
    const s = await h.seedWorking(ctx, { deliveryDays: 5, deliverByAt: h.past(2 * h.DAY_MS), contract: { overdueFlaggedAt: new Date() } });
    const r = await ext.requestExtension({ contractId: s.c.id, days: 5, reason: REASON }, { mailer: h.spyMailer() });
    assert.equal(r.code, "too_late", "flagged contracts can't ask");
    // Flag set by hand on a contract that asked before the flag (the race the pending-pause prevents):
    await prisma.contract.update({ where: { id: s.c.id }, data: { overdueFlaggedAt: null } });
    const ok = await ext.requestExtension({ contractId: s.c.id, days: 5, reason: REASON }, { mailer: h.spyMailer() });
    await prisma.contract.update({ where: { id: s.c.id }, data: { overdueFlaggedAt: new Date() } });
    await ext.answerExtension({ contractId: s.c.id, extensionId: ok.extension.id, clientId: ctx.client.id, grant: true }, { mailer: h.spyMailer() });
    assert.equal((await contractOf(s)).overdueFlaggedAt, null);
  });

  it("delivering withdraws an open request", async () => {
    const { s, e } = await open();
    await changes.submitDelivery({ contractId: s.c.id, note: "done early" });
    assert.equal((await prisma.contractExtension.findUnique({ where: { id: e.id } })).status, "withdrawn");
  });
});

describe("48-hour auto-grant", () => {
  it("unanswered after 48 h: granted, date moved, both told; a second sweep does nothing", async () => {
    const s = await h.seedWorking(ctx, { deliveryDays: 5 });
    const r = await ext.requestExtension({ contractId: s.c.id, days: 2, reason: REASON }, { mailer: h.spyMailer() });
    const before = (await contractOf(s)).deliverByAt;
    const later = () => new Date(r.extension.answerDueAt.getTime() + 60_000);
    const mailer = h.spyMailer();
    const deps = { prisma: h.scopedPrisma(), mailer, now: later };
    assert.deepEqual(await ext.sweepExtensions(deps), { autoGranted: 1 });
    assert.equal((await prisma.contractExtension.findUnique({ where: { id: r.extension.id } })).status, "autoGranted");
    assert.equal((await contractOf(s)).deliverByAt.getTime(), before.getTime() + 2 * h.DAY_MS);
    assert.deepEqual(mailer.sent.map((m) => m.k).sort(), ["sendExtensionAnswered", "sendExtensionAutoGrantedToClient"]);
    assert.deepEqual(await ext.sweepExtensions(deps), { autoGranted: 0 });
  });

  it("not yet 48 h: untouched", async () => {
    const s = await h.seedWorking(ctx);
    const r = await ext.requestExtension({ contractId: s.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() });
    await ext.sweepExtensions({ prisma: h.scopedPrisma(), mailer: h.spyMailer() });
    assert.equal((await prisma.contractExtension.findUnique({ where: { id: r.extension.id } })).status, "pending");
  });

  it("the client answers after 48 h but before the tick: their answer stands", async () => {
    const s = await h.seedWorking(ctx);
    const r = await ext.requestExtension({ contractId: s.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() });
    const later = () => new Date(r.extension.answerDueAt.getTime() + 60_000);
    await ext.answerExtension({ contractId: s.c.id, extensionId: r.extension.id, clientId: ctx.client.id, grant: false }, { mailer: h.spyMailer(), now: later });
    await ext.sweepExtensions({ prisma: h.scopedPrisma(), mailer: h.spyMailer(), now: later });
    assert.equal((await prisma.contractExtension.findUnique({ where: { id: r.extension.id } })).status, "declined");
  });

  it("the 5-minute tick runs the auto-grant", async () => {
    const s = await h.seedWorking(ctx);
    const r = await ext.requestExtension({ contractId: s.c.id, days: 1, reason: REASON }, { mailer: h.spyMailer() });
    await life.runTick({ prisma: h.scopedPrisma(), mailer: h.spyMailer(), paystack: h.fakeProvider(), autoRelease: false, now: () => new Date(r.extension.answerDueAt.getTime() + 1) });
    assert.equal((await prisma.contractExtension.findUnique({ where: { id: r.extension.id } })).status, "autoGranted");
  });
});
```

Append to `stage2Routes.test.js`:

```js
describe("extension routes", () => {
  it("talent asks (201), other talent can't (403), client can't ask (403); client answers (200), talent can't answer (403)", async () => {
    const s = await h.seedWorking(ctx, { deliveryDays: 5 });
    const ask = (tok) => post(tok, `/jobs/${s.job.id}/contract/extension`, { days: 2, reason: "Waiting on the client's assets." });
    assert.equal((await ask(tb)).status, 403);
    assert.equal((await ask(ct)).status, 403);
    const asked = await ask(tt);
    assert.equal(asked.status, 201, JSON.stringify(asked.json));
    const answer = (tok, decision) => post(tok, `/jobs/${s.job.id}/contract/extension/${asked.json.extension.id}/answer`, { decision });
    assert.equal((await answer(tt, "grant")).status, 403);
    assert.equal((await answer(ct, "maybe")).status, 400);
    const granted = await answer(ct, "grant");
    assert.equal(granted.status, 200, JSON.stringify(granted.json));
    assert.ok(granted.json.contract.deliverByAt);
  });
});
```

- [ ] **Step 2: Run, expect failure** (module missing).

- [ ] **Step 3: Create `backend/src/contractExtensions.js`:**

```js
// The delivery date — extensions (stage 2 of "How a job gets paid") and the
// overdue flag. Decided 2026-10-01: a talent may make 2 requests (a declined
// one counts), one open at a time, each up to the job's original duration;
// the client has 48 h to answer and silence grants it (as on Fiverr).
const { DAY, RULES, baseDeps, recordEvent, refuse, validReason, parties } = require("./contractCore");

const OPEN_STATUSES = ["funded", "inProgress"];

async function requestExtension({ contractId, days, reason }, deps) {
  const { prisma, mailer, now } = baseDeps(deps);
  const at = now();
  const contract = await prisma.contract.findUnique({ where: { id: contractId }, include: { job: true } });
  if (!contract) return refuse(404, "not_found", "Contract not found.");
  if (!OPEN_STATUSES.includes(contract.status)) {
    return refuse(400, "not_open", "Extensions can only be requested before the work is delivered.");
  }
  if (!contract.deliverByAt || !contract.job.deliveryDays) {
    return refuse(400, "no_delivery_date", "This job has no delivery date to extend.");
  }
  if (contract.overdueFlaggedAt || at.getTime() >= contract.deliverByAt.getTime() + RULES.overdueGraceMs) {
    return refuse(400, "too_late", "It's more than 3 days past the delivery date, so an extension can no longer be requested.");
  }
  if (!Number.isInteger(days) || days < 1 || days > contract.job.deliveryDays) {
    return refuse(400, "bad_days", `Ask for 1 to ${contract.job.deliveryDays} extra days (up to the job's original duration).`);
  }
  if (!validReason(reason)) {
    return refuse(400, "bad_reason", `Explain the delay in ${RULES.reasonLength.min} to ${RULES.reasonLength.max} characters.`);
  }
  if (contract.extensionsUsed >= RULES.maxExtensionRequests) {
    return refuse(400, "no_requests_left", "You've used both extension requests on this job.");
  }
  if (await prisma.contractExtension.findFirst({ where: { contractId, status: "pending" } })) {
    return refuse(409, "already_pending", "An extension request is already waiting for the client's answer.");
  }

  const answerDueAt = new Date(at.getTime() + RULES.extensionAnswerMs);
  const extension = await prisma.$transaction(async (trx) => {
    // Compare-and-swap on the request count: two simultaneous requests read
    // the same count, and only one of them can move it.
    const { count } = await trx.contract.updateMany({
      where: { id: contract.id, extensionsUsed: contract.extensionsUsed, status: { in: OPEN_STATUSES } },
      data: { extensionsUsed: { increment: 1 } },
    });
    if (count === 0) return null;
    const created = await trx.contractExtension.create({
      data: { contractId: contract.id, requestedDays: days, reason: reason.trim(), requestedAt: at, answerDueAt },
    });
    await recordEvent(trx, {
      jobId: contract.jobId,
      contractId: contract.id,
      type: "extension_requested",
      meta: { extensionId: created.id, days, answerDueAt, deliverByAt: contract.deliverByAt },
    });
    return created;
  });
  console.log(
    `extension: request contract=${contract.id} days=${days} usedBefore=${contract.extensionsUsed} committed=${Boolean(extension)}`,
  );
  if (!extension) return refuse(409, "conflict", "This contract just changed. Refresh and try again.");

  const { client } = await parties(prisma, contract);
  if (client) {
    mailer
      .sendExtensionRequested({
        to: client.email,
        jobTitle: contract.job.title,
        days,
        reason: extension.reason,
        proposedDeliverBy: new Date(contract.deliverByAt.getTime() + days * DAY),
        answerDueAt,
      })
      .catch((err) => console.error("extension: failed to email the client:", err));
  }
  return { ok: true, extension };
}

/** Adds the extension's days to the delivery date; clears an overdue flag the new date makes stale. */
async function applyGrant(trx, extension, at) {
  const contract = await trx.contract.findUnique({ where: { id: extension.contractId } });
  const deliverByAt = new Date(contract.deliverByAt.getTime() + extension.requestedDays * DAY);
  const stillOverdue = deliverByAt.getTime() + RULES.overdueGraceMs <= at.getTime();
  await trx.contract.update({
    where: { id: contract.id },
    data: { deliverByAt, overdueFlaggedAt: stillOverdue ? contract.overdueFlaggedAt : null },
  });
  return deliverByAt;
}

/**
 * The client grants or declines. No time check: an answer that reaches the
 * server before the tick has auto-granted stands, even a little past 48 h.
 */
async function answerExtension({ contractId, extensionId, clientId, grant }, deps) {
  const { prisma, mailer, now } = baseDeps(deps);
  const at = now();
  const extension = await prisma.contractExtension.findUnique({
    where: { id: extensionId },
    include: { contract: { include: { job: true } } },
  });
  if (!extension || extension.contractId !== contractId) return refuse(404, "not_found", "Extension request not found.");

  const deliverByAt = await prisma.$transaction(async (trx) => {
    const { count } = await trx.contractExtension.updateMany({
      where: { id: extension.id, status: "pending" },
      data: { status: grant ? "granted" : "declined", resolvedAt: at, resolvedById: clientId },
    });
    if (count === 0) return null;
    const date = grant ? await applyGrant(trx, extension, at) : extension.contract.deliverByAt;
    await recordEvent(trx, {
      jobId: extension.contract.jobId,
      contractId,
      type: grant ? "extension_granted" : "extension_declined",
      meta: { extensionId, deliverByAt: date },
    });
    return date;
  });
  console.log(`extension: answer ${extensionId} contract=${contractId} grant=${grant} committed=${Boolean(deliverByAt)}`);
  if (!deliverByAt) {
    return refuse(409, "already_answered", "That request has already been answered (it may have been granted automatically after 48 hours).");
  }

  const { talent } = await parties(prisma, extension.contract);
  if (talent) {
    mailer
      .sendExtensionAnswered({ to: talent.email, jobTitle: extension.contract.job.title, outcome: grant ? "granted" : "declined", deliverByAt })
      .catch((err) => console.error("extension: failed to email the talent:", err));
  }
  return { ok: true, deliverByAt, contract: await prisma.contract.findUnique({ where: { id: contractId } }) };
}

/** Tick: grant every request the client left unanswered for 48 h. */
async function sweepExtensions(deps) {
  const { prisma, mailer, now } = baseDeps(deps);
  const at = now();
  const due = await prisma.contract.findMany({
    where: { extensions: { some: { status: "pending", answerDueAt: { lte: at } } } },
    select: { id: true },
  });
  let autoGranted = 0;
  for (const { id } of due) {
    const extension = await prisma.contractExtension.findFirst({
      where: { contractId: id, status: "pending", answerDueAt: { lte: at } },
      include: { contract: { include: { job: true } } },
    });
    if (!extension) continue;
    const deliverByAt = await prisma.$transaction(async (trx) => {
      const { count } = await trx.contractExtension.updateMany({
        where: { id: extension.id, status: "pending" },
        data: { status: "autoGranted", resolvedAt: at },
      });
      if (count === 0) return null;
      const date = await applyGrant(trx, extension, at);
      await recordEvent(trx, {
        jobId: extension.contract.jobId,
        contractId: id,
        type: "extension_auto_granted",
        meta: { extensionId: extension.id, answerDueAt: extension.answerDueAt, deliverByAt: date },
      });
      return date;
    });
    console.log(
      `extension: auto-grant ${extension.id} contract=${id} answerDueAt=${extension.answerDueAt.toISOString()} now=${at.toISOString()} committed=${Boolean(deliverByAt)}`,
    );
    if (!deliverByAt) continue;
    autoGranted++;
    const { client, talent } = await parties(prisma, extension.contract);
    const jobTitle = extension.contract.job.title;
    await Promise.allSettled([
      talent ? mailer.sendExtensionAnswered({ to: talent.email, jobTitle, outcome: "autoGranted", deliverByAt }) : null,
      client ? mailer.sendExtensionAutoGrantedToClient({ to: client.email, jobTitle, deliverByAt }) : null,
    ]);
  }
  return { autoGranted };
}

module.exports = { requestExtension, answerExtension, sweepExtensions };
```

- [ ] **Step 4: Withdraw on delivery.** In `contractChanges.js` `submitDelivery`, inside the transaction after `contractDelivery.create`, add:

```js
    // Delivering makes an open extension request moot.
    await trx.contractExtension.updateMany({
      where: { contractId: contract.id, status: "pending" },
      data: { status: "withdrawn", resolvedAt: at },
    });
```

- [ ] **Step 5: Tick.** In `contractLifecycle.js` add `const extensions = require("./contractExtensions");` and, above `runTick`:

```js
// Stage 2 sweeps, run after the stage 1 work on every tick. Each starts from
// prisma.contract.findMany, so a test can scope a whole tick to its own rows.
const STAGE2_SWEEPS = [["extensions", (deps) => extensions.sweepExtensions(deps)]];
```

Inside `runTick`'s `try`, after the auto-release block and before the summary log:

```js
    for (const [name, sweep] of STAGE2_SWEEPS) {
      try {
        Object.assign(summary, await sweep(deps));
      } catch (err) {
        console.error(`tick: ${name} sweep failed:`, err);
      }
    }
```

and change the log condition to `if (Object.values(summary).some(Boolean))`.

- [ ] **Step 6: Routes.** In `jobsRoutes.js` add `const extensions = require("../contractExtensions");` and:

```js
router.post("/:id/contract/extension", loadContractForJob, requireAwardedTalent, async (req, res) => {
  const result = await extensions.requestExtension({
    contractId: req.contract.id,
    days: Number(req.body?.days),
    reason: req.body?.reason,
  });
  if (!result.ok) return res.status(result.status).json({ error: result.error });
  return res.status(201).json({ extension: serializeExtension(result.extension) });
});

router.post("/:id/contract/extension/:extensionId/answer", loadContractForJob, requireClient, async (req, res) => {
  if (req.job.clientId !== req.user.id) return res.status(403).json({ error: "Not your job." });
  const decision = req.body?.decision;
  if (decision !== "grant" && decision !== "decline") {
    return res.status(400).json({ error: "decision must be 'grant' or 'decline'." });
  }
  const result = await extensions.answerExtension({
    contractId: req.contract.id,
    extensionId: req.params.extensionId,
    clientId: req.user.id,
    grant: decision === "grant",
  });
  if (!result.ok) return res.status(result.status).json({ error: result.error });
  return res.json({ contract: await serializeContract(result.contract) });
});
```

- [ ] **Step 7: Mailer.** Add to `mailer.js` (and to `module.exports`):

```js
/** The talent asked for more time; silence for 48 h grants it. */
function sendExtensionRequested({ to, jobTitle, days, reason, proposedDeliverBy, answerDueAt }) {
  return send({
    to,
    subject: `Extension requested on "${jobTitle}"`,
    html: `
      <p>The talent working on <strong>${escapeHtml(jobTitle)}</strong> has asked for ${days} more day${days === 1 ? "" : "s"}, which would move the delivery date to <strong>${formatWAT(proposedDeliverBy)}</strong>.</p>
      <p>Their reason: "${escapeHtml(reason)}"</p>
      <p>Please grant or decline it in the app by <strong>${formatWAT(answerDueAt)}</strong>. If you don't answer by then, it is granted automatically.</p>
    `,
    fallbackContext: `extension requested for ${to}: ${jobTitle}`,
  });
}

const EXTENSION_OUTCOMES = {
  granted: (date) => `The client granted your extension. The new delivery date is <strong>${formatWAT(date)}</strong>.`,
  autoGranted: (date) => `The client didn't answer within 48 hours, so your extension was granted automatically. The new delivery date is <strong>${formatWAT(date)}</strong>.`,
  declined: (date) => `The client declined your extension. The delivery date stays <strong>${formatWAT(date)}</strong>.`,
};

function sendExtensionAnswered({ to, jobTitle, outcome, deliverByAt }) {
  return send({
    to,
    subject: outcome === "declined" ? `Extension declined on "${jobTitle}"` : `Extension granted on "${jobTitle}"`,
    html: `<p><strong>${escapeHtml(jobTitle)}</strong>: ${EXTENSION_OUTCOMES[outcome](deliverByAt)}</p>`,
    fallbackContext: `extension ${outcome} for ${to}: ${jobTitle}`,
  });
}

function sendExtensionAutoGrantedToClient({ to, jobTitle, deliverByAt }) {
  return send({
    to,
    subject: `Extension granted on "${jobTitle}"`,
    html: `<p>You didn't answer the talent's extension request on <strong>${escapeHtml(jobTitle)}</strong> within 48 hours, so it was granted automatically, as agreed. The new delivery date is <strong>${formatWAT(deliverByAt)}</strong>.</p>`,
    fallbackContext: `extension auto-granted (client) for ${to}: ${jobTitle}`,
  });
}
```

- [ ] **Step 8: Run** `npm test` → all pass.
- [ ] **Step 9: Deliberate breakage check.** Temporarily delete `extensionsUsed: contract.extensionsUsed,` from the compare-and-swap `where` and run `node --env-file-if-exists=.env.test --test --test-name-pattern="same instant" test/extensions.test.js` → expect FAIL. Restore, re-run → PASS. Record in testing.md (Task 7).
- [ ] **Step 10: Review and commit** (`Stage 2: extension requests with a 48-hour auto-grant`).

---

### Task 4: Change rounds, escalation, and the release claim

**Files:**
- Modify: `backend/src/contractChanges.js` (`requestChanges`, `escalateContract`, `sweepChanges`)
- Modify: `backend/src/contractLifecycle.js` (release claim in `releasePayment`; `autoReleaseOne` treats a lost race as superseded; sweep registered)
- Modify: `backend/src/user/jobsRoutes.js` (route), `backend/src/admin/mailer.js` (3 templates)
- Create: `backend/test/changes.test.js`; Modify: `backend/test/stage2Routes.test.js`

**Interfaces:**
- Produces: `requestChanges({contractId, clientId, reason}, deps) -> {ok, escalated, contract} | refuse`; `escalateContract(prisma, mailer, {contract, from, reason, note?, by?, at}) -> {ok, escalated:true, contract} | refuse`; `sweepChanges(deps) -> {escalated}`. Escalation reasons: `client_rejected_after_final_round`, `talent_missed_change_deadline`. Mailer: `sendChangesRequested`, `sendEscalated({to, jobTitle, reason})`, `sendEscalationToAdmin({to, jobTitle, contractId, reason, note})`.

- [ ] **Step 1: Failing tests.** Create `backend/test/changes.test.js`:

```js
// Change rounds: at most 2, each with a 3-day resubmit clock; still
// unresolved after round 2, or the talent misses the clock -> an admin.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;
const changes = require("../src/contractChanges");
const life = require("../src/contractLifecycle");

const WHY = "The logo colours don't match the brand guide.";
let ctx;
before(async () => { ctx = await h.fixtures(); });
after(async () => {
  await prisma.job.deleteMany({ where: { title: { startsWith: h.TITLE_PREFIX } } });
  await prisma.$disconnect();
});
const contractOf = (s) => prisma.contract.findUnique({ where: { id: s.c.id } });
const ask = (s, deps = {}) => changes.requestChanges({ contractId: s.c.id, clientId: ctx.client.id, reason: WHY }, { mailer: h.spyMailer(), ...deps });

describe("requesting changes", () => {
  it("round 1: changesRequested, 3-day resubmit clock, review clock stopped, talent emailed with the reason", async () => {
    const s = await h.seedSubmitted(ctx);
    const mailer = h.spyMailer();
    const at = new Date();
    const r = await ask(s, { mailer, now: () => at });
    assert.equal(r.ok, true);
    assert.equal(r.escalated, false);
    const c = await contractOf(s);
    assert.equal(c.status, "changesRequested");
    assert.equal(c.changeRounds, 1);
    assert.equal(c.changeDueAt.getTime(), at.getTime() + 3 * h.DAY_MS);
    assert.equal(c.reviewDueAt, null);
    const round = await prisma.changeRequest.findFirst({ where: { contractId: s.c.id } });
    assert.equal(round.reason, WHY);
    assert.deepEqual(mailer.sent.map((m) => [m.k, m.to, m.args.round]), [["sendChangesRequested", ctx.talentA.email, 1]]);
  });

  it("a reason is required; only delivered work can be sent back", async () => {
    const s = await h.seedSubmitted(ctx);
    assert.equal((await changes.requestChanges({ contractId: s.c.id, clientId: ctx.client.id, reason: "no" })).code, "bad_reason");
    const w = await h.seedWorking(ctx);
    assert.equal((await ask(w)).code, "not_submitted");
  });

  it("two requests at the same instant: one round", async () => {
    const s = await h.seedSubmitted(ctx);
    const rs = await Promise.all([ask(s), ask(s)]);
    assert.equal(rs.filter((r) => r.ok).length, 1);
    assert.equal(await prisma.changeRequest.count({ where: { contractId: s.c.id } }), 1);
  });

  it("full cycle: round 1, resubmit, round 2, resubmit, still unhappy -> escalated to an admin, no round 3", async () => {
    const s = await h.seedSubmitted(ctx);
    for (let round = 1; round <= 2; round++) {
      assert.equal((await ask(s)).ok, true, `round ${round}`);
      assert.equal((await changes.submitDelivery({ contractId: s.c.id, note: `v${round + 1}` })).ok, true);
    }
    const mailer = h.spyMailer();
    const r = await ask(s, { mailer });
    assert.equal(r.escalated, true);
    assert.equal((await contractOf(s)).status, "disputed");
    assert.equal(await prisma.changeRequest.count({ where: { contractId: s.c.id } }), 2);
    const ev = await prisma.contractEvent.findFirst({ where: { contractId: s.c.id, type: "escalated" } });
    assert.equal(ev.meta.reason, "client_rejected_after_final_round");
    assert.equal(ev.meta.note, WHY);
    assert.ok(mailer.sent.filter((m) => m.k === "sendEscalated").length === 2, "client and talent told");
  });
});

describe("the talent's 3-day resubmit clock", () => {
  const sentBack = async () => {
    const s = await h.seedSubmitted(ctx);
    await ask(s);
    return { s, due: (await contractOf(s)).changeDueAt };
  };

  it("missed: escalated to an admin", async () => {
    const { s, due } = await sentBack();
    const r = await changes.sweepChanges({ prisma: h.scopedPrisma(), mailer: h.spyMailer(), now: () => new Date(due.getTime() + 1) });
    assert.deepEqual(r, { escalated: 1 });
    assert.equal((await contractOf(s)).status, "disputed");
    const ev = await prisma.contractEvent.findFirst({ where: { contractId: s.c.id, type: "escalated" } });
    assert.equal(ev.meta.reason, "talent_missed_change_deadline");
  });

  it("not yet due: untouched", async () => {
    const { s } = await sentBack();
    await changes.sweepChanges({ prisma: h.scopedPrisma(), mailer: h.spyMailer() });
    assert.equal((await contractOf(s)).status, "changesRequested");
  });

  it("resubmitted a little late but before the tick: the resubmission stands", async () => {
    const { s, due } = await sentBack();
    const late = () => new Date(due.getTime() + 60_000);
    assert.equal((await changes.submitDelivery({ contractId: s.c.id, note: "v2" }, { now: late })).ok, true);
    await changes.sweepChanges({ prisma: h.scopedPrisma(), mailer: h.spyMailer(), now: late });
    assert.equal((await contractOf(s)).status, "submitted");
  });

  it("the tick runs it", async () => {
    const { s, due } = await sentBack();
    await life.runTick({ prisma: h.scopedPrisma(), mailer: h.spyMailer(), paystack: h.fakeProvider(), autoRelease: false, now: () => new Date(due.getTime() + 1) });
    assert.equal((await contractOf(s)).status, "disputed");
  });
});

describe("money and change requests never cross", () => {
  it("a disputed contract is never auto-released", async () => {
    const s = await h.seedSubmitted(ctx, { contract: { status: "disputed", reviewDueAt: h.past() } });
    const pay = h.fakeProvider();
    await life.runTick({ prisma: h.scopedPrisma(), mailer: h.spyMailer(), paystack: pay, autoRelease: true });
    assert.equal(pay.payouts.length, 0);
    assert.equal((await contractOf(s)).status, "disputed");
  });

  it("client taps Request changes while a payout is in flight: refused, and the contract ends approved with the money sent", async () => {
    const s = await h.seedSubmitted(ctx);
    const pay = h.fakeProvider();
    let releaseTransfer;
    const gate = new Promise((resolve) => (releaseTransfer = resolve));
    const realInitiate = pay.initiateTransfer;
    pay.initiateTransfer = async (args) => { await gate; return realInitiate(args); };
    const releasing = life.releasePayment({ contractId: s.c.id, trigger: "client_approved" }, { paystack: pay, mailer: h.spyMailer() });
    for (let i = 0; i < 50 && !(await contractOf(s)).releaseClaimedAt; i++) await new Promise((r) => setTimeout(r, 50));
    const r = await ask(s);
    releaseTransfer();
    const released = await releasing;
    assert.equal(r.ok, false);
    assert.equal(r.code, "conflict");
    assert.equal(released.ok, true);
    assert.equal((await contractOf(s)).status, "approved");
    assert.equal(pay.payouts.length, 1);
  });

  it("a failed payout releases the claim so the client can still ask for changes", async () => {
    const s = await h.seedSubmitted(ctx);
    const r = await life.releasePayment({ contractId: s.c.id, trigger: "client_approved" }, { paystack: h.fakeProvider({ refusePayouts: true }), mailer: h.spyMailer() });
    assert.equal(r.ok, false);
    assert.equal((await contractOf(s)).releaseClaimedAt, null);
    assert.equal((await ask(s)).ok, true);
  });
});
```

Append to `stage2Routes.test.js`:

```js
describe("request-changes route", () => {
  it("only the job's client; talent 403", async () => {
    const s = await h.seedSubmitted(ctx);
    const path = `/jobs/${s.job.id}/contract/request-changes`;
    assert.equal((await post(tt, path, { reason: "Please change the font." })).status, 403);
    const r = await post(ct, path, { reason: "Please change the font." });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.equal(r.json.contract.status, "changesRequested");
    assert.equal(r.json.escalated, false);
  });
});
```

- [ ] **Step 2: Run, expect failures** (`requestChanges is not a function`, no `releaseClaimedAt` set).

- [ ] **Step 3: Implement in `contractChanges.js`.** Extend the import to `const { RULES, baseDeps, recordEvent, refuse, validReason, parties } = require("./contractCore");` and add:

```js
/**
 * The client sends delivered work back. After the last round there is no
 * further round: the same action escalates to an admin. Conditional on no
 * payout being in flight (releaseClaimedAt), so changes can never be
 * requested on work whose payment has already left.
 */
async function requestChanges({ contractId, clientId, reason }, deps) {
  const { prisma, mailer, now } = baseDeps(deps);
  const at = now();
  if (!validReason(reason)) {
    return refuse(400, "bad_reason", `Explain what needs changing in ${RULES.reasonLength.min} to ${RULES.reasonLength.max} characters.`);
  }
  const contract = await prisma.contract.findUnique({ where: { id: contractId }, include: { job: true } });
  if (!contract) return refuse(404, "not_found", "Contract not found.");
  if (contract.status !== "submitted") return refuse(400, "not_submitted", "Changes can only be requested on delivered work.");

  if (contract.changeRounds >= RULES.maxChangeRounds) {
    return escalateContract(prisma, mailer, {
      contract,
      from: "submitted",
      reason: "client_rejected_after_final_round",
      note: reason.trim(),
      by: clientId,
      at,
    });
  }

  const round = contract.changeRounds + 1;
  const resubmitDueAt = new Date(at.getTime() + RULES.changeResubmitMs);
  const committed = await prisma.$transaction(async (trx) => {
    const { count } = await trx.contract.updateMany({
      where: { id: contract.id, status: "submitted", changeRounds: contract.changeRounds, releaseClaimedAt: null },
      data: { status: "changesRequested", changeRounds: round, changeDueAt: resubmitDueAt, reviewDueAt: null },
    });
    if (count === 0) return false;
    await trx.changeRequest.create({
      data: { contractId: contract.id, round, reason: reason.trim(), requestedAt: at, resubmitDueAt },
    });
    await recordEvent(trx, { jobId: contract.jobId, contractId: contract.id, type: "changes_requested", meta: { round, resubmitDueAt } });
    return true;
  });
  console.log(`changes: request contract=${contract.id} round=${round} roundsBefore=${contract.changeRounds} committed=${committed}`);
  if (!committed) {
    return refuse(409, "conflict", "This delivery just changed (it may have been approved or paid). Refresh and try again.");
  }

  const { talent } = await parties(prisma, contract);
  if (talent) {
    mailer
      .sendChangesRequested({
        to: talent.email,
        jobTitle: contract.job.title,
        round,
        maxRounds: RULES.maxChangeRounds,
        reason: reason.trim(),
        resubmitDueAt,
      })
      .catch((err) => console.error("changes: failed to email the talent:", err));
  }
  return { ok: true, escalated: false, contract: await prisma.contract.findUnique({ where: { id: contract.id } }) };
}

/**
 * Parks a contract as `disputed` for an admin (stage 3 resolves it). From
 * `submitted` it is conditional on no payout in flight; from
 * `changesRequested` it is conditional on the resubmit clock having run out,
 * so a resubmission that commits first wins.
 */
async function escalateContract(prisma, mailer, { contract, from, reason, note, by, at }) {
  const guard = from === "submitted" ? { releaseClaimedAt: null } : { changeDueAt: { lte: at } };
  const committed = await prisma.$transaction(async (trx) => {
    const { count } = await trx.contract.updateMany({
      where: { id: contract.id, status: from, ...guard },
      data: { status: "disputed", reviewDueAt: null, changeDueAt: null },
    });
    if (count === 0) return false;
    await recordEvent(trx, {
      jobId: contract.jobId,
      contractId: contract.id,
      type: "escalated",
      meta: { reason, note: note ?? null, by: by ?? null, round: contract.changeRounds },
    });
    return true;
  });
  console.log(`changes: escalate contract=${contract.id} from=${from} reason=${reason} committed=${committed}`);
  if (!committed) return refuse(409, "conflict", "This contract just changed. Refresh and try again.");

  console.error(`DISPUTE NEEDS ADMIN contract=${contract.id} job=${contract.jobId} reason=${reason}`);
  const { job, client, talent } = await parties(prisma, contract);
  const owners = await prisma.adminUser.findMany({ where: { role: "owner", status: "active" } });
  await Promise.allSettled([
    client ? mailer.sendEscalated({ to: client.email, jobTitle: job.title, reason }) : null,
    talent ? mailer.sendEscalated({ to: talent.email, jobTitle: job.title, reason }) : null,
    ...owners.map((a) => mailer.sendEscalationToAdmin({ to: a.email, jobTitle: job.title, contractId: contract.id, reason, note })),
  ]);
  return { ok: true, escalated: true, contract: await prisma.contract.findUnique({ where: { id: contract.id } }) };
}

/** Tick: a talent who didn't resubmit within 3 days goes to an admin. */
async function sweepChanges(deps) {
  const { prisma, mailer, now } = baseDeps(deps);
  const at = now();
  const due = await prisma.contract.findMany({
    where: { status: "changesRequested", changeDueAt: { lte: at } },
    include: { job: true },
  });
  let escalated = 0;
  for (const contract of due) {
    const r = await escalateContract(prisma, mailer, { contract, from: "changesRequested", reason: "talent_missed_change_deadline", at });
    if (r.ok) escalated++;
  }
  return { escalated };
}
```

and export `{ submitDelivery, requestChanges, escalateContract, sweepChanges }`.

- [ ] **Step 4: Release claim in `contractLifecycle.js`.** Extend the core import with `RULES` (already there from Task 1). In `releasePayment`, change `const { prisma, paystack } = defaults(deps);` to `const { prisma, paystack, now } = defaults(deps);` and insert, after the payout-account check and before `let attempt;`:

```js
  // Claim the release before any money moves, so a change request (or a
  // second release) can't slip in between the transfer and the status
  // update. A claim older than RULES.releaseClaimStaleMs belongs to a release
  // that crashed mid-way and may be taken over: findPayoutAttempt still
  // reuses any transfer that crash left live.
  const claimedAt = now();
  const claim = await prisma.contract.updateMany({
    where: {
      id: contract.id,
      status: "submitted",
      OR: [{ releaseClaimedAt: null }, { releaseClaimedAt: { lte: new Date(claimedAt.getTime() - RULES.releaseClaimStaleMs) } }],
    },
    data: { releaseClaimedAt: claimedAt },
  });
  console.log(`release: claim contract=${contract.id} trigger=${trigger} claimed=${claim.count === 1} previousClaim=${contract.releaseClaimedAt?.toISOString() ?? "none"}`);
  if (claim.count === 0) {
    return { ok: false, status: 409, code: "release_in_progress", error: "Payment is already being released. Refresh in a moment." };
  }
  const unclaim = () => prisma.contract.updateMany({ where: { id: contract.id, releaseClaimedAt: claimedAt }, data: { releaseClaimedAt: null } });
```

Then call `await unclaim();` immediately before each of the three failure `return`s that follow (the `catch` for `transfer_error`, the `otp`/`received` branch, and the `!== "success" && !== "pending"` branch).

In `autoReleaseOne`, right after `const result = await releasePayment(...)`, add:

```js
  // Lost a race with the client's own Approve (or a change request): not a failure.
  if (!result.ok && (result.code === "release_in_progress" || result.code === "not_submitted")) {
    return { outcome: "superseded" };
  }
```

Register the sweep: `const changes = require("./contractChanges");` and add `["changes", (deps) => changes.sweepChanges(deps)]` to `STAGE2_SWEEPS`.

- [ ] **Step 5: Route.** In `jobsRoutes.js`:

```js
/**
 * The client sends delivered work back with a reason. After the second
 * round the same action escalates the job to an admin instead
 * (`escalated: true` in the response).
 */
router.post(
  "/:id/contract/request-changes",
  loadContractForJob,
  requireClient,
  requireContractStatus("submitted"),
  async (req, res) => {
    if (req.job.clientId !== req.user.id) return res.status(403).json({ error: "Not your job." });
    const result = await changes.requestChanges({ contractId: req.contract.id, clientId: req.user.id, reason: req.body?.reason });
    if (!result.ok) return res.status(result.status).json({ error: result.error });
    return res.json({ escalated: result.escalated, contract: await serializeContract(result.contract) });
  },
);
```

- [ ] **Step 6: Mailer** (add and export):

```js
function sendChangesRequested({ to, jobTitle, round, maxRounds, reason, resubmitDueAt }) {
  return send({
    to,
    subject: `Changes requested on "${jobTitle}" (round ${round} of ${maxRounds})`,
    html: `
      <p>The client asked for changes to <strong>${escapeHtml(jobTitle)}</strong>.</p>
      <p>What they asked for: "${escapeHtml(reason)}"</p>
      <p>Please resubmit in the app by <strong>${formatWAT(resubmitDueAt)}</strong>. If you don't resubmit by then, the job goes to a King Domain admin.</p>
      ${round === maxRounds ? "<p>This is the last round: if the client is still not satisfied after it, an admin will decide.</p>" : ""}
    `,
    fallbackContext: `changes requested (round ${round}) for ${to}: ${jobTitle}`,
  });
}

const ESCALATION_REASONS = {
  client_rejected_after_final_round: "The client was still not satisfied after the last round of changes",
  talent_missed_change_deadline: "The requested changes weren't resubmitted in time",
};

function sendEscalated({ to, jobTitle, reason }) {
  return send({
    to,
    subject: `"${jobTitle}" has gone to a King Domain admin`,
    html: `
      <p>${ESCALATION_REASONS[reason]} on <strong>${escapeHtml(jobTitle)}</strong>, so the job has gone to a King Domain admin.</p>
      <p>The admin will look at every version of the work and the change requests, and decide. Nothing is paid out or refunded until then.</p>
    `,
    fallbackContext: `escalated (${reason}) for ${to}: ${jobTitle}`,
  });
}

function sendEscalationToAdmin({ to, jobTitle, contractId, reason, note }) {
  return send({
    to,
    subject: `Dispute needs an admin: "${jobTitle}"`,
    html: `
      <p><strong>${escapeHtml(jobTitle)}</strong> (contract ${escapeHtml(contractId)}) was escalated: ${ESCALATION_REASONS[reason]}.</p>
      ${note ? `<p>The client wrote: "${escapeHtml(note)}"</p>` : ""}
      <p>There is no dispute screen yet (stage 3). The contract is parked as <code>disputed</code>; nothing moves until it is resolved.</p>
    `,
    fallbackContext: `escalation (${reason}) to admin ${to}: ${contractId}`,
  });
}
```

- [ ] **Step 7: Run** `npm test` → all pass, including lifecycle J (the concurrent approve now loses with `release_in_progress` or `not_submitted` and one transfer is still the outcome).
- [ ] **Step 8: Deliberate breakage checks.** (a) Remove `releaseClaimedAt: null` from `requestChanges`'s `where` → "payout is in flight" test must FAIL; restore. (b) Change `escalateContract`'s guard for `changesRequested` to `{}` → "resubmitted a little late but before the tick" must FAIL; restore. Re-run all → PASS.
- [ ] **Step 9: Review and commit** (`Stage 2: change rounds, escalation to an admin, and a release claim so payouts and change requests can't cross`).

---

### Task 5: Overdue flag

**Files:**
- Modify: `backend/src/contractExtensions.js` (`sweepOverdue`)
- Modify: `backend/src/contractLifecycle.js` (register sweep), `backend/src/admin/mailer.js` (`sendDeliveryOverdueToClient`)
- Create: `backend/test/overdue.test.js`

**Interfaces:**
- Produces: `sweepOverdue(deps) -> {flagged}`.

- [ ] **Step 1: Failing tests.** Create `backend/test/overdue.test.js`:

```js
// Delivery date + 3 days, nothing delivered, no extension pending: flagged
// once and the client is told. No cancel and no refund in stage 2.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;
const ext = require("../src/contractExtensions");
const life = require("../src/contractLifecycle");

let ctx;
before(async () => { ctx = await h.fixtures(); });
after(async () => {
  await prisma.job.deleteMany({ where: { title: { startsWith: h.TITLE_PREFIX } } });
  await prisma.$disconnect();
});
const sweep = (mailer = h.spyMailer()) => ext.sweepOverdue({ prisma: h.scopedPrisma(), mailer });
const flagOf = async (s) => (await prisma.contract.findUnique({ where: { id: s.c.id } })).overdueFlaggedAt;

describe("overdue", () => {
  it("3 days past the date with nothing delivered: flagged once, client emailed, event recorded", async () => {
    const s = await h.seedWorking(ctx, { deliverByAt: h.past(3 * h.DAY_MS + 60_000) });
    const mailer = h.spyMailer();
    assert.deepEqual(await sweep(mailer), { flagged: 1 });
    assert.ok(await flagOf(s));
    assert.deepEqual(mailer.sent.map((m) => [m.k, m.to]), [["sendDeliveryOverdueToClient", ctx.client.email]]);
    assert.ok(await prisma.contractEvent.findFirst({ where: { contractId: s.c.id, type: "overdue" } }));
    assert.deepEqual(await sweep(), { flagged: 0 }, "only once");
  });

  it("less than 3 days past: not flagged", async () => {
    const s = await h.seedWorking(ctx, { deliverByAt: h.past(2 * h.DAY_MS) });
    await sweep();
    assert.equal(await flagOf(s), null);
  });

  it("a pending extension request pauses it", async () => {
    const s = await h.seedWorking(ctx, { deliverByAt: h.past(3 * h.DAY_MS + 60_000) });
    await prisma.contractExtension.create({ data: { contractId: s.c.id, requestedDays: 2, reason: "Waiting on assets.", answerDueAt: h.future() } });
    await sweep();
    assert.equal(await flagOf(s), null);
  });

  it("delivered work and legacy jobs are never flagged", async () => {
    const delivered = await h.seedSubmitted(ctx, { contract: { deliverByAt: h.past(10 * h.DAY_MS) } });
    const legacy = await h.seedAward(ctx, { contract: { status: "inProgress", payByAt: null } });
    await sweep();
    assert.equal(await flagOf(delivered), null);
    assert.equal(await flagOf(legacy), null);
  });

  it("the tick runs it", async () => {
    const s = await h.seedWorking(ctx, { deliverByAt: h.past(3 * h.DAY_MS + 60_000) });
    await life.runTick({ prisma: h.scopedPrisma(), mailer: h.spyMailer(), paystack: h.fakeProvider(), autoRelease: false });
    assert.ok(await flagOf(s));
  });
});
```

- [ ] **Step 2: Run, expect failure** (`sweepOverdue is not a function`).
- [ ] **Step 3: Implement** in `contractExtensions.js` (export it):

```js
/**
 * Tick: delivery date + 3 days, nothing delivered, no extension waiting for
 * an answer -> flag once and tell the client. Stage 2 records the fact only;
 * cancelling for a refund arrives with stage 3 (decision 2026-10-01).
 */
async function sweepOverdue(deps) {
  const { prisma, mailer, now } = baseDeps(deps);
  const at = now();
  const cutoff = new Date(at.getTime() - RULES.overdueGraceMs);
  const due = await prisma.contract.findMany({
    where: {
      status: { in: OPEN_STATUSES },
      overdueFlaggedAt: null,
      deliverByAt: { lte: cutoff },
      extensions: { none: { status: "pending" } },
    },
    include: { job: true },
  });
  let flagged = 0;
  for (const contract of due) {
    const { count } = await prisma.contract.updateMany({
      where: { id: contract.id, status: { in: OPEN_STATUSES }, overdueFlaggedAt: null, deliverByAt: { lte: cutoff } },
      data: { overdueFlaggedAt: at },
    });
    console.log(
      `overdue: contract=${contract.id} deliverByAt=${contract.deliverByAt.toISOString()} cutoff=${cutoff.toISOString()} flagged=${count === 1}`,
    );
    if (count === 0) continue;
    flagged++;
    await recordEvent(prisma, { jobId: contract.jobId, contractId: contract.id, type: "overdue", meta: { deliverByAt: contract.deliverByAt } });
    const { client } = await parties(prisma, contract);
    if (client) {
      await mailer
        .sendDeliveryOverdueToClient({ to: client.email, jobTitle: contract.job.title, deliverByAt: contract.deliverByAt })
        .catch((err) => console.error("overdue: failed to email the client:", err));
    }
  }
  return { flagged };
}
```

Register `["overdue", (deps) => extensions.sweepOverdue(deps)]` in `STAGE2_SWEEPS` (after `changes`).

Mailer (add and export):

```js
/** Stage 2 only records this; cancel-for-refund arrives with stage 3. */
function sendDeliveryOverdueToClient({ to, jobTitle, deliverByAt }) {
  return send({
    to,
    subject: `"${jobTitle}" is 3 days past its delivery date`,
    html: `
      <p>The delivery date for <strong>${escapeHtml(jobTitle)}</strong> was <strong>${formatWAT(deliverByAt)}</strong>. It has now passed by 3 days with nothing delivered and no extension agreed, and we've recorded this on the job.</p>
      <p>The option to cancel for a refund of the job budget isn't available in the app yet.</p>
    `,
    fallbackContext: `delivery overdue (client) for ${to}: ${jobTitle}`,
  });
}
```

- [ ] **Step 4: Run** `npm test` → pass.
- [ ] **Step 5: Review and commit** (`Stage 2: flag a delivery 3 days overdue`).

---

### Task 6: Reminders

**Files:**
- Create: `backend/src/contractReminders.js`
- Modify: `backend/src/contractLifecycle.js` (register sweep), `backend/src/admin/mailer.js` (`sendClockReminder`)
- Create: `backend/test/reminders.test.js`, `backend/test/mailer.test.js`

**Interfaces:**
- Produces: `SCHEDULE`, `currentReminder(entry, due, at) -> label|null`, `sendOnce(prisma, {contractId, key}, send) -> 'sent'|'already_sent'|'failed'`, `sweepReminders(deps) -> {reminded}`; mailer `sendClockReminder({to, kind, jobTitle, dueAt})` with kinds `extension|review|change|delivery|deliveryPassed|deliveryMissedPassed`.

- [ ] **Step 1: Failing tests.** Create `backend/test/reminders.test.js`:

```js
// Every clock whose silence has a default outcome warns the person whose
// silence triggers it: 24 h left, 6 h left; never twice; stale ones skipped.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;
const rem = require("../src/contractReminders");

const H = 3_600_000;
let ctx;
before(async () => { ctx = await h.fixtures(); });
after(async () => {
  await prisma.job.deleteMany({ where: { title: { startsWith: h.TITLE_PREFIX } } });
  await prisma.$disconnect();
});
const entry = (clock) => rem.SCHEDULE.find((e) => e.clock === clock);
const sweepAt = (at, mailer = h.spyMailer(), autoRelease = false) =>
  rem.sweepReminders({ prisma: h.scopedPrisma(), mailer, now: () => at, autoRelease }).then((r) => ({ r, mailer }));

describe("which reminder is current (pure)", () => {
  const due = new Date("2026-10-10T12:00:00Z");
  const at = (hoursBefore) => new Date(due.getTime() - hoursBefore * H);
  it("nothing before 24 h left", () => assert.equal(rem.currentReminder(entry("change"), due, at(30)), null));
  it("24 h reminder between 24 h and 6 h left", () => assert.equal(rem.currentReminder(entry("change"), due, at(20)), "24h"));
  it("at 3 h left the 24 h one is stale; the 6 h one applies", () => assert.equal(rem.currentReminder(entry("change"), due, at(3)), "6h"));
  it("nothing once the clock has run out (the outcome email covers it)", () => assert.equal(rem.currentReminder(entry("change"), due, at(-1)), null));
  it("delivery: a reminder at the date itself, for 3 days", () => {
    assert.equal(rem.currentReminder(entry("delivery"), due, at(-1)), "due");
    assert.equal(rem.currentReminder(entry("delivery"), due, at(-73)), null);
  });
});

describe("sending", () => {
  it("talent's resubmit clock at 20 h left: one '24h' reminder, never twice", async () => {
    const s = await h.seedSubmitted(ctx, { changeRounds: 1, contract: { status: "changesRequested", reviewDueAt: null, changeDueAt: new Date(Date.now() + 20 * H) } });
    const first = await sweepAt(new Date());
    assert.deepEqual(first.mailer.sent.filter((m) => m.args.jobTitle === s.job.title).map((m) => [m.k, m.to, m.args.kind]), [["sendClockReminder", ctx.talentA.email, "change"]]);
    const second = await sweepAt(new Date());
    assert.equal(second.mailer.sent.filter((m) => m.args.jobTitle === s.job.title).length, 0);
  });

  it("two sweeps at the same instant still send it once", async () => {
    const s = await h.seedSubmitted(ctx, { changeRounds: 1, contract: { status: "changesRequested", reviewDueAt: null, changeDueAt: new Date(Date.now() + 5 * H) } });
    const mailer = h.spyMailer();
    await Promise.all([sweepAt(new Date(), mailer), sweepAt(new Date(), mailer)]);
    assert.equal(mailer.sent.filter((m) => m.args.jobTitle === s.job.title).length, 1);
  });

  it("extension waiting on the client: client reminded", async () => {
    const s = await h.seedWorking(ctx);
    await prisma.contractExtension.create({ data: { contractId: s.c.id, requestedDays: 1, reason: "Waiting on assets.", answerDueAt: new Date(Date.now() + 10 * H) } });
    const { mailer } = await sweepAt(new Date());
    assert.deepEqual(mailer.sent.filter((m) => m.args.jobTitle === s.job.title).map((m) => [m.to, m.args.kind]), [[ctx.client.email, "extension"]]);
  });

  it("delivery date passed: talent and client both told; after an extension moves the date, the talent is reminded again", async () => {
    const s = await h.seedWorking(ctx, { deliverByAt: h.past(H) });
    const first = await sweepAt(new Date());
    assert.deepEqual(
      first.mailer.sent.filter((m) => m.args.jobTitle === s.job.title).map((m) => m.args.kind).sort(),
      ["deliveryMissedPassed", "deliveryPassed"],
    );
    await prisma.contract.update({ where: { id: s.c.id }, data: { deliverByAt: new Date(Date.now() + 10 * H) } });
    const again = await sweepAt(new Date());
    assert.deepEqual(again.mailer.sent.filter((m) => m.args.jobTitle === s.job.title).map((m) => m.args.kind), ["delivery"]);
  });

  it("review reminders only when auto-release is on (silence only means something then)", async () => {
    const s = await h.seedSubmitted(ctx, { contract: { reviewDueAt: new Date(Date.now() + 5 * H) } });
    const off = await sweepAt(new Date(), h.spyMailer(), false);
    assert.equal(off.mailer.sent.filter((m) => m.args.jobTitle === s.job.title).length, 0);
    const on = await sweepAt(new Date(), h.spyMailer(), true);
    assert.deepEqual(on.mailer.sent.filter((m) => m.args.jobTitle === s.job.title).map((m) => m.args.kind), ["review"]);
  });

  it("a failed send is retried on the next sweep", async () => {
    const s = await h.seedSubmitted(ctx, { changeRounds: 1, contract: { status: "changesRequested", reviewDueAt: null, changeDueAt: new Date(Date.now() + 5 * H) } });
    const failing = h.spyMailer();
    const broken = new Proxy(failing, { get: (t, k) => (k === "sendClockReminder" ? async () => ({ sent: false, error: new Error("Brevo down") }) : t[k]) });
    await sweepAt(new Date(), broken);
    assert.equal(await prisma.contractReminder.count({ where: { contractId: s.c.id } }), 0);
    const { mailer } = await sweepAt(new Date());
    assert.equal(mailer.sent.filter((m) => m.args.jobTitle === s.job.title).length, 1);
  });
});
```

Create `backend/test/mailer.test.js` (no database):

```js
// Templates escape what users typed and name the deadline. Brevo is stubbed
// by replacing fetch; no email is sent.
const { describe, it, before } = require("node:test");
const assert = require("node:assert/strict");

process.env.BREVO_API_KEY = "test";
process.env.BREVO_SENDER_EMAIL = "noreply@example.com";
const captured = [];
global.fetch = async (_url, opts) => {
  captured.push(JSON.parse(opts.body));
  return { ok: true, text: async () => "" };
};
const mailer = require("../src/admin/mailer");

const EVIL = `<script>alert(1)</script>`;
const due = new Date("2026-10-10T12:00:00Z");

describe("stage 2 emails", () => {
  before(() => (captured.length = 0));
  const cases = [
    ["sendExtensionRequested", { days: 2, reason: EVIL, proposedDeliverBy: due, answerDueAt: due }],
    ["sendExtensionAnswered", { outcome: "autoGranted", deliverByAt: due }],
    ["sendExtensionAutoGrantedToClient", { deliverByAt: due }],
    ["sendChangesRequested", { round: 2, maxRounds: 2, reason: EVIL, resubmitDueAt: due }],
    ["sendEscalated", { reason: "talent_missed_change_deadline" }],
    ["sendEscalationToAdmin", { contractId: "c1", reason: "client_rejected_after_final_round", note: EVIL }],
    ["sendDeliveryOverdueToClient", { deliverByAt: due }],
    ...["extension", "review", "change", "delivery", "deliveryPassed", "deliveryMissedPassed"].map((kind) => ["sendClockReminder", { kind, dueAt: due }]),
  ];
  for (const [fn, args] of cases) {
    it(`${fn}${args.kind ? ` (${args.kind})` : ""}: escapes user text and states the date`, async () => {
      captured.length = 0;
      const r = await mailer[fn]({ to: "a@example.com", jobTitle: EVIL, ...args });
      assert.equal(r.sent, true);
      const html = captured[0].htmlContent;
      assert.ok(!html.includes("<script>"), "raw script tag in html");
      if (!["sendEscalated", "sendEscalationToAdmin"].includes(fn)) assert.match(html, /Oct/, "deadline date missing");
    });
  }
  it("an unknown reminder kind throws instead of sending nonsense", async () => {
    await assert.rejects(() => mailer.sendClockReminder({ to: "a@example.com", kind: "nope", jobTitle: "x", dueAt: due }));
  });
});
```

- [ ] **Step 2: Run, expect failure** (module/function missing).
- [ ] **Step 3: Create `backend/src/contractReminders.js`:**

```js
// The reminder schedule (docs/features/stage-2-delivery-and-changes.md).
// Every clock whose silence has a default outcome warns the person whose
// silence triggers it. A reminder is a ContractReminder row inserted BEFORE
// the email goes out (unique per contract + key), so restarts and
// overlapping ticks can't send it twice; a send that fails removes its row so
// the next tick retries it. Keys include the deadline itself, so a deadline
// that moves (an extension) gets fresh reminders.
const { HOUR, RULES, autoReleaseEnabled, baseDeps, parties } = require("./contractCore");

/**
 * `before`: how long before the deadline each reminder goes, largest first.
 * `at`: also remind at the deadline itself, for `atWindowMs` afterwards.
 */
const SCHEDULE = [
  { clock: "extension", to: "client", before: [24 * HOUR, 6 * HOUR] },
  { clock: "review", to: "client", before: [24 * HOUR, 6 * HOUR] },
  { clock: "change", to: "talent", before: [24 * HOUR, 6 * HOUR] },
  { clock: "delivery", to: "talent", before: [24 * HOUR], at: true, atWindowMs: RULES.overdueGraceMs },
  { clock: "deliveryMissed", to: "client", before: [], at: true, atWindowMs: RULES.overdueGraceMs },
];

// The furthest ahead any reminder looks; deadlines beyond it are skipped.
const HORIZON_MS = 24 * HOUR;

/**
 * The label of the reminder that applies now, or null. A reminder only
 * applies until the next one does: after downtime nobody gets "24 hours
 * left" with 3 hours left.
 */
function currentReminder(entry, due, at) {
  const t = at.getTime();
  const d = due.getTime();
  const points = entry.before.map((ms) => ({ label: `${ms / HOUR}h`, from: d - ms }));
  if (entry.at) points.push({ label: "due", from: d, until: d + entry.atWindowMs });
  for (let i = 0; i < points.length; i++) {
    const until = points[i].until ?? (points[i + 1] ? points[i + 1].from : d);
    if (t >= points[i].from && t < until) return points[i].label;
  }
  return null;
}

async function sendOnce(prisma, { contractId, key }, send) {
  try {
    await prisma.contractReminder.create({ data: { contractId, key } });
  } catch (err) {
    if (err.code === "P2002") return "already_sent";
    throw err;
  }
  const result = await send().catch((err) => ({ sent: false, error: err }));
  if (result?.error) {
    await prisma.contractReminder.deleteMany({ where: { contractId, key } });
    console.error(`reminders: send failed key=${key} contract=${contractId}, will retry: ${result.error.message ?? result.error}`);
    return "failed";
  }
  return "sent";
}

/** Every deadline that could need a reminder now, as {clock, contract, due, ref}. */
async function candidates(prisma, at, autoRelease) {
  const horizon = new Date(at.getTime() + HORIZON_MS);
  const list = [];

  const asking = await prisma.contract.findMany({
    where: { extensions: { some: { status: "pending", answerDueAt: { lte: horizon } } } },
    include: { job: true, extensions: { where: { status: "pending" } } },
  });
  for (const c of asking) for (const e of c.extensions) list.push({ clock: "extension", contract: c, due: e.answerDueAt, ref: e.id });

  // Review silence only means something while auto-release is on.
  if (autoRelease) {
    const reviewing = await prisma.contract.findMany({ where: { status: "submitted", reviewDueAt: { lte: horizon } }, include: { job: true } });
    for (const c of reviewing) list.push({ clock: "review", contract: c, due: c.reviewDueAt, ref: c.reviewDueAt.toISOString() });
  }

  const resubmitting = await prisma.contract.findMany({ where: { status: "changesRequested", changeDueAt: { lte: horizon } }, include: { job: true } });
  for (const c of resubmitting) list.push({ clock: "change", contract: c, due: c.changeDueAt, ref: `round${c.changeRounds}` });

  const working = await prisma.contract.findMany({
    where: { status: { in: ["funded", "inProgress"] }, overdueFlaggedAt: null, deliverByAt: { lte: horizon } },
    include: { job: true },
  });
  for (const c of working) {
    list.push({ clock: "delivery", contract: c, due: c.deliverByAt, ref: c.deliverByAt.toISOString() });
    list.push({ clock: "deliveryMissed", contract: c, due: c.deliverByAt, ref: c.deliverByAt.toISOString() });
  }
  return list;
}

const KIND = { extension: "extension", review: "review", change: "change", delivery: "delivery" };
const PASSED_KIND = { delivery: "deliveryPassed", deliveryMissed: "deliveryMissedPassed" };

async function sweepReminders(deps = {}) {
  const { prisma, mailer, now } = baseDeps(deps);
  const autoRelease = deps.autoRelease ?? autoReleaseEnabled();
  const at = now();
  let reminded = 0;
  for (const cand of await candidates(prisma, at, autoRelease)) {
    const entry = SCHEDULE.find((s) => s.clock === cand.clock);
    const label = currentReminder(entry, cand.due, at);
    if (!label) continue;
    const { client, talent } = await parties(prisma, cand.contract);
    const person = entry.to === "client" ? client : talent;
    if (!person) continue;
    const key = `${cand.clock}:${cand.ref}:${label}`;
    const kind = label === "due" ? PASSED_KIND[cand.clock] : KIND[cand.clock];
    const outcome = await sendOnce(prisma, { contractId: cand.contract.id, key }, () =>
      mailer.sendClockReminder({ to: person.email, kind, jobTitle: cand.contract.job.title, dueAt: cand.due }),
    );
    if (outcome === "sent") {
      reminded++;
      console.log(`reminders: sent key=${key} contract=${cand.contract.id} to=${entry.to} due=${cand.due.toISOString()} now=${at.toISOString()}`);
    }
  }
  return { reminded };
}

module.exports = { SCHEDULE, currentReminder, sendOnce, sweepReminders };
```

Register `["reminders", (deps) => reminders.sweepReminders(deps)]` last in `STAGE2_SWEEPS` (with `const reminders = require("./contractReminders");`).

- [ ] **Step 4: Mailer** (add and export):

```js
const CLOCK_REMINDERS = {
  extension: (t, d) => [`Answer the extension request on "${t}"`, `Please grant or decline the talent's extension request on <strong>${escapeHtml(t)}</strong> by <strong>${formatWAT(d)}</strong>. If you don't answer by then, it is granted automatically.`],
  review: (t, d) => [`Review the delivery on "${t}"`, `Please review the delivery of <strong>${escapeHtml(t)}</strong> by <strong>${formatWAT(d)}</strong>. If you don't, payment is released to the talent automatically.`],
  change: (t, d) => [`Resubmit "${t}"`, `Please resubmit <strong>${escapeHtml(t)}</strong> with the requested changes by <strong>${formatWAT(d)}</strong>. If you don't, the job goes to a King Domain admin.`],
  delivery: (t, d) => [`"${t}" is due ${formatWAT(d)}`, `<strong>${escapeHtml(t)}</strong> is due <strong>${formatWAT(d)}</strong>. If you need more time, ask for an extension in the app before then.`],
  deliveryPassed: (t, d) => [`"${t}" is past its delivery date`, `The delivery date for <strong>${escapeHtml(t)}</strong> (<strong>${formatWAT(d)}</strong>) has passed. Deliver now, or ask for an extension in the app within 3 days of that date.`],
  deliveryMissedPassed: (t, d) => [`"${t}" passed its delivery date`, `The delivery date for <strong>${escapeHtml(t)}</strong> (<strong>${formatWAT(d)}</strong>) has passed and nothing has been delivered yet. The talent has been reminded and can still deliver or ask you for an extension within 3 days.`],
};

/** One template for every clock reminder (contractReminders.js). */
async function sendClockReminder({ to, kind, jobTitle, dueAt }) {
  const build = CLOCK_REMINDERS[kind];
  if (!build) throw new Error(`Unknown reminder kind: ${kind}`);
  const [subject, body] = build(jobTitle, dueAt);
  return send({ to, subject, html: `<p>${body}</p>`, fallbackContext: `reminder ${kind} for ${to}: ${jobTitle}` });
}
```

- [ ] **Step 5: Run** `npm test` → pass. If the "never twice" test fails because the unique violation isn't `P2002` under the pg adapter, print `err.code`/`err.name` in the catch, look the behaviour up with Exa (Prisma 7 driver adapters, unique constraint error code), and adjust the check — do not swallow all errors.
- [ ] **Step 6: Deliberate breakage check.** Remove the `create` in `sendOnce` (send unconditionally) → "never twice" and "two sweeps at the same instant" must FAIL; restore → PASS.
- [ ] **Step 7: Review and commit** (`Stage 2: reminders before every clock that defaults on silence`).

---

### Task 7: Ledger, docs, staging

**Files:**
- Modify (mobile repo): `docs/core/testing.md`, `docs/core/payments.md`, `docs/features/stage-2-delivery-and-changes.md` (status line), `docs/README.md`
- Memory: `payment_flow_rules.md`

- [ ] **Step 1: Full run.** `npm test` in the backend; record the exact pass count.
- [ ] **Step 2: testing.md.** Add a "Stage 2" section to the backend ledger: one row per test above (file, guarantee, 🔵/🟢/🟡), the deliberate-breakage results from Tasks 3, 4 and 6, and under *not guaranteed*: push notifications don't exist (email + in-app only); emails to admins on escalation are the only admin signal until stage 3; the release claim's 10-minute stale takeover is untested against a real crash.
- [ ] **Step 3: payments.md.** Update the flow table and "The clocks" with: delivery date fixed at funding; extensions; change rounds; `changesRequested`/`disputed`; overdue; reminders; the release claim; a pointer to the stage 2 spec. Keep "Auto-release is OFF" and "Not built yet" accurate (cancel/refund, disputes, push).
- [ ] **Step 4: Spec status.** Change the status line to `built on staging (backend); UI not built`.
- [ ] **Step 5: Push the backend branch** (production `master` untouched): `git push --force-with-lease origin master:staging`.
- [ ] **Step 6: Commit docs in the mobile repo** after a pre-commit review; update the memory file's stage 2 line.
- [ ] **Step 7: Production is NOT touched.** Before any production deploy, the additive schema (stage 1 + stage 2) goes to production first; that is the ship order in payments.md and needs Victor.
