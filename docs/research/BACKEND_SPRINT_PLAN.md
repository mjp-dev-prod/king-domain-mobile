# King Domain — Backend + Frontend Sprint Plan

> Per CLAUDE.md's working agreement ("product decisions before engineering ones") and
> Hard Rule 5 ("audit before documenting") — this doc audits what actually exists in
> `king-domain-backend` and `king-domain-mobile` before proposing any sprint, the same
> way `pendu-mobile/docs/research/PROFILE_CUSTOMIZATION_RESEARCH.md` audited
> `profile_screen.dart` before proposing anything for Pendu's Gamer Profile.
>
> **Scope decision (owner, 2026-09-17):** build the real product now — frontend and
> backend both, split into sprints that connect to each other in sequence. No time
> estimates. Every place this plan narrows scope from what could theoretically be
> built is named explicitly below, with the reason — never silently absorbed.

---

## 0. What this is actually about

"Build the app" bundles two different kinds of work that need separating, because
they unblock each other in a specific order:

1. **A working backend that doesn't exist yet.** `king-domain-backend` today has
   real, production infrastructure — but zero rows of it are about students, jobs,
   proof, or contracts. Every product screen in the Flutter app is reading from
   in-memory mock data (`mockJobs`, a local `TalentProfileNotifier`).
2. **Wiring the Flutter app to that backend once it exists.** The screens themselves
   are mostly already built (onboarding, profile, proof upload, job feed/detail/apply,
   the contract lifecycle) — this is a rewire, not a rebuild.

A sprint plan that jumps straight to "wire the frontend" produces a frontend that
talks to nothing. A plan that never gets to wiring leaves a backend nobody's app uses.
They have to run in the sequence below.

---

## 1. Audit — what actually exists (read directly)

### 1.1 Backend: real infrastructure, zero product domain

🔵 **Confirmed by reading `prisma/schema.prisma` directly.** Ten models exist:
`WaitlistEntry`, `AdminUser`, `AdminToken`, `AdminSession`, `Decision`,
`DecisionStance`, `DecisionComment`, `PendingNotification`, `McpAuditLog`,
`AppRelease`. Every one of them serves the admin dashboard / shareholder-decisions
side of the project. **There is no `User`, `TalentProfile`, `ProofItem`, `Job`,
`Application`, or `Contract` model.** The product this repo is named for has no
schema yet.

### 1.2 Backend: a real, working auth pattern already exists — reuse it, don't invent one

🟢 **Finding, read directly from `src/admin/routes.js` and `package.json`:** a
complete JWT access+refresh auth system is already built and running for admin
users — `argon2` password hashing, short-lived signed access tokens, a revocable
refresh-session table (`AdminSession`), a `requireAdmin` middleware that verifies the
token and re-checks revocation. This is the same category of system a student/client
auth system needs. **The work here is extending the pattern to a new user type, not
inventing auth from zero** — the same leverage insight as the Pendu doc finding the
palette engine already built and just trapped in one screen.

### 1.3 Backend: file upload and object storage are already dependencies, already wired

