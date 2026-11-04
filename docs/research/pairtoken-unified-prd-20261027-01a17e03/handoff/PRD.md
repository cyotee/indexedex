# Pair Token product requirements

Document identity: pairtoken-unified-prd-r1.
Reviewed draft: pairtoken-unified-prd-draft-r1; retained separately as an immutable council artifact.
Publication state: published single working PRD after the council's one advisory pass. Final wording incorporates coordinator resolutions of feedback; it is not a separately reviewed final revision.
Purpose: one complete working PRD for a separate team to plan an independent implementation of the specified PairToken-local behavior. This is not an implementation plan or implementation authorization.

This PRD supersedes the archived pairtoken-requirements-final-r2 and its proposed errata as the single working specification. The earlier artifacts remain unchanged archives, not additional normative inputs. All original requirement identifiers and PT-AC-01 through PT-AC-58 are retained. PT-CONFORM-03 is the single added requirement identifier, and PT-AC-59 through PT-AC-68 are ten added acceptance scenarios. Clarifications and those additions are integrated here. No companion requirements document, errata annex or council report is needed to interpret this PRD.

## Scope and origin

This document describes the verified PairToken identified by chain 4663, address 0x56C8c249d4c021e93635b120aC68A9a36eb01753, and source match ID 55980642. Source identity was reconfirmed by the council's evidence retrieval on October 27, 2026; source analysts examined the code. The requirements are original prose, interface/data tables and mathematical contracts, not implementation listings.

Only this complete standalone PRD is intended as the planner input. Raw source, member responses, analyst traceability and council deliberations are maintained separately and are not prerequisites for understanding it. This separation records the intended handoff; it does not certify license compliance, legal clearance or a source-unexposed workflow.

The baseline is PairToken, not the earlier IndexedEx alternative-vault report. No source quirk is silently repaired. A proposed IndexedEx adaptation must identify the requirement it changes and stay distinct from a source-equivalence claim. No bytecode identity, vault private-storage layout, original class decomposition or original helper implementation is required; the specified external behavior, integer results and integration contracts are.

## Product purpose and users

Pair Token exposes a freely transferable ERC-20 share representing collective property in one directly held, full-range PoolManager position and the instance's idle pool-currency balances. It provides paired and single-currency entry, paired and chosen-currency exit, permissionless compounding, ordinary share approvals and transfers, and current-state paired-entry and redemption previews. Issuance and redemption follow the exact basket, retention, rounding and checkpoint rules below, not an oracle, target-token liquidation rate or per-holder fee ledger.

An uninitialized instance may be initialized once by any first successful caller. Depositors fund entry and may mint to a nonzero recipient; redemption burns the caller's own shares and pays a nonzero recipient. Any party may call compound. Share transfers, approvals and views do not themselves collect fees. The two deposit and two redemption routes invoke compounding at their specified checkpoints, and anyone may request it through compound. Manager-authorized callback operations follow PT-CB-01 through PT-CB-07, without an additional armed-request requirement. These behaviors remain subject to dependencies and failures and do not guarantee yield or successful execution.

## Scope and non-goals

The objective is independent implementation of the specified PairToken-local behavior, not a new pool engine or an economic redesign. Public ABI, constants, exact integer arithmetic, casts, check order, events, errors, read/interaction contracts and dependency limits are normative. The detailed absence list in PT-ABSENT-01 and PT-ABSENT-02 controls: no getRate, target normalization, personal fee claim, oracle admission rule, fee clamp, rescue, pause, permit, range change or rebalancing is introduced by consolidation. IndexedEx, IRateProvider, Crane and registry adaptations remain separate product decisions, not inherited behavior.

The complete external dependency limits remain inside Part III. Unsupplied manager, factory, fee-manager, hook, currency and live-state behavior must be identified as dependencies rather than invented. This PRD is source-informed technical documentation; it does not certify runtime equivalence, legal clearance or a source-unexposed workflow.

## Conformance and planning use

**PT-CONFORM-01 - Behavioral authority.** The requirements below are normative for this source-equivalent baseline. Read them together with the external dependency limits in Part III. A successful-path example never overrides an earlier guard, dependency failure, arithmetic failure or transfer failure. Callback/dependency edge scenarios state conditional behavior, not proofs that adversarial values are reachable in an ordinary pool.

**PT-CONFORM-02 - Separate-agent planning output.** A later implementation plan should map every requirement ID to planned work and observable acceptance evidence, list manager/factory/fee-manager/token/hook assumptions, identify required public protocol interfaces or standard math dependencies, and distinguish source-preserving work from proposed product changes. It must not fill requirements gaps by consulting target implementation source. If a genuinely unspecified external behavior matters, record that dependency/decision rather than invent its value. This describes the requested plan's inputs and coverage, not an implementation sequence. PT-CONFORM-03 defines the mandatory, more complete form of this same mapping and evidence obligation for conformance claims; the guidance here is not a separate weaker alternative.

**PT-CONFORM-03 - Evidence for conformance claims.** The tagged PT-* requirements and acceptance scenarios, including their subordinate paragraphs and tables, form the complete normative set. Untagged purpose, scope and provenance prose is explanatory, creates no independent behavioral obligation, and does not override a tagged requirement. A plan or implementation claiming conformance shall map every normative requirement and acceptance-scenario identifier to its implementation responsibility and supporting verification evidence. Evidence shall address the specified integer results, ABI and event fields, failure and rollback behavior, and dependency-call ordering where these are observable requirements. For a planning or provenance constraint rather than an execution observation, state how that constraint is satisfied. Documented scenarios are expected observations, not evidence that execution occurred, and they do not exhaust every input.

Identify the concrete dependencies and assumptions used by the evidence. Distinguish PairToken-local conformance from whole-system equivalence, which additionally requires identified compatible manager, factory, fee-manager, hook and currency behavior. Report unresolved mismatches and unverified claims explicitly rather than describing a partial result as complete equivalence. Any deliberate behavioral deviation shall identify the requirement it supersedes and remain distinguishable from this baseline. These criteria define evidence for a later conformance claim; they do not authorize implementation, tests, builds, deployment or legal determinations in this documentation task.

# Part I - Functional requirements


## 1. System, property, and units

**PT-SCOPE-01 - Economic property.** The system shall expose one fungible ERC-20 share associated with one PoolManager position and the instance's idle pool-currency balances. Position earnings are collective property: collection can pay a protocol fraction and reinvest the remainder. Share transfers do not leave historical earnings behind in a seller-specific account.

**PT-SCOPE-02 - Position identity.** The position shall be owned directly by the instance address, without a position-manager NFT. Identity consists of one complete pool key, the full usable tick range derived from its tick spacing, and zero salt. The system shall provide no range change, additional position, target-currency setter, or rebalance entrypoint.

**PT-SCOPE-03 - Accounting model.** Issuance shall use the current two-currency basket, not a booked liquidity-unit reserve, virtual share/liquidity offsets, an oracle, or a target-token liquidation rate. A read of position liquidity is distinct from the ERC-20 supply. There shall be no per-holder fee index, fee debt, unclaimed fee escrow, or separate fee-claim token.

**PT-SCOPE-04 - Unit conventions.** Share balances and supply are raw integers with 18 display decimals. Underlying quantities are their native raw integer units. The system shall not query underlying decimals or normalize amounts before share quotation, retention, dust checks, or fee calculation. Address zero denotes native currency; there is no automatic wrapping or unwrapping. A normally ordered native pair uses native currency as currency0, but initialization itself does not enforce that ordering.

**PT-STATE-01 - Persistent concepts.** The instance shall retain name, symbol, total share supply, share balances, allowances, initialization status, initializer-derived factory, PoolManager, complete pool key, pool identifier, and computed tick bounds. Fresh storage has zero/false/empty values for these nonconstant fields. Position liquidity and pool price are read from the manager, not maintained as a separate share-pricing ledger.

**PT-STATE-02 - Operation-scoped concepts.** A native reservation shall exclude currently reserved native input/refund from idle accounting. An entered flag shall guard the five money-changing entrypoints identified below. A skip-add flag shall disable all liquidity addition during a redemption-only swap. These concepts are stored state during an operation; "operation-scoped" does not mean EVM transient-storage opcodes.

**PT-CONST-01 - Exposed constants.**

| Identifier | ABI type | Value and meaning |
| --- | --- | --- |
| `decimals` | `uint8` | `18`; share display decimals |
| `BPS` | `uint256` | `10000`; basis-point denominator |
| `DEAD_SHARES` | `uint256` | `1000`; raw shares minted to the dead address at genesis |
| `RETENTION_BPS` | `uint256` | `10`; retention parameter |
| `DUST` | `uint256` | `1000`; raw-currency threshold, not decimal-normalized |
| `DEAD` | `address` | `0x000000000000000000000000000000000000dEaD` |

**PT-CONST-02 - Mathematical constants.** Use `Q96 = 2^96`, `Q128 = 2^128`, minimum tick `-887272`, maximum tick `887272`, minimum sqrt price `4295128739`, and maximum sqrt price `1461446703485210103287273052203988822378723970342`. Swap limits are respectively minimum plus one and maximum minus one. Tick and sqrt-price calculations use raw fixed-point integers, not floating-point arithmetic.

## 2. Public interface contract

**PT-API-BASE - ABI conventions.** A pool key is the ordered tuple `(address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks)`. `PoolId` is ABI `bytes32`; `IPoolManager` is ABI `address`. All parameters and return values below are in declared order. "External" and "public" describe the declared visibility; public functions are also externally callable. Unless marked payable, calls reject native value through normal nonpayable ABI dispatch. No method has an implicit owner privilege.

### 2.1 Seventeen named functions and receiver

Each row is a stable candidate requirement ID. Cross-referenced sections define the full behavior rather than merely the signature.

