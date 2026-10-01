# Uniswap V4 FullSpread — implementation and test plan

**Date:** 2026-09-27. **Author:** Astra moderator, consolidating the retained Astra/Grok/MiniMax M3/Kimi K3 council sessions.

**Status:** Council-selected engineering specification under the owner's seven-item delegation. Not implemented or tested. The [current PRD](UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md) is product authority. This plan selects implementation mechanics rather than returning engineering choices to the owner. Validation must correct defects, not silently alter ownership, relax protections, or substitute numerical exact-output inversion.

**Authorization boundary:** Markdown specification only. No code edits, builds, tests, deployment, deletion, live registry action or migration were executed in this round. A separately authorized implementation agent executes this plan. The [finite removal manifest](UNISWAP_V4_FULLSPREAD_REMOVAL_MANIFEST.md) is part of this plan.

## 1. Binding decisions and source notation

| Symbol | Exact meaning |
|---|---|
| Z | `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` |
| U | `contracts/vaults/standard/exchange/protocols/uniswap/` |
| F | `U/v4/`, the unsegmented baseline |
| O | `contracts/protocols/dexes/uniswap/v4/`, the older baseline |
| H / HP | `F/fullSpread/hookless/` / `UniswapV4FullSpreadHooklessStandardExchangeVault` |
| P / PP | `F/fullSpread/ponsFamilyV2Hook/` / `UniswapV4FullSpreadPonsFamilyHook` |
| CP | `U/StandardExchangeConstantProduct.sol` |
| C | `lib/crane/contracts/protocols/dexes/uniswap/v4/` |
| Baseline suffix | `F/UniswapV4FullSpreadStandardExchangeVault<suffix>.sol` |

Production manager is `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` on chain 4663; P uses `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`. Do not duplicate production address literals. H admits zero hook. P admits the fixed current-stack hook and a registered launch with the supported token orientation; its LP fee field is zero as required by the referenced launch factory. Directional protocol fees remain live. Neither a matching ABI nor callback flags admit an impostor or historical-stack hook.

**Pons evidence is closed:** official documentation and validation of graduated pools using the defined hook are accepted. Runtime-bytecode equivalence is neither claimed nor an extra pass/fail gate. Do not add a codehash pin, a different hook, a new owner choice, or a fresh RPC requirement to reopen it. Actual fee accounting, identity validation and callback/funding protection remain required.

H and P are separately compiled economic implementations. P may reuse the pure math/types enumerated in §7 and established generic facets; it must not inherit H's fee, quote, callback or execution orchestration. An ordinary externally hooked SE vault is not a hook diamond and does not switch to hook-factory deployment.

## 2. Accounting quantities and source-backed equations

All asset quantities are raw currency units. Let `S` be pre-operation outstanding share supply, `l` the vault's owned position liquidity, and `q,a,b` the current/lower/upper Q96 sqrt prices. Native currency has one accounting face (WETH at the public ERC20 boundary), not separate ETH and WETH assets.

- `F_i`: actually spendable local holder inventory after excluding current caller credit and pending payments/refunds.
- `D_i`: exact owned position principal using finite-range math and source rounding.
- `E_i`: earned uncollected **own LP** fees, not protocol or Pons fees.
- `B_i = F_i + D_i + E_i`: complete incumbent backing for share pricing.
- `C_i`: net caller contribution, including its eventual sleeve and deployed portions.
- `T_i = D_i + F_i`: placeable holder inventory; after fee collection, the collected fees join F once.
- `R_i`: durable local snapshot used for pretransfer credit; never an economic total.

Every working transition carries these as separate fields, plus pending user payouts, reserved refunds, pool state, fee checkpoints and supply. A balance increase is not automatically caller principal.

### 2.1 F0 — Initial and dual funding

Preserve CP:16–34 and Common:689–715:

```text
mean = floor((decimals0 + decimals1) / 2)
minimum = mean < 3 ? 1 : 10^(mean - 3)
raw = floor(sqrt(C0*C1))
callerShares = raw - minimum
residualSinkShares = max(ceil(priorB0*callerShares/C0),
                         ceil(priorB1*callerShares/C1))
```

Require both actual caller inputs positive and `raw > minimum`; mint minimum plus residual sink shares to the existing dead sink. Metadata errors retain the current source behavior; do not invent a decimals fallback. No single-token bootstrap. Imported activation credits only actual assets delivered from the caller's NFT, not pre-existing sleeve inventory; preserve full-range conversion and NFT custody behavior.

For a live positive two-leg book:

`m = min(floor(S*C0/B0), floor(S*C1/B1))`.

Multi join requires exactly two positive amounts in PoolKey currency order. Identified excess is retained and fully booked, as in the baseline dual-input route. It is not a disguised single-input zap and is not subject to the single-input composition loss test. One-backed-leg cases preserve CP's linear rules; an empty book with nonzero supply cannot manufacture a ratio.

### 2.2 F1 — Blocked single-input issuance and exact-share inverse

Adopt the existing internally settled model, CP:58–95, **only while external PoolManager interaction is blocked**:

```text
K = ceil(sqrt(Bin * Bother))
A = floor(sqrt((Bin + credit) * Bother))
minted = A > K ? floor(S * (A-K) / K) : 0

Aneeded = K + ceil(requestedShares*K/S)
requiredInput = ceil(Aneeded*Aneeded/Bother) - Bin
```

