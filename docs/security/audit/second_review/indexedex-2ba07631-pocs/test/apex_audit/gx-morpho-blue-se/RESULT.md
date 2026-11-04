# gx-morpho-blue-se: Morpho Blue SE adversarial execution (HEAD 2ba07631)

Run: forge test test/apex_audit/gx-morpho-blue-se/MorphoBlueSE_GX.t.sol -vvv
Suite result: ok. 14 passed; 0 failed. The audit profile ran 16 fuzz runs per fuzz test.
Fixture: TestBase_MorphoBlueStandardExchange (real hermetic Morpho + AdaptiveCurveIrm + production DFPkg/diamond).

## Breaks (both latent: MorphoBlueStandardExchangeDFPkg 0x829B9130 is deployed on 4663 with 0 vaults)

### B1 (LOW, confirmed_user_loss): decimalOffset=0 share inflation / zero-share deposits
- DFPkg.initAccount calls `ERC4626Repo._initialize(loan, dec, 0)`. The only protection is a virtual +1 share/+1 asset.
- deposit() and exchangeIn(minOut=0) do not revert when 0 shares are minted.
- Vault deploy is permissionless (T2: an attacker creates a Morpho market and deploys the canonical SE, which starts at supply 0 with no dead shares).
- The donation goes through `morpho.supply(onBehalf=SE)`. It is counted in _liveNav, and no pretransfer sweeper can claim it.
- T2a, single victim: attacker deposits 1 wei and donates 10k; a victim deposits 4,999 and gets 0 shares. Victim loses 100% and the attacker loses 2,500. This is griefing only.
- T2b, four victims of 5,000 each, all 0 shares: attacker net is +5,000 at fair price, victims lose 20,000, and 15,000 is left orphaned to the virtual share.
- By hand, mixed victim sizes (3k/7k/12k/26k) are unprofitable for the attacker. They are still heavy griefing (about 8.5k victim loss).
- T2c: exchangeIn with minOut=1 reverts (Slippage), so slippage-bounded routes are protected.
- Fix: decimalOffset >= 6 (or seed dead shares at deployVault), plus `require(shares > 0)` on deposit/exchangeIn.
- Same class as receiptbacked-inflation (ERC4626 SE). The Morpho economics differ because of the virtual +1.

### B2 (INFO, duplicate class of prepaid-refund-sweep): IERC4626 owner=address(this) (P2 morpho-erc4626-owner-self, now EXECUTED)
- T1: a victim leaves 50k worth of SE shares resting on the diamond (step 1 of a 2-step pretransfer, or a misdirected transfer).
- A plain EOA calls `redeem(stranded, attacker, se)` and receives 50,000 loan. The EOA pretransfer control reverts (EOAPretransferNotAllowed), but redeem with owner=se needs no contract and no allowance.
- T1b: the withdraw() variant takes 100k.
- T1c: LP-owned shares are unreachable, and with nothing resting on the diamond the call reverts.
- The honest LP's value is unchanged. Only third-party resting value is at risk, and any 2-line contract could already take it via the prepaid path, so this adds no new capability. It confirms the P2 reach vote (refuted as a separate vuln; info).

## Held (refuted by execution)
- T3a: pretransferred exact-out wrap via AtomicPretransferCaller, at 33% utilization after 30d interest. paid == previewExchangeOut quote, the refund is exactly push-paid, and LP value is not diluted (`navBefore -= credit` is correct).
- T3b: pretransferred exact-in wrap mints exactly the quote, and LP is not diluted (`navBefore -= actualIn` is correct).
- T4: 365d of pending, unaccrued interest. The NAV view includes it (LP 100,847). A just-in-time 900k deposit then redeem gives the attacker pnl = -1 wei, and the LP keeps the interest (expectedMarketBalances is used everywhere).
- T5: bad debt from an oracle halving plus full liquidation drops NAV from 200,000 to 168,000. The loss is pro-rata across LPs, a late depositor after realization gets a fair 50,000 back, every holder can maxRedeem and fully exit, and residual NAV is 0. (Holders exiting before realization dodge the loss, which is inherent to Morpho Blue and the same for MetaMorpho.)
- T6 fuzz, repay amount x time at 100% utilization: maxWithdraw is 0 at full utilization, redeem(maxRedeem) never reverts, redeem(maxRedeem+1) always reverts, and withdraw(maxWithdraw) succeeds. The maxRedeem inversion is correct.
- T7: after a full exit the residual NAV is 1 wei, and a re-entering depositor's value is fair.
- T8 fuzz, deposit or mint then redeem, with idle donation + interest + utilization: no round-trip profit, and the LP is not drained.
