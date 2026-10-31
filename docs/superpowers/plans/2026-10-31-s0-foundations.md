# S0 Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay the shared ground every later slice (S1–S8 in `docs/core/prd.md` §8) builds on: one skill catalogue, team roles with an audit trail, the team inbox with honest queue numbers and alerts, the sample-data convention, and the reusable app pieces (event cards, a stepper per job type, an evidence viewer, a reason sheet, a consent screen, the protection summary).

**Architecture:** Three repos. The backend (`king-domain-backend`, Node/Express 5, Prisma 7 on Postgres) gets four small modules (`src/skills.js`, `src/admin/capabilities.js`, `src/admin/audit.js`, `src/admin/inbox.js`, `src/alerts.js`) and the routes that expose them. The admin dashboard (`king-domain-admin`, React 19 + shadcn) gets an Inbox page, an Audit log page and capability/on-call controls on the Team page. The app (`king-domain-mobile`, Flutter + Riverpod) gets the skill model and provider, the sample-data marker, and six kit widgets with widget tests. Nothing here changes what a talent or client sees today, except that proof approval now needs the reviewer capability.

**Tech Stack:** Node 22 `node:test`, Express 5, Prisma 7 (`@prisma/adapter-pg`), React 19, TypeScript 6, Vite 8, Tailwind 4, shadcn/radix, lucide-react, Flutter 3 / Dart 3, flutter_riverpod 2.6, flutter_test, url_launcher.

## Global Constraints

- All work lands on staging only: backend and app branch `staging`; never push `master` of the mobile repo (triggers the production APK) or the backend (production). Every push needs Victor's go-ahead.
- Schema changes are additive and are pushed to the Neon **test** branch first (for `npm test`), then to the Neon **staging** branch with Victor's go-ahead; production is not touched in S0.
- Brand v1 only (CLAUDE.md): tokens from `lib/core/constants/`; violet = act, gold = money only, green = verified/done, amber = waiting, red = errors; no emoji; line icons; no glow except the single primary button.
- Every screen and widget state is designed: empty, loading (skeleton; spinner only inside the working button; held ≥ 300 ms via `AppMotion.minLoading`), failed (inline, with Retry), waiting, rejected, done — each with a next step (CLAUDE.md "no dead ends").
- Logging rule (CLAUDE.md hard rule 1): log the state that decides the outcome and the read-back, never only the input.
- Tests: targeted per task. The full suites run once at the end of S0, one at a time (the PC is low on RAM): backend `npm test`, app `flutter test`, admin `npm run build && npm run lint`.
- The five launch skills and their start-proof formats are exactly those in `docs/core/prd.md` §4.2 (D25).
- Second-person approval threshold for manual money actions: ₦100,000 (D44). Not used in S0 code beyond being recorded; it is enforced in S6.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

## File structure

**Backend (`king-domain-backend`)**
- Create `src/skills.js` — the skill catalogue (categories, the five launch skills, start-proof fields). Pure data and lookups.
- Create `src/admin/capabilities.js` — the capability list, `hasCapability`, `requireCapability`, `canReviewSkill`.
- Create `src/admin/audit.js` — `recordAudit`, `actorRoleOf`.
- Create `src/admin/inbox.js` — the queue registry, targets with defaults, percentile maths, `inboxFor(admin)`.
- Create `src/alerts.js` — `raiseAlert`, `sendDigest`, `onCallNow`, `sweepOverdue`, `startOpsScheduler`.
- Create `src/admin/opsRoutes.js` — `/admin/inbox`, `/admin/audit`, `/admin/on-call`, `/admin/alerts/test`, `/admin/admins/:id/capabilities`.
- Modify `prisma/schema.prisma` — `AdminCapability` enum, `AdminUser.capabilities`, `AdminUser.reviewerSkills`, models `AdminAuditEvent`, `QueueTarget`, `OnCallShift`, `OpsAlert`.
- Modify `src/admin/routes.js` — `publicUser` returns capabilities and reviewer skills.
- Modify `src/admin/proofReviewRoutes.js` — approve and reject need the reviewer capability and write an audit event in the same transaction.
- Modify `src/admin/mailer.js` — `sendOpsAlert`.
- Modify `src/index.js` — `GET /skills`, mount `opsRoutes`, start the ops scheduler.
- Modify `test/helpers.js` — `ensureAdmin`, `adminTokenFor`, `serveFakeSlack`, `startServer({ env })`.
- Tests: `test/skills.test.js`, `test/capabilities.test.js`, `test/audit.test.js`, `test/inbox.test.js`, `test/alerts.test.js`, `test/opsRoutes.test.js`.

**Admin dashboard (`king-domain-admin`)**
- Modify `src/lib/api.ts` — types and calls for capabilities, skills, inbox, audit, on-call, test alert.
- Create `src/lib/capabilities.ts` — `can(user, capability)` and labels.
- Create `src/pages/Inbox.tsx`, `src/pages/Audit.tsx`.
- Create `src/components/team/CapabilityEditor.tsx`, `src/components/team/OnCallPanel.tsx`.
- Modify `src/pages/Team.tsx`, `src/components/Shell.tsx`, `src/App.tsx`.

**App (`king-domain-mobile`)**
- Create `lib/data/models/skill.dart`, `lib/presentation/providers/skills_provider.dart`.
- Create `lib/presentation/widgets/common/sample_data_notice.dart`, `docs/core/sample-data.md`.
- Create `lib/presentation/widgets/kit/event_card.dart`, `kd_stepper.dart`, `evidence_viewer.dart`, `reason_sheet.dart`, `consent_screen.dart`, `protection_summary.dart`.
- Create `lib/core/constants/job_lifecycles.dart`.
- Tests: `test/skill_model_test.dart`, `test/sample_data_notice_test.dart`, `test/event_card_test.dart`, `test/kd_stepper_test.dart`, `test/evidence_viewer_test.dart`, `test/reason_sheet_test.dart`, `test/consent_screen_test.dart`, `test/protection_summary_test.dart`.

---

## Part A — Backend

### Task A1: The skill catalogue and `GET /skills`

**Files:**
- Create: `king-domain-backend/src/skills.js`
- Modify: `king-domain-backend/src/index.js` (add the route next to `/waitlist/count`)
- Test: `king-domain-backend/test/skills.test.js`

**Interfaces:**
- Produces: `CATEGORIES: {key, label}[]`, `SKILLS: {key, label, category, open, startProof: {key, label, kind, min, max}[]}[]`, `skillByKey(key) → skill | null`, `isSkillKey(key) → boolean`, `catalogue() → {categories, skills}`. Category `label`s equal the existing `ProofItem.category` / `Job.category` strings, so old rows still match. `GET /skills → 200 {categories, skills}` (public, no auth).

- [ ] **Step 1: Write the failing test**

```js
// test/skills.test.js — pure module test, no database.
const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const skills = require("../src/skills");

describe("skill catalogue", () => {
  it("has exactly the five launch skills from the PRD, all open", () => {
    assert.deepEqual(
      skills.SKILLS.map((s) => s.key),
      ["graphic-design", "short-form-video", "social-media", "writing", "web-development"],
    );
    assert.ok(skills.SKILLS.every((s) => s.open === true));
  });

  it("keeps the six existing category labels so old jobs and proof still match", () => {
    assert.deepEqual(skills.CATEGORIES.map((c) => c.label), [
      "Software & tech", "Design & creative", "Writing & content", "Marketing & growth", "Tutoring & training", "Video & media",
    ]);
    for (const s of skills.SKILLS) {
      assert.ok(skills.CATEGORIES.some((c) => c.key === s.category), `${s.key} points at a real category`);
    }
  });

  it("gives every skill a start-proof format with sane bounds", () => {
    const kinds = new Set(["files", "image", "video", "text", "link"]);
    for (const s of skills.SKILLS) {
      assert.ok(s.startProof.length >= 1, `${s.key} has a start proof`);
      for (const f of s.startProof) {
        assert.ok(kinds.has(f.kind), `${s.key}.${f.key} kind`);
        assert.ok(f.min >= 1 && f.max >= f.min, `${s.key}.${f.key} bounds`);
      }
    }
    assert.deepEqual(skills.skillByKey("short-form-video").startProof.map((f) => f.key), ["roughCut", "timeline"]);
  });

  it("looks skills up by key and refuses unknown keys", () => {
    assert.equal(skills.skillByKey("writing").label, "Writing");
    assert.equal(skills.skillByKey("nope"), null);
    assert.equal(skills.isSkillKey("writing"), true);
    assert.equal(skills.isSkillKey(""), false);
  });
});
```

- [ ] **Step 2: Run it to see it fail**

Run (from `king-domain-backend`): `node --test test/skills.test.js`
Expected: FAIL — `Cannot find module '../src/skills'`.

- [ ] **Step 3: Write the module**

```js
// src/skills.js
// The one list of skills King Domain verifies and hires for (PRD §4.2, §4.6, decision D25).
// Category labels are the strings already stored on ProofItem.category and Job.category,
// so rows written before skills existed still resolve. The app reads this through GET /skills.

const CATEGORIES = [
  { key: "tech", label: "Software & tech" },
  { key: "design", label: "Design & creative" },
  { key: "writing", label: "Writing & content" },
  { key: "marketing", label: "Marketing & growth" },
  { key: "tutoring", label: "Tutoring & training" },
  { key: "video", label: "Video & media" },
];

// kind: files (any document or image), image, video, text (typed in the app), link (a URL).
const SKILLS = [
  {
    key: "graphic-design",
    label: "Graphic design",
    category: "design",
    open: true,
    startProof: [
      { key: "concepts", label: "Two or three concept directions", kind: "files", min: 2, max: 3 },
      { key: "moodboard", label: "A moodboard", kind: "image", min: 1, max: 1 },
    ],
  },
  {
    key: "short-form-video",
    label: "Short-form video editing",
    category: "video",
    open: true,
    startProof: [
      { key: "roughCut", label: "Rough cut of the first piece", kind: "video", min: 1, max: 1 },
      { key: "timeline", label: "Screenshot of the project timeline", kind: "image", min: 1, max: 1 },
    ],
  },
  {
    key: "social-media",
    label: "Social media management",
    category: "marketing",
    open: true,
    startProof: [
      { key: "calendar", label: "The month's content calendar", kind: "files", min: 1, max: 1 },
      { key: "firstWeek", label: "The first week's posts, drafted", kind: "files", min: 1, max: 14 },
    ],
  },
  {
    key: "writing",
    label: "Writing",
    category: "writing",
    open: true,
    startProof: [
      { key: "outline", label: "Outline", kind: "text", min: 1, max: 1 },
      { key: "firstSection", label: "The first section", kind: "files", min: 1, max: 1 },
    ],
  },
  {
    key: "web-development",
    label: "Web development",
    category: "tech",
    open: true,
    startProof: [
      { key: "structure", label: "Wireframes or a sitemap", kind: "files", min: 1, max: 5 },
      { key: "repository", label: "Repository with the first commits, or a staging link", kind: "link", min: 1, max: 1 },
    ],
  },
];

const byKey = new Map(SKILLS.map((s) => [s.key, s]));

function skillByKey(key) {
  return byKey.get(key) ?? null;
}

function isSkillKey(key) {
  return typeof key === "string" && byKey.has(key);
}

function catalogue() {
  return { categories: CATEGORIES, skills: SKILLS };
}

module.exports = { CATEGORIES, SKILLS, skillByKey, isSkillKey, catalogue };
```

- [ ] **Step 4: Expose it.** In `src/index.js`, add `const skills = require("./skills");` with the other requires, and directly below the `app.get("/waitlist/count", …)` block:

```js
// Public: the app builds skill pickers, briefs and start-proof forms from this (PRD §4.2).
app.get("/skills", (req, res) => {
  res.json(skills.catalogue());
});
```

- [ ] **Step 5: Run the test to see it pass**

Run: `node --test test/skills.test.js`
Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
git add src/skills.js src/index.js test/skills.test.js
git commit -m "Skills: one catalogue of the five launch skills and their start-proof formats, served at GET /skills

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task A2: Schema for capabilities, audit, queue targets, on-call and alerts

**Files:**
- Modify: `king-domain-backend/prisma/schema.prisma`

**Interfaces:**
- Produces (Prisma models used by A3–A6): `AdminUser.capabilities AdminCapability[]`, `AdminUser.reviewerSkills String[]`; `AdminAuditEvent {id, actorId, actorRole, action, subjectType, subjectId, reasonCode?, note?, details Json?, createdAt}`; `QueueTarget {queueKey @id, targetMinutes, defaultWhenLate, updatedAt}`; `OnCallShift {id, adminId, startsAt, endsAt, createdAt}`; `OpsAlert {id, severity, queueKey, title, body, link?, slackSent, emailedTo String[], digestedAt?, createdAt}`.

- [ ] **Step 1: Add to `prisma/schema.prisma`.** Below `enum AdminRole { … }`:

```prisma
/// What an admin may do beyond reading (PRD §2, decision D43). An owner may do everything.
/// One person can hold several.
enum AdminCapability {
  reviewer    // proof verification, limited to reviewerSkills
  checker     // authenticity, identity and student documents
  safety      // reports, job-post screening
  disputes    // dispute rulings, start-proof objections
  finance     // refunds, splits, chargebacks, payout failures
  support     // shortlists, general help
  shareholder // read-only: ledger, metrics, audit log
}
```

Inside `model AdminUser { … }`, after `role`:

```prisma
  capabilities   AdminCapability[] @default([])
  /// Skill keys from src/skills.js this admin may review (only with the reviewer capability).
  reviewerSkills String[]          @default([])
  auditEvents    AdminAuditEvent[]
  onCallShifts   OnCallShift[]
```

At the end of the file:

```prisma
/// Every action an admin takes, kept unchanged (PRD §4.11, decision D43). Never updated or deleted.
model AdminAuditEvent {
  id          String    @id @default(uuid())
  actorId     String
  actor       AdminUser @relation(fields: [actorId], references: [id])
  /// The actor's role and capabilities at the time, e.g. "admin:checker,reviewer" or "owner".
  actorRole   String
  /// Dotted verb, e.g. "proof.approve", "admin.capabilities", "oncall.create".
  action      String
  subjectType String
  subjectId   String
  reasonCode  String?
  note        String?
  details     Json?
  createdAt   DateTime  @default(now())

  @@index([subjectType, subjectId])
  @@index([actorId, createdAt])
  @@index([createdAt])
  @@map("admin_audit_events")
}

/// A queue's promised handling time, stored as data so it can be changed without a deploy.
/// A queue without a row uses the default in src/admin/inbox.js.
model QueueTarget {
  queueKey        String   @id
  targetMinutes   Int
  defaultWhenLate String
  updatedAt       DateTime @updatedAt

  @@map("queue_targets")
}

/// Who is on call, and when (decision D45).
model OnCallShift {
  id        String    @id @default(uuid())
  adminId   String
  admin     AdminUser @relation(fields: [adminId], references: [id])
  startsAt  DateTime
  endsAt    DateTime
  createdAt DateTime  @default(now())

  @@index([startsAt, endsAt])
  @@map("on_call_shifts")
}

/// An alert to the team (decision D46). Urgent ones go out at once; digest ones wait for the daily digest.
model OpsAlert {
  id         String    @id @default(uuid())
  /// "urgent" or "digest"
  severity   String
  queueKey   String
  title      String
  body       String
  link       String?
  slackSent  Boolean   @default(false)
  /// Addresses the mailer confirmed it sent to (read back, not attempted).
  emailedTo  String[]  @default([])
  digestedAt DateTime?
  createdAt  DateTime  @default(now())

  @@index([severity, digestedAt])
  @@index([queueKey, createdAt])
  @@map("ops_alerts")
}
```

- [ ] **Step 2: Push to the Neon test branch and regenerate the client.** With `DIRECT_URL` temporarily set to the test branch's direct URL (the same database as `TEST_DATABASE_URL`, non-pooled):

Run: `DIRECT_URL="<test branch direct url>" npm run db:push`
Expected: "Your database is now in sync with your Prisma schema" and "Generated Prisma Client". If it asks to accept data loss, stop: every change here is additive, so a data-loss prompt means the wrong database or a typo.

- [ ] **Step 3: Read the schema back.** Run: `DIRECT_URL="<test branch direct url>" npx prisma db pull --print | grep -E "admin_audit_events|queue_targets|on_call_shifts|ops_alerts|capabilities"`
Expected: all five names appear.

- [ ] **Step 4: Commit**

```bash
git add prisma/schema.prisma src/generated
git commit -m "Schema: admin capabilities, audit events, queue targets, on-call shifts, ops alerts (additive)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task A3: Capabilities, the audit log, and proof review behind them

**Files:**
- Create: `king-domain-backend/src/admin/capabilities.js`, `king-domain-backend/src/admin/audit.js`
- Modify: `king-domain-backend/src/admin/routes.js` (`publicUser`), `king-domain-backend/src/admin/proofReviewRoutes.js` (approve, reject), `king-domain-backend/test/helpers.js`
- Test: `king-domain-backend/test/capabilities.test.js`, `king-domain-backend/test/audit.test.js`

**Interfaces:**
- Consumes: Prisma models from A2; `isSkillKey` from A1.
- Produces: `CAPABILITIES: string[]`; `hasCapability(admin, cap) → boolean`; `requireCapability(...caps)` Express middleware (403 `{error: "You don't have access to this."}`); `canReviewSkill(admin, skillKey) → boolean`; `actorRoleOf(admin) → string`; `recordAudit(db, admin, {action, subjectType, subjectId, reasonCode?, note?, details?}) → Promise<AdminAuditEvent>`. `publicUser(user)` gains `capabilities: string[]`, `reviewerSkills: string[]`. Test helpers gain `ensureAdmin(email, {role = "admin", capabilities = [], reviewerSkills = []})` and `adminTokenFor(admin)`.

- [ ] **Step 1: Write the failing unit test for capabilities**

```js
// test/capabilities.test.js — pure, no database.
const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const caps = require("../src/admin/capabilities");