Use the existing helper's exact positivity guards and final minimum-one handling. With zero opposite backing and positive same-side backing, forward is `floor(credit*S/Bin)` and inverse is `ceil(requestedShares*Bin/S)`. Reject single-token first mint and depositing into an empty same-side reserve. Mint exactly requested shares on exact-output; integer surplus remains in backing. Require reference checks `forward(required)>=requested` and `forward(required-1)<requested` in its domain.

Prepaid credit, including reserved refundable credit, is excluded from incumbent reserves. OutBase:53–61 already does this correctly. Do not remove that subtraction. F1 is **not** an inverse of idle swap/composition/min-ratio minting.

### 2.3 F2 — Blocked redemption

Adopt CP:98–110 for exact-input shares:

```text
u = floor(Bout*shares/S)
v = floor(Bother*shares/S)
output = u + (v == 0 ? 0 : floor((Bout-u)*v/Bother))
```

Pay only with sufficient actual local output-token cover. Retain the existing prohibition on a full-supply burn when positive opposite backing remains. Do not discard the opposing entitlement or pretend E is spendable.

For **zero opposite backing**, the exact-output inverse is `ceil(output*S/Bout)`, with output no greater than backing, sufficient cover and supply bounds. For **positive two-leg backing**, `_sharesForSingleExit` at CP:113–128 is bisection: do not use it for exact-output. That matrix cell is `InvalidRoute`.

Do not adopt the real-valued radical plus two checks: with `Bout=Bother=100`, `S=1000`, requested output `1`, the radical rounds to shares `6`, but both `forward(6)` and `forward(7)` are `0`; `forward(10)=1`. This is a hand-checkable source counterexample, not a newly executed test.

### 2.4 F3 — Dual exact-output exit

Common:1169–1181:

`burn0=ceil(output0*S/B0)`, `burn1=ceil(output1*S/B1)`.

Require positive outputs, positive reserves/supply and equal burns. Enforce maximum shares and actual delivered/owned shares, burn exactly that amount, and pay both requested outputs exactly. Idle execution removes `floor(l*burn/S)` as required by the existing exit, collects its fees once and uses available local cover for integer differences. Blocked execution requires both local covers without unlock. No clamp-to-supply or short payment.

### 2.5 F4 — External pool swap and Pons charge

Exact-input uses source core forward evaluation with a finite step budget. Read live directional protocol fee and LP fee; reproduce `ProtocolFeeLibrary.calculateSwapFee` and core integer splitting, not independent fee subtraction from the user's input twice. Own LP recovery uses fee-growth checkpoints and actual owned liquidity; it is not a flat share of all fees.

P charges the unspecified leg using the registered launch's snapshot:

`h(n)=floor(n*hookFeeBps/10000)+floor(n*creatorTaxBps/10000)`.

Exact-input net output is core output minus `h(coreOutput)`. Exact-output input debt is core input plus `h(coreInput)`. Preserve the two separate floors. Source: `ponsFamily/v2/hooks/PonsV2MemeHook.sol:480–524`. Global fee setters are not substituted for per-pool terms. P's own LP fee is zero under its factory model, but protocol fee and Pons charges still apply.

**Selected exact-output domain:** one core step, positive active liquidity, total core fee below 1e6, and terminal price strictly inside the first core step target (including bitmap-word boundaries, not merely initialized ticks). Use the existing `SwapMath.computeSwapStep` exact-output branch and `SqrtPriceMath.getNextSqrtPriceFromOutput`, with rounded-up input debt and fee `ceil(netInput*f/(1e6-f))`. Do not size an exact-output route by tick traversal or numerical inversion. More general exact-input traversal stays supported subject to the work budget.

For context, the continuous direction equations are `t=s-output/L` and net input `L*(1/t-1/s)` for token0-in; for token1-in, `t=L*s/(L-output*s)` and input `L*(t-s)`. Implementation uses the Q96 source helpers, not these real-number expressions as replacements for integer rounding. Reject representational overflow, boundary crossing and unsupported exact-output domains before funding.

### 2.6 F5 — Idle single-input composition

For credited input `c`, simulate a gross caller-funded exact-input swap `x`, forming the caller basket `(c-x, netOutput(x))`. Independently project/re-read incumbent D and E at the resulting price. Pool repricing and the vault's own LP recovery belong to B, not C. Allocate liquidity, reconcile the caller's marginal placement cost, then mint F0's proportional shares.

For positive composition legs require, using exact wide products:

`10000*m*B_i >= 9999*S*C_i`, for each `i`.

This is the flooring-inclusive 1 bp depositor bound. No absolute-dust waiver and no idle fallback to F1 when alignment fails. For a genuinely one-sided position/book domain, use the existing linear ownership rule only if no opposite asset is silently donated and the same relative protection is satisfied; otherwise reject. Bootstrap remains F0 dual-only.

No applicable existing inverse of the complete idle F5 transition was selected. Idle token→exact-shares is `InvalidRoute`, not a search or a newly derived candidate.

### 2.7 F6 — Idle exact-input share redemption

