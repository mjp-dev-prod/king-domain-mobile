# King Domain

Student talent marketplace — students and emerging talent prove their skills, work under
protected payment terms, and build a reputation that outlasts graduation.

This repo is the **Flutter mobile app** and the anchor workspace for the project. Sibling
repos live alongside it:

| Directory | What it is |
|---|---|
| `king-domain-mobile` | Flutter app (this repo) — `com.kingdomain` / `king_domain` |
| `king-domain-backend` | Node/Express API |
| `king-domain-web` | Waitlist landing page — React 19 + Vite + `vite-react-ssg` (NOT Next.js) |

Source of truth for product decisions: `Student_Talent_Marketplace_Product_Vision_v0.1.pdf`.

---

## Brand — v0

Working direction, established while building the waitlist landing page. Not locked; a motion
designer may revise it. Anything built now should use these values rather than inventing new
ones, so a later change is a single find-and-replace.

The concept: **proof, credentials, earned trust** — closer to a verified ledger or a diploma
than a generic gradient SaaS startup. Warm, confident, restrained.

### Colour

| Token | Hex | Role |
|---|---|---|
| Ink | `#151A2E` | Primary dark ground; body text on light surfaces |
| Ink-2 | `#1E2438` | Raised dark surface — cards, status strip |
| Ink-3 | `#2A3149` | Hairline borders on dark |
| Paper | `#FAF8F3` | Warm off-white ground — deliberately not pure white |
| Paper-2 | `#F1EEE6` | Secondary light surface |
| **KD Gold** | `#C9A227` | **The** accent — CTAs, logomark, italic emphasis |
| Gold-soft | `#E0BE4A` | Gold hover / lighter gold on dark |
| Signal Green | `#2F7A5E` | Verified / proof / trust cues on light |
| Green-soft | `#4FA37F` | Same cues on dark |
| Slate | `#5B6178` | Secondary text on light |
| Slate-dim | `#8A90A3` | Secondary text on dark |
| Open/pending | `#E2896C` | Status badges only — a decision, application, etc. still awaiting resolution |
| Settled | `#6FBBA2` | Status badges only — resolved/closed, same semantic family as Signal Green |

Open/pending and Settled are a status-badge pair, added for the admin dashboard's shareholder
decisions feature and reused wherever else a record needs an open-vs-resolved status (never as
general decoration, same rule as Signal Green). Values match the Marketplace Decision Ledger
artifact's own dark-mode tokens so both surfaces agree.

**Gold is the single bold move.** Primary CTA, the KD mark, italic emphasis in a headline, one
or two key highlights — nothing else. It must never become a dominant fill or a background.
Green is reserved strictly for verification/proof/status semantics, never decoration.

### Type

| Role | Face | Notes |
|---|---|---|
| Display | **Fraunces** | Headlines. Italic + gold for the emphasised phrase in a hero. |
| Body | **Public Sans** | All running copy and UI. |
| Mono | **JetBrains Mono** | Eyebrow labels, stat labels, step numbers. Uppercase, letter-spaced. |

Logomark is a typographic **KD** in Fraunces 700, gold. No illustrated logo yet — deliberately
left open.

### Do not

These were explicit calls, not accidents:

- No gradients — background, text, button or border.
- No glassmorphism, frosted panels or blur effects.
- No heavy drop shadows or glows. Depth comes from hairline borders (`Ink-3`) and flat fills.
- No rounded-everything. Corner radius stays small (3–6px).
- No stock photography, no floating abstract blob illustrations.
- No emoji as icons or section markers. Icons are simple line/geometric (`lucide-react` on web).

Reference implementation: `king-domain-web/src/styles/_tokens.scss`.

---

## Working agreement

- **No MVP mentality.** Depth over speed; a thin slice validates the model, it is not a licence
  to ship something half-considered.
- **Product decisions before engineering ones.** Several major questions (marketplace model,
  verification mechanics, progression scoring, payment provider, dispute rules, monetisation)
  are deliberately still open and tracked in a decision ledger. Do not let an implementation
  choice quietly settle one of them — flag it instead.
- **Database is not chosen yet.** The backend currently persists the waitlist to a JSON file on
  purpose, to avoid locking a data-layer decision ahead of domain modelling. Leaning is
  Postgres + Prisma when real entities exist, but that is not decided.

---

## Hard rules — learned the expensive way on a sibling project