🔵 `multer` is already installed (`package.json`) — unused today, but it's the
Express file-upload middleware, and proof-item uploads (a screenshot, a file, a work
sample) need exactly this. `@supabase/supabase-js` is already integrated and already
used for APK storage (`AppRelease.apkUrl`, per the model's own comment). **Proof-item
file storage is the same bucket pattern applied to a new file type, not a new
infrastructure decision.**

### 1.4 Frontend: what's real Dart code today

🔵 Confirmed by reading the files directly, on the `wedge-prototype` branch:

| Screen / flow | File | Status |
|---|---|---|
| Onboarding (welcome/signup/login/verify) | `presentation/screens/onboarding/` | Real UI, no backend call |
| Profile builder | `profile_builder_screen.dart` | Real UI, writes to local `TalentProfileNotifier` |
| Proof upload + human-review gate | `proof_upload_screen.dart`, `talent_profile_provider.dart` | Real UI; review is `simulateReviewApproval()` — a **fake** approve button standing in for a human reviewer |
| Job feed / detail / apply | `job_feed_screen.dart`, `job_detail_screen.dart`, `apply_screen.dart` | Real UI, reads `mockJobs` (a hardcoded `List<Job>` in `job.dart`) |
| Contract lifecycle (funded → in progress → submitted → approved) | `contracts/contract_detail_screen.dart`, `submit_deliverable_screen.dart` | Real UI, state lives in local `JobsNotifier`, not a server |

🟢 **The domain shapes are already designed** in `talent_profile.dart` and `job.dart`
— `TalentProfile`, `ProofItem` (with `category` + `status: pending|verified`), `Job`,
`JobApplicationStatus`, `ContractStatus` (`funded|inProgress|submitted|approved`).
**The Prisma schema in Sprint 1 should mirror these field-for-field where reasonable**
— they're the product's actual settled shape, already proven out in real screens, not
a schema to design from scratch on a whiteboard.

### 1.5 What's genuinely undecided (do not let any sprint quietly settle these)

Per `docs/core/vision-vs-research-reconciliation.md` §4, still open:
- **Payment/escrow provider** — nothing below builds real money movement. `funded`/
  `released` stay status strings server-side until this is picked.
- **Which category launches first** — the mock data spans four categories; this plan
  doesn't narrow that, since the owner has since said the full vision (not the
  narrowed wedge) is what's being built now.
- **Where the client-side experience lives** — same Flutter app in a client mode, a
  separate app, or the existing admin/web stack. Flagged in §6, not decided here.

---

## 2. Sprint sequence

Each sprint only depends on the one(s) listed before it — no sprint here requires
something from a *later* sprint to be meaningfully testable on its own.

### Sprint 1 — Backend: product schema + real auth for students and clients

**Depends on:** nothing (first sprint).

- Prisma models, mirroring the Flutter shapes in §1.4: `User` (role: `talent` |
  `client`), `TalentProfile`, `ProofItem`, `Job`, `Application`, `Contract`.
- Extend the existing JWT auth pattern (§1.2) to `User` — signup, login,
  access+refresh tokens, session revocation. Reuse `argon2` + the token-issuing shape
  already proven in `src/admin/jwt.js` and `routes.js`, don't design a new scheme.
- No business logic beyond auth yet. Done when: a student can sign up, log in, and
  hit an authenticated `/me` endpoint that returns their own record.

### Sprint 2 — Backend: profile, proof upload, and the human-review workflow

**Depends on:** Sprint 1 (needs `User` + auth to know whose profile/proof it is).

- Endpoints: create/update `TalentProfile`, submit a `ProofItem` (file upload via
  the already-installed `multer` → Supabase Storage bucket, per §1.3).
- **A real reviewer-side endpoint** — approve/reject a `ProofItem` — replacing the
  Flutter app's `simulateReviewApproval()` fake. This is the actual trust gate
  (`isVerifiedIn(category)`, already coded in `talent_profile.dart`) becoming real
  instead of a self-serve button. Whether the reviewer surface is a new endpoint the
  existing admin dashboard calls, or a standalone tool, is an open implementation
  question for this sprint — not a design decision, since the *mechanic* (human
  reviews, marks verified/pending) is already settled per the vision doc and the
  market-validation research (`docs/research/market-validation-2026-09-12.md` §10).

### Sprint 3 — Backend: jobs, applications, and the contract state machine

**Depends on:** Sprint 2 (an applicant needs a verified `TalentProfile` to apply).

