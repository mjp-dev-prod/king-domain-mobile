# Work gaps implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the three gaps in [work-gaps-applications-stepper-job-edit.md](./work-gaps-applications-stepper-job-edit.md): the talent's "Applied" list, the five-step lifecycle stepper on both contract screens, and edit or close an open job (backend and app).

**Architecture:** Backend: a new `src/jobs.js` service (the repo's `contractChanges.js` pattern: `baseDeps`, `refuse`, results `{ok, status, code, error}`) holds every job-state guard as ONE conditional `updateMany`, so concurrent requests serialise on the job row. Routes stay thin. App: pure functions decide what to show (`appliedJobs`, `lifecycleSteps`), widgets render them, and the `JobsNotifier` gets `editJob`, `closeJob` and a revision-aware `applyTo`.

**Tech Stack:** Node 20+/Express/Prisma 7 (`@prisma/adapter-pg`) with `node:test` against a Neon test branch; Flutter 3.38/Dart/Riverpod 2.6/`flutter_test`.

## Global Constraints

- Scope: **no money behaviour changes.** Payment, payout, refund and cancel-after-award code is untouched. Awarding only gains a closed-job guard.
- Brand v1: amber = waiting, green = done, red = missed/errors, violet = you can act, gold = money only. No emoji as icons, no decorative gradients, no glow except the single primary button. Radius 12/16/20/28/pill. Press-scale and 250 ms state changes already live in the kit; reuse it.
- Copy never says where money is held (Paystack lists escrow services as ineligible). Say "Client has paid", "Paid to your payout account".
- Product name only through `AppBrand.name`.
- Every state is designed: skeleton while loading, an error with Retry, an empty state that says why and what next. Respect reduced motion (`MediaQuery.maybeDisableAnimationsOf`).
- Tabular figures for money and counts.
- Rules: edit only before the first applicant applies; close and edit only before an award; close is final; closed jobs take no applications and cannot be awarded.
- Schema is additive only (nullable or defaulted columns).
- `ApplicationStatus` values stay `pending | selected | notSelected`.
- TDD: no production code without a failing test first. Watch each test fail for the stated reason.
- **Never push the mobile repo's `master`** (Codemagic builds a production APK from it). Nothing is pushed or deployed in this plan; Task 12 only prepares it and asks Victor.
- Backend repo: `C:\mobile-projects\flutter\kings domain\king-domain-backend` (local `master`, tracks `origin/staging`). Mobile repo: `C:\mobile-projects\flutter\kings domain\king-domain-mobile`.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File structure

Backend (`king-domain-backend`):
- Modify `prisma/schema.prisma` (Job: `closedAt`, `revision`, `lastAppliedAt`).
- Create `src/jobs.js`: `validateJobInput`, `jobInclude`, `editJob`, `closeJob`, `applyToJob`, `awardJob`.
- Modify `src/user/jobsRoutes.js`: use the service; add `PATCH /:id`, `POST /:id/close`; feed visibility; serialize `closedAt` and `revision`.
- Modify `test/helpers.js`: export `ensureUser`.
- Create `test/jobs.test.js` (service level, with races) and `test/jobsRoutes.test.js` (real HTTP, port 4613).

Mobile (`king-domain-mobile`):
- Modify `lib/data/api_client.dart` (`ApiException.code`, `ApiException.fromResponse`), `lib/data/models/job.dart` (`closedAt`, `revision`, `closed`), `lib/presentation/providers/jobs_provider.dart` (`editJob`, `closeJob`, `applyTo(revision:)`).
- Create `lib/presentation/screens/shell/applied_jobs.dart` (pure `appliedJobs`, `appliedStatusLine`, widget `AppliedTile`); modify `work_tab.dart` (segments).
- Create `lib/presentation/widgets/contract/lifecycle_stepper.dart`; modify `contract_parts.dart` (`ContractHeader.action`), `contract_detail_screen.dart`, `client_contract_screen.dart`.
- Modify `post_job_screen.dart` (edit mode), `applicants_screen.dart` (live job, menu, close, read-only when closed), `client_jobs_tab.dart` (closed tiles), `job_detail_screen.dart` (closed view, revision, `terms_changed`), `job_feed_screen.dart` (hide closed).
- Create tests: `test/job_model_test.dart`, `test/work_applied_test.dart`, `test/lifecycle_stepper_test.dart`, `test/edit_close_job_test.dart`; extend `stage2_screens_test.dart` as needed.
- Docs: `docs/core/testing.md`, `docs/README.md`.

---

## Task 1: Schema columns and the test database

**Files:** Modify `prisma/schema.prisma` (backend). No test of its own: Task 2's tests fail until the columns exist.

- [ ] **Step 1: Add the columns** to `model Job`, directly after `awardedApplicationId`:

```prisma
  /// Set when the client closes the job before awarding it. A closed job is
  /// hidden from other talents' feeds and takes no applications.
  closedAt DateTime?
  /// Bumped on every edit. An application carries the revision the talent
  /// read; a mismatch means the terms changed under them (src/jobs.js).
  revision Int @default(0)
  /// Set by every application: the "terms are locked" marker, read by the
  /// edit guard (a job with applications from before this column existed is
  /// caught by `applications: none` instead).
  lastAppliedAt DateTime?
```

- [ ] **Step 2: Push to the TEST database only, with a guard that refuses anything else.** `.env` holds other databases, so set both variables explicitly:

```bash
cd "/c/mobile-projects/flutter/kings domain/king-domain-backend"
set -a; . ./.env.test; set +a
node -e "const u=new URL(process.env.TEST_DATABASE_URL); console.log('host:', u.host); if(/supabase/i.test(u.host)) process.exit(1)"
DATABASE_URL="$TEST_DATABASE_URL" DIRECT_URL="$TEST_DATABASE_URL" npx prisma db push
DATABASE_URL="$TEST_DATABASE_URL" DIRECT_URL="$TEST_DATABASE_URL" npx prisma generate
```
Expected: `Your database is now in sync with your Prisma schema`, no data-loss warning. If it warns about data loss, STOP: the change is additive and should never warn. If it hangs for more than a minute, retry with the `-pooler` part removed from the host in both variables.

- [ ] **Step 3: Verify the columns exist:**

```bash
DATABASE_URL="$TEST_DATABASE_URL" node -e "const {prisma}=require('./src/db');prisma.job.findFirst({select:{closedAt:true,revision:true,lastAppliedAt:true}}).then(r=>{console.log('ok',r);return prisma.\$disconnect()})"
```
Expected: `ok null` or `ok { closedAt: null, revision: 0, lastAppliedAt: null }`.

- [ ] **Step 4: Commit**

```bash
git add prisma/schema.prisma
git commit -m "Job: closedAt, revision and lastAppliedAt for editing and closing open jobs

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 2: Job input validation and `editJob` (service), then `PATCH /jobs/:id`

**Files:** Create `src/jobs.js`, `test/jobs.test.js`, `test/jobsRoutes.test.js`; modify `src/user/jobsRoutes.js`, `test/helpers.js`.

**Interfaces:**
- Produces: `validateJobInput(body) -> {ok:true, value:{title,category,description,budget,deliveryDays}} | {ok:false,status,code,error}`; `jobInclude`; `editJob({jobId, clientId, input}, deps?) -> {ok:true, job} | {ok:false,status,code,error}` with codes `invalid`, `not_found`, `not_yours`, `closed`, `awarded`, `has_applicants`.

- [ ] **Step 1: Export `ensureUser` from the test helpers** (one word added to the last line of `test/helpers.js`): change `module.exports = { prisma, CATEGORY, ...` to also include `ensureUser`.

- [ ] **Step 2: Write the failing service tests**, `test/jobs.test.js`:

```js
// Editing, closing, applying to and awarding a job before it has a contract.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const h = require("./helpers");
const { prisma } = h;
const jobs = require("../src/jobs");

let ctx, otherClient;
before(async () => {
  ctx = await h.fixtures();
  otherClient = await h.ensureUser("testsuite-client-2@example.com", "client", "Suite Client Two");
});
after(async () => {
  await prisma.job.deleteMany({ where: { title: { startsWith: h.TITLE_PREFIX } } });
  await prisma.$disconnect();
});

const openJob = (data = {}) =>
  prisma.job.create({
    data: { clientId: ctx.client.id, title: `${h.TITLE_PREFIX}${crypto.randomBytes(3).toString("hex")}`, category: h.CATEGORY, description: "suite", budget: 1000, deliveryDays: 5, ...data },
  });
const input = (over = {}) => ({ title: `${h.TITLE_PREFIX}edited`, category: h.CATEGORY, description: "a new description", budget: 2500, deliveryDays: 9, ...over });
const edit = (job, over, clientId = ctx.client.id, deps) => jobs.editJob({ jobId: job.id, clientId, input: input(over) }, deps);

describe("validateJobInput", () => {
  it("accepts a good job and trims the text", () => {
    const r = jobs.validateJobInput({ title: "  Logo  ", category: " Design ", description: " Make one ", budget: "1500", deliveryDays: "7" });
    assert.equal(r.ok, true);
    assert.deepEqual(r.value, { title: "Logo", category: "Design", description: "Make one", budget: 1500, deliveryDays: 7 });
  });

  it("refuses each bad field with its own message", () => {
    const good = { title: "t", category: "c", description: "d", budget: 10, deliveryDays: 5 };
    const cases = [
      [{ title: "  " }, "title is required."],
      [{ category: undefined }, "category is required."],
      [{ description: "" }, "description is required."],
      [{ budget: 0 }, "budget must be a positive number."],
      [{ budget: "x" }, "budget must be a positive number."],
      [{ deliveryDays: 0 }, "deliveryDays must be a whole number of days from 1 to 60."],
      [{ deliveryDays: 61 }, "deliveryDays must be a whole number of days from 1 to 60."],
      [{ deliveryDays: 2.5 }, "deliveryDays must be a whole number of days from 1 to 60."],
    ];
    for (const [over, message] of cases) {
      const r = jobs.validateJobInput({ ...good, ...over });
      assert.equal(r.ok, false, JSON.stringify(over));
      assert.equal(r.status, 400);
      assert.equal(r.code, "invalid");
      assert.equal(r.error, message);
    }
  });
});

describe("editJob", () => {
  it("changes every field, bumps the revision, and leaves the job open", async () => {
    const job = await openJob();
    const r = await edit(job);
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.equal(r.job.title, `${h.TITLE_PREFIX}edited`);
    assert.equal(r.job.description, "a new description");
    assert.equal(Number(r.job.budget), 2500);
    assert.equal(r.job.deliveryDays, 9);
    assert.equal(r.job.revision, 1);
    assert.equal(r.job.closedAt, null);
    assert.equal((await edit(job)).job.revision, 2);
  });

  it("is refused for another client's job (403) and a missing job (404)", async () => {
    const job = await openJob();
    assert.equal((await edit(job, {}, otherClient.id)).status, 403);
    assert.equal((await jobs.editJob({ jobId: "00000000-0000-0000-0000-000000000000", clientId: ctx.client.id, input: input() })).status, 404);
    assert.equal((await prisma.job.findUnique({ where: { id: job.id } })).revision, 0);
  });

  it("is refused for invalid input and changes nothing", async () => {
    const job = await openJob();
    const r = await edit(job, { budget: -5 });
    assert.equal(r.code, "invalid");
    assert.equal((await prisma.job.findUnique({ where: { id: job.id } })).revision, 0);
  });

  it("is refused once someone has applied (has_applicants) and the terms stay as they were", async () => {
    const job = await openJob({ title: `${h.TITLE_PREFIX}locked` });
    await prisma.application.create({ data: { jobId: job.id, talentId: ctx.talentA.id } });
    const r = await edit(job);
    assert.equal(r.ok, false);
    assert.equal(r.status, 409);
    assert.equal(r.code, "has_applicants");
    assert.match(r.error, /Someone has already applied/);
    const after = await prisma.job.findUnique({ where: { id: job.id } });
    assert.equal(after.title, `${h.TITLE_PREFIX}locked`);
    assert.equal(after.revision, 0);
  });

  it("is refused when the applicant pre-dates lastAppliedAt (applications exist, the column is null)", async () => {
    const job = await openJob();
    await prisma.application.create({ data: { jobId: job.id, talentId: ctx.talentA.id } });
    assert.equal((await prisma.job.findUnique({ where: { id: job.id } })).lastAppliedAt, null);
    assert.equal((await edit(job)).code, "has_applicants");
  });

  it("is refused once awarded (awarded) or closed (closed)", async () => {
    const awarded = await h.seedAward(ctx);
    assert.equal((await edit(awarded.job)).code, "awarded");
    const closed = await openJob({ closedAt: new Date() });
    assert.equal((await edit(closed)).code, "closed");
  });
});
```

- [ ] **Step 3: Run it and watch it fail for the right reason:**
`cd "C:/mobile-projects/flutter/kings domain/king-domain-backend" && node --env-file-if-exists=.env.test --test test/jobs.test.js`
Expected: FAIL, `Cannot find module '../src/jobs'`.

- [ ] **Step 4: Write `src/jobs.js`:**

```js
// A job before it has a contract: edit it until someone applies, close it,
// apply to it, award it. Design: docs/features/work-gaps-applications-stepper-job-edit.md
// in the mobile repo.
//
// Every guard here is ONE conditional UPDATE on the job row. Concurrent
// requests queue on that row's lock and re-check its columns once they get it,
// so "no edit after the first applicant", "no application after a close" and
// "no award after a close" hold without raw SQL or serializable transactions.
const { RULES, baseDeps, refuse } = require("./contractCore");

const jobInclude = { client: true, contract: true, _count: { select: { applications: true } } };
const loadJob = (prisma, id) => prisma.job.findUnique({ where: { id }, include: jobInclude });

const MSG = {
  closed: "This job has been closed.",
  awarded: "This job has already been awarded.",
  awardedEdit: "This job has already been awarded, so it can't be changed.",
  locked: "Someone has already applied, so the terms are locked. Close this job and post a new one to change them.",
};

/** The fields a client sets when posting or editing a job, checked and trimmed. */
function validateJobInput(body) {
  const { title, category, description, budget, deliveryDays } = body ?? {};
  if (typeof title !== "string" || !title.trim()) return refuse(400, "invalid", "title is required.");
  if (typeof category !== "string" || !category.trim()) return refuse(400, "invalid", "category is required.");
  if (typeof description !== "string" || !description.trim()) return refuse(400, "invalid", "description is required.");
  const budgetNum = Number(budget);
  if (!Number.isFinite(budgetNum) || budgetNum <= 0) return refuse(400, "invalid", "budget must be a positive number.");
  const days = Number(deliveryDays);
  if (!Number.isInteger(days) || days < RULES.deliveryDays.min || days > RULES.deliveryDays.max) {
    return refuse(400, "invalid", `deliveryDays must be a whole number of days from ${RULES.deliveryDays.min} to ${RULES.deliveryDays.max}.`);
  }
  return { ok: true, value: { title: title.trim(), category: category.trim(), description: description.trim(), budget: budgetNum, deliveryDays: days } };
}

/** Why a guarded update touched nothing, from the row as it is now. Null when the row is open. */
async function stateRefusal(prisma, jobId, { editing }) {
  const job = await prisma.job.findUnique({ where: { id: jobId } });
  if (!job) return refuse(404, "not_found", "Job not found.");
  if (job.closedAt) return refuse(409, "closed", MSG.closed);
  if (job.awardedApplicationId) return refuse(409, "awarded", editing ? MSG.awardedEdit : MSG.awarded);
  return null;
}

/**
 * The client edits their own job, only while it is open and nobody has applied.
 * The update's WHERE is the rule; if it matches nothing we read the row again
 * to say which part of the rule failed.
 */
async function editJob({ jobId, clientId, input }, deps) {
  const { prisma } = baseDeps(deps);
  const checked = validateJobInput(input);
  if (!checked.ok) return checked;

  const job = await prisma.job.findUnique({ where: { id: jobId } });
  if (!job) return refuse(404, "not_found", "Job not found.");
  if (job.clientId !== clientId) return refuse(403, "not_yours", "Not your job.");

  const { count } = await prisma.job.updateMany({
    where: { id: job.id, clientId, closedAt: null, awardedApplicationId: null, lastAppliedAt: null, applications: { none: {} } },
    data: { ...checked.value, revision: { increment: 1 } },
  });
  if (count === 1) return { ok: true, job: await loadJob(prisma, job.id) };

  return (await stateRefusal(prisma, job.id, { editing: true })) ?? refuse(409, "has_applicants", MSG.locked);
}

module.exports = { validateJobInput, jobInclude, loadJob, stateRefusal, editJob, MSG };
```

- [ ] **Step 5: Run the service tests, expect PASS** (same command as Step 3).

- [ ] **Step 6: Write the failing HTTP tests**, `test/jobsRoutes.test.js` (this file grows in later tasks):

```js
// The job routes over real HTTP: the real server against the test database.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;

let ctx, otherClient, fake, server, ct, c2, ta, tb;
before(async () => {
  ctx = await h.fixtures();
  otherClient = await h.ensureUser("testsuite-client-2@example.com", "client", "Suite Client Two");
  for (const t of [ctx.talentA, ctx.talentB]) {
    const profile = await prisma.talentProfile.findUnique({ where: { userId: t.id } });
    await prisma.proofItem.deleteMany({ where: { talentProfileId: profile.id } });
    await prisma.proofItem.create({ data: { talentProfileId: profile.id, category: h.CATEGORY, title: "Verified work", status: "verified" } });
  }
  fake = await h.serveFakeProvider(h.fakeProvider());
  server = await h.startServer({ port: 4613, paystackUrl: fake.url, autoRelease: false });
  [ct, c2, ta, tb] = await Promise.all([h.tokenFor(ctx.client), h.tokenFor(otherClient), h.tokenFor(ctx.talentA), h.tokenFor(ctx.talentB)]);
});
after(async () => {
  server?.stop();
  fake?.server.close();
  await prisma.job.deleteMany({ where: { title: { startsWith: h.TITLE_PREFIX } } });
  await prisma.$disconnect();
});

const api = (tok, method, p, body) => h.call(server.base, tok, method, p, body);
const body = (over = {}) => ({ title: `${h.TITLE_PREFIX}http`, category: h.CATEGORY, description: "suite", budget: 1000, deliveryDays: 5, ...over });
const post = async (over) => (await api(ct, "POST", "/jobs", body(over))).json.job;

describe("POST /jobs", () => {
  it("returns closedAt null and revision 0 on a new job", async () => {
    const r = await api(ct, "POST", "/jobs", body());
    assert.equal(r.status, 201);
    assert.equal(r.json.job.closedAt, null);
    assert.equal(r.json.job.revision, 0);
  });

  it("keeps refusing bad input with the same messages", async () => {
    const r = await api(ct, "POST", "/jobs", body({ deliveryDays: 0 }));
    assert.equal(r.status, 400);
    assert.match(r.json.error, /deliveryDays must be a whole number of days from 1 to 60/);
  });
});

describe("PATCH /jobs/:id", () => {
  it("the owner edits an open job with no applicants", async () => {
    const job = await post();
    const r = await api(ct, "PATCH", `/jobs/${job.id}`, body({ title: `${h.TITLE_PREFIX}renamed`, budget: 4000 }));
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.equal(r.json.job.title, `${h.TITLE_PREFIX}renamed`);
    assert.equal(Number(r.json.job.budget), 4000);
    assert.equal(r.json.job.revision, 1);
  });

  it("a talent gets 403, another client gets 403, a missing job gets 404, bad input gets 400", async () => {
    const job = await post();
    assert.equal((await api(ta, "PATCH", `/jobs/${job.id}`, body())).status, 403);
    assert.equal((await api(c2, "PATCH", `/jobs/${job.id}`, body())).status, 403);
    assert.equal((await api(ct, "PATCH", "/jobs/00000000-0000-0000-0000-000000000000", body())).status, 404);
    assert.equal((await api(ct, "PATCH", `/jobs/${job.id}`, body({ budget: 0 }))).status, 400);
  });

  it("is refused with 409 and a code once someone applied, once awarded, and once closed", async () => {
    const applied = await post();
    await prisma.application.create({ data: { jobId: applied.id, talentId: ctx.talentA.id } });
    const a = await api(ct, "PATCH", `/jobs/${applied.id}`, body());
    assert.equal(a.status, 409);
    assert.equal(a.json.code, "has_applicants");

    const awarded = await h.seedAward(ctx);
    assert.equal((await api(ct, "PATCH", `/jobs/${awarded.job.id}`, body())).json.code, "awarded");

    const closed = await post();
    await prisma.job.update({ where: { id: closed.id }, data: { closedAt: new Date() } });
    assert.equal((await api(ct, "PATCH", `/jobs/${closed.id}`, body())).json.code, "closed");
  });
});
```

- [ ] **Step 7: Run it, expect FAIL** (`node --env-file-if-exists=.env.test --test test/jobsRoutes.test.js`): the PATCH tests fail with status 404 (no such route) and the POST test fails on `closedAt` being `undefined`.

- [ ] **Step 8: Wire the routes** in `src/user/jobsRoutes.js`. (a) Add `const jobsService = require("../jobs");` beside the other requires. (b) In `serializeJob`, after `awardedApplicationId: job.awardedApplicationId,` add `closedAt: job.closedAt ?? null,` and `revision: job.revision ?? 0,`. (c) Replace the body of `router.post("/", requireClient, ...)` with:

```js
router.post("/", requireClient, async (req, res) => {
  const checked = jobsService.validateJobInput(req.body);
  if (!checked.ok) return res.status(checked.status).json({ error: checked.error });
  const job = await prisma.job.create({ data: { clientId: req.user.id, ...checked.value }, include: jobsService.jobInclude });
  return res.status(201).json({ job: await serializeJob(job) });
});

/** Edit an open job nobody has applied to yet (docs/features/work-gaps-applications-stepper-job-edit.md). */
router.patch("/:id", requireClient, async (req, res) => {
  const result = await jobsService.editJob({ jobId: req.params.id, clientId: req.user.id, input: req.body });
  if (!result.ok) return res.status(result.status).json({ error: result.error, code: result.code });
  return res.json({ job: await serializeJob(result.job) });
});
```

- [ ] **Step 9: Run both new files and the whole backend suite**, expect PASS: `npm test`. (Existing `stage2Routes` delivery-days test must still pass.)

- [ ] **Step 10: Commit**

```bash
git add src/jobs.js src/user/jobsRoutes.js test/jobs.test.js test/jobsRoutes.test.js test/helpers.js
git commit -m "Edit an open job until the first applicant applies

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 3: `closeJob`, `POST /jobs/:id/close`, and feed visibility

**Files:** Modify `src/jobs.js`, `src/user/jobsRoutes.js`, `test/jobs.test.js`, `test/jobsRoutes.test.js`.

**Interfaces:** Produces `closeJob({jobId, clientId}, deps?) -> {ok:true, job} | {ok:false,...}` with codes `not_found`, `not_yours`, `closed`, `awarded`.

- [ ] **Step 1: Add the failing service tests** to `test/jobs.test.js`:

```js
describe("closeJob", () => {
  const close = (job, clientId = ctx.client.id, deps) => jobs.closeJob({ jobId: job.id, clientId }, deps);

  it("closes the job and marks every pending application not selected", async () => {
    const job = await openJob();
    await prisma.application.create({ data: { jobId: job.id, talentId: ctx.talentA.id } });
    await prisma.application.create({ data: { jobId: job.id, talentId: ctx.talentB.id } });
    const r = await close(job);
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.ok(r.job.closedAt);
    const statuses = (await prisma.application.findMany({ where: { jobId: job.id } })).map((a) => a.status);
    assert.deepEqual(statuses, ["notSelected", "notSelected"]);
  });

  it("closes a job nobody applied to", async () => {
    assert.equal((await close(await openJob())).ok, true);
  });

  it("is refused for another client (403), a missing job (404), a closed job and an awarded job (409)", async () => {
    const job = await openJob();
    assert.equal((await close(job, otherClient.id)).status, 403);
    assert.equal((await jobs.closeJob({ jobId: "00000000-0000-0000-0000-000000000000", clientId: ctx.client.id })).status, 404);
    assert.equal((await close(job)).ok, true);
    assert.equal((await close(job)).code, "closed");
    const awarded = await h.seedAward(ctx);
    const r = await close(awarded.job);
    assert.equal(r.code, "awarded");
    assert.equal((await prisma.job.findUnique({ where: { id: awarded.job.id } })).closedAt, null);
  });
});
```

- [ ] **Step 2: Run, expect FAIL** (`jobs.closeJob is not a function`).

- [ ] **Step 3: Implement.** In `src/jobs.js` add before `module.exports`, and export `closeJob`:

```js
/**
 * The client closes their own open job: final. In one transaction the job gets
 * closedAt (only if it is still open and unawarded) and every pending
 * application becomes notSelected, so no applicant is left waiting on a job
 * that will never pick anyone. An application written at the same moment
 * either commits first (and is swept by the second statement) or finds the
 * job closed and is refused (applyToJob).
 */
async function closeJob({ jobId, clientId }, deps) {
  const { prisma, now } = baseDeps(deps);
  const job = await prisma.job.findUnique({ where: { id: jobId } });
  if (!job) return refuse(404, "not_found", "Job not found.");
  if (job.clientId !== clientId) return refuse(403, "not_yours", "Not your job.");

  const closed = await prisma.$transaction(async (trx) => {
    const { count } = await trx.job.updateMany({
      where: { id: job.id, clientId, closedAt: null, awardedApplicationId: null },
      data: { closedAt: now() },
    });
    if (count === 0) return false;
    await trx.application.updateMany({ where: { jobId: job.id, status: "pending" }, data: { status: "notSelected" } });
    return true;
  });
  if (closed) return { ok: true, job: await loadJob(prisma, job.id) };

  return (await stateRefusal(prisma, job.id, { editing: false })) ?? refuse(409, "closed", MSG.closed);
}
```

- [ ] **Step 4: Run the service tests, expect PASS.**

- [ ] **Step 5: Add the failing HTTP tests** to `test/jobsRoutes.test.js`:

```js
describe("POST /jobs/:id/close and feed visibility", () => {
  const feedIds = async (tok) => (await api(tok, "GET", "/jobs")).json.jobs.map((j) => j.id);

  it("the owner closes it: closedAt is set, and the pending applicant sees it as not selected", async () => {
    const job = await post();
    await prisma.application.create({ data: { jobId: job.id, talentId: ctx.talentA.id } });
    const r = await api(ct, "POST", `/jobs/${job.id}/close`);
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.ok(r.json.job.closedAt);
    const seen = (await api(ta, "GET", "/jobs")).json.jobs.find((j) => j.id === job.id);
    assert.equal(seen.myApplicationStatus, "notSelected");
    assert.ok(seen.closedAt);
  });

  it("a closed job leaves the feed for talents who never applied, and stays for its owner", async () => {
    const job = await post();
    assert.ok((await feedIds(tb)).includes(job.id));
    await api(ct, "POST", `/jobs/${job.id}/close`);
    assert.ok(!(await feedIds(tb)).includes(job.id));
    assert.ok((await feedIds(ct)).includes(job.id));
  });

  it("a talent gets 403, another client gets 403, closing twice and closing an awarded job get 409 with a code", async () => {
    const job = await post();
    assert.equal((await api(ta, "POST", `/jobs/${job.id}/close`)).status, 403);
    assert.equal((await api(c2, "POST", `/jobs/${job.id}/close`)).status, 403);
    assert.equal((await api(ct, "POST", `/jobs/${job.id}/close`)).status, 200);
    const again = await api(ct, "POST", `/jobs/${job.id}/close`);
    assert.equal(again.status, 409);
    assert.equal(again.json.code, "closed");
    const awarded = await h.seedAward(ctx);
    assert.equal((await api(ct, "POST", `/jobs/${awarded.job.id}/close`)).json.code, "awarded");
  });
});
```

- [ ] **Step 6: Run, expect FAIL** (close route 404s; the feed still lists closed jobs).

- [ ] **Step 7: Wire the route and the feed** in `src/user/jobsRoutes.js`. Add after the PATCH route:

```js
/** Close an open job: final, hides it from other talents, ends pending applications. */
router.post("/:id/close", requireClient, async (req, res) => {
  const result = await jobsService.closeJob({ jobId: req.params.id, clientId: req.user.id });
  if (!result.ok) return res.status(result.status).json({ error: result.error, code: result.code });
  return res.json({ job: await serializeJob(result.job) });
});
```
and change the feed query's `where` in `router.get("/")` from `category ? { category: String(category) } : undefined` to:

```js
    where: {
      AND: [
        category ? { category: String(category) } : {},
        // A closed job stays visible to its owner and to talents who applied to it.
        { OR: [{ closedAt: null }, { clientId: req.user.id }, { applications: { some: { talentId: req.user.id } } }] },
      ],
    },
```

- [ ] **Step 8: Run both files and `npm test`, expect PASS. Commit:**

```bash
git add src/jobs.js src/user/jobsRoutes.js test/jobs.test.js test/jobsRoutes.test.js
git commit -m "Close an open job; closed jobs leave other talents' feeds

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 4: `applyToJob` with the revision guard

**Files:** Modify `src/jobs.js`, `src/user/jobsRoutes.js`, `test/jobs.test.js`, `test/jobsRoutes.test.js`.

**Interfaces:** Produces `applyToJob({jobId, talentId, revision?}, deps?) -> {ok:true, application} | {ok:false,...}` with codes `not_found`, `closed`, `awarded` (400), `terms_changed`, `already_applied`. The route has already checked verified-in-category and the payout account.

- [ ] **Step 1: Add the failing service tests** to `test/jobs.test.js`:

```js
describe("applyToJob", () => {
  const apply = (job, talent = ctx.talentA, revision, deps) => jobs.applyToJob({ jobId: job.id, talentId: talent.id, revision }, deps);

  it("creates the application and stamps lastAppliedAt", async () => {
    const job = await openJob();
    const r = await apply(job, ctx.talentA, 0);
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.equal(r.application.status, "pending");
    assert.ok((await prisma.job.findUnique({ where: { id: job.id } })).lastAppliedAt);
  });

  it("accepts an application without a revision (older app builds)", async () => {
    assert.equal((await apply(await openJob())).ok, true);
  });

  it("refuses an application made on older terms (terms_changed) and creates nothing", async () => {
    const job = await openJob();
    await edit(job); // revision is now 1
    const r = await apply(job, ctx.talentA, 0);
    assert.equal(r.status, 409);
    assert.equal(r.code, "terms_changed");
    assert.equal(await prisma.application.count({ where: { jobId: job.id } }), 0);
    assert.equal((await apply(job, ctx.talentA, 1)).ok, true);
  });

  it("refuses a closed job (409 closed) and an awarded job (400 awarded)", async () => {
    const closed = await openJob({ closedAt: new Date() });
    const c = await apply(closed);
    assert.equal(c.status, 409);
    assert.equal(c.code, "closed");
    const awarded = await h.seedAward(ctx);
    const a = await apply(awarded.job, ctx.talentA);
    assert.equal(a.status, 400);
    assert.equal(a.code, "awarded");
  });

  it("a second application by the same talent is already_applied and leaves one row", async () => {
    const job = await openJob();
    assert.equal((await apply(job)).ok, true);
    const r = await apply(job);
    assert.equal(r.status, 409);
    assert.equal(r.code, "already_applied");
    assert.equal(await prisma.application.count({ where: { jobId: job.id } }), 1);
  });

  it("a missing job is 404", async () => {
    assert.equal((await jobs.applyToJob({ jobId: "00000000-0000-0000-0000-000000000000", talentId: ctx.talentA.id })).status, 404);
  });
});
```

- [ ] **Step 2: Run, expect FAIL** (`jobs.applyToJob is not a function`).

- [ ] **Step 3: Implement** in `src/jobs.js` (export `applyToJob`):

```js
/**
 * A verified talent applies. The job row is claimed first (guarded on open,
 * unawarded and, when the app sent it, the revision the talent read) and the
 * application is written in the same transaction, so an application can never
 * land on a job that closed, was awarded, or was edited since the talent
 * looked at it. Setting lastAppliedAt is also what locks the terms (editJob).
 */
async function applyToJob({ jobId, talentId, revision }, deps) {
  const { prisma, now } = baseDeps(deps);
  const job = await prisma.job.findUnique({ where: { id: jobId } });
  if (!job) return refuse(404, "not_found", "Job not found.");
  if (job.closedAt) return refuse(409, "closed", MSG.closed);
  if (job.awardedApplicationId) return refuse(400, "awarded", MSG.awarded);

  try {
    const application = await prisma.$transaction(async (trx) => {
      const { count } = await trx.job.updateMany({
        where: { id: job.id, closedAt: null, awardedApplicationId: null, ...(revision === undefined ? {} : { revision }) },
        data: { lastAppliedAt: now() },
      });
      if (count === 0) return null;
      return trx.application.create({ data: { jobId: job.id, talentId }, include: { talent: true } });
    });
    if (application) return { ok: true, application };
  } catch (err) {
    // The @@unique([jobId, talentId]) in schema.prisma: a double apply is a clean 409.
    if (err.code === "P2002") return refuse(409, "already_applied", "You've already applied to this job.");
    throw err;
  }

  const fresh = await prisma.job.findUnique({ where: { id: job.id } });
  if (fresh?.closedAt) return refuse(409, "closed", MSG.closed);
  if (fresh?.awardedApplicationId) return refuse(400, "awarded", MSG.awarded);
  return refuse(409, "terms_changed", "This job was just edited. Read the new details, then apply again.");
}
```

- [ ] **Step 4: Run the service tests, expect PASS.**

- [ ] **Step 5: Add the failing HTTP tests** to `test/jobsRoutes.test.js`:

```js
describe("POST /jobs/:id/apply", () => {
  it("applies (201), with or without the revision the talent read", async () => {
    const withRev = await post();
    const a = await api(ta, "POST", `/jobs/${withRev.id}/apply`, { revision: 0 });
    assert.equal(a.status, 201, JSON.stringify(a.json));
    const without = await post();
    assert.equal((await api(tb, "POST", `/jobs/${without.id}/apply`)).status, 201);
  });

  it("a stale revision is 409 terms_changed; a non-integer revision is 400", async () => {
    const job = await post();
    await api(ct, "PATCH", `/jobs/${job.id}`, body({ description: "changed" }));
    const stale = await api(ta, "POST", `/jobs/${job.id}/apply`, { revision: 0 });
    assert.equal(stale.status, 409);
    assert.equal(stale.json.code, "terms_changed");
    assert.equal((await api(ta, "POST", `/jobs/${job.id}/apply`, { revision: "x" })).status, 400);
    assert.equal((await api(ta, "POST", `/jobs/${job.id}/apply`, { revision: 1 })).status, 201);
  });

  it("a closed job is 409 closed", async () => {
    const job = await post();
    await api(ct, "POST", `/jobs/${job.id}/close`);
    const r = await api(ta, "POST", `/jobs/${job.id}/apply`, { revision: 0 });
    assert.equal(r.status, 409);
    assert.equal(r.json.code, "closed");
  });

  it("applying twice is 409 already_applied; an unverified category is still 403", async () => {
    const job = await post();
    assert.equal((await api(ta, "POST", `/jobs/${job.id}/apply`)).status, 201);
    assert.equal((await api(ta, "POST", `/jobs/${job.id}/apply`)).json.code, "already_applied");
    const other = await post({ category: "A category nobody is verified in" });
    assert.equal((await api(ta, "POST", `/jobs/${other.id}/apply`)).status, 403);
  });
});
```

- [ ] **Step 6: Run, expect FAIL** (stale and closed cases return 201/400 today).

- [ ] **Step 7: Wire the apply route.** Replace the part of `router.post("/:id/apply", ...)` that follows the payout-account check (from `if (job.awardedApplicationId)` to the end of the handler) with:

```js
  const { revision } = req.body ?? {};
  if (revision !== undefined && !Number.isInteger(revision)) {
    return res.status(400).json({ error: "revision must be a whole number." });
  }
  const result = await jobsService.applyToJob({ jobId: job.id, talentId: req.user.id, revision });
  if (!result.ok) return res.status(result.status).json({ error: result.error, code: result.code });
  return res.status(201).json({ application: serializeApplication(result.application) });
});
```
(The verified-in-category and payout-account checks above it stay exactly as they are.)

- [ ] **Step 8: Run both files and `npm test`, expect PASS. Commit:**

```bash
git add src/jobs.js src/user/jobsRoutes.js test/jobs.test.js test/jobsRoutes.test.js
git commit -m "Applications carry the job revision and are refused on closed or edited jobs

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 5: `awardJob` (characterisation first, then the closed-job guard)

