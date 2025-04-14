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
- CI must run `forge build` and `forge test` and fail the PR if tests fail.
