# Astra — Upper/Lower Wings independent original findings

**Date/access:** 2026-10-05. **Purpose:** requirements evidence for a separate product PRD, not an implementation plan. No shell, git, tests, implementation or peer-artifact reading. Existing FullSpread must remain unchanged. Confidence: high on inspected source/accounting boundaries; proposed economics and geometry require owner selection, not a safety claim.

Notation: `H/` = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`; `H/Common`, `H/PositionRepo`, etc. denote files prefixed `UniswapV4FullSpreadHooklessStandardExchangeVault`. `Z` = `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`. Existing family PRDs are precedent, not automatic authorization for this new family.

## 1. Product identity and evidence boundary

**Owner-fixed:** prefix `UniswapV4UpperLowerWingsStandardExchangeVault`; center plus upper/lower wings; local sleeve for nested-manager conditions; DETFs may compose eligible SEs or bare tokens. Recommend distinct sibling root `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`, corresponding test root, product ID, instance identity, salts and storage namespace. Use Crane Facet/Target/Repo, interface-owned PkgInit/PkgArgs and manager/vault-registry deployment. This is an SE vault owning V4 positions, not automatically a mined-address V4 hook.

**Observed:** H/PositionRepo:9–22 stores one center; H/Common:659–666 explicitly creates no wings; :832–835 uses minimum/maximum usable ticks. H/RouteTypes:48–68 models one position. This is not a three-position implementation awaiting a name change.

The supplied commit `35f47b5195d16fdf90fd7c032a10f8d3b916fd90` is an unverified historical locator. No git access performed. Accept the user's correction that `92cdf89a^` is center-only; neither that restoration nor ~1.28M whole-test gas proves wings behavior. A PRD must label historical restoration separately from newly selected strategy.

## 2. Exact geometry is an unresolved product decision

“Center plus wings” does not determine center width, wing overlap, anchor, capital weights, or recentering. PRD must give exact functions mapping anchor/tickSpacing/configuration into three `(lower,upper,salt)` tuples, including negative-tick rounding, minimum/maximum tick clamps, equality and collapsed-range rejection.

**Candidate requiring approval:** contiguous finite ranges `[t0,t1)`, `[t1,t2)`, `[t2,t3)` with current/reference price inside center `[t1,t2)` at placement. Upper is initially token0-only and lower token1-only. Alternative: full-range center with overlapping wings. They have different inventory, active-liquidity and fee behavior; do not choose by naming convention. Define weights in token/value budgets, not meaningless equality of liquidity units across widths.

Specify whether anchors are immutable, deterministic epoch snapshots, TWAP-based, or manager-selected; who can change them; residual placement; depleted/empty wings; crossing exact endpoints; returning to center; all-one-sided conditions; tick saturation; and whether recenter atomically closes all old positions. No unbounded collection of abandoned epochs. Every retained position, including inactive old ranges, remains counted until closed.

## 3. Custody, backing and fees

For token `i`, require separate ledgers:

`B_i = F_i + sum_j D_ij + sum_j E_ij`, for `j ∈ {lower,center,upper}` plus any explicitly retained position.

`F` excludes caller credit, payouts and refunds; `D` is finite-range principal; `E` is earned own LP fees. Durable custody snapshots used for pretransfer must contain actual local holdings only, not `B`. Source precedent: H/Common:514–550; H/RouteTypes:37–45; Z:119–159. Collecting fees is E→F once, never new caller contribution. Adding/removing liquidity rounds differently; reconcile placement losses explicitly rather than subtracting rounded inventory valuations.

Separate external protocol fees, owned LP fee recovery, allowed hook charges, SE usage fees and maintenance compensation. Decide their rates, authority, crystallization and payer. Three positions need independent fee checkpoints and exact active-liquidity attribution. ERC6909 currency claims are not automatically tokenized position ownership; direct position ownership is keyed by owner/range/salt.

## 4. First mint and scalar ownership

Recommend dual actual-token activation with permanent minimum shares and explicit disposition of pre-existing donations, following current source—not README folklore: `StandardExchangeConstantProduct.sol:16–34` uses decimal-scaled minimum and direct metadata calls. The new PRD must select share decimals, minimum formula and sink; malformed metadata and one-sided activation need explicit outcomes. Imports are a separate optional owner choice, including NFT custody, valuation and conversion costs.

For live idle scalar entry, recommend caller-funded composition, then placement, then proportional issuance against the **post-swap incumbent whole book**: `m=min_i floor(S*C_i/B_i)` for positive legs. Count caller sleeve contribution; attribute own-position repricing and swap-earned fees to incumbents. This follows Z:174–208 but needs a three-position projection, not single-center reuse. Zero/one-sided books need explicit formulas and domains.

For scalar redemption, specify proportional local and each-position entitlements, fee collection, exact removal rounding, then conversion of the opposing entitlement using post-removal pool liquidity. Remaining-holder swap fees stay with remaining holders. Define dust, full-user exit with permanent minimum, and exact-output eligibility independently. A forward quote is not an exact-output inverse; unsupported routes must fail before pulling funds.

**Manipulation:** post-swap proportional minting prevents simple misattribution but is not a proof against spot manipulation, recenter sandwiches, or blocked/idle cycling. Historical local CP settlement (`StandardExchangeConstantProduct.sol:58–110`) is a second economic mechanism: applying it to spot-valued three-range backing can transfer value. Owner must select blocked scalar pricing and oracle/gating policy. Neither adding a sleeve nor a TWAP field establishes safety. Specify oracle freshness, warm-up, deviations and unavailable-oracle behavior if an oracle is used. No claim of “economically safe default.”

## 5. Sleeve and manager state

**Fact:** protocol-locked/idle permits opening `unlock`; already-unlocked/in-session forbids another `unlock`. H/Common:300–301,583–594 follows this distinction. Core still permits operations within an existing session; using them safely would require a separately designed authenticated integration, not an automatic bypass.

Required default scope from owner intent: nested routes operate from funded local inventory only; no nested unlock, optimistic deployed cover, or collection of unavailable fees. Insufficient cover reverts atomically. A positive target is not unlimited redemption capacity.

Owner must choose target definition and bounds. Existing FullSpread uses `F=p*D`, hence `targetFree=floor((F+D)*p/(1+p))`, not `p*(F+D)` (Z:134–157). For wings, D must aggregate all owned positions. Define per-token cover, reserve replenishment, target-zero behavior, allocation priority versus wings, and public capacity views. Mode is per configured manager, not a global transaction flag.

## 6. Lifecycle, surfaces and management requirements

PRD needs a route matrix for both directions × idle/blocked × empty/live/one-sided: scalar exact-in/out swaps, deposits/redemptions; multi-token joins/exits; SY; maintenance/recenter; imports if approved. Include exact formulas, supported useful domains, caps, errors, recipients, deadlines and funding. No universal-rejection “compatibility.”

Require ERC20/permit, Basic/StandardVault discovery with explicit custody-versus-backing views, SE In/Out and multi-asset interfaces, native SY, ERC165 and executable proxy selector coverage. Consumer compatibility requires `IStandardExchangeTransitionQuote` operations and projected holder/supply state (`contracts/interfaces/IStandardExchangeTransitionQuote.sol:4–38`), external projection/rate support where consumed (:41–58), and unavailable-unlock context (`IStandardExchangeUnlockContextQuote.sol:8–16`). Snapshots must project all positions, ticks, fees and sleeve, not overwrite projected state with live reads. Same-state previews equal execution; interface adapters must not price differently.

Management needs finite work limits for swaps, tick traversal, quote probes, position updates and total nested calls; callback caller plus active payload/budget binding (H/Common:583–594,683–700 precedent); economic price/placement-loss limits; authorization and no-op/progress conditions. Existing FullSpread constants 25/50/10/1 bp (H/TransitionPlanner:19–24) and permissionless repeatability are **not selected automatically** for wings. Per-call bounds do not bound repeated extractive maintenance.

## 7. Acceptance matrix and gas evidence

Require real registry-deployed SUT/core and independent references. Test all geometry regions/boundaries and wing transitions; unequal external/own liquidity; own boundary crossings with zero aggregate liquidity-net; fees/checkpoints and rounding; mixed decimals/native face; direct and pretransferred funding; excess-credit refunds; donations before activation/live; minimum supply; reentrancy/forged callbacks; mutable fee/oracle failure; sandwich/recenter and blocked-idle round trips; zero sleeve, depletion and funded recovery; projected versus actual sequential operations; disabled-inbound with exit preservation; cross-instance isolation and proxy surfaces.

Consumer matrix: standalone SE and SY; Orbital, single/dual CP and eligible other hooks; DETF first/later bonds, mint/burn, funded staking/SY and close/claim lifecycle. Use wings plus other eligible SE families and raw tokens, not FullSpread-only fixtures.

**Weighted dimensional correction:** current Weighted accepts `2≤n≤8` total legs (`weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:373–400`). Cover buffered count `b=1..8` with raw `r=0..8-b`, subject to `2≤b+r≤8`; eight buffered plus raw is invalid. A mandatory raw DETF self-leg limits buffered legs to seven at n=8; eight-buffered belongs to standalone Weighted. Cover permutations, unequal weights, both directions, same/different managers and repeated SE dependencies; duplicate binding rejects where family law forbids it.

Measure standalone **and outer consumer transactions**, including intrinsic/calldata gas, dispatch, all rate/transition quotes and settlement. A capped subcall or whole-test result is not a chain transaction receipt. Require chain/fork/block/client provenance, cold/warm distinction, peak useful-domain work and runtime-size gates. EIP-7825 specifies 16,777,216 transaction gas where active, independently of block gas; do not reuse 31M/32M across chains without verifying activation/network policy. No wings gas results exist in this pass.

## Owner decisions needed to finalize—not an implementation plan

Select geometry/anchor/allocation/recenter policy; supported hook/manager/network set; blocked scalar pricing and manipulation controls; sleeve target/bounds; bootstrap/minimum/import policy; fee and maintenance authority/compensation; exact-output domains; execution/work/gas acceptance limits. Preserve FullSpread and its ongoing analytic work. A detailed PRD may mark these unresolved but cannot honestly claim a complete executable economic specification until selected.

**External evidence:** Context7 `/uniswap/v4-core`, then https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol (observed upstream pragma 0.8.26, unpinned main) confirms `AlreadyUnlocked`, delta settlement and position ownership; https://eips.ethereum.org/EIPS/eip-7825 confirms specified transaction cap, not deployment status of every chain. Accessed 2026-10-05. Local sources use `^0.8.0`; no compiler/git identity measured. No historical security/gas assertion adopted.
