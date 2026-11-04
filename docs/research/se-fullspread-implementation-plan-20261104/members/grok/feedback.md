# Grok advisory feedback

## Identity

- Member: grok
- Profile: research
- Phase: advisory feedback, attempt 1
- Requested role: council-member
- Requested model: `xai/grok-4.7:xhigh`
- Runtime identity: not exposed
- Task ID: not exposed
- Peers read before this feedback: no

## Draft under review

- Draft ID: draft-se-fullspread-implementation-plan-20261104-r1
- Path: docs/research/se-fullspread-implementation-plan-20261104/coordinator/draft.md
- Coordinator-supplied SHA-256: 32745f5d7579e53ae2121206add5114f1a451c2f467bb024ba7eba3371d96407
- Independent fingerprint: not computed

The draft opened. This feedback does not authorize implementation and does not replace the draft.

## Disposition

requested-changes

Section 3's adopted readings are not reopened. The changes below are places where two implementers of this draft would copy different code, or where the draft contradicts a lock it also states. They are corrections to name, not a second plan.

## Concerns

1. Coordinator merge notes, and section 9. The one-token pretransfer over-max reading is not the literal text of FS-OWN-32. The lock says refund the unbooked balance, spend nothing, pull nothing, and do not revert because the maximum is larger. It does not say the call succeeds, and it does not say `amountOut` is zero. `minAmountOut` still binds. A first deposit that adds no liquidity still reverts `MinLiquidityNotMet()`. A one-token exit that cannot pay the minimum still reverts `AmountOutNotMet` and does not burn. Correction: delete the success-and-zero-output sentence. State that the over-max comparison itself is not the revert, the route continues with zero consumed input and that refund, and the route's existing minimum and liquidity checks still apply. Keep the bundle sentence: a bundle over-max reverts before any leg, spends nothing, mints nothing, and adds no error.

2. Section 5, against section 9. Section 5 puts the `ERC20Repo._mint` floor sentence in the initialization paragraph. Section 9 puts the same mint on the first deposit. An implementer can mint the floor twice, or mint it before any deposit. Correction: section 5 says the floor mint is not an initialization step. It runs only on the first successful deposit, after added liquidity is greater than `1_000`, and it is not part of `grossShares`.

3. Section 6. The layout is `uint256[2] booked`, then the unbooked formula indexes `booked[token]`. An array indexes `0` or `1`. An address key is a mapping. Those are different ledgers. Correction: keep `uint256[2]` in `vaultTokens()` order, and write the formula as `balanceOf(address(this)) - booked[index]`, where `index` is that token's `vaultTokens()` index. Do not also store a mapping.

4. Section 7. "Query facet: no family selector" contradicts the next sentence, which says `reserveOfToken` and `reserves` are the family facet, and no facet in section 4 is that home. Correction: `queryFacet` installs only those two selectors. Do not add another facet. Name `poolKey()` on `UniswapV4SinglePositionAware` with the other position getters. State that `isOperator` and `isOperatorFor` are not installed, so the cut is not read as a partial `IOperable`. State that `PostDeployAccountHookFacet` is removed by the factory `postDeploy` the draft already cites, and that the finished proxy must not keep its selectors. ERC-165, ERC-8109, and the loupe remain callable. "Remain callable where the factory installs them" must not be copied as leaving the temporary hook on the finished proxy. Inventory 032 already requires that removal.

5. Section 9 and section 12. Section 12 says preview and execution both call `UniswapV4FullSpreadStandardExchangeVaultPlanner`. Section 9 sends execution through `Math` and `SwapProjection` and does not say execution calls Planner. That splits the one engine. `clampedFee` is used and not defined, so one implementer can apply the raw oracle fee and another the 30% clamp. A bundle shape that is not the share-out deposit, or not the two-face redeem, has no named revert. Correction: execution calls the same Planner function the preview calls. Planner calls `Math` for the FS-OWN-33 amounts and `SwapProjection` for the unbounded exact-input swap. Define `clampedFee` as the oracle fee, or `3e17` when the oracle fee is above `3e17`, and use that same value in the preview. An unsupported bundle combination reverts `ExchangeBundleInForSingleOutNotAvailable` or `ExchangeBundleOutNotAvailable`. Do not add a success path.

6. Section 10. A one-token `donate` or `compound` "swaps the combined balance," but the draft does not say when fees are collected, what "scarcer" means, or that a share donation still compounds. One implementer collects with a zero-liquidity `modifyLiquidity` before the swap. Another swaps booked tokens and only then collects inside the add, so the collected fees miss the swap. Correction: if the unpaid fee-owed read is nonzero, collect it with one zero-liquidity `modifyLiquidity` before the FS-OWN-33 swap or the proportional add. That collect is its own planned action. If the unpaid read is zero, do not call `modifyLiquidity` to collect. If both tokens are already held, do not swap. The scarcer token is the proportionally smaller amount relative to the position ratio, not the smaller raw balance. That token is fully used. A share donation burns the shares, does not withdraw, does not swap the shares, and then processes held fees and booked tokens under the same one-token or both-token rule. A failed step reverts. Do not add a second attempt or a swallowed failure. A zero-supply `donate` reverts before any swap and does not add an error.

