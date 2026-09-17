# Correction 03 — Three Invented Mechanics in the 2026-09-13 Stitch Export

> Send to Gemini before the next Stitch pass. This is the third correction in the
> same category, and the pattern now matters more than any individual fix — see the
> closing section.

## Verified first: the vision doc was not the problem

Before writing this, the vision-doc copy Stitch was working from
(`student_talent_marketplace_product_vision_v0.1.md`, 635 lines) was searched
directly for every mechanic below. **None of them appear in it.** The spec Stitch
received was intact. These were invented during generation, not inherited from a
drifted source.

---

## 1. "Proof Score" leaked into a screen we never corrected

**Where:** `application_scope_negotiation` — *"Short-Form Video Proof (Verified Score
94/100)"*.

Correction 02 removed the composite score from talent discovery, and that landed —
`talent_discovery_proof_evaluation_2` is clean. But the same invented metric
reappeared on a different screen, which means it was treated as a local fix to one
screen rather than a rejected concept.

**The concept is rejected everywhere, not just on discovery.** There is no numeric
proof score in this product, under any label, on any screen. Verification is a
binary fact set by a human reviewer — verified, pending, or unverified — per
category. A number implies a precision the review process does not have and cannot
defend, and it recreates exactly the ranking dynamic Correction 02 removed.

**Fix:** delete the score. The screen already carries the real signal — "UNILAG
verified" and "Short-form video — proof verified by human review". That is the whole
claim, and it is enough.

---

## 2. "ESCROW-FREE • PROTECTED FLOW" contradicts its own screen

**Where:** `screen_8_scope_agreement_project_funding` — header reads
*"ESCROW-FREE • PROTECTED FLOW"*, while the same card says funds are *"locked in
protected status"* and *"released only after you approve"*.

Those two statements cannot both be true. Holding a buyer's funds until approval is
escrow in substance, whatever it is called. Worse, "escrow-free" is a **claim about
the payment architecture that nobody has decided** — the payment provider and
regulated structure are explicitly open questions in the vision doc (§13), and the
market research flagged that two well-funded Nigerian fintechs died specifically on
this cost structure in 2026. This is not a label to improvise.

**Fix:** remove the phrase entirely. Use the vision doc's own term —
**"protected transaction"** — and describe the mechanic in plain words: funds are
held, then released on approval. Make no claim about *how* they are held.

---

## 3. "Double-blind review system" is invented — and might be worth keeping

**Where:** `screen_10_reputation_signal_mutual_review` — a "DOUBLE-BLIND REVIEW
SYSTEM" where feedback is revealed only after both parties submit.

This one is different from the other two, and the difference is worth stating
plainly: **the mechanic is defensible.** The market research found documented
reputation inflation on oDesk/Elance driven by retaliation fear in public bilateral
rating systems — average ratings rose a full star over seven years with no quality
improvement — and the platform's own fix was a feedback channel the counterparty
could not see. Mutual-reveal attacks the same failure. On the evidence, it is
probably a good idea.

**It is still not Gemini's or Stitch's decision to make.** It does not appear in the
vision doc, it changes how reputation works, and it was introduced silently inside a
screen design. A good invented mechanic introduced without a decision is still an
undecided mechanic — and the reason this matters is that nobody would have caught it
if it had been a *bad* one dressed the same way.

**Fix for now:** keep it in the prototype, but label it visibly as flagged and
undecided (already done in the built prototype's annotation). Do not build further
screens that assume it. It needs an explicit decision.

Also drop the jargon: "double-blind" is clinical-trial language. Say what it does —
*"reviews are revealed after both sides submit"*.

---

## The pattern, which now matters more than any single fix

Three corrections, three different screens, one identical failure: a plausible
marketplace mechanic was invented to fill a gap the vision doc left open, and
presented as settled design.

- Correction 01: a mandatory skill challenge gating job access.
- Correction 02: a composite score ranking students against each other.
- Correction 03: a proof score (again), an escrow claim, a review mechanic.

**The operating rule from here:** when the vision doc is silent on a mechanic,
that silence is the answer — design the screen *without* the mechanic, and flag the
gap. Do not fill it. Every one of these was generated because the gap felt like it
needed something there. If a screen genuinely cannot be designed without inventing
a mechanic, stop and raise it rather than shipping the invention inside a layout,
where it arrives looking decided.

A useful test before adding anything: *can I point to the section of the vision doc
this comes from?* If not, it does not go in the screen.
