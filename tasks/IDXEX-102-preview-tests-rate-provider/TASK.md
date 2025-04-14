Title: Add preview/execution tests for rate-provider tokens
ID: IDXEX-102
Status: Ready
Priority: Medium
Dependencies: IDXEX-064

Summary
- Add tests that deploy a pool containing a rate-provider token (yield-bearing), ensure preview uses balancesRaw and matches execution for several scenarios.

Problem
- Rate-provider tokens (tokens where token balance != underlying assets due to a rate) can cause previews to diverge from execution if preview uses normalized balances. Tests are required to ensure parity for these tokens.

Goal
- Add unit tests covering pools with rate-provider tokens and assert preview/execution parity across non-empty, near-empty, and initialized/uninitialized pools.

Acceptance Criteria
- Tests exercising tokens with rate providers are added and pass in CI.

Notes
- Depends on IDXEX-064 which fixed the balance source.
