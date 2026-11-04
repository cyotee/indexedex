# chain-detf-system: CONFIRMED. The composite beats every single primitive, and the bond leg dominates.

Test file: `ChainDetfSystem.t.sol`. Run it with FOUNDRY_PROFILE=audit forge test --match-path .../chain-detf-system/ChainDetfSystem.t.sol -vv --match-contract '^ChainDetfSystemTest$' --skip "'*/p4-*/*'"`.
The `--skip` is needed only because foreign files `p4-fs/FSInvHandler.sol` and `p4-v3fs/V3FSHandler.sol`, which other agents left in the t4 slots, currently fail with stack-too-deep.

## Product modeled (scripts/foundry/anvil_robinhood_main)
- DETF over a 3-token weighted buffer hook: DETF 60 / pair0 20 / pair1 20, the FEE_ACCRUAL weights. Each pair leg sits behind an SE vault (ERC4626 SE).
- Real V4 PoolManager, bond NFT and sDETF staking. `ownerOnlyLiquidity = true`.
- FixtureEconomics settings, applied by the owner before the attack: dexSwapFee 3e14, seigniorage 5%, bond terms 1 day to 180 days with 0–50% bonus.
- `ChainDetfSystemDeployedThrTest` reruns the same tests with the launch json thresholds (mint 1.05, burn 0.95). The results are identical: the pair0 synthetic price is 4.7, and the bond path has no gate.
- Honest state:
  - first bond of 1000 pair0 (180 days)
  - 60 honest mints of 100 pair0
  - a 90-day honest bonder with 300 pair0
- The honest minter's DETF (581e9, 62% of the pool's DETF reserve) is lent through a simulated flash lender. It charges 0.10% and must be repaid in the same tx (asserted).
- The attacker is an unprivileged contract using public hook, DETF, sDETF and bond-NFT calls only. It must restore its pair1 float (asserted), ends the tx holding no liquid DETF (asserted), and all PnL is measured in pair0.

## Winning chain (test_chain_max2, X2), one tx
1. Flash-borrow δ DETF and dump it against the **pair0** leg. This raises rD and lowers rP0.
2. `bond(pair0, 1000, 1 day)` in 2 chunks:
   - g = rD·B/rP0 is inflated twice over (both rD and rP0 moved), and the protocol mints g and joins it with minLp=0.
   - The principal is priced from the depressed pair0→DETF spot.
3. `exchangeIn(pair0 300 → DETF)` mint. The bond join refilled rP0, so the pair0 gate is open again, while spot is still depressed.
4. Buy back only δ+fee DETF. The over-minted g stays in the pool.
5. Sell the surplus DETF, restore pair1, repay the loan.
6. After the 1-day lock, claim the bond and sell the principal into the pool.

## Results (runner output, pair0 units, 1e18)
| scenario (flash = 62% of pool DETF) | realized | atomic in-tx |
|---|---|---|
| honest bond 1000 + mint 300 (no flash) | -189.1 | -1002.8 |
| spot-mint single (third-leg dump, mint 300) | +158.3 | +158.3 |
| spot-mint single (pair0-leg dump) | reverts (0x7939f424) | — |
| bond-spot single (pair0-leg dump, bond 1000) | +3030.0 | +1076.8 |
| bond-spot single (third-leg dump, bond 1000) | +1608.1 | +609.1 |
| **COMPOSITE X2: pair0-leg dump, bond 1000, then mint 300** | **+3089.3** | **+1255.5** |
| bond-spot single, bond 2000 | +3311.8 | +651.7 |
| COMPOSITE X4: bond 2000, then mint 300 | **+3314.5** | +747.4 |
| third-leg composite (test_chain_max): mint 300 + bond 1000 | +1623.3 | +677.4 |

- **Composite beats the best single primitive:**
  - X2 vs bond-spot at the same size: +59 realized, +179 atomic.
  - X4 vs X3: +2.8 realized, +96 atomic.
  - X2 vs the best spot-mint: about 20x.
  - All of these are asserted in `test_chain_max2` and `test_chain_max`, which both PASS.
- **Victims are every DETF holder and bonder.** All reserve LP is protocol-owned. After X2 is realized:
  - Reserve pair value falls from 14,585 to 11,491 pair0, a loss of 21.2%, which matches the attacker's gain.
  - Backing per 1e9 circulating DETF falls from 6.714 to 5.150 pair0 (-23%).
  - Honest bond principals are fixed DETF amounts, so they lose the same 23%.

How profit scales with DETF inventory (`test_chain_inventorySweep`, X2 shape):

| flash DETF as % of pool DETF | realized | atomic |
|---|---|---|
| 5% | -5.5 | -978 |
| 10% | +185 | -921 |
| 25% | +921 | -556 |
| 50% | +2397 | +579 |

## Primitives that do not compose (execution evidence)
- **JIT staking of the seigniorage pot.** `fundRewards` rebases instantly, but in this setup it does not pay: the attacker captured 0.054e9 DETF against a 0.17e9 flash fee, and realized PnL went from 109.4 to 106.7.
- **Pair-drain without DETF inventory.** Flash pair1, buy pair0 out of the pool, bond, then restore. This is always worse than an honest bond: -16 to -59 pair0. The attacker holds no DETF to buy back the over-minted g cheaply, so a DETF float is required.
- **SE underlying manipulation.** ERC4626 SE rates can only be pushed up (by donation). That raises rP0 and shrinks g, which is the wrong direction. Per-leg rates also cancel in the weighted hook. Not composable.
- **dual-identity-outleg-zero.** This sits in the DUAL CP hook's `_exitSingleAssetFrom`. The DETF product uses the weighted hook, and DETF burn uses `exitProportional`, so the path is unreachable. The bug also needs a victim calling with min=0. Not composable.

## Notes and caveats
- **This overturns P3's detf-bond-spot "weighted not profitable".** That run used 30d/180d locks and spot restoration on every leg. Under the deployed 1-day minimum lock and 0.03% fee, with an unwind that buys back only δ, the bond is the dominant extraction on the live-like 60/20/20 family.
- **Preconditions.**
  - DETF inventory of about 10% or more of the pool's DETF reserve for a realized profit, and about 45% or more for an atomic profit. It is returned plus a fee in the same tx: whale, lender or LP.
  - The realized portion carries 1 day of lock and price risk. The PoC realizes it with no other market activity.
- **Not executed on the live 4663 fork.** Live DTF-DETF runs pre-HEAD code. Its TVL is about 2.1 WETH-equivalent (census).
- **Fix.**
  - Price bond g and the principal, and mint gross, from a manipulation-resistant reference (TWAP or synthetic) with a deviation band.
  - Add min-out/minLp to `bond()` and `_joinUnbalanced`.
  - Gate bonds like mints, or cap the bond size per tx.

## Adversarial review (2026-10-21)
- Re-ran `test_chain_max2` on t4: PASS, numbers reproduce exactly (X2 +3089.3 realized / +1255.5 atomic; pool pair value -21.21%; backing/1e9 circ DETF 6.714 -> 5.150).
- Cheat scan clean: owner pranks / vm.etch / fee + bond-term config only in setUp/_setupHonest (values match FixtureEconomics: MIN_LOCK 86400, DEX_SWAP_FEE 3e14, SEIGNIORAGE 5e16, weights 60/20/20). Attack tx is an unprivileged contract (prank only sets msg.sender/tx.origin to a fresh EOA); no store/deal/mockCall during the attack; own pair0 minted to attacker is netted out; pair1 restored, zero DETF left, lender repaid + 0.10% (all asserted); PnL is pure pair0 from real swaps.
- Mechanism confirmed in source: `_purchaseBond` quotes g and the principal from live pool state (`_quoteBondG`, `_quoteBondPurchase`) and `_joinBond` has no caller min-out.
- Minor: in `test_chain_max2`, "composite > spot-mint single" is vacuous because X1 reverts (rp[1] = int min). The +158 third-leg spot-mint comparison lives in `test_chain_max`.
- **Caveat (new test `test_chain_whaleMTM`).** The profit depends on borrowing DETF from a third party and repaying it in units that have lost value. If the 581e9 DETF float is the attacker's own:
  - Valued at backing, the inventory marks down by 910 pair0, so the net is +2180 (still profitable).
  - Valued at pool spot, DETF falls from 0.02346 to 0.00586 per 1e6 wei after realization (-75%). The inventory marks down by 10,234 pair0, so the net is -7144.
  - So the attack is clearly profitable only with a DETF lender (a money market or OTC loan) or LP-lent float. No such market is evidenced on Robinhood 4663, and live TVL is about 2.1 WETH running pre-HEAD code.
  - DETF holders' market-value loss (spot -59% right after the tx) is larger than the 23% backing dilution.