| ID | Signature | Visibility / mutability | Returns | Caller and recipient rules |
| --- | --- | --- | --- | --- |
| PT-API-01 | `initialize(IPoolManager manager, PoolKey key, string name_, string symbol_)` | external, nonpayable | none | Any first successful caller becomes factory; section 4. |
| PT-API-02 | `approve(address spender, uint256 amount)` | external, nonpayable | `bool` | Changes caller's allowance to spender; zero spender allowed. |
| PT-API-03 | `transfer(address to, uint256 amount)` | external, nonpayable | `bool` | Debits caller; `to` must be nonzero. |
| PT-API-04 | `transferFrom(address from, address to, uint256 amount)` | external, nonpayable | `bool` | Uses allowance from `from` to caller, including when caller equals `from`; `to` nonzero. |
| PT-API-05 | `poolKey()` | external, view | `PoolKey` | Unrestricted read of stored tuple. |
| PT-API-06 | `token0()` | public, view | `address` | Unrestricted; unwraps stored currency0. |
| PT-API-07 | `token1()` | public, view | `address` | Unrestricted; unwraps stored currency1. |
| PT-API-08 | `positionLiquidity()` | public, view | `uint128` | Unrestricted manager-backed position read. |
| PT-API-09 | `basket()` | public, view | `(uint256 reserve0, uint256 reserve1)` | Unrestricted manager/token-backed read; section 5. |
| PT-API-10 | `previewDeposit(uint256 amount0, uint256 amount1)` | public, view | `(uint256 shares, uint256 used0, uint256 used1)` | Quote only; no transfer, native-value requirement, or recipient. |
| PT-API-11 | `previewRedeem(uint256 shares)` | external, view | `(uint256 amount0, uint256 amount1)` | Quote only; no ownership or allowance check. |
| PT-API-12 | `deposit(uint256 amount0, uint256 amount1, uint256 minShares, address to)` | external, payable, guarded | `uint256 shares` | Caller funds entry; shares to nonzero `to`; native refund to caller. |
| PT-API-13 | `zapDeposit(address tokenIn, uint256 amountIn, uint256 minShares, address to)` | external, payable, guarded | `uint256 shares` | Caller funds chosen leg; shares to nonzero `to`; no zap-specific refund. |
| PT-API-14 | `redeem(uint256 shares, uint256 min0, uint256 min1, address to)` | external, nonpayable, guarded | `(uint256 amount0, uint256 amount1)` | Burns caller's shares; pays both currencies to nonzero `to`. |
| PT-API-15 | `redeemZap(uint256 shares, address tokenOut, uint256 minOut, address to)` | external, nonpayable, guarded | `uint256 out` | Burns caller's shares; selected output to nonzero `to`. |
| PT-API-16 | `compound()` | external, nonpayable, guarded | `(uint256 fees0, uint256 fees1)` | Permissionless; no caller reward or recipient parameter. |
| PT-API-17 | `unlockCallback(bytes rawData)` | external, nonpayable | `bytes` | Configured-manager equality only; section 10. |
| PT-API-18 | `receive()` | external, payable | none | Empty calldata accepts native value from any sender; no event or accounting mutation beyond balance. |

"Guarded" means the shared entered flag rejects an already entered call with `Reentrancy`, is set before the function body, and cleared on successful return. This applies only to PT-API-12 through PT-API-16. The receiver, initializer, ERC-20 functions, callback, and views do not carry that guard. There is no fallback accepting unknown function selectors.

### 2.2 Seventeen generated getters

**PT-GET-BASE.** Each getter is externally callable, view, nonpayable, unrestricted, and returns the indicated stored/constant value without a fee sync or mutation.

| ID | Getter signature | Return |
| --- | --- | --- |
| PT-GET-01 | `name()` | `string` |
| PT-GET-02 | `symbol()` | `string` |
| PT-GET-03 | `decimals()` | `uint8`, constant 18 |
| PT-GET-04 | `totalSupply()` | `uint256`, including dead-address shares |
| PT-GET-05 | `balanceOf(address account)` | `uint256` |
| PT-GET-06 | `allowance(address owner, address spender)` | `uint256` |
| PT-GET-07 | `BPS()` | `uint256`, constant 10000 |
| PT-GET-08 | `DEAD_SHARES()` | `uint256`, constant 1000 |
| PT-GET-09 | `RETENTION_BPS()` | `uint256`, constant 10 |
| PT-GET-10 | `DUST()` | `uint256`, constant 1000 |
| PT-GET-11 | `DEAD()` | `address`, dead-address constant |
| PT-GET-12 | `factory()` | `address` |
| PT-GET-13 | `poolManager()` | `IPoolManager` / ABI address |
| PT-GET-14 | `poolId()` | `PoolId` / ABI bytes32 |
| PT-GET-15 | `tickLower()` | `int24` |
| PT-GET-16 | `tickUpper()` | `int24` |
| PT-GET-17 | `initialized()` | `bool` |

## 3. Exact arithmetic contracts

**PT-MATH-01 - Integer arithmetic and failure.** All quantities are integers. `floor` and `ceil` refer to exact integer division. Ordinary PairToken `uint256` multiplication, addition and subtraction are checked unless an explicit modular behavior is stated below. A full-precision product/division is different from a checked multiplication followed by division: the former permits an intermediate product wider than 256 bits, while requiring a nonzero denominator and a final result fitting `uint256`.

Let `MD(a,b,c) = floor(a*b/c)` evaluated with a full-precision product, and `MU(a,b,c) = ceil(a*b/c)` with the same product precision. Both reject `c=0` or an out-of-range result; these helper failures use an unadorned revert. `MU` also rejects an overflow caused by upward rounding. Checked ordinary multiplication shall be retained for the genesis product, retention product, fee-basis-point product, and both cap-basis-point products. Algebraically rearranging one of these into `MD` shall not silently remove its overflow failure.

**PT-MATH-02 - Amount deltas.** For nonnegative sqrt-price integers sorted as `a <= b` and liquidity `L`, define:

- `A0down(a,b,L) = floor(MD(L*Q96, b-a, b) / a)`.
- `A0up(a,b,L) = ceil(MU(L*Q96, b-a, b) / a)`.
- `A1down(a,b,L) = MD(L, b-a, Q96)`.
- `A1up(a,b,L) = A1down(a,b,L) + 1` exactly when the product has a nonzero remainder modulo `Q96`; otherwise it equals `A1down`.

Both amount functions sort their two supplied endpoints. The amount0 function rejects a zero lower endpoint with `InvalidPrice()`, including for zero liquidity. Amount1 uses the absolute endpoint difference and does not apply that price-zero check. `L` has width `uint128` and endpoints have width `uint160`; `L*Q96` fits in `uint256`.

**PT-MATH-03 - Amounts to liquidity.** After ordering bounds `a <= b`, define:

- `L0(a,b,x) = MD(x, MD(a,b,Q96), b-a)`.
- `L1(a,b,y) = MD(y, Q96, b-a)`.

Each individual result must fit `uint128`, otherwise `SafeCastOverflow()`. Equal bounds produce a division failure. At live price `p`, available amounts `x,y` fund:

| Price condition | Fundable liquidity `Fit(p,a,b,x,y)` |
| --- | --- |
| `p <= a` | `L0(a,b,x)` |
| `a < p < b` | `min(L0(p,b,x), L1(a,p,y))` |
| `p >= b` | `L1(a,b,y)` |

Inside the range both candidate conversions are individually checked before choosing the minimum; an overflowing candidate is not excused because the other is smaller. This function's range branching must not be imported into `basket`, whose endpoint use is separately specified.

**PT-MATH-04 - Tick price.** The tick-to-sqrt-price function `T(t)` accepts `-887272 <= t <= 887272`; otherwise it rejects with `InvalidTick(int24 t)`. It must reproduce the integer function below, not a floating-point approximation or an assumed exact-real-power rounding:

Let the set-bit indices of `abs(t)` be `b1 < ... < bk`. Starting with mathematical value `R0 = Q128`, define `Rj = floor(R(j-1) * C[bj] / Q128)`. Let `R = Rk` if `t <= 0`, and `R = floor((2^256-1)/Rk)` if `t > 0`. Then `T(t) = ceil(R/2^32)`. The following fixed coefficients define the integer function; they are numerical constants, not executable source.

| Bit index | Coefficient, hexadecimal integer |
| --- | --- |
| 0 | `fffcb933bd6fad37aa2d162d1a594001` |
| 1 | `fff97272373d413259a46990580e213a` |
| 2 | `fff2e50f5f656932ef12357cf3c7fdcc` |
| 3 | `ffe5caca7e10e4e61c3624eaa0941cd0` |
| 4 | `ffcb9843d60f6159c9db58835c926644` |
| 5 | `ff973b41fa98c081472e6896dfb254c0` |
| 6 | `ff2ea16466c96a3843ec78b326b52861` |
| 7 | `fe5dee046a99a2a811c461f1969c3053` |
| 8 | `fcbe86c7900a88aedcffc83b479aa3a4` |
| 9 | `f987a7253ac413176f2b074cf7815e54` |
| 10 | `f3392b0822b70005940c7a398e4b70f3` |
| 11 | `e7159475a2c29b7443b29c7fa6e889d9` |
| 12 | `d097f3bdfd2022b8845ad8f792aa5825` |
| 13 | `a9f746462d870fdf8a65dc1f90e061e5` |
| 14 | `70d869a156d2a1b890bb3df62baf32f7` |
| 15 | `31be135f97d08fd981231505542fcfa6` |
| 16 | `9aa508b5b7a84e1c677de54f3e99bc9` |
| 17 | `5d6af8dedb81196699c329225ee604` |
| 18 | `2216e584f5fa1ea926041bedfe98` |
| 19 | `48a170391f7dc42444e8fa2` |

Thus `T(0)=Q96`; endpoint values are the sqrt extrema in PT-CONST-02. The coefficients and intermediate floors matter to exact compatibility.

**PT-MATH-05 - Square root and casts.** Genesis uses the integer floor square root of the checked `uint256` product. A same-width signed-to-unsigned `int128` conversion preserves the low 128 bits: define `U128(d)=d` for nonnegative `d`, otherwise `d+2^128`, then widen to `uint256`. This is not a checked positivity conversion. Removal/collection return values use `U128`; swap output instead explicitly clamps a nonpositive output delta to zero.

The redemption liquidity result is narrowed to `uint128` by retaining low 128 bits, not by a checked cast. In ordinary consistent share states it is bounded by existing liquidity, but the conversion rule itself shall not be replaced by an additional guard. Negating a signed `int128` minimum while settling a negative delta overflows and reverts before unsigned conversion.

For a requested swap amount `x`, conversion to signed `int256` precedes checked negation. Its encoded signed amount is `-x` for `0 <= x < 2^255`; `x=2^255` fails the negation; and for `x > 2^255` the result is positive `2^256-x`. The contract does not add an explicit upper-bound check that would eliminate this width-dependent behavior. This is an encoding requirement, not a claim that such amounts occur in an ordinary supported pool.

## 4. Initialization and permissions

**PT-INIT-01 - One-shot initialization.** An already initialized instance shall reject `initialize` with `AlreadyInitialized` before checking its other arguments. A first initialization with manager address zero shall reject with `ZeroAddress`. On success, the caller becomes `factory`, the manager and complete key are stored, the supplied name and symbol are stored, and `initialized` becomes true. No independent factory authorization is required and no initialization event is emitted.

**PT-INIT-02 - Position derivation.** The pool identifier is the Keccak-256 hash of the standard ABI encoding of the five-field pool key. For supplied spacing `h`, the bounds are:

- lower: `truncTowardZero(-887272/h) * h`;
- upper: `truncTowardZero(887272/h) * h`.

Zero spacing causes division failure and rolls back the entire initialization. The instance shall not add local validation that spacing is positive or at most 32767, that currencies are sorted/different, that the manager has code, that a pool is initialized, or that the hook has a particular policy. Normal manager validation is a dependency boundary, not an initializer guard. Salt is always 32 zero bytes, not an initializer input.

