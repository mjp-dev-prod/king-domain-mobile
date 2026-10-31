# King Domain — Docs

Durable planning docs for the project, compiled here rather than left in chat history or
ephemeral artifacts. This repo is the anchor workspace (see root `CLAUDE.md`), so docs
live here regardless of which sibling repo (backend, web, admin) they end up affecting.

- **`features/`** — plans for features not yet built, or built and worth documenting.
  Each doc states its status at the top (planned / in progress / built) so it's obvious
  at a glance whether it describes reality or intent.
- **`core/`** — how things actually work, or what's actually decided. Authoritative;
  update in the same PR as the code/decision it describes.
- **`research/`** — domain research and validation passes. Dated; treat as a snapshot,
  not a live source of truth.

## Current docs

- [Product requirements (PRD)](./core/prd.md) — **start here: what King Domain is, for whom, every
  journey and screen, the quality bar, the build slices S0–S8, and the register of decisions D1–D46.**
  Written 2026-10-31 from the eleven research topics below. It replaces the sprint plan as the build order.
- [Backend + Frontend Sprint Plan](./research/BACKEND_SPRINT_PLAN.md) — the September build order
  (6 sprints, now largely built); superseded as the order by the PRD's slices. Kept for the history of how
  the backend was sequenced.
- [Vision vs. Research Reconciliation](./core/vision-vs-research-reconciliation.md) —
  reconciles the original product vision against the 2026-09-12 market validation
  research, section by section. Still the reference for *what* to build; the sprint
  plan above is the reference for *what order*.

- [Payments](./core/payments.md) — how money moves: payout accounts, Paystack funding
  and its three confirmation paths, payout on approval, what's not built. Read before
  touching anything in the contract lifecycle.
- [Testing](./core/testing.md) — what the test suites cover, what passed, and what is
  *not* guaranteed (real payouts, production, CI). Update with every behaviour change.
- [Session updates](./core/session-updates.md) — the end-of-session Slack update for shareholders and
  collaborators: hooks, webhook setup, what is posted and what never is.
- [Stage 2 — delivery dates, extensions, change rounds](./features/stage-2-delivery-and-changes.md) —
  approved design for the second stage of the payment rules, with the clarifications Victor
  settled that the ledger text doesn't state.
- [Work gaps: my applications, lifecycle stepper, edit or close a job](./features/work-gaps-applications-stepper-job-edit.md) —
  the design for three gaps found on Victor's phone and in the 2026-10-22 audit, including the race
  guards that make "edit only before the first applicant" safe. Read before touching jobs, the Work
  tab or the contract screens.
- [Work gaps implementation plan](./features/work-gaps-implementation-plan.md) — the task-by-task
  build plan for the design above (backend and app), each task test-first.
- [Profile photos](./features/profile-photos.md) — public photos: where they show, what is stored, the
  rules the server enforces, and why they are public while proofs stay private.
- [Account deletion and privacy](./features/account-deletion-and-privacy.md) — what deleting an account removes
  and keeps, why it is blocked during a contract, the race safety, the policy and web pages, and what Victor
  and a lawyer must confirm before they go live.
- [Push notifications](./features/push-notifications.md) — what gets pushed and to whom, the outbox design,
  token handling, what Victor sets up (Render, Codemagic), and what only a phone can confirm.
- [Imagery surfaces](./features/imagery-surfaces.md) — every place images appear (proof, photos,
  deliveries, job references, illustrations), each linked to the decision it comes from. Read
  before rendering any image.
- [Stage 2 implementation plan](./features/stage-2-implementation-plan.md) — the task-by-task
  build plan for the design above (backend only), with the tests each task must pass.

### Full-vision prototype (design track)

The clickable prototype lives at
[`prototypes/king-domain-full-vision.html`](../prototypes/king-domain-full-vision.html) —
open it in a browser. 10 screens across both the talent and client journeys, built
from the 2026-09-13 Stitch export with corrections applied. This is the design
reference the sprint plan's Prisma schema and endpoints are built against.

