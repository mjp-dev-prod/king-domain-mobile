# King Domain — Vision vs. Research Reconciliation

> **Status:** Living reference. Read this before re-deriving "what are we actually
> building" from scratch in a new session.
>
> **Inputs reconciled:**
> - `Student_Talent_Marketplace_Product_Vision_v0.1.pdf` (the original vision — 15
>   sections, explicitly *not* an engineering spec)
> - `docs/research/market-validation-2026-09-12.md` (the adversarial research pass —
>   20 sections + verdict, built specifically to stress-test the vision)
>
> **Reading order:** §0 (verdict) → §1 (the reconciliation table) → §2 (what to build
> first) → everything else is backup detail.
>
> **Evidence tags**, same as both source docs: 🟢 FACT · 🔵 OBSERVATION · 🟣 SYNTHESIS ·
> 🟡 HYPOTHESIS · 🔴 UNKNOWN

---

# §0 VERDICT — read this first

**The vision is not wrong. It is not being shrunk. It is being sequenced.** Every
element in the vision doc's own "Settled direction" table (its §13) is still true as a
*destination*. What the research changes is the **order** you build them in and **which
one you lead with** — because the vision doc's own §14 already says to do exactly that
("lock the marketplace model... map journeys... define trust model... only then
translate to engineering") and nobody has done step 1 yet.

1. **The vision correctly identifies the problem is trust, not talent.** Both documents
   agree: students have skills, buyers don't know who to trust. 🟢 Where they diverge is
   *which* trust mechanism to build first.
2. **The vision's proposed first trust mechanism (broad proof-of-skill: assessments +
   credentials + portfolio, all at once, across many categories) is the one piece the
   research found the weakest live evidence for.** Upwork tried platform-administered
   skill tests and killed them in 2020; the replacement badge system is in
   maintenance-only mode since 2024. 🟢 This is not "skip verification" — it's "verify
   identity and real delivered work, not test scores."
3. **The vision's real, sharpest, most differentiated idea — protected transactions —
   is also the research's strongest, most independently-confirmed finding.** Payment
   risk is the #1 evidenced pain point on both the student and buyer side, everywhere,
   including a live-funded Nigerian competitor (EscrowPay) built on exactly this insight
   with nothing else attached. 🟢 This is the vision's best-supported idea, not a
   casualty of the research.
4. **Campus-first and broad-category are the two vision elements the research found
   genuinely weak evidence for** — not because they're bad ideas, but because the
   nearest real precedent (Clutch: literally this product, campus-exclusive, broad
   creator categories) ran this exact experiment and dropped both before reaching
   scale. 🟢 This is real, on-point, first-degree precedent — not an analogy.
5. **Reputation-that-compounds is coherent as a long-term destination and unvalidated
   as a launch mechanism.** No study found shows reputation *causes* retention as
   opposed to correlating with it, and real academic evidence predicts a meaningful
   minority of users will actively avoid public ranking even against their own
   interest. 🟢 Keep it in the vision. Don't build it first, and don't make it public
   by default.
6. **Nothing here removes a category from the vision permanently.** The research's
   wedge (one category, one transaction type, manual matching, payment-protection as
   the headline) is explicitly the *first slice*, not the ceiling — its own §19 says
   "if this validates, the broader platform elements become things to add to a working
   core, not things to build simultaneously with an unproven one."

**What this means concretely:** build the trust/payment layer first, against one
category, with real students and a real (small) buyer — using the profile and proof
system you've already built in the Flutter app — before adding more categories, public
reputation, campus-exclusivity, or algorithmic matching. Section 2 below is the actual
build list.

---

# §1 The reconciliation table

Every row in the vision doc's own §13 "Settled direction" / "Still open" tables, checked
against the research's findings. **Confirmed** = research supports building this as
described. **Confirmed but resequenced** = the *idea* is right, the *timing/mechanism*
needs to change. **Contradicted** = real evidence argues against building it this way,
specifically.

