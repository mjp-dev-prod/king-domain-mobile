# Discovery: how talents find work and clients find talent (research, 2026-10-30)

**Why:** Victor, 2026-10-30: "how will the browsing of jobs be". Discovery covers both directions: a talent
finding jobs, and a client finding talents, plus the ready-made packages decided in D4. PRD research topic 5.
It proposes; decisions are in §9.

Tags: 🟢 fact (named source) · 🔵 observed (this codebase) · 🟣 synthesis · 🟡 hypothesis · 🔴 unknown.

## 1. Short answer

🟣 Five ways to meet, none of which ranks people by a score:

1. **Talents browse jobs** in the skills they are verified in, with filters, saved searches and instant
   alerts, free for everyone.
2. **Clients post a job** and get applicants; a job stops taking applications at 50 applicants or after
   5 days, and the client reopens it in one tap if they want more.
3. **Clients browse talents** by skill, see real work first, and invite them to a job.
4. **Clients buy a ready-made package** a talent has published.
5. **Clients ask King Domain to find someone**: the team sends a shortlist. This is how the companies
   Balogun mentioned get served well from day one, before the marketplace is busy.

## 2. What King Domain has today (🔵)

- One job feed: search by words, sort by newest, budget or delivery time, a "can apply" switch
  (`feed_filter.dart`). All filtering happens on the phone over every job.
- Six broad categories (`skill_categories.dart`): Software & tech, Design & creative, Writing & content,
  Marketing & growth, Tutoring & training, Video & media. Verification is per category.
- Clients can only post a job and wait. No talent browsing, no invitations, no packages, no alerts, no
  limit on applicants.

## 3. What we already decided (keep)

From `docs/core/correction-talent-discovery-screen.md` (Victor, September): **no composite score, no "top
candidate" badge, no ranking of people.** Show real facts (verified status, a real work thumbnail, a plain
count of completed jobs, the reviewer's note) and let the client weigh them. A newly verified talent with
no jobs must be visibly discoverable, "not pushed to the bottom of an implied ranking". Proof-verification
D5 and the education line (D15) add to the facts shown.

## 4. Why newcomers must be seen (🟢)

- **Pallais (American Economic Review, 2014)** randomly hired 952 inexperienced workers on oDesk (now
  Upwork). Getting one job roughly **tripled their earnings in the next two months**; a **detailed,
  objective evaluation** (speed, accuracy, following instructions, on time) raised earnings further. Clients
  hire too few beginners because the first hire creates information everyone else benefits from. 🟣 So the
  platform should actively help a verified beginner get the first job, and the first review should be
  specific, not just stars (feeds the reputation topic).
- Badges help low-reputation sellers most (Elfenbein et al., cited in the September research).

## 5. Too many applications hurt everyone (🟢)

- On the same platform, **the top 25% of jobs got 75% of all applications** while the bottom 25% got 0.4%;
  clients with 30+ applications **opened fewer than half** of them (Horton, Vasserman & Watt).
- A field experiment on 45,742 jobs closed a job to new applicants **at 50 applicants or after 5 days**,
  with a one-click reopen for the client. Applications fell 11% (by 20 at the busiest jobs), **hiring stayed
  at 41% and quality did not drop**; only 7% of clients reopened. Applicants saved effort they could spend on
  jobs where they had a real chance.
- **Upwork charges talents to apply** ("Connects", $0.15 each, varying per job) and sells a paid boost to
  the top of a client's list. 🟣 King Domain's rule that a talent never pays anyone (client trust D-rules)
  rules both out; the soft cap does the anti-spam job without charging students.

## 6. How the others connect clients and talent (🟢)

- **Upwork:** job posts can be public or private (invite-only); clients search talent with filters (skills,
  rate, location, badges, people hired before) and **invite** them to a job; saved talent lists; instant job
  alerts (paid plan only), based on jobs the freelancer applied to before.
- **Fiverr:** a catalog of priced packages; **Briefs**: the client writes a brief (with AI help), Fiverr
  sends it to a few matching freelancers, each has **72 hours** to answer, and the client gets **up to five
  tailored offers**. Fiverr Pro adds shortlisting by a human and paid sourcing by domain experts. Fiverr
  standardises the package fields in some categories so offers can be compared.
- **Toptal:** a human matcher proposes candidates within 24–48 hours instead of a search.
- The September research recommended **human-run matching** while the marketplace is small
  (`market-validation-2026-09-12.md` §13).

## 7. Proposal (🟣, for the PRD)

### 7.1 Skills, not just categories
Verification is per skill (proof-verification §7.1), so the six categories become groups of skills, e.g.
Video & media → short-form video editing, long-form video editing, motion graphics, voice-over. Every skill
has its standard, rubric and start-proof format. Which skills open at launch is decision 5.

### 7.2 Talents finding work
- **Jobs for you**: jobs in the skills they are verified in, newest first; other skills shown with what it
  takes to get verified in them.
- **Filters**: skill, job type (one delivery, milestones, monthly, hourly), budget, delivery time, verified
  client, local or international (money topic), and "few applicants yet".
- **Saved searches and instant alerts** (push) for everyone, free.
- **Invitations** tab: jobs a client invited them to, with a deadline to respond.
- **Each job card**: title, skill, job type, budget in gold, delivery time, how many have applied out of
  50, the client's track-record summary (D19), when it was posted.
- **Applying**: a short answer to the brief, the 1–3 most relevant pieces of verified work chosen from their
  profile, and any answers to the client's screening questions. Price: decision 2.
- **No dead ends**: no jobs in their skills → set an alert, publish a package, add a second skill, see when
  similar jobs were last posted.