**Files:** Modify `src/jobs.js`, `src/user/jobsRoutes.js`, `test/jobs.test.js`, `test/jobsRoutes.test.js`.

**Interfaces:** Produces `awardJob({jobId, clientId, applicationId}, deps?) -> {ok:true, contract} | {ok:false,...}` with codes `not_found`, `not_yours`, `closed`, `awarded` (400). Behaviour for an open job must be IDENTICAL to today's route (selected / notSelected / contract awaitingPayment with the frozen fee and the 24 h pay window / `awarded` event).

- [ ] **Step 1: Write the characterisation test over HTTP and run it against the CURRENT route** (it must pass before any change; that is what makes the refactor safe). Add to `test/jobsRoutes.test.js`:

```js
describe("POST /jobs/:id/applications/:applicationId/award", () => {
  it("awards one applicant: selected, the rest not selected, a contract awaiting payment with the frozen fee and pay window", async () => {
    const job = await post({ budget: 2000 });
    const a = (await api(ta, "POST", `/jobs/${job.id}/apply`)).json.application;
    const b = (await api(tb, "POST", `/jobs/${job.id}/apply`)).json.application;
    const before = Date.now();
    const r = await api(ct, "POST", `/jobs/${job.id}/applications/${a.id}/award`);
    assert.equal(r.status, 201, JSON.stringify(r.json));
    assert.equal(r.json.contract.status, "awaitingPayment");
    assert.equal(Number(r.json.contract.platformFeeAmount), 200);
    const payByMs = new Date(r.json.contract.payByAt).getTime() - before;
    assert.ok(Math.abs(payByMs - 24 * 3_600_000) < 60_000, `payBy window ${payByMs}`);
    const rows = await prisma.application.findMany({ where: { jobId: job.id } });
    assert.equal(rows.find((x) => x.id === a.id).status, "selected");
    assert.equal(rows.find((x) => x.id === b.id).status, "notSelected");
    assert.equal((await prisma.job.findUnique({ where: { id: job.id } })).awardedApplicationId, a.id);
    assert.equal(await prisma.contractEvent.count({ where: { jobId: job.id, type: "awarded" } }), 1);
  });

  it("only the job's client; a second award and a missing application are refused", async () => {
    const job = await post();
    const a = (await api(ta, "POST", `/jobs/${job.id}/apply`)).json.application;
    assert.equal((await api(c2, "POST", `/jobs/${job.id}/applications/${a.id}/award`)).status, 403);
    assert.equal((await api(ct, "POST", `/jobs/${job.id}/applications/00000000-0000-0000-0000-000000000000/award`)).status, 404);
    assert.equal((await api(ct, "POST", `/jobs/${job.id}/applications/${a.id}/award`)).status, 201);
    assert.equal((await api(ct, "POST", `/jobs/${job.id}/applications/${a.id}/award`)).status, 400);
  });
});
```
Run: `node --env-file-if-exists=.env.test --test test/jobsRoutes.test.js`. Expected: PASS on the unchanged route. If it fails, fix the TEST until it describes today's behaviour truthfully (look at `lifecycle.WINDOWS.paymentMs` and `paystack.calculatePlatformFee` if a number differs), not the route.