These five cost real time on Pendu (the other product in this workspace). They are
not style preferences; each one traces to a specific multi-hour failure. Adopt them
here from day one rather than rediscovering them.

**1. Log the state that DECIDES the outcome, never the value you passed in.**
A log that reports a parameter you handed to an API — while the API actually decides
using different state — reads as authoritative and actively misleads. On Pendu this
turned a ~1h bug into a many-hour investigation and produced two false "it's working"
claims against a correct user bug report.

- Log **both sides** of every comparison (id match, dedupe, sort key, merge winner).
- Log the **read-back**, not "write succeeded" — `INSERT OR IGNORE` hides failures.
- Before saying "fixed", name the log line that would appear **if it were wrong**, and
  confirm it is absent. If you can't name one, it isn't instrumented.
- **Believe a user's bug report over your own log line.** The log has been wrong before.

**2. Verify library/framework behaviour with Exa — never from memory.**
Anything version-sensitive (a package's exact export surface, a framework's current
behaviour, best practice for a fast-moving tool) gets `mcp__exa__web_search_exa` or
`mcp__exa__web_fetch_exa` **first**. Real cost on a sibling repo: several wrong
assumptions in a row about React 19 / react-router SSR behaviour, each costing a full
rebuild-and-inspect cycle. Exa is for the outside world; reading this repo's actual
code is for "does it work here". Use both.

**3. Research before building, when entering an unfamiliar domain.**
This project is a student talent marketplace — two-sided marketplaces, escrow,
verification and reputation are all domains with well-documented failure modes. Before
committing engineering time to a major mechanic, establish: what happens today, who
has the problem, how they solve it now, what already exists, and where it fails.

Tag findings so evidence stays separable from opinion: 🟢 fact (named source) ·
🔵 observed (in a product or this codebase) · 🟣 synthesis (multiple sources agree) ·
🟡 hypothesis (unvalidated) · 🔴 unknown.

**A negative conclusion is a successful outcome.** "Users don't have this problem" or
"an existing tool already solves this well" saves months. Never shape research to make
an existing idea look correct.

**4. Shrink the scope, never the standard.**
One mechanic that works completely beats three that half-work. If something must be
cut, say what was cut and why — never silently narrow the ask. This applies to AI
agents too: if a model proposes a fake/static substitute for real behaviour to make a
task easier, reject it.

**5. Audit before documenting, and keep the operating file accurate.**
On Pendu, the file every AI session reads on every prompt still described the product
by its **previous name** and never mentioned four shipped features. Every session was
starting from a wrong premise and silently rebuilding context mid-task — a direct cause
of scope drift and ghost bugs.

- This file must stay short enough to actually be read. A long file gets skimmed, and a
  skimmed file is the same as no file.
- Put **rules and identity** here. Do **not** put a feature inventory here — that is the
  part that rots.
- If this file contradicts the code, **the code is right** — fix this file.

---

## Docs

Keep a task-based index at [`docs/README.md`](docs/README.md) — find docs by "what am I
doing", not by browsing a folder. If a doc isn't in the index, it isn't load-bearing.

Structure to grow into (Pendu reached 87 unindexed docs before this was fixed):

| Folder | Holds | Rots? |
|---|---|---|
| `docs/core/` | How things actually work. **Authoritative.** | **No** — update with the code, same PR |
| `docs/research/` | Domain research, market findings, strategy | Yes — date it |
| `docs/features/` | Per-feature specs | Update or archive |
| `docs/archive/` | Superseded. Marked do-not-trust | Frozen |

Rules: one doc per subject (no `_V2`, `_FIXES`, `_PROGRESS` — edit the original);
behaviour docs go in `core/` and nowhere else; don't document a fix, fix it and correct
the doc that was wrong.

---

## Session hygiene

- **End a session when the model starts shrinking scope or repeating mistakes.** Long
  contexts degrade: early instructions get ignored and the easiest code path wins. Start
  a fresh session with a short written handoff instead of pushing through.
- **Hand off in writing, not memory.** At the end of a working session, write a short
  block — what's done, what's next, what's blocked, open decisions — and paste it into
  the next session. Treat it as the source of truth over anything the model "remembers".
- **Push before you stop.** Work isn't done until `git push` succeeds.

---

*Last verified against the codebase: 2026-09-12. Working-discipline section ported from
the Pendu workspace, where each rule traces to a specific real failure.*
