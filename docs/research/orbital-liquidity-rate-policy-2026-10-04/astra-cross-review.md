# Astra — single combined cross-review

2026-10-04. I read Grok, MiniMax M3 and Kimi K3’s complete original reports together before concluding. They are evidence, not authority. My original remains unchanged. No cross-review artifacts, tests, shell or delegation used. Kimi’s disclosed incidental exposure to two peer snippets limits first-pass independence; it does not invalidate independently checkable findings.

Shorthand: `O/` = `contracts/hooks/uniswap/v4/standardExchange/orbital/`; `W/` = sibling `weighted/`. Solidity basenames below omit their full `UniswapV4StandardExchange{Orbital|Weighted}BufferHook` prefix.

## Agreements and retained Astra findings

All three support the central separation: **raw inventory ownership; rated swap pricing**. All reject the moderator’s inference of a bug solely from rated variables in `_planDeposit`. I retain both conclusions, but reject MiniMax’s stronger claim of bit-identical equivalence.

I retain my finding that proportional exits can fail on rates **with fees off**, and that `WeightedFundedBindingTest` does not establish FullSpread compatibility. No report supplies current measured evidence that the old planner fits gas.

## Specific objections, verified against source

### 1. Integer cancellation is conditional—not bit-identical

MiniMax’s “identically,” “gas, not correctness,” and guaranteed bit-identical rewrite claims are false generally. `O/ClaimLib.sol:317–329` separately floors rated conversions; `O/Math.sol:146–171` divides their results. Same-rate cancellation holds before those floors, not necessarily afterward.

Hand-calculated counterexample: equal decimals, rate=1.5 WAD, held=3, contributed=2, supply=12. Raw issuance is 8; rated issuance is `floor(12×3/4)=9`. Thus ratio error can **overmint**, not merely conservatively undermint. This is an arithmetic counterexample, not a demonstrated reachable exploit. Kimi’s “≤1 unit per term” does not bound final LP error: supply multiplication and a small denominator amplify it.

Also, `O/ClaimLib.sol:332–338` checks call success, return length and nonzero rate—not equality between reads. `ExitQuoteLib.sol:378–381` has zero-result face-unit fallbacks, another exception to cancellation. Grok’s caution is substantially correct.

### 2. Full exit execution is not rate-free

MiniMax’s “no rate read anywhere in the remove path” is contradicted by `O/Common.sol:1359–1366`: after payouts, `_burnAndPay` invokes `_recomputeL2`, `_snapshotKLastIfFeeOn`, and `_syncVaultReserves`.

`Common.sol:459–479` shows rated reads in synchronization and sphere recomputation independently of growth-fee activation. A reverting provider on a remaining nonzero holding can therefore revert the **entire transaction, including earlier payouts**, with fees off. Kimi’s fee-only explanation is incomplete; Grok correctly describes `_proRataOut` locally but overstates operation-level conformity/liveness. Rate-free payout arithmetic is not a rate-free entrypoint.

### 3. Partial joins: strengthen my original finding

Grok and Kimi prompted a deeper trace. `O/Common.sol:1093–1102` passes rated reserves to `_partialUsed`; `1162–1183` divides face offers by those reserves. Unlike full-book mapping at `1106–1112`, partial used amounts are returned as face without buffer inversion (`1145–1157`). `_partialNavShares:1649–1655` combines rated reserves with face contributions; `O/Math.sol:380–391` prices that mixed vector.

**Correction/addition to Astra:** this is a specific observed unit-accounting concern, not merely unspecified fallback economics. However, Kimi’s claimed dilution “magnitude = SE deposit fee” is not established: final issuance is weighted sphere NAV, not simply `F/heldValue`. Direction and magnitude depend on actual buffer output, rate, rounding and state. A numeric execution trace remains necessary.

### 4. Fixtures and single-asset routes

MiniMax’s failure to locate a filename named `WeightedFundedBindingTest` does not imply no such contract: it exists in `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol:171–176`. Its base, `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol:47–56`, deploys ERC4626 SEs over SimpleYieldERC4626. Astra, Grok and Kimi agree correctly.

MiniMax’s “no zap-out” conclusion uses obsolete descriptive prose: `O/WithdrawTarget.sol:153–177` withdraws proportionally then swaps residuals. Conversely, Kimi’s “single-asset joins/exits are zaps” must remain Orbital-specific: Weighted uses inventory-domain invariant math (`W/JoinCore.sol:593–611`), not that basket-swapping procedure.

## Bootstrap and fee exceptions: family scope

My original qualification stands. Agent law `docs/agent/INDEXEDEX_AGENT_LAW.md:240` explicitly introduces its rated `kLast` statement with “On the constant-product hooks.” APEX remediation plan D63 (`:153`) references D60 work package 2. Weighted PRD `:61–64` specifies native first mint and `kLast`. Orbital independently retains rated bootstrap/growth in its PRD `:306,324–328` and `O/Common.sol:899–948,971–984,1225–1241`. Do not transplant one family’s exception or fee policy wholesale.

## Plain-English recommendation and remaining gaps

* **Raw in-kind liquidity:** calculate ownership using concrete token/share balances, without price rates.
* **Actual conversions:** quote shares minted or assets redeemed; raw ownership does not mean 1:1 conversion or zero fees.
* **Internal swaps/zaps:** retain fail-closed rated pricing and sequential state projection; final proportional mint/burn remains raw.
* **Bookkeeping:** treat rated bootstrap, growth fees, reserve views and sphere updates separately. They currently defeat rate-failure exit liveness. A recovery design needs explicit fee/state rules—not a silent rate=1 fallback.

Rates are not guaranteed cheap, and `rateAfterExchange` can call projected `quoteRate` (`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:133–149`). Removing rate arithmetic does not remove necessary SE simulations. Remaining evidence gaps: reachable rounding/partial-join traces, failed-provider end-to-end tests, and matched-state gas measurements. Confidence is high on source facts, moderate on unexecuted economic impacts. Agreement is not a security proof.