**PT-INIT-03 - No additional privilege or readiness gate.** Initialization shall not initialize the manager's pool or fund a position. No operating method shall gain an `initialized` check not present in the specified behavior. ERC-20 methods and the receiver can operate before initialization. Manager-backed operations may fail through their downstream calls; that is not a specified `NotInitialized` error. The declared `NotFactory` error has no active predicate.

**PT-PERM-01 - Reentrancy scope.** A nested call to any guarded entrypoint during another guarded entrypoint shall reject with `Reentrancy` before its body checks. Calls to unguarded functions are not rejected merely because the entered flag is set. In particular, views are not promised a pre-operation snapshot during external callbacks, and share approvals/transfers do not gain a global operation lock.

## 5. Position reads, basket and share quotations

**PT-VIEW-01 - Manager state identity.** The position is identified by the packed hash of `(instance address, lower int24 tick, upper int24 tick, zero bytes32 salt)`, with field widths 20, 3, 3 and 32 bytes. Its liquidity is a `uint128` manager-backed value. The current price is the manager's `uint160` sqrt price; current tick is the signed `int24` manager value. Active pool liquidity used for compounding is not necessarily the instance's own position liquidity.

For compatibility with the supplied manager-read interface, let `B = keccak256(abi.encode(poolId, bytes32(uint256(6))))`. Slot0 is read at `B`, active pool liquidity at `B+3`, and the position entry at `keccak256(abi.encode(positionKey, bytes32(uint256(B)+6)))`. Position liquidity is read from the first word of that position entry. Price is the low 160 bits of slot0 and tick is the next 24 bits interpreted as signed; each of the two liquidity reads retains the low 128 bits of its respective word. These are dependency-access semantics, not an assertion that every address satisfying the manager ABI has that layout. Each displayed hash preimage consists of two 32-byte words, so standard ABI encoding and packed concatenation of those same two words give the same 64 bytes. This equivalence does not extend to shorter or dynamic operands.

**PT-VIEW-02 - Basket.** Let `p` be the current manager price and `L` the position liquidity. Read price, then position liquidity, then add currency0 idle before currency1 idle under PT-BAL-01, preserving the principal calculations and checked additions specified below:

- if `L>0`, `r0 = A0down(p,T(upper),L) + idle0` and `r1 = A1down(T(lower),p,L) + idle1`;
- if `L=0`, `r0=idle0` and `r1=idle1`, without evaluating the principal tick-price amount terms.

Addition is checked. The live `p` is passed directly to the amount functions; it is **not clamped** to the usable range. Their endpoint sorting, not an idealized range-position valuation, controls out-of-range results. Uncollected position fees are not independently included. The result is not a guaranteed full execution payout: retention, automatic compounding, separate execution rounding, and external behavior can differ.

**PT-QUOTE-01 - Complete paired quote.** Define `Quote(a0,a1,r0,r1,S) = (g,u0,u1)` with the following ordered branch precedence:

| Condition | Gross shares `g` | Selected amounts `u0,u1` |
| --- | --- | --- |
| `S=0` or both reserves zero | `floor(sqrt(a0*a1))`, with checked product | `a0,a1` |
| Otherwise `r0=0` | `MD(a1,S,r1)` | `0,a1` |
| Otherwise `r1=0` | `MD(a0,S,r0)` | `a0,0` |
| Otherwise | `min(MD(a0,S,r0), MD(a1,S,r1))` | `min(a0,MU(g,r0,S))`, `min(a1,MU(g,r1,S))` |

In the first branch only, if `S=0` and `g<=1000`, reject with `BadGenesis`. When supply is positive but both reserves are zero, this genesis-size guard does not apply. A zero result can therefore be a valid preview even though a deposit later rejects it.

**PT-VIEW-03 - Deposit preview.** `previewDeposit` shall sample the current basket, then current supply, and return `Quote`. It shall not compound, pull currencies, reserve native value, require positive position addition, subtract genesis dead shares, check `minShares`, or validate a recipient. Its genesis share return is gross.

**PT-VIEW-04 - Redemption preview.** If supply is zero or requested shares are zero, `previewRedeem` shall return `(0,0)` without reading the basket. Otherwise, with current basket `r0,r1` and supply `S`, define `payout = floor(shares*9990/10000)` using a checked multiplication, then return `(MD(r0,payout,S), MD(r1,payout,S))`. It shall not check the caller's balance, enforce `shares<=S`, burn, compound, or simulate a sale. Preview failure can still arise from reads or arithmetic.

**PT-VIEW-05 - Preview/execution distinction.** Previews are current-state quotations, not promises of exact subsequent results. Entry/exit execution compounds first. Execution redemption separately rounds the liquidity slice and each idle allocation, whereas its preview rounds each total basket fraction. Pending fees, ratio swaps, actual manager deltas, rounding, hooks, and intervening state can change results. No standalone zap preview or `getRate` is provided.

## 6. Deposits

### 6.1 Paired deposits

**PT-DEP-01 - Admission and native checkpoint.** After acquiring the entered guard, `deposit` shall reject a zero recipient with `ZeroAddress`. If stored currency0 is native, `msg.value` must equal requested `amount0`; otherwise value must be zero. A mismatch rejects with `NativeMismatch`. Reserve that value from idle accounting before automatic compounding, so the incoming native principal is not incumbent property during that compound.

**PT-DEP-02 - Quote checkpoint.** The basket and supply used for `Quote` shall be sampled after automatic compounding and before either ERC-20 pull. The quoted gross shares must be positive and at least `minShares`; otherwise reject with `MinShares`. This check occurs before transfer-in and before any genesis dead-share deduction. The preceding automatic compound may execute a pool-moving balancing swap; no compound tick-movement guard applies. The later user-zap tick guard is a separate route-specific rule.

**PT-DEP-03 - Transfer-in and fundable addition.** Pull selected currency0, then selected currency1, using the receipt semantics in section 11. Call their returned amounts `v0,v1`. Retain native reservation `msg.value-v0` when currency0 is native, otherwise zero. The selected native input is then eligible idle; only its refund remains reserved.

For the paired-entry addition, sample currency0 idle, then currency1 idle, then read the fresh manager price. The liquidity addition shall use **all these sampled idle balances**, including old leftovers and unsolicited transfers, at that price. This read order is specific to paired entry and does not replace the separate Deploy price/idle checkpoints. There is no dust threshold on this deposit addition. Its requested liquidity is `Fit(p,T(lower),T(upper),idle0,idle1)`; when positive, request that addition through an Add unlock. No independent post-add position-liquidity equality check is performed.

The computed/requested positive liquidity and a successful manager interaction are the source's indication of an addition. Do not replace them with an invented independently measured `uReceived` test. An Add callback's returned used-amount payload is not used to recompute paired shares.

**PT-DEP-04 - Genesis and normal mint.** If the snapshotted supply is zero, the computed addition must be nonzero, otherwise reject with `BadGenesis`. Mint 1000 shares to `DEAD` and mint `g-1000` to `to`; return the latter. These are actual supply-increasing mints, not virtual offsets or a supply-reducing burn.

For positive snapshotted supply, mint and return `g`; there is no extra requirement that the computed addition be positive. Genesis uses the zero-supply quote branch even if prior donations/compounding already produced basket property.

**PT-DEP-05 - Receipt mismatch and refunds.** Measured ERC-20 receipts shall replace selected amounts for the event and liquidity funding, but **shall not change the already computed or checked shares**. A token delivering less or more than requested can therefore change funding without a paired-share recomputation, if the overall operation succeeds.

Unselected requested ERC-20 excess is never pulled. Pulled amounts that do not fit the addition stay idle; they are not universally refunded. After minting, clear the remaining native reservation and refund its amount to `msg.sender`, not `to`. Zero refund skips the send. A failed nonzero refund rejects with `TransferFailed` and rolls back the deposit. Emit `Deposit` after the refund with pull-returned amounts `v0,v1` and net recipient shares. A zero selected amount returns zero without a token call. A native pull returns its selected nominal amount without balance-delta measurement. A nonzero ERC-20 pull returns the checked post-call instance balance minus its pre-call balance; the difference may be zero. A lower post-call balance fails checked subtraction. These receipt rules do not recompute the already quoted shares or bypass any later failure.

### 6.2 Single-leg zap deposits

**PT-ZAP-01 - Admission.** After the entered guard, reject zero `to`. Accept `tokenIn` equal to currency0 first, otherwise currency1; otherwise `BadToken`. If both addresses match because of an invalid stored key, the currency0 branch wins. Require exactly `msg.value=amountIn` only when currency0 is native and chosen as input; all other input choices require zero value. Reserve incoming native value while automatically compounding.

**PT-ZAP-02 - Pre-zap reference and cap.** After compounding, snapshot basket `r0,r1` and supply `S`. Reject with `BadGenesis` if any is zero. Choose `rIn` from the input side of this **vault basket**. Idle balances, including unsolicited transfers, contribute to that reference and can affect the cap. The actual post-compound basket, current rate and integer flooring determine the cap; a prior donation is not a guarantee of a strictly larger final cap. Reject zero nominal input, or nominal input above `floor(rIn*factory.maxZapBps()/10000)`, with `ZapTooLarge`. The multiplication is checked. The zero-input alternative short-circuits that particular cap getter, but earlier compounding may itself have called the factory. Equality with the cap is permitted. There is no local clamp on the returned `uint16` setting.

**PT-ZAP-03 - Deployment and tick guard.** Pull the selected input under PT-BAL-02 and let the returned amount be `v`; clear the native reservation. Request a Deploy operation with swap amount `floor(v/2)` in the input-to-other direction. It may use existing idle balances as well as newly received funds. The same Deploy callback performs its optional swap and any fitting addition, as specified in section 10.

After Deploy returns, compute the absolute difference of its signed `int24` before/after ticks, using checked signed subtraction. Reject with `ZapMovesPrice` if it exceeds the then-read `factory.maxZapTickMove()`. Equality passes. The source does not locally require that limit to be nonnegative. The returned after tick is sampled after swap settlement and before the subsequent add; it is not independently resampled after that add.

**PT-ZAP-04 - Issuance.** Let Deploy report amounts `w0,w1` attributed to the add. Mint:

`g = min(MD(w0,S,r0), MD(w1,S,r1))`.

The reserves and supply are the pre-zap snapshots. Both denominators were required nonzero. Reject `g=0` or `g<minShares` with `MinShares`, then mint/return `g` and emit `Deposit` with `w0,w1`. These amounts derive from add deltas, not directly from the nominal deposit or a segregated depositor sub-balance. They may reflect deployment of old idle funds. No genesis dead-share mint, post-deployment position comparison, or zap-specific leftover/native refund is performed.

## 7. Redemption and retained property