- Endpoints: post a `Job`, list/filter jobs, apply (`Application`), and — the piece
  the prototype work surfaced as a real gap — **one client selects one applicant**,
  which should mark the `Job` awarded and every other `Application` on it as not
  selected server-side. (This is the exact bug found and fixed in the HTML prototype;
  see `docs/core/correction-*.md` for why it matters — it's not cosmetic, it's the
  actual single-award business rule from the vision doc's client journey.)
- `Contract` lifecycle transitions (`funded → inProgress → submitted → approved`) as
  real server-side state changes, replacing the local `JobsNotifier` state.
- Still no real money. "Funded" here means the state transitions correctly and
  auditable — not that a payment provider was charged. That's Sprint 5.

### Sprint 4 — Frontend: wire the Flutter app to the real backend

**Depends on:** Sprints 1–3 (needs real endpoints to call).

- Replace `TalentProfileNotifier` and `JobsNotifier`'s local state with real API
  calls to Sprint 1–3's endpoints.
- Real auth flow replacing the current onboarding UI's pass-through.
- Real file upload for `ProofItem` instead of storing a local device file path.
- Done when: every screen currently reading mock data reads from the real backend
  instead, with no behavior change from the user's point of view — this sprint is a
  rewire, not a redesign.

### Sprint 5 — Payment/escrow integration

**Depends on:** Sprint 3 (a `Contract` state machine has to exist before it can be
backed by real money) and Sprint 4 conceptually (so the funded/release states are
user-visible once wired), but can start its own research/vendor-selection work in
parallel with Sprint 4's engineering.

- The one decision nothing else can keep faking: who actually holds the client's
  money between `funded` and `approved`. Per the market-validation research §14,
  bank-transfer-native and flat-fee-capped fits this transaction size better than a
  %-based card processor for the Nigerian context — that's a lean, not a decision;
  the actual vendor selection is this sprint's real work.

### Sprint 6 — Client-side experience

**Depends on:** Sprint 3 (jobs/contracts must exist to post/fund/review against) and
benefits from Sprint 5 being underway (funding needs somewhere real to send money).

🔴 **Open, deliberately not decided here:** does the client experience live in the
same Flutter app behind a client-mode toggle, a separate app, or the existing
admin/web stack (`king-domain-admin`, already has real auth and a working dashboard
shell)? The full-vision prototype (`prototypes/king-domain-full-vision.html`) mocked
up client screens (post a need, review applicants, fund, approve delivery) assuming a
mobile client experience, but that was never a settled architecture decision — it was
a design prototype. This needs an explicit call before Sprint 6 can be scoped further.

---

## 3. What was cut from "build everything now," and why

Per Hard Rule 4 ("shrink the scope, never the standard — say what was cut and why"):

- **Algorithmic/matching-first discovery** is not in any sprint above. The vision
  doc leaves the marketplace model partly open (§7), and nothing in Sprints 1–4
  requires picking matching-first vs. job-marketplace vs. hybrid — a plain job
  post/apply/select flow (what's already built in the prototype and mock data) is
  sufficient to make the backend real. Matching automation is additive later, not
  a blocker now.
- **Public reputation/progression scoring** is not in any sprint. Per the
  market-validation research §11, this is the one mechanic with real evidence it can
  backfire (opt-out, gaming) if built as a public ranking — it needs its own decision
  pass, not a schema field added as a side effect of building jobs/contracts.
- **Multiple skill-category launch sequencing** is not addressed — Sprint 1's schema
  supports every category already in the mock data; no sprint here picks a "first"
  category, since that was a wedge-stage sequencing question, not a schema question.

None of these are removed from the vision — they're just not blocking the six sprints
above, and any one of them can become its own sprint once 1–6 are further along.

---

## 4. Open questions

🔴 **Reviewer surface for Sprint 2** — new endpoint on the existing admin dashboard,
or a standalone tool? Not yet decided.

🔴 **Client-side architecture (Sprint 6)** — same app, separate app, or the existing
admin/web stack? The single biggest open question in this whole plan.

🔴 **Escrow/payment vendor (Sprint 5)** — research-backed lean (bank-transfer-native,
flat-fee-capped) exists; no vendor has been evaluated or chosen.

---

## Sources

- This repo, read directly: `king-domain-backend/prisma/schema.prisma` (full schema,
  confirmed zero product models), `src/admin/routes.js` + `package.json` (existing
  JWT auth pattern, multer/Supabase already installed)
- `king-domain-mobile`, read directly: `lib/data/models/talent_profile.dart`,
  `lib/data/models/job.dart` (the real domain shapes to mirror in Prisma),
  `lib/presentation/screens/contracts/` (the real contract-lifecycle UI, on the
  `wedge-prototype` branch)
- `docs/core/vision-vs-research-reconciliation.md` §2–4 — what's settled vs. open
- `docs/research/market-validation-2026-09-12.md` §10, §11, §14 — proof-of-skill
  mechanism, reputation-system risk, payment-vendor lean
- `docs/core/correction-talent-discovery-screen.md` — the single-award bug found in
  the prototype that Sprint 3 explicitly accounts for
