# Astra — Round 2 combined cross-review

2026-10-01. Read complete Grok (90 lines), MiniMax (177), and Kimi (88) originals together; no cross-review artifacts read. Originals remain frozen. Findings below are source/math checks, not a vote.

**Notation:** N = `lib/crane/contracts/protocols/pol/net/src/`; U = `lib/crane/contracts/protocols/dexes/uniswap/v2/`; M = `lib/crane/contracts/utils/math/`; V = `contracts/protocols/dexes/uniswap/v2/`.

## 1. Capacity, tax, and treasury dust

**Kimi's exact capacity formula agrees with mine:** for positive P and U=1e9,

`bMax=floor(((C+1)U−1)/P)=ceil((C+1)U/P)−1`.

This follows from `floor(bP/U)≤C`, before the second payout floor. Grok's proposed starting value `floor(CU/P)` is conservative; decrementing cannot recover its omitted feasible inputs. MiniMax likewise understates maximal capacity. Scaled integer counterexample: U=10,P=6,C=1 gives their candidate 1, but maximum 3, since floor(18/10)=1. Overflow-safe evaluation remains required. Source: `N/InverseBond.sol:75–83`.

**Grok's tax rounding is wrong:** receipt is `g−floor(gt/D)`, not `floor(g(D−t)/D)`. For g=19,t=500,D=10000, actual receipt is 19, versus 18 using his expression (`N/NET.sol:131–145`). Both swap and deposit legs need the exact predicate and floor. MiniMax's gross-reserve equations omit those taxes despite acknowledging them verbally. Two separately taxed portions do not imply a blanket 10% tax on the entire input.

**MiniMax's USDG dust ownership proposal is invalid.** `payoutWad mod F` is less than one raw USDG unit, measured in WAD—not up to F−1 raw USDG. Only `floor(payoutWad/F)` transfers from Treasury (`InverseBond.sol:82–88`; `Treasury.sol:135–145`). No residual token arrives at the SE. The value remains in Treasury while capacity consumption includes it. It cannot fund SE revenue, user refunds, or invented mint claims.

## 2. Marginal allocation and zap counterexamples

Kimi's continuous sale KKT conditions agree with mine. **MiniMax labels average price as marginal:** for `Q(s)=997sy/(1000x+997s)`,

`Q'(s)=997*1000*x*y/(1000*x+997s)^2`,

not `997y/(1000x+997s)`. His initial-marginal-only rule misses interior splits. Clean no-fee counterexample: X=Y=100,A=100,p=0.5, nonbinding capacity. Initial pool marginal 1 exceeds p, but optimum pool input is approximately 41.421 and buyback input 58.579; total output approximately 58.579 exceeds pool-only 50. This is continuous reasoning, not an executable vector.

MiniMax's no-fee zap solution `n*x/(n+2x)` is also incorrect. Actual constant-product balancing gives `sqrt(x(x+n))−x`. With x=y=n=100, the correct swap is approximately 41.421, not 33.333. At 33.333 the pool outputs 25; retained 66.667 NET/25 USDG does not match post-swap 133.333/75 reserves.

All broadly agree the zap objective is **final LP/share delivery**, not USDG alone. Grok's capacity-first mixed construction is a candidate, not a proof of optimum. My original balanced continuous objective remains applicable under its stated assumptions. I reiterate its limitation: stationary-point neighbors do not establish the global integer optimum through tax, payout and LP floors.

**Mixed zap remains requested scope.** Kimi may identify a solver blocker, but two-mode-only B/C is incomplete coverage, not a substitute fulfilling that request. Likewise, MiniMax cannot silently remove existing exact-output routes because the new optimizer is difficult.

## 3. Order and repeated fills: seller economics

**Kimi's exact order-independence claim is false.** For received pool input a, fee multiplier γ<1 and clean reserves:

`k'/k=(X+a)/(X+γa)>1`.