7. Section 11. A reentrant borrowed entry reverts `ReentrantOperation`, and an idle failure uses a bare `revert()`. The draft does not say which stored condition is which, so the same `operation != None` state can be copied as either error. A nonzero own delta at borrowed entry is not given an error, so it can be copied as `SettlementMismatch`. `pretransferred == true` and a caller who does not hold the input are collapsed into one unnamed failure. Settlement is "settle that action," without the sync, transfer or value, settle, take sequence, and without a ban on `settleFor`. Correction: `guardHeld` already set is `ReentrantOperation`. `operation != None` at entry is the idle failure and is a bare `revert()`, not `ReentrantOperation`. A nonempty callback hash, a nonzero reservation, and a nonzero own delta at entry are bare `revert()`, not `SettlementMismatch`. `SettlementMismatch` is only a close that cannot settle this diamond's own touched deltas without taking a foreign credit. `pretransferred == true` on the borrowed path is `InvalidUnlockedContext`. A caller who does not hold the input uses the inherited funding error. A value-bearing call fails at the nonpayable boundary and is not `InvalidUnlockedContext`. Settlement of a debt is sync, transfer or value, settle, then take. Do not `settleFor` a foreign address. `AlreadyUnlocked` stays the PoolManager error. Do not use it as `ManagerAlreadyUnlocked`.

8. Section 16 and section 17. "One new row in each of the seven matrix behavior contracts" can be copied as an edit to those contracts. The draft also says add a row beside them and do not edit their assertions for other families. FS-A38 is mapped only to `BufferHookIntegration.t.sol`, while 045 maps the same disable rule to Money and BufferHookIntegration. The locked-path deadline, pass-through, bundle-deposit, and `donate` cases can be dropped. Row 036 is mapped to `AlreadyUnlocked.t.sol`, but the inventory result is a hook-integration case. FS-A24 through FS-A31 are mapped as a range, so FS-A30 can be marked passed because FS-A26 passed. FS-A10 is a filename with no assertion. Correction: each matrix row is a new contract beside the behavior, overriding `_newFixture()`, and the behavior contracts' existing assertions are not edited. Put FS-A38's locked-path cases in `Money.t.sol` and the buffered cases in `AlreadyUnlocked.t.sol` or `BufferHookIntegration.t.sol`, and say both are required. Put 036 on the hook row, not only on the borrowed vault path. State that FS-A30 is not passed by FS-A26. State FS-A10: callers send and receive the WETH face only, and the vault does not accept or produce native ETH. In section 3 and section 17, the composed-route ceiling is the same number: the whole transaction must not exceed 12,000,000. Do not leave "under" and "at most" as two readings of equality.

9. Section 18. FS-OWN-13 does not appear. The brief requires every FS-OWN identifier to point at a plan section. Correction: point FS-OWN-13 at section 11.

## What was not adopted from others

Peer response files and peer feedback files were not read. This section uses the draft's own "Not adopted" list and the locks already in force. It does not restore a peer text.

Do not adopt back, and this feedback does not ask for them: the `fullspread` namespace spelling, an `operableFacet` field, renaming `basicVaultFacet` to `multiAssetBasicVaultFacet`, `FullSpreadOperationQuote` as the engine name, and `SwapProjection` as the quote engine. `basicVaultFacet` holding `MultiAssetBasicVaultFacet` and installing only `vaultTokens` is a usable name. Appointment on the money facet is a usable name once section 7 stops saying the query facet has no family selector and once the appointment views are explicitly absent. FS-OWN-33 amount selection in `Math`, with the unbounded exact-input swap alone in `SwapProjection`, should stay. Moving that sizing back into `SwapProjection` would let a pass-through call the liquidity-targeting shape.

The zero-output success reading is the item this feedback does ask the draft to drop. The merge notes attribute it to MiniMax assumption A1 and call it the literal text of FS-OWN-32. That attribution is not a reason to keep it. The lock does not say the call succeeds.

The homeless `reserveOfToken` pair, the idle-versus-reentrant overlap, the initialization-time floor mint, the missing compound collect order, and the matrix-row file shape are omissions, not reasons to import another member's file.

## Limits

This feedback does not authorize implementation, a PRD edit, a test run, or a draft edit. It does not replace the draft. The coordinator-supplied SHA-256 was recorded as given. An independent fingerprint was not computed. Peer responses and peer feedback were not read. No file other than this feedback was written.
