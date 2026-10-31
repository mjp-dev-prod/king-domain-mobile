# Verifying identity, student status and age (research, 2026-10-30)

**Why:** SheerID is not available to King Domain, so we need our own way to know that a talent is a real
person, is the student they claim to be, and is old enough to work. Victor, 2026-10-30: "we can do our own
means of verifying you are a student". PRD research topic 3. It proposes; decisions are in §10.

Builds on `docs/research/spotify-sheerid-student-verification.md` (2026-09-13), which found that even
SheerID falls back to a person reviewing documents where no school database exists, and that the check
must be on **current enrolment**, not on an ID card that outlives the student.

Tags: 🟢 fact (named source) · 🔵 observed (this codebase) · 🟣 synthesis · 🟡 hypothesis · 🔴 unknown.

## 1. Short answer

🟣 Three separate checks, each with the right evidence:

1. **Identity** (everyone who moves money, talents and clients): NIN plus a live selfie matched to the
   NIMC photo, through a licensed Nigerian provider. Gives the legal name and date of birth.
2. **Student status** (talents who say they are students): this session's course registration form or
   school fees receipt, plus the student ID card, checked by a person; a code to the school email where the
   school issues one. Renewed every session.
3. **Age**: from the NIN date of birth. Under 18 is a child under Nigerian data law, and many first-year
   students are 16 or 17, so this needs a rule (decision 3).

## 2. What King Domain does today (🔵)

- Sign-up asks for a name, an email, a password and talent or client. The talent email field suggests
  `you@university.edu.ng` but nothing checks it.
- No identity check, no student check, no age check, for either side.
- The payout account name is resolved through Paystack, but it is not compared with anything.

## 3. What a Nigerian student can actually show (🟢)

- **Every session, students pay fees and register courses on the school portal**, then print the course
  form and the fees receipt. UNICAL: "Pay this session's school fees… Register your courses"; the matric
  number is issued once fees are paid. UI and FUNAAB publish session registration timelines and late
  penalties. So **the course form and the fees receipt are dated to the current session**: the kind of
  document SheerID's method needs.
- **School fees are paid through Remita** at many schools, with the matric number on the payment (UNILAG's
  payment guide). Remita's "confirm presented receipt" is a feature of the receiving organisation's own
  Remita profile, so 🔴 King Domain can't assume it can check a receipt by its RRR.
- **Some schools issue student email accounts**: UI students log in with their "student institutional
  email"; FUNAAB gives every student a Google Workspace account at `student.funaab.edu.ng`. Not every
  school does, so a school-email code is a useful extra signal, not the method.
- **The national student list exists but is closed.** NELFUND's Student Verification System holds records
  uploaded by each school (matched by admission or matric number, checked against JAMB). No public or
  third-party access was found. 🟡 A partnership could open it later; not something to plan on.

## 4. Identity checks available in Nigeria (🟢)

- Licensed providers (Smile ID, Prembly/Identitypass, Dojah, Youverify, Bytid and others) check a **NIN
  against NIMC** and **match a live selfie to the NIMC photo**, with liveness checks that stop printed
  photos, screens and replayed videos (Bytid: depth, colour flash, random prompts; a duplicate-face check
  flags one person opening several accounts).
- **Cost is small:** published prices run from about **₦150 (NIN with face match) plus ₦50 (liveness)**
  (Bytid) to ₦200 + ₦400 (VerifyNG); Dojah starts at $0.06 per call.