- [ ] **Step 2: Add the failing closed-job tests.** HTTP (`test/jobsRoutes.test.js`, inside the award `describe`):

```js
  it("a closed job cannot be awarded (409 closed) and no contract is created", async () => {
    const job = await post();
    const a = (await api(ta, "POST", `/jobs/${job.id}/apply`)).json.application;
    await api(ct, "POST", `/jobs/${job.id}/close`);
    const r = await api(ct, "POST", `/jobs/${job.id}/applications/${a.id}/award`);
    assert.equal(r.status, 409);
    assert.equal(r.json.code, "closed");
    assert.equal(await prisma.contract.count({ where: { jobId: job.id } }), 0);
  });
```
and service level (`test/jobs.test.js`):

```js
describe("awardJob", () => {
  it("refuses a closed job, creates no contract, and leaves the application as it was", async () => {
    const job = await openJob();
    const app = await prisma.application.create({ data: { jobId: job.id, talentId: ctx.talentA.id } });
    await jobs.closeJob({ jobId: job.id, clientId: ctx.client.id });
    const r = await jobs.awardJob({ jobId: job.id, clientId: ctx.client.id, applicationId: app.id });
    assert.equal(r.code, "closed");
    assert.equal(await prisma.contract.count({ where: { jobId: job.id } }), 0);
    assert.equal((await prisma.job.findUnique({ where: { id: job.id } })).awardedApplicationId, null);
  });
});
```

