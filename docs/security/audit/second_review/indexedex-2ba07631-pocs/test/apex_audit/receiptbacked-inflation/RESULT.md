# receiptbacked-first-deposit-inflation: CONFIRMED (generic ERC4626 SE; latent, not deployed on 4663)

Test: ReceiptBackedInflation.t.sol (fixture TestBase_ERC4626StandardExchange + SimpleYieldERC4626). 4/4 PASS.

Mechanism: ReceiptBackedERC4626AccountingLib.sharesFromReceiptUnits returns 1:1 at supply==0, otherwise floor(delta*S/backing).
backing = live receipt balanceOf. No virtual offset. No zero-share revert in ReceiptBackedERC4626Target.deposit (lines 100-112).

Attack (attacker is unprivileged throughout):
1. Attacker calls ERC4626StandardExchangeDFPkg.deployVault(protocolVault). This is permissionless, and the salt makes it the canonical vault.
2. Attacker calls deposit(1), gets 1 share, then transfers D = 10,000e18 receipts to the vault.
3. Victim calls IERC4626.deposit(9,999e18) and gets 0 shares. The call does not revert.
4. Attacker calls redeem(1) and receives 19,999e18 + 1. Net profit = 9,999e18 receipts (= 9,999e18 underlying), exactly the victim's loss.

Other results:
- Partial theft: a victim deposit of 19,999e18 gets 1 share and loses 4,999.5e18, which the attacker gains.
- exchangeIn with minAmountOut=0 also mints 0 shares; the attacker gains 9,999e18.
- exchangeIn with minAmountOut=1 reverts, so a slippage bound protects that route.

Not tested:
- Stata: the fixture is a placeholder. The code path is the same (AaveV3StataStandardExchangeCommon:206-217).
- Aerodrome and loop: P2 refuted both on economics (virtual +1 share; 1000 dead shares).

Severity: medium. Nothing is lost on Robinhood 4663 today because no ERC4626 SE or Stata vault is in the manifests. A victim must use raw deposit() or exchangeIn with minOut=0.

Fix: add virtual shares/assets (decimalsOffset), or seed/burn dead shares at deployVault, and revert when shares == 0.
