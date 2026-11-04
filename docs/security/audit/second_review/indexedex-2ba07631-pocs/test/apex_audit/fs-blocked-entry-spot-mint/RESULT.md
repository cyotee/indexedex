# fs-blocked-entry-spot-mint: CONFIRMED (hookless and Pons V4 FullSpread)

Files: `FSBlockedEntrySpotMint.t.sol` (hookless, plus break-even sweep and control), `FSBlockedEntrySpotMintPons.t.sol` (Pons).
Run: `forge test <file> -vv`. All 9 tests pass.

## What the attack does
1. `FSAttacker` is an unprivileged contract. It calls `PoolManager.unlock` itself, so `canOpenPoolManagerUnlock()` returns false and the vault runs in blocked mode.
2. Inside the callback it swaps token1 -> token0 until sqrtP is 2x (k = 4). This makes token0 scarce in the vault's live-slot0 book. Deltas are settled from the attacker's own capital, which is counted as cost.
3. It enters the vault in blocked mode using one of two routes:
   - `exchangeIn(token0 -> vault)`, the single-sided deposit (InBase.sol:304-312)
   - `exchangeOut(token0 -> vault)`, the blocked-only exact-out mint (OutBase.sol:59-71)
4. It swaps back to exactly the original sqrtP (the code checks this), settles, and the unlock closes.
5. With the PM locked (vault idle) it exits with `exchangeOutOneToMany`, a pro-rata dual exit at the fair price.

Profit and loss are valued at the restored price P = 1. Both tokens have 18 decimals. Vault NAV includes uncollected fees.

## Setup
Real PoolManager, TWAP oracle and vault, all registry-deployed by the project's Acceptance fixture. Default sleeve is 20%.
- Hookless pool fee is 0.3%. The Pons pool has LP fee 0 and a 1% creator tax plus the hook's fee policy.
- The honest LP deposits 1000/1000 through the normal idle path before the attack.
- External full-range LP liquidity is 1000e18 in the main case. The vault then holds about 45% of active liquidity.

## Results (k = 4)
| case | shares minted vs fair | attacker net profit | victim (honest LP) delta |
|---|---|---|---|
| Hookless single-sided, a = 800 | 539.9 vs 400 | **+174.8 (873 bps of TVL)** | -179.3 |
| Hookless exact-out mint, s = 52% of S | paid 764.4 for 520 shares (fair 382.2 shares) | **+174.3 (871 bps)** | -178.8 |
| Pons single-sided | 539.9 vs 400 | **+126.8 (633 bps)** | -181.8 |
| Pons exact-out mint | same | **+126.3 (631 bps)** | -181.3 |
| Control, k = 1 (no price move) | 341.6 vs 400 | -87.0 (-434 bps) | +87.0 |

## Break-even sweep (hookless, vault share of active in-range liquidity)
| vault share of active liquidity | net profit |
|---|---|
| ~45% | +873 bps |
| ~10% | +727 bps |
| ~4% | +445 bps |
| ~2% | -28 bps (k = 2: -147 bps) |
| ~1% | -931 bps |
| ~0.08% (project default fixture depth) | -21,700 bps |

The victim's loss is about -179 at every depth. When the attack is unprofitable for the attacker, it still costs the vault's LPs money, but the attacker pays more in swap fees.

## Corrections to the hypothesis
- The dual-deposit sub-claim was not tested. All three skeptics refuted it by AM-GM.
- Profit is bounded by the free sleeve, not by about sqrt(k) times unbounded value. The measured profit matches the econ lens formula `1 - sqrt(beta(2-beta))`, which gives about 8.3% at sigma = 0.2 and k = 4.

## Preconditions
The vault must hold at least about 3-4% of in-range pool liquidity at a 0.3% fee. This is plausible when the vault is the main LP of its own pool. No flash loan is needed for the price move, because V4 flash accounting covers it. The deposit amount `a` (about 0.8 x the vault's token0 backing) is capital that comes back at exit, and can be flash-borrowed (about 5 bps).

## Live exposure
Per P2, the one live Pons FS vault on chain 4663 (0x999D...1009) is dust-seeded, so nothing can be extracted today.

## Fix
Do not admit single-sided or exact-out mints in blocked mode. Alternatively, price blocked-mode entries against a manipulation-resistant reference (TWAP or a stored idle-mode book), with a deviation revert.
