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

- [Backend + Frontend Sprint Plan](./research/BACKEND_SPRINT_PLAN.md) —
  **the current build order.** 6 sprints (schema+auth → profile/proof/review →
  jobs/applications/contracts → frontend wiring → payment → client-side experience),
  each depending only on the sprint(s) before it. Owner decision 2026-09-17: build the
  real product now, not a narrowed wedge — this supersedes the "narrower first slice"
  framing in the reconciliation doc below.
- [Vision vs. Research Reconciliation](./core/vision-vs-research-reconciliation.md) —
  reconciles the original product vision against the 2026-09-12 market validation
  research, section by section. Still the reference for *what* to build; the sprint
  plan above is the reference for *what order*.

- [Payments](./core/payments.md) — how money moves: payout accounts, Paystack funding
  and its three confirmation paths, payout on approval, what's not built. Read before
  touching anything in the contract lifecycle.
- [Testing](./core/testing.md) — what the test suites cover, what passed, and what is
  *not* guaranteed (real payouts, production, CI). Update with every behaviour change.
- [Stage 2 — delivery dates, extensions, change rounds](./features/stage-2-delivery-and-changes.md) —
  approved design for the second stage of the payment rules, with the clarifications Victor
  settled that the ledger text doesn't state.
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
