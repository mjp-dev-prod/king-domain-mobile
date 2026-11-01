# Overnight build: handoff (2026-10-31)

Written for Victor, to read first thing. Everything below is on **local branches, committed, not pushed**, except
S0 to S2, which went to staging on 2026-11-01 (backend, schema and admin). Nothing here has been run on a phone.

**Update 2026-11-02: S3 to S8 are built too (see "S3 to S8" at the end).** They are code-complete and committed, but
**none of the S3 to S8 test suites, the admin build or the full app suite has been run since they were written**: you asked
for building first and one careful verification pass after. Treat everything from S3 on as "written, analysed, not yet
proven". The verification pass is listed at the end.

## What you asked for

Three slices from the PRD (S0, S1, S2), built unattended, inline (no subagents). Then, on 2026-10-31 and 2026-11-02,
the remaining slices S3 to S8 in the same way.

## Where each branch is

| Repo | Branch | Based on |
|---|---|---|
| king-domain-mobile | `s0-foundations` | `prd` (the PRD, research and plan commit) |
| king-domain-backend | `s0-foundations` | `profile-photos` |
| king-domain-admin | `s0-foundations` | `master` |

## Status by slice

| Slice | Backend | Admin dashboard | App | Verified how |
|---|---|---|---|---|
| **S0 Foundations** | Done | Done | Done | Backend tests, admin build/lint, app tests (below) |
| **S1 Accounts and identity** | Done | Done (checker queue) | Done | Same |
| **S2 Proving a skill** | Done | Done (authenticity queue, blind review page) | Done (skills hub, builder, results) | Same, plus a fake private bucket in tests |

All three slices are built. "Done" means built and tested as described below, not looked at on a phone.

## What was verified, and what was not

Verified by running it:
- Backend: the whole suite, 318 tests, all passing (run once the three slices were complete; one S2 file rule was tightened afterwards and its suite re-run: 16 route tests plus the account-deletion addition pass).
- Admin dashboard: `npm run build` (TypeScript) passes; the new files lint clean. 12 lint errors that were
  already in older pages (Decisions, Entries, Ledger, auth and others) are untouched.
- App: `flutter analyze` clean; the whole suite passes (323 tests); existing tests that render the profile tab were
  updated to stub the new server-backed providers (see "Things you might trip over").

**Not verified (cannot be from here):**
- Nothing was run on a phone or in a browser. The screens are tested with widget tests only; look at them.
- No real Slack, email, Paystack, identity provider or R2 was contacted. Slack, email and storage are faked in tests.
- Camera and video capture (`image_picker`) and the new `file_picker` are untested beyond compiling.
- A real upload from a phone to a real R2 bucket, and a reviewer playing a real R2 video in the dashboard, have not
  happened. The signed link, the headers and the checksum were checked against a local fake that behaves like S3 (and
  that check found a real bug, below), but only R2 itself can confirm it.

## Decisions I made without you (all easy to change)

1. **Minimum age 16** to use the app (`IDENTITY_MIN_AGE`, default 16). The PRD left age open; 16 matches university
   admission. Under 18 needs the guardian step.
2. **`IDENTITY_REQUIRED` is off by default.** The gate on apply / post / award exists and is tested, but staging keeps
   working as it is until you set `IDENTITY_REQUIRED=true`.
3. Proof review (the existing admin screen) now **needs the Reviewer role**. Nobody has it yet except owners, so
   after this reaches staging, give Balogun and Debbie roles on the Team page or they will see "no access".
4. The guardian's confirmation page is served by the backend itself (`/guardian/confirm`), so the emailed link always
   lands on a real page. It needs `PUBLIC_API_URL` set to the backend's public address.
5. Identity documents and videos go to a new **private** storage bucket `identity-docs` (created on first use).
6. Payout accounts: once someone is verified, the bank account name must match their verified name; unverified people
   are not blocked (nothing to compare with yet).
7. Account deletion now also deletes identity checks, guardian records, identity files and the region / education
   / identity fields.

## Setup you owe before staging can use this