| Vision element | Vision's own status | Research verdict | What changes |
|---|---|---|---|
| **Problem**: connect capable students to real clients and safer paid work | Settled | ✅ **Confirmed** | Nothing — this is the thesis and it holds. |
| **Positioning**: professional marketplace for emerging talent, students first | Settled | ✅ **Confirmed** | Nothing — "not Fiverr for students" as a *long-term* identity is fine. Just don't lead the *first build* with the full breadth this implies. |
| **Trust is foundational** | Settled | ✅ **Confirmed, strongly** | This is the single best-supported idea in the whole vision. Lead with it. |
| **Protected transactions are foundational** | Settled | ✅ **Confirmed, strongly** | Build this *first*, not alongside five other mechanisms. Use an existing/partnered escrow rail, not custom payment infrastructure, for the first version — the research found two well-funded adjacent fintechs (Gigbanc, Chimoney) died specifically on compliance/KYC cost, not demand. |
| **Proof of skill**: portfolio + practical evidence + optional/required assessments | Settled | 🟡 **Confirmed but resequenced** | Portfolio + real delivered work: yes, lead with this. Platform-administered *assessments/tests* as a primary signal: the weakest, most actively-dying trust mechanism found (Upwork killed its own). Keep assessments as a possible *later, secondary* signal, not the launch mechanism. |
| **Talent identity**: profile represents capability, not just a bio | Settled | ✅ **Confirmed** | Already built in the Flutter app (`TalentProfile`, skill categories, proof items). Extend, don't replace. |
| **Progression / reputation grows through real evidence** | Settled | 🟡 **Confirmed but resequenced** | The *private*, portable version (a verified work history the student controls) is well-supported. The *public, ranked, compounding* version has real evidence it will backfire for a meaningful minority of users (opt-out, gaming). Build the private record first; treat public ranking as a separate, later, opt-in decision. |
| **Broad categories**: support multiple remote-service disciplines | Settled | 🔴 **Contradicted for the launch; fine as a destination** | Every marketplace-strategy source (NfX, Andrew Chen, and the direct Clutch precedent) says liquidity is won category-by-category, not all at once. Launch in one category. Expand once that one works. |
| **Campus advantage**: use concentrated campus talent for acquisition | Settled | 🔴 **Contradicted as a first move** | Campus solves *supply* recruiting, which isn't the hard side. It does nothing evidenced for *demand* (buyers), which both major marketplace frameworks say is the harder side to win. Clutch — the nearest real precedent — dropped campus-exclusivity before reaching scale. Use campus as one *channel* to find students; don't gate the product on it or market it as the differentiator. |
| **Monetization**: multiple models remain open | Settled | ✅ **Confirmed — stay open, with one addition** | Nothing to lock yet. New input: escrow "float" (interest on held funds) is a real, disclosed revenue line at Upwork; worth modeling once a payment partner is chosen. Flat-fee-capped models (not %-based) fit small transactions better — a %-based model like Stripe Connect's can eat >20% of a $15–100 transaction in processing/dispute costs alone. |
| **Marketplace model** (services / jobs / matching / hybrid) | Open | 🟡 **Narrowed, not resolved** | Research found *none* of the four standard models, alone or combined, was built to serve true beginners well (Fiverr's catalogue = invisible new sellers; Upwork's jobs = costly proposals; Toptal's matching = excludes beginners by design). The closest fit to the evidence: **manual, human-run matching** for the wedge — not an algorithm, not open browse-and-bid. Revisit the standard models once liquidity exists. |
| **Exact verification mechanics** | Open | 🟣 **Answered directly — see §2** | University affiliation, verified manually, plus real delivered work — not a skills test. |
| **Exact progression levels / scoring** | Open | 🔴 **Stays open, deliberately** | Don't design this yet. No evidence exists either way for this specific product; premature scoring design risks locking in the same public-ranking friction flagged above. |
| **Skill assessment design** | Open | 🟠 **Deprioritized, not answered** | Don't build one for the wedge. If built later, the one rigorous study found (Kässi & Lehdonvirta) says it needs to be *hard/selective* to help true beginners — an easy test actively fails to help the population it's meant to serve. |
| **Category taxonomy** | Open | 🟣 **Narrowed for launch** | Research's own category matrix (its §9) points to graphic design or short-form video editing as the strongest combination of real growing demand + accessible skill barrier. Writing is in measured decline (-32% YoY on Upwork, 2025); web dev carries the same demand-fragility risk that killed Andela's junior-dev program. |
| **Payment provider / regulated structure** | Open | 🟣 **Narrowed for launch** | Bank-transfer-native, not card-based — matches how Nigerian buyers and students already transact and avoids card-network fees King Domain won't see anyway. A flat-fee-capped escrow model (like EscrowPay's) fits small transactions better than a %-based one. Partner with an existing provider for the wedge; do not build custom payment rails yet. |
| **Dispute rules** | Open | 🟣 **Narrowed for launch** | Needs to be cheap and fast at small dollar amounts — Upwork's own arbitration can cost more than the disputed amount on a small job. A flat, low-cost, human-reviewed process (EscrowPay's "an agent reviews evidence within two hours") fits the wedge's transaction size much better than a formal arbitration system. |
| **Monetization mix** | Open | ✅ **Stays open** | Correctly still undecided. Don't lock this before the wedge proves real transaction volume exists. |
| **Growth / acquisition engine** | Open | 🟠 **Partially answered** | Campus helps find students (supply). It does not, on its own, solve finding buyers (demand). A real acquisition plan needs an explicit demand-side answer, not an assumption that supply density creates it. |
| **Brand / name / visual identity** | Open, not in vision doc | N/A | Brand v0 already exists (`CLAUDE.md`) — unaffected by any of this. |

