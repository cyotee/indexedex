# MiniMax M3 — cross-review of REQ-02 plan drafts

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer plan used as authority. No peer original was read.
- **Target:** current IndexedEx working tree, current state 2026-10-14.
- **Question:** agreements, specific objections, and unresolved dissent against the three peer plan drafts on three named points.
- **Re-reads performed:** I re-read the disputed production source for this round: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol` (full 627 lines), the four sweep copies at lines 367-379 (DepositCommon), 131-142 (WithdrawalLib), 388-400 (Target), 477-489 (SeTarget), the InBase `_executeZapOutExactIn` for the holder-arg shape, the precedent test at `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:85-100`, and the SE preview chain at `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:35-70, 102-104` plus `ReceiptBackedERC4626AccountingLib.sol:18-52`. I did not re-read REMEDIATION_PRD.plan.md. I did not read docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.plan.md.

## (1) Keep `previewResidualBuffer` and change it to `internal`, versus inlining the body and deleting the calls

**Agree with all three peers.** The PRD step 1 says "Change `previewResidualBuffer` in `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol` from `external` to `internal`. Keep the body a direct `previewExchangeIn`." No peer proposes inlining the body. My own draft did the same. The PRD controls; the choice is settled.

I verified that the function is at `ClaimLib.sol:382-389`, is `external view`, has the direct `previewExchangeIn` body, and contains no `catch` and no zero check. The four sweeps already call it as `ClaimLib.previewResidualBuffer(excess)` — all library call sites, which compile unchanged against an `internal` library function (inlined).

## (2) Which sweep copies a production TestBase hook actually reaches

**Agree with all three peers.** Two sweep copies are reached by the production TestBase hook; two are not.

| Copy | Reached by the production TestBase hook? |
|---|---|
| `DepositCommon._refundPairDust` (`.../DepositCommon.sol:367-379`) | Yes. Called from `_deposit` (`:491`), `_depositWithSeShares` (`:582`), `_depositSingle` (`:712`). Public entries: `single.deposit`, `single.depositWithSeShares`, `single.depositSingle`. |
| `WithdrawalLib.refundPairDust` (`.../WithdrawalLib.sol:131-142`) | Yes. Called directly inside `Withdrawal.withdrawFrom` at `:66`, and via `WithdrawTarget._refundPairDust` at `:338-340`, which is reached from `_withdraw` (`:536`) and `_withdrawSeShares` (`:575`). Public entries: `single.withdraw`, `single.withdrawSeShares`, `single.withdrawSingle`. |
| `Target._refundPairDust` (monolithic, `.../Target.sol:388-400`) | No. The monolithic `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget` is referenced only by itself and by two PRD markdown files (`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`, `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`); no production contract inherits it. The TestBase deploys split facets (`SeFacet`, `DepositFacet`, `DepositSingleFacet`, `DepositPreviewFacet`, `WithdrawFacet`) via `PkgFactory.deployPackage` at `TestBase_...:115-126`; none of those facets routes to the monolithic Target. |
| `SeTarget._refundPairDust` (`.../SeTarget.sol:477-489`) | No. The only definition in that file. `SeFacet` inherits `SeTarget` and is installed, but no function in `SeTarget` calls this copy. |

This agrees with Astra, Grok, and Kimi. The disagreement among peers is whether to "exercise one entry per reached sweep" (Astra, Grok, my own draft) or "exercise both reached sweeps with separate tests" (Kimi). PRD Case 1 step 4 says "Exercise one production entry for each sweep function that a production path actually calls." That maps to two reached sweeps, each with one production entry. Kimi's plan of four tests (zero-quote × two sweeps, reverting-quote × two sweeps) is consistent with the PRD; my own draft also has separate tests per reached sweep. Both are acceptable; both are also in agreement that the monolithic Target and SeTarget copies are unreached and not exercised.

I do not dissent.

## (3) Whether Case 2 may fault a non-SUT harness `balanceOf`

**Partial disagreement.** The three peers take materially different positions.

**Astra and Grok** restrict Case 2 to a production-state revert of the bound SE itself: "Investigate real pause/disable or other existing rejection behavior only; do not assume that disabling execution also disables a view preview." Grok adds: "A pause, a disabled vault, or another rejection the production vault already exposes may be used only if it does not replace the vault."

**Kimi** proposes faulting a non-SUT harness read on the underlying ERC-4626 receipt vault (`SimpleYieldERC4626`, the `pairProtocolVault` harness), citing the precedent at `UniswapV4DetfLeftoverPreview.t.sol:91-97` (which mocks `seOther.balanceOf(se)` where `seOther` is a fixture token, not the SUT SE). Kimi also explicitly leaves the ruling open as a stop-and-report condition: "If the coordinator rules that faulting the protocol-vault harness read violates 'Do not mock the vault,' then Case 2 is not reachable on this bound vault: stop, report that the revert case was not reached, and do not fake it."

**My view, after re-read:**

- The PRD Case 2 instruction at line 100 says "Use the same production hook and the same bound vault. Reach a state the vault already supports in which `previewExchangeIn` of the sweep's excess reverts." The "vault" here is the bound SE.
- The PRD's forbidden mocks list at line 110 is "the hook or the Standard Exchange." The bound SE is the Standard Exchange; the underlying ERC-4626 receipt (`pairProtocolVault`) is a separate contract — a harness stub for this hook test. The forbidden list does not name the receipt vault.
- The SE's preview path is `ERC4626StandardExchangeCommon._previewExchangeIn` (`contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:35-70`), which calls `_receiptBacking()` at `:102-104`. `_receiptBacking()` calls `ReceiptBackedERC4626AccountingLib.backingReceiptUnits(protocolVault(), address(this), false)` at `:18-30`. That library function reads `IERC20(address(receipt)).balanceOf(holder)` (`:23`), `receipt.asset()` (`:24`), and `receipt.convertToShares(bookedUnderlying)` (`:51`). All three external reads are on the receipt vault (`SimpleYieldERC4626`), not on the SE.
- I verified by re-reading `SimpleYieldERC4626.sol` (the `pairProtocolVault`): it has no revert path in its quote math (`convertToShares` returns `assets` when supply or totalAssets is zero, otherwise the proportional share; no `_requireNotDisabled` or pause gate in the preview path of `contracts/vaults/standard/erc4626/`).
- The bound SE (`ERC4626StandardExchangeInTargetExt`) does not reject a positive `previewExchangeIn` for any excess on this fixture. No production state of the bound SE reverts the preview.
- The sibling precedent at `UniswapV4DetfLeftoverPreview.t.sol:91-97` mocks `seOther.balanceOf(se)`. `seOther` is a fixture token (`SimpleMintableERC20`), not the SUT SE. The header comment at line 91 says "Both SE and DETF proxies remain real." This is the council-accepted construction for "reverting preview" tests on this hook family.

**I agree with Kimi that the construction is not a vault mock and matches the accepted sibling precedent.** The mock faults a non-SUT ERC-4626 receipt `balanceOf` read; the bound SE remains real; the hook remains real; the production path remains real. The PRD's "do not mock the vault" language targets the SE, not the receipt.

**I also agree with Kimi that this is a stop-and-report condition.** If a future owner ruling decides that faulting the receipt counts as a vault mock, Case 2 is unreached on this bound vault and the implementation session reports that, exactly as Kimi frames it. The plan must keep that stop condition armed.

**I disagree with Astra and Grok only in the framing, not the substance.** Astra and Grok both say "investigate real pause/disable or other existing rejection behavior only." On this bound vault, no such state exists. So either (a) the test reaches Case 2 only by faulting a non-SUT dependency (Kimi's path), or (b) Case 2 is reported unreached (Astra and Grok's fallback). Both peers accept the fallback; Kimi also accepts it. The disagreement is whether Kimi's construction is on-bounds.

I read the PRD as on-bounds: "do not mock the vault" = "do not mock the Standard Exchange," and the SE is not the SE's receipt. My cross-review position: Kimi's construction is acceptable if the implementer documents the precedent, names the non-SUT read being faulted, and keeps Kimi's stop condition armed.

I also want to flag a separate ambiguity in all three peer plans that none of them resolved. Case 1 reachability depends on `convertToShares(excess)` returning zero. For a wei-sized excess with `totalAssetsStored` raised by `simulateYield` so the share rate is far above the asset rate, `SimpleYieldERC4626.convertToShares(excess)` would return `(excess * supply) / totalAssetsStored`, which floors to 0 for `excess < (totalAssetsStored + supply - 1) / supply`. The DETF precedent at `UniswapV4DetfLeftoverPreview.t.sol:41-42` raised backing by `1e30` to force this exact flooring. Kimi cites this precedent and proposes the same construction. None of the peer plans include the `simulateYield` call in their pseudocode; my own draft also omitted it. Astra's Case 1 step 2 mentions "Using only supported existing state transitions, establish pair custody above `MAX_DUST_WEI` and a zero SE preview for the exact excess" but does not name the `simulateYield` lever. Grok's Case 1 step 5 leaves the precondition as "call `previewExchangeIn` on the bound vault for the hook's pair token, that same excess, and the vault as `tokenOut`. That is the view the sweep uses. This is Case 1 only if that call returns 0." All three peer plans therefore agree Case 1 must be verified by direct `previewExchangeIn` and is reachable only when that call returns 0; they agree on the verification method but differ on whether they propose a way to set up that zero (Kimi does; Astra and Grok leave it to the implementer). I do not dissent; I record it as a documentation gap.

## Material peer claims not separately re-read

- I did not re-read the six `_refundPairDust` call sites in `DepositCommon` past the four primary reachability lines. I read the four sweeps, the WithdrawTarget adapter, and the InBase holder-arg shape. The reachability claims rest on `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol` (re-read fully), the four sweep files (re-read at the cited lines), `WithdrawTarget.sol:338-340, 536, 575` (re-read), `DepositCommon.sol:491, 582, 712` (re-read), `Target.sol:846, 971, 1139, 1215` (re-read), `SeTarget.sol:477-489` (re-read), `TestBase_...sol:78-149` (re-read this round).
- I did not re-read every other peer claim line by line; this cross-review is on the three named points only.

## Unresolved dissent this pass cannot resolve

1. Whether faulting `pairProtocolVault.balanceOf(se)` in Case 2 is a vault mock or a non-SUT harness mock. Kimi argues the latter and cites the sibling DETF precedent. Astra and Grok treat it as off-spec and require a real production state. The PRD text is ambiguous on "the vault." Kimi already plans to report unreached if the coordinator rules otherwise; Astra and Grok accept the same fallback. My position is that Kimi's construction matches the sibling precedent and the PRD's forbidden-mock list, but I record this as unresolved if a future ruling lands.
2. Whether Kimi's four-test split (zero × two sweeps, revert × two sweeps) versus Astra's "two distinct cases, each exercised separately for every actually reachable sweep implementation" is the PRD-mandated minimum. The PRD Case 1 step 4 says "Exercise one production entry for each sweep function that a production path actually calls" — two reached sweeps, one entry each. Both interpretations are consistent on the two-reached-sweep minimum; Kimi's four tests and Astra's two tests are both within PRD scope. I record this as a non-blocking choice.

## Evidence gaps

- No Forge run. No source identity hash. The visibility-change compile outcome is unverified; PRD step 3's stop-and-report contingency is expected to be unused but stays armed.
- The `simulateYield`-then-zero-preview construction for Case 1 is cited by Kimi and by the DETF precedent but not separately re-read beyond those two sources. The flooring math in `SimpleYieldERC4626.convertToShares` is verified: returns `assets` when `supply == 0 || totalAssetsStored == 0`, otherwise `(assets * supply) / totalAssetsStored`. With `totalAssetsStored` raised above `supply`, a wei-sized `assets` floors to 0. This is a known path; I did not run it.
- The monolithic `Target.sol` reachability is verified by an exact-name search of `contracts/`: only the file itself and two PRD markdowns reference it. I did not re-search `lib/` or `test/` for any spec that exercises the monolithic Target directly. If a test file outside `contracts/` instantiates the monolithic Target, the unreached claim is wrong. The PRD says do not add an entry to reach it; the implementer should record any such test as evidence the copy is reached.

I did not run Forge.