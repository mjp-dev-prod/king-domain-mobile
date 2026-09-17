# Correction — Proof-of-Skill Screen (Talent Journey Step 2)

> Send this to Gemini before it reprompts Stitch for this screen. It supersedes the
> first version of this screen (the "Demonstrate Capability with Evidence" screen with
> a mandatory practical challenge and "Submit Skill Evidence & Unlock Jobs" CTA).

## What was wrong with the first version

The prompt followed the brand rules correctly (colors, type, no invented jargon, no
3D/gradients) — that part worked. But the underlying **mechanic** doesn't match the
vision doc or the research, and the user caught this directly by asking: *"if I were a
developer, would I have to code a challenge? Not everyone will do this — some will
just give up looking at it."* That instinct is correct, and here's why:

1. **The vision doc never says proof-of-skill is a mandatory gate.** §5 and §10
   describe portfolio evidence, completed marketplace work, and assessments "where
   useful" as *additive* ways to build credibility over time — not a required timed
   challenge a student must clear before "unlocking" jobs. The screen's own copy
   ("Submit Skill Evidence & Unlock Jobs," a pending-review countdown clock for a
   synthetic 30-second-reel task) invented a gate mechanic that isn't in the source
   document.

2. **The research found platform-administered skill tests are the weakest, actively
   dying trust signal.** Upwork built exactly this kind of mechanic and killed it in
   2020 because clients had learned to ignore the scores and the tests were gameable.
   The evidence-strength order that actually holds up, strongest to weakest: real
   completed work history + reviews → outcome-gated badges (earned by delivering real
   client work) → verifiable portfolio with named/live links → recognized third-party
   credentials (only in categories buyers already understand) → generic
   platform-administered tests, which is the weakest signal found anywhere in the
   research.

3. **A synthetic task disrespects real evidence.** A developer with two years of real
   freelance work and a real GitHub history would be stopped at the same gate as
   someone with nothing, and forced to prove themselves via an artificial task instead
   of what they already did. That's backwards, and it's exactly the friction the
   research's cold-start findings warn about — LinkedIn's own data shows ~49% of users
   never finish profile completion even with far lower stakes than "prove you can
   code."

4. **This mechanic already exists correctly in the real Flutter app** and should be
   what this screen is designed to match, not something reinvented on top of it: a
   student submits one real work sample per skill category (a file, a link, a
   description of real past work), and a human reviewer marks it verified or not.
   There's no timed challenge, no synthetic task, no "unlock" framing. A student can't
   apply to jobs in a category until it's verified there — but that gate is tied to
   real evidence, reviewed by a person, not a manufactured test.

## What to design instead

Redesign this screen around **real work samples + human review**, not a challenge:

- Per skill category, the student attaches **real proof**: a file upload, a portfolio
  link (Behance, GitHub, a live site, a video they actually made), or a description of
  actual past work — not a task assigned by the platform.
- Status is simply **Pending review** → **Verified**, set by a human reviewer, not a
  countdown clock on a synthetic deliverable.
- No CTA framing this as "unlocking" access. The plain state is: this category isn't
  verified yet, so job applications in it aren't available yet — worded as a fact
  about the category, not as a gate the student must clear to "earn" access.
- A student with **zero proof items should still have a usable, visible profile** —
  proof accumulates per category over time; it's not a blocking step in a linear
  onboarding wizard the way "STEP 2 OF 3" framed it.
- If a genuinely new-to-everything beginner has no work to show yet, do not
  invent a synthetic test to fill that gap. This is a real, currently unsolved
  question — flag it back rather than designing around it with a challenge mechanic.
  (Every competitor studied in the research has the same unsolved gap; there is no
  evidenced answer to copy.)

## Rules that still apply, unchanged

Everything from the original Stitch/Gemini briefs still holds: strict brand tokens,
no invented jargon, no 3D/gradients/glow, "illustrative" labeling for anything the
vision doc leaves open, real sample data, mobile-first responsive layout. This
correction only changes the *mechanic* being designed, not the visual system.