**PT-EXIT-01 - Shared redemption checkpoints.** Both exit routes acquire the entered guard and reject a zero recipient before compounding. The zap route additionally validates its selected token before compounding. Both automatically compound before checking whether the requested share burn is positive or affordable.

After compounding, snapshot supply `S`; reject zero requested shares `s` or zero `S` with `MinShares`. Snapshot currency0 idle, then currency1 idle under PT-BAL-01, then burn **the caller's** `s` shares, without using an allowance or accepting an owner parameter. Insufficient share balance fails checked subtraction. Read position liquidity after the burn.

**PT-EXIT-02 - Retention and exact decomposition.** With pre-burn supply `S`, requested burn `s`, sampled idle balances `i0,i1`, and position liquidity `L`:

- `payout = floor(s*9990/10000)` with checked multiplication;
- `ell = low128(MD(L,payout,S))`;
- request removal of `ell` only if it is positive;
- if removal occurred, let `c0,c1` be its returned unsigned-converted caller deltas; otherwise both are zero;
- final pair amounts are `a0 = c0 + MD(i0,payout,S)` and `a1 = c1 + MD(i1,payout,S)`, with checked additions.

The liquidity fraction and idle fractions round separately. Burned shares are `s`, not `payout`. The retention includes the basis-point haircut and all effects of sequential integer rounding. No extra liquidity is removed to compensate for rounding, minima, or later swap fill. Fees or hook effects appearing in the returned removal caller delta are not stripped out as non-principal.

**PT-EXIT-03 - Paired output.** `redeem` shall reject with `MinOut` if `a0<min0` or `a1<min1`. Transfer positive `a0` in currency0, then positive `a1` in currency1, to `to`. Skip each transfer whose amount is zero. Return `(a0,a1)` and emit `Redeem` after transfers. This path performs no post-removal sale, though its initial compound may have swapped.

**PT-EXIT-04 - Chosen-leg output.** `redeemZap` shall accept `tokenOut` equal to currency0 first, otherwise currency1; otherwise `BadToken`. There is no permanent configured target. Its swap input is the unwanted amount from PT-EXIT-02. When positive, request a Deploy operation in the unwanted-to-wanted direction while skip-add is true; clear that flag after successful return. This suppresses **all** addition during that Deploy, including dust and remaining-holder inventory. When the unwanted amount is zero, omit this swap unlock.

Let `z` be the positive returned output delta, or zero for no swap/nonpositive output delta. The output is the checked sum of the wanted amount from PT-EXIT-02 and `z`. Reject if below `minOut`, then perform the selected-currency transfer **even when this final output is zero**. Return it, but emit `Redeem` using the pre-swap pair amounts `a0,a1` and original shares `s`, not the final one-token output.

**PT-EXIT-05 - Zero, partial-fill and last-holder behavior.** Positive burns whose `payout` or `ell` rounds to zero are not rejected solely for that reason. Minima and downstream transfers still apply. The exit swap has no user-zap size cap or tick-movement guard, and no explicit verification of complete input consumption or strictly positive output. A partial fill can therefore succeed if settlement, output transfer and `minOut` succeed. Unconsumed input remains in the instance balance rather than being separately refunded by the exit.

There is no last-redeemer sweep or "burn all remaining supply" privilege. Dead-address balances are actual shares and normally remain after ordinary holders redeem. Transfers to/from that address are not specially forbidden by ERC-20 rules; it is not mathematically removed from supply. The contract makes no claim that all backing property can be recovered by the last ordinary holder.

## 8. Collective collection, protocol routing and compounding

**PT-COMP-01 - Trigger and reported collection.** Public `compound` is permissionless and guarded. The same compound behavior occurs at the defined checkpoint in both deposit and both redemption routes. It does not run on approvals, share transfers, views or unsolicited currency receipts.

Read position liquidity. If positive, collect through a zero-liquidity-change Collect unlock; otherwise collection values are zero and no collection unlock occurs. Reported `fees0,fees1` are the Collect callback's unsigned-converted **caller deltas**, not the separately reported `feesAccrued` fields. Manager/hook contributions can therefore matter. There is no per-account allocation.

**PT-COMP-02 - Runtime protocol fraction.** Only when at least one reported collection value is positive, read `factory.feeManager()`, then `factory.protocolFeeBps()`. Both reads occur even if the fee-manager result is zero. If both manager and fee rate are nonzero, attempt currency0 routing then currency1 routing, each for `floor(fees_i*feeBps/10000)`, using a checked product. No local maximum of 10000 is imposed on the `uint16` setting. A zero computed amount skips that currency's notification.

Only this collected pair determines the protocol fraction for this compound. Existing idle donations are not separately fee-taxed merely for being idle. Fees returned incidentally during a later add in the same compound are resolved but do not cause a second protocol-carve calculation in that compound.

The attempted protocol amount is not capped at the corresponding reported collection, the instance's idle balance, or a separately segregated principal budget. A returned `uint16` fee rate above 10000 can therefore request more than was collected. If payment or a fee-manager token pull succeeds, it can consume other held balance. Native reservation excludes an amount from idle accounting; it does not create an independent spending restriction on protocol notification. Successful ERC-20 notification remains no proof that approved tokens were pulled.

This consequence does not change notification failure handling or checked idle subtraction. For example, suppose currency0 is native, the collection pair is `(100,0)`, the protocol rate is 20000, and the instance has actual native balance `R+100` with reservation `R`, where `R>=100`. Assume a nonzero fee manager accepts the attempted native payment of 200 without returning funds and no intervening call changes the remaining balance. The payment leaves `R-100`. The subsequent native idle calculation subtracts the still-active reservation `R` and fails checked subtraction. That uncaught failure rolls back the entire transaction, including the payment. It is not a successful permanent principal drain.

Preserve the uncapped calculation and these failure semantics. Do not add a rate clamp, collected-fee cap or principal-spending guard to make this conditional case succeed.

**PT-COMP-03 - Protocol notification semantics.**

| Currency and condition | Required behavior and reported protocol amount |
| --- | --- |
| Native, nonzero attempted amount | Call `notify(address(0), amount, poolId)` with that native value. Successful completion reports `amount`. A caught notification revert reports zero and leaves the reverted payment in the instance. |
| ERC-20, nonzero attempted amount | Attempt `approve(feeManager,amount)` through the low-level approval helper. A returned false/failing low-level call causes routing to report zero without notification. |
| ERC-20, approval helper accepts | Call `notify(tokenAddress,amount,poolId)` with no native value. Successful completion reports `amount`; there is no post-call receipt or balance proof and no unconditional success-path allowance reset. |
| ERC-20, notification revert caught | Attempt `approve(feeManager,0)`, ignore its returned Boolean, and report zero. A decoding failure in that cleanup approval can still propagate. |

The source's catches do not cover all conceivable failures. Factory getter failures, checked arithmetic, malformed approval return data, and local/dependency call-setup failures can abort an operation. Do not specify "fee-manager failure can never block users." A successful notification is not proof that an ERC-20 allowance was consumed or tokens were pulled. Any actual token movement depends on the fee manager and token.

**PT-COMP-04 - Dust trigger and ratio calculation.** After protocol routing, sample currency0 idle as `i0`, then currency1 idle as `i1`, under PT-BAL-01. Skip Deploy if both are at most 1000. Otherwise calculate a proposed ratio swap using a fresh price `p`, bounds `a=T(lower), b=T(upper)`, and `F=Fit(p,a,b,i0,i1)`.

When `F>0`, needs are `n0=A0up(p,b,F)` and `n1=A1up(a,p,F)`; when `F=0`, both needs are zero. Leftovers are `j0=max(i0-n0,0)` and `j1=max(i1-n1,0)`, without underflow. Token0 leftover value in token1 units is:

`v0 = MD(MD(j0,p,Q96),p,Q96)`.

Choose token0 as input when `v0>=j1`, otherwise choose token1. Ties select token0. If the chosen leftover is at most 1000, swap amount is zero. Otherwise the uncapped proposal is half that leftover, floored.

**PT-COMP-05 - Active-pool cap.** For a positive leftover proposal, read active pool liquidity `Lpool`. If it is zero, the swap amount is zero. Otherwise the input-side reserve reference is:

- token0 input: `A0down(p,b,Lpool)`;
- token1 input: `A1down(a,p,Lpool)`.

Cap the proposal at `floor(floor(reserve*factory.maxZapBps()/10000)/4)`, with checked multiplication before the first division. This uses **active pool liquidity**, not position liquidity or the vault basket. The factory cap getter is not needed on the earlier zero-leftover/zero-active-liquidity exits. No compound tick-movement check is applied.

**PT-COMP-06 - Deploy outcome and events.** When the outer idle trigger fired, request Deploy even if the ratio swap amount is zero. Deploy can still add fitting balances. Its reported liquidity addition is the computed amount requested in a successful add, not a post-call independently measured increase.

Emit `Compounded` only if at least one reported collection amount or the reported liquidity addition is positive. A swap alone does not trigger this event. Return the reported collection pair from public `compound`, before subtraction of the protocol fraction; do not return net fees, swap output, or liquidity added in their place. No shares are minted or burned by compounding.

## 9. Share balances and allowances

**PT-ERC20-01 - Approval.** `approve` shall replace the allowance from caller to spender, permit zero spender and zero amount, emit `Approval`, and return true. It shall not require zeroing a prior allowance, verify initialization, collect fees, or call the manager.

**PT-ERC20-02 - Transfers.** `transfer` shall reject zero destination before subtracting the sender's balance. Sender subtraction is checked. Recipient addition is modulo `2^256` as the supplied implementation specifies, though ordinary supply invariants constrain it. Emit `Transfer` and return true. Zero transfers and self-transfers to a nonzero address are allowed; a successful self-transfer has no net balance change. No fee state or pool state is updated.

**PT-ERC20-03 - Delegated transfers.** `transferFrom` shall first inspect allowance from `from` to caller. A finite allowance is reduced by checked subtraction; an allowance equal to `2^256-1` is unchanged. There is no caller-equals-owner bypass. Then apply the same destination/balance rules as a normal transfer. Allowance consumption emits no additional `Approval`. A later failure rolls back the allowance reduction. No independent zero-`from` check exists; for example, zero-amount transfers from a zero-balance source can succeed when the destination is nonzero.

**PT-ERC20-04 - Mint/burn state.** Mints increase total supply by checked addition and increase the recipient balance modulo `2^256`, then emit `Transfer` from zero. Burns subtract the holder's balance with checked arithmetic and reduce supply modulo `2^256`, then emit `Transfer` to zero. No external mint/burn method is provided. Ordinary entry and exit requirements determine when these internal state transitions occur; the specification does not add an access-controlled administrative mint.

## 10. Manager callback and interaction contract