const owner = { role: "owner", capabilities: [], reviewerSkills: [] };
const reviewer = { role: "admin", capabilities: ["reviewer"], reviewerSkills: ["writing"] };
const reader = { role: "admin", capabilities: [], reviewerSkills: [] };

function run(mw, admin) {
  let status = 200, body = null, nexted = false;
  const res = { status(c) { status = c; return this; }, json(b) { body = b; return this; } };
  mw({ admin }, res, () => { nexted = true; });
  return { status, body, nexted };
}

describe("capabilities", () => {
  it("lists the seven capabilities from decision D43", () => {
    assert.deepEqual(caps.CAPABILITIES, ["reviewer", "checker", "safety", "disputes", "finance", "support", "shareholder"]);
  });

  it("an owner has every capability; others only what they were given", () => {
    assert.equal(caps.hasCapability(owner, "finance"), true);
    assert.equal(caps.hasCapability(reviewer, "reviewer"), true);
    assert.equal(caps.hasCapability(reviewer, "finance"), false);
    assert.equal(caps.hasCapability(reader, "reviewer"), false);
  });

  it("requireCapability lets the right people through and refuses the rest with 403", () => {
    assert.equal(run(caps.requireCapability("reviewer"), reviewer).nexted, true);
    assert.equal(run(caps.requireCapability("reviewer"), owner).nexted, true);
    const refused = run(caps.requireCapability("reviewer", "checker"), reader);
    assert.equal(refused.nexted, false);
    assert.equal(refused.status, 403);
    assert.equal(refused.body.error, "You don't have access to this.");
  });

  it("a reviewer reviews only their skills; an owner reviews any", () => {
    assert.equal(caps.canReviewSkill(reviewer, "writing"), true);
    assert.equal(caps.canReviewSkill(reviewer, "graphic-design"), false);
    assert.equal(caps.canReviewSkill(owner, "graphic-design"), true);
    assert.equal(caps.canReviewSkill(reader, "writing"), false);
  });
});
```

- [ ] **Step 2: Run it to see it fail.** Run: `node --test test/capabilities.test.js` — Expected: FAIL, module not found.

- [ ] **Step 3: Write `src/admin/capabilities.js`**

```js
// What each admin may do (PRD §2, decision D43). The owner role may do everything;
// everyone else needs the capability. Read access to the dashboard itself still only
// needs a signed-in admin (requireAdmin).

const CAPABILITIES = ["reviewer", "checker", "safety", "disputes", "finance", "support", "shareholder"];

function hasCapability(admin, capability) {
  if (!admin) return false;
  if (admin.role === "owner") return true;
  return Array.isArray(admin.capabilities) && admin.capabilities.includes(capability);
}

/** Express middleware: passes if the admin has ANY of the listed capabilities. Use after requireAdmin. */
function requireCapability(...capabilities) {
  return (req, res, next) => {
    if (capabilities.some((c) => hasCapability(req.admin, c))) return next();
    return res.status(403).json({ error: "You don't have access to this." });
  };
}

/** Proof in a skill is reviewed only by an owner or a reviewer holding that skill. */
function canReviewSkill(admin, skillKey) {
  if (!admin) return false;
  if (admin.role === "owner") return true;
  return hasCapability(admin, "reviewer") && Array.isArray(admin.reviewerSkills) && admin.reviewerSkills.includes(skillKey);
}

module.exports = { CAPABILITIES, hasCapability, requireCapability, canReviewSkill };
```

- [ ] **Step 4: Run it to see it pass.** Run: `node --test test/capabilities.test.js` — Expected: PASS, 4 tests.

- [ ] **Step 5: Add the admin helpers to `test/helpers.js`.** Below `tokenFor`, add (and add `ensureAdmin, adminTokenFor` to `module.exports`):

```js
const adminAuth = require("../src/admin/auth");
const adminJwt = require("../src/admin/jwt");

/** An active admin for tests; capabilities and reviewer skills are reset to what is passed. */
async function ensureAdmin(email, { role = "admin", capabilities = [], reviewerSkills = [] } = {}) {
  return prisma.adminUser.upsert({
    where: { email },
    update: { role, capabilities, reviewerSkills, status: "active" },
    create: { email, name: email.split("@")[0], role, capabilities, reviewerSkills, status: "active" },
  });
}

async function adminTokenFor(admin) {
  const { sessionId } = await adminAuth.createSession(admin.id, "test-suite");
  return adminJwt.generateAccessToken(admin, sessionId);
}
```

- [ ] **Step 6: Write the failing audit test (database-backed)**

```js
// test/audit.test.js — the audit log and proof review behind the reviewer capability, over real HTTP.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;
const { recordAudit, actorRoleOf } = require("../src/admin/audit");

let ctx, server, owner, reviewer, reader, tOwner, tReviewer, tReader, profile;
before(async () => {
  ctx = await h.fixtures();
  owner = await h.ensureAdmin("testsuite-owner@example.com", { role: "owner" });
  reviewer = await h.ensureAdmin("testsuite-reviewer@example.com", { capabilities: ["reviewer"], reviewerSkills: ["writing"] });
  reader = await h.ensureAdmin("testsuite-reader@example.com");
  server = await h.startServer({ port: 4621, paystackUrl: "http://127.0.0.1:9", autoRelease: false });
  [tOwner, tReviewer, tReader] = await Promise.all([owner, reviewer, reader].map(h.adminTokenFor));
  profile = await prisma.talentProfile.findUnique({ where: { userId: ctx.talentA.id } });
});
after(async () => {
  server?.stop();
  await prisma.proofItem.deleteMany({ where: { talentProfileId: profile.id } });
  await prisma.adminAuditEvent.deleteMany({ where: { actorId: { in: [owner.id, reviewer.id, reader.id] } } });
  await prisma.$disconnect();
});

const api = (tok, method, p, body) => h.call(server.base, tok, method, p, body);
const pending = () => prisma.proofItem.create({ data: { talentProfileId: profile.id, category: h.CATEGORY, title: `${h.TITLE_PREFIX}proof` } });

describe("audit log", () => {
  it("actorRoleOf records role and sorted capabilities", () => {
    assert.equal(actorRoleOf({ role: "owner", capabilities: [] }), "owner");
    assert.equal(actorRoleOf({ role: "admin", capabilities: ["reviewer", "checker"] }), "admin:checker,reviewer");
  });

  it("recordAudit writes the event and refuses one without a subject", async () => {
    const e = await recordAudit(prisma, owner, { action: "test.write", subjectType: "Test", subjectId: "t1", note: "hello" });
    const back = await prisma.adminAuditEvent.findUnique({ where: { id: e.id } });
    assert.equal(back.action, "test.write");
    assert.equal(back.actorRole, "owner");
    await assert.rejects(() => recordAudit(prisma, owner, { action: "test.write", subjectType: "Test" }), /subjectId/);
  });
});

describe("proof review needs the reviewer capability and leaves an audit trail", () => {
  it("an admin without the capability gets 403 and nothing changes", async () => {
    const item = await pending();
    const r = await api(tReader, "POST", `/admin/proof-items/${item.id}/approve`);
    assert.equal(r.status, 403);
    assert.equal((await prisma.proofItem.findUnique({ where: { id: item.id } })).status, "pending");
  });

  it("a reviewer approves, and the approval and its audit event land together", async () => {
    const item = await pending();
    const r = await api(tReviewer, "POST", `/admin/proof-items/${item.id}/approve`);
    assert.equal(r.status, 200, JSON.stringify(r.json));
    const events = await prisma.adminAuditEvent.findMany({ where: { subjectType: "ProofItem", subjectId: item.id } });
    assert.equal(events.length, 1);
    assert.equal(events[0].action, "proof.approve");
    assert.equal(events[0].actorId, reviewer.id);
    assert.equal(events[0].actorRole, "admin:reviewer");
  });

  it("a rejection keeps its reason in the audit event even though the item is deleted", async () => {
    const item = await pending();
    const reason = "The file doesn't open. Please upload it again as an image or PDF.";
    const r = await api(tOwner, "POST", `/admin/proof-items/${item.id}/reject`, { reason });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.equal(await prisma.proofItem.findUnique({ where: { id: item.id } }), null);
    const [event] = await prisma.adminAuditEvent.findMany({ where: { subjectType: "ProofItem", subjectId: item.id } });
    assert.equal(event.action, "proof.reject");
    assert.equal(event.note, reason);
    assert.equal(event.details.title, `${h.TITLE_PREFIX}proof`);
  });
});
```

- [ ] **Step 7: Run it to see it fail.** Run: `node --env-file=.env.test --test test/audit.test.js`
Expected: FAIL — `Cannot find module '../src/admin/audit'`.

- [ ] **Step 8: Write `src/admin/audit.js`**

```js
// The audit log (PRD §4.11, decision D43): who did what, when, why, with which evidence.
// Rows are only ever inserted. Pass a Prisma transaction client as `db` so the action and its
// audit event commit together.

function actorRoleOf(admin) {
  const caps = Array.isArray(admin.capabilities) ? [...admin.capabilities].sort() : [];
  return caps.length ? `${admin.role}:${caps.join(",")}` : admin.role;
}

async function recordAudit(db, admin, { action, subjectType, subjectId, reasonCode = null, note = null, details = null }) {
  if (!action || !subjectType || !subjectId) {
    throw new Error("recordAudit needs action, subjectType and subjectId.");
  }
  const event = await db.adminAuditEvent.create({
    data: { actorId: admin.id, actorRole: actorRoleOf(admin), action, subjectType, subjectId, reasonCode, note, details },
  });
  console.log(`audit: ${action} ${subjectType}=${subjectId} by admin=${admin.id} role=${event.actorRole} event=${event.id}`);
  return event;
}

