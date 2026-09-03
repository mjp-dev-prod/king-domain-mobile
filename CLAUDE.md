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