Collect prior earned fees, establish pro-rata local entitlement, remove `floor(l*shares/S)`, and convert the opposing local/removal entitlement with F4. Pay the measured selected-currency result; preserve the baseline retained-residual behavior and fully book any unspent opposite entitlement. Newly earned fees on the remaining holder position belong to remaining holders. Quote required removal against post-removal active liquidity, not the original pool liquidity.

General exact-output inversion of F6 is not adopted: current OutBase:64–118 uses search/inventory inversion. Retain only the source-linear, no-conversion branch (zero opposing backing and no conversion-dependent position leg), with funding checks and §3's combined certificate when idle. A positive opposite inventory is not rounded away to create eligibility.

### 2.8 Source inventory disposition

| Existing primitive | Disposition |
|---|---|
| CP `_initialShares`, `_sharesForDeposit` dual/blocked branches | Adopt in F0/F1 domains only |
| CP `_amountInForShares` | Adopt blocked exact-share issuance only |
| CP `_singleExit` | Adopt blocked exact-input redemption |
| CP `_sharesForSingleExit` | Search; exclude from exact-output execution/preview |
| FullSpread `_dualExitShareBurns` | Adopt F3 |
| Core SwapMath/SqrtPriceMath | Adopt F4's explicit one-step exact-output domain; forward evaluator for exact-input |
| `ConstProdUtils` deposit/sale/purchase/swap-deposit helpers | Valid for their documented CP domains; do not substitute V2 pool reserves for finite-range external V4 state |
| `ConstProdUtils` target-LP zap-in and target-output zap-out | Search paths at approximately 619–652 and 801–832; not evidence of a complete exact-output closed form |
| V3/V4 ZapQuoter search | May inform permitted forward/exact-input work, never an exact-output inverse |
| `UniswapV4FullSpreadClosedFormCandidate.sol` / council DER proposals | Unadopted; no repair/adoption work package |

These are selected domains, not a proof that no wider equation exists.

## 3. Complete closed placement transition (CC)

CC is the combined algebraic subset for eligible idle exact-output routes. It is not a public solver call and not a claim that `LiquidityAmounts` alone solves an arbitrary swap-plus-rebalance problem.

1. Freeze caller credit/exclusions before any collection. Snapshot manager state, liquidity, own position, fees, supply, live sleeve p and caller limits.
2. Project prior `E_i=floor((feeGrowthInside_i-last_i)*l/2^128)` collection once, with the same core checkpoint/modular-growth semantics. Do not issue an invalid zero-liquidity poke.
3. Evaluate the complete adopted user leg: F4 one-step external exact-output, F3 dual payout, or the F6 linear branch. Include required liquidity removal, caller principal, exact output and refunds. Exclude reserved user liabilities from holder placement budgets.
4. For any user swap, project exact new own LP growth after protocol deduction; use `floor(lpFeeAmount*2^128/activeLiquidity)` and actual fee checkpoints. Do not book protocol or Pons fees as E. Collect projected E where required for placement.
5. On the residual holder book, calculate `target_i=floor(T_i*p/(1e18+p))`, `budget_i=T_i-target_i`. Calculate candidate final liquidity with `LiquidityAmounts.getLiquidityForAmounts(q,a,b,budget0,budget1)`.
6. For addition, evaluate the target and `max(targetLiquidity-1,currentLiquidity)` as a fixed rounding stencil; for removal evaluate the target directly. Include unchanged liquidity only if both terminal bands already pass. No adaptive increment/decrement loop.
7. Evaluate actual signed-liquidity settlement deltas: addition debts round up, removal proceeds round down. Do not approximate settlement by subtracting two rounded position valuations. Recompute final D/F/E, targets, liabilities and supply.
8. Accept only a representable candidate with every intermediate debt funded, exact requested output/max input satisfied, correct share equations, applicable execution protections, and final `rho<=1bp` and `sigma=0` as defined in §6. Choose the highest-liquidity passing candidate. All final balances/deltas reconcile exactly.
9. Execute that fixed action list and verify the measured result. No numerical repair tail, re-quote rescue or optimistic acceptance of partial output. A mismatch reverts atomically.

A missing certificate is a defined domain failure, not mathematical proof of nonexistence. Require successful nonzero/no-trade and nontrivial placement test cases for both families; universal rejection cannot satisfy acceptance.

## 4. Determinate selector/state/family matrix

Each scalar row expands to token0/token1 directions and independently to H and P. P applies F4's hook charge only to external swaps; blocked internal settlement does not call the hook. Both families share mathematical requirements, not implementation dispatch.

`BR` below means the bounded exact-in/public holder repair specified in §6, whose truthful no-op is permitted. Caller-required composition/removal is never optional maintenance.