- Slack: an incoming webhook for a new `#alerts` channel → Render env `OPS_SLACK_WEBHOOK_URL`. Also `ADMIN_DASHBOARD_URL`
  and `PUBLIC_API_URL`. Never paste the webhook into chat or git.
- Push the schema to **staging** (additive; I only pushed to the test branch): `DIRECT_URL=<staging direct url> npm run db:push`.
- Give people roles on the Team page (Reviewer + skills, Checker, Shareholder).

## Things you might trip over

- Tests that render the profile tab (`shell_tabs`, `sign_out`, `photo_usage`, `push_ui`, `delete_account`) needed the
  new providers stubbed and a scroll to reach Sign out, because the profile tab has two more rows now. That is a test
  change, but it also means the account rows sit lower on a short phone screen.
- The first backend `db:push` against the Neon test branch failed once with "can't reach database" (the branch had
  scaled to zero) and worked on retry. Same may happen on staging.
- Source files in these repos use Windows line endings; scripted edits must handle `\r\n`.

## S2: proving a skill (what was built)

**The journey.** Profile > Your skills > a skill > Start. The person builds a draft: 2 or 3 pieces of real work, each
with the brief, their role, when it was made, the finished work (or a live link), and for at least one piece working
files and drafts; then one 2 to 3 minute walkthrough video, and a declaration that it is their own work (plus a note if
they used AI). A checklist says exactly what is left. Sending asks for confirmation because it cannot be changed after.

Then, in order: (1) a **checker** confirms it is really theirs (walkthrough, working files, drafts, nothing found
published elsewhere); (2) **two reviewers** who hold the skill score it against the rubric, 1 to 4 per line, **blind to
each other and to who made it**; if they disagree a **third** decides; (3) the person gets the result with **reasons**:
the lines that fell short, what good looks like for each, and the reviewers' own words, never who they were. Every
attempt stays in a visible history.