**PT-CB-01 - Authority and framing.** Every unlock request is made by the instance directly to the configured manager with ABI encoding of `(operation, bytes payload)`. The manager is expected to call the instance's `unlockCallback`. The callback shall reject any other sender with `NotPoolManager` **before** decoding data. It shall not require an armed request, entered flag, stored amount budget, receiver binding, or nonce. Separate manager enforcement of lock and settlement rules is an external dependency.

**PT-CB-02 - Operation encoding and return schema.** The operation discriminator is an ABI enum with values 0 through 4, encoded in its ABI word. Nested payloads and return bytes use standard Solidity ABI encoding, not packed encoding.

| Value / operation | Payload contract | Manager action | Inner return content |
| --- | --- | --- | --- |
| 0 / None | Outer bytes must decode; inner payload unused | None | Reject with `NotPoolManager`, even for the manager sender |
| 1 / Add | ABI `uint128 liquidity` | Positive liquidity modification for that amount, including zero if explicitly requested by callback data | `(uint256 used0,uint256 used1)` |
| 2 / Remove | ABI `uint128 liquidity` | Negative liquidity modification for that amount; zero remains a zero change | `(uint256 amount0,uint256 amount1)` from `U128` of caller deltas |
| 3 / Collect | Inner payload is ignored | Zero liquidity modification | Same two unsigned-converted caller deltas |
| 4 / Deploy | ABI tuple `(bool zeroForOne,uint256 swapAmount)` | Optional swap followed by conditional add | Tuple `(uint256 used0,uint256 used1,uint256 swapOut,int24 tickBefore,int24 tickAfter,uint128 liquidityAdded)` |

Malformed outer/required inner ABI data and out-of-domain enum values fail through ABI decoding rather than being reclassified as an application-level token or slippage error. Standard ABI trailing-data tolerance and integer/Boolean width validation apply. The callback itself is nonpayable. Its returned value is ABI `bytes` containing the inner encoding above; the manager unlock's expected bytes result carries that inner result to the calling operation.

**PT-CB-03 - Modification semantics.** Every add, remove or collection shall call manager `modifyLiquidity` with the stored key, computed ticks, zero salt, requested signed liquidity change, and empty hook data. It receives signed `int128` caller deltas `c0,c1` and separately signed fee deltas `f0,f1`. Resolve currency0 caller delta, then currency1 caller delta. Amounts described as used by an addition shall be:

`used_i = max(int256(f_i)-int256(c_i),0)`.

These differences are calculated after widening to signed 256-bit values. They are not necessarily actual balance changes in a hook-altered case. Removal and collection instead return `U128(c_i)`. The source does not reject a negative caller delta solely before that unsigned reinterpretation, although resolving it can fail.

**PT-CB-04 - Deploy price checkpoints and swap.** Deploy reads price and tick before doing anything else. Its before/after tick reports initially equal that tick. A zero swap amount makes no swap call and no post-swap tick read.

For a positive swap request, call manager `swap` with the stored key, requested direction, the signed amount specified in PT-MATH-05, and empty hook data. Price limit is minimum sqrt price plus one for token0-to-token1, maximum sqrt price minus one for the other direction. For ordinary representable positive inputs this is an exact-input request; the explicit signed-width qualification still applies.

The output report is the positive part of the opposite-currency delta, otherwise zero. Resolve currency0 then currency1 deltas before rereading price and after tick. No returned-input equality or independent positive-output check is performed.

**PT-CB-05 - Deploy addition.** If skip-add is true, return the swap report with zero used amounts and zero reported addition. Otherwise sample currency0 idle, then currency1 idle under PT-BAL-01, and calculate fundable liquidity using the current price already held by Deploy. When positive, request modification by that amount, report its used amounts from PT-CB-03, and report that requested liquidity as added. When zero, report zero used amounts and zero addition. This add has no dust threshold and no independent after-add liquidity comparison.

**PT-CB-06 - Delta settlement.** For each signed currency delta:

- negative native delta: payable `settle` for its positive magnitude;
- negative ERC-20 delta: `sync(currency)`, low-level transfer of the magnitude to manager, then `settle`;
- positive delta: `take(currency,instance,amount)`;
- zero delta: no settlement call for that currency.

The signed-minimum negation behavior in PT-MATH-05 applies. The returned `settle` paid amount is not used to adjust shares or validate equality. Positive amounts are taken to the instance before user payout. No ERC-6909 claim mint/burn or debt forgiveness/clear route is used. Any manager-enforced remaining-delta error propagates.

**PT-CB-07 - Separate unlock boundaries.** A compound can use one Collect unlock and another Deploy unlock. A paired deposit may then use a separate Add unlock. Redemption may then use a Remove unlock, and zap redemption a further swap-only Deploy unlock. Token pulls, share minting and burning, protocol notifications, and user payouts occur at the checkpoints specified here rather than inside a single encompassing callback. No one-callback atomicity rule shall replace this call structure. Transaction-level revert atomicity still applies.

## 11. Currency balances, transfers, donations and refunds

**PT-BAL-01 - Idle property.** Native idle is the instance's actual native balance minus the native reservation, using checked subtraction. ERC-20 idle is the token's reported `balanceOf(instance)`. No donation exclusion, principal escrow, per-depositor attribution, or expected-balance reconciliation is applied. A direct currency transfer does not mint shares, but its balance contribution can affect subsequent basket quotes, additions and redemption. Transfers of assets other than the configured pair do not enter these calculations and have no provided rescue route.

Whenever both configured idle balances are sampled as a pair, read currency0 idle before currency1 idle. This order does not establish a shared snapshot or authorize moving reads across a route's price, burn, settlement or reservation checkpoints. A native idle read uses the instance's actual native balance minus its current reservation; it does not call an ERC-20 balance function. Paired-entry addition reads a fresh manager price after its two idle reads. Deploy instead uses the initial or post-swap price already obtained at its specified checkpoint. The order introduces no new rejection condition, positive-receipt requirement or independently segregated balance budget.

**PT-BAL-02 - Incoming funds.** Pulling amount zero shall make no token call and return zero. Pulling a native amount shall return that nominal amount without making a transfer or independently checking funding. For the ordinary native currency0 routes, separate entrypoint value checks account for the incoming native value. A nonzero ERC-20 pull shall read the instance balance, call `transferFrom(caller,instance,amount)`, reread balance, and return the checked difference. If the latter balance is lower, subtraction fails. Reads use the external token ABI and can themselves fail or return malformed data.

**PT-BAL-03 - Low-level transfer helpers.** ERC-20 pulls and ERC-20 payments into PoolManager use low-level `transferFrom` and `transfer` respectively. They accept a successful call with no return data or with an ABI-decodable true Boolean. A failed call or decoded false rejects with PairToken `TransferFailed`; malformed nonempty return data can instead fail ABI decoding. There is no code-existence guard, retry, automatic approval strategy, fee adjustment, or decimal conversion in these helpers. A successful call/Boolean is not independent proof of token movement.

**PT-BAL-04 - Approval helper.** Protocol approvals use a low-level call to `approve(spender,amount)`. Failed calls return false to the routing logic; empty data or decoded true on a successful call returns true; decoded false returns false. Malformed nonempty data can revert on decoding. No zero-first retry is performed. The helper's result does not prove actual allowance state, and a successful external call that returns false need not have undone its own state changes.

**PT-BAL-05 - User payout helper.** Outgoing redemption payouts differ from PT-BAL-03:

- Native payout uses an empty-calldata value call to the recipient.
- ERC-20 payout uses `transfer(recipient,amount)`. Success requires the low-level call to succeed and either return no data or at least 32 bytes whose first word is exactly one. This inspects the raw first return word rather than ABI-decoding a Boolean. Extra bytes after that word are permitted; nonempty shorter data or another first word fails.
- Failed payouts use `WrappedError(address target,bytes4 selector,bytes reason,bytes details)`, containing the failed target (the payout recipient for native, the token address for ERC-20), the outbound selector (`bytes4(0)` for native, `transfer` for ERC-20), and the four-byte `NativeTransferFailed()` or `ERC20TransferFailed()` context in `details`. Its `reason` contains the complete raw returndata of the failed-or-rejected low-level call, whether returned by a revert or by a successful call whose data failed the payout acceptance rule.

Amounts reported by redemption and checked against minima are nominal transfer amounts, not the recipient's measured balance increase. Outgoing fee-on-transfer effects are not compensated or independently checked.

**PT-BAL-06 - Native refund difference.** Paired-entry refund clears the stored reservation before a nonzero empty-calldata value call to the sender. Refund failure uses PairToken `TransferFailed`, not the wrapped payout error. Refund zero skips the call. Native receipts outside a reservation are idle property; the receiver does not authenticate a manager or refund sender.

**PT-BAL-07 - Nonstandard-token boundary.** There is no local allowlist or explicit prohibition of transfer-tax, rebasing, paused, blacklisting, or dishonest-return tokens. Such tokens can change balances, amounts, and failure outcomes through the rules above. This baseline neither guarantees safe support nor imports an external project's prohibition. Any later restriction would be an explicit behavior change.

## 12. Events and emission order

**PT-EVENT-01 - Event schemas.** All five events are non-anonymous. Field order and indexing shall be:

| Event | Fields in order | Indexed fields |
| --- | --- | --- |
| `Transfer` | `address from, address to, uint256 value` | `from`, `to` |
| `Approval` | `address owner, address spender, uint256 value` | `owner`, `spender` |
| `Deposit` | `address sender, address to, uint256 amount0, uint256 amount1, uint256 shares` | `sender`, `to` |
| `Redeem` | `address sender, address to, uint256 amount0, uint256 amount1, uint256 shares` | `sender`, `to` |
| `Compounded` | `uint256 fees0, uint256 fees1, uint256 protocol0, uint256 protocol1, uint128 liquidityAdded` | none |

**PT-EVENT-02 - Values.** `sender` in deposit/redemption events is the original entrypoint caller, and `to` is the supplied recipient. Paired `Deposit` amounts are pull-returned amounts under PT-BAL-02: nominal selected native amounts or checked ERC-20 post-minus-pre balance differences, including zero. Zap `Deposit` amounts are reported add-used amounts, not the input pull return. Genesis `Deposit.shares` is the net recipient amount after the dead mint. `Redeem.shares` is the entire burned amount; zap `Redeem.amount0/amount1` remain the pair allocation before its sale. `Compounded` records reported collection, reported protocol routing, and requested successful addition as defined in section 8.

**PT-EVENT-03 - Local ordering.**

| Operation | Required order of that operation's own events |
| --- | --- |
| Approval | Allowance assignment precedes `Approval`. |
| Share transfer | Required allowance/balance changes precede `Transfer`; no consumption `Approval`. |
| Paired genesis deposit | Any automatic `Compounded`; `Transfer` from zero to dead address; `Transfer` from zero to recipient; native refund call; `Deposit`. |
| Other deposit / zap entry | Any automatic `Compounded`; recipient mint `Transfer`; paired-only native refund if applicable; `Deposit`. |
| Redemption | Any automatic `Compounded`; burn `Transfer`; removal/sale/payout effects; `Redeem`. |
| Compound | Collection, routing, and deployment precede its conditional `Compounded`. |