### 7.3 Clients finding talent
- **Post a job**, public or invite-only. Applications stop at **50 or after 5 days**; the client sees
  "Applications paused. Reopen?" and reopens in one tap.
- **Browse talents** by skill. Each card: photo, a thumbnail of real work, verified skills with dates, the
  education line, completed jobs as a plain count, availability, usual response time, package prices if
  any. **Order: recently active first**, never a score; filters for education line, availability, has
  completed jobs, price range. A newly verified talent is labelled "New on King Domain" as a fact, not
  sorted down.
- **Invite to a job**, up to 20 invitations per job, each valid 72 hours.
- **Applicants list**: in the order they applied, every applicant on equal footing, with the checks panel,
  chosen work, answers, and the client's own shortlist and decline actions (declined applicants are told).
- **Saved talents and hire again.**

### 7.4 Ready-made packages (D4)
- A talent publishes up to three tiers for a verified skill, using the **standard fields for that skill**
  (what's included, quantity, formats, revisions, delivery time, price), so packages are comparable.
- Packages can be one delivery or monthly (job types D1, D3).
- The client buys a package, fills in the skill's brief form, funds it, and it becomes a contract with the
  usual protections and start proof.
- Packages are browsed by skill, priced in gold, ordered by recently active like talents.

### 7.5 "Find someone for me" (King Domain shortlist)
- The client describes the need (the same structured brief); the team, helped by an AI model, sends a
  shortlist of 3–5 verified talents with a line on why each fits; the talents are asked first and only
  available ones are sent.
- A promised response time, shown to the client.
- This serves the companies Balogun is bringing from day one, while job and talent volumes are still low.

### 7.6 Helping beginners get the first job (Pallais)
- "New on King Domain" is shown as a plain fact on cards, never as a penalty.
- The shortlist service deliberately includes a verified newcomer where one fits.
- The first review is specific (on time, followed the brief, quality), designed in the reputation topic.

## 8. What this changes in the app

A skill taxonomy under the six categories; a server-side job feed with filters and paging (today all jobs
are filtered on the phone); saved searches and alerts; the soft cap and reopen; talent browsing and
profiles for clients; invitations; packages; the shortlist request and its admin queue; applicant
management (shortlist, decline with notice).

## 9. Decisions for Victor

1. **Soft cap**: a job stops taking applications at 50 applicants or after 5 days; the client reopens in
   one tap. Adopt?
2. **Price**: the client sets the budget and talents apply at that price (no bidding each other down, which
   the September research found beginners do to get a first review), or talents may propose a different
   price?
3. **Talent browsing order for clients**: recently active first, no score, newcomers labelled as new.
   Adopt?
4. **"Find someone for me"**: the team (with an AI model) sends clients a shortlist of 3–5 verified talents.
   Adopt, and is there a promised response time (e.g. within 24 hours)?
5. **Which skills open at launch?** Each needs a standard, rubric, start-proof format and reviewers who
   practise it. Proposed first set, matching the start-proof formats already drafted: graphic design,
   short-form video editing, social media management, writing, web development. Add or remove?

### Answered by Victor, 2026-10-30 (carry into the PRD as decisions)

- **D21. Soft cap adopted** (50 applicants or 5 days). Victor: getting more applicants beyond the cap
  "should be a premium benefit". Our reading: reopening a paused job is a paid client feature. Pricing and
  what else is premium belong to the money topic and the ledger (monetisation is an open decision).
- **D22. The client sets the price**; talents apply at that budget, no bidding.
- **D23. Talents ordered by recently active, no score**, newcomers labelled as new, plus a **region**
  filter (state and city for Nigeria, country for international), which means the profile records the
  talent's region.
- **D24. "Find someone for me" adopted, with a promised response time computed from real data**, and
  response-time stats that talents can see and understand:
  - *King Domain's promise:* shown as "usually within N hours", where N is the 90th percentile of the
    delivery times of the last 20 shortlists, so the promise is kept 9 times in 10; outside the team's
    working hours the screen shows the actual time the clock starts.
  - *A talent's response time:* the median time from a client's first message or invitation to the talent's
    first reply, over the last 30 days; shown in buckets (within an hour, within a few hours, within a day,
    more than a day) and only after at least 3 conversations. The talent sees their own figure, how it is
    calculated and why clients weigh it, on their profile screen.
- **D25. Launch skills:** graphic design, short-form video editing, social media management, writing, web
  development. More skills are added later, each with its own standard, rubric, start proof and reviewers.

## 10. Unknowns (🔴)

- How many jobs and talents exist at launch: the shortlist service carries discovery until volume grows.
- Whether Nigerian clients prefer posting jobs or buying packages: watch both.

## Sources

- Pallais, "Inefficient Hiring in Entry-Level Labor Markets", American Economic Review 104(11) (2014); NBER
  w18917.
- Horton, Vasserman & Watt, "Reducing Congestion in Labor Markets: A Case Study in Simple Market Design";
  Horton, "Job-Seekers Send Too Many Applications" (autopause experiment) and NBER slides.
- Upwork Help: "Understanding and using Connects"; "How to boost your proposal"; "How to become a Rising
  Talent"; "How to submit a proposal"; "Send invites"; "Search for talent"; "How to get instant job alerts";
  "Fill an Enterprise job"; "Uma Recruiter for freelancers"; Upwork resources, "How to Get Noticed and Win
  Jobs as a New Freelancer".
- Fiverr Help: "Post a project brief: get tailored offers"; "Personalized offers (Briefs) for freelancers";
  "Submitting a brief to connect with a freelancer"; "Creating and managing Gig packages" (standardised
  categories).
- Earlier: `docs/core/correction-talent-discovery-screen.md`; `docs/research/market-validation-2026-09-12.md`
  §5, §13.