---

# §2 What to build first (the wedge, made concrete)

This is the direct translation of the research's §19 "Initial Wedge" into what already
exists in `king-domain-mobile` today, so this is additive work, not a rewrite.

**Already built and correct to keep as-is:**
- Onboarding flow (Welcome → Sign Up → Login → Verify Email)
- `TalentProfile` + `ProofItem` model, with the human-verification gate already in
  place (`isVerifiedIn()` — a student can't apply in a category until a human has
  verified proof in it). **This is already the right verification mechanism per the
  research** — real proof, human-reviewed, not a platform-administered test.
- Job feed / detail / apply flow, backed by the `Job` model

**What to narrow, not remove:**
- The mock job catalog currently spans four categories (Design, Software, Writing,
  Marketing). For the wedge, pick **one** — design or short-form video editing, per the
  research's category matrix — and treat the rest as "coming later," not deleted.

**What's missing and is the actual next build:**
- A **contract/escrow status flow** bolted onto the existing Apply → Accepted step:
  `Funded → In Progress → Submitted → Approved`, using the `openPending`/`settled`
  tokens already in `AppColors`. Plain language, not a fintech-vault aesthetic: "This
  job is funded. You'll be paid once the client approves your delivery."
- A **deliverable submission screen**, reusing the interaction pattern already built in
  `proof_upload_screen.dart`.
- **No custom payment/escrow backend for the wedge.** The first 5–10 real transactions
  should run through manual matching and an existing/partnered escrow tool — this
  directly tests the research's "transaction test" (§20 of the research doc) without
  committing engineering time to payment infrastructure before knowing if it's needed.

**Explicitly not building yet** (per §1 above): a second/third category, public
reputation or rankings, platform-administered skill assessments, algorithmic matching,
or a campus-exclusive gate on signup.

---

# §3 Answering the specific question you asked: what's actually new/differentiated for the profile/KYC step?

The research's clearest, most actionable finding on this: buyers' real fear is
**deception** (fake portfolios, someone else doing the work, fabricated credentials) —
not inexperience. 🟢 That reframes what "proof of skill" needs to defend against, and
it points to something genuinely differentiated King Domain can build that Fiverr,
Upwork, Freelancer.com, Contra, and Toptal structurally cannot, because none of them are
student-specific:

1. **University-verified identity tied to real enrollment**, not just an `.edu`-style
   email check — the trust anchor Handshake already exploits at scale in the US
   (reaching $1.1B annualized revenue off exactly this owned relationship). King Domain
   doesn't have Handshake's pre-existing verified base, so this needs to be a genuine,
   deliberate verification step, not a checkbox.
2. **Process-based proof, not static portfolio images** — a short recorded work-in-
   progress checkpoint or timestamped delivery step for real jobs, which directly
   defends against both "someone else did this" and AI-fabricated portfolios (the
   Bureau of Investigative Journalism found real Fiverr listings using AI-generated
   headshots impersonating named professionals — a static image proves nothing anymore).
3. **A named human accountable per verification** — already partially true in the app
   today (`ProofItem.status` goes `pending → verified` via human review before a
   student can apply in that category). This is a real, working anti-fraud mechanism
   most competitors don't have. Worth making more visible in the product ("Verified by
   [reviewer/program name]"), not just a backend gate.

This is a real, buildable, differentiated answer — and it's squarely inside "build the
trust layer first," not a departure from the research.

---

# §4 Open questions this doc deliberately does not answer

Per the vision doc's own instruction not to lock decisions prematurely, and the
research's instruction not to manufacture false certainty:

- Exact payment/escrow partner for Nigeria (bank-transfer-native, flat-fee-capped) —
  needs direct evaluation, not assumed from research alone.
- Whether design or short-form video is the better first category — both are
  defensible from the research; this is a real decision to make, not derive.
- How buyers for the first 5–10 manual transactions get found at all — campus supply-
  side recruiting is easier than demand-side buyer acquisition, and this doc does not
  pretend to have solved that.
- Whether "King Domain" leads with the payment-protection framing publicly, or keeps
  the fuller "professional reputation" vision as the public pitch while the escrow
  mechanism is what's actually tested first internally.
