# Training camps: from learning a skill to the first paid job (research, 2026-10-31)

**Why:** At the 24 Oct meeting Balogun described in-person video-editing training he already runs: more than
100 people signed up without advertising, some can't afford transport to class, and the plan is to "train
people for what we want them to do" and then bring them onto the platform. Victor, 2026-10-30: the training
camps are part of the plan. PRD research topic 10. It proposes; decisions are in §7.

Tags: 🟢 fact (named source) · 🔵 observed (this codebase or the meeting) · 🟣 synthesis · 🟡 hypothesis ·
🔴 unknown.

## 1. Short answer

🟣 Training belongs inside the app, run as **cohorts with deadlines** (in person and online side by side,
so transport is not the barrier), ending in a **final project made under a trainer's eye** that counts as
verified proof, and followed by a **first paid job** reserved for graduates. The one thing that kills
training programmes is graduates nobody hires; the evidence below is mostly about that.

## 2. What exists (🔵)

- Balogun's in-person classes (Lagos); demand without advertising; transport cost already stops some
  students (24 Oct meeting).
- Already decided: work made in a King Domain camp is real work, attested by the trainer (route B, D6); the
  education line includes "Trained · King Domain camp" (D15); the shortlist service deliberately includes
  verified newcomers (discovery §7.6).
- Nothing in the app for training today.

## 3. What happens when training isn't tied to jobs (🟢)

- **Andela** paid about **$20,000 to train one developer over six months**, then placed them with clients.
  By 2019 clients wanted experienced engineers; junior developers "could sit in the office for months and
  not go out in the field". Andela closed its training programmes in Nigeria, Kenya and Uganda and let go of
  about **420 junior developers** (Quartz, BusinessDay, Techpoint 2019; Rest of World 2021; IFC case study).
- **A first job is what unlocks the rest**: getting one job tripled inexperienced workers' earnings in the
  next two months, and a specific evaluation raised them further (Pallais, AER 2014; discovery §4).
- 🟣 So graduates need real demand waiting for them, and the training should follow the skills clients are
  actually posting jobs in.

## 4. What makes people finish (🟢)

- Self-paced online courses: about **20%** completion on average (Kizilcec & Halawa, cited by SuaCode).
- **SuaCode Africa**, a smartphone-based coding course for Africans (mostly Nigeria and Ghana): **72%** of
  admitted students finished, with **fixed release dates and hard deadlines**, facilitators answering
  questions, materials **available offline**, and students forming their own WhatsApp support groups. Entry
  required submitting the first assignments (a commitment filter).
- **Keeping up with deadlines in the first two weeks almost doubles** the chance of finishing; taking part in
  discussion raises it by over 25% (Coursera, "Drivers of Quality in Online Learning").
- A **study plan plus weekly SMS reminders** raised completion by 15 percentage points among learners who made
  a plan (Behavioural Insights Team, Bangladesh).

## 5. Proposal (🟣, for the PRD)

### 5.1 Training in the app
- **Cohorts**, per launch skill (D25): dates, schedule, in person (where) and/or online, seats, cost
  (decision 3), the trainer.
- **Apply and commit**: the first assignment is part of applying, as SuaCode did, so seats go to people who
  will finish.
- **The cohort page**: sessions, assignments with deadlines, materials downloadable for offline use (data
  costs), a cohort conversation in the app (the messaging design, so records and safety rules apply),
  weekly progress reminders by push and SMS.
- **Trainer feedback** on each assignment, written against the same skill standard the reviewers use.

### 5.2 Hybrid, so transport is not the barrier
Every cohort runs online alongside the in-person class, with the same deadlines and the same final project.
Students who can come to class do; those who can't still finish.

### 5.3 From training to verified
The final project is made during the cohort, with its drafts and working files saved in the app; the trainer
attests it was made in class; it then goes to the two reviewers like any proof (route B). Passing gives
**Verified** in the skill and the "Trained · King Domain camp · cohort" line.

### 5.4 From verified to the first paid job
- **Demand first**: cohorts open in skills where clients are posting jobs; companies can **sponsor a cohort**
  and get first sight of its graduates.
- **A first-job track**: small real jobs from partner companies (the ones Balogun mentioned) reserved for
  new graduates, each with a mentor who looks over the work before it is delivered. The client gets a
  checked delivery; the graduate gets a first completed job and a specific first review (D29).
- Graduates also go into the shortlist service as verified newcomers.

### 5.5 Honest numbers
Each cohort's results are recorded and shown to the team (and, once there is enough data, publicly):
how many finished, how many were verified, how many got a first paid job within 60 days, and what they
earned in their first three months. These decide which cohorts run next.

### 5.6 The scam overlap
"Pay for training and we'll give you a job" is one of the classic recruitment scams aimed at young Nigerians
(client trust §4). If training ever costs money, it must **never** be tied to getting work on King Domain,
and the app says so plainly.

## 6. What this changes in the app

A Training section (cohorts, applying, cohort pages, assignments, offline materials, reminders), a trainer
role (feedback, attestation), the cohort conversation, the first-job track (reserved jobs, mentor review),
sponsorship by companies, and cohort outcome reporting in the admin dashboard.

## 7. Decisions for Victor (and Balogun)

1. **Training inside the app** as in §5.1–5.3 (cohorts, deadlines, offline materials, trainer feedback,
   attested final project that goes to the two reviewers)?
2. **Every cohort online as well as in person**, so transport is never the reason someone can't finish?
3. **Who pays for training?** Free (sponsored by companies or grants), paid by trainees (never tied to
   getting work), or a mix? Balogun's view matters here; money rule → ledger.
4. **A first-job track**: small real jobs from partner companies reserved for new graduates, with a mentor
   check before delivery?

### Answered by Victor, 2026-10-31 (carry into the PRD as decisions)

- **D41. Training is a later feature**, not part of the first build ("not on my hot list right now"); it
  was Balogun's initiative. When it is built, it lives **inside the app** as in §5.1–5.3. The PRD records it
  as a later phase with this design, so nothing built now has to be undone for it (the "Trained" education
  line and route B already exist in the earlier decisions).
- **D42. Training is paid for by a mix** of sponsorship and trainee fees, never tied to getting work.
- Decisions 2 (online alongside in person) and 4 (first-job track) were explained to Victor 2026-10-31; they
  can wait for Balogun, since training is a later phase.

## Sources

- Quartz, "Andela is overhauling its outsourcing model in Africa" (Sep 2019); BusinessDay, "In biggest layoff
  in African tech industry, Andela dismisses 420" (Sep 2019); Techpoint Africa (Sep 2019); Rest of World,
  "The truth about Africa's tech talent shortage" (2021); IFC, Andela case study.
- Boateng et al., "SuaCode Africa: Teaching Coding Online to Africans using Smartphones" (arXiv 2107.12257);
  Coursera, "Drivers of Quality in Online Learning" (2020); Behavioural Insights Team, "Nudging learners to
  complete their online courses" (2020).
- Pallais, AER (2014). 24 Oct 2026 team meeting transcript (Fathom).
