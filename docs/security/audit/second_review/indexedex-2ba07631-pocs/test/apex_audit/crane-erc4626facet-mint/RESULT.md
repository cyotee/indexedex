# crane-erc4626facet-mint — RESULT: CONFIRMED (staking: full drain; UniV2: fee-desync dilution)

## A. Staking SE free mint (EtherFi weETH / Lido wstETH / RocketPool rETH) — CONFIRMED, full drain
Root cause: the DFPkg facetCuts (e.g. EtherFiWeETHStandardExchangeDFPkg.sol:162-166, cut[3]) Add the
generic Crane ERC4626Facet (deposit/mint/withdraw/redeem). initAccount sets lastTotalAssets=0, and the SE paths never
update it. Crane `_secureReserveDeposit` credits `balanceOf(this) - lastTotalAssets`, and it skips the transferFrom when
that already equals `assets`.
Attack (unprivileged EOA, zero capital, one tx each): `deposit(W = asset.balanceOf(vault), attacker)` mints
W*(S+1000) shares for nothing. Then `exchangeIn(vaultShare -> asset)` (or Crane `redeem`) pays out the whole reserve.

Runner output (victim deposits 100 of the asset through the SE path first):
- EtherFi: minted 1.001e43 shares for a 0 transfer; attacker weETH +100e18; victim redeem value 99.9e18 -> 0. Crane-redeem variant also +100e18.
- Lido: attacker wstETH +100e18; victim 99.9e18 -> 0.
- RocketPool: attacker rETH +100e18; victim 99.9e18 -> 0.
Files: EtherFiCraneFreeMint.t.sol, LidoCraneFreeMint.t.sol, RocketPoolCraneFreeMint.t.sol (all PASS).

Reach caveat: no deployment manifest or script deploys these three packages (on Robinhood 4663 or anywhere else). They
are only built in test bases, so this is a latent issue that would be critical on deploy.
Fix: wire the ReceiptBacked/RebasingAware ERC4626 facet (as the ERC4626-SE and Aave-Stata SEs do), or drop the ERC4626 mutators from these packages.

## B. UniV2 SE (Camelot has the same structure) — CONFIRMED as fee-checkpoint desync / holder dilution
A Crane `deposit` updates lastTotalAssets but does not call `_checkpointVaultReserves`. The next SE op treats the
deposited LP's underlying as "fee yield" and mints oversized fee shares to feeTo.
Run (usageFee 0.1%, vault owns 100 LP of a 1010 LP pool, depositor puts in 10 LP):
- control (same LP deposited via the SE path): 0 fee shares
- Crane deposit: 1.01e26 fee shares; alice's LP value 99.99999 -> 99.90827 (-0.0917 LP, about 0.09%)
The loss scales with D/L0 * poolSupply/L0 * usageFee. The value goes to the protocol feeTo, not to the attacker, so this
is griefing or an accidental loss for honest ERC4626 integrators. Low/medium severity.
Parts (a)/(b) of the V2 hypothesis (claiming unbooked LP, burning diamond-held shares) were not re-PoC'd. They duplicate
the already-reported pretransfer class, since a one-line contract can already do this through the SE path.
File: UniV2CraneFeeDesync.t.sol (PASS). UniV2 SE is not in the live 4663 fee-accrual manifests.