| ID / selector direction | Idle | PoolManager already in-session | Interleaving disposition |
|---|---|---|---|
| R1 `exchangeIn(token_i, ..., token_j, ...)` | F4 forward swap, then BR | Reject; no invented local direct-swap venue | Exact-in forward work permitted; no exact-output inverse used |
| R2 `exchangeOut(token_i, ..., token_j, ...)` | F4 one-core-step exact-output + CC; otherwise `InvalidRoute` | `InvalidRoute` | Execute certified placement; never append numerical repair |
| R3 `exchangeIn(token_i, ..., shares, ...)` | F5 composition → allocation → mint | F1 forward issuance | Required caller composition/allocation idle; omit external maintenance blocked |
| R4 `exchangeOut(token_i, ..., shares, ...)` | `InvalidRoute` | F1 inverse | No F1 substitution for idle composition |
| R5 `exchangeIn(shares, ..., token_i, ...)` | F6, then BR on remaining holders' book | F2 with local cover | Required removal/conversion differs from optional holder repair |
| R6 `exchangeOut(shares, ..., token_i, ...)` | Source-linear no-conversion branch + CC only; otherwise `InvalidRoute` | Linear inverse only when opposite backing is zero; general two-leg inverse `InvalidRoute` | No radical/check-loop/bisection fallback |
| R7 `exchangeInManyToOne([token0,token1], ..., shares, ...)` | F0 activation/dual join, placement and applicable BR | F0 local dual accounting | Do not apply single-zap loss test to intentional Multi excess |
| R8 `exchangeOutOneToMany(shares, ..., [token0,token1], ...)` | F3 + CC when available; otherwise F3 required removal/payout without holder repair under the explicit vector-route exception below | F3 with both local covers | No exact-in vector-output selector is invented |
| R9 SY `deposit` / `redeem` | Exactly R3 / R5 | Exactly corresponding blocked row | Same shares, fees, funding and maintenance; no parallel formula |
| R10 `importPosition` / activation | Existing full-range conversion + F0 actual dual funding | Reject unlock-dependent import | No unilateral bootstrap or exact-output shortcut |
| R11 `rebalanceLiquidReserve` | BR; placement preferred, at most one holder swap | Preserve interaction-blocked rejection | No share mint/burn; unrestricted successive calls |

### 4.1 Route-preservation exception: selected interpretation

- Preserve funded blocked share routes without external interleaving under Z's explicit no-nested-unlock/state law. This does not create a missing operation inverse.
- For idle scalar directions, an exact-in mode remains with permitted bounded forward work; lack of a combined exact-output certificate does not alone justify omitting required interleaving from that exact-output branch.
- **For R8, adopt Grok's route-preserving interpretation:** evaluate both API modes of the vector direction, not its inverse-direction join. Exact-in vector output is unavailable by interface design; rejecting the sole algebraic exact-output interface solely for missing combined maintenance would leave both modes unavailable. Preserve F3 and explicitly omit only holder maintenance when CC fails. This is a documented compile-time route policy, not a user-selectable cheap path. Required removal, fees, cover, exact payouts and booking still execute. Astra's final cross-review preferred rejecting this row; the moderator selects preservation consistent with the owner's route-preservation intent. This is not unanimous council agreement.

Do not apply R8's exception to unrelated scalar routes or drop caller-required allocation. Public repair remains available afterwards.

### 4.2 Errors and discovery

Use `IStandardExchangeErrors.InvalidRoute(address tokenIn,address tokenOut)` for unsupported formula/combined domains before pull, fee collection, supply change or unlock. On a valid vector whose formula domain fails, use share input and first output token. Preserve distinct existing deadline, authentication, min/max, actual-delivery and insufficient-cover errors. Do not invent `InvalidRoute()` or a reason-string overload.

Token discovery describes supported directional assets, not every amount's funding/price domain. Numeric previews evaluate the matrix and revert on unsupported positive requests; no fabricated zero quote. Preserve documented zero-amount view behavior separately from money-path zero-amount errors. Transition previews evaluate the same operation on their supplied snapshot.

## 5. Funding, attribution and workflow order

1. Validate canonical PoolKey/manager/hook, route, entrypoint guards and mode. Quote unsupported exact-output domains before economic actions. Establish expected caller credit without changing durable snapshots.
2. For pull exact-in, measure exact delivered delta. For pretransfer exact-in, credit exactly the declared amount after the existing code-bearing-caller guard and `LocalCreditLib.available(balance,R)` check. Excess unclaimed surplus is not added to caller credit. For pull exact-output, pull quoted used only. For pretransfer exact-output, credit `min(unbooked,maxInput)` and reserve/refund only `credit-used` to the caller. Never refund booked inventory.
3. Snapshot B/D/F/E/S and liabilities with that caller credit excluded. Collect old E only after credit is fixed. During blocked operations include E in backing but not local cover.
4. Execute the selected user leg. During composition, caller input is the only swap budget. Capture its gross spent/net received amounts independently from own-position repricing and LP fee accrual; those latter changes belong to incumbents.
5. Allocate before mint. For a positive-liquidity addition, compute caller-attributable rounding cost as the exact aggregate book loss from its required placement, bounded by the corresponding caller leg; deduct it from C, not hidden incumbent principal. Any holder-funded removal rounding belongs to B. Recompute m and the 1 bp bound after attribution. Revert an unreconciled delta; do not silently assign unexplained losses as fees.
6. Mint F0/F1 shares or burn/pay the selected exit. Required payout/refund budgets cannot finance holder maintenance. BR after mint/burn belongs to then-current shareholders and mints no shares.
7. Complete refunds, payouts and native wrapping; synchronize the full held ERC20 set, including both pool-token faces and self-share custody, to actual balances. Never infer local credit from an economic total minus current position inventory. Persist zero self-share balances when appropriate.

