# S3: Jobs and discovery (plan, 2026-10-31)

PRD §8 S3; decisions D1, D17 to D25; research `job-types-2026-10-30.md`, `discovery-2026-10-30.md`,
`client-trust-and-safety-2026-10-30.md`. Built unattended: local commits only, schema on the Neon TEST branch only.

## What a person can do when this is done

**Client:** post a job in 8 steps (type, skill, structured brief, price and currency, delivery, screening
questions, visibility, review); see their first post held for screening and why; see applicants in the order they
applied with a checks panel; shortlist or decline (declined talents are told); see "applications paused" at 50
applicants or 5 days and reopen; browse talents (recently active first, region filter) and open a profile; invite
up to 20 talents per job (valid 72 h); save talents; ask "find someone for me" and see the promised time.

**Talent:** Jobs for you (verified skills first) with server-side filters and paging; saved searches with instant
push alerts; job detail with the client's track record, applicant count out of 50; apply with an answer, 1 to 3
verified pieces and screening answers; Invitations; the shortlist question ("are you available?").

**Team:** queue "Job posts" (first posts, approve or reject with a reason code), queue "Shortlists" (build a
shortlist of 3 to 5 with a line each), both in the inbox with targets and audit events.

## Decisions I am carrying (from your answers) and ones I had to make

Carried: D1 four types, no contests; D17 first post screened; D21 soft cap 50 or 5 days, reopen is premium;
D22 client sets price, no bidding; D23 recently active, no score, "New on King Domain", region filter; D24 shortlist
promise = p90 of the last 20 shortlists; D25 five launch skills.

Made by me (all easy to change, all listed in the handoff):
1. **Reopen is not gated yet.** It is premium (D21/D39) but Play Billing is S8 and the price is undecided, so the
   endpoint checks `REOPEN_REQUIRES_PREMIUM` (off by default). Nothing quietly settles the monetisation decision.
2. **USD is storable, not payable yet.** A job can be priced in NGN or USD (D37); paying in dollars is S5.
3. **"Recently active"** = the last time the person used the app (`User.lastActiveAt`, updated at most every 10 min).
4. **"New on King Domain"** = verified in a skill within the last 30 days and no completed job.
5. **Screening patterns** are a plain list (contact details, outside payment, "pay to apply", "send money first",
   crypto, "WhatsApp me"); they flag, a person decides. The same detector is reused for messages in S4 (D18).
6. **The shortlist working hours** are an open item (PRD §7). Until set, the promise counts all hours.
7. **Response time** needs messages, so it is built in S4; S3 only reserves where it shows on the profile.
8. **Packages** are S8; "packages" in the discovery doc are not here.

## Backend

Schema: `Job` gains jobType, skillKey, brief (structured), currency, visibility, screeningQuestions, postStatus
(screening / live / rejected / paused), screening decision fields, pausedAt / reopenedAt. `Application` gains
answer, pieceIds, screeningAnswers, `shortlisted` and `declined` states (with who was told and when).
New: `Invitation`, `SavedTalent`, `SavedSearch`, `ShortlistRequest` and `ShortlistItem`. `User.lastActiveAt`.

Pure rules (own tests): structured brief per skill and type (`briefs.js`), risk detection (`safety.js`), cap /
invitation / promise / "new" rules (`discoveryRules.js`), saved-search matching.

Routes: extended `POST /jobs`, `PATCH /jobs/:id`; server-side `GET /jobs` (filters, paging, "for you"); `GET /jobs/:id`
(track record); extended `POST /jobs/:id/apply`; applicants with checks panel; shortlist / decline; pause / reopen;
`GET /talents`, `GET /talents/:id`; invitations; saved talents; saved searches; shortlist requests.
Admin: `/admin/job-posts`, `/admin/shortlists`.

## App

Jobs for you with filter sheet and saved searches; job detail (track record, cap, ask later); apply sheet;
Invitations; client: post-a-job flow, my jobs, applicants and detail, browse talents, talent profile, invite sheet,
saved talents, find someone for me.

## Not in S3 (named so nothing is silently missing)

- "Ask a question before applying" (premium, D28/D38): needs messaging, so S4 and S8.
- Packages, buying a package: S8.
- Talent response-time figure: S4 (needs conversations).
- Client track record: facts computable today (member since, jobs posted and hired, paid out); review-derived facts
  (ratings, how fast they review) wait for S7.
- Real-money USD funding, display currency and the day's rate: S5.
