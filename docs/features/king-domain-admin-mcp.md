# King Domain Admin MCP — Plan

**Status:** Planned, not built.
**Pattern source:** `pendu-admin-mcp` + `pendu---backend/src/mcp-admin/*` (same company,
built by Samuel and Claude together — this is a direct port of a proven pattern, not a
new design).

**Why this exists:** so Claude Code can act directly on the King Domain backend/admin
system from a session — create decisions, check their status, read waitlist/admin data,
manage admins — without Samuel manually pasting curl commands or me publishing/
republishing artifacts by hand every time something changes. This is also the mechanism
that keeps "reduce the artifacts created" real: once decisions live in the real database
via the [shareholder decisions feature](./shareholder-decisions.md), an MCP tool can
read/write them directly instead of a decision living only in an ad-hoc HTML artifact.

## Shape (identical structure to pendu-admin-mcp)

Two pieces:

1. **An isolated auth namespace in `king-domain-backend`** — `/api/mcp-admin/*`, guarded
   by a single static bearer token (`MCP_ADMIN_API_TOKEN`), completely separate from the
   admin session-cookie auth the dashboard uses. A leaked MCP token can only ever hit
   this one route namespace, never the session-based admin routes or the public
   `/waitlist` endpoint.
2. **A standalone stdio MCP server** (`king-domain-admin-mcp`, sibling repo/directory to
   the other four) — a thin, generic dispatcher driven by a declarative tool list. It
   does not hand-write a function per tool; each tool is `{ name, method, path, tier,
   description, params }` and the server maps a tool call straight onto an HTTP request
   against `/api/mcp-admin${path}`.

## Tiering (carried over from pendu-admin-mcp)

- **Tier 1** — read-only (list decisions, get waitlist stats, list admins). No audit log
  needed beyond normal request logs.
- **Tier 2** — mutating but reversible/low-risk (post a comment, cast a stance, create a
  decision). Logged — see "Audit logging" below for where.
- **Tier 3** — mutating with real, harder-to-reverse impact (closing a decision, revoking
  an admin, deleting data). Requires the caller to pass a literal `confirmed: true` —
  enforced at the Zod schema level, so the call fails validation before it even reaches
  the backend unless that's explicitly set. This exists specifically so an agent can't
  accidentally revoke someone's admin access or close a decision as a side effect of a
  loosely-worded request — it has to be a deliberate, named action.

## Candidate tool list (first pass — not final)

Grouped by the resource they touch. Every list endpoint forwards a loose query-params
object rather than re-declaring every filter, matching pendu-admin-mcp's approach.

**Decisions** (once the [shareholder decisions feature](./shareholder-decisions.md) exists)
- `list_decisions` (tier 1)
- `get_decision` (tier 1)
- `create_decision` (tier 2) — owner-only at the backend level regardless of MCP tier
- `add_decision_comment` (tier 2)
- `cast_decision_stance` (tier 2)
- `close_decision` (tier 3, requires confirmation)

**Waitlist**
- `list_waitlist_entries` (tier 1)
- `get_waitlist_stats` (tier 1)
- `get_waitlist_export_summary` (tier 1) — **not** a raw CSV dump over the tool response.
  MCP's stdio JSON-RPC channel isn't a file-transfer mechanism, and a growing waitlist
  would eventually blow past reasonable tool-output size. Returns structured JSON
  instead: `total_count`, `count_by_category`, `latest_signups` (small capped list). The
  actual CSV file download stays exactly where it already is — the dashboard's existing
  `/admin/waitlist/export.csv` HTTP endpoint, used by its download button — which is the
  correct mechanism for a real file, not something MCP needs to replicate.

**Admin management**
- `list_admins` (tier 1)
- `invite_admin` (tier 2)
- `revoke_admin` (tier 3, requires confirmation — this ends someone's access immediately)

This list grows as the product does (once Milestone 06 domain objects exist — jobs,
applications, contracts — those get their own read/write tools too). Not designing that
now; this MCP is scoped to what already exists plus the decisions feature.

## Audit logging

`pendu-admin-mcp`'s local `audit.log` file lives on **the machine running the MCP
server** (Claude Code's own machine, since this is a stdio server the client launches
locally) — it is never deployed to Render, so the "ephemeral filesystem loses the log on
restart" concern doesn't actually apply to it as originally built. That said, a
local-only file is still the wrong home for King Domain's tier-2/3 audit trail for a
different, real reason: it's invisible to other shareholders, disappears if Samuel
switches machines, and tier-2/3 actions here (creating a decision on someone's behalf,
revoking an admin) deserve a durable record everyone with dashboard access can see, not
just a file on one laptop.

**Decision**: write tier-2/3 audit entries through the backend, into Postgres —
`McpAuditLog` (tool name, args, response status, actor, timestamp) — via a dedicated
`POST /api/mcp-admin/_audit` call the MCP server makes alongside (or the backend can do
this itself, inside each mcp-admin route handler, which avoids a second network call per
action and is the simpler option). Keep a local `audit.log` too as a cheap secondary
trail for offline debugging, but the database table is the source of truth.

## Security notes carried over deliberately

- The MCP token auth is **not** built on top of the existing admin session/cookie auth
  middleware. Same reasoning as pendu: extending shared auth to recognize a second token
  type risks that token working somewhere it shouldn't. A completely separate, narrowly-
  scoped check is safer even though it's a few more lines of code.
- The backend refuses all `/api/mcp-admin/*` requests with a `503` if
  `MCP_ADMIN_API_TOKEN` isn't set in the environment — fails closed, not open.
- The token itself lives only in this MCP server's local `.env` (gitignored) and the
  backend's environment (Render) — never in the mobile app, never in a public repo.

## Build order

1. `king-domain-backend`: add `src/mcp-admin/mcp-admin.middleware.js` and
   `mcp-admin.routes.js`, mounted at `/api/mcp-admin`, wrapping the same underlying
   logic the session-authenticated `/admin/*` routes already use (don't duplicate
   business logic — the MCP routes call the same service functions, just behind
   different auth). Include the `McpAuditLog` table in this pass's migration.
2. New sibling directory `king-domain-admin-mcp` — `server.js` + `tools.js`, same
   dependencies as pendu-admin-mcp (`@modelcontextprotocol/sdk`, `zod`, `dotenv`).
3. Register it in Claude Code's MCP config so it's available in future sessions here,
   the same way `pendu-admin` shows up as `mcp__pendu-admin__*` tools today.
4. Build decisions tools alongside the decisions feature itself, not before it — no
   point wiring MCP tools against an API that doesn't exist yet.

## Sequencing relative to the decisions feature

This MCP server is genuinely more useful *after* the shareholder decisions feature
exists — most of its value is decisions + waitlist/admin tools together. Recommend
building the decisions feature's backend first, then adding this MCP layer on top of
the same routes, rather than building the MCP shell first with nothing real behind it.

## Reviewed

External review (2026-09-03) prompted two changes, both folded in above:
`export_waitlist_csv` was replaced with `get_waitlist_export_summary` (structured JSON,
not a raw file blob over stdio — the real CSV download stays on the existing HTTP
endpoint), and tier-2/3 audit logging moves from a local-only file to a `McpAuditLog`
Postgres table, since the local file is invisible to other shareholders regardless of
whether it's technically ephemeral-storage-safe (it runs on Samuel's machine, not
Render, so that specific risk didn't apply, but the durability/visibility problem is
real for a different reason).
