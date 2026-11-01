# S5: contracts and money (what was built, and what was not)

PRD §3.1 steps 10 to 13, §4.2, §4.9, §4.10; decisions D2, D8, D22, D35, D37. Backend, admin and app are all on the
`s0-foundations` branches, local only.

## Built

**The start proof and the first 20%.**
- After a skill job is paid, the talent cannot deliver until the **start proof** is accepted. It is a fixed format per
  skill (`startProof` in `src/skills.js`): files, a picture, a video, typed text or a link, each with a minimum and a
  maximum. The server checks the count and the type; the app shows exactly what is missing before Send is enabled.
- Files go from the phone straight to the private bucket (the same direct upload as S2) and are checked by size on the
  way in; a failed upload leaves no half-made row.
- The client has **24 hours** to accept or raise a point. **Silence accepts** (`START_PROOF_AUTO_ACCEPT=false` turns
  that off). Accepting pays the talent **20% of the price** at once; approval later pays only the rest.
- A client can object only from a **checklist** (a part is missing, wrong format, wrong work, not their work, cannot be
  opened). Quality and taste are not on it. A person on the **Disputes** capability checks the proof against the skill's
  format in the dashboard (Start proofs) and either upholds the objection (the proof goes back to the talent as a new
  round) or dismisses it (the 20% is paid). Every ruling is audited and needs a written note.
- Money follows the existing payout pattern: claim first, one Paystack transfer reference per attempt
  (`kd_upfront_<contract>_<n>`), never a second transfer on top of a live one, status read back after.
- Jobs without a skill (posted before skills existed) have no start proof and behave exactly as before.

**Drafts.** The talent can share work in progress during the job. It starts no clock, asks nothing of the client, and
is kept dated as evidence. The client is notified.

**Receipts.** A plain record per paid job: service, client, talent, price, fee, total paid, date, Paystack reference,
and (for the talent) the payouts. `GET /jobs/:id/contract/receipt` and `GET /jobs/receipts/mine`.

**Display currency (D37).** A person chooses naira or dollars for what they read. Amounts in the other currency get an
"about" line using a rate the team sets by hand (`FX_NGN_PER_USD`, `FX_AS_OF`). With no rate nothing is converted.
Money is always paid in the job's own currency.

**The gate on what cannot be paid for yet.** Milestone, monthly and hourly jobs, and dollar jobs, are refused at
posting and at award with a plain reason, and the app shows them as "not available yet" instead of offering them.
`JOB_TYPES_ENABLED` and `USD_JOBS_ENABLED` switch them on once their money flow exists.

## Not built (cut, so nothing is silently missing)

- **Milestone, monthly and hourly funding and release.** Each funds and releases per unit (a milestone, a month, a
  week). The data model and the brief forms exist (S3); the money does not. Posting them is refused until it does.
- **Dollar payments.** Paying by card in dollars, and paying talents in naira at the day's rate, needs a partner for
  dollar payouts (open item) and a rates source. Dollar jobs are refused until then.
- **The refund when a talent stops after the start proof.** The rule is written (the client keeps the start-proof work
  and gets the other 80% back; the 20% is not refunded) and said before payment, but the refund itself belongs to
  disputes and cancellation (S6).
- **A message button inside the contract room.** The Messages tab reaches the same person; the contract room does not
  link to the conversation yet.
- **Email for the start proof.** The client and talent are told by push and see it in the app; no email template was
  added.
- **A live rates provider.** The rate is set by hand.

## Open decisions this touches (flagged, not settled)

- Whether the 20% should ever be paid when a client's objection is upheld and the talent never fixes it (today the job
  stays unpaid at the 20% until the talent sends a proof that passes; nothing times it out).
- Whether the 24 hour silence rule should apply on weekends and public holidays.
- The payout fee: Paystack's transfer fee is paid by King Domain per transfer, so splitting the payout in two costs
  one extra fee per job. Not modelled in the price.
