# Reviews and reputation (research, 2026-10-30)

**Why:** The vision's promise is "a reputation that outlasts graduation". Clients need honest signals about
talents, talents need honest signals about clients (D19), and beginners need their first jobs to count
(Pallais, discovery §4). PRD research topic 7. It proposes; decisions are in §8.

Tags: 🟢 fact (named source) · 🔵 observed (this codebase) · 🟣 synthesis · 🟡 hypothesis · 🔴 unknown.

## 1. Short answer

🟣 Star averages don't work: they inflate until nearly everyone has five stars, and people rate kindly in
public for fear of retaliation. So King Domain records **facts the system can measure** (on time, change
rounds, response time), asks clients **specific questions** instead of stars, hides both reviews **until
both sides have written theirs**, and asks one **private** question that only King Domain sees. Profiles
show plain counts, never an average or a rank.

## 2. What King Domain has today (🔵)

Nothing: no reviews either way, no work history on profiles, no levels beyond "verified in a category".

## 3. What we already decided (keep)

- No composite score, no ranking of people, no "top candidate" (`correction-talent-discovery-screen.md`).
- Levels as facts: **Verified**, then **Proven** earned through real King Domain jobs (proof-verification
  §7.7, D5). Verified skills and completed jobs can be issued as portable Open Badges.
- Client track record shown to talents, including ratings from talents (D19).

## 4. What the research shows (🟢)

- **Ratings inflate until they say nothing.** On a large online labour market the share of workers getting
  a perfect 5 stars went from **33% to 85% in six years**; more than half the rise was raters lowering their
  standards, not better work. **28.4% of clients who privately said they would definitely not rehire a
  worker still gave them 4 or more stars publicly**; the reverse almost never happened. Private feedback
  scores fell while public ones rose (Filippas, Horton & Golden, Marketing Science 2022).
- **Hiding reviews until both sides submit reduces retaliation.** In an Airbnb experiment, reviews hidden
  until both had reviewed (or 14 days passed), and locked after, raised review rates (hosts +9.8%), cut the
  correlation between guest and host ratings by 48% (less tit-for-tat), and made ratings slightly more
  honest (Fradkin, Grewal & Holtz, Marketing Science 2021).
- **Detailed, objective evaluations help good beginners.** In Pallais's experiment, a comment with objective
  facts (speed, accuracy, following instructions, on time) raised workers' later earnings beyond a generic
  positive comment; it helped those who did well and hurt those who did badly (AER 2014).
- **Early mistakes matter less than having a history at all**: 1–2 negatives on a new eBay identity had no
  significant effect (Resnick & Zeckhauser 2006); Upwork recalculates its Job Success Score on a rolling
  basis so early mistakes fade (September research §11).
- **Public comparison backfires for a meaningful minority**, and people protect a public score dishonestly
  (September research §11).

## 5. Proposal (🟣, for the PRD)

### 5.1 Facts the system records itself
For every job, measured from timestamps, not opinions: start proof on time, delivered by the deadline (and
extensions used), change rounds used, response time, completed or cancelled, any dispute and how it ended.
These can't be inflated or bargained over.

### 5.2 The client's review of the talent
Asked after approval and payout, within 14 days:
- **Followed the brief?** Yes / partly / no.
- **Quality met what was agreed?** Yes / partly / no.
- **Communicated well?** Yes / partly / no.
- **Would you recommend them?** Yes / no.
- A written comment, with prompts that ask for specifics ("what did they do well, what could be better?").

### 5.3 The talent's review of the client
Same window: **brief was clear**, **feedback was clear and on time**, **paid and approved fairly**,
**would work with them again**, plus a comment. Feeds the client track record (D19).

### 5.4 Hidden until both are in, then locked
Neither side sees the other's review until both have submitted or 14 days pass; after that, reviews can't be
edited. Each side may post **one public reply** to the review about them.

### 5.5 One private question
Both sides also answer, privately: **"Would you work with this person again?"** Only King Domain sees it.
It is used for quality checks (re-checking a skill when the signal goes bad, proof-verification §7.7),
for the Proven level, and for the "find someone for me" shortlist. Never shown, never traceable to the
rater.

### 5.6 What profiles show
Plain counts and recent first: "6 jobs in short-form video · 6 on time · 5 of 6 clients would recommend",
the review comments, the facts per job, and the talent's replies. No star average, no rank, no leaderboard.
The last 12 months lead, the full history is a tap away, so early mistakes fade without being erased.

### 5.7 Proven level (per skill)
Proposed: **3 completed jobs in the skill**, none lost in a dispute, delivered on time (extensions granted
by the client count as on time), and every client said they would recommend. Lost if the signal turns bad
(two lost disputes, or repeated private "no" answers), which triggers a re-check.

### 5.8 Reviews that break the rules
Removed only for: threats or abuse, personal information, content unrelated to the work, or using a review
as leverage ("five stars if you do extra work free" or "a bad review unless you refund"). Leverage is
reportable in the conversation. Disagreement with an honest review is not grounds for removal; the reply is.

### 5.9 Portable
Completed jobs and Proven levels are added to the talent's portable record (Open Badges 3.0, proof
verification §7.7), so the reputation leaves with them.

## 6. What this changes in the app

Review screens for both sides after each job, reminders, the hidden-then-revealed logic, the private
question, profile sections for history and reviews, replies, the Proven calculation per skill, the report
flow for reviews, and the client track record fed by talents' reviews.

## 7. Unknowns (🔴)

- Whether clients in Nigeria fill in reviews without a nudge: measure the review rate and adjust reminders.

## 8. Decisions for Victor

1. **No star averages**: specific yes/partly/no questions, a recommendation, system-measured facts, and
   plain counts on profiles. Adopt?
2. **Reviews hidden until both sides submit (or 14 days), then locked**, with one public reply each?
3. **A private "would you work with them again?"** that only King Domain sees, used for quality checks,
   Proven and shortlists?
4. **Proven level**: 3 completed jobs in the skill, none lost in a dispute, on time, all clients
   recommending. Right numbers?

### Answered by Victor, 2026-10-30 (carry into the PRD as decisions)

- **D29.** No star averages: specific yes/partly/no questions, a recommendation, system-measured facts,
  plain counts on profiles.
- **D30.** Reviews hidden until both sides submit (or 14 days), then locked; one public reply each.
- **D31.** A private "would you work with them again?" seen only by King Domain, used for quality checks,
  Proven and shortlists.
- **D32.** Proven level per skill: 3 completed jobs in the skill, none lost in a dispute, on time, every
  client recommending.

## Sources

- Filippas, Horton & Golden, "Reputation Inflation", Marketing Science (2022); NBER w25857.
- Fradkin, Grewal & Holtz, "Reciprocity and Unveiling in Two-Sided Reputation Systems: Evidence from an
  Experiment on Airbnb", Marketing Science (2021).
- Pallais, "Inefficient Hiring in Entry-Level Labor Markets", AER (2014).
- Earlier: `docs/research/market-validation-2026-09-12.md` §11 (Resnick & Zeckhauser; Upwork JSS; social
  image loss aversion; Niederle & Vesterlund); `docs/core/correction-talent-discovery-screen.md`.