module.exports = { actorRoleOf, recordAudit };
```

- [ ] **Step 9: Put proof review behind the capability, with the audit in the same transaction.** In `src/admin/proofReviewRoutes.js`:
  - Add `const { requireCapability } = require("./capabilities");` and `const { recordAudit } = require("./audit");`.
  - Change `router.post("/:id/approve", async (req, res) => {` to `router.post("/:id/approve", requireCapability("reviewer"), async (req, res) => {`.
  - Replace the approve `try { updated = await prisma.proofItem.update({...}); } catch …` block with:

```js
  let updated;
  try {
    updated = await prisma.$transaction(async (tx) => {
      const row = await tx.proofItem.update({
        where: { id: item.id },
        data: { status: "verified", reviewedById: req.admin.id, reviewedAt: new Date() },
        include: withTalent,
      });
      await recordAudit(tx, req.admin, {
        action: "proof.approve",
        subjectType: "ProofItem",
        subjectId: item.id,
        details: { title: item.title, category: item.category, talentUserId: item.talentProfile?.userId ?? null },
      });
      return row;
    });
  } catch (err) {
    if (err.code === RECORD_GONE) return res.status(409).json({ error: ALREADY_HANDLED });
    throw err;
  }
```

  - Change `router.post("/:id/reject", async (req, res) => {` to `router.post("/:id/reject", requireCapability("reviewer"), async (req, res) => {`.
  - Replace the reject `try { await prisma.proofItem.delete(...) } catch …` block with:

```js
  try {
    await prisma.$transaction(async (tx) => {
      await tx.proofItem.delete({ where: { id: item.id } });
      await recordAudit(tx, req.admin, {
        action: "proof.reject",
        subjectType: "ProofItem",
        subjectId: item.id,
        note: reason,
        details: { title: item.title, category: item.category, talentUserId: item.talentProfile?.userId ?? null },
      });
    });
  } catch (err) {
    if (err.code === RECORD_GONE) return res.status(409).json({ error: ALREADY_HANDLED });
    throw err;
  }
```

- [ ] **Step 10: Return capabilities from `publicUser`.** In `src/admin/routes.js`, inside `publicUser`, after `role: user.role,` add:

```js
    capabilities: user.capabilities ?? [],
    reviewerSkills: user.reviewerSkills ?? [],
```

- [ ] **Step 11: Run the tests to see them pass.** Run: `node --env-file=.env.test --test test/capabilities.test.js test/audit.test.js`
Expected: PASS, 9 tests. The approval test reading back exactly one `proof.approve` event is the check that fails if the audit is not written in the transaction.

- [ ] **Step 12: Commit**

```bash
git add src/admin/capabilities.js src/admin/audit.js src/admin/proofReviewRoutes.js src/admin/routes.js test/helpers.js test/capabilities.test.js test/audit.test.js
git commit -m "Admin: capabilities and an audit log; proof approval and rejection need the reviewer capability and are audited in the same transaction

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task A4: The team inbox (queue registry, targets, honest numbers)

**Files:**
- Create: `king-domain-backend/src/admin/inbox.js`
- Test: `king-domain-backend/test/inbox.test.js`

**Interfaces:**
- Consumes: `hasCapability` (A3); Prisma `QueueTarget`, `ProofItem`.
- Produces: `percentile(values: number[], p: number) → number | null` (nearest rank); `QUEUES` registry entries `{key, label, capability, path, defaultTargetMinutes, defaultWhenLate, openSince(db) → Date[], resolvedDurationsMs(db) → number[]}`; `targetFor(db, queue) → {targetMinutes, defaultWhenLate}`; `inboxFor(db, admin, now = new Date()) → Promise<QueueSummary[]>` where `QueueSummary = {key, label, path, capability, targetMinutes, defaultWhenLate, open, overdue, oldestWaitingMinutes, p50Minutes, p90Minutes, sample}`. Later slices add their queues by appending to `QUEUES`.

- [ ] **Step 1: Write the failing test**

```js
// test/inbox.test.js
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;
const inbox = require("../src/admin/inbox");

let ctx, profile, owner, reader;
before(async () => {
  ctx = await h.fixtures();
  profile = await prisma.talentProfile.findUnique({ where: { userId: ctx.talentA.id } });
  owner = await h.ensureAdmin("testsuite-owner@example.com", { role: "owner" });
  reader = await h.ensureAdmin("testsuite-reader@example.com");
  await prisma.proofItem.deleteMany({ where: { talentProfileId: profile.id } });
  await prisma.queueTarget.deleteMany({ where: { queueKey: "proof" } });
});
after(async () => {
  await prisma.proofItem.deleteMany({ where: { talentProfileId: profile.id } });
  await prisma.queueTarget.deleteMany({ where: { queueKey: "proof" } });
  await prisma.$disconnect();
});

describe("percentile", () => {
  it("uses nearest rank and is null for no data", () => {
    assert.equal(inbox.percentile([], 90), null);
    assert.equal(inbox.percentile([5], 50), 5);
    assert.equal(inbox.percentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 50), 5);
    assert.equal(inbox.percentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 90), 9);
    assert.equal(inbox.percentile([10, 1, 9, 2], 90), 10);
  });
});

describe("inboxFor", () => {
  it("shows a queue only to admins with its capability", async () => {
    assert.ok((await inbox.inboxFor(prisma, owner)).some((q) => q.key === "proof"));
    assert.equal((await inbox.inboxFor(prisma, reader)).some((q) => q.key === "proof"), false);
  });

  it("counts open and overdue items against the target, and the oldest wait", async () => {
    const now = new Date("2026-11-10T12:00:00Z");
    await prisma.proofItem.create({ data: { talentProfileId: profile.id, category: h.CATEGORY, title: `${h.TITLE_PREFIX}old`, createdAt: new Date("2026-11-05T12:00:00Z") } });
    await prisma.proofItem.create({ data: { talentProfileId: profile.id, category: h.CATEGORY, title: `${h.TITLE_PREFIX}new`, createdAt: new Date("2026-11-10T11:00:00Z") } });
    const proof = (await inbox.inboxFor(prisma, owner, now)).find((q) => q.key === "proof");
    assert.equal(proof.targetMinutes, 72 * 60, "default target with no stored row");
    assert.ok(proof.open >= 2);
    assert.ok(proof.overdue >= 1, "the five-day-old item is past 72 hours");
    assert.ok(proof.oldestWaitingMinutes >= 5 * 24 * 60);
  });

  it("a stored target replaces the default", async () => {
    await prisma.queueTarget.upsert({
      where: { queueKey: "proof" },
      update: { targetMinutes: 30, defaultWhenLate: "Escalate" },
      create: { queueKey: "proof", targetMinutes: 30, defaultWhenLate: "Escalate" },
    });
    const proof = (await inbox.inboxFor(prisma, owner)).find((q) => q.key === "proof");
    assert.equal(proof.targetMinutes, 30);
    assert.equal(proof.defaultWhenLate, "Escalate");
  });

  it("reports median and 90th percentile handling time from resolved items", async () => {
    await prisma.proofItem.create({ data: { talentProfileId: profile.id, category: h.CATEGORY, title: `${h.TITLE_PREFIX}done`, status: "verified", createdAt: new Date("2026-11-01T00:00:00Z"), reviewedAt: new Date("2026-11-01T02:00:00Z") } });
    const proof = (await inbox.inboxFor(prisma, owner)).find((q) => q.key === "proof");
    assert.ok(proof.sample >= 1);
    assert.ok(proof.p50Minutes !== null && proof.p90Minutes >= proof.p50Minutes);
  });
});
```

- [ ] **Step 2: Run it to see it fail.** Run: `node --env-file=.env.test --test test/inbox.test.js` — Expected: FAIL, module not found.

- [ ] **Step 3: Write `src/admin/inbox.js`**

```js
// The team inbox (PRD §4.11, admin tools doc §4, decision D43). Each queue states its target,
// what happens if the target passes, and honest numbers: median and 90th percentile of handling
// time ("averages hide the slow tail"), and items still open past target counted as overdue.
// Later slices append their queues here (identity, job posts, shortlists, disputes, chargebacks...).

const { hasCapability } = require("./capabilities");

const RESOLVED_SAMPLE = 50;

/** Nearest-rank percentile. Null when there is no data, so the UI can say "not enough data yet". */
function percentile(values, p) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const rank = Math.ceil((p / 100) * sorted.length);
  return sorted[Math.min(sorted.length, Math.max(1, rank)) - 1];
}

const QUEUES = [
  {
    key: "proof",
    label: "Proof verification",
    capability: "reviewer",
    path: "/proof-review",
    // Provisional: the admin tools doc says to measure for six to eight weeks, then set it.
    defaultTargetMinutes: 72 * 60,
    defaultWhenLate: "The talent sees it is still in review, with the expected date.",
    async openSince(db) {
      const rows = await db.proofItem.findMany({ where: { status: "pending" }, select: { createdAt: true } });
      return rows.map((r) => r.createdAt);
    },
    async resolvedDurationsMs(db) {
      // Only approvals have a reviewedAt today; rejected items are deleted (S2 keeps them),
      // so until then this sample is approvals only.
      const rows = await db.proofItem.findMany({
        where: { status: "verified", reviewedAt: { not: null } },
        select: { createdAt: true, reviewedAt: true },
        orderBy: { reviewedAt: "desc" },
        take: RESOLVED_SAMPLE,
      });
      return rows.map((r) => r.reviewedAt.getTime() - r.createdAt.getTime());
    },
  },
];

async function targetFor(db, queue) {
  const row = await db.queueTarget.findUnique({ where: { queueKey: queue.key } });
  return {
    targetMinutes: row?.targetMinutes ?? queue.defaultTargetMinutes,
    defaultWhenLate: row?.defaultWhenLate ?? queue.defaultWhenLate,
  };
}

const toMinutes = (ms) => (ms === null ? null : Math.round(ms / 60000));

async function inboxFor(db, admin, now = new Date()) {
  const visible = QUEUES.filter((q) => hasCapability(admin, q.capability));
  return Promise.all(
    visible.map(async (q) => {
      const [{ targetMinutes, defaultWhenLate }, openSince, durations] = await Promise.all([
        targetFor(db, q),
        q.openSince(db),
        q.resolvedDurationsMs(db),
      ]);
      const waits = openSince.map((d) => now.getTime() - d.getTime());
      const overdue = waits.filter((w) => w > targetMinutes * 60000).length;
      return {
        key: q.key,
        label: q.label,
        path: q.path,
        capability: q.capability,
        targetMinutes,
        defaultWhenLate,
        open: waits.length,
        overdue,
        oldestWaitingMinutes: waits.length ? toMinutes(Math.max(...waits)) : null,
        p50Minutes: toMinutes(percentile(durations, 50)),
        p90Minutes: toMinutes(percentile(durations, 90)),
        sample: durations.length,
      };
    }),
  );
}

module.exports = { QUEUES, percentile, targetFor, inboxFor };
```

- [ ] **Step 4: Run it to see it pass.** Run: `node --env-file=.env.test --test test/inbox.test.js` — Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add src/admin/inbox.js test/inbox.test.js
git commit -m "Admin inbox: queue registry with stored targets, overdue counts and median/90th-percentile handling times

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task A5: Alerts to Slack and email, the on-call rota, and the daily digest

**Files:**
- Create: `king-domain-backend/src/alerts.js`
- Modify: `king-domain-backend/src/admin/mailer.js` (add `sendOpsAlert`), `king-domain-backend/test/helpers.js` (add `serveFakeSlack`)
- Test: `king-domain-backend/test/alerts.test.js`

**Interfaces:**
- Consumes: Prisma `OpsAlert`, `OnCallShift`, `AdminUser`; `inboxFor`/`QUEUES` (A4); `mailer.send`.
- Produces: `onCallNow(db, at = new Date()) → Promise<AdminUser[]>`; `raiseAlert(db, {severity, queueKey, title, body, link?}, deps?) → Promise<OpsAlert>` (urgent: Slack + email to the people on call, or to the owners when nobody is; digest: stored only); `sendDigest(db, deps?) → Promise<{sent: number}>`; `sweepOverdue(db, now = new Date()) → Promise<number>` (one digest alert per queue per day while it has overdue items); `startOpsScheduler({intervalMs})`. `deps = {fetchImpl, mailer, webhookUrl, dashboardUrl}`, defaulting to the real ones and the env vars `OPS_SLACK_WEBHOOK_URL`, `ADMIN_DASHBOARD_URL`. `mailer.sendOpsAlert({to, title, body, link}) → Promise<{sent: boolean}>`. Test helper `serveFakeSlack() → {url, received: object[], server}`.

- [ ] **Step 1: Add the fake Slack to `test/helpers.js`** (and to `module.exports`):

```js
/** An incoming-webhook stand-in: records each JSON body, answers 200 "ok" like Slack does. */
function serveFakeSlack({ fail = false } = {}) {
  const received = [];
  const server = http.createServer((req, res) => {
    let raw = "";
    req.on("data", (c) => (raw += c));
    req.on("end", () => {
      received.push(JSON.parse(raw || "{}"));
      res.writeHead(fail ? 500 : 200, { "Content-Type": "text/plain" });
      res.end(fail ? "error" : "ok");
    });
  });
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve({ url: `http://127.0.0.1:${server.address().port}/hook`, received, server })));
}
```

- [ ] **Step 2: Write the failing test**

```js
// test/alerts.test.js
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;
const alerts = require("../src/alerts");

let slack, failing, owner, onCall, offDuty, mails;
const fakeMailer = { sendOpsAlert: async ({ to }) => { mails.push(to); return { sent: true }; } };
const deps = () => ({ fetchImpl: fetch, mailer: fakeMailer, webhookUrl: slack.url, dashboardUrl: "https://admin.example" });

before(async () => {
  slack = await h.serveFakeSlack();
  failing = await h.serveFakeSlack({ fail: true });
  owner = await h.ensureAdmin("testsuite-owner@example.com", { role: "owner" });
  onCall = await h.ensureAdmin("testsuite-oncall@example.com", { capabilities: ["finance"] });
  offDuty = await h.ensureAdmin("testsuite-offduty@example.com", { capabilities: ["safety"] });
  await prisma.onCallShift.deleteMany({ where: { adminId: { in: [owner.id, onCall.id, offDuty.id] } } });
  await prisma.opsAlert.deleteMany({ where: { queueKey: { startsWith: "test-" } } });
});
after(async () => {
  slack.server.close();
  failing.server.close();
  await prisma.onCallShift.deleteMany({ where: { adminId: { in: [owner.id, onCall.id, offDuty.id] } } });
  await prisma.opsAlert.deleteMany({ where: { queueKey: { startsWith: "test-" } } });
  await prisma.$disconnect();
});

describe("on call", () => {
  it("finds who is on call at a moment, and nobody outside their shift", async () => {
    const at = new Date("2026-11-14T21:00:00Z");
    await prisma.onCallShift.create({ data: { adminId: onCall.id, startsAt: new Date("2026-11-14T17:00:00Z"), endsAt: new Date("2026-11-15T07:00:00Z") } });
    assert.deepEqual((await alerts.onCallNow(prisma, at)).map((a) => a.id), [onCall.id]);
    assert.deepEqual(await alerts.onCallNow(prisma, new Date("2026-11-15T08:00:00Z")), []);
  });
});

describe("raiseAlert", () => {
  it("an urgent alert goes to Slack and to the person on call, and the row records what was sent", async () => {
    mails = [];
    const before = slack.received.length;
    const row = await alerts.raiseAlert(
      prisma,
      { severity: "urgent", queueKey: "test-chargebacks", title: "Chargeback on ₦55,000", body: "16 working hours to answer.", link: "/inbox" },
      { ...deps(), now: new Date("2026-11-14T21:00:00Z") },
    );
    assert.equal(slack.received.length, before + 1);
    assert.match(slack.received.at(-1).text, /Chargeback on ₦55,000/);
    assert.match(slack.received.at(-1).text, /https:\/\/admin\.example\/inbox/);
    assert.deepEqual(mails, ["testsuite-oncall@example.com"]);
    const back = await prisma.opsAlert.findUnique({ where: { id: row.id } });
    assert.equal(back.slackSent, true);
    assert.deepEqual(back.emailedTo, ["testsuite-oncall@example.com"]);
  });

  it("with nobody on call, an urgent alert emails the owners instead", async () => {
    mails = [];
    await alerts.raiseAlert(prisma, { severity: "urgent", queueKey: "test-safety", title: "Report", body: "A scam report." }, { ...deps(), now: new Date("2026-11-20T12:00:00Z") });
    assert.ok(mails.includes("testsuite-owner@example.com"));
    assert.ok(!mails.includes("testsuite-offduty@example.com"));
  });

  it("a Slack failure is recorded as not sent, and email still goes out", async () => {
    mails = [];
    const row = await alerts.raiseAlert(prisma, { severity: "urgent", queueKey: "test-payouts", title: "Payout failed", body: "x" }, { ...deps(), webhookUrl: failing.url, now: new Date("2026-11-20T12:00:00Z") });
    const back = await prisma.opsAlert.findUnique({ where: { id: row.id } });
    assert.equal(back.slackSent, false);
    assert.ok(mails.length >= 1);
  });

  it("a digest alert is stored, not sent, until the digest goes out once", async () => {
    mails = [];
    const before = slack.received.length;
    await alerts.raiseAlert(prisma, { severity: "digest", queueKey: "test-proof", title: "2 proofs past target", body: "Oldest 5 days." }, deps());
    assert.equal(slack.received.length, before);
    const first = await alerts.sendDigest(prisma, deps());
    assert.ok(first.sent >= 1);
    assert.match(slack.received.at(-1).text, /2 proofs past target/);
    const second = await alerts.sendDigest(prisma, deps());
    assert.equal(second.sent, 0, "nothing is sent twice");
  });

  it("refuses an unknown severity", async () => {
    await assert.rejects(() => alerts.raiseAlert(prisma, { severity: "loud", queueKey: "test-x", title: "t", body: "b" }, deps()), /severity/);
  });
});
```

- [ ] **Step 3: Run it to see it fail.** Run: `node --env-file=.env.test --test test/alerts.test.js` — Expected: FAIL, module not found.

- [ ] **Step 4: Add `sendOpsAlert` to `src/admin/mailer.js`** (next to `sendEscalationToAdmin`, and add it to `module.exports`):

```js
function sendOpsAlert({ to, title, body, link }) {
  const linkHtml = link ? `<p><a href="${escapeHtml(link)}">Open in the admin dashboard</a></p>` : "";
  return send({
    to,
    subject: `King Domain alert: ${title}`,
    html: `<p><strong>${escapeHtml(title)}</strong></p><p>${escapeHtml(body)}</p>${linkHtml}`,
    fallbackContext: `ops alert "${title}"`,
  });
}
```

If `mailer.js` has no `escapeHtml`, add above it:

```js
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}
```

- [ ] **Step 5: Write `src/alerts.js`**

```js
// Alerts to the team (PRD §4.11, decisions D45 and D46). Urgent alerts go out at once to Slack
// (phones get them through the Slack app) and by email to whoever is on call, or to the owners
// when nobody is. Digest alerts wait for one daily message. Each row records what was actually
// sent (read back from Slack's answer and the mailer's result), not what was attempted.

const { prisma: defaultDb } = require("./db");
const mailer = require("./admin/mailer");
const { QUEUES, inboxFor } = require("./admin/inbox");

const SEVERITIES = ["urgent", "digest"];
const DIGEST_HOUR_LAGOS = 8; // 08:00 Africa/Lagos (UTC+1, no daylight saving)

function defaults(deps = {}) {
  return {
    fetchImpl: deps.fetchImpl ?? fetch,
    mailer: deps.mailer ?? mailer,
    webhookUrl: deps.webhookUrl ?? process.env.OPS_SLACK_WEBHOOK_URL ?? "",
    dashboardUrl: deps.dashboardUrl ?? process.env.ADMIN_DASHBOARD_URL ?? "",
    now: deps.now ?? new Date(),
  };
}

async function onCallNow(db, at = new Date()) {
  const shifts = await db.onCallShift.findMany({
    where: { startsAt: { lte: at }, endsAt: { gt: at }, admin: { status: "active" } },
    include: { admin: true },
  });
  return shifts.map((s) => s.admin);
}

async function postSlack(d, text) {
  if (!d.webhookUrl) return false;
  try {
    const r = await d.fetchImpl(d.webhookUrl, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ text }) });
    return r.ok;
  } catch (err) {
    console.error("alerts: slack post failed:", err.message);
    return false;
  }
}

const fullLink = (d, link) => (link ? `${d.dashboardUrl}${link}` : null);

async function raiseAlert(db, { severity, queueKey, title, body, link = null }, deps) {
  if (!SEVERITIES.includes(severity)) throw new Error(`Unknown alert severity "${severity}".`);
  const d = defaults(deps);
  const row = await db.opsAlert.create({ data: { severity, queueKey, title, body, link } });
  if (severity === "digest") {
    console.log(`alerts: digest queued queue=${queueKey} alert=${row.id}`);
    return row;
  }

  const url = fullLink(d, link);
  const slackSent = await postSlack(d, `:rotating_light: *${title}*\n${body}${url ? `\n${url}` : ""}`);

  let recipients = await onCallNow(db, d.now);
  const reason = recipients.length ? "on-call" : "no-one-on-call:owners";
  if (!recipients.length) recipients = await db.adminUser.findMany({ where: { role: "owner", status: "active" } });
  const emailedTo = [];
  for (const admin of recipients) {
    const result = await d.mailer.sendOpsAlert({ to: admin.email, title, body, link: url });
    if (result?.sent) emailedTo.push(admin.email);
  }

  const back = await db.opsAlert.update({ where: { id: row.id }, data: { slackSent, emailedTo } });
  console.log(`alerts: urgent queue=${queueKey} alert=${back.id} slackSent=${back.slackSent} emailed=${back.emailedTo.length}/${recipients.length} via=${reason}`);
  return back;
}

async function sendDigest(db, deps) {
  const d = defaults(deps);
  const due = await db.opsAlert.findMany({ where: { severity: "digest", digestedAt: null }, orderBy: { createdAt: "asc" } });
  if (!due.length) return { sent: 0 };
  const lines = due.map((a) => `• *${a.title}*: ${a.body}${a.link ? ` ${fullLink(d, a.link)}` : ""}`);
  const slackSent = await postSlack(d, `*King Domain daily digest*\n${lines.join("\n")}`);
  const owners = await db.adminUser.findMany({ where: { role: "owner", status: "active" } });
  for (const o of owners) {
    await d.mailer.sendOpsAlert({ to: o.email, title: "Daily digest", body: due.map((a) => `${a.title}: ${a.body}`).join("\n"), link: fullLink(d, "/inbox") });
  }
  const marked = await db.opsAlert.updateMany({ where: { id: { in: due.map((a) => a.id) }, digestedAt: null }, data: { digestedAt: d.now } });
  console.log(`alerts: digest items=${due.length} marked=${marked.count} slackSent=${slackSent} owners=${owners.length}`);
  return { sent: marked.count };
}

/** One digest alert per queue per day while the queue has overdue items. */
async function sweepOverdue(db, now = new Date()) {
  const owner = { role: "owner", capabilities: [] }; // sees every queue
  const queues = await inboxFor(db, owner, now);
  const dayStart = new Date(now);
  dayStart.setUTCHours(0, 0, 0, 0);
  let raised = 0;
  for (const q of queues.filter((q) => q.overdue > 0)) {
    const already = await db.opsAlert.findFirst({ where: { queueKey: q.key, severity: "digest", createdAt: { gte: dayStart } } });
    if (already) continue;
    await raiseAlert(db, {
      severity: "digest",
      queueKey: q.key,
      title: `${q.overdue} in ${q.label} past target`,
      body: `Oldest has waited ${Math.round(q.oldestWaitingMinutes / 60)} h; target ${Math.round(q.targetMinutes / 60)} h.`,
      link: q.path,
    });
    raised++;
  }
  return raised;
}

function lagosHour(date) {
  return (date.getUTCHours() + 1) % 24;
}

/** Every interval: sweep overdue queues; once a day at 08:00 Lagos, send the digest. */
function startOpsScheduler({ intervalMs = 15 * 60 * 1000 } = {}) {
  if (process.env.OPS_SCHEDULER === "off") {
    console.log("alerts: ops scheduler off");
    return null;
  }
  const tick = async () => {
    try {
      await sweepOverdue(defaultDb);
      if (lagosHour(new Date()) === DIGEST_HOUR_LAGOS) await sendDigest(defaultDb);
    } catch (err) {
      console.error("alerts: ops tick failed:", err);
    }
  };
  const timer = setInterval(tick, intervalMs);
  timer.unref?.();
  console.log(`alerts: ops scheduler running every ${Math.round(intervalMs / 60000)} min; queues=${QUEUES.map((q) => q.key).join(",")}`);
  return timer;
}

module.exports = { SEVERITIES, onCallNow, raiseAlert, sendDigest, sweepOverdue, startOpsScheduler, lagosHour };
```

Because the digest only goes out during the 08:00 hour and `sendDigest` marks what it sent, a restart inside that hour cannot send the same items twice; items raised after the digest wait for the next day.

- [ ] **Step 6: Run it to see it pass.** Run: `node --env-file=.env.test --test test/alerts.test.js` — Expected: PASS, 6 tests.

- [ ] **Step 7: Commit**

```bash
git add src/alerts.js src/admin/mailer.js test/helpers.js test/alerts.test.js
git commit -m "Alerts: urgent alerts to Slack and the person on call (owners when nobody is), a daily digest, and a daily overdue sweep; rows record what was actually sent

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task A6: The ops routes (inbox, targets, audit log, on-call, capabilities, test alert)

**Files:**
- Create: `king-domain-backend/src/admin/opsRoutes.js`
- Modify: `king-domain-backend/src/index.js` (mount, start the scheduler), `king-domain-backend/test/helpers.js` (`startServer` accepts `env`)
- Test: `king-domain-backend/test/opsRoutes.test.js`

**Interfaces:**
- Consumes: A1 `isSkillKey`, A3 `requireCapability`/`recordAudit`/`CAPABILITIES`, A4 `inboxFor`/`QUEUES`, A5 `raiseAlert`/`startOpsScheduler`, `requireAdmin`/`requireOwner` from `src/admin/routes.js`.
- Produces (all under `/admin`, all need a signed-in admin):
  - `GET /admin/inbox → {queues: QueueSummary[]}`
  - `PUT /admin/inbox/targets/:queueKey` (owner) body `{targetMinutes: 1..43200, defaultWhenLate: 5..300 chars}` → `{target}`; audited `queue.target`.
  - `GET /admin/audit?subjectType=&subjectId=&actorId=&action=&before=&limit=` (owner or shareholder) → `{events: {id, action, subjectType, subjectId, reasonCode, note, details, actorRole, createdAt, actor: {id, name, email}}[], nextBefore: string | null}`; newest first, `limit` 1..100 (default 50), `before` an ISO date for paging.
  - `GET /admin/on-call?from=` (any admin) → `{shifts: {id, startsAt, endsAt, admin: {id, name, email}}[]}` (shifts ending after `from`, default now).
  - `POST /admin/on-call` (owner) body `{adminId, startsAt, endsAt}` → 201 `{shift}`; `endsAt > startsAt`, at most 7 days long; audited `oncall.create`.
  - `DELETE /admin/on-call/:id` (owner) → `{ok: true}`; audited `oncall.delete`.
  - `PATCH /admin/admins/:id/capabilities` (owner) body `{capabilities: string[], reviewerSkills: string[]}` → `{admin}` (publicUser); audited `admin.capabilities` with before/after.
  - `POST /admin/alerts/test` (owner) → `{alert}`; raises an urgent alert "Test alert from {name}".
  - `startServer({ …, env })` merges `env` into the child environment; `OPS_SCHEDULER: "off"` is always set for tests.

- [ ] **Step 1: Let `startServer` take extra env.** In `test/helpers.js`, change the signature to `async function startServer({ port, paystackUrl, autoRelease = true, storageUrl, env = {} })` and in the `env: { … }` object add, after `SUPABASE_SERVICE_ROLE_KEY: …,`:

```js
      OPS_SCHEDULER: "off", // a test server never sweeps or sends a digest on its own
      OPS_SLACK_WEBHOOK_URL: "", // and never posts to the real Slack unless a test passes a fake
      ...env,
```

- [ ] **Step 2: Write the failing route test**

```js
// test/opsRoutes.test.js — the ops routes over real HTTP.
const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const h = require("./helpers");
const { prisma } = h;

let server, slack, owner, reader, shareholder, target, tOwner, tReader, tShare;
before(async () => {
  slack = await h.serveFakeSlack();
  owner = await h.ensureAdmin("testsuite-owner@example.com", { role: "owner" });
  reader = await h.ensureAdmin("testsuite-reader@example.com");
  shareholder = await h.ensureAdmin("testsuite-shareholder@example.com", { capabilities: ["shareholder"] });
  target = await h.ensureAdmin("testsuite-target@example.com");
  await prisma.onCallShift.deleteMany({ where: { adminId: { in: [owner.id, target.id] } } });
  await prisma.queueTarget.deleteMany({ where: { queueKey: "proof" } });
  server = await h.startServer({ port: 4622, paystackUrl: "http://127.0.0.1:9", autoRelease: false, env: { OPS_SLACK_WEBHOOK_URL: slack.url, ADMIN_DASHBOARD_URL: "https://admin.example" } });
  [tOwner, tReader, tShare] = await Promise.all([owner, reader, shareholder].map(h.adminTokenFor));
});
after(async () => {
  server?.stop();
  slack.server.close();
  await prisma.onCallShift.deleteMany({ where: { adminId: { in: [owner.id, target.id] } } });
  await prisma.queueTarget.deleteMany({ where: { queueKey: "proof" } });
  await prisma.opsAlert.deleteMany({ where: { title: { startsWith: "Test alert from" } } });
  await prisma.adminAuditEvent.deleteMany({ where: { actorId: owner.id } });
  await prisma.$disconnect();
});

const api = (tok, method, p, body) => h.call(server.base, tok, method, p, body);

describe("GET /admin/inbox", () => {
  it("shows the proof queue to an owner and nothing to an admin without capabilities", async () => {
    const o = await api(tOwner, "GET", "/admin/inbox");
    assert.equal(o.status, 200);
    assert.ok(o.json.queues.some((q) => q.key === "proof" && q.path === "/proof-review"));
    const r = await api(tReader, "GET", "/admin/inbox");
    assert.deepEqual(r.json.queues, []);
  });
});

describe("PUT /admin/inbox/targets/:queueKey", () => {
  it("an owner changes a target; bad input and non-owners are refused; unknown queues are 404", async () => {
    const ok = await api(tOwner, "PUT", "/admin/inbox/targets/proof", { targetMinutes: 2880, defaultWhenLate: "Escalate to the owner." });
    assert.equal(ok.status, 200, JSON.stringify(ok.json));
    assert.equal(ok.json.target.targetMinutes, 2880);
    assert.equal((await api(tOwner, "PUT", "/admin/inbox/targets/proof", { targetMinutes: 0, defaultWhenLate: "x" })).status, 400);
    assert.equal((await api(tReader, "PUT", "/admin/inbox/targets/proof", { targetMinutes: 60, defaultWhenLate: "Escalate." })).status, 403);
    assert.equal((await api(tOwner, "PUT", "/admin/inbox/targets/nope", { targetMinutes: 60, defaultWhenLate: "Escalate." })).status, 404);
  });
});

describe("capabilities", () => {
  it("an owner grants capabilities and reviewer skills, and it is audited with before and after", async () => {
    const r = await api(tOwner, "PATCH", `/admin/admins/${target.id}/capabilities`, { capabilities: ["reviewer", "checker"], reviewerSkills: ["writing"] });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.deepEqual(r.json.admin.capabilities.sort(), ["checker", "reviewer"]);
    assert.deepEqual(r.json.admin.reviewerSkills, ["writing"]);
    const [e] = await prisma.adminAuditEvent.findMany({ where: { action: "admin.capabilities", subjectId: target.id }, orderBy: { createdAt: "desc" }, take: 1 });
    assert.deepEqual(e.details.after.capabilities.sort(), ["checker", "reviewer"]);
  });

  it("refuses unknown capabilities and unknown skills", async () => {
    assert.equal((await api(tOwner, "PATCH", `/admin/admins/${target.id}/capabilities`, { capabilities: ["wizard"], reviewerSkills: [] })).status, 400);
    assert.equal((await api(tOwner, "PATCH", `/admin/admins/${target.id}/capabilities`, { capabilities: ["reviewer"], reviewerSkills: ["juggling"] })).status, 400);
    assert.equal((await api(tReader, "PATCH", `/admin/admins/${target.id}/capabilities`, { capabilities: [], reviewerSkills: [] })).status, 403);
  });
});

describe("on-call", () => {
  it("an owner adds and removes a shift; everyone can read the rota; bad shifts are refused", async () => {
    const add = await api(tOwner, "POST", "/admin/on-call", { adminId: target.id, startsAt: "2026-11-14T17:00:00Z", endsAt: "2026-11-15T07:00:00Z" });
    assert.equal(add.status, 201, JSON.stringify(add.json));
    const list = await api(tReader, "GET", "/admin/on-call?from=2026-11-01T00:00:00Z");
    assert.ok(list.json.shifts.some((s) => s.id === add.json.shift.id && s.admin.id === target.id));
    assert.equal((await api(tOwner, "POST", "/admin/on-call", { adminId: target.id, startsAt: "2026-11-15T07:00:00Z", endsAt: "2026-11-14T17:00:00Z" })).status, 400);
    assert.equal((await api(tOwner, "POST", "/admin/on-call", { adminId: target.id, startsAt: "2026-11-01T00:00:00Z", endsAt: "2026-11-20T00:00:00Z" })).status, 400);
    assert.equal((await api(tReader, "POST", "/admin/on-call", { adminId: target.id, startsAt: "2026-11-14T17:00:00Z", endsAt: "2026-11-15T07:00:00Z" })).status, 403);
    assert.equal((await api(tOwner, "DELETE", `/admin/on-call/${add.json.shift.id}`)).status, 200);
  });
});

describe("audit log and test alert", () => {
  it("an owner sends a test alert that reaches Slack, and the shareholder reads it in the audit log", async () => {
    const before = slack.received.length;
    const t = await api(tOwner, "POST", "/admin/alerts/test");
    assert.equal(t.status, 200, JSON.stringify(t.json));
    assert.equal(slack.received.length, before + 1);
    assert.equal(t.json.alert.slackSent, true);
    const log = await api(tShare, "GET", "/admin/audit?action=alert.test&limit=5");
    assert.equal(log.status, 200);
    assert.ok(log.json.events.some((e) => e.action === "alert.test" && e.actor.id === owner.id));
    assert.equal((await api(tReader, "GET", "/admin/audit")).status, 403);
  });
});
```

- [ ] **Step 3: Run it to see it fail.** Run: `node --env-file=.env.test --test test/opsRoutes.test.js` — Expected: FAIL (404s: the routes don't exist yet).

- [ ] **Step 4: Write `src/admin/opsRoutes.js`**

```js
const express = require("express");
const { prisma } = require("../db");
const { requireAdmin, requireOwner, publicUser } = require("./routes");
const { CAPABILITIES, requireCapability } = require("./capabilities");
const { recordAudit } = require("./audit");
const { QUEUES, inboxFor } = require("./inbox");
const { raiseAlert } = require("../alerts");
const { isSkillKey } = require("../skills");

const router = express.Router();
router.use(requireAdmin);

const MAX_SHIFT_MS = 7 * 24 * 3600 * 1000;

router.get("/inbox", async (req, res) => {
  res.json({ queues: await inboxFor(prisma, req.admin) });
});

router.put("/inbox/targets/:queueKey", requireOwner, async (req, res) => {
  const queue = QUEUES.find((q) => q.key === req.params.queueKey);
  if (!queue) return res.status(404).json({ error: "No such queue." });
  const { targetMinutes, defaultWhenLate } = req.body ?? {};
  if (!Number.isInteger(targetMinutes) || targetMinutes < 1 || targetMinutes > 43200) {
    return res.status(400).json({ error: "targetMinutes must be a whole number from 1 to 43200 (30 days)." });
  }
  if (typeof defaultWhenLate !== "string" || defaultWhenLate.trim().length < 5 || defaultWhenLate.length > 300) {
    return res.status(400).json({ error: "Say what happens when the target passes, in 5 to 300 characters." });
  }
  const target = await prisma.$transaction(async (tx) => {
    const before = await tx.queueTarget.findUnique({ where: { queueKey: queue.key } });
    const row = await tx.queueTarget.upsert({
      where: { queueKey: queue.key },
      update: { targetMinutes, defaultWhenLate: defaultWhenLate.trim() },
      create: { queueKey: queue.key, targetMinutes, defaultWhenLate: defaultWhenLate.trim() },
    });
    await recordAudit(tx, req.admin, { action: "queue.target", subjectType: "Queue", subjectId: queue.key, details: { before, after: { targetMinutes: row.targetMinutes, defaultWhenLate: row.defaultWhenLate } } });
    return row;
  });
  res.json({ target });
});

router.get("/audit", requireCapability("shareholder"), async (req, res) => {
  const { subjectType, subjectId, actorId, action, before } = req.query;
  const limit = Math.min(100, Math.max(1, Number.parseInt(req.query.limit ?? "50", 10) || 50));
  const where = {
    ...(subjectType ? { subjectType: String(subjectType) } : {}),
    ...(subjectId ? { subjectId: String(subjectId) } : {}),
    ...(actorId ? { actorId: String(actorId) } : {}),
    ...(action ? { action: String(action) } : {}),
    ...(before && !Number.isNaN(Date.parse(before)) ? { createdAt: { lt: new Date(before) } } : {}),
  };
  const rows = await prisma.adminAuditEvent.findMany({
    where,
    orderBy: { createdAt: "desc" },
    take: limit + 1,
    include: { actor: { select: { id: true, name: true, email: true } } },
  });
  const page = rows.slice(0, limit);
  res.json({
    events: page.map((e) => ({ id: e.id, action: e.action, subjectType: e.subjectType, subjectId: e.subjectId, reasonCode: e.reasonCode, note: e.note, details: e.details, actorRole: e.actorRole, createdAt: e.createdAt, actor: e.actor })),
    nextBefore: rows.length > limit ? page.at(-1).createdAt.toISOString() : null,
  });
});

router.get("/on-call", async (req, res) => {
  const from = req.query.from && !Number.isNaN(Date.parse(req.query.from)) ? new Date(req.query.from) : new Date();
  const shifts = await prisma.onCallShift.findMany({
    where: { endsAt: { gt: from } },
    orderBy: { startsAt: "asc" },
    take: 100,
    include: { admin: { select: { id: true, name: true, email: true } } },
  });
  res.json({ shifts: shifts.map((s) => ({ id: s.id, startsAt: s.startsAt, endsAt: s.endsAt, admin: s.admin })) });
});

router.post("/on-call", requireOwner, async (req, res) => {
  const { adminId, startsAt, endsAt } = req.body ?? {};
  const start = new Date(startsAt);
  const end = new Date(endsAt);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
    return res.status(400).json({ error: "A shift needs a start and an end after it." });
  }
  if (end - start > MAX_SHIFT_MS) return res.status(400).json({ error: "A shift can be at most 7 days long." });
  const admin = await prisma.adminUser.findUnique({ where: { id: String(adminId ?? "") } });
  if (!admin || admin.status !== "active") return res.status(400).json({ error: "Choose an active team member." });
  const shift = await prisma.$transaction(async (tx) => {
    const row = await tx.onCallShift.create({ data: { adminId: admin.id, startsAt: start, endsAt: end } });
    await recordAudit(tx, req.admin, { action: "oncall.create", subjectType: "OnCallShift", subjectId: row.id, details: { adminId: admin.id, startsAt: start, endsAt: end } });
    return row;
  });
  res.status(201).json({ shift });
});

router.delete("/on-call/:id", requireOwner, async (req, res) => {
  const shift = await prisma.onCallShift.findUnique({ where: { id: req.params.id } });
  if (!shift) return res.status(404).json({ error: "Shift not found." });
  await prisma.$transaction(async (tx) => {
    await tx.onCallShift.delete({ where: { id: shift.id } });
    await recordAudit(tx, req.admin, { action: "oncall.delete", subjectType: "OnCallShift", subjectId: shift.id, details: { adminId: shift.adminId, startsAt: shift.startsAt, endsAt: shift.endsAt } });
  });
  res.json({ ok: true });
});

router.patch("/admins/:id/capabilities", requireOwner, async (req, res) => {
  const { capabilities, reviewerSkills } = req.body ?? {};
  if (!Array.isArray(capabilities) || capabilities.some((c) => !CAPABILITIES.includes(c))) {
    return res.status(400).json({ error: `capabilities must be a list drawn from: ${CAPABILITIES.join(", ")}.` });
  }
  if (!Array.isArray(reviewerSkills) || reviewerSkills.some((s) => !isSkillKey(s))) {
    return res.status(400).json({ error: "reviewerSkills must be skill keys from GET /skills." });
  }
  const target = await prisma.adminUser.findUnique({ where: { id: req.params.id } });
  if (!target) return res.status(404).json({ error: "Admin not found." });
  const caps = [...new Set(capabilities)];
  const skills = [...new Set(reviewerSkills)];
  const updated = await prisma.$transaction(async (tx) => {
    const row = await tx.adminUser.update({ where: { id: target.id }, data: { capabilities: caps, reviewerSkills: skills } });
    await recordAudit(tx, req.admin, {
      action: "admin.capabilities",
      subjectType: "AdminUser",
      subjectId: target.id,
      details: { before: { capabilities: target.capabilities, reviewerSkills: target.reviewerSkills }, after: { capabilities: row.capabilities, reviewerSkills: row.reviewerSkills } },
    });
    return row;
  });
  res.json({ admin: publicUser(updated) });
});

router.post("/alerts/test", requireOwner, async (req, res) => {
  const name = req.admin.name || req.admin.email;
  const alert = await raiseAlert(prisma, { severity: "urgent", queueKey: "test", title: `Test alert from ${name}`, body: "If you can read this on your phone, urgent alerts reach you.", link: "/inbox" });
  await recordAudit(prisma, req.admin, { action: "alert.test", subjectType: "OpsAlert", subjectId: alert.id, details: { slackSent: alert.slackSent, emailedTo: alert.emailedTo } });
  res.json({ alert });
});

module.exports = { router };
```

`src/admin/routes.js` currently ends with `module.exports = { router, requireAdmin };`. Change it to `module.exports = { router, requireAdmin, requireOwner, publicUser };` (both functions already exist in that file) so the ops routes share the owner guard and user shape.

- [ ] **Step 5: Mount and start.** In `src/index.js`:
  - add `const adminOps = require("./admin/opsRoutes");` and `const { startOpsScheduler } = require("./alerts");` with the other requires;
  - add `app.use("/admin", adminOps.router);` directly after `app.use("/admin/proof-items", adminProofReview.router);`;
  - inside `app.listen(…)`, after `startPushDispatcher();` add `startOpsScheduler({ intervalMs: minutesFromEnv("OPS_SCHEDULER_INTERVAL_MIN", 15) });`.

- [ ] **Step 6: Run the route tests to see them pass.** Run: `node --env-file=.env.test --test test/opsRoutes.test.js` — Expected: PASS, 6 tests.

- [ ] **Step 7: Check the earlier admin tests still pass.** Run: `node --env-file=.env.test --test test/audit.test.js test/inbox.test.js test/alerts.test.js` — Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/admin/opsRoutes.js src/admin/routes.js src/index.js test/helpers.js test/opsRoutes.test.js
git commit -m "Admin ops routes: inbox, editable queue targets, audit log, on-call rota, capability editing, test alert; ops scheduler started with the server

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Part B — Admin dashboard

The dashboard has no test runner. Each task is checked with `npm run build` (TypeScript), `npm run lint`, and in a browser against a local backend: `VITE_API_BASE=http://localhost:4000 npm run dev` in `king-domain-admin`, with the backend running `npm run dev` against a database that has the A2 schema.

### Task B1: API types and calls

**Files:**
- Modify: `king-domain-admin/src/lib/api.ts`
- Create: `king-domain-admin/src/lib/capabilities.ts`

**Interfaces:**
- Consumes: the A1 and A6 endpoints.
- Produces: types `AdminCapability`, `Skill`, `SkillCategory`, `QueueSummary`, `AuditEvent`, `OnCallShift`, `OpsAlert`; `AdminUser` gains `capabilities: AdminCapability[]`, `reviewerSkills: string[]`; `api.skills()`, `api.inbox()`, `api.setQueueTarget(key, body)`, `api.audit(params)`, `api.onCall(from?)`, `api.addOnCall(body)`, `api.removeOnCall(id)`, `api.setCapabilities(id, body)`, `api.testAlert()`. `can(user, capability) → boolean`, `CAPABILITY_LABELS: Record<AdminCapability, {label, does}>`, `formatMinutes(min: number | null) → string`.

- [ ] **Step 1: Add the types** to `src/lib/api.ts`, below `export type AdminStatus`:

```ts
export type AdminCapability = 'reviewer' | 'checker' | 'safety' | 'disputes' | 'finance' | 'support' | 'shareholder'
```

and change `AdminUser` to:

```ts
export type AdminUser = {
  id: string
  email: string
  name: string | null
  role: AdminRole
  status: AdminStatus
  capabilities: AdminCapability[]
  reviewerSkills: string[]
  lastLoginAt: string | null
  createdAt: string
}
```

Add near the other types:

```ts
export type StartProofField = { key: string; label: string; kind: 'files' | 'image' | 'video' | 'text' | 'link'; min: number; max: number }
export type Skill = { key: string; label: string; category: string; open: boolean; startProof: StartProofField[] }
export type SkillCategory = { key: string; label: string }

export type QueueSummary = {
  key: string
  label: string
  path: string
  capability: AdminCapability
  targetMinutes: number
  defaultWhenLate: string
  open: number
  overdue: number
  oldestWaitingMinutes: number | null
  p50Minutes: number | null
  p90Minutes: number | null
  sample: number
}

export type AuditEvent = {
  id: string
  action: string
  subjectType: string
  subjectId: string
  reasonCode: string | null
  note: string | null
  details: unknown
  actorRole: string
  createdAt: string
  actor: { id: string; name: string | null; email: string }
}

export type OnCallShift = { id: string; startsAt: string; endsAt: string; admin: { id: string; name: string | null; email: string } }
export type OpsAlert = { id: string; title: string; slackSent: boolean; emailedTo: string[] }
```

- [ ] **Step 2: Add the calls** inside `export const api = { … }`, after `proofCounts`:

```ts
  skills: () => request<{ categories: SkillCategory[]; skills: Skill[] }>('/skills'),

  inbox: () => request<{ queues: QueueSummary[] }>('/admin/inbox'),

  setQueueTarget: (key: string, body: { targetMinutes: number; defaultWhenLate: string }) =>
    request<{ target: { queueKey: string; targetMinutes: number; defaultWhenLate: string } }>(
      `/admin/inbox/targets/${encodeURIComponent(key)}`,
      { method: 'PUT', body: JSON.stringify(body) },
    ),

  audit: (params: { action?: string; subjectId?: string; actorId?: string; before?: string; limit?: number } = {}) => {
    const q = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== '') q.set(k, String(v))
    return request<{ events: AuditEvent[]; nextBefore: string | null }>(`/admin/audit?${q}`)
  },

  onCall: (from?: string) =>
    request<{ shifts: OnCallShift[] }>(`/admin/on-call${from ? `?from=${encodeURIComponent(from)}` : ''}`),

  addOnCall: (body: { adminId: string; startsAt: string; endsAt: string }) =>
    request<{ shift: { id: string } }>('/admin/on-call', { method: 'POST', body: JSON.stringify(body) }),

  removeOnCall: (id: string) => request<{ ok: true }>(`/admin/on-call/${id}`, { method: 'DELETE' }),

  setCapabilities: (id: string, body: { capabilities: AdminCapability[]; reviewerSkills: string[] }) =>
    request<{ admin: AdminUser }>(`/admin/admins/${id}/capabilities`, { method: 'PATCH', body: JSON.stringify(body) }),

  testAlert: () => request<{ alert: OpsAlert }>('/admin/alerts/test', { method: 'POST' }),
```

- [ ] **Step 3: Write `src/lib/capabilities.ts`**

```ts
import type { AdminCapability, AdminUser } from './api'

/** Mirrors the backend: an owner can do everything; anyone else needs the capability. */
export function can(user: AdminUser | null | undefined, capability: AdminCapability): boolean {
  if (!user) return false
  return user.role === 'owner' || user.capabilities.includes(capability)
}

export const CAPABILITY_LABELS: Record<AdminCapability, { label: string; does: string }> = {
  reviewer: { label: 'Reviewer', does: 'Reviews proof in the skills chosen for them' },
  checker: { label: 'Checker', does: 'Checks authenticity, identity and student documents' },
  safety: { label: 'Safety', does: 'Handles reports and screens first job posts' },
  disputes: { label: 'Disputes', does: 'Rules on disputes and start-proof objections' },
  finance: { label: 'Finance', does: 'Refunds, splits, chargebacks and payout failures' },
  support: { label: 'Support', does: 'Builds shortlists and answers help requests' },
  shareholder: { label: 'Shareholder', does: 'Reads the ledger, metrics and audit log' },
}

/** "45 min", "6 h", "3 days", or "not enough data yet" for null. */
export function formatMinutes(min: number | null): string {
  if (min === null) return 'not enough data yet'
  if (min < 60) return `${min} min`
  const h = Math.round(min / 60)
  if (h < 48) return `${h} h`
  const d = Math.round(h / 24)
  return `${d} day${d === 1 ? '' : 's'}`
}
```

- [ ] **Step 4: Build.** Run (in `king-domain-admin`): `npm run build` — Expected: success. If an existing page now fails because a test fixture or literal `AdminUser` lacks `capabilities`, add `capabilities: [], reviewerSkills: []` there.

- [ ] **Step 5: Commit**

```bash
git add src/lib/api.ts src/lib/capabilities.ts
git commit -m "Admin: types and calls for capabilities, skills, inbox, audit log, on-call and test alerts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task B2: The Inbox page

**Files:**
- Create: `king-domain-admin/src/pages/Inbox.tsx`
- Modify: `king-domain-admin/src/App.tsx` (route), `king-domain-admin/src/components/Shell.tsx` (nav)

**Interfaces:**
- Consumes: `api.inbox`, `api.setQueueTarget`, `formatMinutes`, `useAuth`.
- Produces: route `/inbox`; nav item "Inbox" first.

- [ ] **Step 1: Write `src/pages/Inbox.tsx`**

```tsx
import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { toast } from 'sonner'
import { AlertTriangle, ChevronRight, Clock, Inbox as InboxIcon, Pencil, RefreshCw } from 'lucide-react'
import { api, ApiError, type QueueSummary } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { formatMinutes } from '@/lib/capabilities'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Sentry } from '@/lib/sentry'

export function Inbox() {
  const { user } = useAuth()
  const [queues, setQueues] = useState<QueueSummary[] | null>(null)
  const [failed, setFailed] = useState(false)
  const [editing, setEditing] = useState<QueueSummary | null>(null)

  const load = useCallback(() => {
    setFailed(false)
    api
      .inbox()
      .then((r) => setQueues(r.queues))
      .catch((err: unknown) => {
        Sentry.captureException(err, { tags: { page: 'inbox' } })
        setFailed(true)
      })
  }, [])

  useEffect(load, [load])

  return (
    <div className="mx-auto w-full max-w-3xl space-y-4 p-4 sm:p-6">
      <header className="flex items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-2xl font-semibold">Inbox</h1>
          <p className="text-sm text-muted-foreground">Everything waiting on the team, with how long it may wait.</p>
        </div>
        <Button variant="ghost" size="icon" onClick={load} aria-label="Refresh">
          <RefreshCw className="size-4" />
        </Button>
      </header>

      {failed && (
        <Card className="flex items-center justify-between gap-3 p-4">
          <p className="text-sm">Couldn't load the inbox. Check your connection.</p>
          <Button size="sm" onClick={load}>Retry</Button>
        </Card>
      )}

      {!failed && queues === null && [0, 1].map((i) => <Skeleton key={i} className="h-28 w-full rounded-xl" />)}

      {!failed && queues?.length === 0 && (
        <Card className="flex flex-col items-center gap-2 p-8 text-center">
          <InboxIcon className="size-6 text-muted-foreground" />
          <p className="font-medium">No queues for you yet</p>
          <p className="max-w-sm text-sm text-muted-foreground">
            Queues appear here once an owner gives you a role on the Team page, such as Reviewer or Finance.
          </p>
        </Card>
      )}

      {queues?.map((q) => (
        <Card key={q.key} className="space-y-3 p-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="font-medium">{q.label}</p>
              <p className="text-sm text-muted-foreground">
                {q.open === 0 ? 'Nothing waiting.' : `${q.open} waiting`}
                {q.overdue > 0 && <span className="ml-2 font-medium text-destructive">{q.overdue} past target</span>}
              </p>
            </div>
            <Button asChild size="sm" variant={q.overdue > 0 ? 'default' : 'secondary'}>
              <Link to={q.path}>
                Open <ChevronRight className="size-4" />
              </Link>
            </Button>
          </div>

          <dl className="grid grid-cols-2 gap-x-4 gap-y-1 text-sm sm:grid-cols-4">
            <div><dt className="text-muted-foreground">Target</dt><dd>{formatMinutes(q.targetMinutes)}</dd></div>
            <div><dt className="text-muted-foreground">Oldest</dt><dd>{q.oldestWaitingMinutes === null ? '—' : formatMinutes(q.oldestWaitingMinutes)}</dd></div>
            <div><dt className="text-muted-foreground">Typical</dt><dd>{formatMinutes(q.p50Minutes)}</dd></div>
            <div><dt className="text-muted-foreground">Slowest 10%</dt><dd>{formatMinutes(q.p90Minutes)}</dd></div>
          </dl>

          <p className="flex items-start gap-2 text-sm text-muted-foreground">
            {q.overdue > 0 ? <AlertTriangle className="mt-0.5 size-4 shrink-0 text-destructive" /> : <Clock className="mt-0.5 size-4 shrink-0" />}
            <span>If it waits past the target: {q.defaultWhenLate}</span>
          </p>

          {q.sample > 0 && <p className="text-xs text-muted-foreground">Times from the last {q.sample} handled.</p>}

          {user?.role === 'owner' && (
            <Button variant="ghost" size="sm" onClick={() => setEditing(q)}>
              <Pencil className="size-4" /> Edit target
            </Button>
          )}
        </Card>
      ))}

      {editing && <TargetDialog queue={editing} onClose={() => setEditing(null)} onSaved={load} />}
    </div>
  )
}

function TargetDialog({ queue, onClose, onSaved }: { queue: QueueSummary; onClose: () => void; onSaved: () => void }) {
  const [hours, setHours] = useState(String(Math.round(queue.targetMinutes / 60)))
  const [whenLate, setWhenLate] = useState(queue.defaultWhenLate)
  const [saving, setSaving] = useState(false)
  const h = Number(hours)
  const valid = Number.isFinite(h) && h > 0 && h <= 720 && whenLate.trim().length >= 5

  async function save() {
    setSaving(true)
    try {
      await api.setQueueTarget(queue.key, { targetMinutes: Math.round(h * 60), defaultWhenLate: whenLate.trim() })
      toast.success('Target saved')
      onSaved()
      onClose()
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : 'Could not save the target.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Target for {queue.label}</DialogTitle>
          <DialogDescription>Measure before promising: set a target the team can keep nine times in ten.</DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          <div className="space-y-1">
            <Label htmlFor="hours">Hours</Label>
            <Input id="hours" inputMode="numeric" value={hours} onChange={(e) => setHours(e.target.value)} />
          </div>
          <div className="space-y-1">
            <Label htmlFor="late">What happens when it passes</Label>
            <Input id="late" value={whenLate} onChange={(e) => setWhenLate(e.target.value)} />
          </div>
        </div>
        <DialogFooter>
          <Button variant="secondary" onClick={onClose}>Cancel</Button>
          <Button onClick={save} disabled={!valid || saving}>{saving ? 'Saving…' : 'Save'}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
```

`@/components/ui/button` supports `asChild` (radix Slot, checked 2026-10-31).

- [ ] **Step 2: Route and nav.** In `src/App.tsx` add `import { Inbox } from '@/pages/Inbox'` and inside `<Route element={<Protected />}>`, before `<Route index …>`: `<Route path="inbox" element={<Inbox />} />`. In `src/components/Shell.tsx`, make the first nav entry `{ to: '/inbox', label: 'Inbox' },`.

- [ ] **Step 3: Build and lint.** Run: `npm run build && npm run lint` — Expected: no errors.

- [ ] **Step 4: Check it in a browser.** With the backend and `npm run dev` running, sign in as the owner, open `/inbox` at desktop width and at 390 px: see the Proof verification card with its numbers; Edit target saves and the card updates; sign in as an admin with no capabilities and see the "No queues for you yet" state; stop the backend and press Refresh to see the Retry card.

- [ ] **Step 5: Commit**

```bash
git add src/pages/Inbox.tsx src/App.tsx src/components/Shell.tsx
git commit -m "Admin: Inbox page with each queue's waiting, overdue, target, typical and slowest-10% times, and owner-editable targets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task B3: The Audit log page

**Files:**
- Create: `king-domain-admin/src/pages/Audit.tsx`
- Modify: `king-domain-admin/src/App.tsx`, `king-domain-admin/src/components/Shell.tsx`

**Interfaces:**
- Consumes: `api.audit`, `can`.
- Produces: route `/audit` (owner or shareholder), nav item "Audit log" shown only to them.

- [ ] **Step 1: Write `src/pages/Audit.tsx`**

```tsx
import { useCallback, useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { ScrollText } from 'lucide-react'
import { api, type AuditEvent } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { can } from '@/lib/capabilities'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Skeleton } from '@/components/ui/skeleton'
import { Sentry } from '@/lib/sentry'

function when(iso: string) {
  return new Date(iso).toLocaleString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

export function Audit() {
  const { user } = useAuth()
  const [action, setAction] = useState('')
  const [subjectId, setSubjectId] = useState('')
  const [events, setEvents] = useState<AuditEvent[] | null>(null)
  const [nextBefore, setNextBefore] = useState<string | null>(null)
  const [failed, setFailed] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)

  const load = useCallback(
    (before?: string) => {
      setFailed(false)
      if (before) setLoadingMore(true)
      api
        .audit({ action: action.trim() || undefined, subjectId: subjectId.trim() || undefined, before })
        .then((r) => {
          setEvents((prev) => (before && prev ? [...prev, ...r.events] : r.events))
          setNextBefore(r.nextBefore)
        })
        .catch((err: unknown) => {
          Sentry.captureException(err, { tags: { page: 'audit' } })
          setFailed(true)
        })
        .finally(() => setLoadingMore(false))
    },
    [action, subjectId],
  )

  useEffect(() => load(), [load])

  if (!can(user, 'shareholder')) return <Navigate to="/" replace />

  return (
    <div className="mx-auto w-full max-w-3xl space-y-4 p-4 sm:p-6">
      <header>
        <h1 className="font-display text-2xl font-semibold">Audit log</h1>
        <p className="text-sm text-muted-foreground">Every action the team takes: who, when, what, and why. Nothing here can be changed.</p>
      </header>

      <div className="grid gap-2 sm:grid-cols-2">
        <Input placeholder="Action, e.g. proof.approve" value={action} onChange={(e) => setAction(e.target.value)} />
        <Input placeholder="Subject id" value={subjectId} onChange={(e) => setSubjectId(e.target.value)} />
      </div>

      {failed && (
        <Card className="flex items-center justify-between gap-3 p-4">
          <p className="text-sm">Couldn't load the audit log.</p>
          <Button size="sm" onClick={() => load()}>Retry</Button>
        </Card>
      )}

      {!failed && events === null && [0, 1, 2].map((i) => <Skeleton key={i} className="h-16 w-full rounded-xl" />)}

      {!failed && events?.length === 0 && (
        <Card className="flex flex-col items-center gap-2 p-8 text-center">
          <ScrollText className="size-6 text-muted-foreground" />
          <p className="font-medium">No actions match</p>
          <p className="text-sm text-muted-foreground">Clear the filters to see everything, newest first.</p>
        </Card>
      )}

      {events?.map((e) => (
        <Card key={e.id} className="space-y-1 p-4">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <p className="font-mono text-sm">{e.action}</p>
            <p className="text-xs text-muted-foreground">{when(e.createdAt)}</p>
          </div>
          <p className="text-sm">
            {e.actor.name ?? e.actor.email} <span className="text-muted-foreground">({e.actorRole})</span> · {e.subjectType} {e.subjectId.slice(0, 8)}
          </p>
          {e.note && <p className="text-sm text-muted-foreground">{e.note}</p>}
        </Card>
      ))}

      {nextBefore && (
        <Button variant="secondary" className="w-full" onClick={() => load(nextBefore)} disabled={loadingMore}>
          {loadingMore ? 'Loading…' : 'Load older'}
        </Button>
      )}
    </div>
  )
}
```

- [ ] **Step 2: Route and nav.** In `src/App.tsx`: `import { Audit } from '@/pages/Audit'` and `<Route path="audit" element={<Audit />} />` inside the protected routes. In `src/components/Shell.tsx`, extend `NavItem` with `capability?: AdminCapability` (import the type from `@/lib/api`), add `{ to: '/audit', label: 'Audit log', capability: 'shareholder' }` after Ledger, and where links are filtered by `ownerOnly`, also hide items whose `capability` the user lacks using `can(user, link.capability)` from `@/lib/capabilities`.

- [ ] **Step 3: Build and lint.** Run: `npm run build && npm run lint` — Expected: no errors.

- [ ] **Step 4: Check it in a browser.** As the owner: the proof approvals from A3 and the capability changes appear newest first; filtering by `proof.approve` narrows; "Load older" appears only when there are more than 50. As an admin without shareholder: the nav item is hidden and `/audit` redirects to Overview.

- [ ] **Step 5: Commit**

```bash
git add src/pages/Audit.tsx src/App.tsx src/components/Shell.tsx
git commit -m "Admin: read-only audit log page for owners and shareholders, with filters and paging

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task B4: Roles and on-call on the Team page

**Files:**
- Create: `king-domain-admin/src/components/team/CapabilityEditor.tsx`, `king-domain-admin/src/components/team/OnCallPanel.tsx`
- Modify: `king-domain-admin/src/pages/Team.tsx`

**Interfaces:**
- Consumes: `api.skills`, `api.setCapabilities`, `api.onCall`, `api.addOnCall`, `api.removeOnCall`, `api.testAlert`, `CAPABILITY_LABELS`.
- Produces: `<CapabilityEditor admin={AdminUser} skills={Skill[]} onSaved={(a: AdminUser) => void} />`; `<OnCallPanel admins={AdminUser[]} />`.

- [ ] **Step 1: Write `src/components/team/CapabilityEditor.tsx`**

```tsx
import { useState } from 'react'
import { toast } from 'sonner'
import { api, ApiError, type AdminCapability, type AdminUser, type Skill } from '@/lib/api'
import { CAPABILITY_LABELS } from '@/lib/capabilities'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

const ALL = Object.keys(CAPABILITY_LABELS) as AdminCapability[]

export function CapabilityEditor({ admin, skills, onSaved }: { admin: AdminUser; skills: Skill[]; onSaved: (a: AdminUser) => void }) {
  const [caps, setCaps] = useState<AdminCapability[]>(admin.capabilities)
  const [reviewSkills, setReviewSkills] = useState<string[]>(admin.reviewerSkills)
  const [saving, setSaving] = useState(false)
  const changed = caps.join() !== admin.capabilities.join() || reviewSkills.join() !== admin.reviewerSkills.join()

  const toggle = <T,>(list: T[], v: T) => (list.includes(v) ? list.filter((x) => x !== v) : [...list, v])

  async function save() {
    setSaving(true)
    try {
      const r = await api.setCapabilities(admin.id, { capabilities: caps, reviewerSkills: caps.includes('reviewer') ? reviewSkills : [] })
      toast.success('Roles saved')
      onSaved(r.admin)
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : 'Could not save the roles.')
    } finally {
      setSaving(false)
    }
  }

  if (admin.role === 'owner') return <p className="text-sm text-muted-foreground">Owner: can do everything.</p>

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2">
        {ALL.map((c) => (
          <button
            key={c}
            type="button"
            title={CAPABILITY_LABELS[c].does}
            aria-pressed={caps.includes(c)}
            onClick={() => setCaps(toggle(caps, c))}
            className={cn('rounded-full border px-3 py-1 text-sm', caps.includes(c) ? 'border-primary bg-primary/10' : 'text-muted-foreground')}
          >
            {CAPABILITY_LABELS[c].label}
          </button>
        ))}
      </div>
      {caps.includes('reviewer') && (
        <div className="space-y-1">
          <p className="text-sm text-muted-foreground">Reviews proof in:</p>
          <div className="flex flex-wrap gap-2">
            {skills.map((s) => (
              <button
                key={s.key}
                type="button"
                aria-pressed={reviewSkills.includes(s.key)}
                onClick={() => setReviewSkills(toggle(reviewSkills, s.key))}
                className={cn('rounded-full border px-3 py-1 text-sm', reviewSkills.includes(s.key) ? 'border-primary bg-primary/10' : 'text-muted-foreground')}
              >
                {s.label}
              </button>
            ))}
          </div>
          {reviewSkills.length === 0 && <p className="text-xs text-destructive">Choose at least one skill, or this reviewer sees no proof.</p>}
        </div>
      )}
      <Button size="sm" onClick={save} disabled={!changed || saving}>{saving ? 'Saving…' : 'Save roles'}</Button>
    </div>
  )
}
```

- [ ] **Step 2: Write `src/components/team/OnCallPanel.tsx`**

```tsx
import { useCallback, useEffect, useState } from 'react'
import { toast } from 'sonner'
import { BellRing, Trash2 } from 'lucide-react'
import { api, ApiError, type AdminUser, type OnCallShift } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const fmt = (iso: string) => new Date(iso).toLocaleString(undefined, { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })

export function OnCallPanel({ admins }: { admins: AdminUser[] }) {
  const active = admins.filter((a) => a.status === 'active')
  const [shifts, setShifts] = useState<OnCallShift[] | null>(null)
  const [adminId, setAdminId] = useState(active[0]?.id ?? '')
  const [startsAt, setStartsAt] = useState('')
  const [endsAt, setEndsAt] = useState('')
  const [busy, setBusy] = useState(false)

  const load = useCallback(() => {
    api.onCall().then((r) => setShifts(r.shifts)).catch(() => setShifts([]))
  }, [])
  useEffect(load, [load])

  async function add() {
    setBusy(true)
    try {
      await api.addOnCall({ adminId, startsAt: new Date(startsAt).toISOString(), endsAt: new Date(endsAt).toISOString() })
      toast.success('Shift added')
      setStartsAt('')
      setEndsAt('')
      load()
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : 'Could not add the shift.')
    } finally {
      setBusy(false)
    }
  }

  async function remove(id: string) {
    try {
      await api.removeOnCall(id)
      load()
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : 'Could not remove the shift.')
    }
  }

  async function testAlert() {
    try {
      const r = await api.testAlert()
      toast.success(r.alert.slackSent ? 'Test alert sent to Slack and email' : 'Slack did not accept it: check OPS_SLACK_WEBHOOK_URL on the server')
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : 'Could not send the test alert.')
    }
  }

  return (
    <Card className="space-y-4 p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-medium">On call</p>
          <p className="text-sm text-muted-foreground">Who gets urgent alerts (chargebacks, safety reports) outside working hours. With nobody on call, the owners get them.</p>
        </div>
        <Button variant="secondary" size="sm" onClick={testAlert}><BellRing className="size-4" /> Send a test alert</Button>
      </div>

      {shifts?.length === 0 && <p className="text-sm text-muted-foreground">No shifts coming up. Add this week's rota below.</p>}
      {shifts?.map((s) => (
        <div key={s.id} className="flex items-center justify-between gap-2 text-sm">
          <span>{s.admin.name ?? s.admin.email}: {fmt(s.startsAt)} → {fmt(s.endsAt)}</span>
          <Button variant="ghost" size="icon" onClick={() => remove(s.id)} aria-label="Remove shift"><Trash2 className="size-4" /></Button>
        </div>
      ))}

      <div className="grid gap-2 sm:grid-cols-4">
        <div className="space-y-1">
          <Label htmlFor="oc-admin">Person</Label>
          <select id="oc-admin" className="h-9 w-full rounded-md border bg-background px-2 text-sm" value={adminId} onChange={(e) => setAdminId(e.target.value)}>
            {active.map((a) => <option key={a.id} value={a.id}>{a.name ?? a.email}</option>)}
          </select>
        </div>
        <div className="space-y-1"><Label htmlFor="oc-start">Starts</Label><Input id="oc-start" type="datetime-local" value={startsAt} onChange={(e) => setStartsAt(e.target.value)} /></div>
        <div className="space-y-1"><Label htmlFor="oc-end">Ends</Label><Input id="oc-end" type="datetime-local" value={endsAt} onChange={(e) => setEndsAt(e.target.value)} /></div>
        <div className="flex items-end"><Button className="w-full" onClick={add} disabled={!adminId || !startsAt || !endsAt || busy}>{busy ? 'Adding…' : 'Add shift'}</Button></div>
      </div>
    </Card>
  )
}
```

- [ ] **Step 3: Use them on the Team page.** In `src/pages/Team.tsx`: load skills once (`api.skills().then((r) => setSkills(r.skills))` in the existing effect, with `const [skills, setSkills] = useState<Skill[]>([])`); under each admin row render `<CapabilityEditor admin={admin} skills={skills} onSaved={(a) => setAdmins((list) => list.map((x) => (x.id === a.id ? a : x)))} />` (use the page's existing admins state setter name); below the admin list render `<OnCallPanel admins={admins} />`.

- [ ] **Step 4: Build and lint.** Run: `npm run build && npm run lint` — Expected: no errors.

- [ ] **Step 5: Check it in a browser** (owner): give Balogun's account Reviewer + Video, save, reload, still there; the change shows in the Audit log; add a shift for tonight, it lists; remove it; Send a test alert with the backend's `OPS_SLACK_WEBHOOK_URL` unset shows the "Slack did not accept it" message (the server answers, Slack was not configured), proving the button's failure path.

- [ ] **Step 6: Commit**

```bash
git add src/components/team src/pages/Team.tsx
git commit -m "Admin Team page: roles and reviewer skills per person, the on-call rota, and a test alert button

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Part C — App

Run each test from `king-domain-mobile` with `flutter test <file>`; the full `flutter test` runs once at the end of S0.

### Task C1: The skill model and provider

**Files:**
- Create: `lib/data/models/skill.dart`, `lib/presentation/providers/skills_provider.dart`
- Test: `test/skill_model_test.dart`

**Interfaces:**
- Consumes: `GET /skills` (A1), `ApiClient.instance.get(path)`.
- Produces: `enum ProofFieldKind { files, image, video, text, link }`; `class StartProofField {key, label, kind, min, max; fromJson}`; `class Skill {key, label, categoryKey, open, startProof; fromJson}`; `class SkillCategory {key, label; fromJson}`; `class SkillCatalog {categories, skills; fromJson; Skill? byKey(String); List<Skill> openIn(String categoryKey); String categoryLabel(String key)}`; `final skillCatalogProvider = FutureProvider<SkillCatalog>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/skill_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/data/models/skill.dart';

const _json = {
  'categories': [
    {'key': 'design', 'label': 'Design & creative'},
    {'key': 'video', 'label': 'Video & media'},
  ],
  'skills': [
    {
      'key': 'graphic-design', 'label': 'Graphic design', 'category': 'design', 'open': true,
      'startProof': [
        {'key': 'concepts', 'label': 'Two or three concept directions', 'kind': 'files', 'min': 2, 'max': 3},
      ],
    },
    {
      'key': 'short-form-video', 'label': 'Short-form video editing', 'category': 'video', 'open': true,
      'startProof': [
        {'key': 'roughCut', 'label': 'Rough cut of the first piece', 'kind': 'video', 'min': 1, 'max': 1},
      ],
    },
  ],
};

void main() {
  test('parses categories, skills and start-proof fields', () {
    final c = SkillCatalog.fromJson(_json);
    expect(c.categories.map((x) => x.label), ['Design & creative', 'Video & media']);
    final video = c.byKey('short-form-video')!;
    expect(video.startProof.single.kind, ProofFieldKind.video);
    expect(video.startProof.single.min, 1);
    expect(c.categoryLabel('video'), 'Video & media');
  });

  test('openIn lists only open skills in a category; unknown keys give null', () {
    final c = SkillCatalog.fromJson(_json);
    expect(c.openIn('design').map((s) => s.key), ['graphic-design']);
    expect(c.byKey('nope'), isNull);
  });

  test('an unknown proof kind fails loudly instead of guessing', () {
    expect(
      () => StartProofField.fromJson({'key': 'k', 'label': 'l', 'kind': 'hologram', 'min': 1, 'max': 1}),
      throwsA(isA<FormatException>()),
    );
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `flutter test test/skill_model_test.dart` — Expected: FAIL, `skill.dart` not found.

- [ ] **Step 3: Write `lib/data/models/skill.dart`**

```dart
/// The skills King Domain verifies and hires for, as served by GET /skills
/// (backend src/skills.js; PRD §4.2 and decision D25).
enum ProofFieldKind { files, image, video, text, link }

class StartProofField {
  final String key;
  final String label;
  final ProofFieldKind kind;
  final int min;
  final int max;

  const StartProofField({required this.key, required this.label, required this.kind, required this.min, required this.max});

  factory StartProofField.fromJson(Map<String, dynamic> j) {
    final kind = ProofFieldKind.values.where((k) => k.name == j['kind']).firstOrNull;
    if (kind == null) throw FormatException('Unknown start-proof kind "${j['kind']}"');
    return StartProofField(key: j['key'] as String, label: j['label'] as String, kind: kind, min: j['min'] as int, max: j['max'] as int);
  }
}

class Skill {
  final String key;
  final String label;
  final String categoryKey;
  final bool open;
  final List<StartProofField> startProof;

  const Skill({required this.key, required this.label, required this.categoryKey, required this.open, required this.startProof});

  factory Skill.fromJson(Map<String, dynamic> j) => Skill(
    key: j['key'] as String,
    label: j['label'] as String,
    categoryKey: j['category'] as String,
    open: j['open'] as bool,
    startProof: [for (final f in j['startProof'] as List) StartProofField.fromJson(f as Map<String, dynamic>)],
  );
}

class SkillCategory {
  final String key;
  final String label;
  const SkillCategory({required this.key, required this.label});
  factory SkillCategory.fromJson(Map<String, dynamic> j) => SkillCategory(key: j['key'] as String, label: j['label'] as String);
}

class SkillCatalog {
  final List<SkillCategory> categories;
  final List<Skill> skills;

  const SkillCatalog({required this.categories, required this.skills});

  factory SkillCatalog.fromJson(Map<String, dynamic> j) => SkillCatalog(
    categories: [for (final c in j['categories'] as List) SkillCategory.fromJson(c as Map<String, dynamic>)],
    skills: [for (final s in j['skills'] as List) Skill.fromJson(s as Map<String, dynamic>)],
  );

  Skill? byKey(String key) => skills.where((s) => s.key == key).firstOrNull;

  List<Skill> openIn(String categoryKey) => [for (final s in skills) if (s.open && s.categoryKey == categoryKey) s];

  String categoryLabel(String key) => categories.firstWhere((c) => c.key == key, orElse: () => SkillCategory(key: key, label: key)).label;
}
```

- [ ] **Step 4: Write `lib/presentation/providers/skills_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../data/models/skill.dart';

/// The skill catalogue from the server. Screens that need it show their own
/// loading and retry states; there is no bundled copy, so the app never shows
/// a skill list the server doesn't have.
final skillCatalogProvider = FutureProvider<SkillCatalog>((ref) async {
  final json = await ApiClient.instance.get('/skills') as Map<String, dynamic>;
  return SkillCatalog.fromJson(json);
});
```

- [ ] **Step 5: Run the test to see it pass.** Run: `flutter test test/skill_model_test.dart` — Expected: PASS, 3 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/skill.dart lib/presentation/providers/skills_provider.dart test/skill_model_test.dart
git commit -m "App: skill catalogue model and provider from GET /skills

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task C2: The sample-data marker and convention

**Files:**
- Create: `lib/presentation/widgets/common/sample_data_notice.dart`, `docs/core/sample-data.md`
- Modify: `docs/README.md` (index the new doc)
- Test: `test/sample_data_notice_test.dart`

**Interfaces:**
- Consumes: `nonProductionApiHost` (from `lib/data/api_client.dart`).
- Produces: `enum DataSource { live, sample }`; `bool get sampleDataAllowed` (true only when `nonProductionApiHost != null`); `class SampleDataNotice extends StatelessWidget { const SampleDataNotice({required DataSource source, required String what}) }` — nothing for `live`, an amber strip for `sample`.

- [ ] **Step 1: Write the failing test**

```dart
// test/sample_data_notice_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/common/sample_data_notice.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.theme, home: Scaffold(body: child));

void main() {
  testWidgets('shows nothing for live data', (tester) async {
    await tester.pumpWidget(_host(const SampleDataNotice(source: DataSource.live, what: 'Disputes')));
    expect(find.textContaining('Sample data'), findsNothing);
  });

  testWidgets('says plainly that the data is a sample and what is not connected', (tester) async {
    await tester.pumpWidget(_host(const SampleDataNotice(source: DataSource.sample, what: 'Disputes')));
    expect(find.text('Sample data'), findsOneWidget);
    expect(find.textContaining("Disputes isn't connected to the server yet"), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `flutter test test/sample_data_notice_test.dart` — Expected: FAIL, file not found.

- [ ] **Step 3: Write `lib/presentation/widgets/common/sample_data_notice.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';

/// Where a screen's data comes from. A store backed by the real API is live;
/// a store standing in for an endpoint that isn't built yet is sample
/// (docs/core/sample-data.md).
enum DataSource { live, sample }

/// Sample stores may only be used against a non-production server. Release
/// builds against production never see sample data.
bool get sampleDataAllowed => nonProductionApiHost != null;

/// The strip every screen shows while its data is a sample, so nobody mistakes
/// it for real behaviour.
class SampleDataNotice extends StatelessWidget {
  final DataSource source;
  final String what;

  const SampleDataNotice({super.key, required this.source, required this.what});

  @override
  Widget build(BuildContext context) {
    if (source == DataSource.live) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: 'Sample data. $what isn\'t connected to the server yet.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.warnSoft, borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, size: 18, color: AppColors.warn),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sample data', style: AppTextStyles.title.copyWith(color: AppColors.warn, fontSize: 13)),
                  Text("$what isn't connected to the server yet. Nothing here is real.", style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write `docs/core/sample-data.md`**

```markdown
# Sample data while the backend catches up

Status: convention, adopted in S0 (2026-10-31). Applies to every slice in `docs/core/prd.md` §8.

Some screens are built before their endpoints exist. They still behave for real against a store; only the
store's source differs.

1. Each feature reads and writes through an interface: `abstract interface class DisputeStore { DataSource get source; … }`.
2. Two implementations: `ApiDisputeStore` (the real API, `source == DataSource.live`) and `SampleDisputeStore`
   (`source == DataSource.sample`, rules applied in memory exactly as the backend will apply them).
3. The provider returns the API store. A sample store is used only when its endpoint does not exist yet **and**
   `sampleDataAllowed` is true (a non-production server); otherwise the screen shows its normal error state.
4. Every screen whose store is a sample shows `SampleDataNotice(source: store.source, what: '<feature>')` at the top.
5. When the endpoint ships, the provider switches to the API store and the sample store is deleted in the same
   change. No sample store survives its endpoint.
6. A sample store is never a fake shortcut for behaviour (CLAUDE.md hard rule 4): it implements the same rules and
   states, so the screen is finished when the API arrives.
```

Then add to `docs/README.md` under Current docs: `- [Sample data while the backend catches up](./core/sample-data.md) — the store-interface convention and the "Sample data" strip; read before building a screen whose endpoint isn't built.`

- [ ] **Step 5: Run the test to see it pass.** Run: `flutter test test/sample_data_notice_test.dart` — Expected: PASS, 2 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/common/sample_data_notice.dart docs/core/sample-data.md docs/README.md test/sample_data_notice_test.dart
git commit -m "App: the Sample data strip and the store-interface convention for screens built ahead of their endpoints

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task C3: Event cards for the contract room

**Files:**
- Create: `lib/presentation/widgets/kit/event_card.dart`
- Test: `test/event_card_test.dart`

**Interfaces:**
- Consumes: `KdTone`, `toneInk`, `toneSurface` (`kd_card.dart`), `KdButton`, `AppTextStyles`, `AppDimensions`, `formatAgo` (`lib/core/formatting/` — use the existing relative-time helper used by `job_detail_screen.dart`).
- Produces: `class EventCardAction {label, onPressed, primary}`; `class EventCard extends StatelessWidget { EventCard({required IconData icon, required String title, required DateTime at, String? body, KdTone tone = KdTone.plain, String? amount, List<EventCardAction> actions = const []}) }`. `amount` is shown in gold (money only).

- [ ] **Step 1: Write the failing test**

```dart
// test/event_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/app_colors.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/event_card.dart';
import 'package:king_domain/presentation/widgets/kit/kd_button.dart';
import 'package:king_domain/presentation/widgets/kit/kd_card.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.theme, home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

void main() {
  testWidgets('shows the event, its time, the amount in gold and acts from the card', (tester) async {
    var accepted = 0;
    await tester.pumpWidget(_host(EventCard(
      icon: Icons.flag_outlined,
      title: 'Start proof submitted',
      body: 'Rough cut and timeline screenshot.',
      at: DateTime.now().subtract(const Duration(minutes: 5)),
      tone: KdTone.warn,
      amount: '₦10,000',
      actions: [EventCardAction(label: 'Accept', primary: true, onPressed: () async => accepted++)],
    )));
    expect(find.text('Start proof submitted'), findsOneWidget);
    expect(find.text('Rough cut and timeline screenshot.'), findsOneWidget);
    final amount = tester.widget<Text>(find.text('₦10,000'));
    expect(amount.style?.color, AppColors.money);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(accepted, 1);
  });

  testWidgets('a card with no actions shows no buttons', (tester) async {
    await tester.pumpWidget(_host(EventCard(icon: Icons.check, title: 'Approved', at: DateTime.now(), tone: KdTone.ok)));
    expect(find.byType(KdButton), findsNothing);
    expect(find.text('Approved'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `flutter test test/event_card_test.dart` — Expected: FAIL, file not found.

- [ ] **Step 3: Write `lib/presentation/widgets/kit/event_card.dart`**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import 'kd_button.dart';
import 'kd_card.dart';

class EventCardAction {
  final String label;
  final FutureOr<void> Function() onPressed;
  final bool primary;
  const EventCardAction({required this.label, required this.onPressed, this.primary = false});
}

/// One job event in the contract room's timeline (PRD §4.7): funded, start
/// proof, draft, delivery, change request, extension, approval, payout. The
/// actions that event needs are taken right on the card.
class EventCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final DateTime at;
  final KdTone tone;
  final String? amount;
  final List<EventCardAction> actions;

  const EventCard({super.key, required this.icon, required this.title, required this.at, this.body, this.tone = KdTone.plain, this.amount, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final ink = tone == KdTone.plain ? AppColors.text2 : toneInk(tone);
    return KdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: tone == KdTone.plain ? AppColors.surface2 : toneSurface(tone), shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.title),
                    Text(formatAgo(at), style: AppTextStyles.hint),
                  ],
                ),
              ),
              if (amount != null)
                Text(amount!, style: AppTextStyles.title.copyWith(color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(body!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2, height: 1.5)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: actions[i].primary
                        ? KdButton(label: actions[i].label, height: AppDimensions.buttonHeightSm, onPressed: actions[i].onPressed)
                        : KdButton.secondary(label: actions[i].label, height: AppDimensions.buttonHeightSm, onPressed: actions[i].onPressed),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

`formatAgo(DateTime)` lives in `lib/core/formatting/deadline.dart`; `KdCard` takes `padding`; `KdButton` and `KdButton.secondary` take `height` (all checked 2026-10-31).

- [ ] **Step 4: Run it to see it pass.** Run: `flutter test test/event_card_test.dart` — Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/kit/event_card.dart test/event_card_test.dart
git commit -m "Kit: event cards for the contract room timeline, with actions on the card and money in gold

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task C4: The stepper and the lifecycle for each job type

**Files:**
- Create: `lib/core/constants/job_lifecycles.dart`, `lib/presentation/widgets/kit/kd_stepper.dart`
- Test: `test/kd_stepper_test.dart`

**Interfaces:**
- Produces: `enum JobKind { oneDelivery, milestones, monthly, hourly }`; `List<String> lifecycleLabels(JobKind kind)` (the PRD §4.1 steps); `enum KdStepState { done, current, waiting, later }`; `class KdStep {label, subtitle?, state}`; `class KdStepper extends StatelessWidget { KdStepper({required List<KdStep> steps}) }` — vertical, thin rail, done = green check, current = violet, waiting = amber, later = muted; semantic label "Step n of m: label, state".

- [ ] **Step 1: Write the failing test**

```dart
// test/kd_stepper_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/job_lifecycles.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/kd_stepper.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.theme, home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  test('each job type has the steps the PRD gives it', () {
    expect(lifecycleLabels(JobKind.oneDelivery), ['Agreed', 'Funded', 'Start proof', 'Working', 'Delivered', 'Review', 'Approved', 'Paid']);
    expect(lifecycleLabels(JobKind.milestones), ['Funded', 'Working', 'Delivered', 'Review', 'Paid']);
    expect(lifecycleLabels(JobKind.monthly), ['Month funded', 'Working', "Month's deliveries", 'Review', 'Paid']);
    expect(lifecycleLabels(JobKind.hourly), ['Week funded', 'Hours reported', 'Approve or dispute', 'Paid']);
  });

  testWidgets('shows every step and announces position and state', (tester) async {
    final steps = [
      const KdStep(label: 'Funded', state: KdStepState.done),
      const KdStep(label: 'Start proof', subtitle: 'Waiting for the client', state: KdStepState.waiting),
      const KdStep(label: 'Working', state: KdStepState.later),
    ];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(KdStepper(steps: steps)));
    expect(find.text('Funded'), findsOneWidget);
    expect(find.text('Waiting for the client'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3: Start proof, waiting on someone'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'the done step shows a check');
    handle.dispose();
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `flutter test test/kd_stepper_test.dart` — Expected: FAIL, files not found.

- [ ] **Step 3: Write `lib/core/constants/job_lifecycles.dart`**

```dart
/// The four job types (decision D1) and the steps each shows (PRD §4.1).
/// Milestone, monthly and hourly steps repeat per unit; the stepper shows one unit.
enum JobKind { oneDelivery, milestones, monthly, hourly }

List<String> lifecycleLabels(JobKind kind) => switch (kind) {
  JobKind.oneDelivery => const ['Agreed', 'Funded', 'Start proof', 'Working', 'Delivered', 'Review', 'Approved', 'Paid'],
  JobKind.milestones => const ['Funded', 'Working', 'Delivered', 'Review', 'Paid'],
  JobKind.monthly => const ['Month funded', 'Working', "Month's deliveries", 'Review', 'Paid'],
  JobKind.hourly => const ['Week funded', 'Hours reported', 'Approve or dispute', 'Paid'],
};
```

- [ ] **Step 4: Write `lib/presentation/widgets/kit/kd_stepper.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

enum KdStepState { done, current, waiting, later }

class KdStep {
  final String label;
  final String? subtitle;
  final KdStepState state;
  const KdStep({required this.label, required this.state, this.subtitle});
}

/// A vertical stepper on a thin rail, for any job type (PRD §4.1). Green only
/// for done, violet for the step you act on, amber when it waits on someone.
class KdStepper extends StatelessWidget {
  final List<KdStep> steps;
  const KdStepper({super.key, required this.steps});

  static String _spoken(KdStepState s) => switch (s) {
    KdStepState.done => 'done',
    KdStepState.current => 'your turn',
    KdStepState.waiting => 'waiting on someone',
    KdStepState.later => 'later',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Semantics(
            label: 'Step ${i + 1} of ${steps.length}: ${steps[i].label}, ${_spoken(steps[i].state)}',
            excludeSemantics: true,
            child: _Row(step: steps[i], first: i == 0, last: i == steps.length - 1, railDone: steps[i].state == KdStepState.done),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final KdStep step;
  final bool first;
  final bool last;
  final bool railDone;
  const _Row({required this.step, required this.first, required this.last, required this.railDone});

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (step.state) {
      KdStepState.done => (AppColors.okSoft, AppColors.ok),
      KdStepState.current => (AppColors.primarySoft, AppColors.primaryText),
      KdStepState.waiting => (AppColors.warnSoft, AppColors.warn),
      KdStepState.later => (AppColors.surface2, AppColors.text3),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(width: 2, height: 8, color: first ? Colors.transparent : AppColors.surface3),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                  child: step.state == KdStepState.done
                      ? Icon(Icons.check_rounded, size: 16, color: ink)
                      : Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: ink, shape: BoxShape.circle))),
                ),
                Expanded(child: Container(width: 2, color: last ? Colors.transparent : (railDone ? AppColors.ok : AppColors.surface3))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label, style: AppTextStyles.title.copyWith(color: step.state == KdStepState.later ? AppColors.text3 : AppColors.text)),
                  if (step.subtitle != null) Text(step.subtitle!, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run it to see it pass.** Run: `flutter test test/kd_stepper_test.dart` — Expected: PASS, 2 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/job_lifecycles.dart lib/presentation/widgets/kit/kd_stepper.dart test/kd_stepper_test.dart
git commit -m "Kit: a stepper for any job type and the lifecycle steps for one delivery, milestones, monthly and hourly work

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task C5: The evidence viewer

**Files:**
- Create: `lib/presentation/widgets/kit/evidence_viewer.dart`
- Test: `test/evidence_viewer_test.dart`

**Interfaces:**
- Consumes: `WorkImage` (`kd_image.dart`), `url_launcher`'s `launchUrl`.
- Produces: `enum EvidenceKind { image, video, file, link, text }`; `class EvidenceItem {kind, label, url?, text?, sizeBytes?, thumbnailUrl?}`; `String formatBytes(int bytes)`; `class EvidenceViewer extends StatelessWidget { EvidenceViewer({required List<EvidenceItem> items, Future<void> Function(Uri)? open}) }` — images show inline; videos and files never load until tapped and show their size; links open outside the app; text shows inline. An empty list shows "Nothing attached".

- [ ] **Step 1: Write the failing test**

```dart
// test/evidence_viewer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/evidence_viewer.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.theme, home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  test('formats sizes the way people read them', () {
    expect(formatBytes(900), '900 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(48 * 1024 * 1024), '48 MB');
    expect(formatBytes((1.5 * 1024 * 1024 * 1024).round()), '1.5 GB');
  });

  testWidgets('a video shows its size and opens only when tapped', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_host(EvidenceViewer(
      open: (u) async => opened.add(u),
      items: const [EvidenceItem(kind: EvidenceKind.video, label: 'Rough cut', url: 'https://cdn.example/cut.mp4', sizeBytes: 48 * 1024 * 1024)],
    )));
    expect(find.text('Rough cut'), findsOneWidget);
    expect(find.textContaining('48 MB'), findsOneWidget);
    expect(opened, isEmpty, reason: 'nothing loads on its own');
    await tester.tap(find.text('Rough cut'));
    await tester.pump();
    expect(opened.single.toString(), 'https://cdn.example/cut.mp4');
  });

  testWidgets('text evidence shows inline, and an empty list says so', (tester) async {
    await tester.pumpWidget(_host(const EvidenceViewer(items: [EvidenceItem(kind: EvidenceKind.text, label: 'Outline', text: '1. Hook\n2. Story')])));
    expect(find.textContaining('1. Hook'), findsOneWidget);
    await tester.pumpWidget(_host(const EvidenceViewer(items: [])));
    expect(find.text('Nothing attached'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `flutter test test/evidence_viewer_test.dart` — Expected: FAIL, file not found.

- [ ] **Step 3: Write `lib/presentation/widgets/kit/evidence_viewer.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import 'kd_card.dart';
import 'kd_image.dart';
import 'pressable.dart';

enum EvidenceKind { image, video, file, link, text }

class EvidenceItem {
  final EvidenceKind kind;
  final String label;
  final String? url;
  final String? text;
  final int? sizeBytes;
  final String? thumbnailUrl;
  const EvidenceItem({required this.kind, required this.label, this.url, this.text, this.sizeBytes, this.thumbnailUrl});
}

String formatBytes(int bytes) {
  const kb = 1024, mb = kb * 1024, gb = mb * 1024;
  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${(bytes / kb).round()} KB';
  if (bytes < gb) return '${(bytes / mb).round()} MB';
  final g = bytes / gb;
  return '${g == g.roundToDouble() ? g.toStringAsFixed(0) : g.toStringAsFixed(1)} GB';
}

Future<void> _launch(Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);

/// Shows proof, start proofs, drafts and deliveries (PRD §4.2, §4.3, §4.9).
/// Light on data: only images render inline; videos and files show their size
/// and load only when tapped.
class EvidenceViewer extends StatelessWidget {
  final List<EvidenceItem> items;
  final Future<void> Function(Uri)? open;
  const EvidenceViewer({super.key, required this.items, this.open});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return KdCard(child: Row(children: [
        const Icon(Icons.attach_file_rounded, color: AppColors.text3),
        const SizedBox(width: 10),
        Text('Nothing attached', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2)),
      ]));
    }
    final go = open ?? _launch;
    return Column(
      children: [
        for (final item in items)
          Padding(padding: const EdgeInsets.only(bottom: AppDimensions.sm), child: _Tile(item: item, open: go)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final EvidenceItem item;
  final Future<void> Function(Uri) open;
  const _Tile({required this.item, required this.open});

  IconData get _icon => switch (item.kind) {
    EvidenceKind.image => Icons.image_outlined,
    EvidenceKind.video => Icons.play_circle_outline_rounded,
    EvidenceKind.file => Icons.description_outlined,
    EvidenceKind.link => Icons.link_rounded,
    EvidenceKind.text => Icons.notes_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (item.kind == EvidenceKind.text) {
      return KdCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.label, style: AppTextStyles.title),
        const SizedBox(height: 6),
        Text(item.text ?? '', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2, height: 1.5)),
      ]));
    }
    final url = item.url;
    final meta = [
      if (item.kind == EvidenceKind.video) 'Video',
      if (item.kind == EvidenceKind.file) 'File',
      if (item.kind == EvidenceKind.link) Uri.tryParse(url ?? '')?.host ?? 'Link',
      if (item.sizeBytes != null) formatBytes(item.sizeBytes!),
      if (item.kind == EvidenceKind.video || item.kind == EvidenceKind.file) 'tap to open',
    ].join(' · ');
    return Pressable(
      onTap: url == null ? null : () => open(Uri.parse(url)),
      semanticLabel: item.label,
      child: KdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.kind == EvidenceKind.image && url != null) ...[
              ClipRRect(borderRadius: BorderRadius.circular(AppDimensions.radiusSm), child: AspectRatio(aspectRatio: 4 / 3, child: WorkImage(url: url))),
              const SizedBox(height: 10),
            ],
            Row(children: [
              Icon(_icon, size: 20, color: AppColors.primaryText),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.label, style: AppTextStyles.title),
                if (meta.isNotEmpty) Text(meta, style: AppTextStyles.hint),
              ])),
              if (url != null && item.kind != EvidenceKind.image) const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.text3),
            ]),
          ],
        ),
      ),
    );
  }
}
```

`Pressable` takes `child`, `onTap`, `scale`, `haptic`, `semanticLabel` (checked 2026-10-31).

- [ ] **Step 4: Run it to see it pass.** Run: `flutter test test/evidence_viewer_test.dart` — Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/kit/evidence_viewer.dart test/evidence_viewer_test.dart
git commit -m "Kit: evidence viewer that shows images inline and never loads videos or files until tapped

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task C6: The reason sheet

**Files:**
- Create: `lib/presentation/widgets/kit/reason_sheet.dart`
- Test: `test/reason_sheet_test.dart`

**Interfaces:**
- Consumes: `showKdSheet`, `KdSheetBody`, `ReasonField` (`kd_fields.dart`), `KdButton`, `KdChoiceChip` if present (else simple selectable rows).
- Produces: `class ReasonCode {code, label, needsNote}`; `class ReasonChoice {code, note}`; `Future<ReasonChoice?> showReasonSheet(BuildContext, {required String title, String? lead, required List<ReasonCode> codes, required String confirmLabel, int noteMin = 10, int noteMax = 500})` — a reason must be picked; a note is required when the code needs one; returns null if dismissed.

- [ ] **Step 1: Write the failing test**

```dart
// test/reason_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/reason_sheet.dart';

const _codes = [
  ReasonCode(code: 'not_brief', label: "Not what the brief said"),
  ReasonCode(code: 'other', label: 'Something else', needsNote: true),
];

void main() {
  testWidgets('confirm stays disabled until a reason is picked, and a note is required when the reason needs one', (tester) async {
    ReasonChoice? result;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () async => result = await showReasonSheet(context, title: 'Why?', codes: _codes, confirmLabel: 'Send'),
      child: const Text('open'),
    )))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'no reason picked yet');

    await tester.tap(find.text('Something else'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'this reason needs a note');

    await tester.enterText(find.byType(TextField), 'The colours are off-brand.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(result?.code, 'other');
    expect(result?.note, 'The colours are off-brand.');
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `flutter test test/reason_sheet_test.dart` — Expected: FAIL, file not found.

- [ ] **Step 3: Write `lib/presentation/widgets/kit/reason_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import 'kd_button.dart';
import 'kd_fields.dart';
import 'kd_sheet.dart';
import 'pressable.dart';

class ReasonCode {
  final String code;
  final String label;
  final bool needsNote;
  const ReasonCode({required this.code, required this.label, this.needsNote = false});
}

class ReasonChoice {
  final String code;
  final String note;
  const ReasonChoice({required this.code, required this.note});
}

/// Picks a structured reason (and a note when needed) for any action that
/// must say why: declining, objecting to a start proof, "something's wrong",
/// reporting. Free text alone is never enough (admin tools doc §3).
Future<ReasonChoice?> showReasonSheet(
  BuildContext context, {
  required String title,
  String? lead,
  required List<ReasonCode> codes,
  required String confirmLabel,
  int noteMin = 10,
  int noteMax = 500,
}) {
  return showKdSheet<ReasonChoice>(
    context,
    builder: (sheet) => _ReasonBody(title: title, lead: lead, codes: codes, confirmLabel: confirmLabel, noteMin: noteMin, noteMax: noteMax),
  );
}

class _ReasonBody extends StatefulWidget {
  final String title;
  final String? lead;
  final List<ReasonCode> codes;
  final String confirmLabel;
  final int noteMin;
  final int noteMax;
  const _ReasonBody({required this.title, required this.lead, required this.codes, required this.confirmLabel, required this.noteMin, required this.noteMax});

  @override
  State<_ReasonBody> createState() => _ReasonBodyState();
}

class _ReasonBodyState extends State<_ReasonBody> {
  final _note = TextEditingController();
  ReasonCode? _picked;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _ready {
    final picked = _picked;
    if (picked == null) return false;
    if (!picked.needsNote) return true;
    return ReasonField.isValid(_note.text, min: widget.noteMin, max: widget.noteMax);
  }

  @override
  Widget build(BuildContext context) {
    return KdSheetBody(
      title: widget.title,
      lead: widget.lead,
      children: [
        const SizedBox(height: 12),
        for (final c in widget.codes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: Pressable(
              onTap: () => setState(() => _picked = c),
              semanticLabel: c.label,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _picked == c ? AppColors.primarySoft : AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(children: [
                  Icon(_picked == c ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 20, color: _picked == c ? AppColors.primaryText : AppColors.text3),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.label, style: AppTextStyles.bodyMedium)),
                ]),
              ),
            ),
          ),
        if (_picked?.needsNote ?? false) ...[
          const SizedBox(height: 4),
          ReasonField(controller: _note, label: 'Tell them more', min: widget.noteMin, max: widget.noteMax),
        ],
        const SizedBox(height: 12),
        KdButton(
          label: widget.confirmLabel,
          onPressed: _ready ? () => Navigator.of(context).pop(ReasonChoice(code: _picked!.code, note: _note.text.trim())) : null,
        ),
      ],
    );
  }
}
```

`ReasonField` takes `controller`, `label`, `hint`, `min` (default 10), `max` (default 1000), `onValidChanged`, and has `static bool isValid(text, {min, max})` (checked 2026-10-31).

- [ ] **Step 4: Run it to see it pass.** Run: `flutter test test/reason_sheet_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/kit/reason_sheet.dart test/reason_sheet_test.dart
git commit -m "Kit: reason sheet that requires a structured reason, and a note when the reason needs one

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task C7: The consent screen

**Files:**
- Create: `lib/presentation/widgets/kit/consent_screen.dart`
- Test: `test/consent_screen_test.dart`

**Interfaces:**
- Produces: `class ConsentDetails {title, purpose, collected: List<String>, whoSees, keptFor, rights, agreeLabel}`; `class ConsentScreen extends StatefulWidget { ConsentScreen({required ConsentDetails details, required Future<void> Function() onAgree, VoidCallback? onDecline}) }` — the checkbox starts unticked (NDPA s.26: consent is an active choice, never pre-selected); Continue is disabled until it is ticked; "Not now" goes back.

- [ ] **Step 1: Write the failing test**

```dart
// test/consent_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/consent_screen.dart';

const _details = ConsentDetails(
  title: 'Check your identity',
  purpose: 'To confirm you are who you say you are before you can be paid.',
  collected: ['Your NIN', 'A live selfie'],
  whoSees: 'Our identity provider and the King Domain checker. Never other users.',
  keptFor: 'The result for as long as you have an account; the selfie is not kept.',
  rights: 'You can ask what we hold, correct it, or delete your account at any time.',
  agreeLabel: 'I agree to this check',
);

void main() {
  testWidgets('starts unticked, says what is collected and why, and only continues once ticked', (tester) async {
    var agreed = 0;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: ConsentScreen(details: _details, onAgree: () async => agreed++)));
    expect(find.text('Your NIN'), findsOneWidget);
    expect(find.textContaining('Never other users'), findsOneWidget);
    final box = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(box.value, isFalse, reason: 'consent is never pre-ticked');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(agreed, 0);

    await tester.tap(find.text('I agree to this check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(agreed, 1);
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `flutter test test/consent_screen_test.dart` — Expected: FAIL, file not found.

- [ ] **Step 3: Write `lib/presentation/widgets/kit/consent_screen.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import 'kd_button.dart';
import 'kd_card.dart';

class ConsentDetails {
  final String title;
  final String purpose;
  final List<String> collected;
  final String whoSees;
  final String keptFor;
  final String rights;
  final String agreeLabel;
  const ConsentDetails({required this.title, required this.purpose, required this.collected, required this.whoSees, required this.keptFor, required this.rights, required this.agreeLabel});
}

/// Shown before collecting anything sensitive: identity, selfies, documents,
/// addresses, call notes (NDPA s.26–27; PRD §4.4). It says who, why, what,
/// who sees it, how long it is kept, and the person's rights, and consent is
/// an active tick, never pre-selected.
class ConsentScreen extends StatefulWidget {
  final ConsentDetails details;
  final Future<void> Function() onAgree;
  final VoidCallback? onDecline;
  const ConsentScreen({super.key, required this.details, required this.onAgree, this.onDecline});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _ticked = false;

  Widget _section(String heading, Widget body) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(heading.toUpperCase(), style: AppTextStyles.label.copyWith(color: AppColors.text3)),
      const SizedBox(height: 4),
      body,
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    final body = AppTextStyles.bodyMedium.copyWith(color: AppColors.text2, height: 1.5);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 16, AppDimensions.gutter, 16),
                children: [
                  Text(d.title, style: AppTextStyles.h2),
                  const SizedBox(height: 8),
                  Text(d.purpose, style: body),
                  const SizedBox(height: 18),
                  KdCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _section('What we collect', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (final c in d.collected) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(c, style: body)),
                      ])),
                      _section('Who sees it', Text(d.whoSees, style: body)),
                      _section('How long we keep it', Text(d.keptFor, style: body)),
                      _section('Your rights', Text(d.rights, style: body)),
                    ]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 8, AppDimensions.gutter, 16),
              child: Column(children: [
                InkWell(
                  onTap: () => setState(() => _ticked = !_ticked),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Row(children: [
                    Checkbox(value: _ticked, onChanged: (v) => setState(() => _ticked = v ?? false)),
                    Expanded(child: Text(d.agreeLabel, style: AppTextStyles.bodyMedium)),
                  ]),
                ),
                const SizedBox(height: 8),
                KdButton(label: 'Continue', onPressed: _ticked ? widget.onAgree : null),
                const SizedBox(height: 8),
                KdButton.secondary(label: 'Not now', onPressed: widget.onDecline ?? () => Navigator.of(context).maybePop()),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to see it pass.** Run: `flutter test test/consent_screen_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/kit/consent_screen.dart test/consent_screen_test.dart
git commit -m "Kit: consent screen that says what, why, who sees it and for how long, with consent never pre-ticked

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task C8: The protection summary

**Files:**
- Create: `lib/presentation/widgets/kit/protection_summary.dart`
- Test: `test/protection_summary_test.dart`

**Interfaces:**
- Consumes: `formatNaira` (`lib/core/formatting/currency.dart`).
- Produces: `class ProtectionLine {icon, title, body, String? amount}`; `List<ProtectionLine> oneDeliveryProtection({required num price, required num fee, required int changeRounds, required int startSharePercent})` (the lines the PRD §3.2 step 6 lists, in plain words); `class ProtectionSummary extends StatelessWidget { ProtectionSummary({required List<ProtectionLine> lines, required num total}) }` — the total in gold; each line with its icon.

- [ ] **Step 1: Write the failing test**

```dart
// test/protection_summary_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/app_colors.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/protection_summary.dart';

void main() {
  test('the one-delivery lines state every rule the client agrees to before paying', () {
    final lines = oneDeliveryProtection(price: 50000, fee: 5000, changeRounds: 2, startSharePercent: 20);
    final text = lines.map((l) => '${l.title} ${l.body}').join(' ');
    expect(text, contains('held'));
    expect(text, contains('20%'));
    expect(text, contains('2 rounds'));
    expect(text, contains('full refund'));
    expect(text, contains('5 days'));
  });

  testWidgets('shows the total in gold and every line', (tester) async {
    final lines = oneDeliveryProtection(price: 50000, fee: 5000, changeRounds: 2, startSharePercent: 20);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: Scaffold(body: SingleChildScrollView(child: ProtectionSummary(lines: lines, total: 55000)))));
    final total = tester.widget<Text>(find.text('₦55,000'));
    expect(total.style?.color, AppColors.money);
    for (final l in lines) {
      expect(find.text(l.title), findsOneWidget);
    }
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `flutter test test/protection_summary_test.dart` — Expected: FAIL, file not found.

- [ ] **Step 3: Write `lib/presentation/widgets/kit/protection_summary.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import 'kd_card.dart';

class ProtectionLine {
  final IconData icon;
  final String title;
  final String body;
  const ProtectionLine({required this.icon, required this.title, required this.body});
}

/// Every rule a client agrees to before paying for a one-delivery job (PRD §3.2 step 6,
/// decisions D8, D33, D35, and the agreed payment rules).
List<ProtectionLine> oneDeliveryProtection({required num price, required num fee, required int changeRounds, required int startSharePercent}) => [
  ProtectionLine(
    icon: Icons.lock_outline_rounded,
    title: 'Your money is held',
    body: '${formatNaira(price)} stays with ${AppBrand.name} until you approve the work. The ${formatNaira(fee)} fee is ours and is not refunded.',
  ),
  ProtectionLine(
    icon: Icons.flag_outlined,
    title: 'Proof the work has started',
    body: 'Early on, the talent sends a start proof in a fixed format. You have 24 hours to accept it or say it isn\'t a real start. Once accepted, $startSharePercent% is paid to them.',
  ),
  ProtectionLine(
    icon: Icons.replay_rounded,
    title: 'Changes included',
    body: 'Up to $changeRounds rounds of changes after delivery. If you don\'t respond within 3 days of a delivery, it is approved.',
  ),
  const ProtectionLine(
    icon: Icons.event_busy_outlined,
    title: 'If the work doesn\'t come',
    body: 'Three days past the delivery date with nothing delivered and no extension, you can cancel for a full refund of the price. If the talent stops after the start proof, you keep that work and get the rest back; the start share is not refunded.',
  ),
  const ProtectionLine(
    icon: Icons.gavel_outlined,
    title: 'If you disagree',
    body: 'Use "Something\'s wrong" to agree a way out. If that fails, the team decides within 5 days, free, with written reasons. The decision is final.',
  ),
];

/// The protection block on the pay screen: plain rules, the total in gold.
class ProtectionSummary extends StatelessWidget {
  final List<ProtectionLine> lines;
  final num total;
  const ProtectionSummary({super.key, required this.lines, required this.total});

  @override
  Widget build(BuildContext context) {
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('You pay', style: AppTextStyles.title)),
            Text(formatNaira(total), style: AppTextStyles.h3.copyWith(color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
          const SizedBox(height: 14),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(l.icon, size: 20, color: AppColors.primaryText),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title, style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Text(l.body, style: AppTextStyles.bodySmall.copyWith(height: 1.45)),
                ])),
              ]),
            ),
        ],
      ),
    );
  }
}
```

`formatNaira` uses `NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0)`, so `formatNaira(55000)` is `₦55,000` (checked 2026-10-31).

- [ ] **Step 4: Run it to see it pass.** Run: `flutter test test/protection_summary_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/kit/protection_summary.dart test/protection_summary_test.dart
git commit -m "Kit: protection summary that states every rule a client agrees to before paying, total in gold

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Finish S0

### Task Z: Full checks, staging, and the walkthrough

- [ ] **Step 1: Full backend suite**, alone: `npm test` (in `king-domain-backend`). Expected: every suite passes, including the six new files.
- [ ] **Step 2: Full app suite**, alone: `flutter analyze && flutter test` (in `king-domain-mobile`). Expected: no analyzer errors; all tests pass.
- [ ] **Step 3: Admin**: `npm run build && npm run lint` (in `king-domain-admin`). Expected: clean.
- [ ] **Step 4: Victor's setup (manual, before staging):** in Slack, create an incoming webhook for a new `#alerts` channel; in Render (staging service) set `OPS_SLACK_WEBHOOK_URL` to it and `ADMIN_DASHBOARD_URL` to the staging admin URL. Never paste the webhook into chat or git.
- [ ] **Step 5: With Victor's go-ahead**, push the schema to the Neon staging branch (`DIRECT_URL=<staging direct url> npm run db:push`), read it back as in A2 step 3, then push the backend and app branches to `staging` and deploy the admin dashboard's staging build.
- [ ] **Step 6: Grant roles** on the staging Team page: Balogun and Debbie get the capabilities they will use (at least Reviewer with their skills, so proof review keeps working for them now that it needs the capability).
- [ ] **Step 7: Walkthrough with Victor on his phone**: open the staging Inbox (phone width), edit a target, see it in the Audit log, add tonight's on-call shift, press "Send a test alert" and confirm it arrives in `#alerts` on his phone and by email; in the app, nothing visible changes yet (the kit pieces are used from S1), so the app part of the walkthrough is the test run.
- [ ] **Step 8: Update docs**: in `docs/core/testing.md` add the six backend and eight app test files to its ledger; in `docs/core/prd.md` §8 mark S0 as built on staging with the date.
- [ ] **Step 9: Push** (after Victor's go-ahead) and run the `session-update` skill at wrap-up.
