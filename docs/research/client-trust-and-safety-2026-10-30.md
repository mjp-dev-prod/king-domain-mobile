# Client trust, and keeping students safe from bad clients (research, 2026-10-30)

**Why:** Victor, 2026-10-30: "how do we reassure clients". At the 24 Oct meeting Balogun described students
being taken advantage of because of lack. Trust has to run both ways: a client must believe the talent is
real and will deliver, and a student must be safe from fake jobs, scams and predators. PRD research topic 4.
It proposes; decisions are in §9.

Tags: 🟢 fact (named source) · 🔵 observed (this codebase) · 🟣 synthesis · 🟡 hypothesis · 🔴 unknown.

## 1. Short answer

🟣 **Clients** are reassured by being shown, at every step, why the risk is low: the talent's checks and
real work before hiring, money held until they approve, early visible progress, and a clear refund path.
**Students** are protected by verified clients, scam jobs screened out before students ever see them, all
contact kept in the app until a job is awarded, warnings when a conversation looks like a scam, and one
absolute rule: **a talent never pays anyone to get or do work.**

## 2. What King Domain does today (🔵)

- Money is held until the client approves (escrow), with the agreed timers and change rounds.
- **The client's email is shown to every talent who opens a job, and the talent's email to the client**
  (flagged as an open item on 2026-10-24). That is exactly the off-platform contact path scammers use.
- No client verification, no client track record shown to talents, no job-post screening, no report or
  block, no in-app messages at all.

## 3. What clients actually fear (🟢, September research)

From `market-validation-2026-09-12.md` §4–6:

- The main buyer fear is **being deceived**, not inexperience: agencies posing as the solo freelancer hired,
  fake or gamed reviews, AI-generated or plagiarised work passed off as custom (a documented $1,490 Fiverr
  case delivered Pinterest images).
- **Dispute processes that are slow or absurd at small amounts** (an Upwork arbitration fee of $675 to
  recover $75).
- **Trust outranks price** in buyer decisions across five independent studies.
- **The word "student" can cost the job**: a second-year student repeatedly lost clients the moment she
  said so; 83% of US hiring managers in one survey "don't fully trust recent grads alone with customers".
  Demonstrated project work outweighs credentials.

## 4. What students face (🟢)

- **Task scams**: an unsolicited WhatsApp message offers daily pay for liking videos or "optimising
  products"; small early payouts build trust, then the victim is pushed to pay "registration", "activation"
  or "upgrade" fees (Punch, Jan 2026; Vanguard, Feb 2026, including a 25-year-old university student asked
  to move to Telegram).
- **Pay-to-get-a-job fees** from ₦5,000 to ₦500,000 for processing, training or onboarding, and fake
  recruitment agencies charging registration fees for jobs that don't exist (BusinessDay 2025; The Nation,
  Jun 2026; Al Jazeera 2022).
- **Impersonation** of real brands (Jumia, Temu) and of HR staff, with convincing logos and documents.
- **Physical danger**: fake job interviews used to rob or rape applicants, most often young women (Al
  Jazeera 2022, quoting a youth and gender advocate).
- 51% of Nigerian consumers were hit by a financial scam in a year, most often through social media (Visa
  "Stay Secure" 2026, cited in the September research).

## 5. What established platforms do (🟢)

- **Client track record shown to freelancers on every job and offer** (Upwork): payment method verified,
  rating from freelancers, jobs posted and hire rate, total spent, location, member since. Freelancer guides
  treat "payment unverified + nothing spent + vague brief" as a walk-away combination and read the text of
  client reviews because star ratings are inflated by fear of retaliation.
- **Upwork's own red flags for fake jobs:** payment unverified, many negative reviews, reviews that sound
  fake, many posts with no hires, short vague descriptions, budgets far above or below the market.
- **Contact details only after a contract** (Upwork): sharing email, phone, Telegram or WhatsApp before a
  contract starts is a violation that can cost the account; contact info can then be shared only inside
  that contract's message room. **Asking** to be paid outside the platform is itself a violation, even if
  it never happens. Report buttons on messages, block, daily limits on new conversations.
- **Fiverr** allows third-party tools only after an order is placed; warnings first, suspension for repeats.
- **Airbnb** analyses messages for safety: it may **block a message or ask for text to be removed** when it
  contains contact details, outside links or references to other sites before a booking, and shows a
  **reminder inside the thread** ("be careful") with a one-tap report when the other side asks for contact
  details early.

## 6. Proposal: reassuring clients (🟣, for the PRD)

At each step the client sees why the risk is low, in plain words:

1. **Before hiring.** On every applicant: the "How this talent was checked" panel (proof-verification §7.8):
   identity, education line, each verified skill and what was examined, jobs completed and on time. The
   profile leads with **real work**, not the student label, because the work is what wins clients (§3).
2. **Posting.** The structured brief per job type (job-types §8) gets applicants who answer the actual
   brief, and is what delivery is later judged against.
3. **Paying.** Before paying, the client sees the protection in one screen: the money stays with King Domain
   until they approve; the start proof arrives early; how many change rounds they have; what happens if the
   talent is late or disappears (the agreed rule: 3 days past the delivery date with nothing delivered, the
   client can cancel for a full refund of the budget); how a dispute is decided and how fast (an admin
   rules within 5 days).