Treasury POL RFV depends on sqrt(k) (`N/Treasury.sol:94–117`), so pool-first can raise the subsequent bid; integer rounding can make the change zero. **Grok reverses the beneficiary:** a higher bid is better for the NET seller, not worse. Capacity may then constrain the amount sold; neither order universally dominates.

Grok's “repeated calls dominated” and Kimi's “no benefit” are also false. Clean continuous example, with enough liquid capacity: R=10,000,S=1,000,discount=.985. Selling 2 NET once pays 19.7. Selling 1 twice pays 9.85, then approximately 9.8501479: total 19.7001479. Both fit a 100-USDG epoch cap if reserves are liquid. Native rounding/gas can alter realized benefit, but not justify a dominance assertion. Source transition: `InverseBond.sol:75–88,108–111`.

MiniMax's RFV explanation is wrong: ordinary liquid-funded buyback decreases RFV while supply shrinks proportionately faster. Capacity does not necessarily reach zero; nor does changing order inherently preserve capacity (`:128–139`).

**My one-buyback-first recommendation remains a bounded policy proposal, explicitly sacrificing possible sequence improvement—not a mathematically optimal result.** Call-count/order acceptance is unresolved.

## 4. Fee helpers, router leftovers, and reference parity

**Grok's claimed protocol-fee formula mismatch is unsupported.** `M/ConstProdUtils.sol:951–959` explicitly selects the exact Uniswap denominator `5*rootK+rootKLast` for ownerFeeShare 16666–16667, matching `_calculateProtocolFeeMint:984–995`. The generic name alone proves no mismatch. Preserve feeOn/kLast, recipient aliases, supply and timing.

**Router addLiquidity does not refund ERC20 leftovers.** It selects amounts then pulls only those amounts; unused desired balances never leave the caller (`U/stubs/UniV2Router02.sol:41–84`). This differs from an SE explicitly returning operation residuals. Standard nominal-ratio selection also does not compensate NET deposit tax.

Kimi's “classic helper fully reusable” is too strong. `M/ConstProdUtils.sol:374–413` and `U/services/UniswapV2Service.sol:339–414` do not model taxed split legs/exogenous USDG. Pair mint's balance-delta accounting does not make the whole zap economically correct.

User-residual return remains my **proposed** policy, not universal existing behavior. `contracts/vaults/basic/BasicVaultCommon.sol:108–137` refunds bounded exact-output pretransfer credit, not exact-input maximums. Preserve distinct exact-output outcomes: vault zap mints requested shares; pass-through delivers all acquired LP (`V/…OutTarget.sol:922–981`). Never refund unrelated balances or treasury dust.

## 5. Quotes, failures, and final disposition

No preview guarantees cross-block execution. MiniMax's canonical “guaranteed floor” and Kimi's best-mode “guaranteed minimum” overstate snapshot semantics. Enforce original limits or revert. MiniMax's unchanged canonical transition-state proposal is incompatible with changed execution (`V/…QuoteTarget.sol:51–100,150–181`). Accounting valuation can exclude unowned capacity while execution projections include its consumption and resulting state.

A reverted buyback subcall rolls back its effects; fallback can recompute remaining conversion/deposit within original limits. It must not blindly replace one zap slice. Unexpected essential failures may instead revert atomically under a selected policy; DETF contraction clauses do not decide this SE choice. Exact-output requires forward replay and minimal-input proof, not unproven Newton iteration or four rounding fixes.

**Recommendation retained:** capacity splits plus mixed NET-funded zaps, explicit sequence/residual/fallback policies, full reference parity, and a proven or explicitly bounded-quality integer allocator. Keep DETF NET/sNET Keep-YT unchanged. **Confidence high** in the source corrections and clean counterexamples; **unproven** production optimizer, deployed equivalence, gas and live availability. Source versions remain PRD v0.34/plan v0.10 and NetNet's 2026-08-28 dump. No shell/tests/RPC or implementation performed; only this assigned report written.