- [ ] **Step 3: Run, expect FAIL** (HTTP: today's route returns 201 for a closed job; service: `jobs.awardJob is not a function`).

- [ ] **Step 4: Implement `awardJob`** in `src/jobs.js` (add `const paystack = require("./paystack"); const lifecycle = require("./contractLifecycle");` to the top; export `awardJob`). The body is today's route logic, with the transaction made interactive and claimed on the job row:

```js
/**
 * The single-award action (docs/core/correction-talent-discovery-screen.md):
 * one applicant selected, every other one not selected, the contract created
 * awaiting payment, all or nothing. The job row is claimed first (still open
 * and unawarded) so an award can never race a close or a second award.
 */
async function awardJob({ jobId, clientId, applicationId }, deps) {
  const { prisma } = baseDeps(deps);
  const job = await prisma.job.findUnique({ where: { id: jobId } });
  if (!job) return refuse(404, "not_found", "Job not found.");
  if (job.clientId !== clientId) return refuse(403, "not_yours", "Not your job.");
  if (job.closedAt) return refuse(409, "closed", MSG.closed);
  if (job.awardedApplicationId) return refuse(400, "awarded", MSG.awarded);

  const winning = await prisma.application.findUnique({ where: { id: applicationId } });
  if (!winning || winning.jobId !== job.id) return refuse(404, "not_found", "Application not found on this job.");

  const platformFeeAmount = paystack.calculatePlatformFee(job.budget);
  const contract = await prisma.$transaction(async (trx) => {
    const { count } = await trx.job.updateMany({
      where: { id: job.id, awardedApplicationId: null, closedAt: null },
      data: { awardedApplicationId: winning.id },
    });
    if (count === 0) return null;
    await trx.application.update({ where: { id: winning.id }, data: { status: "selected" } });
    await trx.application.updateMany({ where: { jobId: job.id, id: { not: winning.id } }, data: { status: "notSelected" } });
    return trx.contract.create({
      data: { jobId: job.id, status: "awaitingPayment", platformFeeAmount, payByAt: new Date(Date.now() + lifecycle.WINDOWS.paymentMs) },
    });
  });
  if (!contract) {
    const fresh = await prisma.job.findUnique({ where: { id: job.id } });
    return fresh?.closedAt ? refuse(409, "closed", MSG.closed) : refuse(400, "awarded", MSG.awarded);
  }
  await lifecycle.recordEvent(prisma, {
    jobId: job.id,
    contractId: contract.id,
    type: "awarded",
    meta: { applicationId: winning.id, payByAt: contract.payByAt },
  });
  return { ok: true, contract };
}
```

- [ ] **Step 5: Replace the award route's body** in `src/user/jobsRoutes.js` (keep the big doc comment above it) with:

```js
router.post("/:id/applications/:applicationId/award", requireClient, async (req, res) => {
  const result = await jobsService.awardJob({ jobId: req.params.id, clientId: req.user.id, applicationId: req.params.applicationId });
  if (!result.ok) return res.status(result.status).json({ error: result.error, code: result.code });
  return res.status(201).json({ contract: await serializeContract(result.contract) });
});
```

- [ ] **Step 6: Run `npm test`, expect PASS**, including the characterisation tests from Step 1 unchanged. If `recordEvent` is not exported by `contractLifecycle` under that name, fix the `require` (today's route calls `lifecycle.recordEvent`, so it is).

- [ ] **Step 7: Commit:**

```bash
git add src/jobs.js src/user/jobsRoutes.js test/jobs.test.js test/jobsRoutes.test.js
git commit -m "Award goes through the job service; a closed job can't be awarded

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 6: Races, and proof that the guards are what stop them

**Files:** Modify `test/jobs.test.js`. No production code unless a race test fails (then the guard is wrong).

`h.barrierPrisma(model, method)` holds the first two callers of `model.method` until both have arrived, so two "simultaneous" calls really do both pass their first read before either writes. Both functions under test call `job.findUnique` first, so that is the barrier.

- [ ] **Step 1: Write the race tests** (append to `test/jobs.test.js`):

```js
describe("races on the job row", () => {
  const ROUNDS = 6; // the winner is decided by timing, so run both orders several times
  const barrier = () => ({ prisma: h.barrierPrisma("job", "findUnique") });

  it("edit vs apply: exactly one wins, and an application never lands on edited terms", async () => {
    for (let i = 0; i < ROUNDS; i++) {
      const job = await openJob();
      const deps = barrier();
      const [e, a] = await Promise.all([
        jobs.editJob({ jobId: job.id, clientId: ctx.client.id, input: input() }, deps),
        jobs.applyToJob({ jobId: job.id, talentId: ctx.talentA.id, revision: 0 }, deps),
      ]);
      assert.equal([e, a].filter((r) => r.ok).length, 1, `round ${i}: ${JSON.stringify([e.code, a.code])}`);
      const after = await prisma.job.findUnique({ where: { id: job.id } });
      const applications = await prisma.application.count({ where: { jobId: job.id } });
      if (e.ok) {
        assert.equal(a.code, "terms_changed");
        assert.equal(applications, 0);
        assert.equal(after.revision, 1);
      } else {
        assert.equal(e.code, "has_applicants");
        assert.equal(applications, 1);
        assert.equal(after.revision, 0);
      }
    }
  });

  it("close vs apply: the job ends closed with no pending application, whatever the order", async () => {
    for (let i = 0; i < ROUNDS; i++) {
      const job = await openJob();
      const deps = barrier();
      const [c, a] = await Promise.all([
        jobs.closeJob({ jobId: job.id, clientId: ctx.client.id }, deps),
        jobs.applyToJob({ jobId: job.id, talentId: ctx.talentA.id }, deps),
      ]);
      assert.equal(c.ok, true, `round ${i}`);
      assert.ok((await prisma.job.findUnique({ where: { id: job.id } })).closedAt);
      assert.equal(await prisma.application.count({ where: { jobId: job.id, status: "pending" } }), 0, `round ${i}: a pending application survived the close`);
      if (a.ok) assert.equal(await prisma.application.count({ where: { jobId: job.id, status: "notSelected" } }), 1);
      else assert.equal(a.code, "closed");
    }
  });

  it("close vs award: exactly one wins and the job is never both closed and awarded", async () => {
    for (let i = 0; i < ROUNDS; i++) {
      const job = await openJob();
      const app = await prisma.application.create({ data: { jobId: job.id, talentId: ctx.talentA.id } });
      const deps = barrier();
      const [c, w] = await Promise.all([
        jobs.closeJob({ jobId: job.id, clientId: ctx.client.id }, deps),
        jobs.awardJob({ jobId: job.id, clientId: ctx.client.id, applicationId: app.id }, deps),
      ]);
      assert.equal([c, w].filter((r) => r.ok).length, 1, `round ${i}: ${JSON.stringify([c.code, w.code])}`);
      const after = await prisma.job.findUnique({ where: { id: job.id } });
      assert.ok(!(after.closedAt && after.awardedApplicationId), `round ${i}: closed AND awarded`);
      const contracts = await prisma.contract.count({ where: { jobId: job.id } });
      if (w.ok) { assert.equal(c.code, "awarded"); assert.equal(contracts, 1); }
      else { assert.equal(w.code, "closed"); assert.equal(contracts, 0); }
    }
  });

  it("two edits at once: both can win (no applicant yet), the revision counts both", async () => {
    const job = await openJob();
    const deps = barrier();
    const rs = await Promise.all([edit(job, { title: `${h.TITLE_PREFIX}one` }, ctx.client.id, deps), edit(job, { title: `${h.TITLE_PREFIX}two` }, ctx.client.id, deps)]);
    assert.equal(rs.every((r) => r.ok), true);
    assert.equal((await prisma.job.findUnique({ where: { id: job.id } })).revision, 2);
  });
});
```

- [ ] **Step 2: Run them, expect PASS** (`node --env-file-if-exists=.env.test --test test/jobs.test.js`).

- [ ] **Step 3: Mutation checks. Prove each race test can fail.** For each of the three removals below, make the change, run only the named test (`--test-name-pattern`), confirm it FAILS for the stated reason, then `git checkout src/jobs.js`:
  1. In `editJob`'s `where`, delete `lastAppliedAt: null, applications: { none: {} }` → "edit vs apply" fails (an edit and an application both succeed).
  2. In `applyToJob`'s claim, delete `closedAt: null,` from the `where` → "close vs apply" fails (a pending application survives).
  3. In `awardJob`'s claim, delete `closedAt: null` from the `where` → "close vs award" fails (closed AND awarded).
If a mutation does NOT make its test fail, the test is not exercising the race: strengthen it before going on. Record the outcome of each in the commit message.

- [ ] **Step 4: Run `npm test` on the restored code, expect PASS. Commit:**

```bash
git add test/jobs.test.js
git commit -m "Race tests for edit, close, apply and award (each guard mutation-checked)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 7: App plumbing: `Job.closedAt/revision`, `ApiException.code`, provider methods

**Files (mobile):** Modify `lib/data/models/job.dart`, `lib/data/api_client.dart`, `lib/presentation/providers/jobs_provider.dart`; create `test/job_model_test.dart`.

- [ ] **Step 1: Write the failing tests**, `test/job_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/job.dart';

Map<String, dynamic> _json({Map<String, dynamic> extra = const {}}) => {
  'id': 'j1',
  'title': 'Logo',
  'category': 'Design & creative',
  'description': 'd',
  'budget': '45000.00',
  'createdAt': '2026-10-20T10:00:00Z',
  'client': {'id': 'c1', 'fullName': 'Chinedu'},
  ...extra,
};

void main() {
  group('Job closed and revision', () {
    test('parse from the API', () {
      final j = Job.fromJson(_json(extra: {'closedAt': '2026-10-21T08:00:00Z', 'revision': 3}));
      expect(j.closed, isTrue);
      expect(j.closedAt, DateTime.utc(2026, 10, 21, 8));
      expect(j.revision, 3);
    });

    test('default to open and revision 0 when absent (older servers)', () {
      final j = Job.fromJson(_json());
      expect(j.closed, isFalse);
      expect(j.closedAt, isNull);
      expect(j.revision, 0);
    });

    test('copyWith keeps them', () {
      final j = Job.fromJson(_json(extra: {'closedAt': '2026-10-21T08:00:00Z', 'revision': 2}));
      final c = j.copyWith(applicationCount: 4);
      expect(c.closed, isTrue);
      expect(c.revision, 2);
    });
  });

  group('ApiException.fromResponse', () {
    test('reads the message and the machine-readable code', () {
      final e = ApiException.fromResponse(409, '{"error":"This job was just edited.","code":"terms_changed"}');
      expect(e.message, 'This job was just edited.');
      expect(e.status, 409);
      expect(e.code, 'terms_changed');
    });

    test('a body without a code leaves it null, and junk falls back to a plain message', () {
      expect(ApiException.fromResponse(400, '{"error":"title is required."}').code, isNull);
      final junk = ApiException.fromResponse(502, '<html>bad gateway</html>');
      expect(junk.message, 'Something went wrong.');
      expect(junk.code, isNull);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** (`cd "C:/mobile-projects/flutter/kings domain/king-domain-mobile" && flutter test test/job_model_test.dart`): compile errors, `closed`, `closedAt`, `revision`, `fromResponse` and `code` are not defined.

- [ ] **Step 3: Implement.** `job.dart`: add `final DateTime? closedAt;` (doc: set when the client closed the job before awarding it) and `final int revision;` (doc: bumped on every edit; sent with an application) after `awardedApplicationId`; add `bool get closed => closedAt != null;`; constructor `this.closedAt, this.revision = 0,`; `fromJson`: `closedAt: DateTime.tryParse(json['closedAt'] as String? ?? ''), revision: json['revision'] as int? ?? 0,`; in `copyWith`'s returned `Job(` add `closedAt: closedAt, revision: revision,`. `api_client.dart`: replace the `ApiException` class with

```dart
class ApiException implements Exception {
  final String message;
  final int status;
  /// A stable machine-readable reason when the server sends one ('terms_changed'),
  /// so the app can react to it without matching message text.
  final String? code;
  ApiException(this.message, this.status, {this.code});

  factory ApiException.fromResponse(int status, String body) {
    Map<String, dynamic>? data;
    try {
      data = body.isEmpty ? null : jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }
    return ApiException((data?['error'] as String?) ?? 'Something went wrong.', status, code: data?['code'] as String?);
  }

  @override
  String toString() => message;
}
```
and in `_request` change the error branch to `throw ApiException.fromResponse(response.statusCode, response.body);` (leave the success-path `data` parsing as is). `jobs_provider.dart`: replace `applyTo` and add the two methods:

```dart
  /// [revision] is the job revision the talent read; the server refuses the
  /// application (code 'terms_changed') if the client edited the job since.
  Future<void> applyTo(String jobId, {int? revision}) async {
    await ApiClient.instance.post('/jobs/$jobId/apply', body: revision == null ? null : {'revision': revision});
    await refresh();
  }

  /// Client: change an open job nobody has applied to yet.
  Future<Job> editJob(
    String jobId, {
    required String title,
    required String category,
    required String description,
    required double budget,
    required int deliveryDays,
  }) async {
    final data = await ApiClient.instance.patch(
      '/jobs/$jobId',
      body: {'title': title, 'category': category, 'description': description, 'budget': budget, 'deliveryDays': deliveryDays},
    );
    await refresh();
    return Job.fromJson(data['job'] as Map<String, dynamic>);
  }

  /// Client: close an open job for good. Pending applicants are told it closed.
  Future<void> closeJob(String jobId) async {
    await ApiClient.instance.post('/jobs/$jobId/close');
    await refresh();
  }
```

- [ ] **Step 4: Run `flutter test test/job_model_test.dart`, expect PASS; then `flutter analyze`, expect `No issues found!`.**

- [ ] **Step 5: Commit:**

```bash
git add lib/data/models/job.dart lib/data/api_client.dart lib/presentation/providers/jobs_provider.dart test/job_model_test.dart
git commit -m "App: job closedAt and revision, ApiException.code, edit/close/apply-with-revision calls

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 8: "Applied" on the Work tab

**Files:** Create `lib/presentation/screens/shell/applied_jobs.dart`, `test/work_applied_test.dart`; modify `lib/presentation/screens/shell/work_tab.dart`; amend the spec's status line.

**Interfaces:** Produces `List<Job> appliedJobs(List<Job>)`, `({String text, KdTone tone}) appliedStatusLine(Job)`, `class AppliedTile` (`job`, `onTap`).

- [ ] **Step 1: Write the failing tests**, `test/work_applied_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/jobs/job_detail_screen.dart';
import 'package:king_domain/presentation/screens/shell/applied_jobs.dart';
import 'package:king_domain/presentation/screens/shell/work_tab.dart';
import 'package:king_domain/presentation/widgets/kit/status_pill.dart';

final _now = DateTime.now();

Job _job(String id, {JobApplicationStatus app = JobApplicationStatus.notApplied, ContractStatus? contract, DateTime? closedAt, Duration age = const Duration(hours: 2)}) => Job(
  id: id,
  title: 'Job $id',
  category: 'Design & creative',
  description: 'd',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(age),
  contractStatus: contract,
  applicationStatus: app,
  closedAt: closedAt,
  awardedApplicationId: contract != null ? 'a1' : null,
  deliveryDays: 5,
  deliverByAt: _now.add(const Duration(days: 3)),
);

class _Jobs extends JobsNotifier {
  _Jobs(this.jobs, {this.fail = false});
  final List<Job> jobs;
  final bool fail;
  @override
  Future<List<Job>> build() async {
    if (fail) throw Exception('offline');
    return jobs;
  }
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile(headline: 'h', bio: 'b', skillCategories: ['Design & creative'], proofItems: []);
}

Future<void> _show(WidgetTester tester, JobsNotifier jobs, {VoidCallback? onBrowse}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [jobsProvider.overrideWith(() => jobs), talentProfileProvider.overrideWith(_Profile.new)],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: Scaffold(body: WorkTab(onBrowseJobs: onBrowse ?? () {})),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('appliedJobs', () {
    test('keeps pending and not-picked applications only; selected ones are contracts, never-applied ones are not mine', () {
      final jobs = [
        _job('pending', app: JobApplicationStatus.pending),
        _job('lost', app: JobApplicationStatus.rejected),
        _job('won', app: JobApplicationStatus.accepted, contract: ContractStatus.funded),
        _job('none'),
      ];
      expect(appliedJobs(jobs).map((j) => j.id), ['pending', 'lost']);
    });

    test('waiting first, then newest first', () {
      final jobs = [
        _job('old-lost', app: JobApplicationStatus.rejected, age: const Duration(days: 9)),
        _job('new-lost', app: JobApplicationStatus.rejected, age: const Duration(days: 1)),
        _job('old-wait', app: JobApplicationStatus.pending, age: const Duration(days: 8)),
        _job('new-wait', app: JobApplicationStatus.pending, age: const Duration(days: 2)),
      ];
      expect(appliedJobs(jobs).map((j) => j.id), ['new-wait', 'old-wait', 'new-lost', 'old-lost']);
    });
  });

  group('appliedStatusLine', () {
    test('waiting is amber and names the client', () {
      final s = appliedStatusLine(_job('a', app: JobApplicationStatus.pending));
      expect(s.text, 'Waiting for Chinedu to pick');
      expect(s.tone, KdTone.warn);
    });

    test('not picked is neutral, closed by the client says so', () {
      final lost = appliedStatusLine(_job('a', app: JobApplicationStatus.rejected));
      expect(lost.text, 'Not picked');
      expect(lost.tone, KdTone.plain);
      final closed = appliedStatusLine(_job('b', app: JobApplicationStatus.rejected, closedAt: _now));
      expect(closed.text, 'Closed by the client');
      expect(closed.tone, KdTone.plain);
    });
  });

  group('Work tab segments', () {
    testWidgets('the Awarded segment is shown first, with counts on both labels', (tester) async {
      await _show(tester, _Jobs([
        _job('won', app: JobApplicationStatus.accepted, contract: ContractStatus.funded),
        _job('w1', app: JobApplicationStatus.pending),
        _job('w2', app: JobApplicationStatus.rejected),
      ]));
      expect(find.text('Awarded · 1'), findsOneWidget);
      expect(find.text('Applied · 2'), findsOneWidget);
      expect(find.text('Job won'), findsOneWidget);
      expect(find.text('Job w1'), findsNothing);
    });

    testWidgets('the Applied segment lists waiting first and shows each status line', (tester) async {
      await _show(tester, _Jobs([
        _job('lost', app: JobApplicationStatus.rejected, age: const Duration(days: 1)),
        _job('wait', app: JobApplicationStatus.pending),
        _job('closed', app: JobApplicationStatus.rejected, closedAt: _now, age: const Duration(days: 3)),
      ]));
      await tester.tap(find.text('Applied · 3'));
      await tester.pumpAndSettle();
      final order = ['Job wait', 'Job lost', 'Job closed'];
      final ys = order.map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('Waiting for Chinedu to pick'), findsOneWidget);
      expect(find.text('Not picked'), findsOneWidget);
      expect(find.text('Closed by the client'), findsOneWidget);
    });

    testWidgets('empty Applied says why and Browse jobs works', (tester) async {
      var browsed = false;
      await _show(tester, _Jobs(const []), onBrowse: () => browsed = true);
      await tester.tap(find.text('Applied · 0'));
      await tester.pumpAndSettle();
      expect(find.text('No applications yet'), findsOneWidget);
      await tester.tap(find.text('Browse jobs'));
      expect(browsed, isTrue);
    });

    testWidgets('a load error shows Retry on the Applied segment too', (tester) async {
      await _show(tester, _Jobs(const [], fail: true));
      await tester.tap(find.text('Applied · 0'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Couldn\'t load'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('tapping an applied job opens it', (tester) async {
      await _show(tester, _Jobs([_job('wait', app: JobApplicationStatus.pending)]));
      await tester.tap(find.text('Applied · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Job wait'));
      await tester.pumpAndSettle();
      expect(find.byType(JobDetailScreen), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run, expect FAIL** (`flutter test test/work_applied_test.dart`): `applied_jobs.dart` does not exist.

- [ ] **Step 3: Create `lib/presentation/screens/shell/applied_jobs.dart`:**

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../data/models/job.dart';
import '../../widgets/kit/kd_card.dart';

/// Jobs the viewer applied to that did not become theirs: still waiting, or
/// not picked. A selected application is a contract and lives under Awarded.
/// Waiting first, then newest first.
List<Job> appliedJobs(List<Job> jobs) {
  int rank(Job j) => j.applicationStatus == JobApplicationStatus.pending ? 0 : 1;
  final list = jobs
      .where((j) => j.applicationStatus == JobApplicationStatus.pending || j.applicationStatus == JobApplicationStatus.rejected)
      .toList();
  list.sort((a, b) {
    final r = rank(a) - rank(b);
    return r != 0 ? r : b.postedAt.compareTo(a.postedAt);
  });
  return list;
}

/// One line on where an application stands. Amber means waiting on someone;
/// "not picked" and "closed" are neutral, never red (nothing was missed).
({String text, KdTone tone}) appliedStatusLine(Job job) {
  if (job.closed) return (text: 'Closed by the client', tone: KdTone.plain);
  return switch (job.applicationStatus) {
    JobApplicationStatus.pending => (text: 'Waiting for ${job.clientName} to pick', tone: KdTone.warn),
    JobApplicationStatus.rejected => (text: 'Not picked', tone: KdTone.plain),
    _ => (text: '', tone: KdTone.plain),
  };
}

/// An application in the Applied list: title, client, budget and the status line.
class AppliedTile extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const AppliedTile({super.key, required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = appliedStatusLine(job);
    final ink = status.tone == KdTone.plain ? AppColors.text2 : toneInk(status.tone);
    return KdCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(job.clientName, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis)),
              Text(formatNaira(job.budget), style: AppTextStyles.title.copyWith(color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(status.text, style: AppTextStyles.bodySmall.copyWith(color: ink, fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Change `work_tab.dart`.** Turn `WorkTab` into a `ConsumerStatefulWidget` that keeps `static List<Job> mine(...)` unchanged and holds `bool _applied = false`. Imports added: `kd_chip.dart`, `applied_jobs.dart`, `../jobs/job_detail_screen.dart`. In `build`, after computing `work`: `final applied = appliedJobs(jobsAsync.valueOrNull ?? const []);`. The loading and error branches stay as they are for both segments. The data branch becomes:

```dart
    } else if (!_applied) {
      body = work.isEmpty ? EmptyState(/* existing "No work yet" empty state, unchanged */) : /* existing list of ContractTile */;
    } else if (applied.isEmpty) {
      body = EmptyState(
        icon: Icons.outbox_outlined,
        title: 'No applications yet',
        body: 'Apply to a job you\'re verified for and it shows up here until the client picks someone.',
        actionLabel: 'Browse jobs',
        onAction: widget.onBrowseJobs,
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < applied.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RiseIn(
                key: ValueKey('applied-${applied[i].id}'),
                delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                child: AppliedTile(
                  job: applied[i],
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: applied[i].id))),
                ),
              ),
            ),
        ],
      );
    }