Collection is E→F, placement F↔D subject to explicit rounding, neither creates contribution. Exact-in retains sleeve/residual assets and refunds nothing. Native ETH cannot remain an untracked second leg; wrap settlement remainder to the configured ERC20 face before final booking.

Preserve the **current** `NativeStandardYieldTarget.sol:20–77`: external routes delegate to SE with `pretransferred=false`; internal-balance redeem uses the active context and fixed proxy self-call. The moderator's current direct read does not support a new SY pretransfer-bug fix. Do not change this generic adapter based on older researcher descriptions; port its existing semantics into both family adapters and test them.

## 6. Placement, repair, fixed arithmetic and bounds

### 6.1 Sleeve

Sample the live fee-oracle p once per planned operation, consistently in preview/execution. Preserve default and stored-zero inheritance semantics; effective zero is genuinely zero. Use:

```text
target_i = floor(T_i*p/(1e18+p))
absoluteFloor_i = 10^max(decimals_i-6,0)
deadband_i = max(absoluteFloor_i, floor(target_i/20))
```

The target is a percentage of final deployed principal, not total assets or pre-placement principal. Handle representational limits under existing token/math domain errors; do not add a decimals allowlist. At p=1e18, target is half of T.

### 6.2 Exact normalized maintenance metric

For `a<q<b`, eliminate per-liquidity denominators:

```text
X = T0*(q-a)*q*b
Y = T1*(b-q)*Q96^2
rho = abs(X-Y)/max(X,Y)
sigma = max_i(max(abs(F_i-target_i)-deadband_i,0)/max(T_i,1))
```

Set rho=0 for an empty book. At/below the lower bound only token0 is deployable: rho=0 only if inactive token1 inventory is zero, otherwise rho=1; symmetric at/above upper bound. Permit placement on the active leg; never divide by a zero coefficient to declare inactive residual balanced.

Maintain separate 1 bp composition and depositor-loss tests. Trading stops when `rho<=1/10000` and `sigma=0`. Compare candidate progress lexicographically by `(max(rho-1/10000,0),sigma)` using exact rational cross-products, **after** all fees, own LP recovery and final placement. Compare with the placement-only baseline, not a temporarily worsened funding-removal state. Tie-break: no swap, lower input turnover, then smaller absolute liquidity delta. Rounded reporting values cannot decide eligibility.

Use wide arithmetic for X/Y, scaled share inequalities and cross-multiplication of two rational progress values. Use eight-limb 2048-bit unsigned product/comparison support in the pure protection helper: X/Y themselves can require up to 736 bits, and comparing two such rational values can require approximately twice that width plus the bps scale. Test carries and maximum operands independently. Reuse existing FullMath where its intermediate/result bounds suffice; a single `mulDiv` does not make an arbitrary multi-factor product safe. No unchecked truncated products. Wide values are internal arithmetic, not new public token units.

### 6.3 Bounded forward planning

- Composition: evaluate swap inputs 0, c and floor(c/2); perform at most 32 sign-bracket refinements using the actual family forward evaluator; evaluate final bracket endpoints. Each simulation has at most 64 core swap steps. Choose a passing candidate with greatest m, then smallest gross input. If no candidate passes exact loss/funding/impact checks, revert `AlignmentNotAchievable()`.
- Do not claim final endpoints are adjacent unless their actual difference is one. Thirty-two probes are a work bound, not a proof of root precision or universal liveness. Never accept a truncated core quote as a completed fill.
- Public/exact-in holder repair: first evaluate algebraic placement without a trade. If both thresholds then pass, use it and stop. Otherwise consider both directions, at most 32 refinements per direction, under actual holder budget and 25 bp bound, with at most 64 forward steps per simulation. The funding-removal step, if needed, is included before quoting at its reduced active liquidity. Select the best terminal candidate by the progress ordering; execute at most one holder swap and final placement.
- If none improves, execute safe placement/fee collection only and return a truthful deferred/no-op maintenance result. Do not partially execute a failed trial trade. Every simulation is read-only; only the selected plan executes. No cooldown, cumulative budget, same-block restriction or caller reward.
- Required composition/allocation can fail the user operation; optional BR's lack of an improving step does not falsely report success as repair. A settlement/accounting error still reverts, not catch-and-book.

Gas/liveness acceptance must exercise realistic and extreme supported amounts in both directions and both families. If selected work bounds prevent required product traffic, correct the specification with concrete evidence; do not silently relax 1 bp protection or enable numerical exact-output inversion.

### 6.4 Fixed execution protections

Declare per family, with no setters: `REBALANCE_IMPACT_BPS=25`, `COMPOSITION_IMPACT_BPS=50`, `EXECUTION_SHORTFALL_BPS=10`, `DEPOSIT_ALIGNMENT_BPS=1`, `REPAIR_COMPOSITION_BPS=1`.

For composition/repair price q0→q1 enforce exactly:

`10000*max(q0,q1)^2 <= (10000+limitBps)*min(q0,q1)^2`.

Apply to price, not sqrt-price. Do not apply 50 bp automatically to an unrelated direct user trade; preserve its established min/max constraints. For actual filled input, require actual net output at least `ceil(feeInclusiveQuote*9990/10000)`; include modeled fees once. Exact-output also requires exact requested payout and max-input enforcement. The shortfall guard never substitutes for deterministic preview/execution equality in tests.

