# Gemini Brief — Directing the King Domain Full Vision Prototype (Pass 1)

> Read this before writing any Stitch prompts. It defines your role in this pass,
> what you're allowed to decide versus not, and the handoff to Claude Code, who
> builds the actual prototype file.

---

## The pipeline for this pass

1. **You (Gemini)** write the Stitch prompts, screen by screen, and review what
   Stitch generates for fit against the vision.
2. **Stitch** generates the visual design for each screen from your prompts.
3. **Claude Code** takes what you and Stitch produce and builds it into one real,
   cohesive, responsive, production-grade HTML prototype file — matching the
   reference file `esports-tournament-flow.html` (Pendu's tournament prototype) in
   depth and craft — and is also the checkpoint that catches anything that drifts
   from the actual product vision before it gets built in.

Your job in this pipeline is **direction and screen-by-screen prompting**, not final
visual sign-off and not implementation. If something you or Stitch produced gets
corrected before it's built into the prototype, that's the process working as
intended, not a failure — it has already happened twice this project (an invented
"money vault" fintech screen, and unrequested 3D claymorphic illustrations), and both
were caught and rejected before reaching real code. The goal this pass is to catch
drift *before* it reaches that stage, by staying tightly anchored to the source
document below.

## The one source of truth

Every prompt you write for Stitch must be traceable to a specific section of
`Student_Talent_Marketplace_Product_Vision_v0.1.pdf`. Do not design from "what a
freelance marketplace usually has" — design from what this specific document says.
That reasoning ("most marketplace apps have this") is exactly what produced the two
hallucinated screens mentioned above. Treat it as a stop sign: if you catch yourself
justifying a screen that way, go re-read the vision doc for what it actually says
instead.

The full screen list to prompt, in order, is the vision doc's own two journeys (§4):

**Talent journey:** join → verify identity/student status → build profile → add
skills/portfolio evidence → complete proof-of-skill step → discover work → apply/
negotiate → work under defined project states → submit delivery → receive payment →
receive reputation signal → use reputation for better opportunities.

**Client journey:** describe need → discover/matched talent → evaluate proof/
portfolio/reputation → select talent, agree scope → fund the project (protected
transaction) → collaborate/receive progress → review, request revision/approve/
escalate → release payment/resolve dispute → leave a review.

Also required, straight from the doc:
- The talent profile's exact layers (§5): identity, campus/education, skills, proof,
  portfolio, marketplace history, reputation, availability, commercial profile. Don't
  add layers, don't drop any.
- The protected-transaction state machine (§8), used verbatim: `PENDING → FUNDED/
  PROTECTED → IN PROGRESS → SUBMITTED → REVISION REQUESTED → APPROVED → RELEASED`,
  branching to `DISPUTED` and `REFUNDED/PARTIAL RESOLUTION`.

## Decisions you can make vs. decisions that aren't yours to make here

**You can pick one reasonable, clearly-labeled option** for anything the vision doc
itself marks as still open (its §13 table) — but it must be labeled as illustrative in
the prompt, so Stitch's output and the final prototype both make clear it isn't a
locked decision:

- **Marketplace model** (§7 — catalogue / job marketplace / matching-first / hybrid):
  the doc's current lean is hybrid. Prompt that, and have Stitch's screen note
  "illustrative — marketplace model not yet locked."
- **Progression stages** (§6): the doc already gives placeholder names — New Talent →
  Verified → Rising Talent → Trusted Talent → Top Talent. Use exactly those, labeled
  as placeholder stage names, not final.
- **Skill assessment design** (§5/§13): direction is portfolio + practical evidence +
  optional/required assessments; exact mechanic is open. Prompt a simple
  assessment/challenge step, labeled illustrative.
- **Verification mechanics** (§8/§13): identity verification + student/university
  verification are both explicitly named. Don't invent a specific technical method
  beyond what the doc says.

**Not yours to decide silently:** anything not implied by the vision doc at all — new
product mechanics, new metaphors (vaults, banking-style framing), or visual identity
choices that override the brand rules below. If something feels missing from the
vision doc that you think the product needs, flag it back to the user as a gap in the
vision doc itself — don't quietly fill it in a Stitch prompt.

## Brand constraints to bake into every Stitch prompt

Carry these into every prompt so Stitch doesn't drift on its own:

- Colors: Ink `#151A2E` / Ink-2 `#1E2438` / Ink-3 `#2A3149` (dark surfaces + hairline
  borders), Paper `#FAF8F3` / Paper-2 `#F1EEE6` (warm off-white, never pure white),
  Gold `#C9A227` / Gold-soft `#E0BE4A` (the single bold accent — CTAs, wordmark,
  emphasis, never a dominant fill), Signal Green `#2F7A5E` / Green-soft `#4FA37F`
  (verification/proof/trust cues only), Slate `#5B6178` / Slate-dim `#8A90A3`
  (secondary text), Open/pending `#E2896C` and Settled `#6FBBA2` (status badges only).
- Type: Fraunces for display/headlines, Public Sans for body/UI, JetBrains Mono for
  uppercase eyebrow/stat labels.
- No gradient fills, no glassmorphism/blur, no drop shadows, glows or specular sheen, no
  rounded-everything (radius stays 3–6px), no claymorphism, no stock photography, no emoji
  as icons.
- Dimensional/3D objects are **allowed only when matte and content-bearing** — real
  work-sample thumbnails, moodboards, delivered media, or a restrained matte object with
  none of the banned effects above. Never as pure decoration next to a label that already
  says the same thing in words. (Updated 2026-09-13 — replaces an earlier blanket "no 3D"
  rule that was stricter than the brand doc actually requires.)
- Don't reference or copy another product's visual language directly — not LinkedIn's
  card-grid look, not Pendu's esports HUD look. Borrow *lessons* (e.g. LinkedIn's
  information density on a job card) without borrowing the *look*.

## What "production-grade" means for what you hand off

Direct Stitch toward, and check for, before handing a screen off:
- Real sample data in every prompt (real-sounding job titles, budgets, student names,
  universities, portfolio items) — never lorem ipsum or placeholder text
- Full information density per screen, not a wireframe-level sketch
- Mobile-width-first layouts (this is a mobile app) that still hold up wider
- Consistent interaction states considered (hover/active/disabled), not just one
  static happy-path view

## When to stop and ask instead of deciding

Flag back to the user rather than guessing when:
- The vision doc doesn't have enough detail to prompt a screen confidently (e.g.
  exact dispute-resolution UI — §8 gives principles, not a flow)
- Two parts of the vision doc seem to want different things for the same screen
- You're about to fill a gap with "what similar apps do" instead of what the document
  says

## Handoff to Claude Code

Once you and Stitch have a screen's design settled, it gets handed to Claude Code to
build into the actual navigable HTML prototype file. Claude Code will check each
screen against the vision doc independently before building it in — expect and treat
that as the intended process, not a rejection of your work.
