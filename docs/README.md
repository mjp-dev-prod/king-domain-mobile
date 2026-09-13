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

- [Vision vs. Research Reconciliation](./core/vision-vs-research-reconciliation.md) —
  **read this first** if picking up product/build-order questions. Reconciles the
  original product vision against the 2026-09-12 market validation research,
  section by section, so "what are we actually building" doesn't need re-deriving.

### Full-vision prototype (design track)

The clickable prototype lives at
[`prototypes/king-domain-full-vision.html`](../prototypes/king-domain-full-vision.html) —
open it in a browser. 10 screens across both the talent and client journeys, built
from the 2026-09-13 Stitch export with corrections applied. This is a design
reference, **not** the build order — the Flutter app ships a much narrower first
slice (see the reconciliation doc).

- [Stitch brief](./core/stitch-brief-full-vision-prototype.md) — what Stitch designs, and the rules it must not break.
- [Gemini brief](./core/gemini-brief-full-vision-prototype.md) — how Gemini directs Stitch, and what is and isn't its call.
- [Correction 01 — proof of skill](./core/correction-proof-of-skill-screen.md) — killed the mandatory skill-challenge gate.
- [Correction 02 — talent discovery](./core/correction-talent-discovery-screen.md) — killed the composite score and "top candidate" ranking.
- [Correction 03 — invented mechanics](./core/correction-03-invented-mechanics.md) — proof-score leak, "escrow-free" contradiction, mutual-reveal review. **Read the closing section** — the pattern across all three corrections matters more than the individual fixes.
- [Spotify / SheerID student verification](./research/spotify-sheerid-student-verification.md) — how student status is actually verified in the wild, and what transfers to Nigeria.
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