**Rules from your answers (D5 to D9).**
- A pass is refused if any line is "below the standard"; a Not yet must say what to fix.
- Before sending again after a Not yet, the person must accept the terms (shown in the app).
- Sending the **same finished files again** is detected by file fingerprint (R2's ETag). The system only **flags** it;
  the checker decides. Penalise = 2 months out of that skill, then 3. Changed work is never a repeat.
- Stolen work or hidden AI = the checker can **ban** the person from that skill. Stop = send back with a reason, no penalty.
- A verified result also creates the old "verified proof item" in that skill's category, so the existing apply gate
  keeps working untouched.
- Files go from the phone straight to a **private R2 bucket** through a presigned link; the server never carries the video.
- Account deletion deletes submissions, restrictions and the files in the bucket.

**Admin dashboard.** New pages: Authenticity (checker) and Skill reviews (reviewer), both in the inbox with targets,
median / 90th percentile and overdue counts, and in the Slack and email overdue alerts. Every action is audited.

**A bug the fake bucket caught.** The AWS SDK, by default, bakes the checksum of an *empty* body into a presigned upload
link, so every real upload from a phone would have failed. Fixed (`requestChecksumCalculation: "WHEN_REQUIRED"`) and
the link is tested to carry no checksum.

## S2: setup you owe

- Create a **private** Cloudflare R2 bucket and set `R2_PRIVATE_BUCKET` on Render (the existing `R2_ACCOUNT_ID`,
  `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` are reused; the key must be able to write to the new bucket). Without it,
  uploads answer "not available" and the hub says so.
- Push the schema to staging (S2 adds five tables; additive).
- Reviewers: you need **two different people** holding the skill (Team page > Reviewer + skills), or nothing can ever
  be decided. Owners can review every skill, but one person cannot review the same submission twice, so with only you
  as owner a submission would wait forever for a second reviewer.
- A Checker for the authenticity step.

## S2: things I decided or could not decide (please read)

1. **Rubrics are drafts.** All five (video, design, social, writing, web) are marked draft in the API, the app and the
   reviewer page. Only video came from the research; the rest I wrote without a practitioner. Each needs a working
   session with someone who does the work (PRD open item).
2. **Reviewers do not see the person's name or email**, only the work. That is my choice to reduce bias; the checker
   does see who it is. Say if you want reviewers to see the name.
3. **The ban is per skill**, not account-wide. Whether stolen work should end the whole account is a policy call I left open.
4. **The reply promise ("within 4 days")** is a constant in the app, from the queue targets (24 h check + 72 h review).
   Those targets are provisional until real handling times exist; change the wording when you set them.
5. **Repeat detection only catches identical files.** A re-exported or re-encoded video has a new fingerprint and will
   not be flagged; the checker's judgement covers that.
6. **The old apply gate is per category, not per skill.** Verifying "Graphic design" unlocks all "Design & creative"
   jobs, because that is how the old gate works. Whether the gate should become per skill is a product decision.
7. **The old single-file proof upload still exists** in the app and the proof-review page, so there are now two ways to
   get verified. I did not remove it (it is how staging works today). Recommend retiring it once you accept S2.
8. **No push notification on a result yet**, only email. The push system exists for contracts; wiring skill results
   into it is a small follow-up.
9. **Data cost.** Walkthrough videos are capped at 300 MB and finished files at 500 MB, and the app does not compress.
   On mobile data that is expensive for the person. The app should warn about size and ideally compress; not done.
10. **Any reviewer holding the skill can pick up any submission** (no assignment, no conflict-of-interest check). The
    blindness is the only protection against reviewing a friend's work.
11. **New app dependency `file_picker` 11.0.3** (for PDFs, documents and project files, which the gallery picker
    cannot choose). It is a native plugin and I could not build the Android app here. If the next phone build fails,
    suspect this first; if so, the writing and web skills lose document upload until it is sorted.

## Not in S2 (cut or left, so nothing is silently missing)

- Reviewer **rubric editing** from the dashboard (rubrics live in `src/rubrics.js`).
- A talent **viewing their own uploaded files** after sending (they see names and sizes, not a preview).
- **Withdrawing** a submission that is in review.
- Reviewer **payment or credit** tracking (a PRD admin-tools item; nothing about it was decided).

---

# S3 to S8 (built 2026-10-31 to 2026-11-02)

All on the `s0-foundations` branches of the mobile, backend and admin repos, committed locally. Per-slice plans:
`docs/superpowers/plans/` (S3, S4, S5). Rules and numbers come from `docs/core/prd.md` §3 and §4.

## Where each slice stands

| Slice | Backend | Admin | App | Tests written | Tests run |
|---|---|---|---|---|---|
| **S3** Jobs and discovery | Done | Job posts, Shortlists queues | Feed, filters, saved searches, apply, post-a-job, applicants, invitations, browse talents | Yes | S3 suites and the app suite passed individually (app 327) |
| **S4** Messaging | Done (calls and note-taker not built) | Safety reports queue | Messages tab, conversation, held messages, attachments, data saver, offline queue | Yes | Rules suite passed (14); route and app tests **not run** |
| **S5** Contracts and money | Done | Start-proof objections | Start proof, drafts, receipts, display currency, 20% | Yes | **Not run** |
| **S6** Disputes and chargebacks | Done | Disputes case screen, Chargebacks | Something's wrong, offers, rulings, cancel for refund | Yes | **Not run** |
| **S7** Reviews and reputation | Done | Reported reviews | Review screen, your reputation, track records, credentials | Yes | **Not run** |
| **S8** Packages and premium | Done | None needed (see cuts) | Packages, orders, premium sheet, questions | Yes | **Not run** |

## What S5 to S8 built, in plain words

**S5.** After a skill job is paid the talent sends a start proof in the skill's fixed format; the client has 24 hours
(silence accepts); accepting pays 20% at once and approval pays the rest. Objections are checked by a person against a
checklist, never for taste. Drafts, receipts, display currency with "about" amounts, and a gate that refuses job types and
dollars whose money flow is not built. Detail: `docs/superpowers/plans/2026-10-31-s5-contracts-and-money.md`.

**S6.** "Something's wrong" in the contract room: pick the problem, see the rule, offer a fixed way out (more time, one more
revision, a split, a cancel, carry on), 48 hours to answer, silence escalates. Either side can ask the team to decide; a
refused third round of changes or a missed resubmit clock opens an already-escalated case. The team rules within 5 days,
free, with written reasons shown to both, final; a ruling that moves more than ₦100,000 needs a second person. A ruling or
agreement pays the talent their share and refunds the client the rest through Paystack's refund API (the 10% fee is never
refunded; the 20% already paid for the start proof is not part of what is split). The client can cancel for a refund 3 days
past the delivery date with nothing delivered. A job whose talent got nothing reopens to the other applicants as a new post
(D20). Card chargebacks arrive by webhook, alert the team at once, count 16 weekday hours, and are answered through
Paystack's Dispute API with a receipt PDF built from our records (name as on ID, amount, card first six and last four, date,
service). A lost chargeback after the talent was paid removes the client (D36). Both sides are asked for an address so a
serious escalation can be followed up in person (D35), with the purpose stated.

