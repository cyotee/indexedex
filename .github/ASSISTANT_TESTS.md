# Assistant Testing & CI Rules

Testing conventions for the repository and for assistant-implemented changes.

Core rules
- Always run `forge build` and `forge test` locally in the workspace before opening a PR.
- Focused tests: when adding a new package or facet, add a focused test asserting critical behaviors (for example: token metadata for deployed DETF instances).

Test scope & location
- Add unit tests under `test/foundry/spec/...` matching existing repo layout.
- When extending an existing module (e.g., `BalancerV38020WeightedPoolMath`), add tests to the same test file to keep math logic collocated.

Policy checks
- Add tests asserting repository-level policies when feasible (e.g., test that deployed vault `symbol()=="DETF"` and `decimals()==18`).

CI
- CI must run `forge build` and hermetic `forge test` and fail the PR if those fail.
- Workflow: `.github/workflows/foundry-ci.yml` (see `docs/ci.md` Profile law).
  - Hermetic only: `forge test` under **default** (`test/foundry/spec`) — no secrets, empty RPC env.
  - Fork suites (`FOUNDRY_PROFILE=fork` / `test/foundry/fork/**`) are **not** run on Actions.
  - CI excludes `**/fork/**` and `*Fork*` under `spec` so misplaced fork smokes never hit Alchemy.
  - Run fork suites **locally only** with `ALCHEMY_KEY` when needed — not in CI, to protect RPC rate limits.
  - Vercel deploys are **not** gated on this workflow.
- Do not mock SUT vaults/manager/registry in new tests; prefer production-first TestBases.
- **Do not add package Foundry profiles.** Focus with `--match-path` / `--match-contract` only.