This is a partial-order contract, not a promise that no other logs occur between entries. Tokens, hooks, fee managers, and reentrant calls to unguarded ERC-20 functions can produce intervening logs. A reverted transaction retains none of its reverted-path state changes or logs.

## 13. Errors, precedence and propagation

**PT-ERROR-01 - Declared custom errors.** Every error below has an empty argument list.

| Error | Local predicate |
| --- | --- |
| `AlreadyInitialized` | Initialization flag already set when `initialize` is called. |
| `NotFactory` | Declared, but no local execution path uses it. Do not invent a factory-only guard. |
| `NotPoolManager` | Callback sender differs from stored manager; also the decoded None operation reaches this error. |
| `Reentrancy` | A guarded entrypoint is entered while its shared entered flag is nonzero. |
| `BadGenesis` | Zero-supply quote at most 1000; zero-supply paired entry with zero computed addition; or zap entry with zero supply or either zero basket reserve. |
| `MinShares` | Paired gross quote or zap final quote is zero/below its minimum; or shared redemption has zero requested shares/supply. |
| `MinOut` | Paired redemption below either output minimum; or chosen-leg redemption below its output minimum. |
| `ZapTooLarge` | Zap entry nominal input is zero or exceeds its runtime vault-basket cap. |
| `ZapMovesPrice` | Reported absolute zap tick movement exceeds the runtime signed limit. |
| `BadToken` | Chosen zap input/output matches neither configured currency. |
| `NativeMismatch` | Payable deposit/zap value fails the exact route-specific condition. |
| `TransferFailed` | Failed/false low-level pull or manager-payment token transfer, or failed nonzero paired native refund. |
| `ZeroAddress` | First initialization's manager is zero; transfer destination is zero; or deposit/redemption recipient is zero. |

**PT-ERROR-02 - Check ordering.** The following precedence must be preserved when several conditions are invalid:

- `initialize`: already-initialized check precedes zero-manager check; subsequent arithmetic failure rolls back all assignments.
- Guarded methods: `Reentrancy` precedes their body validation.
- Paired entry: recipient, native value, automatic compound, post-compound quote/genesis-size rule, share minimum, pulls/add, zero-supply computed-add check, mint/refund.
- Zap entry: recipient, selected token, native value, compound, supply/reserve genesis condition, nominal cap, pull/deploy, signed tick arithmetic and movement limit, share quote/minimum.
- Paired exit: recipient, compound, zero shares/supply, idle reads, caller balance burn, retention arithmetic/liquidity read/removal, minima, payouts.
- Zap exit: recipient and output token before the same shared redemption path; sale before final minimum and payout.
- `transferFrom`: finite allowance subtraction precedes destination and sender-balance validation; `transfer` checks destination before sender balance.
- Callback: sender equality precedes ABI decoding; an accepted None discriminator subsequently uses `NotPoolManager`.

These are observable dependency/check checkpoints, not a line-by-line implementation plan.

**PT-ERROR-03 - Non-custom failures.** Preserve checked-arithmetic overflow/underflow, division-by-zero, integer-width/ABI-decode failure, helper plain reverts and helper custom errors rather than normalizing all failures into the application errors above. In particular, the amount-to-liquidity helper can reject with `SafeCastOverflow()`, tick calculation with `InvalidTick(int24)`, and amount0 delta calculation with `InvalidPrice()`. Standard Solidity 0.8.26 ABI and panic behavior is part of the compilation contract; no new bespoke errors shall be assigned to malformed data or insufficient ERC-20 allowance/balance.

External failures cause the outer operation to fail except at the precise fee-notification and low-level-approval boundaries already specified. This does not mean that every original error byte sequence is bubbled unchanged: local pull/manager-payment failures and native refunds can use `TransferFailed`, malformed local Boolean data can fail decoding, and payout failures use the specified wrapper. Manager and token-balance-read failures retain their respective external-call/decoding behavior. Manager lock/settlement/pool/hook failures and token balance-read failures are not converted into PairToken slippage errors. The concrete errors emitted by absent manager/hook/token implementations remain dependency-defined. Return data that is nominally successful but malformed can still trigger caller-side decoding failure.

**PT-ERROR-04 - Atomicity without extra guarantees.** An uncaught failure shall revert the entire operation, including prior compound effects, share mutations, native reservations, transfers, and logs on that reverted path. Caught protocol-notification failures are exceptions that can allow the outer operation to continue. Atomicity shall not be confused with an extra rejection of partial fills, zero proceeds, or a successful but non-pulling fee notification.

## 14. Explicitly absent behavior

**PT-ABSENT-01.** This baseline shall not silently add `getRate`, `redeemTarget`, ERC-4626 asset conversions, target normalization, per-holder `claimFees`, a fee-index ledger, a TWAP/oracle admission gate, a manipulation-resistance guarantee, permit/signature approvals, external share mint/burn, delegated-owner redemption, a rescue/sweep, manager/factory setters, range changes, pause controls, or a rebalancing policy.

**PT-ABSENT-02.** A source comment describing clone deployment is not evidence of the concrete factory's transaction sequence, governance or initialization protection. Crane facets, CREATE3 services, DFPkg/registry deployment, an armed callback flag, fee-on-transfer bans, and an IndexedEx product rate contract are future adaptation decisions, not inherited requirements of this source baseline.

# Part II - Observable acceptance scenarios

**PT-AC-BASE.** These scenarios describe required observations, not executed tests or a test implementation plan. Where manager, hook, token or fee-manager behavior is a premise, the expected result is conditional on that premise. Amounts are raw units. Unless a scenario addresses interleaving, assume no unrelated state change and that unspecified dependency calls succeed. An expected revert includes rollback of earlier changes in that transaction.

## A. Identity, interfaces and ERC-20

| ID | Scenario | Expected observation | Requirements |
| --- | --- | --- | --- |
| PT-AC-01 | Fresh instance, before initialization | Empty metadata, false initialization, zero ordinary stored values, configured constants available. `previewRedeem(0)` returns zero pair without a manager read. Native receiver and zero-value ERC-20 operations are not blocked by an initialization gate. | PT-STATE-01, PT-API, PT-GET, PT-INIT-03, PT-VIEW-04 |
| PT-AC-02 | Caller A first initializes with nonzero manager and spacing 60 | Factory becomes A; stored key/name/symbol match inputs; bounds are `-887220` and `887220`; pool ID is the key's ABI hash. No initial shares or initialization event. | PT-INIT-01/02 |
| PT-AC-03 | Repeat initialization supplies even a zero manager; separately, first initialization supplies zero manager or zero spacing | Repeat call fails `AlreadyInitialized`; fresh zero-manager call fails `ZeroAddress`; fresh zero-spacing call fails arithmetic and leaves initialization unset. | PT-INIT-01/02, PT-ERROR-02 |
| PT-AC-04 | Nonzero but otherwise invalid manager/key is supplied to first initialization | No invented code-existence, currency-order, pool-readiness or hook-policy check rejects it at this boundary; any actual arithmetic failure remains possible. Later integration can fail independently. | PT-INIT-02/03 |
| PT-AC-05 | Owner sets finite allowance 10, spender transfers 4; then insufficient allowance/balance cases | Successful allowance is 6, balances move by 4, and only `Transfer` is emitted for consumption. Failure rolls back allowance. A caller transferring from itself still needs allowance. | PT-ERC20-01/03 |
| PT-AC-06 | Allowance is maximum uint256; zero/self/zero-destination transfers | Maximum allowance remains unchanged. Zero/self-transfer to a nonzero destination succeeds when prerequisite subtraction permits; zero destination fails. `transferFrom` insufficient finite allowance can fail before the zero-destination check. | PT-ERC20-02/03, PT-ERROR-02 |
| PT-AC-07 | Ordinary holder transfers shares with uncollected position earnings | No collect/compound or fee-debt mutation occurs. No personal earnings claim stays with the seller; transferred shares retain their collective property exposure. | PT-SCOPE-01/03, PT-ERC20-02 |

## B. Quotes, genesis, paired entry and zaps

| ID | Scenario | Expected observation | Requirements |
| --- | --- | --- | --- |
| PT-AC-08 | Zero-supply `previewDeposit(2000,2000)` with successful basket reads | Gross quote 2000, selected amounts 2000 each. With positive computed addition, `deposit(...,minShares=2000,to)` may succeed but mints only 1000 to recipient and 1000 to dead. `minShares=2001` rejects. | PT-QUOTE-01, PT-VIEW-03, PT-DEP-02/04 |
| PT-AC-09 | Zero-supply product sqrt is exactly 1000 or less | Quote/preview fails `BadGenesis`, before deposit's generic share-minimum check. A larger quote with zero computed fundable addition fails `BadGenesis` later in paired entry. | PT-QUOTE-01, PT-DEP-04 |
| PT-AC-10 | Positive supply with both basket reserves zero | Quote uses geometric mean, without the zero-supply 1000 threshold or a dead mint. A zero quote can be returned by preview but is rejected by deposit's `MinShares`. | PT-QUOTE-01, PT-DEP-04 |
| PT-AC-11 | Positive supply and exactly one basket reserve zero | Quote uses only the other leg, selects zero of the empty-reserve leg, and applies the corresponding full-precision floor. No artificial requirement for two nonzero input legs is added to paired entry. | PT-QUOTE-01 |
| PT-AC-12 | `S=10000`, basket `(3000,7000)`, requested amounts `(100,500)` | Quote is 333 shares with selected amounts `(100,234)`. The second amount uses upward rounding; the remaining 266 of requested token1 is not pulled. | PT-QUOTE-01, PT-DEP-03/05 |
| PT-AC-13 | Paired nominal quote is accepted, but a token delivers less than its selected amount | On an otherwise successful operation the share count stays at the earlier quote; the measured amount affects funding and event data. There is no post-receipt share recomputation. Downstream failure is allowed, not disguised as guaranteed token support. | PT-DEP-02/03/05, PT-BAL-02 |
| PT-AC-14 | Native paired request sends exactly `amount0` but quote selects less; recipient differs from sender | Full incoming value is excluded while compounding. Only selected native becomes eligible after the pull checkpoint. Remaining reservation is cleared and refunded to sender after minting, not to recipient. Refund failure reverts everything. | PT-DEP-01/03/05, PT-BAL-06 |
| PT-AC-15 | Wrong native value, or value sent for nonnative currency0 | Payable entry fails `NativeMismatch` before its initial compound. A zero recipient has earlier precedence. Nonpayable methods reject value at dispatch rather than using this route-specific error. | PT-API-BASE, PT-DEP-01, PT-ERROR-02 |
| PT-AC-16 | Pulled balances fund less than all held currencies, or established entry computes zero addition with a positive accepted quote | Unused pulled funds remain idle. Positive-supply entry does not add a genesis-style positive-add guard. No universal ERC-20 refund is made. | PT-DEP-03/04/05 |
| PT-AC-17 | Zap requested before positive supply and both positive reserves | It fails `BadGenesis` after its initial compound checkpoint, rather than bootstrapping the first shares. | PT-ZAP-02 |
| PT-AC-18 | Pre-zap input-side basket reserve is 100000 and `maxZapBps=100` | Nominal input cap is 1000. Input 1001 fails `ZapTooLarge`; 1000 passes that check; zero fails. This is independent of a different active-pool reserve. | PT-ZAP-02 |
| PT-AC-19 | Accepted nominal zap receives 999 actual units | Requested swap amount is 499, not a half of the nominal amount rounded up. Issuance uses deployment-used amounts and the stored pre-zap basket/supply; no zap refund of leftovers is made. | PT-ZAP-03/04 |
| PT-AC-20 | Zap reports tick movement equal to, above, or compared with a negative runtime limit | Equality passes; above fails `ZapMovesPrice`. A nonnegative movement exceeds a negative limit. Failure after deployment rolls back swap/add/pull. | PT-ZAP-03, PT-ERROR-04 |
| PT-AC-21 | Pre-existing idle currency is also consumed by zap Deploy | Reported used amounts can include that deployment. Expected minted shares are the specified minimum of two pre-basket fractions, not a newly introduced depositor-only balance fraction. | PT-ZAP-03/04 |
| PT-AC-22 | Genesis ordinary product overflows uint256 despite a representable mathematical square root | Checked multiplication fails; a full-precision algebraic replacement must not make this input succeed. | PT-MATH-01, PT-QUOTE-01 |

