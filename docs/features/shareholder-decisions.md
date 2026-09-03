# Shareholder Decisions — Feature Plan

**Status:** Planned, not built.
**Owner:** Samuel (owner role in admin).
**Why this exists:** MJP Productions has multiple shareholders in King Domain, not just
Samuel. Right now, decisions get made verbally in weekly meetings, which means every
shareholder is seeing a decision for the first time in the room — discussion and
correction that could have happened async instead eats meeting time. This feature moves
that async: shareholders see a decision the moment it's posted, register a stance and
comments on their own time, and the meeting becomes "resolve the flagged disagreements,"
not "explain the decision from scratch."

This is additive to the [Marketplace Decision Ledger](../../) artifact (the 7-milestone
product-vision ledger). That artifact stays the narrative record of *product* decisions
tied to the vision doc's sequence. This feature is the operational tool: any decision,
big or small, gets a real record with a stance and a comment thread, optionally linked
back to a ledger milestone when relevant.

---

## Who does what

Reuses the existing `AdminUser` roles — no new role introduced.

| Role | Can do |
|---|---|
| **Owner** | Create decisions, edit/close a decision, everything an admin can do |
| **Admin** (shareholders) | View decisions, comment, cast a stance, receive notifications |

This mirrors how the admin's existing `Team` page already works (owner invites/revokes;
admin has read access to waitlist data) — same permission shape, new resource type.

## Core model

### Decision

