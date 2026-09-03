# King Domain — Docs

Durable planning docs for the project, compiled here rather than left in chat history or
ephemeral artifacts. This repo is the anchor workspace (see root `CLAUDE.md`), so docs
live here regardless of which sibling repo (backend, web, admin) they end up affecting.

- **`features/`** — plans for features not yet built, or built and worth documenting.
  Each doc states its status at the top (planned / in progress / built) so it's obvious
  at a glance whether it describes reality or intent.
## Current docs

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
