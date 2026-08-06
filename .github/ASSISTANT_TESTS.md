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
- Workflow: `.github/workflows/foundry-ci.yml` (see `docs/ci.md`).
  - Hermetic: `FOUNDRY_PROFILE=ci forge test` (no secrets).
  - Fork: `FOUNDRY_PROFILE=ci_fork forge test` with repository secret `ALCHEMY_KEY` (raw key only).
- Do not mock SUT vaults/manager/registry in new tests; prefer production-first TestBases.
- Package-isolated profiles (`FOUNDRY_PROFILE=…` in `foundry.toml`) are not all run on every PR; add matrix jobs intentionally.