A decision is a single record: a title, a description (what's being decided and why),
an optional link to a Decision Ledger milestone (01–07, or none), a status, and a
timestamp.

- **Status**: `open` (accepting stances/comments) → `closed` (Samuel has made the call —
  the record stays, but voting/commenting locks). Closing a decision is not the same as
  "everyone agreed" — it just means discussion is done and the call has been made,
  consistent with "most decisions will be made on my own depending on the scale of it."
  **Reopenable**: closing is an owner action, not final. Mis-closes happen, and real
  decisions sometimes get revisited — reopening sets `status` back to `open` and clears
  `closedAt`, logged the same as any other owner action (who reopened it, when). This
  resolves the open question that was originally left for later in this doc.
- Decisions are **owner-only to create**. This isn't a democratic proposal system —
  shareholders respond to decisions, they don't open their own. That was an explicit
  choice: keeps the record clean, avoids decision-sprawl, matches how authority actually
  works in this company (Samuel owns a majority stake and makes the call on most things).

### Stance

Each admin can cast exactly one stance per decision, and can change it any time while
the decision is `open`:

- **Agree**
- **Disagree**
- **Need discussion** — the one that matters most operationally. This is the signal
  that tells Samuel, before the meeting even starts, which decisions actually need
  verbal time and which ones can just be noted and moved past.

Changing a stance after commenting is fine and expected — people update their position
as a thread develops.

### Comment

Free-text, threaded under a decision (flat, not nested — matches the simplicity of the
existing admin UI, no need for deep reply chains on a 3-8 person shareholder group).
Any admin (including the owner) can comment on an open decision.

## Screens (admin dashboard)

| Screen | Purpose |
|---|---|
| **Decisions list** | All decisions, newest first. Each row shows title, status, milestone link (if any), and a compact stance summary (e.g. "3 agree · 1 disagree · 1 need discussion"). |
| **Decision detail** | Full description, the milestone link (if set), the stance breakdown with names attached (not anonymous — this is a small trusted group, not a public poll), the comment thread, and the current admin's own stance selector. |
| **New Decision** (owner only) | Title, description, optional milestone link, publish. |

No separate "my decisions" or dashboard widget for v1 — the Decisions list is the whole
surface. Add a summary card to Overview later if it earns its place once there's usage
to look at.

## Notifications

Two triggers, both real signal rather than noise:

1. **New decision posted** → every admin gets notified immediately. This one's rare
   enough (owner-only, not high-frequency) that instant delivery is fine.
2. **New comment on a decision they haven't cast a stance on yet** → nudges the people
   who haven't weighed in, specifically. Someone who already voted doesn't get pinged
   for every reply in a thread they're already following.

   **Batched, not instant**: a burst of several comments on one thread within a short
   window shouldn't fire one email per comment to the same still-silent person — that's
   the fast path to the feature getting muted. Comments are collected into a queue per
   (decision, recipient) pair and flushed as a single digest email after a delay window
   (start at 4 hours; tune once there's real usage to look at) — "N new comments on
   *[decision title]* since you last checked," not a blow-by-blow.

Delivered via the existing Brevo mailer (`src/admin/mailer.js`) — same pattern as
invite/reset emails, same graceful fallback (logs instead of sending if unconfigured).
The batching queue can be a simple table (`pending_notification`, decision + recipient +
first-queued-at) drained by a scheduled job, rather than anything more elaborate — this
doesn't need a real task queue for a handful of shareholders.

## Why this isn't a public voting/governance system

Worth being explicit about the boundary, since "voting" can imply more than what this
is: this doesn't allocate actual equity-weighted votes, doesn't have quorum rules, and
doesn't bind Samuel to the majority stance. It's a **structured async discussion tool**
that makes disagreement and silence visible before a meeting, not a formal governance
mechanism. That distinction matters because building actual equity-weighted binding
voting would be a much bigger, more legally-loaded feature than what was actually asked
for — this stays in scope as a communication tool.

## Data model sketch (Prisma, king-domain-backend)

Not final — this is the shape to validate against once we start building, not a locked
schema. Recorded here so the plan is concrete enough to review, not just prose.

```prisma
enum DecisionStatus {
  open
  closed
}

enum Stance {
  agree
  disagree
  need_discussion
}

model Decision {
  id          String         @id @default(uuid())
  title       String
  description String
  milestoneRef String?       // e.g. "01", "02" — free string, not a foreign key;
                              // the ledger lives in an artifact, not this database
  status      DecisionStatus @default(open)
  createdById String
  createdBy   AdminUser      @relation(fields: [createdById], references: [id])
  createdAt   DateTime       @default(now())
  closedAt    DateTime?

  stances     DecisionStance[]
  comments    DecisionComment[]

  @@map("decisions")
}

model DecisionStance {
  id         String   @id @default(uuid())
  decisionId String
  decision   Decision @relation(fields: [decisionId], references: [id], onDelete: Cascade)
  userId     String
  user       AdminUser @relation(fields: [userId], references: [id])
  stance     Stance
  updatedAt  DateTime @updatedAt

  @@unique([decisionId, userId]) // one stance per person per decision
  @@map("decision_stances")
}

model DecisionComment {
  id         String   @id @default(uuid())
  decisionId String
  decision   Decision @relation(fields: [decisionId], references: [id], onDelete: Cascade)
  userId     String
  user       AdminUser @relation(fields: [userId], references: [id])
  body       String
  createdAt  DateTime @default(now())

  @@map("decision_comments")
}
```

## Build order

1. Schema + migration (`npm run db:push`, per the existing Prisma-on-Supabase gotchas
   documented in `king-domain-backend`), including the notification queue table.
2. Backend routes: `POST/GET /admin/decisions`, `POST /admin/decisions/:id/stance`,
   `POST /admin/decisions/:id/comments`, `POST /admin/decisions/:id/close`,
   `POST /admin/decisions/:id/reopen`.
3. Notification wiring into the existing mailer: instant send for new decisions, queue
   insert for comments, plus a scheduled job that drains the queue into digest emails.
4. Admin frontend: Decisions list + detail + New Decision form.
5. Real end-to-end test with at least two admin accounts (Samuel + one real shareholder)
   before calling it done — a feature whose entire point is multi-person use needs to
   actually be tested with more than one person.

## Reviewed

External review (2026-09-03) confirmed the shape and prompted two changes, both folded
in above: closing a decision is reversible (owner-only, logged), and comment
notifications are batched into a delay-window digest per (decision, recipient) rather
than sent instantly per comment.