- **Prembly also verifies NYSC certificates**, useful for graduates.
- **Every provider requires business approval before live keys**: registration documents, a use-case
  description, 3–10 business days (Wycord's comparison). 🔵 King Domain's CAC registration is still in
  progress, so **live identity checks wait on CAC** the same way Paystack payouts do.

## 5. What the law requires (🟢 Nigeria Data Protection Act 2023)

- **A child is anyone under 18** (the Act uses the Child's Rights Act definition; FPF's summary). To rely
  on consent for a child, **a parent or guardian must consent**, and the platform must **verify age and
  consent**; a government ID is an acceptable age check (s.31).
- **Face images used to identify someone are biometric data, which is sensitive personal data** (s.65);
  processing it needs consent **for that specific purpose** (s.30).
- **Before collecting**, tell the person who we are, the purpose, the lawful basis, who receives it, how long
  it is kept, their rights, and any automated decision-making (s.27). **Consent must be an active choice**,
  never pre-ticked, in clear language; silence is not consent (s.26).

**Work by under-18s (🟢 Child's Rights Act 2003, s.28):** "No child shall be… employed to work in any
capacity except where a family member engages him/her in light agricultural, horticultural or domestic
work"; offences carry a fine or up to five years' imprisonment, or both, and apply to companies and their
officials (NBS child labour report's table of the Act). Nigerian law is inconsistent here: the Labour Act
sets lower ages for some work, the ILO has asked Nigeria to harmonise, and not every state has adopted the
Child's Rights Act. The statistical standard Nigeria's NBS uses counts 15–17-year-olds as in child labour
only for hazardous work, long hours (43+ a week) or night work. 🔴 Whether a 16–17-year-old selling remote
freelance services counts as being "employed" under s.28 is a question for a lawyer, and the answer decides
whether under-18 paid work can be switched on in production.

## 6. Age in practice (🟢 / 🔵)

- The minimum age for university admission is **16** (JAMB FAQ; Federal Government, July 2025), with
  exceptions below 16 for exceptional candidates. 🟣 So a real share of 100–200 level students are 16 or 17:
  children under the Act.
- 🔵 **Under-18s can hold a bank account and a NIN in their own name.** Victor opened a GTBank account under
  18 within about an hour, and held a minor's NIN from 15 that was migrated to an adult record at 18 (Victor,
  2026-10-30). This replaces an earlier guess here that they often can't. So a minor can be paid into an
  account in their own name.

## 7. Proposal (🟣, for the PRD)

### 7.1 Identity, for everyone who moves money
- Talents before they can apply to paid work; clients before they can fund a job. Browsing and building a
  profile need nothing.
- NIN + live selfie through a licensed provider; we keep the result (legal name, date of birth, checked
  on, provider reference), not the raw biometric data.
- **The payout account's name must match the verified name**, so money only goes to the person who did
  the work.
- The verified face is what the walkthrough video in the proof protocol is matched against
  (proof-verification §7.4), and the duplicate-face check stops one person running several accounts.
- Businesses: a CAC lookup for client companies (providers offer it).
- Consent screen before the camera opens, in plain words (s.26–27).

### 7.2 Student status
- **Evidence:** this session's course registration form **or** fees receipt (showing name, matric number,
  department, level, session), plus the front of the student ID card.
- **Optional extra:** a code sent to the school email, for schools that issue them; passing it speeds up
  review.
- **Checked by a person against a checklist:** the names match the identity check, the session is the
  current one, the photo on the card matches the verified face, the document is consistent with that
  school's genuine format. Over time we keep a **library of genuine document formats per school**, which
  makes fakes stand out.
- **Shown as:** "Student · University of Lagos · 2026/27 session · checked 3 Nov". The matric number and
  the documents are never shown to anyone outside the review.
- **Expires at the end of the session**; the app reminds the talent to renew with the next session's form.
- **Graduates:** "Graduate · University of Lagos · 2027", from a certificate, statement of result or NYSC
  certificate. Skills, jobs and reviews carry on unchanged: that is the reputation that outlasts graduation.
- **Not yet** comes with the reason and what to upload instead. A forged document leads to a ban (the same
  rule as stolen work, decision D9).

### 7.3 Age
- Date of birth comes from the identity check. Under 18 needs a rule (decision 3).

### 7.4 Keeping the data safe
- Documents stored privately, opened only inside a review, every access logged.
- Raw documents deleted a set time after the decision; the outcome (what was checked, when, by whom) is
  kept. Account deletion removes them (existing deletion flow).

## 8. What this changes in the app

An identity step before the first paid action (both sides), a student-status submission with its review
queue in the admin dashboard, renewal reminders each session, the "Student · school · session" and
"Identity checked" facts on profiles and applicants, a name match on payout accounts, an age rule at the
identity step, and consent screens.

## 9. Unknowns (🔴)

- Which schools issue student email accounts: build the list as students arrive.
- Whether a partnership with NELFUND or individual schools could give a direct enrolment check later.
- The exact provider: compare Smile ID, Prembly, Dojah and Bytid on a test account when CAC allows it.

## 10. Decisions for Victor

1. **Identity checks for both sides** (NIN + live selfie through a licensed provider, about ₦200–₦600 per
   person, before the first paid action). Adopt?
2. **Until CAC is done, providers won't issue live keys.** For the end-of-December money test: a team-run
   interim check (photo of the NIN slip plus a short live selfie video, reviewed by us, re-run automatically
   once the provider is live), or no paid work until the provider is live?
3. **Under 18s:** (a) can join, build a profile and get verified, but take paid work only from 18;
   (b) can work with a verified parent or guardian's consent, paid into the guardian's account; or
   (c) 18 and over only.
4. **Who can be a talent:** current students only, or students and graduates ("emerging talent", as the
   vision says), with graduates labelled as such?
5. **Student status renewed every session**, with a reminder. Adopt?

### Answered by Victor, 2026-10-30 (carry into the PRD as decisions)

- **D10. Identity checks for both sides**, before the first paid action. Adopted.
- **D11. Build it now, CAC or not.** CAC is expected this month or next; the PRD and the full UI are built
  regardless, with the provider behind an interface (providers give free sandbox keys before approval) and
  the live keys plugged in when CAC lands. Blockers are to be overcome, not designed around.
- **D12. Under-18s are supported.** Many students fend for themselves at 16–17, so they need the platform
  most. A parent or guardian's details and consent are collected (NDPA s.31), but **the money always goes
  to the student, into an account in the student's own name**. Open: how the guardian's consent is verified
  (proposed: the guardian confirms on their own phone, by code or link, and their name and number are
  recorded). **Victor's decision: under-18 paid work goes ahead.** Millions of Nigerian students already
  work at 16–17 (he was a paid carpenter and delivered goods worth ₦300–500k at that age), and the law is
  contradictory and widely unenforced. The Child's Rights Act s.28 point in §5 stays in this doc as a known
  risk for the shareholders to be aware of, not as a blocker.
- **D13. Anyone with real skill can onboard as a talent**: students, graduates, self-taught people and
  training-camp trainees alike. Everyone goes through the same identity check and the same proof-of-work
  protocol; schooling is a label on the profile, not a condition.
- **D15. Every talent picks an education line:** Student · school · session; Graduate · school · year;
  Trained · King Domain camp or another course (with its certificate); Self-taught. Same checks for all;
  the line only describes them. Marketing still leads with students, as the vision does.
- **D14. Student status is a label, not a gate, and not renewed by force.** What matters is identity and
  proof of work. The label shows the session it was checked for ("Student · UNILAG · checked for 2026/27");
  the talent can update it, and graduates switch to "Graduate".

## Sources

- University portals and notices: University of Lagos (student portal, payment procedure, registration
  update 2025); UNICAL student portal; University of Ibadan student portal; FUNAAB student portal (2026/27
  guidelines).
- Remita support: "How to confirm presented receipts"; "Retrieve Remita Receipt".
- NELFUND, "Public Guidelines for Applicants" (Students Loans Act 2024); Punch (16 Oct 2025); MSME Africa
  (20 Jun 2025); ICPC (May 2025); Independent (May 2024).
- Prembly docs, "NIN With Face"; Bytid pricing page; VerifyNG pricing; Dojah product page; Youverify pricing
  blog (2023); Wycord, "KYC APIs in Nigeria: the nine verified providers compared".
- Nigeria Data Protection Act 2023 (NCC-hosted text): s.26, s.27, s.30, s.31, s.65; TechMeetsLaw (s.30,
  s.31); Future of Privacy Forum, "Nigeria's New Data Protection Act, Explained" (2023).
- JAMB FAQ (2025 eligibility); JAMBulletin 14 Jul 2025 and 18 Aug 2025 (Premium Times, Punch); Federal
  Ministry of Information (Nov 2024).
- Earlier: `docs/research/spotify-sheerid-student-verification.md`.
