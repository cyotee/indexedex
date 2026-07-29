# Mission: DETF Threshold Modes — P0 Core Lib only

Copy this entire file into a new agent session.

You are an **execution agent**. Implement production code and tests for **one phase only**. Do not re-open product decisions.

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` (product law + **§16** encoding locks)
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (single execution tracker — update as you go)
3. `contracts/vaults/detf/core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` (**this is your plan**)
4. Current lib: `contracts/vaults/detf/core/DETFThresholdPolicy.sol`
5. Repo `Agents.md` / `AGENTS.md` (production-first, role names, no `new` for vault packages — pure lib is fine)

## Scope (strict)

- **In scope:** extend `DETFThresholdPolicy.sol` + pure Foundry unit tests only.
- **Out of scope:** F1/F2/F3 package wiring, TestBase changes, facets, events on diamonds, AGENTS.md marketing notes, claim redeem, UI.

## Locked product rules (do not re-litigate)

- `enum ThresholdMode { Policy, Open }` — Policy=0, Open=1
- Core lib owns: enum, `DEFAULT_MINT_THRESHOLD` / `DEFAULT_BURN_THRESHOLD` (1.05e18 / 0.95e18), `resolveThresholds`, mode-aware allow helpers
- Allow helpers: **no `live` param**; Open short-circuits to true; Policy uses strict `>` mint / `<` burn
- Keep **2-arg** Policy wrappers so unported families still compile
- Resolve: `0 → defaults`; validation helpers for mint > burn and valid mode (per plan)
- Families must not reimplement Open short-circuit or defaults

## Process

1. Set P0 to `in_progress` in `DETF_Threshold_Modes_PROGRESS.md` (date + note).
2. Implement exactly per the core lib plan (API signatures, errors, overloads).
3. Add pure unit tests (no diamond / no CraneTest required) as mapped in the plan.
4. Run and keep green:
   ```bash
   forge test --match-path 'test/foundry/spec/vaults/detf/core/DETFThresholdPolicy.t.sol' -vv
   forge build
   ```
   Optionally smoke that existing DETF callers still compile after 2-arg wrappers.
5. When definition-of-done in the plan is met, mark P0 `done` in the progress tracker (date + brief notes). Leave P1+ as `todo`.
6. Stop. Do not start F1.

## Success

- P0 checklist in the plan + tracker definition of done is complete
- Tests you claim green were actually run
- No product re-opens; no family package work in this session
