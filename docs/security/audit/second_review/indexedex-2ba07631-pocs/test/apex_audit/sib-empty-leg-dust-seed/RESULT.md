# sib-empty-leg-dust-seed: siblings of dry-econ-weighted-partial-dust-seed (HEAD 2ba07631)

Parent finding: UniswapV4WeightedSwapHook, partial book with n>=3. Anyone can seed an empty leg with dust and then drain the funded legs. That run made +6998e18.

## Executed on the t4 worker

### 1. UniswapV4StandardExchangeWeightedBufferHook partial path: CONFIRMED (high, code-level)

- File: SeWeightedPartialDustSeed.t.sol. Suite result: ok. 7 passed; 0 failed.
- Setup: the package default, `ownerOnlyLiquidity=false` (TestBase `_pkgOwnerOnlyLiquidity()`). n=3 with equal weights. Leg0 is buffered by an ERC4626 SE; legs 1 and 2 are raw.
- Honest LP: does the D40 partial first mint of 1000e18 + 1000e18, leaving one leg at 0.
- Attacker: unprivileged, uses no cheatcodes after setup. It calls `joinProportional` with dust 1e9 on the empty leg. `LiqLib._scanProportional` sets used=amount with no minimum and no ratio or NAV check, and the book becomes full. The attacker then makes about 77 router swaps of the dust leg into the funded legs, each at 29% of the dust-leg reserve, which stays under MAX_IN_RATIO. Finally it exits its dust shares.

| test | attacker net (price 1, all spend counted) | victim LP out / in |
|---|---|---|
| rawEmptyLeg (leg2) | +1998.33e18 | 0.675e18 / 2000e18 |
| rawEmptyLeg1 (payout via SE unwrap) | +1998.33e18 | 0.675e18 / 2000e18 |
| seEmptyLeg0 (dust-seed the SE leg) | +1999.30e18 | 0.698e18 / 2000e18 |
| withDexFee 0.3% | +1998.50e18 | 0.501e18 / 2000e18 |
| largeBook 1M/leg | +1,998,911e18 | 89.3e18 / 2,000,000e18 (attacker used about 41e18 of its 1000e18 budget) |
| frontrunHonestSeeder | +1998.33e18; the honest fair seed then reverts on slippage | 0.675e18 / 2000e18 |
| control_fairSeed | fair 1000e18 seed gives C->A 1e18 -> 0.948e18 (normal) | n/a |

- Root cause: `UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.partialJoin` / `_scanProportional` (lines 53-70), reached from `JoinCore._partialJoin` (lines 287-307) and from the LiquidityTarget copy (lines 172-192). It is the same defect as the parent, in separate code that needs its own fix. Swaps go live once rIn and rOut are both above 0 (HooksTarget `_hookBeforeSwap` has no full-book or min-depth gate).
- Live exposure: none found. Package 0x42F40974 has 0 instances. The one live SE weighted hook (0x46E068c2, 60/20/20) is `ownerOnlyLiquidity=true` and already a full book. This is a code-level finding for any deployment with n>=3 and `ownerOnlyLiquidity=false` that is in a partial state. PRD D40 explicitly allows staged partial seeding.
- Fix: the same as the parent. Gate the seed of a zero leg (owner/factory only). Or require the seed to be NAV-consistent with the funded book (rate/oracle or min value vs book). Or keep doors touching a freshly seeded leg closed until a minimum-depth seed lands.

### 2. UniswapV4OrbitalSwapHook partial path: CONFIRMED, low (bounded by the radius)

- File: OrbitalPartialDustSeed.t.sol. Suite result: ok. 2 passed.
- Setup: honest (1000, 1000, 0). R = 10,000e18. The attacker dust-seeds leg 2 and sells it in 5e18 steps.
- Result: attacker +9.40e18, victim out 1988.61e18 of 2000e18 (-0.57%).
- Why it is bounded: sphere prices (R-x_i)/(R-x_j) are bounded near 1, so a dust leg only opens a premium of about R/(R-x). This is the known coverage/b02 orbital partial-join note (rawleg-rp-lp-valuation family). Not new.

## Code-checked, not reachable

- SE Curve quad / SE Balancer quad / plain Curve quad / plain Balancer quad: `_firstMint` requires every leg >0, and once supply>0, `_computeJoinProportional` reverts NotFullBook. There is no partial book, so the zero-leg seed path does not exist.
- SE weighted single/unbalanced joins while partial: all revert NotFullBook. Full-book exits cannot zero a leg (WouldZeroReserve, D48).

## Duplicates of known first-seed classes (not re-executed)

- FullSpread hookless/Pons/V3FS first mint at any ratio, and position import at an attacker spot: p2 fs-first-mint-import.
- Wings bootstrap (supply==0 books live balances): p2 wings-bootstrap-and-misc.
- Balancer pool init (shares-only init, virtualTTA): p6 fz-balancer-sharesonly-join.
- ReceiptBacked / 4626 first-deposit: p2/p3 receiptbacked-first-deposit-inflation.
- DETF reserve bootstrap (MixedBuffer `bootstrapFirstBond`, MultiVaultWeighted / ComposedStable `initializeReserve`): permissionless, but all legs must be >0. The bootstrapper funds the whole reserve itself and the LP goes to the DETF/bond NFT, so there is no pre-existing honest victim. Later bonds that price against a skewed spot fall under detf-bond-spot-valuation and h2v-balancer-detf-bond-mint-spot-no-unlock-gate.
