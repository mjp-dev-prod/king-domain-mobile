# How Spotify Verifies Student Status (via SheerID) — and What It Means for King Domain

**Date:** 2026-09-13
**Why this exists:** Director Sam asked how Spotify confirms someone is actually a
student, and specifically whether dropouts/expelled students could keep the discount.
This is directly relevant to King Domain's own unresolved "exact verification
mechanics" question (`Student_Talent_Marketplace_Product_Vision_v0.1.pdf` §13 — an
explicitly open decision), so it's written up here rather than only answered in chat.

**Sources:** SheerID's own site, Knowledge Base, and Developer Center — linked inline.
Where SheerID doesn't publish something (which is itself a finding), that's stated
plainly rather than guessed at.

---

## The direct answer to Sam's questions

**"Do they have access to the school database?"** — Sometimes, not always. SheerID
offers four verification methods, used depending on the school and country
([SheerID Knowledge Base](https://sheerid.zendesk.com/hc/en-us/articles/26408738570779-Student-Verification-FAQ)):

1. **Authoritative data sources** — a direct data connection to the school or a
   third-party enrollment database (SheerID's marketing claims "200K+ data sources"
   globally — [sheerid.com/audience-students](https://www.sheerid.com/audience-students/)).
   This is the closest thing to "do they have access to the school's database," and
   it's real, but SheerID doesn't publish which specific schools/countries have this
   live connection versus which don't.
2. **Single sign-on (SSO)** — the student logs into their actual school portal
   through SheerID, proving enrollment via the school's own login system rather than
   an uploaded document.
3. **Email loop** — verification via a `.edu`-style institutional email address.
4. **Document review** — the fallback: the student uploads a student ID, enrollment
   letter, class schedule, or tuition receipt, and it's reviewed (see below).

**"So some automated tool reads it, right?"** — Yes, first pass is automated
[optical/data extraction against the uploaded document], and if that can't confirm it
instantly, it escalates to **human document review**
([sheerid.com](https://www.sheerid.com/audience-students/) + corroborated by direct
support/FAQ pages). SheerID does not publish the exact automation vs. human split.

**"How are they able to confirm the cards are not fake?" / catching dropouts —
the actual mechanism found:** SheerID checks the **date on the document**, not when it
was uploaded or printed. Per their own support documentation: *"SheerID reviews the
date of enrollment, not the print date or view date. For example, your transcript may
have been printed yesterday, but it shows that your most recent enrollment in classes
was a previous term."* This is how a graduated or dropped-out student holding an old,
real ID card gets caught — the card itself might be genuine, but the enrollment date
on file doesn't match "currently enrolled," so it fails review. Graduation status
specifically has its own separate verification product SheerID sells
([search result summary, sheerid.com](https://www.sheerid.com/audience-students/)).

**Can a fake/forged ID beat this?** SheerID doesn't publish its fraud-detection
methodology (a deliberate opacity — publishing exactly how forgery detection works
would help people beat it). What's confirmed instead is the structural reason forgery
is hard to sustain at scale: when the "authoritative data source" method is available
(direct connection to the school or a national enrollment registry), there's no
document to forge at all — the check is against real institutional records, not a
photo. Document upload is the fallback used specifically *because* that direct
connection isn't available everywhere.

## The one finding most relevant to King Domain specifically

**SheerID's own documentation explicitly states it cannot verify homeschool
students "because central databases and standardized documentation do not exist"
for them.** This is a direct, named admission that their entire model — even the
"200K+ data sources" version — depends on a **centralized, queryable institutional
record existing somewhere**. Where that record doesn't exist, SheerID's own stated
answer is: it can't verify that population at all, not "we found a clever
workaround."

This matters directly for King Domain's Nigerian context: SheerID advertises coverage
in 191 countries (including Nigeria, per general UN-country coverage — no
Nigeria-specific documentation was found confirming which verification method is live
there), but the *quality* of that coverage almost certainly depends on whether a given
Nigerian university has a centralized, digitized, externally-queryable enrollment
system SheerID can connect to via "authoritative data sources," or whether it falls
back to manual document review. No source found confirms which Nigerian universities
(if any) have the former.

## Direct implication for King Domain's own verification design

This is exactly the open question the vision doc leaves unresolved (§13:
"exact verification mechanics"). What this research adds:

- **Don't assume a school-database API connection is available or reliable for
  Nigerian universities by default.** SheerID — a company whose entire business is
  this exact problem, at far larger scale and budget than King Domain — still falls
  back to manual document review as one of its four core methods, and explicitly
  cannot verify populations without a centralized record.
- **The realistic, buildable version of "verify student status" for King Domain's
  first wedge is document review by a human, checking the enrollment date on the
  document against "currently enrolled"** — the same mechanism SheerID uses as its
  fallback, and the same mechanism already correctly built into the Flutter app's
  proof-review flow (human review, not an automated database check).
  Building a direct university-database integration is a real, much later
  possibility — not something to assume as available for the first version.
  See `docs/core/vision-vs-research-reconciliation.md` §3 for how this connects to
  the "verification, not assessment" trust mechanism already decided for the wedge.
- **A dropout/expelled student with a real, unexpired-looking ID is a real, admitted
  gap even for SheerID** — their own fix (checking the enrollment date on the
  document, not the card's physical validity) is directly copyable: King Domain's
  human reviewer should be checking for a *current-term* enrollment document
  (registration receipt, current class schedule, current-dated enrollment letter),
  not just any student ID card, which can outlive someone's actual enrollment.

## Sources

- [SheerID — Student Verification Solutions](https://www.sheerid.com/audience-students/)
- [SheerID Knowledge Base — Student Verification FAQ](https://sheerid.zendesk.com/hc/en-us/articles/26408738570779-Student-Verification-FAQ)
- [SheerID Knowledge Base — Countries and languages](https://sheerid.zendesk.com/hc/en-us/articles/13361305135899-Countries-and-languages)
- [SheerID — press release, verification in 191 countries](https://www.sheerid.com/business/blog/sheerid-announces-student-verification-worldwide/)
- [SheerID Developer Center](https://developer.sheerid.com/)