- [Stitch brief](./core/stitch-brief-full-vision-prototype.md) — what Stitch designs, and the rules it must not break.
- [Gemini brief](./core/gemini-brief-full-vision-prototype.md) — how Gemini directs Stitch, and what is and isn't its call.
- [Correction 01 — proof of skill](./core/correction-proof-of-skill-screen.md) — killed the mandatory skill-challenge gate.
- [Correction 02 — talent discovery](./core/correction-talent-discovery-screen.md) — killed the composite score and "top candidate" ranking.
- [Correction 03 — invented mechanics](./core/correction-03-invented-mechanics.md) — proof-score leak, "escrow-free" contradiction, mutual-reveal review. **Read the closing section** — the pattern across all three corrections matters more than the individual fixes.
- [Spotify / SheerID student verification](./research/spotify-sheerid-student-verification.md) — how student status is actually verified in the wild, and what transfers to Nigeria.
- [UI/UX audit 2026-10-01](./research/ui-audit-2026-10-01.md) — what the app looks and feels like today,
  the defects found, and what Pendu, Discord, Telegram and the platform guidelines actually do.
  Read before any UI redesign.
- [Job types (2026-10-30)](./research/job-types-2026-10-30.md) — PRD research topic 1: the four shapes
  remote work comes in (one delivery, milestones, monthly, hourly), how Upwork, Fiverr and Contra run each,
  Nigerian payment norms, why no contests, and the decisions it raises. Read before touching jobs or contracts.
- [Proof verification and the start proof (2026-10-30)](./research/proof-verification-2026-10-30.md) — PRD
  research topic 2: the verification protocol (evidence pack, walkthrough video, authenticity check, two
  practising reviewers, reasons shown, Verified then Proven levels) and the start-proof formats per skill.
  Read before touching proof, review or payouts.
- [Identity, student status and age (2026-10-30)](./research/student-identity-verification-2026-10-30.md) —
  PRD research topic 3: NIN + live selfie for both sides, current-session documents for student status,
  renewal each session, the under-18 question under the NDPA, and what waits on CAC.
- [Client trust and student safety (2026-10-30)](./research/client-trust-and-safety-2026-10-30.md) — PRD
  research topic 4: what clients fear, the scams aimed at young Nigerian job seekers, how Upwork, Fiverr and
  Airbnb keep contact on-platform, and the proposed protections both ways.
- [Discovery (2026-10-30)](./research/discovery-2026-10-30.md) — PRD research topic 5: job feed and alerts,
  the 50-applicant / 5-day soft cap, talent browsing without scores, invitations, packages, and the
  "find someone for me" shortlist.
- [Messaging (2026-10-30)](./research/messaging-2026-10-30.md) — PRD research topic 6: one conversation per
  relationship with the job's events as cards, voice notes and calls, built light on data, safety and
  record-keeping rules.
- [Reviews and reputation (2026-10-30)](./research/reviews-reputation-2026-10-30.md) — PRD research topic 7:
  why star averages fail, hidden-until-both reviews, the private rehire question, system-measured facts, and
  the Proven level.
- [Disputes, refunds and chargebacks (2026-10-31)](./research/disputes-2026-10-31.md) — PRD research topic
  8: the eBay-style staircase, free rulings with reasons, per-job-type rules, and Paystack's 16-hour
  chargeback deadline.
- [Money (2026-10-31)](./research/money-2026-10-31.md) — PRD research topic 9: naira and dollar pricing,
  naira-only payouts, worked fee examples, premium under Google Play Billing, and the tax questions for an
  accountant.
- [Training camps (2026-10-31)](./research/training-camps-2026-10-31.md) — PRD research topic 10: cohorts
  in the app, hybrid in person and online, attested final projects, the first-job track, and why Andela's
  junior programme failed.
- [Admin tools (2026-10-31)](./research/admin-tools-2026-10-31.md) — PRD research topic 11: the team inbox,
  queue targets and defaults, roles, second-person approval for money, audit log, alerts and on-call.
- [Market Validation Research](./research/market-validation-2026-09-12.md) — the
  adversarial research pass behind the reconciliation doc above.
- [Shareholder Decisions](./features/shareholder-decisions.md) — async decision-making
  for MJP Productions shareholders inside the admin dashboard (comments, stances,
  notifications).
- [King Domain Admin MCP](./features/king-domain-admin-mcp.md) — an MCP server for
  Claude Code to act directly on the admin backend, following the `pendu-admin-mcp`
  pattern.

The [Marketplace Decision Ledger](https://claude.ai/code/artifact/1c48c145-0b28-4a2e-abbc-556b20eb72f5)
(the 7-milestone product-vision sequence) remains a Claude Artifact, not a doc here —
it's a living, interactively-updated record, and artifacts are the right tool for that.
These docs are for plans that need to sit still and be read, reviewed, and built against.
