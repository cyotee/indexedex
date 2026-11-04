# gx-aave-stata: Aave V3.6 Stata SE adversarial execution (HEAD 2ba07631)

Test file: `test/apex_audit/gx-aave-stata/GxAaveStataAdversarial.t.sol`. It runs on the real Crane Aave v3.6 market + StataTokenV2 + the IndexedEx Stata SE diamond. The listed asset is a mintable 18-dec token. A real borrower is warped 180 days, so the liquidity index is 1.00183 RAY. The vault has a dead seed, so first-deposit inflation (a known class) is excluded.
Run: `forge test .../gx-aave-stata/GxAaveStataAdversarial.t.sol -vvv`. Suite result: **ok. 8 passed; 0 failed**.

## NEW: T1, a 1-wei underlying donation bricks every underlying entry (confirmed DoS)
`AaveV3StataStandardExchangeCommon._investUnderlyingIntoStata` (Common.sol:126-134) sweeps the booked local underlying with `stata.deposit(sweep_)`. It does not check that the sweep converts to at least 1 Stata share. StataTokenV2 `_deposit` reverts `StaticATokenInvalidZeroShares()` (0x645f628e) when shares == 0. Once the index is above RAY, `previewDeposit(1) == 0`.
Attack:
1. Transfer 1 wei of underlying to the SE.
2. Run any op that ends in `_syncAllExpectedHoldReserves`, which books the 1 wei. The test uses the attacker's own small deposit.

After that, every underlying→SE exact-in, every exact-out wrap (`_wrapUnderlyingForExactShares` L132) and every SY `deposit(underlying)` reverts. The block survives a 7-day warp. Stata and aToken entries do not sweep, so they still work and do not clear it. Only an exit to underlying clears it, because `_payUnderlying` spends the local wei first. The attacker can then re-grief for 1 wei + gas.
Output: `victim SY deposit ok? false 0x645f628e / victim exactIn ok? false 0x645f628e / victim exactOut wrap ok? false 0x645f628e`.
The same revert also happens naturally when the remaining Aave cap margin `capacity_` is 1 wei: `deposited_ = capacity_` mints 0 shares.
Fix: skip sweeping or investing when `stata.previewDeposit(x) == 0` and leave that amount booked locally. Apply this to both the sweep and the `deposited_` leg.

## NEW: T2, booked aToken is counted as backing but no exit can pay it (griefing, last exiter loses)
`backingReceiptUnits(..., true)` adds the booked aToken (expected-hold extra, DFPkg:253-258) to backing. No exit route pays out aToken:
- `_deliverStata` and the exact-out paths pay only from held Stata or local underlying.
- No route sweeps aToken into Stata.

A donated aToken is booked at the next sync and raises the per-share claim. Early exiters are paid that higher claim out of the held Stata, so the last exiter cannot exit.
Run: A and B each deposit 100e18, then an attacker donates 10e18 aToken. A exits and gets 104.975e18. B's full exit reverts. The most B can realise is 96.026e18, against a fair value of 100e18 before the donation. The 10e18 aToken is stuck for good.
- The attacker loses money: it pays 10e18 so that B loses about 3.97e18. It nets about -5e18 if it is A.
- So this is griefing or a locked-funds issue (low), not theft.
T2b: REFUTED by reviewer. The original stata-exit probe ran after A had already fully exited (0 shares), so it reverted on amount_==0 (InvalidStataPayment) and not because of dust aToken. With a snapshot-isolated probe, both full-exit faces succeed with 3 wei of aToken dust.
Fix: depositATokens the booked aToken into Stata at sync, or leave the aToken extra out of backing.

## Held (refuted by execution)
- T3: 40 exact-out wraps (1, 2, 3, 7, 1e9+1 and 3.3e17 shares) followed by a full exact-in redeem. Start 1000e18, end 1000e18 - 30 wei, so no profit.
- T4: 60 tiny exact-out unwraps (1, 2 and 1e6+1 wei). The attacker got 20000080 underlying for burned shares worth 20000089, so the ceil burn holds.
- T5: supply cap full, so D22 books 100e18 locally. An attacker swaps 150e18 of Stata for underlying through the local cash. Payout = fair. NAV per share is unchanged (1.00183e18 before and after), and B then exits with 99.99e18.
- T6: aToken→SE pull at index > RAY over 8 odd amounts: 8 ok, 0 fail, 0 aToken dust left.
- T7: a prepaid Stata entry and a pull entry mint the same shares (39926900954622119913 each).

Known classes (not re-reported): prepaid-credit-refund-sweep, receiptbacked-first-deposit-inflation, protocol-value-as-unbooked-credit (aToken accrual), unbooked-double-role, sy-redeem-internalbalance-unattributed, create3-name-only-salt.
Live: no Stata SE is deployed on 4663 (per prior manifests), so both findings are latent.