```
and the list children become `ScreenHeader(...)`, a segment row, then `body`:

```dart
          Row(
            children: [
              KdChoiceChip(label: 'Awarded · ${work.length}', selected: !_applied, onTap: () => setState(() => _applied = false)),
              const SizedBox(width: 8),
              KdChoiceChip(label: 'Applied · ${applied.length}', selected: _applied, onTap: () => setState(() => _applied = true)),
            ],
          ),
          const SizedBox(height: 16),
```
(`onBrowseJobs` becomes `widget.onBrowseJobs`; the "needs you" header count stays tied to Awarded.) The empty-state text for the Awarded segment stays exactly as today.

- [ ] **Step 5: Run `flutter test test/work_applied_test.dart`, expect PASS; then the whole suite** (`flutter test`) because `shell_tabs_test.dart` drives this tab. Fix any existing test that now sees the new chips by making it more specific, never by weakening what it asserts.

- [ ] **Step 6: Amend the spec** (`work-gaps-applications-stepper-job-edit.md`): in the item 1 table change "Waiting for the client to pick" to "Waiting for {client name} to pick", matching the app's wording elsewhere ("Waiting for Chinedu to pay").

- [ ] **Step 7: `flutter analyze`, expect clean. Commit:**

```bash
git add lib/presentation/screens/shell/applied_jobs.dart lib/presentation/screens/shell/work_tab.dart test/work_applied_test.dart docs/features/work-gaps-applications-stepper-job-edit.md
git commit -m "Work tab: Applied segment with each application's status

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 9: The lifecycle stepper