**S7.** Reviews both ways with specific questions (no stars), a recommendation, a comment and a private "work with them
again?" that only the team ever sees. Hidden until both are in or 14 days pass, editable until then, locked after, one public
reply each. System facts per job (on time, change rounds, extensions, start proof timing). Profiles show plain counts per
skill, the visible reviews (last 12 months first) with their facts, and Proven per skill (3 jobs, none lost in a dispute, all
on time, every client recommending). A client's record shows what talents said and how fast they review. Reviews are reported
to a safety queue and removed only for abuse, personal data, irrelevance or leverage. Completed jobs, verified skills and
Proven levels become Open Badges 3.0 credentials, signed as VC-JWTs when the issuer key is set.

**S8.** Packages: a verified talent publishes up to three tiers per skill with the skill's standard fields; a client browses
(recently active first, no score, no paid place), fills in the rest of the brief and orders; the talent has 48 hours to
accept; accepting awards the job and the normal rules take over (pay within 24 hours, start proof, and so on). Premium through
Google Play Billing for the two decided features: reopening a paused job (clients) and asking a question before applying
(talents). The server verifies each purchase with Google, records it once, consumes it, and the use spends it; the answer to a
question is shown to every applicant without names (D38).

## Things I decided without you (all easy to change; please read)

1. **A reopened failed job is a new post**, not the old one reopened. A contract's job id is unique, so the old job keeps its
   money trail and the other applicants carry over as pending applications on a copy.
2. **Disputes can be filed any time the job is live**, not only within 3 days of a trigger. The contract's own clocks already
   bound it; the 3-day filing window from the ledger is not enforced.
3. **Settlement uses a new contract status `resolved`**, with the split recorded on the contract. Approved still means "paid in
   full on approval".
4. **Proven needs every completed job in the skill to have a revealed, recommending client review.** A client who never reviews
   therefore blocks Proven. That is the literal reading of D32; say if you would count only reviewed jobs.
5. **Review window is 14 days from payout; a review can be edited until the other is in.** The research says "locked after"; I
   read it as locked once visible.
6. **Premium is free unless `PREMIUM_ENFORCED=true`.** Before launch, and on staging, reopening and asking cost nothing. The
   prices are set in the Play Console, not in our code.
7. **Premium products are consumables**, consumed by the server after it checks them, so they can be bought again.
8. **Packages are one delivery, in naira, only.** Monthly packages wait for monthly money.
9. **An address is asked for but never required**, so nobody is locked out of a dispute for lacking one.
10. **Credentials are signed with an RSA key you provide** (VC-JWT, the 1EdTech-conformant JWT option). Without the key they
    are recorded but not shareable, and the app says so.

## Cut or left (so nothing is silently missing)

- **S3:** asking a question before applying is built in S8; "reopen" works free until `PREMIUM_ENFORCED`.
- **S4:** calls and the AI note-taker (D26), a voice recorder inside the app, sockets (it polls), quiet hours, mute.
- **S5:** milestone, monthly and hourly funding and release; dollar payments and day's-rate payouts; email for the start proof
  (push and in-app only); a message button inside the contract room (the Messages tab reaches the same person).
