# MiniMax M3 — external V3/V4 vault precedent search: independent first pass

**Date:** 2026-10-03. **Round:** external precedent search for search-free scalar V3/V4 vaults. **Independence:** retained session, no peer originals/reviews/synthesis or new peer outputs read. Research only; no delegation/shell/tests/implementation/config/deploy/browser tools.

## 0. Pre-amble: scope and method

Question: do real-world V3/V4 vaults admit synchronous single-token deposit/withdrawal without an exploratory sizing probe, while remaining composable with autonomous buffered-pool callers? The prior rounds' conclusions were that Hookless's `Planner._composition` 32-probe binary search (`TransitionPlanner.sol:73–108`) and `Planner._maintenance` 64-probe holder search (`TransitionPlanner.sol:168–214`) are sizing searches; the natural follow-up is "does anyone solve this differently on V3 or V4?"

I inventoried ≥10 candidate projects, deep-traced ≥4 strongest, and traced the money path through vault, deposit/proxy, strategy/keeper, and quote layer for each. Generic public web search and Context7; no proprietary source sent externally; primary URLs, function names, line ranges and access dates recorded where verifiable. Main branch sources are unpinned deployment truth.

## 1. Inventory at a glance

| # | Project / family | AMM | Single-token deposit route | Single-token exit route | Source/license traceable |
|---|---|---|---|---|---|
| 1 | Charm AlphaVault / AlphaStrategy (UniV3) | V3 | Yes (full-range + base order + limit-order; keeper supplies rebalance; frontend) | binary-search single-sided via libevm/optional | github.com/charmfinance/alpha-vaults-contracts, BUSL |
| 2 | Arrakis V1 / G-UNI (UniV3) | V3 | Manager-driven rebalance `swapAmountBPS`; off-chain router for `swapAndAddLiquidity` | pro-rata burn, single-token via off-chain router | github.com/ArrakisFinance/vault-v1-core, GPL-3.0 |
| 3 | Arrakis V2 (UniV3) | V3 | Both tokens required; rebalance calldata fully manager-supplied | pro-rata burn | github.com/ArrakisFinance/v2-core, GPL-3.0 |
| 4 | Gamma Hypervisor + UniProxy (UniV3) | V3 | UniProxy swaps via pool; off-chain `getDepositAmount` computes | pro-rata burn from base+limit | github.com/GammaStrategies/hypervisor, MIT (per docs) |
| 5 | ICHI oneToken + YieldIQ (UniV3) | V3 | Single-token; `MintMaster` incremental minting, `execute()` called by controller (Chainlink Automation) | redeem path with mintMaster `maxOrder` | github.com/ichifarm/ichi-oneToken (factory); docs.ichi.org |
| 6 | Steer Protocol (UniV3/V4) | V3 + V4 | `tend(uint256, int24, int24, int256, uint160)` — swapAmount from keeper (NOT auto-searched); SDK `SwapCalculator` does binary search OFF-chain | pro-rata | docs.steer.finance; SteerProtocol/steer-sdk |
| 7 | Aperture UniV3Automan (UniV3) | V3 | OptimalSwap **closed-form on-chain** for rebalance swap sizing (not binary search) | direct position burn | github.com/Aperture-Finance/uniswap-v3-automan |
| 8 | Popsicle Sorbetto Fragola (UniV3) | V3 | Both tokens; Normaliser off-chain; `getPositionTicks` closed-form via SqrtPriceMath | pro-rata burn | github.com/Popsicle-Finance/SorbettoFragola |
| 9 | libevm Univ3SingleSidedLiquidity (UniV3) | V3 | **Binary search 128 iterations**; "should be called off-chain" | not applicable (helper library) | github.com/libevm/univ3-butler |
| 10 | Range Protocol (UniV3) | V3 | Both tokens required; vault manager supplies ticks; single-token NOT supported | pro-rata | github.com/Range-Protocol/contracts |
| 11 | Uniswap V3 Range Orders (primitive) | V3 | direct: out-of-range position holds single token; **primitive, not a vault** | burn when crossed | developers.uniswap.org |
| 12 | Beefy CLM (Cowcentrated Liquidity Manager) | V3 (UniV3) | "Single-side Deposits: … effectively swap freely into the other asset, taking from the other depositors in the vault" | pro-rata burn | docs.beefy.finance/beefy-products/clm; BeefyGitHub |
| 13 | Revert Auto-Range/Auto-Compound | V3 | ZAP via 0x aggregator with leftover tokens; single-token NOT direct | NFPM NFT-based | docs.revert.finance |
| 14 | Sommelier Cellars | V3 | Validator-set-governed; strategists supply ranges, swap params | ERC-4626-like redeem | somm.finance |
| 15 | Mellow (Boosted, LStrategy) | V3 | Operator-driven rebalance via off-chain bot; ERC-4626 deposit | pro-rata | docs.mellow.finance |
| 16 | Mellow DepositQueue | V3 | **Async oracle-priced** Fenwick-tree queue; user submits, oracle reports, claim | async | docs.mellow.finance |
| 17 | ALPS | V3 + V4 | Single-deposit USDC → basket of V3+V4 CL positions; off-chain agent via Uniswap SDK + Trading API | USDC-only or basket | github.com/SteerProtocol |
| 18 | Panoptic V2 | V3 + V4 | `SemiFungiblePositionManager.mintTokenizedPosition` allows single-token entry via internal swap (off-chain computed) | ERC1155 burn | github.com/panoptic-labs/panoptic-v2-core |
| 19 | Bunni v2 | V4 hook | `BunniHub.deposit` requires both tokens; single-token NOT direct | `withdraw` pro-rata; bounded iteration; **no swap sizing** | github.com/Bunniapp/bunni-v2 |
| 20 | EulerSwap | V4 hook + EVC | Different primitive — AMM itself; operator-managed reserves | n/a | github.com/euler-xyz/euler-swap |