4. **During the job.** The start proof within days, drafts as they come, deadlines and extension requests
   visible.
5. **If it goes wrong.** The job reopens straight away to the client's other applicants (a re-match, the
   way Toptal replaces a candidate), so a failed hire costs the client days, not the project.
6. **Honesty rules on talents**: the verified talent must do the work personally (handing it to someone else
   is grounds for removal), and AI tools used in a delivery must be declared at delivery. Both are checkable
   through the start proof, drafts and the walkthrough.

## 7. Proposal: keeping students safe (🟣, for the PRD)

1. **Clients are identity-checked before their first job goes live** (NIN + live selfie, or a CAC lookup for
   a company; identity topic D10). A scam post never reaches a student.
2. **New clients' first job posts are screened** before going live: an automatic check for scam patterns
   (liking or following tasks, "registration" or "activation" fees, pay far above the market for trivial
   work, outside links, requests to message on WhatsApp or Telegram) plus a look by the team.
3. **A talent never pays anyone.** No fee to apply, no fee to start, no deposit, no equipment, no training
   charge from a client. The app says so on every job and in every conversation's first message, and any
   such request is a reportable offence that removes the client.
4. **Contact stays in the app until a job is awarded.** No emails or phone numbers shown to either side
   before award (this closes the 2026-10-24 open item). After award, sharing contact details is allowed
   inside that contract's conversation. **Asking for payment outside King Domain is never allowed.**
5. **In-thread warnings, Airbnb-style.** When a message before award contains a phone number, email,
   WhatsApp or Telegram link, a payment request, or an invitation to meet in person, the app holds it and
   asks the sender to remove it, and shows the receiver a short warning with a one-tap report.
6. **Remote by default.** King Domain jobs are remote. If a client asks to meet, the app shows safety
   guidance (public place, tell someone, never go alone to an "interview" at a private address) and the
   report button.
7. **Report and block** on every profile, job and message, with a fast human response. Reports of a client
   pause their jobs while the team looks.
8. **The client's track record is shown to talents** on every job: identity or business checked, member
   since, jobs posted and hired, total paid out through King Domain, how fast they usually review deliveries,
   change rounds used on average, disputes lost, and ratings from talents. (Ratings and private feedback are
   designed in the reputation topic; the research already shows public ratings inflate from fear of
   retaliation, so a private channel matters.)

## 8. What this changes in the app

Client identity at sign-up-to-post, a job-post screening queue in the admin dashboard, masked contact
details, in-app messaging with detection, warnings and report/block (the messaging topic designs the
conversation itself), the protection screen before payment, the re-match on failure, the client track
record panel, the talent-pays-nothing notice, and the honesty declarations at delivery.

## 9. Decisions for Victor

1. **Clients identity-checked before their first job goes live** (not only before paying), so fake jobs
   never reach students?
2. **First job posts from new clients screened** (automatic check plus a look by the team) before going
   live?
3. **No contact details before award; outside-payment requests never allowed; in-thread warnings.**
   Adopt? (Settles the email-exposure item.)
4. **Client track record shown to talents** on every job (the list in §7.8)?
5. **Re-match on failure**: a failed job reopens straight away to the client's other applicants?

### Answered by Victor, 2026-10-30 (carry into the PRD as decisions)

- **D16.** Clients are identity-checked before their first job goes live.
- **D17.** New clients' first job posts are screened (automatic check plus a look by the team) before going
  live.
- **D18.** No contact details before award; asking for payment outside King Domain is never allowed;
  in-thread warnings with one-tap report. Closes the 2026-10-24 email-exposure item.
- **D19.** The client's track record (§7.8) is shown to talents on every job.
- **D20.** A failed job reopens straight away to the client's other applicants.

## 10. Unknowns (🔴)

- How Nigerian clients react to identity checks before posting: a little friction for honest clients,
  a wall for scammers. Watch drop-off at that step.
- Which scam phrases appear in practice: the screening list should grow from real reports.

## Sources

- Upwork: "Signs that a Client May Not Be The Right Fit"; "Client Info Included in Direct Offers" (2018);
  "Get to know each other before a contract"; "Circumvention, and why it's against the rules"; "How to use
  Upwork Messages". Upwork Scout (2026) on reading client stats and "member since"; TrendsOnUp, "How to Read
  an Upwork Job Post".
- Fiverr: "Our Community Standards" (off-platform policy); "Stay protected: Fiverr's off-platform policy".
- Airbnb Help, article 1121 (message analysis, blocking contact details, in-thread reminders).
- Punch, "How Nigerians Fall Victim to Transnational Remote Job Scams" (Jan 2026); BusinessDay, "The rise of
  recruitment fraud in Nigeria" (2025); The Nation, "How recruitment scams prey on unemployed Nigerian youth"
  (Jun 2026); Al Jazeera, "Young job seekers scammed, abused in Nigeria" (2022); Vanguard, "Poor Data
  Privacy: How online scams… score Nigeria's digital economy low" (Feb 2026); UNODC Nigeria, "7 Things
  Human Traffickers Say to Lure Victims".
- Earlier: `docs/research/market-validation-2026-09-12.md` §4–6; the agreed payment rules (ledger milestone
  04, see `docs/features/stage-2-delivery-and-changes.md`).
