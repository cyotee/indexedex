# REQ-SEP-04 execution report

- Date: 2026-10-16
- Authorization: owner requested execution of `REMEDIATION_PRD.plan.md` in this session.
- Status: all specified wording edits applied; required root build running.

## Changes

Applied the plan’s exact EI/EI-SHARE wording and the specified README, C10, D2, D3, and D12 replacements. No executable Solidity, signature, selector, or test changes were made by this task.

| Row | Changed file |
| --- | --- |
| C1 | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol` |
| C2 | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol` |
| C3 | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol` |
| C4 | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol` |
| C5 | `contracts/interfaces/detf/IDetf.sol` |
| C6 | `contracts/interfaces/IRebasingClaimToken.sol` |
| C7 | `contracts/interfaces/IStandardExchangeInMulti.sol` |
| C8 | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` |
| C9 | `contracts/vaults/basic/BasicVaultCommon.sol` |
| C10 | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` |
| C11 | `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol` |
| D1 | `contracts/vaults/standard/exchange/protocols/uniswap/README.md` |
| D2 | `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` |
| D3 | `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md` |
| D4 | `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` |
| D5 | `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md` |
| D6 | `docs/agent/INDEXEDEX_AGENT_LAW.md` |
| D7 | `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md` |
| D8 | `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md` |
| D9 | `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` |
| D10 | `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` |
| D11 | `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` |
| D12 | `docs/plans/UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md` |
| D13 | `docs/plans/UNISWAP_V4_CLOSED_FORM_CANDIDATE_VALIDATION_AGENT_PROMPT.md` |

The execution report is the only new review document. Existing review, research, and audit records were preserved. The deleted legacy V4 family and Slipstream were not edited or restored. No skill synchronization was run.

## Crane submodule

- Previous pin: `212aea6d73b840345bc4198cb7d58e1380434f37`.
- New local commit: `2d626b3663a22281587cb34ac0ac271e968ee3cd` (`docs: clarify declared-bound exact-input credit`).
- The commit changes only the C8 NatSpec sentence in Crane’s `contracts/interfaces/IStandardExchangeIn.sol`.
- IndexedEx’s `lib/crane` gitlink is staged at the new commit. The IndexedEx re-export is unchanged. No push or parent repository commit was performed.

## Verification

- All 24 C/D rows checked; exact EI/EI-SHARE occurrence counts verified, including all 18 Balancer comment blocks.
- All 11 changed Solidity files have identical executable token streams before and after comment removal.
- README lines 3, 34, and 56 and the short-push revert sentence are preserved. BasicVault lines 17, 69–70, and 113 and C10’s following clauses are preserved.
- D2 historical tails are unchanged. D3 differs only by the prescribed current-law note; all historical records are retained.
- Scoped `git diff --check` passed.
- SHA-256 comparison confirmed every other existing tracked file matched the pre-edit snapshot, including tests, unrelated changes, configuration, and the IndexedEx interface re-export.
- Behavioral tests were not run, as directed by this wording-only plan.

## Build

- Command: `forge build`, run from the IndexedEx repository root.
- Profile: default (`FOUNDRY_PROFILE` and `FOUNDRY_VIA_IR` unset; configured `via_ir = false`).
- Existing `out/` and `cache_forge/` were retained.
- Result: pending.
- Build log: `/private/tmp/sep04-execution-4p6mf4he/forge-build.log`.

## Worktree evidence

The starting worktree contained extensive unrelated modifications and deletions. They were preserved. Initial status, unstaged and staged patches, original target contents, tracked-file hashes, the task-only patch, and validation results are recorded under `/private/tmp/sep04-execution-4p6mf4he/`:

- `status-before.txt`, `diff-before.patch`, `staged-before.patch`, `crane-status-before.txt`
- `before.json`, `paths.json`, `wording.json`, `tracked-hashes-before.json`
- `task.patch`, `validation.txt`
