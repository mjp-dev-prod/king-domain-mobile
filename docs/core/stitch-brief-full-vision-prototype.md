# Stitch Brief — King Domain Full Vision Prototype (Pass 1)

> Give this document to Stitch/Gemini as-is before generating any screens. It exists so
> the prototype matches the actual product vision instead of inventing new product
> ideas along the way — that has happened twice already this project (an unrelated
> "money vault" fintech screen, and unrequested 3D claymorphic vault/padlock
> illustrations), and both had to be thrown out.

---

## What this pass is

A full, responsive, click-through, production-grade HTML prototype of the **entire
product vision** — both the talent side and the client side — in one navigable file,
matching the depth and fidelity of the reference file `esports-tournament-flow.html`
(Pendu's tournament lifecycle prototype): real design tokens, a working screen
switcher, full detail on every screen, not wireframe-level placeholders.

This is **not** the build order. The actual King Domain team is shipping a much
narrower first slice in the real Flutter app (one job category, manual matching, a
plain-language payment-protection status — see
`docs/core/vision-vs-research-reconciliation.md` if you want that context). This
prototype is a separate artifact: it exists so the founders can *see the whole vision
laid out*, catch anything that drifts from it early, and decide for themselves how to
phase the real build out of it — piece by piece, later. Don't let "we're only building
X first" cut anything out of this prototype. Show the whole vision here.

## Source of truth

**Every screen, mechanic, and piece of copy in this prototype must trace back to a
specific section of `Student_Talent_Marketplace_Product_Vision_v0.1.pdf`.** If it's not
in that document, don't design it. If you're not sure where something comes from, ask
before inventing it — don't fill the gap with something that "feels right" for a
freelance marketplace in general (that's exactly how the money-vault screen happened:
it wasn't in the vision at all, it was invented because it "felt like" a trust product
needed one).

The vision doc's own journeys are the screen list. Build to these directly:

**Talent journey (vision doc §4):** join → verify identity/student status → build
profile → add skills/portfolio → complete proof-of-skill step → discover work → apply/
negotiate → complete work under defined states → submit delivery → receive payment →
receive reputation signal → use reputation for better opportunities.

**Client journey (vision doc §4):** describe need → discover/matched talent → evaluate
proof/portfolio/reputation → select talent, agree scope → fund the project (protected
transaction) → collaborate/receive progress → review, request revision/approve/
escalate → release payment/resolve dispute → leave a review.

The talent profile's actual layers (identity, campus/education, skills, proof,
portfolio, marketplace history, reputation, availability, commercial profile) are
listed in §5 — use exactly these, don't add or remove layers.

The protected-transaction states are explicitly defined in §8 and must be used
verbatim, not reinvented:
`PENDING → FUNDED/PROTECTED → IN PROGRESS → SUBMITTED → REVISION REQUESTED →
APPROVED → RELEASED`, with `DISPUTED` and `REFUNDED/PARTIAL RESOLUTION` as branches.

## Where the vision is still open — mark it, don't hide it, don't invent past it

The vision doc explicitly leaves several mechanics undecided (§13's "Still open"
table). For this prototype, **design one reasonable, clearly-labeled option per open
item** — never silently present an open decision as settled, and never invent a
mechanic that isn't at least implied by the doc:

- **Marketplace model** (service catalogue vs. job marketplace vs. matching-first vs.
  hybrid — §7): the doc's own current lean is hybrid. Design that, and label the screen
  "illustrative — marketplace model not yet locked."
- **Progression stages** (§6): the doc gives explicit placeholder stage names — New
  Talent → Verified → Rising Talent → Trusted Talent → Top Talent. Use exactly these
  labels, and mark the screen "stage names and thresholds are placeholders, not
  decided."
- **Skill assessment mechanics** (§5/§13): the doc says portfolio + practical evidence +
  optional/required assessments are the direction, but exact design is open. Show a
  simple assessment/challenge step, labeled as illustrative.
- **Verification mechanics** (§8/§13): show identity verification + student/university
  verification as steps (both explicitly named in §8), without inventing a specific
  technical mechanism beyond what's written.

## Hard rules — do not cross these

These are settled brand and product rules, not preferences:

1. **No invented mechanics.** No escrow "vaults," no bank-safe metaphors, no dual-
   signature/FDIC-style fintech framing. The vision's own term is "protected
   transaction" — a plain state machine, not a financial-institution aesthetic.
2. **No claymorphism, glassmorphism, blur, glows, gradient fills, specular sheen, or
   drop shadows.** These are banned outright by King Domain's brand v0 (`CLAUDE.md`).
   Dimensional/3D objects are **permitted only when matte and content-bearing** —
   carrying real information (work-sample thumbnails, moodboards, delivered media) or
   rendered as a restrained matte object with none of the banned effects above.
   Dimensional objects as pure decoration are not permitted: if a label already states
   something in words, it does not also need an icon of it. (Updated 2026-09-13 — this
   replaces an earlier blanket "no 3D" rule.)
3. **Use King Domain's actual brand tokens, not a new palette invented for this
   prototype:**
   - Ink `#151A2E` / Ink-2 `#1E2438` / Ink-3 `#2A3149` (dark surfaces, hairline
     borders)
   - Paper `#FAF8F3` / Paper-2 `#F1EEE6` (warm off-white, never pure white)
   - Gold `#C9A227` / Gold-soft `#E0BE4A` — the *single* bold accent (primary CTA,
     wordmark, emphasis). Never a dominant fill or background.
   - Signal Green `#2F7A5E` / Green-soft `#4FA37F` — verification/proof/trust cues
     only, never decoration.
   - Slate `#5B6178` / Slate-dim `#8A90A3` — secondary text.
   - Open/pending `#E2896C` and Settled `#6FBBA2` — status badges only (e.g. contract
     states), same rule as Signal Green: never general decoration.
   - Corner radius stays small (3–6px) — no rounded-everything.
   - Type: Fraunces (display/headlines), Public Sans (body/UI), JetBrains Mono
     (eyebrow labels, stat labels — uppercase, letter-spaced).
4. **Do not clone another platform's visual language.** LinkedIn's density lesson
   (real metadata, real trust badges, real information per card) is worth learning
   from conceptually — LinkedIn's actual light-grey card-grid look is not. Same for
   any esports/gaming HUD look (that's Pendu's brand, a different product).
5. **Do not lead with marketing copy on functional screens.** The vision doc frames
   King Domain as infrastructure for real work, not a landing-page pitch — job feeds,
   profiles, and contract screens should read as a working tool, not an ad for the
   product.

## What "production-grade" means for this pass

Match the reference file's actual craft, not just its length:

- Real, consistent design tokens (CSS variables), not ad hoc inline colors
- A working phase/screen navigator so every screen in both journeys is reachable and
  clickable in one file
- Full information density per screen — real sample data (job titles, budgets,
  student names, universities, portfolio items), not lorem ipsum or placeholder text
- Responsive layout that holds up at mobile width first (this is a mobile app), but
  should not break on a wider viewport either
- Consistent interaction states (hover/active/disabled) on every button and card,
  not just the "happy path" screens

## When something is genuinely ambiguous

Stop and ask rather than guessing. Specifically flag back if:
- A screen the vision doc implies doesn't have enough detail in the doc to design
  confidently (e.g. exact dispute-resolution UI — §8 gives principles, not a flow)
- Two sections of the vision doc seem to want different things for the same screen
- You're tempted to add something because "most marketplace apps have this" — that
  reasoning is explicitly what caused the earlier hallucinated screens and should be
  treated as a stop sign, not a design justification
