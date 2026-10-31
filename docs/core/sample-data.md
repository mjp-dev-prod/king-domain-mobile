# Sample data while the backend catches up

Status: convention, adopted in S0 (2026-10-31). Applies to every slice in `docs/core/prd.md` §8.

Some screens are built before their endpoints exist. They still behave for real against a store; only the
store's source differs.

1. Each feature reads and writes through an interface: `abstract interface class DisputeStore { DataSource get source; … }`.
2. Two implementations: `ApiDisputeStore` (the real API, `source == DataSource.live`) and `SampleDisputeStore`
   (`source == DataSource.sample`, rules applied in memory exactly as the backend will apply them).
3. The provider returns the API store. A sample store is used only when its endpoint does not exist yet **and**
   `sampleDataAllowed` is true (a non-production server); otherwise the screen shows its normal error state.
4. Every screen whose store is a sample shows `SampleDataNotice(source: store.source, what: '<feature>')` at the top.
5. When the endpoint ships, the provider switches to the API store and the sample store is deleted in the same
   change. No sample store survives its endpoint.
6. A sample store is never a fake shortcut for behaviour (CLAUDE.md hard rule 4): it implements the same rules and
   states, so the screen is finished when the API arrives.
