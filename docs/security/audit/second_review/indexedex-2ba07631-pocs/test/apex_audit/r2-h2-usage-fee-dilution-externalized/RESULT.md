# r2-h2-usage-fee-dilution-externalized: RESULT

Status: CONFIRMED (the mechanism runs as described). Severity: LOW (unprivileged griefing of LPs that benefits the protocol, with no attacker profit) plus INFO/centralization (operator can set a 100% fee instantly).

Test: `R2UsageFeeDilution.t.sol`. It reuses the fixture from h2-admin-upgrade/UsageFeeDilution.t.sol (TestBase_ERC4626StandardExchange, real ERC4626 SE diamond via DFPkg) and adds test C, an accounting test.
Run on the audit runner: `forge test .../R2UsageFeeDilution.t.sol -vv --skip V3FSHandler V3FSInvariant V3FSSanity`. The skip is needed because the the audit runner slot copies of p4-v3fs/V3FSHandler.sol are stale and do not compile (stack too deep), which breaks the audit-profile build. Result: 3/3 PASS.

## Results
- A, unprivileged, live default usageFee = 5%. The LP holds 1000 receipts. The griefer round-trips 10 receipts x 20.
  The griefer loses 0.0990 receipts and the LP loses 9.380 receipts (~95x). All of it accrues to feeTo.
- C, accounting. The depositor receives exactly the pre-fee `userShares`. Supply grows by `s + 5% * s`, so the fee is minted on top.
  The griefer's balance strictly decreases (no attacker profit). feeTo gain (9.479) equals LP loss (9.380) plus griefer cost (0.099).
  For comparison, if the fee were deducted from the depositor, the depositor would pay 10 receipts and LPs would pay 0.
- B, privileged. Owner calls `setUsageFeeOfVault(se, 1e18)`, which takes effect instantly; the only check is `<= WAD`. feeTo cycles 1000 receipts x 5.
  LP value falls from 952.38 to 67.01. feeTo extracts 885.37 beyond its legitimate fee, and that equals the LP loss.

## Assessment
- The code does what the hypothesis says. `_mintWithUsageFee` (ERC4626StandardExchangeCommon.sol:224-234) mints the full `userShares` to the user and then mints `userShares*fee` to feeTo. The `minAmountOut` check runs on the pre-fee `amountOut` (InTarget:68-79). Redeem has no exit fee.
- The behavior is documented as intended. The code comment says "User receives full userShares; fee expands supply to feeTo" (D40/D40a/D57), and the Morpho PRD D29 calls it the "Stata inflation pattern". The flaw is in the economics: every depositor's usage fee is paid by existing holders. An outsider can force LPs to pay the fee at about S/s leverage, but the outsider cannot profit. The value goes to the protocol's own feeTo.
- Unprivileged attacker profit: none (cost 0.099 per 200 cycled). Victim loss: about 4.7% of the cycled volume, taken from LPs and paid to feeTo.
- Privileged path: this is a centralization or rug risk (100% fee, no timelock). Recommendation: deduct the fee from the depositor's shares, cap the usage fee well below 100%, and put fee changes behind a timelock.
