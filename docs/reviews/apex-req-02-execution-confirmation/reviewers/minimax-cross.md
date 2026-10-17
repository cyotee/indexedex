# MiniMax M3 — REQ-02 execution cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No peer plan, peer cross, or REMEDIATION_PRD.md under `apex-req-02-execution-confirmation/` was read. I did not read `docs/reviews/apex-req-02-execution-confirmation/REMEDIATION_PRD.md` per the coordinator instruction.
- **Target:** current IndexedEx working tree, current state 2026-10-14.
- **Question:** agreements and dissent on whether the plan was executed completely, and on whether Case 2's checked-arithmetic donation is incorrect execution.

## Re-reads this round

- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol:133-182` (the Case 1 / Case 2 helpers and the `expectCall` pin).
- `contracts/test/stubs/SimpleYieldERC4626.sol:102-106, 114-116, 186-190` (the `convertToShares` checked arithmetic, the `previewDeposit` path, and the `simulateYield` transition).
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:35-70, 102-104` (the SE preview path that lands on `vault.convertToShares`).
- The peer originals' verdict tables and reasoning.

## (1) Was the plan executed completely?

**Agree with all three peers.** The plan's done-when list is satisfied against the current source and tests. I re-read the four sweep copies and the new test file this round; the only production edit is the visibility change in `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384` (now `internal view`), and `bufferQuotedResidual` at `:393` is still `external`. The four sweeps at `DepositCommon.sol:367-379`, `WithdrawalLib.sol:131-142`, `Target.sol:388-400`, `SeTarget.sol:477-489` still call `ClaimLib.previewResidualBuffer(excess)` and keep `if (preview == 0) return` and `bufferQuotedResidual` only after a positive quote. The new test file `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol` has four witnesses (`depositWithSeShares` zero at `:47-68`, `withdrawSeShares` zero at `:71-91`, `depositWithSeShares` revert at `:94-106`, `withdrawSeShares` revert at `:109-122`) plus a no-selector loupe check at `:125-131`. The monolith and `SeTarget` copies are cited as unreached at `ResidualPreview.t.sol:20-21` and are not given a new entry. `evidence/focused-tests.log:37-64` records 21 passed, 0 failed.

I do not dissent on completeness. I do not run Forge this round; the green count is the prior session's reported run, not a new run I produced.

I also note, like the three peers, that one minor process observation carries forward from my own original: the `apex-req-02-execution-confirmation/` directory named in the task exists in the round but contains only the four reviewer files plus my own original; the plan, PRD, execution report, and evidence all live under `apex-req-02-residual-preview-internal/`. The three peers also recorded this; I do not re-litigate it.

## (2) Is Case 2's checked-arithmetic donation incorrect execution?

**Agree with all three peers that Case 2 is not incorrect execution.** The construction reads as on-bounds per the plan and PRD.

The plan text (lines 86, 89) requires a state the bound SE supports in which `previewExchangeIn` of the sweep's excess reverts, forbids "mocking the vault," and forbids "faulting a harness `balanceOf`." The PRD (lines 102-103) restates these as the same three prohibitions.

The witness at `_prepareRevertingQuote` (`ResidualPreview.t.sol:156-163`) does none of the three prohibited things:

- It does not mock the vault. `SimpleYieldERC4626` is the real, unchanged harness receipt deployed by the TestBase (`TestBase_...:88`).
- It does not fault a harness `balanceOf`. The test exercises the production `convertToShares` checked multiplication at `SimpleYieldERC4626.sol:102-106` (`return (assets * supply) / totalAssetsStored;` with Solidity's checked `*`), not `balanceOf`. The follow-on call to `convertToShares` is the actual production code path the SE's `_previewExchangeIn` lands on at `ERC4626StandardExchangeCommon.sol:52`.
- It does not add a token or vault that exists only to throw. The same `pairToken` and the same `SimpleYieldERC4626` are used in Case 1 and the existing deploy / SE matrix tests; Case 2 only changes the donated amount, not the dependency.

The amount boundary is the smallest `excess` that causes `assets * supply` to overflow (`type(uint256).max / pairProtocolVault.totalSupply() + 1` at `:157`). The same boundary is reached by the EVM's checked arithmetic on a real production vault, not by a test stub. The plan line 86 admits "another rejection the production vault already exposes"; the EVM-enforced overflow is such a rejection.

The witness also pins the path. `_expectSweepQuote` at `:173-181` calls `vm.expectCall` on the SE's `previewExchangeIn` and on `convertToShares`, each at count 1, so an earlier parent-quote revert cannot satisfy the test. The pre-parent precondition at `:160-162` confirms the same excess reverts on the direct call before the parent is invoked. Rollback assertions at `:205-213` cover pair, raw, SE shares, LP balance, and LP supply.

Kimi records one judgment note: "Whether an overflow-magnitude donation is 'a state the vault already supports' in the plan's intended sense is a coordinator/owner reading; I record the question and do not score it as incorrect execution." I agree with the disposition. The plan's "vault already supports" phrasing admits both domain-state rejections (pause, disable) and arithmetic rejections the production vault exposes. The receiving vault here is `SimpleYieldERC4626` — the production harness whose `convertToShares` is called on every preview path — and its checked arithmetic is a real property the fixture exposes. Kimi's "faithful witness of the property Case 2 exists to prove" framing matches the plan's intent.

Grok's analysis is the same: "Case 2 is a state the bound receipt already computes: checked `assets * supply / totalAssets`. It is not a pause or disable path. The plan allows another rejection the production vault already exposes, and it forbids a harness `balanceOf` fault. This construction follows that split." I agree.

Astra records: "These assertions are appropriately aimed at the specified sweep behavior. That inference is supported by the saved passing results, but I did not independently reproduce their execution. A fixture arithmetic-boundary witness does not establish every real-world pause/disable behavior; the plan does not require that broader claim." I agree on the scope, and the plan does not require a domain-level pause/disable witness.

I therefore do not dissent on either point. The plan is executed completely, and Case 2 is not incorrect execution.

## Evidence gaps

- I did not run Forge. The 21/0/0 result is the prior session's reported run; the cross-review does not reproduce it.
- I did not re-verify the implementation report's claim that the four sweeps are "byte-for-byte unchanged from HEAD." The four sweep bodies I re-read match the original configuration; the absence of any unrelated change is asserted by the report, not independently re-derived.
- The first focused-test run crashed before any test executed (`focused-tests-sandbox-crash.log:40-79`); the report reran the same command outside the sandbox. The cross-review accepts the rerun as the reported run and does not attempt to repeat it.
- Whether `vm.expectCall` counts a call that reverts is not independently verified by me; the reported green run is consistent with counting, but Foundry's semantics on a reverted call are not body-checked here.
- I did not re-search `test/` outside the new ResidualPreview file for any remaining wrapper that exposes the preview. The loupe check at `ResidualPreview.t.sol:125-131` and the production grep of `previewResidualBuffer` covering exactly the ClaimLib declaration and the four sweep call sites are the strongest no-selector evidence available without a re-run.

## End

I did not run Forge.