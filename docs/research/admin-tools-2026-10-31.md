# Admin tools: running the marketplace behind the scenes (research, 2026-10-31)

**Why:** Almost every decision in topics 1–10 creates work for people at King Domain: reviewing proof,
checking identities, screening first job posts, building shortlists, ruling on disputes, answering
chargebacks within 16 hours, handling safety reports. Today the team is Victor, Balogun and Debbie, helped by
an AI model (D7). The tools decide whether those promises are kept. PRD research topic 11 (the last). It
proposes; decisions are in §7.

Tags: 🟢 fact (named source) · 🔵 observed (this codebase) · 🟣 synthesis · 🟡 hypothesis · 🔴 unknown.

## 1. Short answer

🟣 One **inbox** for the team, made of queues, each with its **clock, a stated default if the clock runs
out, and the evidence needed on one screen**; **roles** so each person sees only what their work needs;
**a second person's approval** for money actions outside the automatic rules; an **audit log** of every
action; **urgent alerts** to phones and Slack with someone on call; and honest numbers (the slowest 10%,
not just the average) for every queue.

## 2. What exists (🔵)

- `king-domain-admin` (React web): Overview, waitlist Entries, Decisions and Ledger (shareholder decisions),
  Proof review, App releases, Team, Settings.
- Roles: **owner** (invites and revokes admins) and **admin** (read-only). Nothing in between.
- `king-domain-admin-mcp`: an MCP server through which Claude acts on the admin backend.
- Proof review approves or rejects (rejection deletes the item and emails the reason; proof-verification §2).
- Payout retries: a refused transfer is retried hourly up to 24 times, then left for an admin (payments
  rules). No queue shows it yet.

## 3. What good review operations do (🟢)