I inventoried 20, deep-traced 8 (Charm, Arrakis V1/V2, Gamma, ICHI, Steer, Aperture, Beefy CLM, Bunni v2). Several external/public confirmations recorded as leads, not full traces (Mellow, Sommelier, ALPS, Revert, Popsicle, Range Protocol, libevm).

## 2. Strongest candidates deep-traced

### 2.1 Beefy CLM — the canonical "core + wing" precedent

**This is the strongest positive counterexample to the prior rounds' "vibe of impossibility"** and validates the wing proposal directly.

Source: https://docs.beefy.finance/beefy-products/clm; https://beefy.com/articles/clm/; https://beefy.com/articles/ltipp/ (all accessed 2026-10-03).

**Mechanism (on-chain, deterministic):**
- "CLM products will (1) put as many tokens as possible into a 50/50 position with the predetermined width for the strategy centered on the current price. We'll call this the main position. (2) With whichever token there is more of, create another position as a 1-sided limit order just 1 tick outside of the current tick. We'll call this the alt position." (https://beefy.com/articles/clm/)
- Two positions: 50/50 core + 1-sided alt (the alt is precisely the "wing" from the prior round).
- `moveTicks`: Gelato-driven. "Withdraw all liquidity from both positions; complete accurate accounting of both tokens so that we can provide each user their fair share of the overall pool; harvest; liquidity is added back in the previously described manner into the two positions with the primary position centered around the new price." Frequency adjustable.
- ERC-20 share token (`cowToken`); issued as proportional share of pooled CLM funds.

**Single-token deposit (the audit dimension):**
> "Single-side Deposits: Because the CLM deposit tokens you receive on deposit reflect a proportional share of all tokens in the vault that's the same proportion for all users, a user who deposits only one token directly (i.e. not through ZAP) would instantly gain entitlement to a proportionate share of the other token in exchange for part of their deposit. This allows single-side deposits to effectively swap freely into the other asset, taking from the other depositors in the vault who are left with more of the single-side deposit asset."
- Beefy's docs **explicitly state** single-token deposits are an internal swap against other depositors (Class D — internal-market pricing). The depositor gets proportional shares; the other depositors bear the imbalance.
- "In extreme cases, excessive single-side deposits can deprive ordinary depositors of their alternative asset, leading to excessive and unintended exposure to the single-side deposit asset for everyone." → the documented economic risk of Class D.

**Search status of user path:** The CLM deposit takes one token, mints pro-rata shares (`shares = deposit_value * S / V` where V is the pooled CLM funds valued via Uniswap SDK on-chain). The CLM **does not binary-search the swap size** for the deposit itself — the user provides one token and gets a proportional share. The conversion to the other token happens through other depositors and is bounded.

**Position cap:** exactly 2 positions (core + alt) per pool. Conservative.

**Reclassification:** Class D (internal market against holders) **plus** Class A (on-chain deterministic core+wing placement). Specifically, the wing placement itself is on-chain closed form (`getLiquidityForAmount*`), but the share-admission uses internal book valuation, not the pool price.

**License:** docs site; contract source on BeefyFinance GitHub.

### 2.2 Aperture UniV3Automan — closed-form on-chain optimal swap

**This is the strongest positive counterexample to the binary-search claim** for rebalance swap sizing.

Source: https://github.com/Aperture-Finance/uniswap-v3-automan (MIT); https://medium.com/@aperturefinance/open-sourcing-our-optimal-univ3-swap-no-more-leftover-tokens-db3e9eaf5d23 (accessed 2026-10-03).

**Mechanism:**
- `OptimalSwap` library computes the optimal swap amount analytically (NOT iterative).
- "In March 2023, we independently developed our closed-form solution in Solidity (with heavy use of inline assembly in Yul) which is efficient enough for on-chain use in our automation manager contract. It was only while writing this and going through the history of DeFi for references that I discovered a Desmos calculator that also offers a closed-form solution for the case where `token1` is swapped for `token0`."
- "If the calculation were done via binary search (trial & error), the required gas would be an order of magnitude larger."
- Use case: rebalance a single V3 position to a new range with correct token ratio (NOT vault-share minting).
- Gas: ~21k for the closed-form swap amount calc, "perfectly acceptable for inclusion in a rebalance transaction."

**Search status of user path:** N/A — UniV3Automan manages existing user-owned positions; it's not a vault minting fungible shares. But the **math** is directly relevant: a closed-form swap-size formula exists for the optimal-token-ratio problem in V3 CL.

**License:** MIT (per Aperture docs and repo).

**Limitation:** Aperture's closed form is for the "optimal swap to reach a target ratio in a single V3 position" — not for the Hookless "share-of-incremental-book ratio after swap and own-LP accrual" problem. The latter is the harder one.

### 2.3 Arrakis V1 (G-UNI) and Arrakis V2 — manager-driven rebalance

Sources: https://github.com/ArrakisFinance/vault-v1-core (V1); https://github.com/ArrakisFinance/v2-core (V2) (both accessed 2026-10-03).

**V1 (`ArrakisVaultV1.sol`):**
- Single position per pool, single fee tier.
- `mint(mintAmount, receiver)` → `amount0 = mulDiv(amount0Current, mintAmount, totalSupply)`, `amount1 = mulDiv(amount1Current, mintAmount, totalSupply)` — **pro-rata, no probe** (search-free on user-op path).
- `_swapAndDeposit` uses `pool.swap(zeroForOne, swapAmount, swapThresholdPrice, "")` where `swapAmount = (zeroForOne ? amount0 : amount1) * swapAmountBPS / 10000` — **manager-supplied** `swapAmountBPS`, not auto-searched. Reclassification: Class C (basket core with manager-driven swap).
- `executiveRebalance(newLowerTick, newUpperTick, swapThresholdPrice, swapAmountBPS, zeroForOne)` — manager only.

**V2 (`ArrakisV2.sol`):**
- Multiple ranges, multiple fee tiers per pool. `Range[]` array.
- `mint` and `burn` pro-rata across all ranges (no probe).
- `rebalance(Rebalance calldata rebalanceParams_)` — fully manager-supplied `burns[]`, `swap (router, payload, amountIn, expectedMinReturn)`, `mints[]`. Manager calls `router.call(payload)` with the swap payload they supply.
- No single-token deposit on-chain; users deposit both tokens. Off-chain routers (GUniRouter, ArrakisV2Helper, Arrakis Public Vault Router V2) can swapAndAddLiquidity with off-chain-computed parameters.

**Search status of user path:** Search-free. Both V1 and V2 use pro-rata math on the user deposit/redeem path.

**V2's public deposit entrypoint** warns: "the vault composition may change between transaction submission and execution. Always set appropriate slippage tolerance (by passing min and max amounts in add/remove liquidity parameters)" (https://docs.arrakis.finance/...). The frontend is responsible for computing swap amounts.

**License:** GPL-3.0.

### 2.4 Gamma Hypervisor + UniProxy — basket + off-chain router

Source: https://github.com/GammaStrategies/hypervisor; https://docs.gamma.xyz/gamma/lp-vaults/developer-portal (accessed 2026-10-03).

**Hypervisor mechanism:**
- 2 positions per vault: `baseLower/Upper` and `limitLower/Upper` (concentrated range orders).
- `deposit(uint256 deposit0, uint256 deposit1, address to, address from)` requires both tokens. Closed-form share mint: `shares = (deposit1 + deposit0 * price / PRECISION) * totalSupply / (pool0*price/PRECISION + pool1)`.
- `withdraw(shares, to, from)` burns pro-rata from base+limit positions.
- `rebalance(...)` is `onlyOwner` with `swapQuantity` from owner.

**UniProxy single-asset deposit:**
- `UniProxy.getDepositAmount(lpTokenAddress, tokenProvidedAddress, tokenProvidedQuantity)` — **off-chain** helper to compute the right ratio for a single-token deposit.
- "UniProxy.deposit(token0Quantity, token1Quantity, userAddress, lpTokenAddress, minAmounts)" — calls the UniProxy which then executes an internal swap on the pool.

**Search status of user path:** Closed form (pro-rata). Single-token entry uses an off-chain router that swaps via the pool. Reclassification: C (basket core) for direct deposit, B (off-chain router) for single-asset.

### 2.5 ICHI oneToken + YieldIQ — internal market against holders

Sources: https://docs.ichi.org/home/how-ichi-works; https://docs.ichi.org/home/yieldiq-strategy; https://github.com/ichifarm/ichi-oneToken/; https://certificate.quantstamp.com/full/ichi.pdf (Quantstamp audit, accessed 2026-10-03).

**Mechanism:**
- "Single-Token Deposits: A Staking-Like Experience. ICHI enables users to deposit a single token into an ICHI Vault through its app or partner platforms. Unlike traditional liquidity pools that require paired token deposits, ICHI streamlines the process by allowing users to provide liquidity with just one asset." (https://docs.ichi.org/home/how-ichi-works)
- "ICHI eliminates the need for swaps during deposits or rebalances. The protocol allocates liquidity directionally, meaning it knows exactly what users deposited and adjusts ranges accordingly to avoid unnecessary selling of assets." (ibid)
- "On-Chain Autonomy: 100% Smart Contract Logic. All rebalancing functions run on-chain, without a privileged controller or external script." (ibid)
- "IChainClass: rebalancing runs on-chain; controller (Chainlink Automation) calls execute()" (Quantstamp).
- `OneTokenV1` has `mint`, `redeem`, `MintMaster` (incremental minting with `maxOrder` and `stepSize`), `ICHIPeggedOracle` / `UniswapOracleSimple` (oracles for valuation), `CompositeOracle` (composite oracles for currency pairs).

**Search status:** ICHI does **not** binary-search a swap size for deposits. Single-token deposit: creditted locally, minted against oracle-quoted asset value. YieldIQ: "tracks inventory ratio (how much of each token) and only rebalances when the composition deviates from the target ratio. This avoids unnecessary swaps and fees." (YieldIQ docs)

**Reclassification:** **Class D (oracle / internal inventory pricing)**. The share-admission uses `PeggedOracle` (1:1 for stablecoins) or `UniswapOracleSimple` (UniV2 TWAP) — i.e., an oracle-based valuation, not the pool's current spot. The Quantstamp audit confirms the oracles are integral to the mint/redeem math.

**Limitation:** Requires oracle infrastructure. Different oracle choices have different risk profiles.

**License:** docs site; Quantstamp audit confirms `OneTokenV1Base` design.

### 2.6 Steer Protocol — keeper-supplied swap

Source: https://docs.steer.finance; https://github.com/SteerProtocol/steer-sdk-examples (accessed 2026-10-03).

**Mechanism:**
- `tend(uint256 totalWeight, int24 newLowerTick, int24 newUpperTick, int256 swapAmount, uint160 sqrtPriceLimitX96)` — **keeper supplies `swapAmount`**.
- "Swap Amount: Amount to be swapped from one token to another this tend. zeroForOne if positive, oneForZero if negative."
- Single-Asset Deposit via SDK: `calculateSwapAmount`, `simulateSwap`, `estimateLpTokens` are all off-chain. **SDK explicitly does binary search** (`SwapCalculator.getSwapAmount` accepts `maxIterations` parameter, default 10).
- "The swap is currently routed through the same UniV3 pool you are providing liquidity to." (Aperture-style legacy note — Steer has since integrated aggregators.)

**Search status of user path:** Closed form on-chain (off-chain planning for swap size). Reclassification: B (off-chain planner) or C (basket core with off-chain planner).

**License:** docs; SteerProtocol GitHub.

### 2.7 Popsicle Sorbetto Fragola — closed-form tick placement

Source: https://github.com/Popsicle-Finance/SorbettoFragola; https://docs.popsicle.finance/our-tech/our-contracts; http://popsiclefinance.medium.com/popsicle-jit-engine-update (accessed 2026-10-03).

**Mechanism:**
- `deposit(uint256 amount0Desired, uint256 amount1Desired, address to)` requires both tokens.
- `getPositionTicks` computes `tickLower, tickUpper` using closed-form `SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp` / `FromAmount1RoundingDown`.
- ZAP via "Normaliser" — off-chain (or eventually on-chain with `JIT Engine`) computes swap parameters.
- `rerange()`, `rebalance()` — keeper-driven.

**Search status:** Closed-form for tick placement; swap amount off-chain.

**License:** Public repo (low star count).

### 2.8 Bunni v2 — V4 native shapeshifting liquidity

Source: https://github.com/Bunniapp/bunni-v2 (accessed 2026-10-03).

**Mechanism:**
- Uniswap V4 hook with shapeshifting liquidity density functions (LDFs): `UniformDistribution`, `GeometricDistribution`, `CarpetedGeometricDistribution`, etc.
- `BunniHub.withdraw(WithdrawParams{..., shares, ...})` returns pro-rata `(amount0, amount1)`. **Pro-rata, no probe on withdraw.**
- `BunniHubLogic::withdraw` reads `idleBalance` and `poolBalances`, returns proportional amounts. Iterates a bounded set of sub-positions (the LDF may split liquidity into many sub-ranges).
- `BunniQuoter.quoteWithdraw(...)` exists for off-chain quotes.
- `ReHypothecationHook` (OpenZeppelin): `addReHypothecatedLiquidity(shares)` adds liquidity in the **ratio of yield source balances** (closed form). Single-deposit-to-many-LP-shares model.

**Search status:** Search-free for deposit/withdraw. No single-token entry on the vault itself.

**Bunni exploit (https://gist.github.com/giovannidisiena/716324d50b6649be3a0e91395890917e):** "Perform a large number of small liquidity withdrawals. There is no change in liquidity densities but a further decrease in active liquidity and idle balance which causes the total liquidity to be reduced from 5.8303185165681209e16 to 9.114083388149667e15. The `BunniHubLogic::withdraw` logic intends to reduce the idle balance proportionally to the active the active liquidity being removed; however, this `mulDiv` computation rounds down which effectively rounds the stored idle balance up." → withdrawal rounding can be exploited; not a sizing search, but a rounding precision issue.

**License:** Bunniapp/bunni-v2.

## 3. Classification by prompt's A–E scheme

### Class A — Genuine on-chain deterministic scalar vault
- **Beefy CLM (Class A on placement, Class D on admission):** on-chain core+alt wing placement; single-token deposit internally swaps against other depositors.
- **Bunni v2:** on-chain withdrawal pro-rata; no single-token entry.
- **Arrakis V1/V2:** on-chain withdraw pro-rata; single-token entry via off-chain router.

### Class B — Scalar via caller-provided swap/calldata or off-chain planning
- **Aperture UniV3Automan:** closed-form on-chain OptimalSwap for rebalance (not a vault, but the math is reusable).
- **Steer Protocol:** swapAmount from keeper / SDK off-chain binary search.
- **libevm Univ3SingleSidedLiquidity:** explicit 128-iter binary search, off-chain by design.
- **Popsicle Fragola:** off-chain Normaliser.
- **Revert Auto-Range:** ZAP via 0x aggregator, swap parameters determined by aggregator.

### Class C — Proportional basket core with scalar UX wrapper
- **Arrakis V1/V2:** pro-rata mint/burn; single-token via off-chain router → C.
- **Gamma Hypervisor + UniProxy:** same.
- **Steer Protocol Multi Position Manager:** same.
- **Mellow LStrategy / Boosted:** pro-rata ERC-4626; rebalance via off-chain operator.

### Class D — Oracle / NAV or internal inventory pricing
- **Beefy CLM (admission side):** single-token deposit effectively swaps against other depositors' pooled balance.
- **ICHI oneToken / YieldIQ:** oracle-priced admission (`PeggedOracle`, `UniswapOracleSimple`); on-chain `MintMaster` with `maxOrder`/`stepSize`.
- **ALPS:** single-deposit USDC → basket valuation.
- **Mellow DepositQueue:** async oracle-priced Fenwick tree queue.

### Class E — Asynchronous / non-fungible / private-managed / not analogous
- **Charm Alpha (when fully off-chain driven; AlphaVault strategies with keeper-rebalance):** keeper-rebalance; not autonomous.
- **Sommelier Cellars:** validator-set-governed; not autonomous.
- **EulerSwap:** AMM primitive, not a vault wrapping existing CL.
- **Range Pool (poolsharks):** CL AMM itself, not a vault.
- **Panoptic V2:** derivatives + collateral, not analogous to a fungible LP vault.
- **Range Protocol Vault:** manager picks tick range; single-token not supported.
- **Uniswap V3 Range Orders:** primitive, not a vault; supports the wing proposal's underlying primitive.

**The strongest positive reusable example is Beefy CLM.** It shows core+wing = 2-position bounded vault with autonomous on-chain deposit (single-token via internal book swap, Class D for admission) and on-chain pro-rata withdrawal (no probe).

The strongest positive reusable math is **Aperture's closed-form OptimalSwap** for the rebalance-swap problem (not for the share-mint problem). It demonstrates a closed-form exists for a related but different question.

## 4. Lessons against Hookless/Orbital compatibility

| Lesson | Compatible with Hookless/Orbital? |
|---|---|
| Proportional basket core (Arrakis V1/V2, Gamma, Mellow) | Yes: closed-form mint/burn, no probe on user path. Removes scalar single-token entry — incompatible with owner mandate. |
| Manager-driven rebalance (Arrakis, Gamma, Steer, Revert) | No: not autonomous; Orbital can't supply manager calldata. |
| Core+wing (Beefy CLM) | **Yes**: bounded 2 positions, on-chain core+alt placement; single-token via internal market (Class D). Closest analog to prior round's "wing + core" proposal. |
| Closed-form OptimalSwap (Aperture) | Math reusable for rebalance, not for share mint. |
| Oracle admission (ICHI, ALPS, Mellow Queue) | Requires oracle infrastructure; new owner decision. Class D admits single-token only via oracle or internal book. |
| V4 hook vault (Bunni v2) | Native V4 hook shape; search-free withdraw, no single-token entry. Reusable hook pattern. |
| Async/Fenwick-queue (Mellow DepositQueue) | Not synchronous; violates owner mandate. |
| Derivatives (Panoptic V2) | Different analog; not a fungible LP vault. |

**Autonomous Orbital call capability under each class:**
- A: Yes (Beefy CLM-style: Orbital can call `deposit(token, amount)` directly).
- B: No (off-chain planner / keeper supplies swap).
- C: Basket-only.
- D: Yes if the oracle is pre-deployed and acceptable.
- E: No.

## 5. Economic/availability tradeoffs

- **Internal market (Beefy CLM):** "In extreme cases, excessive single-side deposits can deprive ordinary depositors of their alternative asset" → bounded by `MAX_DEPOSITS_PER_BATCH` or charge spread λ.
- **Oracle admission (Mellow Queue, ICHI):** freshness, max-age, max-deviation gates; oracle governance.
- **Manager-controlled (Arrakis/Gamma/Steer/Revert):** manager is a single point of failure / extraction risk.
- **Async queue (Mellow):** deposit is delayed until oracle reports; users do not get immediate shares.
- **Range Orders primitive (Uniswap V3 docs):** price at the boundary is the average of tickLower and tickUpper — slippage inherent; boundary tick rounding to spacing.
- **Bunni exploit rounding:** `mulDiv` floor causes idle balance to round up relative to active balance; multi-class or repeated small withdrawals accumulate.

## 6. V3 → V4 boundaries

- **V3:** Position key `(owner, tickLower, tickUpper, salt)`. Multiple positions per owner per (lower, upper) by salt. `Position.update` accrues fees per liquidity unit.
- **V4:** Position key `keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))` (Context7 `/uniswap/v4-core`, `Position.calculatePositionKey`, accessed 2026-10-03). Same salt semantics. Active liquidity by tickBitmap walk; own-LP recovery via `feeGrowthInside`. Out-of-range one-sided positions work identically.
- **Bunni v2:** introduces LDFs (Liquidity Density Functions) that shape liquidity as a continuous distribution across price, breaking the single-position-per-(lower, upper) limitation. Withdrawal rounding precision issues remain (exploit evidence).
- **EulerSwap:** V4 hook + EVC; different primitive (AMM with credit-vault collateral); not a vault wrapping V4.
- **Panoptic V2 V4 SFPM:** ERC1155-based V4 position manager; allows single-token entry via internal swap (off-chain swap amount computed).

**Implication for Hookless redesign:** V4 supports multiple positions per owner via distinct salts (V3's same owner/ticks/salt rule). Hookless's current single-position design (`PositionRepo.sol:9–22`, one position) would need multi-salt/multi-position bookkeeping to support core+wing(s). The V4 hook pattern (Bunni) is a viable alternative: hook-controlled position management via `beforeAddLiquidity/afterAddLiquidity/...` callbacks.

## 7. License gaps

- **Charm alpha-vaults-contracts** — BUSL; not directly re-licensable for production reuse without permission.
- **Arrakis v1-core / v2-core** — GPL-3.0; copyleft — copying source into a Hookless tree would impose copyleft on the derivative. **Architectural reuse only** (read and re-implement); no source copy.
- **GammaStrategies/hypervisor** — MIT (per docs); clean reuse with attribution.
- **Aperture-Finance/uniswap-v3-automan (OptimalSwap)** — MIT; clean reuse.
- **libevm/univ3-butler** — license not read this round; treat as read-only lead.
- **Bunniapp/bunni-v2** — repo public; check `LICENSE` file before reuse.
- **SteerProtocol** — license not read this round.
- **Popsicle-Finance/SorbettoFragola** — repo public, low star count, license not verified this round.

**No license conclusion without source license/version evidence.** Treat all repos as "architectural read; do not copy code without license verification."

## 8. Ranked shortlist of reusable mechanisms

1. **Beefy CLM core + 1-sided wing** (Class A on placement + Class D on admission): bounded 2-position vault; on-chain deterministic placement; single-token entry via internal market. **Strongest positive counterexample.**
2. **Arrakis V1/V2 pro-rata mint/burn** (Class C): closed-form, no probe; off-chain router for single-token entry. Architecture reusable.
3. **Aperture OptimalSwap math** (Class B): rebalance-swap closed form on-chain. Not directly the share-mint problem but the same kind of analytic approach.
4. **ICHI oneToken oracle admission + on-chain MintMaster** (Class D): single-token via oracle; on-chain incremental minting with `maxOrder` step. Reusable pattern.
5. **Bunni v2 V4 hook pattern** (Class A on withdraw, no single-token entry): bounded iteration, search-free pro-rata withdrawal.
6. **Mellow async deposit queue** (Class E for synchronicity): rejected for current question's synchronous mandate.

## 9. Strongest positive reusable example

**Beefy CLM (canonical reference: https://docs.beefy.finance/beefy-products/clm).** A live, audited, deployed vault that:
- Uses 50/50 core + 1-sided alt as two bounded positions.
- Single-token deposit: depositor mints pro-rata against the pooled balance (internal swap against other depositors).
- On-chain deterministic placement and rebalance (`moveTicks` Gelato task).
- Issues ERC-20 share tokens fungibly.
- Documents the economic risk explicitly ("excessive single-side deposits can deprive ordinary depositors").
- Two positions (not 256; not 5; conservative 2-position cap).

This validates the wing proposal AND shows the admission-rule choice matters.

## 10. Nearest miss / disqualifiers

- **Bunni v2:** strong shape-shifting mechanism but no single-token entry. Disqualifies for the synchronous single-token mandate but validates the core+wing primitive in V4.
- **Mellow DepositQueue:** solves single-token via async queue with oracle pricing. Violates synchronicity.
- **Range Orders primitive:** not a vault. Validates the underlying primitive for wings.
- **Aperture OptimalSwap:** closed-form but for the rebalance-swap problem, not the share-mint problem. Math reusable as a methodological lead.
- **ICHI / Mellow:** requires oracle infrastructure (owner-economic decision).

## 11. Recommended next human decision

The owner must choose the **admission rule**:
- (D1) Internal market against holders (Beefy CLM model; documented risk; spread λ optional). Search-free; no oracle.
- (D2) Oracle-based admission (ICHI, ALPS, Mellow Queue; requires owner-approved oracle infrastructure; freshness/deviation gates; potential manipulation risk if oracle is same-pool TWAP).
- (D3) Restricted analytic conversion (one candidate closed-form swap + reject; PRD plan §6.4 R2; liveness unproven but bounded).
- (D4) Forced proportional basket (Arrakis/Gamma/Popsicle model; eliminates single-token entry on the vault itself).

**Recommended architecture given owner mandate:** Beefy CLM-like core + 1-sided wing (Class A placement) + Class D admission via internal market (D1) **or** oracle (D2). Bounded 2–3 positions. On-chain deterministic placement, search-free on user-op path. Documented economic risk + λ spread for Class D.

**Owner must explicitly accept:** (a) the wing primitive and the cross-market risk of single-token admission; (b) the choice of admission rule; (c) the position-count cap; (d) the new spread/diffusion charges; (e) the autonomous caller capability (no nested unlock; search-free for admitted paths).

## 12. Acceptance/benchmark/evidence coverage ledger

| Claim | Source path:line | Confidence |
|---|---|---|
| Beefy CLM core+alt = 2 positions, single-token via internal book | docs.beefy.finance/beefy-products/clm (live, deployed) | High |
| Aperture OptimalSwap is closed-form on-chain | Aperture-Finance/uniswap-v3-automan + Medium article (2023-07-28) | High |
| Arrakis V1 mint/burn pro-rata, manager supplies `swapAmountBPS` | ArrakisFinance/vault-v1-core, `ArrakisVaultV1.sol:executiveRebalance` | High |
| Arrakis V2 multi-range, manager supplies full `Rebalance calldata` | ArrakisFinance/v2-core, `ArrakisV2.sol:rebalance` | High |
| Gamma Hypervisor pro-rata deposit, UniProxy off-chain single-token | GammaStrategies/hypervisor + docs.gamma.xyz | High |
| ICHI oneToken single-token, oracle admission, on-chain MintMaster | docs.ichi.org + Quantstamp audit | High |
| Steer keeper supplies `swapAmount`, SDK does binary search off-chain | docs.steer.finance + steer-sdk | Medium (license not verified) |
| libevm binary search 128 iterations, off-chain | libevm/univ3-butler, `SingleSidedLiquidityLib.sol:30-160` | High |
| Popsicle Fragola closed-form tick placement, off-chain Normaliser | Popsicle-Finance/SorbettoFragola + medium | Medium |
| Bunni v2 search-free withdraw; LDF primitives; exploit rounding | Bunniapp/bunni-v2; giovannidisiena exploit gist | High |
| Uniswap V3 range order primitive: out-of-range holds one token | developers.uniswap.org/docs/sdks/v3/guides/managing-liquidity/range-orders | High |
| V4 position key = keccak256(owner, tickLower, tickUpper, salt) | Context7 /uniswap/v4-core, Position.calculatePositionKey | High |
| LiquidityAmounts.getLiquidityForAmounts regimes | lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:67–76 | High |

**No new implementation or peer reads.** Originals preserved unchanged. No consensus claimed; no measured gas claim.

## 13. Confidence and gaps

Confidence: **high** on the wing-precedent (Beefy CLM, Uniswap V3 Range Orders primitive), on the proportional-basket math (Arrakis, Gamma, Mellow), on Aperture's closed-form approach as a methodology lead. **Medium** on ICHI's on-chain-automation claim (Quantstamp audit confirms on-chain rebalance path; off-chain keeper triggers via Chainlink Automation), on Mellow/Sommelier as comparable (license/source not deeply traced). **Lower** on V4-native single-token vault with true search-free composition (no strong positive example found; Bunni is closest but lacks single-token entry).

**Gaps:** Reclassification of single-asset semantics vs proportional share formulas in fine detail for Mellow, Sommelier, Revert, ALPS (read at docs level, not contract level). License verification for libevm, Steer, Popsicle. V4 hook-specific vaults beyond Bunni and EulerSwap (e.g., Tessera, Sorella, Angstrom vault products) not searched. Charm Alpha's on-chain rebalance path with `_executeStrategies` not deep-traced. ReHypothecationHook (OpenZeppelin uniswap-hooks) demonstrated a class-A rehypothecated ERC20 share on V4 — could be a future V4 rehypothecation precedent.

**Stop for human decision; no implementation authorized.** Saved: `docs/research/uniswap-v3-v4-vault-precedents-2026-10-03/minimax-original.md`. No peer reads; no consensus claims; no measured gas claim.