- **S6:** emails for dispute steps (push and in-app only); a payout-failures queue (still only logged); an AI timeline for the
  case screen (people read the assembled evidence); call summaries in the case (calls are not built); the agent-visit procedure
  (to be written). Auto-release is still the `AUTO_RELEASE_ENABLED` setting; it is now safe to consider because disputes exist.
- **S7:** a "work with them again" use in the shortlist builder, and a re-check queue for Proven (the signal is computed and
  Proven is revoked, but no queue item is created); review reminders are push only.
- **S8:** a report on a package (reports exist for messages and reviews); an admin view of packages and entitlements; refunds
  of a Play purchase are not listened for (no real-time developer notifications), so a refunded purchase keeps its credit until
  someone removes it; more package tiers or skills as premium; team seats.

## Setup you owe before staging can use S3 to S8

Schema (all additive; I only pushed to the Neon **test** branch): `DIRECT_URL=<staging direct url> npm run db:push`.

| Setting (Render env) | For | Without it |
|---|---|---|
| `PUBLIC_API_URL` | Credential links, guardian page | Credentials not shareable |
| `CREDENTIAL_SIGNING_KEY` (RSA private key, PEM) | Signing credentials | Credentials recorded, not shareable |
| `JOB_TYPES_ENABLED`, `USD_JOBS_ENABLED` | Turning on milestones, monthly, hourly, dollars | Only one-delivery in naira can be posted |
| `FX_NGN_PER_USD`, `FX_AS_OF` | "About" amounts | Only exact amounts are shown |
| `START_PROOF_AUTO_ACCEPT=false` | Switch off silence-accepts | Silence accepts after 24 hours |
| `PREMIUM_ENFORCED=true`, `PLAY_PACKAGE_NAME`, `PLAY_SERVICE_ACCOUNT_JSON`, `PLAY_PRODUCT_REOPEN`, `PLAY_PRODUCT_QUESTION` | Premium | Both features are free; buying says it is unavailable |
| `IDENTITY_REQUIRED=true` | The identity gate | Off, as before |

Paystack: subscribe the webhook to `charge.dispute.create`, `charge.dispute.remind`, `charge.dispute.resolve`,
`refund.processed`, `refund.failed` (it already has `charge.success` and the transfer events), and check the key may create
refunds and answer disputes. Play Console: create the two consumable products and a service account that can read purchases.
Roles: **Disputes** for rulings and start-proof objections, **Finance** for chargebacks, **Safety** for reported reviews.

## Assumptions I could not check from here (named so the verification pass looks at them)

- **Paystack `GET /refund?reference=`** is how I check for an earlier refund before creating one (so a retry never refunds
  twice). The docs list the parameter without naming it; I used `reference`.
- **Paystack dispute `resolution` values.** I treat `merchant-accepted` or a refund amount as a lost chargeback and anything
  else as won, and keep the raw payload on the row so the team can see what Paystack actually said.
- **Refunds go against `Contract.paystackReference`**, the reference the funding was confirmed with.
- **The new native dependency `in_app_purchase` 3.3.1** could not be built here, like `file_picker` before it. If the next
  phone build fails, suspect these two first.
- **The VC-JWT header** carries `kid` and `jwk` as in the 1EdTech example; a third-party verifier has not been tried.

## The verification pass (once, in this order)

1. Backend: `npm test` (one process at a time; the suite takes a while on this machine). New files: `startProof`, `disputes`,
   `reviews`, `packages`, `premium`, plus the earlier S3 and S4 route suites.
2. Admin: `npm run build`, then lint the new pages.
3. App: `flutter analyze`, then the full `flutter test`. New: `contract_extras_test`, `dispute_screen_test`,
   `review_screen_test`, `packages_premium_test`, `messages_test`; `discovery_test_support` stubs the new providers.
4. Push the schema to staging, deploy, and walk it with a test client and two talents: pay, start proof, deliver, review,
   dispute, a package order, and a chargeback from Paystack's test mode.
5. Only after that: decide `AUTO_RELEASE_ENABLED`, `IDENTITY_REQUIRED`, `PREMIUM_ENFORCED` and the premium prices.
