# King Domain: product requirements (living document)

Status: first written 2026-10-31 from PRD research topics 1–11 (2026-10-30 and 31) and Victor's decisions
D1–D46. Edit in place as we build; one doc, no versions. Decision numbers point to the register in §9 and to
the research doc that holds the evidence. **(assumed)** marks a working answer until the named person
confirms. **LATER** marks something designed here but not in the first build. Nothing here is built yet
unless §8 says so.

Sources: `Student_Talent_Marketplace_Product_Vision_v0.1.pdf`; the research docs in `docs/research/`
dated 2026-10-30 and 2026-10-31 (job types, proof verification, identity, client trust, discovery, messaging,
reviews, disputes, money, training, admin tools); the September research and corrections; the 24 Oct team
meeting. Where this doc and the code disagree about what exists, the code is right; where they disagree about
what should exist, this doc is right until changed here.

## 1. The product in one paragraph, and the rules every screen follows

King Domain is where students and emerging talent in Nigeria **prove a skill with real work, get paid under
protected terms, and build a record that stays with them**. Clients get verified people, money that is held
until they approve, and a fair way out when things go wrong. The team keeps it honest with checks that a
person makes and records.

Rules that apply everywhere:

1. **No dead ends, blanks or skipped steps.** Every state (empty, loading, failed, waiting on someone,
   rejected, done) says why and offers the next step (CLAUDE.md, 2026-10-30).
2. **No scores and no rankings of people.** Facts, not numbers that rank (September correction, D23, D29).
3. **A talent never pays anyone to get or do work.** Premium is optional, bought only through Google Play,
   and never buys a better place than another talent (D38).
4. **Money is held until the work is approved**, and every rule about money is shown before anyone pays.
5. **Contact stays in the app until a job is awarded**; outside payment is never allowed (D18).
6. **People decide**; the AI model prepares (D7, D33).
7. **Light on data**: nothing heavy downloads on mobile data without asking.

## 2. The people

| Who | What they do on King Domain |
|---|---|
| **Talent** | Proves skills with real work, finds and does jobs, sells packages, gets paid into an account in their own name, builds a record. Anyone with real skill: student, graduate, trained or self-taught (D13, D15). |
| **Under-18 talent** | Same as a talent; a parent or guardian gives consent; the money always goes to the talent's own account (D12). |
| **Guardian** | Confirms consent for an under-18 talent on their own phone. Has no other role. |
| **Client (individual)** | Posts jobs, browses talents, buys packages, pays, approves, reviews. Identity-checked before the first job goes live (D16). |
| **Client (business)** | As above, checked through CAC. Companies may later sponsor training (LATER). |
| **International client** | Pays in dollars by card; verified by passport and selfie or a business registry (D37). |
| **King Domain team** | Victor, Balogun, Debbie for now, in roles: owner, reviewer (per skill), checker, safety, disputes, finance, support; shareholders read-only (D43). On call in rotation (D45). |
| **AI assistant** | Prepares checklists, reverse image searches, timelines, call summaries, draft reasons. Never decides (D7, D26, D33). |
| **Trainer** | LATER (D41): runs cohorts, gives feedback, attests final projects. |

## 3. Journeys

### 3.1 Talent
1. **Sign up**: name, email, password, "I'm here to work". Email code.
2. **Region and education line**: state and city (or country), and Student · school · session / Graduate ·
   school · year / Trained · course / Self-taught (D15, D23).
3. **Profile**: photo, headline, bio. Browsing jobs works from here; applying needs the next steps, and the
   app says which ones are missing.
4. **Identity**: consent screen, NIN, live selfie through the provider; under-18s add a guardian, who
   confirms on their phone (D10, D12). Until the provider's live keys exist (after CAC), the team checks a
   NIN slip photo and a short live video by hand and the provider re-checks later (D47).
5. **Verify a skill** (one of the five launch skills, D25): the evidence pack (2–3 real pieces with brief,
   role and date; working files; drafts; a 2–3 minute walkthrough video; a declaration of own work and AI
   use), after reading and accepting the terms on repeat submissions (D5, D9). Result: **Verified** with what
   was checked, or **Not yet** with the reason per standard line and what to do, or **Removed** with the
   reason. The submission stays visible either way.
6. **Payout account** in their own verified name (name match).
7. **Find work**: Jobs for you (verified skills first), filters (skill, job type, budget, deadline, verified
   client, local or international, few applicants), saved searches and instant alerts, invitations (D21–D25).