- **Targets you can keep**: measure for six to eight weeks before promising; one target per queue, stored as
  data; fix when the clock starts; report the **median and the 90th percentile** ("averages hide the slow
  tail, and the slow tail is where incidents come from"); count items still open past target as misses;
  pair every speed target with a quality check. A fast median with a slow tail usually means overnight
  items wait for the morning, and the fix is **on-call cover**, not more reviewers (Macchia, *The T&S
  Handbook*).
- **Design queues around the decision and the money**: one decision per queue; "pre-movement" queues (money
  still held) get tight targets; every queue states its **default when the target expires** (release,
  decline, extend, escalate) instead of leaving it implicit (Outlier Lab, alert review operations).
- **The case screen decides quality**: all evidence on one screen, a snapshot kept for later checks,
  **structured reason codes required** (free text alone isn't enough), one-tap common actions with
  confirmation on irreversible ones, **AI assistance clearly labelled with its sources one tap away**,
  access logging and least-privilege visibility (Outlier Lab; AppMaster).
- **Every action writes an audit event**: who (and their role at the time), when, what changed, why (a reason
  code and a note), which evidence (AppMaster).
- **Named owners and controlled actions**: write down who may refund, change a payout, restrict an account or
  reverse a decision; automation may prepare evidence, but a named person approves sensitive outcomes and
  stays accountable for the explanation (softservice, creator platform support).

## 4. The queues (🟣, from the decisions so far)

| Queue | Comes from | Target | If the target passes |
|---|---|---|---|
| **Chargebacks** | Paystack dispute webhook | Answer within **16 working hours** (Paystack) | Paystack auto-accepts and takes the money: alert everyone on call well before |
| **Safety reports** (scams, threats, outside payment, meeting in person) | D18, client trust §7 | Hours | The reported side's jobs are paused while it waits |
| **Start-proof objections** | D8 | 24 hours | The share stays held (no money moves until decided) |
| **First job posts from new clients** | D17 | Same day | The post stays hidden |
| **"Find someone for me" shortlists** | D24 | The published promise (90th percentile of the last 20) | Shown late to the client with a new time; counted as a miss |
| **Disputes** | D33 | Ruling within **5 days** | Escalated to the owner |
| **Identity and student checks** (manual until the provider is live, then the provider's exceptions) | D10–D14 | 24–48 hours | The person can still browse; paid actions wait |
| **Proof verification** (authenticity check, then two reviewers per skill, a third on disagreement) | D5–D9 | A few days; set after measuring | Shown to the talent as still in review with the expected date |
| **Payout failures** (retries exhausted) | Payments rules | Same day | Owner alerted |
| **Reported reviews** | D29–D31 | A few days | The review stays up until decided |
| **Training** (later phase) | D41 | — | — |

Every queue item opens a **case screen** with its evidence together (for a dispute: the brief, the
conversation, confirmed call summaries, the start proof, every delivery version), the AI model's summary
labelled as such, the allowed actions, and a required reason code.

## 5. People, permissions and money (🟣)

- **Roles** instead of owner/read-only: **owner**; **reviewer** (per skill, sees only proof in their skills);
  **checker** (authenticity, identity and student documents); **safety**; **disputes**; **finance** (refunds,
  splits, chargebacks, payout failures); **support**; **shareholder** (read-only: ledger, metrics, audit log).
  One person can hold several roles; each sees only what those roles need, and every opening of a private
  document is logged.
- **A second person approves money actions outside the automatic rules**: a manual refund, a split, a payout
  override, writing off a chargeback. The rules in the product (auto-release, the 20% start share, agreed
  splits) run on their own; anything a person decides about money needs a second team member's approval
  above a threshold (decision 2).
- **Audit log** of every admin action, kept unchanged, readable by owners and shareholders.
- **AI groundwork, people decide** (D7, D33): the AI prepares checklists, reverse image searches, timelines
  and draft reasons; a named person makes every decision about identity, money, safety or restrictions.

## 6. Alerts, cover and numbers (🟣)

- **Urgent items** (chargebacks, safety reports, payout failures) alert the people on call by push and in a
  Slack channel (Slack is the team's hub); everything else arrives as a daily digest.
- **On-call cover** for evenings and weekends, because Paystack's 16-hour clock and safety reports don't wait
  for the morning (decision 3).
- **The admin dashboard works on a phone**, since the team reviews on the move.
- **Numbers per queue**: median and 90th percentile time, misses, and a quality figure (for proof: how often
  the two reviewers agree; for disputes: how often a second admin would have ruled the same on a sample).
  The shortlist promise (D24) and talents' response times use the same honest method.

## 7. Decisions for Victor

1. **One team inbox** with the queues in §4 (each with its target and its default), case screens with the
   evidence together, and the roles in §5 replacing owner/read-only. Adopt?
2. **Second-person approval** for manual money actions (refunds, splits, payout overrides, chargeback
   write-offs). From what amount? Proposed: every manual money action, since the team is small and the
   automatic rules cover the normal cases.
3. **On-call**: who covers chargebacks and safety reports on evenings and weekends? A simple weekly rota
   between Victor, Balogun and Debbie?
4. **Urgent alerts** to phones and a Slack channel (for example `#alerts`), daily digest for the rest?

### Answered by Victor, 2026-10-31 (carry into the PRD as decisions)

- **D43.** One team inbox with the queues in §4, case screens with the evidence together, and the roles in
  §5 replacing owner/read-only.
- **D44.** Second-person approval for manual money actions **above an amount**. Victor gave no figure:
  **₦100,000 (assumed)** until he confirms.
- **D45.** A weekly on-call rota between Victor, Balogun and Debbie for chargebacks and safety reports on
  evenings and weekends.
- **D46.** Urgent alerts to phones and a Slack channel (e.g. `#alerts`); a daily digest for everything else.

## Sources

- Macchia, *The T&S Handbook*, ch. 7 "Standing up review operations"; The Outlier Lab, "Alert Review
  Operations"; AppMaster, "Content moderation queue design that stays consistent at scale" (2025); Digital
  Trust & Safety Partnership, "Best Practices for AI and Automation in Trust & Safety" (2024); softservice,
  "Creator platform customer support" (2026).
- This workspace: `king-domain-admin/src/pages`, `king-domain-backend/src/admin`, `prisma/schema.prisma`
  (AdminRole), `docs/core/payments.md`; Paystack chargeback deadlines (disputes §4).