## C. Redemption, previews and balances

| ID | Scenario | Expected observation | Requirements |
| --- | --- | --- | --- |
| PT-AC-23 | `S=10000`, `s=1000`, `L=50000`, idle `(101,99)` after compound | `payout=999`, removal request `4995`, idle contributions `(10,9)`. Final pair is actual removal-return amounts plus those contributions; all 1000 shares burn. | PT-EXIT-01/02 |
| PT-AC-24 | A holder burns one raw share, with zero minima and otherwise successful dependencies | `payout=0`, no liquidity removal, no idle payout. The burn can succeed. Paired route skips zero output calls; chosen-leg route still attempts the selected zero transfer. | PT-EXIT-02/03/04/05 |
| PT-AC-25 | Same small burn but a positive required output | It fails `MinOut` and restores shares and prior compound effects; zero rounded liquidity is not the earlier rejection. | PT-EXIT-03/04, PT-ERROR-04 |
| PT-AC-26 | Another holder approved caller, but caller has no shares and attempts redemption | Allowance does not authorize an owner-substituting redemption. Only caller balance is burned and insufficient balance fails. | PT-EXIT-01 |
| PT-AC-27 | Chosen-leg exit with opposing amount X gets a partial-fill manager result | Resolve actual returned deltas. If total chosen-token amount meets `minOut` and payout succeeds, no extra complete-fill check rejects. Unconsumed input remains idle; no add occurs while skip-add is set. | PT-EXIT-04/05, PT-CB-04/05 |
| PT-AC-28 | Caller chooses token0 versus token1 on separate exits | Either configured currency can be selected; no stored target controls selection. An unrelated token fails `BadToken` before compounding. The event still describes the pre-swap pair amounts. | PT-EXIT-04, PT-EVENT-02 |
| PT-AC-29 | Preview redemption receives zero supply/shares, or requests more shares than supply | Zero case returns zero pair before manager reads. Positive oversized requests have no ownership/supply cap check; calculate by the preview formula subject to arithmetic/read failure. | PT-VIEW-04 |
| PT-AC-30 | Current-state preview precedes pending collection/reinvestment and later redemption | Equality with execution is not required. Compare preview's total-basket floor with execution's separate liquidity/idle floors and post-compound checkpoint. | PT-VIEW-05 |
| PT-AC-31 | Direct pool-currency donation arrives without a share mint | Supply and share balances stay unchanged; idle and basket can increase; later addition/redemption can use it. An unrelated-token donation is not included and no rescue API appears. | PT-BAL-01 |
| PT-AC-32 | All ordinary holders redeem while dead-address shares remain | No sweep overrides retention or burns dead shares; remaining supply includes those shares. | PT-EXIT-05, PT-DEP-04 |
| PT-AC-33 | Live sqrt price lies outside usable tick bounds | Basket applies its supplied endpoint pairs with sorting and no clamp. Fundable-liquidity calculation separately selects its one-sided branch. An idealized range formula must not replace basket behavior. | PT-MATH-02/03, PT-VIEW-02 |

## D. Collection, routing, callbacks and failures

| ID | Scenario | Expected observation | Requirements |
| --- | --- | --- | --- |
| PT-AC-34 | Position liquidity zero, with idle balances; separately, positive position liquidity | Zero position skips Collect but can still Deploy idle. Positive position issues zero-change collection and uses its caller deltas for returned fees. No shares mint from compound. | PT-COMP-01/06 |
| PT-AC-35 | Collection pair is `(10000,5000)`, protocol rate 250, nonzero manager; notifications succeed | Attempt amounts `(250,125)`. Public compound still returns `(10000,5000)`; the event records those collections and reported routing, not net `(9750,4875)` as its fee fields. | PT-COMP-02/03/06 |
| PT-AC-36 | Collection is positive but fee manager is zero; separately, both collections zero | In the first case both fee-manager and fee-rate getters are read but routing is skipped. In the second, those two collection-routing getters are skipped; a ratio-swap cap read can still occur. | PT-COMP-02 |
| PT-AC-37 | ERC-20 notification returns successfully without pulling approved tokens | Reported protocol amount is still the attempted amount. No success-path reset or balance proof is invented; actual remaining balances remain eligible idle. | PT-COMP-03 |
| PT-AC-38 | Native notification reverts; ERC-20 notification reverts after accepted approval | Caught native failure reports zero. Caught ERC-20 failure attempts allowance reset and reports zero, unless an unhandled cleanup/decode failure aborts. | PT-COMP-03 |
| PT-AC-39 | Approval helper returns false versus malformed nonempty data | False skips notification and reports zero; malformed data can abort with decode failure. A factory getter failure also propagates instead of being swallowed by the notification catch. | PT-BAL-04, PT-COMP-03 |
| PT-AC-40 | Both idle values equal 1000; separately, one exceeds 1000 | First case skips Deploy. Second invokes ratio calculation and Deploy, even if the ratio proposal is zero. The outer threshold is strict and uses raw units. | PT-COMP-04/06 |
| PT-AC-41 | Heavier leftover is at most 1000, or active pool liquidity is zero | Proposed swap becomes zero at the corresponding checkpoint. A zero swap does not by itself suppress an otherwise triggered addition attempt. | PT-COMP-04/05/06 |
| PT-AC-42 | Token0 converted leftover equals token1 leftover; positive proposal hits a small cap | Tie chooses token0. Apply both sequential value floors and the quarter of the runtime active-pool reserve cap. Do not substitute the user-zap basket cap or apply its tick guard. | PT-COMP-04/05 |
| PT-AC-43 | Only a ratio swap occurs, with zero collected amounts and zero addition | A state-changing compound can omit `Compounded`, because swap output alone is not its emission predicate. | PT-COMP-06 |
| PT-AC-44 | Add returns new fee deltas after the collection checkpoint | Settle its caller deltas and calculate used amounts from fee-minus-caller deltas. No second protocol fraction is computed for those later add fees during the same compound. | PT-COMP-02, PT-CB-03 |
| PT-AC-45 | Unrelated sender calls callback with either valid or malformed bytes | Always reject sender with `NotPoolManager` before decoding. A configured-manager callback is not rejected solely because no armed flag or entered operation exists. | PT-CB-01 |
| PT-AC-46 | Configured manager sends None, valid Add/Remove/Collect/Deploy, or malformed required payload | None gives `NotPoolManager`; valid operations follow their schemas; malformed data uses ABI failure. Collect ignores its inner payload. No new callback liquidity-positive check is added. | PT-CB-02 |
| PT-AC-47 | A settled removal/collection caller delta is `-1`, and settlement succeeds | Returned unsigned amount is `2^128-1`, not zero, an absolute value, or a checked-conversion rejection. A negative delta equal to signed-int128 minimum instead fails magnitude negation. | PT-MATH-05, PT-CB-03/06 |
| PT-AC-48 | Swap returns a nonpositive opposite-currency delta | Swap output report is zero; actual deltas are still settled. No positive-output guard is invented; outer share/output minima may independently reject. | PT-CB-04 |
| PT-AC-49 | Negative ERC-20 delta versus positive delta | Observe sync before transfer before settle for the former; observe take to instance for the latter; zero delta produces neither path. Hook data is empty. | PT-CB-03/04/06 |
| PT-AC-50 | Compound then entry/exit requires collection, deployment and another operation | Observe separate unlock boundaries, with pulls/mints/burns at their stated outer checkpoints. Do not merge the whole flow into one armed callback. | PT-CB-07 |
| PT-AC-51 | A token or notification callback reenters a guarded method versus a share approval/transfer | Guarded method rejects `Reentrancy` before body checks. Unguarded share methods are not rejected by that flag; their ordinary authorization/balance rules still apply. | PT-PERM-01 |
| PT-AC-52 | Outgoing payout token returns one byte instead of a full true ABI word; pulling token similarly returns malformed bytes | Payout fails through wrapped transfer-error behavior; its reason preserves the actual short returned bytes (for example, one byte 0x01), or the full 32 zero bytes if a successful token call returns false. Pulling may instead fail Boolean decoding. A PairToken `TransferFailed` must not be imposed on all malformed-data paths. | PT-BAL-03/05 |
| PT-AC-53 | Positive token payout is taxed by the token | Output minimum and event use the nominal amount; no recipient-balance measurement compensates for the tax. | PT-BAL-05/07 |
| PT-AC-54 | A later minimum check, refund, or payout fails after successful earlier compound/mint/burn effects | The whole transaction's reverted-path state and logs roll back. A separately caught notification failure does not necessarily cause such rollback. | PT-ERROR-04 |
| PT-AC-55 | Mathematical helper boundary: `T(0)`, tick outside range, equal liquidity-price bounds, or oversized one-side liquidity candidate | Respect `Q96`, `InvalidTick`, division failure, and checked candidate cast respectively. Do not rescue a cast overflow by selecting the other candidate first. | PT-MATH-02/03/04 |
| PT-AC-56 | A callback requests a swap magnitude at the signed uint256/int256 boundary | Encoding follows PT-MATH-05, including failure at `2^255` and sign reinterpretation above it; no newly specified safe-cast guard changes this baseline. Feasibility in ordinary pool states is not asserted. | PT-MATH-05, PT-CB-04 |
| PT-AC-57 | Logs are consumed for genesis, zap entry, zap exit and allowance consumption | Match all indexed fields, schemas, gross/net distinctions and local ordering from section 12. Never infer final zap output directly from `Redeem.amount0/amount1`. | PT-EVENT-01/02/03 |
| PT-AC-58 | Client calls an absent `getRate`, `claimFees`, administrative mint or rescue selector | No such public function is introduced; unknown selectors follow the absence of a fallback. | PT-ABSENT-01 |