**Files:** Create `lib/presentation/widgets/contract/lifecycle_stepper.dart`, `test/lifecycle_stepper_test.dart`; modify `contract_detail_screen.dart` and `client_contract_screen.dart` (insert the stepper), and fix any existing assertions that now match twice.

**Interfaces:** Produces `enum StepProgress { done, current, later }`; `class LifecycleStep { final String label; final String? subtitle; final StepProgress progress; final KdTone tone; final IconData icon; }`; `List<LifecycleStep> lifecycleSteps(Job job, {required bool forClient})` (requires `job.contractStatus != null`); `class LifecycleStepper extends StatelessWidget { final Job job; final bool forClient; }`.

Rules (the spec table): current step index by status: awaitingPayment 1; funded, inProgress, changesRequested 2; submitted, disputed 3; approved: every step done. Labels: `Awarded`, `Payment secured`, `Working on it`, `Client reviews`, then step 5 is `You're paid` (talent) or `Talent is paid` (client). Tone of the current step: red for disputed or an overdue inProgress; otherwise violet when it is the viewer's turn (`contractNeedsYou`, plus inProgress for the talent), amber when the viewer is waiting. Subtitles: below.

- [ ] **Step 1: Write the failing tests**, `test/lifecycle_stepper_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/presentation/widgets/contract/lifecycle_stepper.dart';
import 'package:king_domain/presentation/widgets/kit/status_pill.dart';

final _now = DateTime.now();

Job _job(ContractStatus s, {bool overdue = false, int changeRounds = 0, DateTime? payByAt, DateTime? deliverByAt, DateTime? reviewDueAt}) => Job(
  id: 'j1',
  title: 'Logo',
  category: 'Design & creative',
  description: 'd',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now,
  contractStatus: s,
  platformFeeAmount: 4500,
  deliveryDays: 5,
  overdue: overdue,
  changeRounds: changeRounds,
  payByAt: payByAt,
  deliverByAt: deliverByAt,
  reviewDueAt: reviewDueAt,
);

List<StepProgress> _progress(List<LifecycleStep> s) => s.map((e) => e.progress).toList();
const D = StepProgress.done, C = StepProgress.current, L = StepProgress.later;

void main() {
  group('which steps are done, current and later', () {
    final table = <ContractStatus, List<StepProgress>>{
      ContractStatus.awaitingPayment: [D, C, L, L, L],
      ContractStatus.funded: [D, D, C, L, L],
      ContractStatus.inProgress: [D, D, C, L, L],
      ContractStatus.changesRequested: [D, D, C, L, L],
      ContractStatus.submitted: [D, D, D, C, L],
      ContractStatus.disputed: [D, D, D, C, L],
      ContractStatus.approved: [D, D, D, D, D],
    };
    for (final e in table.entries) {
      for (final forClient in [false, true]) {
        test('${e.key.name} as ${forClient ? 'client' : 'talent'}', () {
          expect(_progress(lifecycleSteps(_job(e.key), forClient: forClient)), e.value);
        });
      }
    }
  });

  group('labels', () {
    test('five steps; the last one is worded for the viewer', () {
      final talent = lifecycleSteps(_job(ContractStatus.funded), forClient: false).map((s) => s.label).toList();
      expect(talent, ['Awarded', 'Payment secured', 'Working on it', 'Client reviews', 'You\'re paid']);
      final client = lifecycleSteps(_job(ContractStatus.funded), forClient: true).map((s) => s.label).toList();
      expect(client.last, 'Talent is paid');
    });
  });

  group('tone of the current step', () {
    KdTone tone(ContractStatus s, {required bool forClient, bool overdue = false}) =>
        lifecycleSteps(_job(s, overdue: overdue), forClient: forClient).firstWhere((x) => x.progress == StepProgress.current).tone;

    test('violet when it is your turn, amber when you are waiting', () {
      expect(tone(ContractStatus.awaitingPayment, forClient: true), KdTone.brand);
      expect(tone(ContractStatus.awaitingPayment, forClient: false), KdTone.warn);
      expect(tone(ContractStatus.funded, forClient: false), KdTone.brand);
      expect(tone(ContractStatus.funded, forClient: true), KdTone.warn);
      expect(tone(ContractStatus.inProgress, forClient: false), KdTone.brand);
      expect(tone(ContractStatus.inProgress, forClient: true), KdTone.warn);
      expect(tone(ContractStatus.submitted, forClient: true), KdTone.brand);
      expect(tone(ContractStatus.submitted, forClient: false), KdTone.warn);
      expect(tone(ContractStatus.changesRequested, forClient: false), KdTone.brand);
      expect(tone(ContractStatus.changesRequested, forClient: true), KdTone.warn);
    });

    test('red for a dispute and for a missed delivery date', () {
      expect(tone(ContractStatus.disputed, forClient: true), KdTone.bad);
      expect(tone(ContractStatus.inProgress, forClient: false, overdue: true), KdTone.bad);
    });
  });

  group('subtitles use real data and say nothing about where money is held', () {
    String? sub(Job j, int i, {required bool forClient}) => lifecycleSteps(j, forClient: forClient)[i].subtitle;

    test('awaiting payment: the client is told how long they have, the talent who they wait for', () {
      final j = _job(ContractStatus.awaitingPayment, payByAt: _now.add(const Duration(hours: 23, minutes: 30)));
      expect(sub(j, 1, forClient: true), startsWith('Pay within 23h'));
      expect(sub(j, 1, forClient: false), 'Waiting for Chinedu to pay');
    });

    test('paid: says who paid, with the total the client paid on the client side', () {
      final j = _job(ContractStatus.funded);
      expect(sub(j, 1, forClient: false), 'Chinedu has paid');
      expect(sub(j, 1, forClient: true), contains('₦49,500'));
    });

    test('in progress shows the time left, or the missed date when overdue', () {
      final due = _job(ContractStatus.inProgress, deliverByAt: _now.add(const Duration(days: 2, hours: 1)));
      expect(sub(due, 2, forClient: false), startsWith('Due in 2d'));
      final late = _job(ContractStatus.inProgress, overdue: true, deliverByAt: _now.subtract(const Duration(days: 4)));
      expect(sub(late, 2, forClient: false), '3 days past the delivery date');
    });

    test('changes requested names the round', () {
      final j = _job(ContractStatus.changesRequested, changeRounds: 1);
      expect(sub(j, 2, forClient: false), 'Changes requested, round 1 of 2');
    });

    test('in review: the talent waits for the client; the client is told to review; a later step explains the window', () {
      final j = _job(ContractStatus.submitted, reviewDueAt: _now.add(const Duration(days: 3)));
      expect(sub(j, 3, forClient: true), 'Review it now');
      expect(sub(j, 3, forClient: false), startsWith('Waiting for Chinedu'));
      final working = _job(ContractStatus.inProgress);
      expect(sub(working, 3, forClient: false), 'Up to 3 days to approve or ask for changes');
    });

    test('disputed is with an admin; the last step reads as a payout, not a holding', () {
      expect(sub(_job(ContractStatus.disputed), 3, forClient: true), 'With a King Domain admin');
      expect(sub(_job(ContractStatus.approved), 4, forClient: false), 'Paid to your payout account');
      expect(sub(_job(ContractStatus.approved), 4, forClient: true), 'Paid out to the talent');
      for (final s in ContractStatus.values) {
        for (final c in [false, true]) {
          for (final step in lifecycleSteps(_job(s), forClient: c)) {
            expect(step.subtitle ?? '', isNot(contains('held')), '${s.name} ${step.label}');
          }
        }
      }
    });
  });

  group('the widget', () {
    Future<void> show(WidgetTester tester, Job job, {required bool forClient, bool reduceMotion = true}) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
        home: Scaffold(body: SingleChildScrollView(child: LifecycleStepper(job: job, forClient: forClient))),
      ));
      await tester.pump();
    }

    testWidgets('shows all five labels', (tester) async {
      await show(tester, _job(ContractStatus.inProgress, deliverByAt: _now.add(const Duration(days: 2))), forClient: false);
      for (final l in ['Awarded', 'Payment secured', 'Working on it', 'Client reviews', 'You\'re paid']) {
        expect(find.text(l), findsOneWidget);
      }
    });

    testWidgets('each step announces its position and state to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, _job(ContractStatus.submitted), forClient: false);
      expect(find.bySemanticsLabel(RegExp(r'^Step 3 of 5: Working on it, done')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Step 4 of 5: Client reviews, current')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Step 5 of 5: You\x27re paid, later')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a waiting step pulses unless motion is reduced', (tester) async {
      final waiting = _job(ContractStatus.submitted);
      await show(tester, waiting, forClient: false, reduceMotion: false);
      expect(find.byType(PulseDot), findsOneWidget);
      await show(tester, _job(ContractStatus.approved), forClient: false);
      expect(find.byType(PulseDot), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run, expect FAIL** (compile error: `lifecycle_stepper.dart` does not exist). Note on the pulse test: `PulseDot` itself stops animating under reduced motion, so the test asserts presence only when motion is allowed; if the final `show(...)` for `approved` leaves a stale tree, wrap each case in its own `testWidgets`.

- [ ] **Step 3: Create `lib/presentation/widgets/contract/lifecycle_stepper.dart`:**

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/job.dart';
import '../kit/kd_card.dart';
import '../kit/status_pill.dart';
import 'contract_parts.dart';

enum StepProgress { done, current, later }

class LifecycleStep {
  final String label;
  final String? subtitle;
  final StepProgress progress;
  final KdTone tone;
  final IconData icon;
  const LifecycleStep({required this.label, required this.subtitle, required this.progress, required this.tone, required this.icon});
}

const _icons = [
  Icons.how_to_reg_outlined,
  Icons.lock_outline_rounded,
  Icons.work_outline_rounded,
  Icons.rate_review_outlined,
  Icons.account_balance_outlined,
];

/// The five steps of a contract, derived only from the contract's status and
/// dates. The words say what happened ("has paid", "paid to your payout
/// account"), never where money is held.
List<LifecycleStep> lifecycleSteps(Job job, {required bool forClient}) {
  final status = job.contractStatus!;
  final current = switch (status) {
    ContractStatus.awaitingPayment => 1,
    ContractStatus.funded || ContractStatus.inProgress || ContractStatus.changesRequested => 2,
    ContractStatus.submitted || ContractStatus.disputed => 3,
    ContractStatus.approved => -1,
  };
  final allDone = status == ContractStatus.approved;

  StepProgress progressOf(int i) => allDone || i < current ? StepProgress.done : (i == current ? StepProgress.current : StepProgress.later);

  final overdue = status == ContractStatus.inProgress && job.overdue;
  final yourTurn = status == ContractStatus.inProgress ? !forClient : contractNeedsYou(job, forClient: forClient);
  final currentTone = status == ContractStatus.disputed || overdue ? KdTone.bad : (yourTurn ? KdTone.brand : KdTone.warn);

  final client = job.clientName;
  String left(DateTime? t, String unknown) => t == null ? unknown : (timeLeft(t) ?? 'now');

  String? subtitle(int i, StepProgress p) {
    switch (i) {
      case 0:
        return forClient ? 'You picked a talent' : 'Picked by $client';
      case 1:
        if (p == StepProgress.current) {
          return forClient ? 'Pay within ${left(job.payByAt, '24 hours')}' : 'Waiting for $client to pay';
        }
        if (p == StepProgress.done) return forClient ? 'You paid ${formatNaira(job.clientTotal)}' : '$client has paid';
        return null;
      case 2:
        if (p == StepProgress.current) {
          return switch (status) {
            ContractStatus.funded => forClient ? 'Waiting for the talent to start' : 'Start when you\'re ready',
            ContractStatus.changesRequested => 'Changes requested, round ${job.changeRounds} of ${Job.maxChangeRounds}',
            _ => overdue ? '3 days past the delivery date' : (job.deliverByAt == null ? 'In progress' : 'Due in ${left(job.deliverByAt, 'time')}'),
          };
        }
        return p == StepProgress.done ? 'Delivered' : null;
      case 3:
        if (status == ContractStatus.disputed) return 'With a ${AppBrand.name} admin';
        if (p == StepProgress.current) {
          if (forClient) return 'Review it now';
          return job.reviewDueAt == null ? 'Waiting for $client' : 'Waiting for $client · by ${formatDeadline(job.reviewDueAt!)}';
        }
        return p == StepProgress.done ? 'Approved' : 'Up to 3 days to approve or ask for changes';
      default:
        return forClient ? 'Paid out to the talent' : 'Paid to your payout account';
    }
  }

  const labels = ['Awarded', 'Payment secured', 'Working on it', 'Client reviews'];
  return [
    for (var i = 0; i < 5; i++)
      LifecycleStep(
        label: i < 4 ? labels[i] : (forClient ? 'Talent is paid' : 'You\'re paid'),
        subtitle: subtitle(i, progressOf(i)),
        progress: progressOf(i),
        tone: progressOf(i) == StepProgress.current ? currentTone : (progressOf(i) == StepProgress.done ? KdTone.ok : KdTone.plain),
        icon: _icons[i],
      ),
  ];
}

/// The contract's five steps as a vertical rail: done (green check), the
/// current one in the tone of whose turn it is, later ones muted.
class LifecycleStepper extends StatelessWidget {
  final Job job;
  final bool forClient;
  const LifecycleStepper({super.key, required this.job, required this.forClient});

  @override
  Widget build(BuildContext context) {
    final steps = lifecycleSteps(job, forClient: forClient);
    return KdCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        children: [for (var i = 0; i < steps.length; i++) _StepRow(index: i, step: steps[i], last: i == steps.length - 1)],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final LifecycleStep step;
  final bool last;
  const _StepRow({required this.index, required this.step, required this.last});

  @override
  Widget build(BuildContext context) {
    final done = step.progress == StepProgress.done;
    final current = step.progress == StepProgress.current;
    final ink = done ? AppColors.ok : (current ? toneInk(step.tone) : AppColors.text3);
    final nodeFill = done ? AppColors.okSoft : (current ? toneSurface(step.tone) : AppColors.surface3);
    final stateWord = done ? 'done' : (current ? 'current' : 'later');
    final waiting = current && step.tone == KdTone.warn;

    return Semantics(
      container: true,
      label: 'Step ${index + 1} of 5: ${step.label}, $stateWord${step.subtitle == null ? '' : ', ${step.subtitle}'}',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 30,
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: nodeFill, shape: BoxShape.circle),
                      child: Icon(done ? Icons.check_rounded : step.icon, size: 16, color: ink),
                    ),
                    if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: done ? AppColors.ok : AppColors.surface3)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 6 : 14, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              step.label,
                              style: AppTextStyles.title.copyWith(fontSize: 14.5, color: step.progress == StepProgress.later ? AppColors.text3 : AppColors.text),
                            ),
                          ),
                          if (waiting) ...[const SizedBox(width: 8), PulseDot(color: ink, size: 6)],
                        ],
                      ),
                      if (step.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(step.subtitle!, style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5, color: current ? ink : AppColors.text2)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```