## 7. Exact family component/reuse map

Expand every suffix in the following list as `<HP><suffix>.sol` under H and `<PP><suffix>.sol` under P. This defines two distinct files/types for each row; short HP/PP notation is document-only, never a production shortened name.

| Layer | Exact suffixes | Responsibility |
|---|---|---|
| Package/factory | `DFPkg`, `_Component_FactoryService` | Registry package deployment, constant binding, cuts and artifact identity |
| Shared within one family | `Common`, `InBase`, `OutBase`, `OutExecuteTarget` | Family-only custody/planning/execution helpers |
| Single input | `InTarget`, `InFacet`, `InExecutionDelegate`, `InQueryTarget`, `InQueryFacet` | EI money/transition surfaces |
| Multi input/ordinary query | `InMultiTarget`, `InMultiFacet`, `InMultiQueryTarget`, `InMultiQueryFacet` | MI and baseline ordinary EI previews |
| Single output | `OutTarget`, `OutFacet`, `OutExecutionDelegate`, `OutQueryTarget`, `OutQueryFacet` | EO and transition surfaces |
| Multi output/ordinary query | `OutMultiTarget`, `OutMultiFacet`, `OutMultiQueryTarget`, `OutMultiQueryFacet` | MO and baseline ordinary EO previews |
| Maintenance/import | `LiquidReserveTarget`, `LiquidReserveFacet`, `PositionImportTarget`, `PositionImportFacet` | Own family repair/position lifecycle |
| Storage/dependencies | `PositionRepo`, `PoolKeyAwareRepo`, `PoolManagerAwareRepo`, `ExecutionContextRepo` | Vault-local state and authenticated transient action context |
| Economic models | `QuoteService`, `TransitionPlanner` | Own family's read-only complete transition and plan; no other-family dispatcher |

Also create `I<HP>DFPkg.sol` / `I<PP>DFPkg.sol` with all Pkg structs on the interface, and `interfaces/I<prefix>LiquidReserve.sol` preserving the existing required selector set. Keep existing generic repository slots unchanged so shared ERC20/vault facets access the same data. Retain baseline position/key/manager field layouts and slot semantics in each separately compiled family; instance diamond addresses isolate storage. The new execution-context slot is family-qualified and independent of those persistent slots.

For each family create `test/bases/TestBase_<prefix>.sol`, `TestBase_<prefix>_Decimals.sol`, and decimal suffix bases `H6`, `H9`, `P6_R9`, `P6_R18`, `P9_R6`, `P9_R18`, `P18_R6`, `P18_R9`. Reuse real Crane protocol fixtures and the IndexedEx TestBase inheritance chain; these suffixes express token decimal combinations, not permission for cross-family economic dispatch.

### Permitted H→P source reuse

Create exactly these hook-independent files under H, and import them from P:

- `UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol`: pure book exclusions, targets, rational composition/progress coefficients and placement rounding arithmetic; no hook/manager external calls.
- `UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol`: pure wide integer product/comparison and bps checks.
- `UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol`: enums/memory data shapes only, no model-selected call targets.

Reuse established external generic components unchanged: `ERC20Facet`, `ERC2612Facet`, `ERC5267Facet`, `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet`; LocalCreditLib; NativeStandardYieldTarget/Selectors/Context; CP; Crane FullMath/SwapMath/SqrtPriceMath/LiquidityAmounts/StateLibrary and core forward quoter; registry, manager, fee oracle and factory infrastructure. Preserve the fee-oracle usage type/default cascade; renaming a type does not create a new economic fee domain.

**Do not reuse across families:** Common, QuoteService, TransitionPlanner, In/Out delegates, callbacks, position-import or liquid-reserve facets/targets. Even a seemingly generic facet inheriting family Common compiles its family quote code; deploy the separately named family copy. P must not inherit H's base vault orchestration. No unknown-hook vanilla fallback survives.

### Deployment and selector wiring

Facets/delegates use CREATE3 and exact full contract-name salts under current project law. Packages deploy via IndexedEx manager/registry and typed FactoryServices, not raw diamond-factory bypass. PkgInit/Args stay on interfaces. Production hook/manager constants are package-fixed and not instance-overridable. Hermetic bindings are supplied only through the existing test-construction path using real local manager/hook instances; do not add a public production bypass.

Preserve every baseline public SE, query, Multi, native SY, position import, reserve and oracle selector under its matching family owner facet; no byte-selector values are hand-invented. Build declaration controls from Targets/interfaces, verify package cuts and call every selector on the registry-deployed proxy. Preserve existing instance-salt derivation through the package namespace; no global one-vault-per-pool rule. Occupied component-name reuse must match expected immutables/delegates or fail rather than silently deploying stale behavior.

No new tunable public API is required. Expose fixed protection values through a separate read-only diagnostics interface `executionProtectionBps() returns (uint16,uint16,uint16,uint16,uint16)` on LiquidReserveFacet, ordered as the five constants in §6.4. Do not change the liquid-reserve policy interface ID by adding that selector to it. Keep detailed route-domain diagnostics internal to the shared plan result and tests; ordinary previews retain their established ABI.