## E. Consolidated clarification and boundary scenarios

These additional scenarios make already-specified behavior explicit. PT-AC-BASE and the same failure precedence apply; no scenario creates a new guard, repricing rule, fee clamp or execution guarantee.

| ID | Scenario | Expected observation | Requirements |
| --- | --- | --- | --- |
| PT-AC-59 | Successful native paired entry sends exactly requested amount0, but the accepted quote selects less; sender and recipient differ | The native pull return and Deposit native amount equal the selected nominal amount, not msg.value or a transfer-time balance difference. The remaining reservation is cleared and refunded to the caller after minting and before Deposit. A zero refund skips the call. | PT-DEP-01/03/05, PT-BAL-02/06, PT-EVENT-02/03 |
| PT-AC-60 | Established paired entry accepts a positive gross quote; a nonzero ERC-20 pull passes its return-data check but leaves the instance balance unchanged | The pull returns zero. There is no strictly-positive-receipt guard or share recomputation. If subsequent steps succeed, the corresponding Deposit amount is zero and the earlier accepted share count is minted. | PT-DEP-02/04/05, PT-BAL-02, PT-EVENT-02 |
| PT-AC-61 | A nonzero ERC-20 pull passes its low-level return-data check, but post-call instance balance is lower than pre-call balance | Checked subtraction fails and the operation rolls back, including earlier compound effects. The receipt is not clamped to zero or replaced with the nominal request; the negative difference is not by itself reclassified as TransferFailed. | PT-BAL-02/03, PT-ERROR-03/04 |
| PT-AC-62 | Trace reached idle-pair samples in basket, paired addition, redemption, compounding and Deploy addition | Each pair reads currency0 before currency1. Paired addition reads fresh price afterward; Deploy uses its already-held price. Redemption samples before burning. Skip-add Deploy returns without introducing idle-pair reads. Earlier failures still stop later reads. | PT-BAL-01, PT-VIEW-02, PT-DEP-03, PT-EXIT-01, PT-COMP-04, PT-CB-04/05 |
| PT-AC-63 | Established zap passes earlier guards; Deploy succeeds but computes no addition and reports both used amounts zero; subsequent tick arithmetic and movement check pass | Final share quote is zero, so MinShares rejects even when minShares is zero. Earlier pull, swap and compound effects roll back. No dead-share mint, separate no-add guard or leftover refund is introduced. | PT-ZAP-02/03/04, PT-CB-05, PT-ERROR-02/04 |
| PT-AC-64 | Chosen-leg redemption has final output zero and zero minimum, and the selected zero-value transfer succeeds; separately, paired redemption has zero output legs | Chosen-leg redemption still attempts the selected transfer, returns zero and emits the pre-swap pair amounts and original burned shares. Paired redemption skips each zero-amount payout call. Earlier dependency and minimum checks retain precedence. | PT-EXIT-02/03/04/05, PT-BAL-05, PT-EVENT-02, PT-ERROR-02 |
| PT-AC-65 | A reached native redemption payout, including a chosen-leg zero-value payout, is rejected by the recipient; all earlier steps succeed | Fail with WrappedError targeting the recipient, selector bytes4(0), the complete raw returned reason bytes and four-byte NativeTransferFailed() details. Revert the entire operation, including burn and earlier compound effects; do not use the paired native-refund TransferFailed error for this payout. | PT-EXIT-03/04, PT-BAL-05/06, PT-ERROR-04 |
| PT-AC-66 | Public compound starts with zero position liquidity; an idle balance exceeds DUST and Deploy successfully reports positive addition A | No Collect unlock or collection-routing fee-manager/rate getter reads occur. Return remains (0,0). Emit Compounded(0,0,0,0,A) and mint no shares. Ratio sizing may still read the factory cap getter. | PT-COMP-01/02/04/05/06 |
| PT-AC-67 | Public compound starts with zero position liquidity; the outer idle trigger fires and Deploy succeeds but reports zero addition | No Collect unlock runs and the public return is (0,0). Deploy still runs under its stated rules. No Compounded event is emitted solely for a swap or for zero addition, and no shares mint. | PT-COMP-01/04/06 |
| PT-AC-68 | Native collection pair is (100,0), protocol rate is 20000, actual pre-notification native balance is R+100 with reservation R>=100; notification accepts 200 without returning funds and no intervening balance change occurs | The next native idle subtraction underflows. Revert the whole transaction, including notification payment and collection. No fee clamp, caught-zero-protocol substitution or successful permanent principal drain is inferred. | PT-COMP-02/03/04, PT-BAL-01, PT-ERROR-04 |

# Part III - Dependency limits and planning boundaries

## 15. Required external contracts and observations

**PT-DEPENDS-01 - Factory view interface.** The stored initializer-caller address is used as a runtime provider of four nonpayable external view methods:

| Signature | Return | Used by |
| --- | --- | --- |
| `feeManager()` | `address` | Collection protocol routing |
| `protocolFeeBps()` | `uint16` | Collection protocol fraction |
| `maxZapBps()` | `uint16` | User-zap nominal cap and compound ratio cap |
| `maxZapTickMove()` | `int24` | User-zap post-deployment tick guard |

No defaults, immutability, governance constraints, owner, valid ranges beyond ABI types, or deployment-time snapshots of these values are established. Reads happen at the checkpoints specified above. A plan may depend on this interface without inventing its implementation.

**PT-DEPENDS-02 - Fee manager.** Notification is `notify(address token,uint256 amount,bytes32 poolId)`, external payable, with no declared return value. Native routing supplies value; ERC-20 routing supplies an allowance and no value. The actual pull, attribution, accounting, governance, recipient behavior and downstream calls are unknown. Successful return has exactly the reporting consequences specified in PT-COMP-03, not an implied accounting proof.

**PT-DEPENDS-03 - PoolManager interface.** Required interactions are `unlock(bytes)->bytes`; `modifyLiquidity` with `(int24 tickLower,int24 tickUpper,int256 liquidityDelta,bytes32 salt)` and empty hook data, returning caller and fee deltas; `swap` with `(bool zeroForOne,int256 amountSpecified,uint160 sqrtPriceLimitX96)` and empty hook data, returning caller delta; `sync(address currency)`; payable `settle()->uint256`; `take(address currency,address to,uint256 amount)`; and external storage reads through `extsload(bytes32)->bytes32`.

Each balance delta is a signed 256-bit packed value with signed 128-bit currency0 in the high half and signed 128-bit currency1 in the low half. Stored key and manager-read layout are requirements, not assumptions of arbitrary-manager compatibility.

The concrete manager/Pool engine is absent. Its full swap mathematics across ticks, fee processing, hook enforcement, lock behavior, pool validation, actual delta/error behavior, and deployed state are not independently established by this document. The supplied interface describes these responsibilities but is not execution proof.

**PT-DEPENDS-04 - Hooks and pool fees.** The key can identify a hook, and the instance forwards the key and empty hook data. There is no local hookless-only condition or local dynamic-fee prohibition. Hooks can affect caller deltas, outputs and execution failures under the manager interface. Treating manager-returned fees as independent proof of backed personal liabilities would be an additional, unsupported inference; this baseline does not create those liabilities.

**PT-DEPENDS-05 - Underlying currencies and chain state.** ERC-20 balance, approval and transfer implementations, actual decimals, freeze/tax/rebase behavior, available liquidity, initialized ticks, current price, recipient acceptance of native value and live factory values are not supplied. The requirements specify reactions to their observed results, not guaranteed outputs from unsupplied contracts.

## 16. What is settled and what blocks a narrower plan

| Subject | Settled by the baseline | Remaining unknown / planning effect |
| --- | --- | --- |
| Property and mint/burn rules | Basket claim, piecewise quote, dead mint, retention, exact checkpoint/rounding rules | No unresolved product decision is needed to preserve these. Changing them is a redesign. |
| Interfaces and events | Public signatures/getters, event indexing/values, guard and caller rules | A source-equivalent API plan can proceed from these requirements. |
| PairToken math helpers | Exact formulas, widths, thresholds, integer tick function | A planner need not inspect raw source to know the required results. Numerical equivalence still requires later authorized verification. |
| Factory creation/governance | First successful initializer becomes factory; runtime getters are known | Concrete clone creation/atomic initialization/governance/defaults are absent. An environment-specific deployment plan is blocked from claiming exact factory parity until these are supplied or explicitly scoped out. |
| Fee-manager integration | Interface, allowance/value pattern, success/failure reporting | Concrete pull/routing implementation and defaults are absent. Do not plan a particular token-sweep or distribution policy as an observed fact. |
| Manager engine and layout | Required calls, encoding, storage-read convention and expected responsibilities | Whole-system execution equivalence requires an identified compatible manager version/deployment; this bundle alone does not reconstruct its entire engine. |
| Hooks | Key forwarding, empty data, returned-delta consumption, no local allowlist | Concrete hook behavior is unknown; a fixed-output or hook-security guarantee would be blocked. |
| Token support and recipient behavior | Exact helper acceptance/rejection and measurement behavior | No global nonstandard-token safety guarantee or live recipient behavior is settled. |
| Live outputs and parameters | Algebra and check positions are known | No current cap, protocol rate, price, balance, fee yield or concrete user payout can be invented. |
| Architecture adaptation | Direct position ownership is specified | Crane/registry/rate-provider adaptations require separate explicit decisions and a documented divergence from this baseline. |
| Workflow provenance | This candidate is source-informed, authored by a source-exposed analyst | A different planner alone does not establish source nonexposure or legal clearance. |

**PT-HANDOFF-01 - Standalone use.** Publish this complete PRD as the single planner-facing working specification, including its purpose, conformance rules, full functional requirements, complete acceptance scenarios and external dependency limits. No earlier requirements document, errata annex, council report, source listing or instruction to inspect target code is required to interpret it. Preserve analyst traceability separately. If a later plan deliberately changes a specified behavior, identify the requirement it supersedes and obtain the separate product decision; do not describe that change as source equivalence.

**PT-HANDOFF-02 - Limits of this document.** This task authorizes documentation consolidation, not implementation, execution, deployment or legal determinations. The PRD is source-informed; its acceptance scenarios are not executed evidence. No license opinion, legal clearance or source-unexposed workflow is certified. A source SPDX marker, verified-match metadata or a different implementing agent does not itself establish those conclusions. These limits do not prevent requirements-based planning, but unknown external behavior must remain an explicit dependency rather than an invented guarantee.




