# gx-aerodrome-camelot-univ2: adversarial execution (Aerodrome v1 SE, Camelot V2 SE, UniV2 SE)

HEAD 2ba07631. Runner: FOUNDRY_PROFILE=audit forge test --match-path (the audit runner, audit profile). Local fixtures only. Aerodrome, Camelot and UniV2 SE are not deployed on 4663 (census.md), so a live fork does not apply.

## NEW: A-DUST. Aerodrome `_claimAndCompoundFees` dust-excess zap reverts and freezes every LP-moving vault route (confirmed_dos, low)

`_claimAndCompoundFees` (AerodromeStandardExchangeCommon.sol:469) runs without a try/catch at the start of every route that touches LP:
- In: deposit, withdraw, zap-in deposit, zap-out
- Out: the same four routes
- SY `_redeemLpSharesFrom` (:41, new in this diff)

When the claimed one-sided fee excess is above `DEFAULT_DUST_THRESHOLD = 1000` wei (:128), `_zapInExcess` (:598) swaps about half of it with minOut 0 (:652). If that half-swap rounds to 0 output in the other token, the Aerodrome pool reverts with `InsufficientOutputAmount()` (0x42301c23, Pool.sol:366). The revert takes down the whole vault op.

Where it bites: pools whose raw price ratio is above about 500:1, which covers most real pairs (WETH/USDC at 18/6 decimals, cbBTC/WETH, and so on). The frozen band is excess in (1000 wei, about 2·rIn/rOut wei). For a WETH/USDC pool at 3000 that is roughly 1e3 to 6.7e8 wei of WETH.

File: `AeroCompoundDustDoS.t.sol`, 5/5 PASS. Pool: 100 WETH-like (18 dec) / 300k USDC-like (6 dec). Alice deposits honest LP.
- `test_dust_fee_freezes_all_vault_routes`: the attacker does one 1e10-wei WETH swap in the public pool and gets 29 USDC wei back, so the cost is about $0.00003 plus gas. After that, Alice's withdraw, Alice's zap-out and Bob's zap-in all revert with 0x42301c23. `previewExchangeIn` still quotes normally. The vault only recovers after an organic 1-WETH trade.
- `test_natural_self_freeze_cascade`: **no attacker.** After organic volume, the 4th consecutive honest no-swap op freezes the vault. Each compound's own zap swap accrues a one-sided fee of about 0.1% of the zapped amount back to the vault. That fee decays geometrically into the band, and the band (about 6e5x wide) is too wide to skip over.
- `test_attacker_refreezes_after_organic_volume`: the attacker re-freezes with 3 cheap LP-deposit triggers. Alice's full withdraw and Bob's 5000 USDC zap-in revert. The attacker's own LP is fully recoverable afterwards (20381390217 in, 20381395397 back), so the attack costs nothing.
- `test_band_scan`: swaps of 1e9, 1e10 and 1e11 wei leave the vault FROZEN. Swaps of 5e11, 1e12 and 1e13 wei leave it OK.
- `test_control_balanced_1to1_not_frozen`: a 1:1 pair with equal decimals is not affected.

Impact:
- Temporary liveness DoS with no fund loss. The freeze lasts until an external trade pushes the pending fees out of the band (any trade above about $0.5 on the USDC side or about 1e-6 ETH on the WETH side).
- An attacker can grief or front-run specific withdrawals and deposits every block, and composed integrators (DETF/SY) inherit the reverts.
- On a low-volume pool the vault can stay frozen with no attacker at all.
- The code predates the diff. It is reached by a route this diff added (SY redeem).

Fix: before `_zapInExcess`, require `pool.getAmountOut(saleAmt, tokenIn) > 0` and a nonzero quoted liquidity. Otherwise keep the amount as stored excess (`_setExcessToken*`). Alternatives: wrap the compound in a self-call try/catch, or make the dust threshold value-aware instead of a flat 1000 wei.

## Held (refuted_by_execution) — coverage evidence
| Test | Result |
|---|---|
| AeroValueConservation G1: compound-on-touch sandwich (zero-min addLiquidity/zap), push 500/2000/6000 of a 10k pool | Attacker net -2.38 / -8.39 / -22.5 tokenA. Alice LP vs control **+1.33 / +4.69 / +12.6**, so the protocol gains (matches the h3 simulation) |
| G2: JIT 4.46e21 LP deposit then withdraw right after organic fees | Fees are compounded before the mint. Attacker residual +2.7e14 LP (6e-8 relative), which is the vault's own zap-fee rebate. Alice +2.5e14. Dust |
| G3: zap-in then zap-out round trip at 1e12 / 10e18 / 3000e18 | out < in every time (0.3% to 0.18% loss) |
| G4: exact-out zap-in vs exact-in | Same shares for the same input. Pull equals used exactly |
| G5: atomic pretransfer exact-out zap-in (honest contract) | Refund = credit - used. Exact shares. The zap residual is booked, and a sweeper's pretransferred claim reverts |
| G6: exact-out zap-out | Delivers ≥ amountOut (+1 wei). Burns the same shares exact-in would need |
| G7: unseeded deployVault(pool) (offset 0), 1-wei mint + 3162 LP donation, victim deposits 1265 LP with minOut 0 | Victim gets 0 shares, but the attacker loses 949 LP. Griefing only. Already known (receiptbacked-first-deposit-inflation, Aerodrome refuted on economics) |
| UniV2 H1 / Camelot H1: JIT around the k-growth fee mint | LP back = in - 1 |
| UniV2 / Camelot H2: zap round trips | out < in |
| UniV2 H3: exact-out zap-in at preview(10e18) shares | used = 10e18 - 1 |
| Camelot H3 | exact-out tokenA→vault returns `InvalidRoute` (deliberate, CamelotV2StandardExchangeOutTarget.sol:715-718) |
| UniV2 / Camelot H4: exact-out zap-out | Delivered = amountOut. Burns the same shares as exact-in |
| UniV2 / Camelot H5: price push 1000/5000 then fee-mint trigger then swap back | Attacker net -5.5/-21.2 (UniV2) and -9.2/-35.3 (Camelot) |
| UniV2 / Camelot H6: unseeded 1-wei + 1000-LP donation, victim 400 LP | Donation is ignored by the lastTotalAssets pricing. Victim gets 8e8 shares, attacker loses 500 LP |

Run totals: AeroCompoundDustDoS 5/5, AeroValueConservation 7/7, UniV2ValueConservation 6/6, CamelotValueConservation 6/6 PASS.
Known items that were not re-reported: prepaid-credit-refund-sweep, lp-strict-equality-donation-dos (1b358bdf only names the revert), camelot-passthrough-unbooked-payout, r2 Camelot exact-out strict equality, crane-erc4626 fee desync.

## Reviewer note (adversarial review, re-run 5/5 PASS)
- Hardened the PoC: every caught revert is now asserted to be Pool `InsufficientOutputAmount()` (0x42301c23). Added an exact-out zap-out route (`exchangeOut` shares to exactly 1000 USDC), which also reverts. Added `assertGe` that the attacker's LP is fully recoverable.
- The SY `_redeemLpSharesFrom` route is NOT exercised by a test. It is covered by static reading only: it calls `_claimAndCompoundFees` unconditionally at Common.sol:41.
- No duplicate found. Earlier work on Aerodrome compound-on-touch (h3 spot-pricing, p3c) covered sandwich profitability. lp-strict-equality-donation-dos is a different root cause (LP donation versus a balance equality check).
- Severity is low. The impact is liveness only, with no principal loss, and Aerodrome SE is not deployed on 4663.