Callback context commits manager, active workflow, planned action sequence, liabilities and budgets. Accept callbacks only from the configured manager during that active context; preserve reentrancy guards and signed-delta settlement. Standalone execution delegates must never access a proxy's custody directly. New family errors are `AlignmentNotAchievable()`, `PriceImpactExceeded()`, `ExecutionShortfall()`, `AccountingMismatch()`, `QuoteWorkLimit()`; reuse existing errors for existing guards. Events may report residuals/maintenance status, but acceptance relies on actual state, not logs alone.

## 8. Acceptance specification and tests to implement

Roots: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/` and matching `ponsFamilyV2Hook/`. Put reusable TestBases/Behaviors with contracts; use production-first registry-deployed proxies, real fee oracle and protocol fixtures. No mocked vault/manager/registry/PoolManager subject. Current compiler baseline: Solidity 0.8.35, optimizer runs 1, via-IR disabled; default hermetic and standard fork profiles. No runtime-equivalence gate.

| Suite | Required assertions | Z acceptance coverage |
|---|---|---|
| `AdmissionAndIdentity.t.sol` | Correct constants/registration; wrong manager/hook, historical/same-flags impostors; separate economic paths; generic reuse whitelist; all target-derived selectors on proxy; occupied salts/immutables and independent instance state | 14,23–25,28 |
| `FormulaDomains.t.sol` | Every R1–R11 expansion; one-step boundary and fee limits; F1 forward/minimal inverse; F2 radical counterexample; linear one-leg only; F3 equal-ceil; no bisection/external candidate on EO; supported nonzero successes, not universal rejects | 6,17–20 |
| `QuoteExecutionParity.t.sol` | Exact same-state preview amount=execution result; projected S/D/F/E/fees/pool/position/local snapshots match; identical unsupported-domain failure; stale-state execution still enforces guards | 2,10,18–20,29 |
| `EquivalentInterfaces.t.sol` | SY deposit↔EI token→share, SY redeem↔EI share→token, internal-balance SY equivalent custody/burn, ordinary↔transition quotes, equivalent Multi wrappers/proportional reference; compare full asset/share state and rounding | 15,20,29 |
| `AttributionAndBooking.t.sol` | Credit before collection; prior donations underclaim absorbed; no caller credit from own fees; E→F once; all held-token snapshots after payout/refund; true/false funding/refund laws; zero-delivery after external repricing rejected | 2,3,10,12,13 |
| `ZapAndPlacement.t.sol` | Repeated unilateral deposits, actual caller basket, placement before mint, residual ownership, exact 1bp boundary and just-outside, tiny/large values, 6/9/18 decimals, p=0/.2/1 and live inherited changes, bootstrap/import minimum/dead shares | 1–6,11,15 |
| `MaintenanceProgress.t.sol` | Placement preference, exact finite-range target, terminal post-cost lexicographic progress, useful partial steps, no churn when both bands pass, same-transaction/block repeats, no reward/throttle, bounded solver defer, funded-removal active-liquidity changes | 7–11,17,21,22 |
| `NestedAndConsumer.t.sol` | Real outer unlock and consuming hook; blocked F1/F2/F3 under local cover and rejection on shortage; no nested unlock; affected DETF/transition/SY consumers use correct family interfaces | 4,5,15,20 |
| `Adversarial.t.sol` | Cross-mode cycles with independent cost attribution; pretransfer EOA/constructor/delegated-wallet semantics; booked-inventory/refund theft; hostile callback/context/reentrancy; late guard rollback; disable inbound preserves exits; overflow/extreme ticks | 12,13,16,23 |
| `RuntimeAndWork.t.sol` | Every actual facet/delegate/package <=24,576 runtime bytes; measured solver/quote work within declared bounds; no stale/unlinked artifacts; representative feasible deposits succeed and infeasible ones fail cleanly | 17,24,27 |
| `RemovalAndConsumerClosure` evidence record | Exact manifest exclusions, preserved revision, both families ready for audit submission; post-removal build and replacement/consumer results use final source/artifact revision | 26,27 |

### Exact parity protocol

For each matrix cell prepare identical snapshots, caller credit, fee-oracle value, manager state, pool liquidity and hook terms. Preview before any other economic operation; execute on an equivalent restored state. Compare integer amounts **exactly**, independently observe token/share deltas, fees, position and durable snapshots. Comparing two calls to the same quote helper is not sufficient evidence.

Ordinary previews without funding arguments model an unprepaid caller at their snapshot. For push tests, obtain that economic preview before transfer or use the transition snapshot with explicit credit excluded; do not count the same pushed amount as both incumbent backing and fresh input. False exact-output pulls only used; true exact-output reserves/refunds only credited excess. Funding availability errors may differ from pure numerical quote domains when the caller never provided input, but formula eligibility must agree.

Equivalent **in-kind interfaces**, not superficially similar operations, must match: same underlying operation, state, payer/recipient, currency faces and funding semantics. Do not assert that two sequential zaps equal one dual join, that a zero-leg Multi call is valid, or that external and internally settled venues have the same cost. Pons exact-in taxes output and exact-out taxes input; test each against its own fee semantics, not an invented inverse-mode equality. For real inverses, test minimal sufficient input and exact requested payment with residual ownership, not unsupported numerical identity.

Pons-specific controls: sum-of-floors at amount 50 and two 100-bp terms is 0, not 1; registered rates unaffected by later global defaults; creator/buyback recipient changes do not invent different swapper charges; fee sweeps between operations are explicit new state, not parity failures at identical state. Both directions, native/WETH and supported decimal combinations are mandatory.

### Independent arithmetic/reference requirements

Test-side exhaustive search over small integer domains is permitted to validate selected equations; production exact-output search is not. References must not call the production helper under test for expected results. Use actual core swap/liquidity settlement plus independently computed share/fee attribution; include big-product/carry, one-wei threshold, fee-growth rounding and terminal placement-debt cases. No unexplained relative or ±1-unit allowance hides deterministic disagreement. Fixed 10 bp shortfall is an execution guard, not the parity-test tolerance.

## 9. Execution phases and completion gates

1. **Freeze specification and baseline evidence.** Record source revision and artifact identities; use this matrix, exact component map and linked finite manifest. Treat six old code-linked PRDs as deprecated, not unresolved law. Do not delete anything yet.
2. **Implement H first.** Add pure helpers, separate accounting state, F0–F6 selected domains, CC, bounded solver, ordinary/transition/SY parity, callbacks, factory/registry and complete proxy surfaces. Test each equation against independent controls. Keep unrelated V3/CP users stable.
3. **Implement P separately.** Reuse only the enumerated pure/generic components. Implement fixed singleton registration/admission, separate per-pool fee decoding and family-specific planning/settlement; no hookless fallback. Apply the same behavioral suites to real Pons fixtures.
4. **Close consumers and acceptance.** Rehome the manifest's known old FactoryService/TestBase dependencies, update artifact lookups and preserved usage interface IDs, port existing regressions, and run all applicable acceptance checks. For changed production files, refresh artifacts before tests under current CLAUDE workflow; no via-IR, profile/config workaround or stale bytecode. No deployment/broadcast is included.
5. **Record audit-submission readiness.** Both families implemented/tested, all applicable acceptance evidence recorded, manifest/import closure checked, historical revision captured. This is the later human readiness checkpoint, not a new choice of formulas and not audit completion.
6. **Execute finite legacy removal only after the gate.** Retire 80 listed Solidity files and six historical documents under their recorded dispositions. Preserve both replacement subtrees and all exclusions. Refresh artifacts and rerun replacement/consumer tests on the final post-removal revision. Audit handoff identifies that revision/results, not just pre-removal green tests.

If a test refutes a selected equation, correct the implementation or explicitly amend the engineering specification with the counterexample. Do not silently adopt a speculative formula, blanket-disable a required family, turn a failure into an unchecked fallback, or treat passing tests as proof of security/economic soundness.

## 10. Council adjudication, evidence and limits

Astra/Grok equation analysis receives the requested weight, checked against current source. Both reject the general integer radical inverse after cross-review, preserve the source blocked mint inverse, and agree on separate family orchestration. Kimi's new DER inverses and MiniMax's mislabeled swap/share formulas are not adopted. The final bound is Astra's 32 refinements/64 steps with explicit failure, not Grok's eight-probe proposal. The vector exception follows Grok's preservation interpretation, with Astra's dissent recorded in §4.1. No unanimous endorsement of every selected detail is claimed.

Direct moderator source checks include CP:16–128; Common:689–715,1169–1239; OutBase:45–118; NativeStandardYieldTarget:20–77; PonsV2MemeHook:480–524; `IStandardExchangeErrors.sol:25`; and directory reads of both legacy roots and their interfaces/TestBases. Researcher source citations further cover core SwapMath:52–105, SqrtPriceMath signed deltas:264–289, LiquidityAmounts:48–77, quoter:143–225 and launch-factory zero-LP-fee validation:1485–1498. Canonical Crane architecture/deployment/testing and IndexedEx testing guidance were read directly; current CLAUDE takes precedence over stale skill examples.

Official Pons documentation: https://docs.ponsfamily.com/v2 and https://docs.ponsfamily.com/llms.txt, previously accessed 2026-09-27. Accepted by owner; this round did not freshly verify chain runtime or run tests. Astra used Context7 for upstream core documentation before external library claims; locally read source governs this implementation baseline. Compiler/runtime settings are repository baseline, not independent deployment attestation.

Eight calls completed the round: four original continuations and four same-session combined cross-reviews. Originals and cross-reviews are retained unchanged under `docs/research/uniswap-v4-plan-specification-2026-09-27/`. Sessions: Astra `ses_f1c5107bfffefDJanl5lU29WfQ`; Grok `ses_f1c4d2922ffewPe5TNJvLvwfiy`; MiniMax M3 `ses_f1c42bd1cffeeUULWzxjga1tEf`; Kimi K3 `ses_f1c40272fffegWv5fAQexS8el4`.

Confidence is high in the directly read source formulas, fee-floor correction, accounting order and finite manifest; medium in end-to-end integer workflow feasibility and solver gas/liveness until the defined tests run. These are implementation-validation obligations, not unanswered owner questionnaires. Plan authoring is complete for this bounded round; implementation remains separately authorized.
