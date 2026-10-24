# Account deletion and the privacy policy

**Status (2026-10-24): backend, app and the two web pages are built and tested on local branches; nothing is
deployed.** Decided by Victor 2026-10-22: deleting an account is **blocked while the person has an active
contract** (as client or talent); the company named in the policy is **MJP Productions Limited**. Everything else
below is my proposal, marked **[confirm]**. Deploy needs: `User.deletedAt` pushed to staging (and later production),
backend and app builds, the web branch `privacy-pages` merged, and the lawyer's review of the policy first.

Why now: Google Play requires an in-app deletion path **and** a public web page where someone can ask for deletion
without the app, plus a public privacy policy link. Nigeria's NDPA 2023 gives people a right to have their data
erased, subject to what the law makes us keep. The policy itself needs a lawyer's review before launch (see the end).

## What deletion does

Deleting is **anonymise-and-remove**, not "drop the row", because a finished job is also a payment record and the
other person's work history.

| Data | Result |
|---|---|
| Sign-in (email, password, verification and reset codes, every session) | Gone. The email address is free to sign up again |
| Name on the account | Becomes **"Deleted user"** wherever the other side of a kept job sees it |
| Profile photo (file in the public bucket) | Deleted |
| Talent profile: headline, bio, skills, **bank details**, Paystack recipient | Deleted. The Paystack recipient is set inactive through Paystack's API |
| Proof items and their files (private bucket) | Deleted |
| Applications that did not win | Deleted |
| Waitlist sign-up with the same email | Deleted |
| A client's jobs that never had a contract and have no money trail | **Deleted** (their applications with them) |
| A client's jobs with no contract but a money trail (an award that was cancelled) | **Closed and kept** as a record, shown with "Deleted user" |
| Jobs with a finished contract, the contract, its events and the delivered files | **Kept**, with the person shown as "Deleted user". **[confirm]**: payment records and the other side's proof of work; the retention period is a lawyer question |
| Paystack's own records (transactions, transfers, customer email) | Stay with Paystack. Only they can erase them; the policy says so |

A confirmation email goes to the old address once it is done.

## The rule: no deletion with an active contract

"Active" is any contract that is not `approved`: awaiting payment, funded, in progress, submitted, changes
requested, disputed. The person is told which jobs, and how to resolve them (finish, or for an unpaid award wait
for the 24-hour window). **[confirm]**: awaiting payment counts as active, because a client who is about to pay
would otherwise delete the account under the talent.

### Race safety

An award or an application can arrive at the same moment as a deletion. Deleting takes the user row's lock first
(it marks `deletedAt`), then counts active contracts. Awarding, applying and posting a job take a shared lock on
the people involved and refuse if either is already deleted. So either the contract is created first (deletion
sees it and is refused) or the deletion commits first (the award is refused). No contract can end up pointing at
an anonymised person.

## Backend

- `User.deletedAt DateTime?` (additive schema change; staging and production need the push).
- `src/accounts.js`: `deleteAccount({ userId })` (all of the above in one transaction, then best-effort file and
  Paystack cleanup, logged with what was actually deleted), `lockLive` used by award, apply and post-job.
- `DELETE /users/me` with `{ password }`: re-checks the password (rate limited), answers 200, 401 wrong password,
  409 `active_contracts` with the list of jobs.
- `scripts/delete-user.js --email x --yes`: the same service, for requests that arrive by email (the web page).
- Cleanup that fails (storage or Paystack down) never undoes the deletion; the log line names the leftovers.

## App

Profile, bottom of the list: **Delete account** (danger row). A sheet says what is deleted and what is kept, asks for
the password, and on success signs out with a toast. With an active contract the server's answer is shown with the
jobs listed. The sign-up screen gets "By continuing you agree to the Privacy policy" (terms follow later). A
**Privacy policy** row links to the public page.

## Privacy policy and the web pages (`king-domain-web`)

Static pages in `public/privacy/` and `public/delete-account/` (the site is a single-page `vite-react-ssg` app;
static files avoid touching the router). The delete-account page tells people to use the app, or to email
**[confirm contact email: kingdomainapp@gmail.com]** from the address on the account; we delete within **[confirm: 30
days]** and confirm by email. It does not invent a form.

The policy names **MJP Productions Limited**, and lists what is really collected and who processes it: Brevo (email),
Sentry (errors), PostHog (the website only, no session replay), Supabase (database and files), Render (hosting),
Neon (database, staging only), Paystack (payments), Vercel and Cloudflare (website and app downloads). It states the
NDPA rights, the 72-hour breach notice, how to complain to the NDPC, and what is kept after deletion and why.
**Terms of service are not drafted:** they depend on the payment and dispute model, which is still open, and a
published draft would settle those decisions by accident.

## Not in this work, and flags

- **Lawyer review** of the policy and of retention periods, and whether MJP must register with the NDPC as a
  data controller of major importance (needs a lawyer or the NDPC's thresholds, not a guess).
- **Things the policy states that Victor must confirm before it goes live:** the contact email, "within 30 days" for
  email requests, that MJP Productions Limited is "registered in Nigeria" (the CAC filing is still being corrected),
  and that there is **no age rule** written anywhere. Whether under-18s may sign up is a product and legal decision;
  the policy is silent on it, which a lawyer will likely want filled.
- **Emails are shown to the other side** (verified in `jobsRoutes.js`): every student who views a job gets the client's
  name, photo **and email**; a client gets an applicant's. The policy says so because it is true. A product decision
  whether to show email only after an award would let the policy say less.
- **The app downloads its fonts from Google at runtime** (`google_fonts`, nothing bundled), so Google sees each
  phone's address. The policy discloses it. Bundling the fonts removes it and also makes first launch work offline.
- Proof files are not private from clients: a client sees up to three verified proof files of an applicant in the job's
  category. The policy says that. Their deletion with the talent is covered.
- Database backups (Neon, Supabase) hold deleted data until they expire; the policy says so, without a number.
- Exports ("give me my data") are a separate NDPA right; not built. The policy tells people to email.
- The pages are static HTML on branch `privacy-pages` of `king-domain-web`; not yet built with the site or opened in
  a browser. They load no scripts and no external files, so the policy page itself tracks no one.

## What was verified (2026-10-24)

Backend, over real HTTP, fake Paystack, fake storage, disposable users: 16 tests in `test/accountDeletion.test.js`
(rules, what goes and stays, cleanup failures, three race interleavings, rate limit, the script). A mutation that
turned the lock into a no-op failed all four race tests. The 37 existing jobs tests still pass. App: 10 widget tests
and 5 client tests. Not run: the full suites (end of sprint).
