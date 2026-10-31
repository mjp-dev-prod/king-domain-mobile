# Verifying proof of work, and the start proof (research, 2026-10-30)

**Why:** Victor, 2026-10-30: verification must follow a protocol "so it's not just random people that think
your work is cute so you are qualified". Decision D2 (job types doc §9) adds a second use of the same
idea: a **start proof** that unlocks an early share of a held payment. This is PRD research topic 2. It
proposes; decisions are listed in §10.

Tags: 🟢 fact (named source) · 🔵 observed (this codebase) · 🟣 synthesis · 🟡 hypothesis · 🔴 unknown.

## 1. Short answer

🟣 Verification becomes a defined protocol with three questions answered separately, each by the right
person:

1. **Is this person who they say they are?** (identity, a separate PRD topic)
2. **Did they really make this work?** (authenticity: a checker, using evidence a thief can't produce)
3. **Is the work good enough for paid jobs in this skill?** (quality: two reviewers who practise the skill,
   scoring against a written standard)

Then trust keeps growing from **real King Domain jobs**, which is the strongest signal there is. The same
"evidence a thief can't produce" idea defines the start proof.

## 2. What King Domain does today (🔵)

- A talent uploads **one file and a title** per category (`ProofItem`: category, title, filePath).
- One admin, in the admin dashboard, taps approve or reject (`proofReviewRoutes.js`). There is no standard
  to judge against, no second opinion, no authenticity check.
- **Rejecting deletes the item.** The reason goes by email only; in the app the proof just disappears.
- Status is two values: pending, verified. A verified category lets the talent apply in it.

## 3. What we already decided (keep, don't re-litigate)

From `docs/core/correction-proof-of-skill-screen.md` and `market-validation-2026-09-12.md` §10–11 (🟢):

- **No timed, platform-made test as a gate for everyone.** Upwork killed its skill tests in 2020 because
  clients ignored the scores and they were easy to pass without real skill. Real work is reviewed, not a
  synthetic task.
- **Trust signals, strongest first:** completed work with reviews → badges earned by delivering real
  work → verifiable portfolio with live links → recognised third-party credentials → platform tests.
- **Certificates help beginners only if they are hard to get** (Kässi & Lehdonvirta, OECD 2019).
- **Badges help unproven sellers most:** eBay's Top Rated badge lifted sales 45% more for sellers at the
  25th reputation percentile than at the 75th (Elfenbein, Fisman & McManus, NBER).
- **AI makes fake portfolios cheap**; the countermeasure practitioners converge on is live, unscripted
  explanation of one's own work.
- **Public rankings backfire** for a meaningful minority; prefer facts over scores.
- Left open then: what a beginner with no work at all does. §7 answers it.

## 4. What serious vetters do (🟢)

- **Toptal:** language and personality interview, skill assessment, **live screening by an expert in the
  same field**, a **1–3 week test project**, then ongoing performance. About 3% pass. A candidate who failed
  the live stage was allowed to retry after a month.
- **Fiverr vetted-only categories:** portfolio link required, reviews with files, and a **required video**
  with a short bio and a walk-through of a project they completed; review takes up to 4 weeks; reapply
  after 6 months; status is re-evaluated continuously and can be lost.
- **Fiverr Pro:** "industry experts evaluate every freelancer"; applicants describe their creative process
  and tools; Pro status is kept only with on-time delivery, communication and ratings.

## 5. How to tell the work is really theirs (🟢)

Hiring guides for creative work agree (foundmaker, Zinn Hub, iCreatives, TD Games, Mediabistro):

- **Authorship shows in the process, not the screenshots.** Ask for the **working files** (layers, Figma,
  the editing project, version history): "Anyone who made a piece can show you its layers, its repository
  or its draft history."
- **Reverse image search** two pieces; stolen portfolios are usually lifted wholesale from one source.
- **Ask something only the author could answer** ("what was hardest, what did you try first?"). Real
  memories get richer under a follow-up; fabrications get thinner. People using others' work avoid a call.
- **Ask what their role was** on team work; vagueness is the signal, not the team work itself.
- **A real case:** a "video editor" applied for a job with another editor's podcast edits; he was caught
  only because the HR team showed the portfolio to someone who appeared in the videos (LinkedIn, 2026).

**AI detection is not a verdict** (🟢): detectors' reliability "decays sharply" in the wild; one study
found the best models detect AI content about two-thirds of the time (CJR 2025; CREST). **Content
Credentials (C2PA)** are signed provenance data from cameras and tools like Adobe, and are worth reading
when present, but screenshots and reposting strip them and adoption is early. 🟣 So check the person and
the process, not the pixels.

## 6. How reliable expert judgement is (🟢)

- In a three-year study of digital art portfolios, three assessors marking the same work with a rubric
  agreed poorly (average correlation **0.46**), but their **combined** scores were highly reliable
  (Cronbach's alpha **0.94**). Pairwise comparison by several judges was more reliable still (0.96).
- Reliability depended on **assessor experience**; inexperienced assessors produced the inconsistent
  judgements. Shared criteria agreed in advance, and **moderation meetings** to discuss disagreements,
  improved it (Newhouse & Tarricone 2014, 2017).
- Rubrics only built sound judgement when assessors took part in **designing the rubric and the
  moderation** (Menéndez Varela & Gregori Giralt).

🟣 So: never one reviewer; reviewers who practise the skill; a written standard per skill with example
submissions at the bar; a third opinion when two disagree; regular calibration.

## 7. The proposed protocol (🟣, for the PRD)

### 7.1 What gets verified
Verification is **per skill**, not per broad category: "Short-form video editing", not "Video". A skill has
a written **standard**: what work at the bar looks like, the rubric, example submissions that pass and fail.

### 7.2 Three routes in (no dead end for anyone)
- **A. I have real work.** Submit an evidence pack (7.3).
- **B. I trained with King Domain.** A trainer attests that the final project was made in class under
  observation (Balogun's camps), and it goes to the same two reviewers. Observed work answers "did they
  make it" better than anything else.
- **C. I have nothing yet.** The app doesn't stop here. It offers the next training cohort, and a **practice
  brief**: a realistic brief from a library, done in the app with drafts saved as it goes, untimed, reviewed
  like real work. This is a route for people with nothing to show, never a gate for people with real work.
  (It departs from the September correction's "don't invent a task"; see decision 2.)

### 7.3 The evidence pack (route A)
1. **Two or three real pieces** in the skill. Per piece: the brief, their role (alone, or which part in a
   team), the date, the client if they can name one, a live link if it exists.
2. **Working files for at least one piece**, in the form the skill uses: layered PSD/AI or a Figma link;
   the editing project's timeline (Premiere, CapCut, DaVinci); a document's version history; a code
   repository with its history.
3. **Drafts or work in progress** for at least one piece.
4. **A 2–3 minute walkthrough video**, face visible, explaining one piece: what was asked, what they tried,
   what changed and why (the Fiverr vetted-category requirement, and the practitioners' unscripted check).
5. A **declaration** that the work is theirs, and which AI tools they used, if any.

### 7.4 Authenticity check (a trained checker, not the reviewers)
- Face in the walkthrough matches the identity check on the account.
- Reverse image search on two pieces; live links opened; credits looked for.
- Working files exist and match the finished piece.
- Content Credentials read where present; AI detectors never used as a verdict.
- Optional **follow-up question** about the work, answered by short video or text, when anything is
  unclear.
- Outcome: passes to quality review, or stops with a reason. Stolen work suspends the account.

### 7.5 Quality review (two reviewers who practise the skill)
- Each scores **independently** against the skill's rubric, without seeing the other's score.
- Agree → result. Disagree → a third reviewer decides, and the case goes into the next calibration session.
- Reviewers are recruited from vetted practitioners and King Domain trainers; each passes a **calibration
  set** before reviewing and is re-calibrated regularly. Their agreement rate is tracked.
- A reviewer never reviews someone they know or someone from their own school.
- Draft rubric for short-form video editing, to be finished with practitioners (🟡): structure and story;
  pacing and rhythm; sound (levels, music, clean dialogue); picture (colour consistency, framing);
  captions and titles; fit to the brief; export quality.

### 7.6 Outcomes, always shown in the app
- **Verified** in the skill, with the date and what was checked.
- **Not yet**, with the reason per rubric line and what to do next (which part to strengthen, the next
  training cohort, a practice brief), and when they can resubmit.
- **Removed** for misconduct (stolen work, fake identity), with the reason and how to appeal.
- The submission is kept, never silently deleted: the talent can always see what they sent and what was
  said.

### 7.7 After verification: levels earned by real work
- **Verified**: passed the protocol. Can apply in that skill.
- **Proven**: earned by completed, approved King Domain jobs in the skill (number and conditions to set
  with the reputation topic). Outcome-earned badges are the second-strongest signal in §3.
- Shown as **facts, not scores** ("Verified 12 Nov by 2 video editors · 4 jobs completed"), no public rank.
- Re-check when the signal goes bad (repeated disputes or failed deliveries in the skill).
- **Portable:** verified skills and completed jobs can be issued as **Open Badges 3.0** credentials
  (W3C Verifiable Credentials: the talent keeps them in a wallet, shares them anywhere, and anyone can check
  they came from King Domain untampered). This is the "reputation that outlasts graduation" in a standard
  form.

### 7.8 What the client sees
A "How this talent was checked" panel on every applicant and profile: identity checked, student checked
(separate topic), each verified skill with the date, the two-reviewer check and what evidence was examined,
jobs completed and delivered on time.

## 8. The start proof (decision D2, made concrete)

**Idea:** the early money is earned by showing real work has started, in a fixed format per skill. 🟢 One
hiring guide puts it exactly: "Keep the first payment small and the first checkpoint early… An impostor
cannot produce the checkpoint; a real maker produces it without thinking about it" (foundmaker).

**Formats, from the stages each trade already uses** (video stages: 🟢 Frame.io, Addaly; others 🟡 to
confirm with practitioners):

| Skill | Start proof | Why this stage |
|---|---|---|
| Video editing | Rough cut (or assembly for long pieces) of the first piece, plus a screenshot of the project timeline. For a batch of reels: the first reel's rough cut. | The industry's first review round is "structure only: music temporary, colour flat". |
| Graphic design | Two or three concept directions (sketches or rough digital) and a moodboard. | The first client checkpoint in a design project. |
| Social media (monthly) | The month's content calendar and the first week's posts drafted. | The plan the whole month runs on. |
| Writing | Outline and the first section. | Structure agreed before the bulk is written. |
| Web / development | Wireframes or sitemap, plus the repository with first commits or a staging link. | Structure and a working base. |
| Hourly work | None: paid weekly anyway. | |

**Mechanics (proposed):**
- Applies to one-delivery jobs and to the first milestone of a milestone job.
- The talent uploads into **fixed fields** for that skill (not a free upload), so it is checked against a
  checklist, not judged for quality.
- The client has **24 hours** to accept it or say "this isn't a real start"; silence accepts. An objection
  goes to an admin, who checks it against the checklist.
- Accepted → the share is paid out. The start proof is kept as a dated version (also evidence of authorship).
- **The share:** proposed **20%**. Nigerian practice values a job at about 25% before the main work starts
  (a creator contract's kill fee: 25% before shooting, 50% after shooting, 75% after first draft; ugc.ng),
  and the guide above says keep the first payment small.
- **Risk to decide:** a talent takes the 20% and disappears. Mitigations: identity is verified, the start
  proof is real work the client keeps, abandoning a job is recorded and blocks further applications. What
  the client gets back in that case is a money rule (decision 4).

## 9. What this changes in the app (for the PRD's slice plan)

Proof becomes a submission with several pieces, files, a video and a declaration; a checker queue and a
reviewer queue in the admin dashboard; skill standards and rubrics as data; reviewer calibration; results
with reasons that stay visible to the talent; levels per skill; the client's "how this talent was checked"
panel; start-proof fields per skill on the contract; partial payouts on the contract.

## 10. Decisions for Victor

1. **The protocol:** evidence pack with a walkthrough video, an authenticity check, two practising reviewers
   against a written standard, reasons always shown in the app, levels Verified then Proven. Adopt?
2. **Beginners with nothing to show:** a practice brief (untimed, drafts saved, reviewed like real work) and
   the training route. This changes the September correction, which said not to invent a task. Your call.
3. **Who reviews, and are they paid?** Proposed: vetted practitioners and Balogun's trainers, paid per
   review. Paying reviewers is a money rule → ledger.
4. **Start proof:** 20% share, 24 hours for the client to object, and what the client gets back if a talent
   abandons the job after taking it. Money rule → ledger.
5. **Resubmitting after "Not yet":** Toptal waits a month, Fiverr six. Proposed: **14 days**, or straight
   away after completing a training cohort.

### Answered by Victor, 2026-10-30 (carry into the PRD as decisions)

- **D5. The protocol is adopted** (§7: evidence pack with walkthrough video, authenticity check, two
  reviewers, reasons shown in the app, Verified then Proven).
- **D6. No practice briefs.** King Domain can't write briefs for every skill the way a university would, so
  **real work is the way in**, reviewed by two people. Route C in §7.2 is dropped. "Real work" means work
  the person actually made: client work, but also their own projects, school work, or work done for a
  friend, church or campus event. A talent with nothing yet is told exactly what counts and pointed to
  training where it exists, so it is still not a dead end. Work made in a King Domain training camp is real
  work (route B) unless Victor says otherwise.
- **D7. Reviewers are the King Domain team for now**, working with an AI model that does the groundwork
  (the authenticity checklist, reverse image search, a first pass against the rubric) while people decide.
  Staff reviewers later. Note: two reviewers are still required, and where nobody on the team practises a
  skill, one of the two should be someone who does (§6: reviewer experience is what makes judgements
  reliable).
- **D8. Start proof: 20% share, 24 hours for the client to object.** What the client gets back if a talent
  abandons the job after taking it is **open**.
- **D9. No fixed waiting time; abuse is penalised instead.** A talent may resubmit after "Not yet" at any
  time. Reviewers see every past submission in that skill, so repeated work is visible. Before each
  submission the app shows the terms, which the talent must accept: sending back work already marked "Not
  yet" without the fixes asked for is penalised with **no submissions in that skill for 2 months**, then
  **3 months** if repeated; stolen or fake work leads to a **ban**. (The 2-then-3 ladder is our reading of
  Victor's "2 or 3 months"; confirm when writing the PRD.)

## 11. Unknowns (🔴)

- How many reviewers per skill launch needs, and their turnaround time: depends on sign-up volume.
- The rubrics themselves: need practitioners (the trainers) in a working session per skill.
- Whether clients in Nigeria read and value a "how this was checked" panel: test it with the companies
  Balogun mentioned.

## Sources

- Toptal, "Why 3%" and FAQ; Distributed.blog, "Inside Toptal's Distributed Screening Process" (2019);
  reederz.com, "I got hired by Toptal" (2016).
- Fiverr Help: "How to become a Fiverr Pro freelancer"; "Vetted-only categories for freelancers";
  "Creating and optimizing your Fiverr Pro Gig"; "How to find the right freelancers on Fiverr Pro".
- foundmaker, "How to be sure you're hiring the person who made the work"; Zinn Hub, "How to Review a
  Freelancer Portfolio Properly" (2026); iCreatives, "The 7-Step Portfolio Review Process" (2026); TD Games,
  "How to Verify a Vendor Actually Produced Its Portfolio Assets" (2026); Mediabistro, "How to Interview
  Designers"; zenweb.my (2026); Aryansh Kundra, LinkedIn post on portfolio theft (2026).
- Columbia Journalism Review, "Do AI Detection Tools Work?" (2025); CREST, "From Detection to Provenance";
  The Verge on C2PA (2024); Partnership on AI, Microsoft case study (2024); aicheck.app (2026).
- Newhouse, "Using digital portfolios for high-stakes assessment in visual arts", RPTEL (2014); Newhouse &
  Tarricone, "Using pairwise comparisons in the online social moderation of performance assessment" (2017);
  Tarricone & Newhouse, Educational Assessment (2017); Menéndez Varela & Gregori Giralt, "Rubrics for
  developing students' professional judgement".
- Frame.io Workflow Guide, "Editing stages"; Addaly, "The stages, and how long each really takes"; Storyflow
  (2026); PlayPause (2026); FileFeedback (2026).
- 1EdTech, Open Badges 3.0 specification and announcement (2024).
- ugc.ng, "UGC Contract Template for Nigerian Creators".
- Earlier evidence carried over: `docs/research/market-validation-2026-09-12.md` §10–11 and
  `docs/core/correction-proof-of-skill-screen.md`.