8. **Apply**: an answer to the brief, 1–3 verified pieces, screening answers; at the client's price (D22).
   Premium talents may ask a question first; the answer is added to the job for all (D28, D38).
9. **Awarded**: the conversation becomes the contract room once the client pays.
10. **Start proof** in the skill's fixed format; on the client's acceptance (or 24 hours of silence) 20% is
    paid out (D2, D8).
11. **Work**: drafts shared without starting the review clock; extensions if needed (stage 2 rules).
12. **Deliver**; the client approves, asks for changes (up to 2 rounds) or nothing happens and it approves
    after 3 days.
13. **Paid** in naira (dollar jobs converted at the day's rate shown in advance, D37).
14. **Review** the client, and be reviewed; both hidden until both are in (D29–D31).
15. **Grow**: facts and counts on the profile; **Proven** after 3 completed jobs in the skill with no lost
    dispute, on time, all clients recommending (D32); publish **packages** (D4); portable credentials.

### 3.2 Client
1. **Sign up**: "I'm here to hire"; individual or business.
2. **Identity**: NIN and selfie, CAC for a business, passport for international (D16, D37).
3. **Find talent**, one of five ways (discovery §1): post a job; browse talents (recently active first,
   region filter) and invite; buy a package; ask "find someone for me" (a shortlist of 3–5 within the
   published time, D24).
4. **Post a job**: type (one delivery, milestones, monthly, hourly), skill, the skill's structured brief,
   price and currency, delivery days, screening questions, public or invite-only. A new client's first post
   is screened before it goes live (D17).
5. **Applicants**: in the order they applied, with each talent's checks panel, chosen work and answers;
   shortlist or decline (declined talents are told). At 50 applicants or 5 days the job pauses; reopening is
   premium (D21, D39).
6. **Award and pay**: the protection screen first (what's held, the start proof, change rounds, the
   late-delivery refund, the 20% rule if a talent abandons, how disputes are decided), then pay the price
   plus 10% by card, bank transfer or USSD (D35).
7. **During the job**: accept or object to the start proof; see drafts; answer extensions.
8. **Approve** or ask for changes; review the talent.
9. **If it fails**: the job reopens to the other applicants at once (D20).

### 3.3 When something goes wrong (both sides)
"Something's wrong" in the contract room → pick the problem → the rule and the evidence side by side →
propose a way out (more time, one more revision, a split, cancel by agreement, carry on) → 48 hours to answer
→ either side escalates, or silence does → a King Domain ruling within 5 days, free, with written reasons,
final (D33, D34).

### 3.4 The team
One inbox of queues, each with its target and its default when the target passes; a case screen with all the
evidence; roles; second-person approval for manual money actions above ₦100,000 (D44); audit log; urgent
alerts to phones and Slack; weekly on-call (D43–D46).

## 4. Mechanics (the rules, with their decisions)

### 4.1 Job types and lifecycles (D1–D3; job types doc)
| Type | Money | Lifecycle shown to both sides |
|---|---|---|
| One delivery | Whole price held after award | Agreed → Funded → Start proof → Working → Delivered → Review (≤2 change rounds) → Approved → Paid |
| Milestones | Each milestone funded before it starts; client can stop after any approved milestone | The milestone list; each runs Funded → Working → Delivered → Review → Paid; start proof on milestone 1 |
| Monthly | Each month funded on a reminder, by any method; card or direct debit only if the client opts in (Paystack can't repeat a bank transfer) | Agreed monthly scope → Month funded → Work → Month's deliveries → Review → Paid → renew, change or end |
| Hourly | Client pre-funds a weekly cap (hours × rate); unused hours go back | Agreed rate and cap → Week funded → Hours reported with what was done and files → Approve or dispute → Paid |

No contests (D1). The agreed timers (24 h to pay, delivery dates, 2 extensions with 48 h answers, 3-day
review, 2 change rounds, overdue at +3 days) apply per unit: per job, milestone, month or week. The numbers
for hourly reports and monthly notice are to be confirmed (§7).

**The structured brief**, per skill and type: deliverables, quantity, formats, revisions included, usage
rights, files the client provides, references, deadline. It is what reviews and disputes are judged against.

### 4.2 Start proof (D2, D8, D35)
| Skill | Start proof |
|---|---|
| Graphic design | 2–3 concept directions and a moodboard |
| Short-form video editing | Rough cut of the first piece plus a timeline screenshot |
| Social media management | The month's content calendar and the first week's posts drafted |
| Writing | Outline and the first section |
| Web development | Wireframes or sitemap plus the repository with first commits or a staging link |
| Hourly | None |

Uploaded into fixed fields; checked against a checklist, not for quality; 24 hours for the client to object
(an admin checks objections); accepted → 20% paid out. If the talent then abandons the job, the client keeps
the start-proof work and gets the other 80% back; the 20% is not refunded, and this is said before payment.

### 4.3 Proving a skill (D5–D9; proof verification doc)
Per skill. The evidence pack (§3.1 step 5). An authenticity check by a checker: face in the walkthrough
against the identity check, reverse image search on two pieces, working files match, Content Credentials read
where present, an optional follow-up question; AI detectors never a verdict. Then **two reviewers who practise
the skill** score independently against the skill's rubric; a third decides if they disagree; reviewers pass a
calibration set first. Results always shown in the app with reasons. "Real work" includes own projects, school
work and work for friends, church or campus events (D6). No fixed wait to resubmit; reviewers see every past
submission; resending rejected work unchanged means no submissions in that skill for 2 months, then 3 (the
2-then-3 ladder confirmed 2026-10-31); stolen or fake work means a ban (D9).

### 4.4 Identity, student status and age (D10–D15)
Identity for both sides before the first paid action (talent) or first live job (client): NIN + live selfie
through a licensed provider; payout name must match. Student status is a label from this session's course form
or fees receipt plus the ID card, checked by a person; it shows the session it was checked for and is never
forced to renew (D14). Under-18s: supported, guardian consent, paid into their own account (D12). The Child's
Rights Act s.28 point is a known risk recorded in the identity doc, not a blocker (Victor's decision).
Biometric data is sensitive under the NDPA: consent screens before the camera, results kept, raw biometrics
not.

### 4.5 Trust and safety (D16–D20; client trust doc)
Clients identity-checked before their first job goes live; first posts screened for scam patterns; "a talent
never pays anyone" shown on every job and conversation; no contact details before award; outside-payment
requests never allowed; in-thread warnings that hold contact details, links, payment requests and invitations to
meet; remote by default with safety guidance; report on everything; the client's track record on every job
(checked, member since, jobs posted and hired, total paid out, how fast they review, change rounds, disputes
lost, talents' ratings); failed jobs reopen to the other applicants.

### 4.6 Discovery (D21–D25; discovery doc)
Five ways to meet (§3.2 step 3). Soft cap at 50 applicants or 5 days, reopening is premium. Client sets the
price. Talents ordered by recently active, newcomers labelled "New on King Domain", region filter. Invitations:
up to 20 per job, valid 72 hours. Packages: up to three tiers per verified skill with the skill's standard
fields. The shortlist promise is the 90th percentile of the last 20 shortlists; a talent's response time is the
median of first replies over 30 days, shown in buckets after 3 conversations, with an explanation the talent
can read. Launch skills: graphic design, short-form video editing, social media management, writing, web
development.

### 4.7 Messaging and calls (D26–D28; messaging doc)
One conversation per relationship; after award the job's events appear as cards and are acted on there. Text,
voice notes up to 5 minutes, photos, files (large files straight to storage with resume); no APK/EXE; no links
before award. Data saver: no auto-download on mobile data, sizes shown, offline queue. Calls in the app; the AI
note-taker runs only if both agree, writes a **draft** summary that counts only when both confirm (speech
recognition fails on Pidgin), and the audio is deleted after. Contract messages can't be deleted. No blocking
during an active contract; reporting alerts the team.

### 4.8 Reviews and reputation (D29–D32; reviews doc)
System facts per job (start proof on time, delivered on time, change rounds, response time, outcome). The
client's review: followed the brief, quality as agreed, communicated well (yes/partly/no), would recommend,
comment. The talent's review of the client in the same shape. Hidden until both are in or 14 days, then locked;
one public reply each. A private "work with them again?" only King Domain sees. Profiles show counts, recent
first, no averages. Reviews removed only for abuse, personal data, irrelevance or leverage. Completed jobs and
Proven levels are issued as portable credentials (Open Badges 3.0).

### 4.9 Disputes and chargebacks (D33–D36; disputes doc)
The staircase in §3.3. Per type: per milestone (approved ones never reopen), per month, per weekly report;
start-proof objections checked against the checklist. Every payment produces a receipt with what Paystack needs
(name as on ID, amount, card digits, date, service description) plus the approval record and delivered files.
Chargebacks: alert at once, answer within 16 working hours through Paystack's Dispute API; a chargeback lost
after the talent was paid for approved work is absorbed by King Domain and the client removed. Both sides'
addresses are collected (purpose stated) so serious escalations can be followed up in person; agents' visits
follow a safety procedure (to write).

### 4.10 Money (D37–D40; money doc)
Prices in naira or dollars; dollars by card into King Domain's Zenith USD account; talents paid in naira at
the day's actual rate, shown before applying and before payout; display currency for everyone, marked "about";
dollar payouts to talents once a licensed partner exists. The client pays the price plus 10%; talents receive
100%; Paystack's costs come out of the 10% (worked examples in the money doc). Premium through Google Play
Billing (15%), starting with two features: reopening a paused job (clients) and asking before applying
(talents). Tax and the agent structure go to the team meeting and an accountant before real money moves.

### 4.11 Admin tools (D43–D46; admin tools doc)
Queues: chargebacks, safety reports, start-proof objections, first job posts, shortlists, disputes, identity
and student checks, proof verification, payout failures, reported reviews. Each with target, default, case
screen, reason codes, audit events, median and 90th-percentile times, and a quality figure. Roles as in §2.
Works on a phone.

### 4.12 Training (D41–D42; training doc) — LATER
Cohorts in the app with deadlines, offline materials, cohort conversation and trainer feedback; final project
made in class, attested, then reviewed by two reviewers; paid for by a mix of sponsorship and fees, never tied
to getting work. Online alongside in person and a first-job track are proposed and wait for Balogun.

## 5. Every screen

Each screen is built with all its states (§6). Existing screens are redesigned inside their slice, not
patched.

**Onboarding and account (both):** Welcome · Sign up (work or hire) · Email code · Log in · Forgot / reset
password · Identity: consent → NIN → live selfie → result (verified / in review / not yet, with reason) ·
Guardian consent (talent side) and the guardian's confirmation page · International identity (passport or
business) · Region and education line · Notifications permission · Settings (display currency, data saver,
quiet hours, notifications, privacy policy, delete account) · Premium (Play Billing).

**Talent:** Jobs for you (filters, saved searches) · Job detail (client track record, applicants count, ask a
question) · Apply sheet · Invitations · My applications · My profile as clients see it (checks panel, work,
facts, reviews) · Edit profile · Skills hub (status per skill) · Skill submission (evidence pack, walkthrough
recorder, terms) · Submission result (verified / not yet / removed) · Packages (list, create, edit) · Payout
account · Earnings (history, yearly statement) · Response-time explainer.

**Client:** My jobs · Post a job (type → skill → brief → price and currency → delivery → screening →
visibility → review) · Post in screening · Applicants (cap paused, reopen) · Applicant detail · Browse talents
· Talent profile · Invite to job · Packages browse · Package detail and buy (brief form) · Find someone for me
(request, waiting, shortlist) · Protection screen and pay · Saved talents.

**Contract room (both), per type:** Conversation with event cards · Milestone list · Monthly periods · Weekly
hours reports · Start proof submit (talent) and accept or object (client) · Share a draft · Deliver · Review:
approve or request changes · Extension request and answer · Something's wrong → ways out → escalated → ruling ·
Call (note-taker consent, summary card to confirm) · Review after the job (both, with the private question) ·
Receipt.

**Messages:** Conversations list · Conversation before award (warnings) · Report · Block.

**Admin (web, works on a phone):** Inbox · one queue page per queue in §4.11 · case screens (proof with two
reviewers, identity and student document, job post, shortlist builder, dispute with evidence and ruling form,
start-proof objection, safety report, chargeback response, payout failure, reported review) · Audit log ·
Roles and team · Skill standards, rubrics and start-proof formats · Reviewer calibration · Metrics · Ledger
(exists) · App releases (exists) · Waitlist (exists).

**LATER:** Training (cohorts, cohort page, assignments, trainer feedback and attestation), dollar payouts.

## 6. Quality bar (the done-gate for every slice)

| Area | Rule |
|---|---|
| Brand | Brand v1 tokens, type and radii from `lib/core/constants/`; each colour only for its job (CLAUDE.md). |
| Icons | Simple line icons only; no emoji. |
| States | Every screen designed for empty, loading (skeletons; a spinner only inside the working button; held ≥300 ms), failed (inline, with Retry, input kept), waiting on someone, rejected and done, each with a next step. |
| Motion | 250 ms state, 400 ms layout, 450–700 ms arrivals; press-scale on everything tappable; haptic on choices; off under reduced motion. |
| Words | Plain language; money in gold with tabular figures; every rule about money shown before paying. |
| Forms | Inline validation on blur and submit; first invalid field focused; nothing lost going back; the main button stays above the keyboard. |
| Data | Images and voice compressed; nothing heavy auto-downloads on mobile data; sizes shown. |
| Accessibility | WCAG AA contrast; labels on icon buttons; 48 dp targets; status never by colour alone; text scaling. |
| Safety | D18 detection wherever users type to each other before award; report available on every profile, job, message and review. |
| Honest data | Real behaviour only. Where the backend isn't built yet, sample data sits behind a store interface and the screen shows a visible staging marker; no fake substitute ships as real. |
| Logging | Log the state that decides an outcome and the read-back (CLAUDE.md rule 1). |
| Tests | Targeted tests per change; the full suites once at the end of each slice, one at a time (the PC is low on RAM). |
| Verified for real | Run on Victor's phone (and a cheap Android) against staging; every state seen, not assumed. |

## 7. Open items and assumptions (who decides)

- **Victor:** hourly report and monthly notice numbers (§4.1); premium prices (with the ledger); the shortlist service's
  working hours.
- **Team meeting / accountant:** turnover and VAT questions (D40, plain-language note in the money doc).
- **Ledger (the team's rule for major decisions):** post D2, D4, D21/D39, D35, D36, D42 and the premium prices
  for the shareholders' stances.
- **Balogun:** training funding details, online alongside in person, the first-job track (LATER).
- **Paystack (written answer still needed):** holding funds in the Balance (escrow), and confirming job payments
  stay outside Google Play Billing on Android.
- **Build-phase research:** the identity provider (sandbox first), a partner for dollar payouts, the call media
  server's cost, address checks and the agents' visit procedure.
- **Practitioners per skill:** the rubric, standard and calibration set for each of the five launch skills
  (one working session each).
- **Known risks, not blockers:** Child's Rights Act s.28 for under-18 paid work; the brand name is a placeholder
  (rename pending).

## 8. Build slices

All work goes to **staging** (branch `staging` of each repo); production waits for Victor's go-ahead. Each slice
gets its own task-level plan just before it starts, ships its admin queue with it, passes §6, and ends with a
walkthrough on Victor's phone.

| Slice | Contents |
|---|---|
| **S0 Foundations** | Skill taxonomy (categories → skills, D25); store interfaces and sample data with the staging marker; backend roles (D43), audit log, the inbox frame and Slack/push alerts (D46); the shared kit pieces every slice needs (event cards, per-type stepper, evidence viewer, reason-code sheet, consent screen, protection screen). |
| **S1 Accounts and identity** | Sign up for both sides, region and education line, identity (provider interface, sandbox, interim manual check), guardian consent, international identity, payout name match, consent and privacy updates; checker queue. |
| **S2 Proving a skill** | Skills hub, evidence pack with video and large-file upload (storage for video, which also delivers the video portfolio task from the 24 Oct meeting), walkthrough recorder, results with reasons and history, penalties; authenticity and two-reviewer queues, rubrics, calibration. |
| **S3 Jobs and discovery** | Post a job (types, structured briefs, currency), first-post screening, Jobs for you with filters, saved searches and alerts, soft cap, applications, applicants, browse talents, invitations, saved talents, the shortlist service with its computed promise. |
| **S4 Messaging and calls** | Conversations, voice notes, files, data saver, detection and warnings, report and block, calls with the AI note-taker. |
| **S5 Contracts and money** | Contract room with event cards, the four job types, start proof and the 20% release, drafts, deliveries, changes and extensions in the UI, the protection screen, receipts, naira and dollar pricing, display currency, payouts in naira at the day's rate. |
| **S6 Disputes and chargebacks** | Something's wrong, ways out with clocks, escalation, admin case screen and rulings, refunds and splits, chargeback alert and response, second-person approval; then auto-release switched on. |
| **S7 Reviews and reputation** | Reviews both ways, the private question, system facts, profile history, Proven, the client track record, portable credentials. |
| **S8 Packages and premium** | Packages (create, browse, buy), Google Play Billing for the two premium features. |
| **LATER** | Training (D41), dollar payouts, more premium features. |

The real-money test (target end of December) needs S1, S3, S4, S5 and S6 on staging with live Paystack and
identity keys, which depend on CAC.

## 9. Decision register

Each line: the decision, then where its evidence and full wording live.

| # | Decision | Doc |
|---|---|---|
| D1 | Four job types (one delivery, milestones, monthly, hourly); no contests | job types |
| D2 | Early money is earned by a start proof in a fixed format per skill, smaller than 50% | job types |
| D3 | Monthly work funded per month on a reminder; card or direct debit only if the client opts in | job types |
| D4 | Ready-made packages alongside job posts (ledger) | job types |
| D5 | Verification protocol adopted (evidence pack, walkthrough, authenticity check, two reviewers, reasons, Verified then Proven) | proof |
| D6 | No practice briefs; real work (including own, school and community work) is the way in; camp work counts | proof |
| D7 | Reviewers are the team with an AI doing groundwork; staff later; one reviewer who practises the skill | proof |
| D8 | Start proof: 20% share, 24 hours to object | proof |
| D9 | No fixed resubmit wait; resending rejected work: 2 then 3 months; stolen work: ban | proof |
| D10 | Identity checks for both sides | identity |
| D11 | Build regardless of CAC; provider behind an interface | identity |
| D12 | Under-18s supported; guardian consent; paid to their own account; s.28 a known risk, not a blocker | identity |
| D13 | Anyone with real skill can onboard | identity |
| D14 | Student status is a label, not a gate, not forced to renew | identity |
| D15 | Education line: Student, Graduate, Trained, Self-taught | identity |
| D16 | Clients identity-checked before their first job goes live | client trust |
| D17 | First job posts from new clients screened | client trust |
| D18 | No contact details before award; no outside payment; in-thread warnings | client trust |
| D19 | Client track record shown to talents | client trust |
| D20 | Failed jobs reopen to the other applicants | client trust |
| D21 | Soft cap at 50 applicants or 5 days; reopening is premium | discovery |
| D22 | The client sets the price; no bidding | discovery |
| D23 | Talents ordered by recently active, no score, region filter | discovery |
| D24 | "Find someone for me" with a data-computed promise; talent response-time stat explained | discovery |
| D25 | Launch skills: graphic design, short-form video, social media, writing, web development | discovery |
| D26 | Calls in the app with an AI note-taker; summaries count only when both confirm | messaging |
| D27 | Contract messages can't be deleted | messaging |
| D28 | Asking before applying is a talent premium feature | messaging |
| D29 | No star averages; specific questions, facts and counts | reviews |
| D30 | Reviews hidden until both are in, then locked; one reply each | reviews |
| D31 | Private "work with them again?" for King Domain only | reviews |
| D32 | Proven: 3 jobs in the skill, no lost dispute, on time, all recommend | reviews |
| D33 | Dispute staircase with 48-hour clocks and a free 5-day ruling with reasons | disputes |
| D34 | Rulings are final | disputes |
| D35 | Abandonment after the start share: client keeps the work, loses the 20%; addresses for in-person follow-up | disputes |
| D36 | Lost chargebacks after paying a talent for approved work are absorbed by King Domain | disputes |
| D37 | Naira or dollar prices; naira payouts at the day's rate; display currency | money |
| D38 | Premium never buys a better place; pre-apply answers shared with all applicants | money |
| D39 | Premium starts with two features; more much later | money |
| D40 | Tax goes to the team meeting and an accountant | money |
| D41 | Training is a later phase, designed in-app | training |
| D42 | Training paid for by a mix, never tied to getting work | training |
| D43 | Team inbox, case screens, roles | admin tools |
| D44 | Second-person approval for manual money actions above ₦100,000 (confirmed 2026-10-31) | admin tools |
| D45 | Weekly on-call rota | admin tools |
| D46 | Urgent alerts to phones and Slack; daily digest | admin tools |
| D47 | Until the identity provider is live, the team checks a NIN slip photo and a short live video by hand; the provider re-checks later (confirmed 2026-10-31) | identity |

Earlier decisions still in force: the payment rules (ledger milestone 04; `docs/features/stage-2-delivery-and-changes.md`,
`docs/core/payments.md`), the September corrections (`docs/core/correction-*.md`), brand v1 (CLAUDE.md), and the
"no dead ends" rule (CLAUDE.md, 2026-10-30).
