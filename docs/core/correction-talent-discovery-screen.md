# Correction — Talent Discovery Screen (Client Journey Step 2)

> Send this to Gemini before it reprompts Stitch for this screen. It supersedes the
> "Applicants For: Campus Brand Ambassador Launch Videos" screen with "SORT BY: PROOF
> SCORE" and a "TOP RECOMMENDED CANDIDATE" badge.

## What was wrong with the first version

Brand tokens, type, and the "illustrative" footer label were all followed correctly.
The problem is the underlying **ranking mechanic**, which the user caught directly:
*"I don't want a situation whereby the platform just turns immediately to choosing a
few 'elite' when a lot of people are also good but just haven't had the chance to
complete jobs."* That instinct is correct and is backed directly by the research:

1. **The vision doc doesn't describe discovery as a ranked leaderboard.** §7's
   matching-first concept is about reducing a client's *search effort*, not producing
   a permanent, visible hierarchy of students sorted by a composite score. A numeric
   "Proof Score" used as the default sort, plus a "⭐ TOP RECOMMENDED CANDIDATE" badge,
   is a mechanic invented on top of the doc, not drawn from it.

2. **The research found this exact pattern is a real cold-start trap, not a neutral
   feature.** Elfenbein, Fisman & McManus found verification/badging helps *new,
   unproven* sellers disproportionately more than established ones — a good system
   should work to surface capable newcomers, not bury them under a score gap.
   Resnick & Zeckhauser's eBay study found that a couple of early negative signals on
   a new identity had *no significant effect* on outcomes — meaning the size of the
   gap a numeric "Proof Score" visually implies (e.g. 94/100 vs. an unranked newcomer)
   overstates how much that difference should actually matter. Ranking by a composite
   score concentrates opportunity on whoever got there first and actively worsens the
   "no experience → no reviews → fewer clients → no experience" loop the vision doc
   itself names as the core problem to solve (§6).

3. **A public composite score is exactly the reputation mechanic the research flags as
   unvalidated and risky**, not merely unproven. The academic evidence on public,
   compared rankings (cited in the wider research dossier) shows real friction: people
   avoid opting into public comparison even against their own interest, and reputation
   inflation/gaming risk rises once a score becomes something to protect. None of that
   is disproven by making the score read "Proof Score" instead of "reputation" — it's
   the same mechanic with different label.

## What to design instead

The user has decided: show **real signals, let the client weigh them** — no
platform-declared winner, no composite score, no "top candidate" badge.

- **No numeric composite score anywhere on the card** (no "94/100," no "Proof Score,"
  no equivalent under a different name).
- **No "top recommended" / "best match" badge.** Every candidate who is Verified in
  the requested category is shown on equal visual footing — position on the screen
  should not itself imply the platform picked a winner.
- **Show real, non-manipulable facts per candidate instead**, drawn directly from
  what the vision doc's profile layers actually define (§5): verified status
  (university-verified, category-verified — a plain fact, not a score), a real
  work-sample thumbnail/link (not a synthetic task, per the earlier proof-of-skill
  correction), number of completed contracts (a plain count, not a weighted metric),
  and the actual human reviewer's note on the submitted proof item, if any.
- **Ordering should not be a ranking.** Use something neutral — e.g. most recently
  verified first, or unordered/client-filterable by the facts above (category,
  availability, completed-jobs count as a plain filter, not a sort-to-top mechanic).
  The client reads the real signals and decides; the platform does not pre-select a
  favorite for them.
- **A newly-verified student with zero completed jobs must still be visibly
  discoverable and legible** — not pushed to the bottom of an implied ranking. Being
  new is a fact to display plainly, not a penalty to visually bury.

## On the "the app looks too plain" note

Separate, valid point: discovery cards with no visual identity per candidate (no
avatar, no thumbnail of actual work) are harder to evaluate and undersell the vision
doc's own "proof over claims" principle (§5) — a thumbnail of real delivered work is
itself a form of proof, and arguably more legible at a glance than a score number.
Add a real avatar and a small thumbnail of the actual attached work sample (the same
one referenced in the proof-of-skill correction) to each card. This is a density/
legibility fix, not a ranking mechanic — don't let visual polish reintroduce an
implied "best to worst" ordering through card size or placement.

## Rules that still apply, unchanged

Everything from the original Stitch/Gemini briefs and the proof-of-skill correction
still holds: strict brand tokens, no invented jargon, no 3D/gradients/glow,
"illustrative" labeling for anything the vision doc leaves open, real sample data,
mobile-first responsive layout. This correction only changes the *ordering/ranking
mechanic* and adds real visual identity per card — it doesn't change the visual
system.
