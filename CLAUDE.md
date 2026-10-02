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

## Brand — v1 (mobile app)

Chosen by Victor on 2026-10-02 from `prototypes/palette-explorer.html` (Royal Violet, Public Sans
headlines). It replaces v0 because v0 ("flat fills, hairline borders, 3–6px corners, no
shadows") made the app look like a tutorial project. Evidence and references:
[docs/research/ui-audit-2026-10-01.md](docs/research/ui-audit-2026-10-01.md).

**Scope:** the Flutter app. The waitlist site (`king-domain-web`) and the admin dashboard still use
v0 tokens; moving them is a separate decision, not implied by this one.

The concept is unchanged: **proof, credentials, earned trust.** What changed is how it is
rendered. Depth comes from **tonal layering** (stacked dark surfaces, as Discord and Telegram do),
soft rounded shapes and motion. It is **not** neumorphism: soft-shadow controls fail contrast and
look broken in dark mode.

### Colour (Royal Violet)

| Token | Hex | Role |
|---|---|---|
| Ground | `#0D0A16` | Page background |
| Surface-1 | `#151121` | Cards, list groups, inputs |
| Surface-2 | `#1D182E` | Raised: tiles inside cards, floating tab bar, sheets |
| Surface-3 | `#27203D` | Highest: toasts, pressed/selected, skeleton shimmer |
| Line | `rgba(255,255,255,.06)` | Dividers inside a surface only; never card outlines |
| Text | `#F2EFFA` | Primary text (off-white, never pure white) |
| Text-2 | `#ABA4C3` | Secondary text |
| Text-3 | `#716A8B` | Hints, timestamps, disabled |
| **Violet** | `#7451F2` | **The** action colour: primary button fill, active tab, progress |
| Violet-text | `#A991FF` | Violet used as text or icons on dark (fill violet is too dark for text) |
| Violet-soft | `rgba(140,108,255,.16)` | Selected chips, active tab pill, brand tags |
| **Gold** | `#F2C14E` | **Money only** — budgets, earnings, payouts — and the KD logomark |
| Green | `#34D399` | **Verified / done / paid** only (soft: `rgba(52,211,153,.13)`) |
| Amber | `#F5A55B` | Waiting on someone: pending, extension requested, deadline near |
| Red | `#F87171` | Errors, destructive actions, missed deadlines |

On-violet text is white (5.0:1). Every pairing above passes WCAG AA; the palette explorer
measures them live.

**Each colour has one job.** Violet means "you can act", gold means "money", green means
"verified or done", amber means "waiting". Never use one for another's meaning, and never as
decoration.

### Type

| Role | Face | Notes |
|---|---|---|
| Headlines and UI | **Public Sans** | 800 weight, tight letter-spacing for headlines; 600–700 for titles |
| Body | **Public Sans** | 400–500 |
| Mono | **JetBrains Mono** | Eyebrow labels and step numbers only. Uppercase, letter-spaced |
| Logomark | **Fraunces 700** | The typographic **KD** in gold. The only place Fraunces remains |

Numbers that line up (money, counts, countdowns) use tabular figures.

### Shape, depth and motion

- **Radius:** 12 (small controls) · 16 (buttons, tiles) · 20 (cards) · 28 (hero cards, sheets) ·
  pill (chips, tags, tab indicator).
- **Depth:** a card is one surface step lighter than what it sits on. No borders around cards.
- **Shadows** only on things that float: the tab bar, sheets, toasts, the sticky CTA bar.
- **Glow:** only the **single primary button** on a screen gets a soft violet shadow. Nothing else
  glows: not cards, icons, text or badges.
- **Motion:** 250 ms state changes, 400 ms layout, 450–700 ms arrivals; `easeOutCubic` for most,
  a spring (`easeOutBack`) for selection pops. Press-scale 0.92–0.98 on everything tappable;
  haptic tick on choices. Respect reduced motion.
- **States are designed, not defaulted:** skeletons for lists, spinner only inside the button
  that's working, toasts (one at a time, Undo for reversible actions), empty states that say
  why and what to do next, inline errors with Retry. A loading state is held ≥ 300 ms so it
  never flashes.

### Imagery

Decided 2026-09-13, after a Stitch pass shipped a 3D gold padlock and a Gemini pass proposed a
claymorphic asset set; still in force.

Images must be **real content**: a talent's actual work, delivered files, profile photos. Real
work imagery is what fixes "the app looks plain", and it doubles as proof. Dimensional/3D art is
allowed only when it is matte and carries information, never as decoration. Illustrations are
allowed for empty states. Where images appear, and what each surface traces back to:
[docs/features/imagery-surfaces.md](docs/features/imagery-surfaces.md).

### Do not

- No neumorphism (soft-shadow controls) and no glassmorphism or blur on cards.
- No gradients as decoration. Allowed only as functional fades (content scrolling under a
  sticky bar, skeleton shimmer).
- No glow except the single primary button.
- No stock photography, no floating abstract blobs, no decorative 3D.
- No emoji as icons or section markers. Icons are simple line icons (Lucide style).
- No colour used outside its job (see Colour).

Reference implementation: `prototypes/palette-explorer.html` (Royal Violet). The Flutter tokens
in `lib/core/constants/` move to these values when the UI rebuild starts.

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

*Last verified against the codebase: 2026-10-02 (brand v1). Working-discipline section ported from
the Pendu workspace, where each rule traces to a specific real failure.*