(Verify `AppColors.okSoft` exists; if the soft green token is named differently, use the existing one that `toneSurface(KdTone.ok)` resolves to. `AppBrand.name` is "King Domain", so the disputed subtitle matches the test while the name is unchanged; if the name ever changes, change the test to use `AppBrand.name`.)

- [ ] **Step 4: Run `flutter test test/lifecycle_stepper_test.dart`, expect PASS.**

- [ ] **Step 5: Show it on both contract screens.** In `contract_detail_screen.dart`, add `import '../../widgets/contract/lifecycle_stepper.dart';` and make the stepper the first entry of `cards`: `LifecycleStepper(job: job, forClient: false),` before `..._stateCards(...)`. In `client_contract_screen.dart` do the same with `forClient: true`. Then write one assertion per screen in `test/stage2_screens_test.dart` (use that file's existing helpers) that the five labels are present for a funded contract.

- [ ] **Step 6: Run the whole suite** (`flutter test`). Existing tests that look for a text now shown twice (`Payment secured` appears as the stepper label and, on the talent's funded screen, as an existing notice title) must be made precise (`find.descendant(of: find.byType(NoticeCard), matching: find.text('Payment secured'))`), never loosened to `findsWidgets` without a reason. Then `flutter analyze`, expect clean.

- [ ] **Step 7: Commit:**

```bash
git add lib/presentation/widgets/contract/lifecycle_stepper.dart lib/presentation/screens/contracts/contract_detail_screen.dart lib/presentation/screens/client/client_contract_screen.dart test/lifecycle_stepper_test.dart test/stage2_screens_test.dart
git commit -m "Contract screens: five-step lifecycle stepper for the talent and the client

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 10: Edit and close a job (client side)

**Files:** Modify `lib/presentation/widgets/contract/contract_parts.dart` (`ContractHeader.action`), `post_job_screen.dart`, `applicants_screen.dart`, `client_jobs_tab.dart`; create `test/edit_close_job_test.dart`.

- [ ] **Step 1: Write the failing tests**, `test/edit_close_job_test.dart` (reuse the `_Jobs` recording-notifier pattern from `applicants_and_submit_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/contract_history.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/screens/client/applicants_screen.dart';
import 'package:king_domain/presentation/screens/client/post_job_screen.dart';
import 'package:king_domain/presentation/screens/shell/client_jobs_tab.dart';

final _now = DateTime.now();

Job _job({int applicants = 0, DateTime? closedAt, ContractStatus? contract, String? awarded}) => Job(
  id: 'j1',
  title: 'Logo and brand kit',
  category: 'Design & creative',
  description: 'A long enough description of the work.',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(const Duration(days: 1)),
  applicationCount: applicants,
  closedAt: closedAt,
  contractStatus: contract,
  awardedApplicationId: awarded,
  deliveryDays: 5,
);

class _Jobs extends JobsNotifier {
  _Jobs(this.job, {this.editError, this.closeError});
  Job job;
  final ApiException? editError;
  final ApiException? closeError;
  final calls = <String>[];

  @override
  Future<List<Job>> build() async => [job];
  @override
  Future<List<JobApplication>> listApplications(String jobId) async => const [];
  @override
  Future<Job> editJob(String jobId, {required String title, required String category, required String description, required double budget, required int deliveryDays}) async {
    calls.add('edit:$title|$category|$description|${budget.round()}|$deliveryDays');
    if (editError != null) throw editError!;
    return job;
  }

  @override
  Future<void> closeJob(String jobId) async {
    calls.add('close:$jobId');
    if (closeError != null) throw closeError!;
  }
}

Future<void> _show(WidgetTester tester, Widget screen, _Jobs jobs) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [jobsProvider.overrideWith(() => jobs), contractHistoryProvider('j1').overrideWith((ref) async => const ContractHistory())],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  group('the manage menu on the applicants screen', () {
    testWidgets('an open job with no applicants offers Edit and Close', (tester) async {
      await _show(tester, ApplicantsScreen(job: _job()), _Jobs(_job()));
      await tester.tap(find.byTooltip('Manage this job'));
      await tester.pumpAndSettle();
      expect(find.text('Edit job'), findsOneWidget);
      expect(find.text('Close job'), findsOneWidget);
      expect(find.text('Terms are locked'), findsNothing);
    });

    testWidgets('once someone has applied, Edit is replaced by why the terms are locked', (tester) async {
      await _show(tester, ApplicantsScreen(job: _job(applicants: 2)), _Jobs(_job(applicants: 2)));
      await tester.tap(find.byTooltip('Manage this job'));
      await tester.pumpAndSettle();
      expect(find.text('Edit job'), findsNothing);
      expect(find.text('Terms are locked'), findsOneWidget);
      expect(find.textContaining('Close it and post a new one'), findsOneWidget);
      expect(find.text('Close job'), findsOneWidget);
    });

    testWidgets('an awarded job and a closed job have no menu', (tester) async {
      await _show(tester, ApplicantsScreen(job: _job(contract: ContractStatus.awaitingPayment, awarded: 'a1')), _Jobs(_job(contract: ContractStatus.awaitingPayment, awarded: 'a1')));
      expect(find.byTooltip('Manage this job'), findsNothing);
      await _show(tester, ApplicantsScreen(job: _job(closedAt: _now)), _Jobs(_job(closedAt: _now)));
      expect(find.byTooltip('Manage this job'), findsNothing);
    });
  });

  group('closing a job', () {
    testWidgets('the confirmation says how many applicants will see it closed, then closes and leaves the screen', (tester) async {
      final jobs = _Jobs(_job(applicants: 3));
      await _show(tester, Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => ApplicantsScreen(job: _job(applicants: 3)))), child: const Text('open'))))), jobs);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Manage this job'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close job'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 applicants'), findsOneWidget);
      expect(find.textContaining('can\'t be undone'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Close job').first);
      await tester.pumpAndSettle();
      expect(jobs.calls, ['close:j1']);
      expect(find.byType(ApplicantsScreen), findsNothing);
      await _drainToasts(tester);
    });

    testWidgets('a refusal from the server is shown and nothing closes', (tester) async {
      final jobs = _Jobs(_job(), closeError: ApiException('This job has already been awarded.', 409, code: 'awarded'));
      await _show(tester, ApplicantsScreen(job: _job()), jobs);
      await tester.tap(find.byTooltip('Manage this job'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close job'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Close job').first);
      await tester.pumpAndSettle();
      expect(find.text('This job has already been awarded.'), findsOneWidget);
      expect(find.byType(ApplicantsScreen), findsOneWidget);
      await _drainToasts(tester);
    });
  });

  group('a closed job', () {
    testWidgets('the applicants screen is read-only and says it was closed', (tester) async {
      await _show(tester, ApplicantsScreen(job: _job(closedAt: _now)), _Jobs(_job(closedAt: _now)));
      expect(find.text('Closed'), findsWidgets);
      expect(find.textContaining('You closed this job'), findsOneWidget);
      expect(find.textContaining('Pick '), findsNothing);
    });
  });

  group('edit mode', () {
    testWidgets('opens filled with the job, saves the changes, and leaves', (tester) async {
      final jobs = _Jobs(_job());
      await _show(tester, Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => PostJobScreen(editing: _job()))), child: const Text('open'))))), jobs);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Edit job'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Logo and brand kit'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Logo and brand kit'), 'Logo, brand kit and guide');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(jobs.calls.single, 'edit:Logo, brand kit and guide|Design & creative|A long enough description of the work.|45000|5');
      expect(find.text('Save changes'), findsNothing);
      await _drainToasts(tester);
    });

    testWidgets('a locked job shows the server\'s reason and stays on the form', (tester) async {
      final jobs = _Jobs(_job(), editError: ApiException('Someone has already applied, so the terms are locked. Close this job and post a new one to change them.', 409, code: 'has_applicants'));
      await _show(tester, PostJobScreen(editing: _job()), jobs);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Someone has already applied'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('posting a new job is unchanged: the button still says Post job', (tester) async {
      await _show(tester, const Scaffold(body: PostJobScreen()), _Jobs(_job()));
      expect(find.text('Post job'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
    });
  });

  group('the client\'s list', () {
    testWidgets('a closed job shows a Closed pill and sorts after open ones', (tester) async {
      final open = _job();
      final closed = Job(
        id: 'j2', title: 'Old closed job', category: 'Design & creative', description: 'd', budget: 1000, clientId: 'c1', clientName: 'Chinedu',
        postedAt: _now, closedAt: _now, deliveryDays: 5,
      );
      expect(ClientJobsTab.mine([closed, open], 'c1').length, 2);
      final sorted = ClientJobsTab.sorted([closed, open]);
      expect(sorted.map((j) => j.id), ['j1', 'j2']);
    });
  });
}
```
(`ClientJobsTab.sorted` is a small new static the tab uses for its ordering, so the order is testable without pumping the whole shell; add a widget-level assertion for the pill in `shell_tabs_test.dart` if the tab can be pumped there.)

- [ ] **Step 2: Run, expect FAIL** (compile errors: `PostJobScreen.editing`, `ClientJobsTab.sorted`; the tooltip finder finds nothing).

- [ ] **Step 3: `ContractHeader` gets an optional `action`** in `contract_parts.dart`: add `final Widget? action;` and `this.action` to the constructor; in the top row place it after the pill: `pill, if (action != null) ...[const SizedBox(width: 8), action!],`.

- [ ] **Step 4: `PostJobScreen` edit mode.** Add `final Job? editing;` (constructor `this.editing`). In `initState`, when editing, prefill `_title.text`, `_description.text`, `_budget.text = job.budget.round().toString()`, `_category`, `_deliveryDays = job.deliveryDays ?? 7`, and `_descriptionValid = job.description.trim().length >= 20` (check `ReasonField` syncs from a prefilled controller; if it does not report validity on first build, call its validity callback from `initState` via the same rule it uses). `_submit` becomes:

```dart
    try {
      if (widget.editing != null) {
        await ref.read(jobsProvider.notifier).editJob(widget.editing!.id, title: _title.text.trim(), category: category, description: _description.text.trim(), budget: _budgetValue!, deliveryDays: _deliveryDays);
      } else {
        await ref.read(jobsProvider.notifier).postJob(title: _title.text.trim(), category: category, description: _description.text.trim(), budget: _budgetValue!, deliveryDays: _deliveryDays);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    if (widget.editing != null) {
      KdToast.show(context, 'Job updated.');
      Navigator.of(context).pop();
      return;
    }
    /* existing post-success code */
```
`build` wraps the list in `Scaffold` and swaps the header when editing: `ContractHeader(title: 'Edit job', sub: 'Terms lock once someone applies.', pill: StatusPill('Open', tone: KdTone.brand))` instead of `ScreenHeader(over: 'New job', title: 'Post a job')`; the button reads `Save changes` / `Saving`; the error card title is `Couldn't save the changes`; the footnote under Budget stays. When not editing, nothing changes.

- [ ] **Step 5: `ApplicantsScreen`.** Read the live job: `final job = ref.watch(jobsProvider).valueOrNull?.where((j) => j.id == widget.job.id).firstOrNull ?? widget.job;` (so an edit or close refreshes the header), `final closed = job.closed;`. Pill: `closed ? const StatusPill('Closed') : StatusPill('$count applied')`. Info text: closed → `You closed this job. Applicants can see that it was closed.`. `canAward: !awarded && !closed`. Header action when `!awarded && !closed`:

```dart
action: Tooltip(
  message: 'Manage this job',
  child: Pressable(
    onTap: () => _openMenu(job),
    semanticLabel: 'Manage this job',
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.more_horiz_rounded, color: AppColors.text),
    ),
  ),
),
```
and the two sheets:

```dart
  void _openMenu(Job job) {
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Manage this job',
        children: [
          const SizedBox(height: 14),
          if (job.applicationCount == 0)
            KdButton(
              label: 'Edit job',
              variant: KdButtonVariant.soft,
              onPressed: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostJobScreen(editing: job)));
              },
            )
          else
            const NoticeCard(
              tone: KdTone.plain,
              icon: Icons.lock_outline_rounded,
              title: 'Terms are locked',
              body: 'Someone has already applied, so the details can\'t change under them. Close it and post a new one to change them.',
            ),
          const SizedBox(height: 10),
          KdButton(label: 'Close job', variant: KdButtonVariant.danger, onPressed: () { Navigator.of(sheet).pop(); _confirmClose(job); }),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Never mind', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }

  void _confirmClose(Job job) {
    final n = job.applicationCount;
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Close this job?',
        lead: n == 0
            ? 'Nobody has applied yet. A closed job can\'t be reopened. Post a new one if you change your mind.'
            : '$n applicant${n == 1 ? '' : 's'} will see that it was closed. A closed job can\'t be undone. Post a new one if you change your mind.',
        children: [
          const SizedBox(height: 18),
          KdButton(
            label: 'Close job',
            busyLabel: 'Closing',
            variant: KdButtonVariant.danger,
            onPressed: () async {
              final sheetNav = Navigator.of(sheet);
              final nav = Navigator.of(context);
              try {
                await ref.read(jobsProvider.notifier).closeJob(job.id);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (!mounted) return;
              sheetNav.pop();
              KdToast.show(context, 'Job closed.');
              nav.pop();
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Keep it open', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }
```
(The tests look for `ElevatedButton`; if `KdButton` is not built on `ElevatedButton`, change the finders to `find.widgetWithText(KdButton, ...)`. Check `kd_button.dart` first and write the test against what it really renders.)

- [ ] **Step 6: `ClientJobsTab`.** Add `static List<Job> sorted(List<Job> jobs)` that returns a copy ordered by `rank(j) = j.closed ? 3 : (j.contractStatus == null ? 1 : contractSortRank(j, forClient: true))` (stable) and use it in `build`. In `_tile`, the open-job card shows `StatusPill('Closed')` instead of `StatusPill('Open', tone: KdTone.brand)` when `job.closed`, and its bottom line reads `Closed` (plus ` · N applicant(s)` when there were any) in `AppColors.text3` with no "pick one".

- [ ] **Step 7: Run `flutter test test/edit_close_job_test.dart`, expect PASS; then the whole suite and `flutter analyze`, expect clean.**

- [ ] **Step 8: Commit:**

```bash
git add lib/presentation/widgets/contract/contract_parts.dart lib/presentation/screens/client lib/presentation/screens/shell/client_jobs_tab.dart test/edit_close_job_test.dart
git commit -m "Client: edit an open job until someone applies, or close it

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 11: Talent side of a closed or edited job

**Files:** Modify `lib/presentation/screens/jobs/job_detail_screen.dart`, `lib/presentation/screens/jobs/job_feed_screen.dart`; extend `test/edit_close_job_test.dart` or add `test/job_detail_closed_test.dart`.

- [ ] **Step 1: Write the failing tests** (a new `test/job_detail_closed_test.dart`, same harness as `shell_tabs_test.dart`: override `jobsProvider` with a recording notifier whose `applyTo` records `revision` and can throw `ApiException('...', 409, code: 'terms_changed')`, and `talentProfileProvider` with a verified, payout-ready profile):
  1. A closed job the talent never applied to: the detail screen shows the pill `Closed`, the card `This job is closed` with the client's name, and **no Apply button** (`find.text('Apply for this job')` finds nothing).
  2. An open job: tapping Apply, then `Send application`, calls `applyTo` with `revision: job.revision` (use a job with `revision: 2`; assert the recorded call is `apply:j1:2`).
  3. `terms_changed`: the notifier's `applyTo` throws `ApiException(..., 409, code: 'terms_changed')`; after `Send application` the sheet is gone, a refresh was requested (recorded), and the toast `This job was just edited. Check the new details, then apply again.` is shown; no error toast.
  4. Any other `ApiException` still shows its message in the sheet (existing behaviour kept).
  5. Feed: a closed job the talent never applied to is not listed; a closed job they applied to is listed. Test through `job_feed_screen` the way `shell_tabs_test.dart` pumps the feed.

- [ ] **Step 2: Run, expect FAIL** (closed jobs still show Apply; `applyTo` is called without a revision).

- [ ] **Step 3: Implement.** `job_detail_screen.dart`: `final closed = job.closed;`; pill: closed → `const StatusPill('Closed')` (before the applied pill logic: an applicant whose job closed sees `Closed` too); `_gate`: when `closed` return `NoticeCard(tone: KdTone.plain, icon: Icons.block_outlined, title: 'This job is closed', body: '${job.clientName} closed it, so it isn\'t taking applications.')` ahead of the verified/payout cards; action bar: `if (!applied && !filled && !closed) KdButton(...)`. In `_confirmApply`:

```dart
            onPressed: () async {
              try {
                await ref.read(jobsProvider.notifier).applyTo(job.id, revision: job.revision);
              } on ApiException catch (e) {
                if (e.code == 'terms_changed') {
                  await ref.read(jobsProvider.notifier).refresh();
                  if (!sheet.mounted) return;
                  Navigator.of(sheet).pop();
                  KdToast.show(sheet, 'This job was just edited. Check the new details, then apply again.');
                  return;
                }
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (!sheet.mounted) return;
              Navigator.of(sheet).pop();
              KdToast.show(sheet, 'Application sent to ${job.clientName}');
            },
```
`job_feed_screen.dart` (line ~47): extend the filter so a closed job only stays when the viewer applied: `.where((j) => !j.closed || j.applicationStatus != JobApplicationStatus.notApplied)` combined with the existing awarded rule.

- [ ] **Step 4: Run the new tests, then the whole suite and `flutter analyze`, expect all PASS and clean.**

- [ ] **Step 5: Commit:**

```bash
git add lib/presentation/screens/jobs test/job_detail_closed_test.dart
git commit -m "Talent: closed jobs say so and take no applications; edited terms are re-read before applying

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Task 12: Whole-system verification, docs, and the handoff

**Files:** Modify `docs/core/testing.md`, `docs/README.md`, the spec's status line; update the memory file `pending_next_build.md`.

- [ ] **Step 1: Full backend suite on the final code:** `cd "C:/mobile-projects/flutter/kings domain/king-domain-backend" && npm test`. Expected: all green, count higher than the baseline recorded before this work. Paste the summary line.

- [ ] **Step 2: Full app checks:** `flutter analyze` (expect `No issues found!`) and `flutter test` (expect all passing, count higher than the 83 baseline).

- [ ] **Step 3: Run the real stack by hand once, end to end, against the test server on a scratch port**, and look at the screens: start the backend against the test database (`PORT=4620`), run the app on the connected phone or an emulator with `--dart-define=KD_API_BASE=http://<machine-ip>:4620` (see the `phone_testing` notes), and walk: post a job as a client, edit it, apply as a talent, see it under Applied, close it as the client, see "Closed by the client" on the talent side; open a funded contract on both roles and read the stepper. Tests prove the logic; this proves it reads right. Note anything that looks wrong and fix it with a test first.

- [ ] **Step 4: Update the docs.** `docs/core/testing.md`: add the new suites (`jobs.test.js`, `jobsRoutes.test.js`, the four app test files) with what each guarantees and what is NOT guaranteed (multi-instance races on a real production database are modelled with `barrierPrisma`, not load-tested). Mark the spec's status line "built (not deployed)". Fix the stale sentence in `docs/research/BACKEND_SPRINT_PLAN.md` that says the backend has no product models: add a dated note at the top pointing to the current code instead of rewriting it.

- [ ] **Step 5: Commit** the docs in the mobile repo.

- [ ] **Step 6: Stop and ask Victor before anything leaves this machine.** Nothing so far was pushed or deployed. To put this on staging he must agree to: (1) pushing the backend `master` to `origin/staging` (Render deploys it), preceded by the additive schema push to the Neon staging database; (2) bumping the app version, creating the matching draft release in the staging admin, and pushing the mobile `master` to `origin/staging` (Codemagic builds a staging APK; never push mobile `master` to `origin/master`); (3) him publishing the draft in the admin. The staging schema push is additive and loses no data; it still changes a database his testers are using, so it is his call.

- [ ] **Step 7: Update memory** (`pending_next_build.md`): the three gaps are built and tested locally, awaiting his go-ahead to deploy; profile photos remain, and so does Firebase last.

## Self-review against the spec

- Spec item 1 (Applied segment, statuses, order, empty/error): Task 8.
- Spec item 2 (five steps, table, subtitles, no "held by", accessibility, reduced motion): Task 9.
- Spec item 3 rules and schema: Tasks 1-5. Endpoints (`PATCH`, `close`, `apply` revision, feed visibility, `serializeJob`): Tasks 2-4. Race guards for edit/apply, close/apply, close/award and the award claim: Tasks 4-6, with mutation checks. App edit mode, menu, close sheet, closed views, `terms_changed`: Tasks 10-11.
- Spec tests list: backend rules, errors, effects, visibility, stale revision, award on closed, three races; app Applied, stepper for every status and viewer, edit mode, menu and disabled state, close confirmation, closed views, `terms_changed`.
- Not in scope (money, push, reopen, search): untouched.
- Names consistent across tasks: `editJob`, `closeJob`, `applyToJob`, `awardJob`, `validateJobInput`, `jobInclude`, codes `invalid | not_found | not_yours | closed | awarded | has_applicants | terms_changed | already_applied`; app `appliedJobs`, `appliedStatusLine`, `AppliedTile`, `lifecycleSteps`, `LifecycleStep`, `StepProgress`, `LifecycleStepper`, `ApiException.code`, `ContractHeader.action`, `PostJobScreen.editing`, `ClientJobsTab.sorted`.
