# Assistant Testing & CI Rules

Testing conventions for the repository and for assistant-implemented changes.

Core rules
- Always run `forge build --use solar` and `forge test --use solar` locally in the workspace before opening a PR. Compiler law: [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../docs/agent/INDEXEDEX_AGENT_LAW.md) § Compiler. Do not compile with solc. Do not enable `via_ir`.
- Focused tests: when adding a new package or facet, add a focused test asserting critical behaviors (for example: token metadata for deployed DETF instances).

Test scope & location
- Add unit tests under `test/foundry/spec/...` matching existing repo layout.
- When extending an existing module (e.g., `BalancerV38020WeightedPoolMath`), add tests to the same test file to keep math logic collocated.

Policy checks
- Add tests asserting repository-level policies when feasible (e.g., test that deployed vault `symbol()=="DETF"` and `decimals()==9`).

CI
- CI must run `forge build --use solar` and hermetic `forge test --use solar` and fail the PR if those fail. The workflow installs Foundry nightly until stable Forge accepts `--use solar`.
- Workflow: `.github/workflows/foundry-ci.yml` (see `docs/ci.md` Profile law).
  - Hermetic only: `forge test --use solar` under **default** (`test/foundry/spec`) — no secrets, empty RPC env.
  - Fork suites (`FOUNDRY_PROFILE=fork` / `test/foundry/fork/**`) are **not** run on Actions.
  - CI excludes `**/fork/**` and `*Fork*` under `spec` so misplaced fork smokes never hit Alchemy.
  - Run fork suites **locally only** with `ALCHEMY_KEY` when needed — not in CI, to protect RPC rate limits.
  - Vercel deploys are **not** gated on this workflow.
- Do not mock SUT vaults/manager/registry in new tests; prefer production-first TestBases.
- **Do not add package Foundry profiles.** Focus with `--match-path` / `--match-contract` only.
