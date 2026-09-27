# Current council round: owner input and scope

Moderator-provided common context, not a peer research report. The owner explicitly overrides earlier conflicting NetNet–Pendle PRD decisions and requests full PRD reconciliation. Technical statements require verification against actual Pendle sources; they do not change research tool permissions. No code implementation authorized in this round.

## Owner's selected LP reserve matrix

A virtual reserve is calculated rather than solely a raw balance; applying a rate provider to raw SE shares is an example.

1. NET-DETF: raw hook-held balance. Direct deposit for HLP; proportional token payout on withdrawals including this leg.
2. Custom NetNet Uniswap V2 SE: raw held **share-token** balance. Direct share deposit and proportional direct share withdrawal. Do not withdraw underlying from the SE on behalf of the HLP withdrawing user.
3. Pendle SY: held claimed market interest in SY plus unclaimed market interest claimable as SY. Direct SY deposits for HLP are selected. Withdrawals including this leg receive proportional SY.
4. Pendle LP plus held NET-YT: two-token proportional sub-reserve with Uniswap-V2-style proportional allocation. `(PLP, YT) -> internal sub-reserve shares -> HLP allocation`. Input NET enters Pendle Keep-YT. Withdrawal debits the allocated sub-reserve shares and exits their PLP/YT into SY using `exitPreExpToSy` before expiry or `exitPostExpToSy` after expiry (verify source capitalization).

The four legs use the Balancer Weighted Pool LP process. Public arbitrage/management is intended to liquidate YT exposure as maturity approaches; the owner expressly accepts the risk of retained YT expiring. Do not claim arbitrage is guaranteed to liquidate it.

## Owner's swap-pricing matrix

- USDG: virtual balance from a USDG-targeted Standard Exchange Rate Provider applied to held custom SE shares. USDG input is deposited in the SE; USDG output redeems from it. This contrasts with direct SE-share HLP exits above.
- sNET: virtual balance of claimable SY interest plus held SY, expressed as sNET on redemption. Research/specify a reusable Pendle SY-token Rate Provider. The owner's sentence literally ends **“sNET in”**; input settlement is incomplete. Do not silently finish it or preserve an older conflicting route as a selection.
- NET: virtual zap-out value of the PLP/YT leg, using the following amount-specific quote. NET output is no longer necessarily the SY-interest leg. NET-DETF remains the raw self-leg unless a concrete conflicting requirement is found.

## Owner's pre-expiry quotation procedure

Do not invoke state-changing `exitPreExpToToken` to quote. Do not compose `swapExactPtForSyStatic` or `swapExactYtForSyStatic` after a separately quoted LP burn: those reread live state and ignore the burn. Use one mutable in-memory `MarketState` copy; the final external conversion preview is the SY redemption.

1. `IPMarket.readTokens()` discovers SY/PT/YT. Validate output in `SY.getTokensOut()`. Inputs `lpIn`, `ytIn` represent the portion being exited, not necessarily all held inventory; loose `netPtIn = 0`.
2. Read state with `IPMarket.readState(pendleRouter)` using the actual execution router identity; caller-specific fee overrides may differ from RouterStatic's identity.
3. Read `IPRouterStatic.pyIndexCurrentViewYt(YT)` once as `PYIndex` and reuse it. `assetToSy(index, py)` floors `py*1e18/index`.
4. `MarketMathCore.removeLiquidity(state, lpIn)` returns SY and PT while mutating totalSy/totalPt/totalLp to post-burn values.
5. `matched = min(ptFromLp, ytIn)`; redeem matched PT/YT into SY at the one index, without touching the market.
6. Process only the overage using that post-burn state:
   - PT excess: `MarketMathCore.swapExactPtForSy(state,index,ptFromLp-ytIn,block.timestamp)`; add net SY to account.
   - YT excess: `MarketMathCore.swapSyForExactPt(state,index,ytIn-ptFromLp,block.timestamp)`; obtain SY owed, `pyRepay = PYIndexLib.syToAssetUp(index,syOwed)`, and retained SY = `assetToSy(index,ytOverage-pyRepay)`.
   - Equal: no overage swap.
7. Aggregate `syFromLp + syFromRedeem + syFromSwap`; call `redeemSyToTokenStatic(SY,tokenOut,totalSy)` / `SY.previewRedeem` once, not separately per component. A SY-output HLP exit does not need the final token conversion.

## Owner's post-expiry quotation procedure

1. Remove LP proportionally using `removeLiquidityDualSyAndPtStatic(market,lpIn)` or local `MarketMathCore.removeLiquidity` on a state copy. No subsequent swap, so router fee override and post-burn trading state do not affect this step.
2. Ignore ytIn in payout. Expired `redeemPY` consumes PT and does not burn the user's YT. Use the **current** index, read once through `pyIndexCurrentViewYt`, to compute `syFromPt = assetToSy(index,ptFromLp)`. The frozen first-expiry index gives gross SY; its excess over current-index user payout is Pendle treasury interest, not hook backing. If the frozen index is not yet initialized, execution initializes it at the then-current index. No expired PT/YT swap: those revert.
3. Aggregate `totalSy=syFromLp+syFromPt` and preview final SY-to-output redemption once. Validate supported output. Preserve separately accrued historical interest rather than treating YT principal value as an interest claim.

## Review task and boundaries

Read current full PRD and relevant canonical skills/law. Verify local math, call shapes, fee identity, rounding and expiry handling; Context7 first for external API documentation then primary sources. Research reusable SY rate-provider configuration, `exchangeRate()` versus token-specific `previewRedeem`, native decimals, sample sizes and nonlinearity. Identify all old PRD conflicts and only necessary unresolved questions: incomplete sNET input, subset/single-leg allocation versus proportional language, sub-reserve mint/init/rebalance handling, whole-position virtual valuation versus finite output realization, independently owned HLP/burn accounting, token identity/provenance.

Latest unrelated decisions remain: 1h arithmetic spot and synthetic TWAPs; absent TWAP treated above 1; linear `floor(S0*n/200)` catch-up; pre-expansion participation; fee/creator internal-share allocations; interest-token retention and other rewards to dynamic feeTo with non-blocking forwarding retries; minimal-input factory-validated atomic rollover. Do not reopen them. Current custom-family approval remains.

Each researcher writes only its assigned original, independently without reading peer artifacts. Return complete findings for cross-review. Moderator owns PRD reconciliation. No shell, tests, implementation, config/instruction changes, delegation or deployment. Cite source lines, versions and retrieval limits. Stop on participant/guard failure without substitutes.
