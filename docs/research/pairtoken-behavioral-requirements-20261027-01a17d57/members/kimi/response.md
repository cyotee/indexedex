Ask: Author a new independent PairToken behavioral-requirements response - wanted: complete source-faithful requirements, scenarios, dependency limits, and traceability. For you: `apply_patch` is unavailable, so the complete admitted Markdown artifact follows; no files were changed and no current-run peers were read. Now: no task remains. Next: no task remains.

# Candidate PairToken Behavioral Requirements

Document status: independent initial requirements response  
Run: `pairtoken-behavioral-requirements-20261027-01a17d57`  
Baseline: verified PairToken source identified in the run brief  
Purpose: functional requirements for a later implementation-planning workflow, not an implementation plan or implementation authorization

## 1. System, property, and scope

### PT-SCOPE-001 — Single fungible claim

The system shall provide one freely transferable, 18-decimal ERC-20 share token representing collective ownership of:

1. one Uniswap V4 liquidity position;
2. the vault’s idle balances of the two pool currencies; and
3. future position growth produced by fee compounding, after any successfully routed protocol carve.

There shall be no second receipt token, position NFT requirement, personal fee-claim ledger, or separately redeemable historical fee balance.

### PT-SCOPE-002 — One fixed position identity

Each vault instance shall bind to one `PoolKey`, one full-range tick interval derived from that key’s tick spacing, and zero position salt. The position owner shall be the vault contract address itself.

The vault shall not support additional ranges, later migration of the pool key, a configured target currency, or rebalancing into another position.

### PT-SCOPE-003 — Source-equivalent behavior, including quirks

An implementation shall preserve the behavior specified here, including behavior that might be redesigned in another product. In particular, it shall not silently:

- replace basket-based issuance with liquidity-unit issuance;
- segregate donations or idle balances from share property;
- introduce per-account fee accounting;
- repair genesis slippage ordering;
- recompute paired-deposit shares after measuring ERC-20 receipt;
- add full-fill or positive-output assertions to swaps;
- add an armed callback flag;
- reject zero-payout burns; or
- invent a `getRate` API.

### PT-SCOPE-004 — Out-of-scope adaptations

Crane diamond deployment, DFPkg/registry integration, a product-specific `getRate`, alternative fee policy, configurable ranges, target-only redemption, and policy changes are future adaptations, not requirements of this baseline.

The source’s EIP-1167 deployment description is provenance information, not independently verified deployed bytecode or factory behavior.

---

## 2. State concepts, units, and constants

### PT-STATE-001 — Units and notation

All token amounts, fees, idle balances, reserves, and swap outputs shall use the currencies’ raw indivisible units. No token-decimal normalization shall occur in vault accounting.

| Symbol | Meaning |
|---|---|
| `S` | Current share `totalSupply`, including dead shares |
| `s` | Shares supplied to an operation |
| `L` | Current liquidity of the vault’s one position |
| `P` | Current pool `sqrtPriceX96`, in Q64.96 form |
| `PL`, `PU` | Square-root prices at the lower and upper position ticks |
| `I_i` | Vault idle balance of currency `i`, after native reservation adjustment |
| `R_i` | Basket reserve of currency `i`: position amount plus `I_i` |
| `Q96` | `2^96` |
| `floorDiv(a,b)` | Integer division rounding down |
| `ceilDiv(a,b)` | Integer division rounding up |
| `mulFloor(a,b,d)` | Full-precision `floor(a*b/d)` |
| `mulCeil(a,b,d)` | Full-precision `ceil(a*b/d)` |

Share decimals are metadata and do not introduce a price or conversion offset into the equations.

### PT-STATE-002 — Constants

| Constant | Required value | Effect |
|---|---:|---|
| `BPS` | `10_000` | Basis-point denominator |
| `DEAD_SHARES` | `1_000` raw shares | Genesis dead mint |
| `RETENTION_BPS` | `10` | Redemption retention |
| `DUST` | `1_000` raw currency units | Compounding threshold |
| `DEAD` | `0x000000000000000000000000000000000000dEaD` | Genesis recipient |
| `decimals` | `18` | Share metadata |
| position salt | `bytes32(0)` | Position identity |
| `MIN_TICK`, `MAX_TICK` | `-887272`, `887272` | Tick helper bounds |
| `MIN_SQRT_PRICE` | `4295128739` | Swap-limit base |
| `MAX_SQRT_PRICE` | `1461446703485210103287273052203988822378723970342` | Swap-limit base |

### PT-STATE-003 — Mutable state concepts

The implementation shall expose or maintain behavior equivalent to:

- ERC-20 metadata, supply, balances, and allowances;
- `factory`, `poolManager`, stored `PoolKey`, `poolId`, ticks, and `initialized`;
- an operation-scoped native reservation;
- a non-reentrancy state; and
- a swap-only flag suppressing liquidity addition during chosen-leg redemption.

No booked liquidity ledger `U`, conversion offset, target currency, fee index, reward debt, unclaimed-fee balance, escrow liability, or remainder account exists in this baseline.

---

## 3. Complete public and external API

### PT-API-001 — Declared named functions

The following 17 declared functions and the payable receiver constitute the complete named external interaction surface.

| Function | Mutability | Returns | Caller and recipient rules |
|---|---|---|---|
| `initialize(IPoolManager _poolManager, PoolKey calldata key, string calldata name_, string calldata symbol_)` | external, nonpayable | none | First successful caller becomes `factory`; callable only while uninitialized |
| `approve(address spender,uint256 amount)` | external, nonpayable | `bool` | Approves `msg.sender`’s shares; zero spender is not rejected |
| `transfer(address to,uint256 amount)` | external, nonpayable | `bool` | Transfers from `msg.sender`; `to` must be nonzero |
| `transferFrom(address from,address to,uint256 amount)` | external, nonpayable | `bool` | Uses `from`’s allowance for `msg.sender`; `to` must be nonzero |
| `poolKey()` | external, view | `PoolKey memory` | Unrestricted |
| `token0()` | public, view | `address` | Returns unwrapped currency0 |
| `token1()` | public, view | `address` | Returns unwrapped currency1 |
| `positionLiquidity()` | public, view | `uint128` | Reads the vault-owned, zero-salt position |
| `basket()` | public, view | `(uint256 reserve0,uint256 reserve1)` | Current position amounts plus idle balances |
| `previewDeposit(uint256 amount0,uint256 amount1)` | public, view | `(uint256 shares,uint256 used0,uint256 used1)` | Quotes against present basket and supply |
| `previewRedeem(uint256 shares)` | external, view | `(uint256 amount0,uint256 amount1)` | Quotes two-leg retained redemption |
| `deposit(uint256 amount0,uint256 amount1,uint256 minShares,address to)` | external, payable | `uint256 shares` | Pulls from `msg.sender`; mints to nonzero `to`; native refund goes to `msg.sender` |
| `zapDeposit(address tokenIn,uint256 amountIn,uint256 minShares,address to)` | external, payable | `uint256 shares` | Pulls from `msg.sender`; mints to nonzero `to`; no native refund |
| `redeem(uint256 shares,uint256 min0,uint256 min1,address to)` | external, nonpayable | `(uint256 amount0,uint256 amount1)` | Burns only `msg.sender`’s shares; pays nonzero `to` |
| `redeemZap(uint256 shares,address tokenOut,uint256 minOut,address to)` | external, nonpayable | `uint256 out` | Burns only `msg.sender`’s shares; pays selected currency to nonzero `to` |
| `compound()` | external, nonpayable | `(uint256 fees0,uint256 fees1)` | Permissionless; returns gross collected amounts |
| `unlockCallback(bytes calldata rawData)` | external, nonpayable | `bytes memory` | `msg.sender` must equal configured `poolManager` |
| `receive()` | external, payable | none | Accepts native currency from any sender |

`deposit`, `zapDeposit`, `redeem`, `redeemZap`, and `compound` shall be non-reentrant. The other functions and receiver shall not acquire that guard implicitly.

### PT-API-002 — Generated getters

The following 17 generated getters shall be public, view, nonpayable, and unrestricted:

| Getter | Result |
|---|---|
| `name()` | `string` |
| `symbol()` | `string` |
| `decimals()` | `uint8(18)` |
| `totalSupply()` | `uint256` |
| `balanceOf(address account)` | `uint256` |
| `allowance(address owner,address spender)` | `uint256` |
| `BPS()` | `uint256(10_000)` |
| `DEAD_SHARES()` | `uint256(1_000)` |
| `RETENTION_BPS()` | `uint256(10)` |
| `DUST()` | `uint256(1_000)` |
| `DEAD()` | dead address |
| `factory()` | `address` |
| `poolManager()` | manager address |
| `poolId()` | `bytes32` |
| `tickLower()` | `int24` |
| `tickUpper()` | `int24` |
| `initialized()` | `bool` |

### PT-API-003 — Pool key structure

The stored key shall contain currency0, currency1, pool fee, tick spacing, and hooks. Initialization stores the supplied key; the vault itself does not add an independent hook-policy or dynamic-fee validation layer.

---

## 4. Initialization and plain ERC-20 behavior

### PT-INIT-001 — One-shot initialization

Initialization shall:

1. revert `AlreadyInitialized` if already initialized;
2. revert `ZeroAddress` if the supplied manager is zero;
3. mark the instance initialized;
4. set `factory` to the caller;
5. store the manager, key, name, and symbol;
6. derive `poolId` as the key’s canonical V4 hash;
7. derive the lower tick as `TickMath.minUsableTick(key.tickSpacing)`; and
8. derive the upper tick as `TickMath.maxUsableTick(key.tickSpacing)`.

The first successful initializer therefore becomes `factory`. `NotFactory` shall remain declared but unused; no factory-only initializer restriction shall be invented.

### PT-ERC20-001 — Approvals

`approve` shall overwrite `allowance[msg.sender][spender]`, emit `Approval`, and return `true`.

`transferFrom` shall leave `type(uint256).max` allowance unchanged. Any finite allowance shall be reduced by the transferred amount using checked subtraction, so insufficient allowance reverts.

### PT-ERC20-002 — Transfers

Transfers shall:

- reject a zero recipient with `ZeroAddress`;
- subtract from the sender using checked arithmetic;
- add to the recipient using the source’s unchecked balance-addition semantics;
- emit exactly one share `Transfer`; and
- return `true`.

Transfers shall not collect or compound fees, alter position liquidity, change supply, or create personal fee claims. Zero-amount transfers are not independently rejected.

### PT-ERC20-003 — Mint and burn accounting

Minting shall increase supply with checked addition, increase the recipient balance with unchecked addition, and emit `Transfer(address(0),to,amount)`.

Burning shall decrease the holder balance with checked subtraction, decrease supply with unchecked subtraction, and emit `Transfer(from,address(0),amount)`.

Redemption shall burn only the caller’s balance; share allowances shall not authorize redemption of another account’s shares.

---

## 5. Price, liquidity, basket, and view mathematics

### PT-MATH-001 — Full-precision and checked arithmetic

`mulFloor` and `mulCeil` shall preserve a 512-bit intermediate product and revert if the denominator is invalid or the result cannot fit `uint256`.

The following multiplications use ordinary checked `uint256` multiplication rather than full-precision multiplication:

- `amount0 * amount1` in geometric quotes;
- `shares * 9_990` in redemption payout;
- `fees_i * protocolFeeBps` in protocol carve;
- `reserveIn * maxZapBps` in the user-zap cap; and
- active-pool reserve times `maxZapBps` in the compounding cap.

Solidity 0.8.26 checked arithmetic and narrowing rules shall apply. In particular, liquidity and signed swap-size conversions shall not silently truncate.

### PT-MATH-002 — Position amount helpers

For sorted square-root prices `a <= b`, define:

```text
A0_down(a,b,l) = floor(floor(l * Q96 * (b-a) / b) / a)
A0_up(a,b,l)   = ceil(ceil(l * Q96 * (b-a) / b) / a)
A1_down(a,b,l) = floor(l * (b-a) / Q96)
A1_up(a,b,l)   = ceil(l * (b-a) / Q96)
```

The helper shall sort its two price arguments before applying these formulas. Requirements shall not substitute an idealized out-of-range clamp for this actual helper behavior.

### PT-MATH-003 — Liquidity supported by token amounts

For current price `P` and sorted bounds `a <= b`:

- at or below `a`, only amount0 determines liquidity;
- strictly inside `(a,b)`, liquidity is the smaller of the amount0-supported and amount1-supported values;
- at or above `b`, only amount1 determines liquidity.

For amount0:

```text
intermediate = floor(a*b/Q96)
liquidity0 = floor(amount0*intermediate/(b-a))
```

For amount1:

```text
liquidity1 = floor(amount1*Q96/(b-a))
```

The result shall be narrowed to `uint128` with overflow rejection.

### PT-MATH-004 — Integer square root

Genesis and empty-basket quotes shall use the floor integer square root of the checked product `amount0 * amount1`.

### PT-MATH-005 — Position liquidity

`positionLiquidity()` shall read manager state for:

```text
owner = vault address
range = stored tickLower/tickUpper
salt = zero
```

It shall not return a cached or separately maintained liquidity total.

### PT-VIEW-001 — Basket

When `L > 0`, position components shall be:

```text
position0 = A0_down(P,PU,L)
position1 = A1_down(PL,P,L)
```

When `L = 0`, both position components are zero.

The basket shall then be:

```text
R0 = position0 + I0
R1 = position1 + I1
```

Basket reads shall not collect pending fees or simulate compounding.

### PT-VIEW-002 — Paired share quote

Given offered amounts `a0,a1`, basket `R0,R1`, and supply `S`, the quote shall follow all branches exactly:

| Condition | Quoted shares | Quoted used amounts |
|---|---|---|
| `S == 0`, or `R0 == 0 && R1 == 0` | `floorSqrt(a0*a1)` | `(a0,a1)` |
| Only `R0 == 0` | `mulFloor(a1,S,R1)` | `(0,a1)` |
| Only `R1 == 0` | `mulFloor(a0,S,R0)` | `(a0,0)` |
| Both reserves positive and `S > 0` | `min(mulFloor(a0,S,R0),mulFloor(a1,S,R1))` | Rounded-up proportional amounts, capped by offers |

For the final branch, with gross shares `g`:

```text
used0 = min(a0,mulCeil(g,R0,S))
used1 = min(a1,mulCeil(g,R1,S))
```

At zero supply, a geometric quote `g <= 1_000` shall revert `BadGenesis`.

### PT-VIEW-003 — Deposit preview

`previewDeposit` shall apply PT-VIEW-002 to the current basket and current supply without compounding.

At genesis it returns the gross geometric quote, not the net amount the recipient receives after the dead-share deduction.

### PT-VIEW-004 — Redemption preview

If `S == 0` or `s == 0`, `previewRedeem` shall return `(0,0)`.

Otherwise:

```text
payout = floor(s*9_990/10_000)
preview0 = mulFloor(R0,payout,S)
preview1 = mulFloor(R1,payout,S)
```

The preview shall not:

- check the caller’s share balance;
- reject `s > S` independently;
- collect or compound fees;
- simulate actual liquidity removal;
- simulate a chosen-leg swap; or
- guarantee equality with execution.

Execution rounds the liquidity slice and idle allocation separately, whereas this preview rounds proportional total basket amounts.

---

## 6. Paired deposits and genesis

### PT-DEP-001 — Entry checks and checkpoints

`deposit` shall reject a zero share recipient and enforce native-value rules before compounding:

- if currency0 is native, `msg.value` must equal offered `amount0`;
- otherwise `msg.value` must be zero.

The current native value shall initially be reserved so it is excluded from incumbent idle balances during compounding and basket quotation.

The function shall then compound before capturing `R0`, `R1`, and `S`.

### PT-DEP-002 — Quote before pull

The contract shall compute `(grossShares,quotedUsed0,quotedUsed1)` using PT-VIEW-002 and the post-compound, pre-pull basket and supply.

It shall revert `MinShares` when:

```text
grossShares == 0 OR grossShares < minShares
```

At genesis this check applies to gross shares before the dead-share deduction. Therefore, a successful call may mint fewer than `minShares` to the recipient.

### PT-DEP-003 — Pull and actual receipt

The contract shall pull only the quoted used amounts.

For ERC-20 legs, actual receipt shall be measured as the vault balance increase across `transferFrom`. The returned used amounts shall become these measured receipts. The already computed share amount shall not be recomputed.

For native currency0, receipt equals the requested used amount. Unused ERC-20 shall not be pulled. Pulled ERC-20 that does not fit the subsequent add shall remain idle rather than being universally refunded.

After pulling, the native reservation shall become:

```text
msg.value - used0, when currency0 is native
0, otherwise
```

This leaves the used native amount available for deployment while reserving the expected refund.

### PT-DEP-004 — Add all supportable idle liquidity

After the pull, the contract shall calculate liquidity supported by all current idle balances at the current price and full-range bounds.

If that liquidity is positive, it shall perform a separate Add unlock. Existing donations and previously idle balances are therefore eligible for deployment, not merely the current depositor’s funds.

There is no booked-`U` update or reconciliation requirement.

### PT-DEP-005 — Genesis and completion

If and only if pre-deposit `S == 0`:

1. liquidity added by the deposit must be positive, or the call reverts `BadGenesis`;
2. `1_000` shares shall be minted to `DEAD`; and
3. the recipient share amount shall become `grossShares - 1_000`.

If `S > 0` but both basket reserves were zero, the geometric branch shall be used without a new dead mint and without the genesis positive-added-liquidity guard.

The contract shall mint the resulting shares to `to`, refund remaining reserved native to `msg.sender`, and emit `Deposit` using measured used amounts and net recipient shares.

Native refund failure shall revert `TransferFailed`.

---

## 7. Single-leg zap deposits

### PT-ZAP-001 — Token and native selection

`zapDeposit` shall reject a zero recipient and determine swap direction from `tokenIn`:

- token0 input means zero-for-one;
- token1 input means one-for-zero;
- any other address reverts `BadToken`.

For native currency0 input, `msg.value` must equal `amountIn`. In every other case, `msg.value` must be zero. Violations revert `NativeMismatch`.

The incoming native value shall be reserved during the initial compound.

### PT-ZAP-002 — Existing-vault and size requirements

After compounding, the contract shall capture the pre-zap basket and supply. It shall revert `BadGenesis` if:

```text
S == 0 OR R0 == 0 OR R1 == 0
```

The selected input reserve is `R0` for token0 input and `R1` for token1 input. Nominal `amountIn` shall be bounded before the pull:

```text
cap = floor(reserveIn * factory.maxZapBps() / 10_000)
```

`amountIn == 0` or `amountIn > cap` reverts `ZapTooLarge`.

This cap uses the vault basket, including idle balances. It is distinct from the active-pool-liquidity cap used by compounding.

### PT-ZAP-003 — Measured input, swap, and deployment

The contract shall pull nominal `amountIn`, replace it with measured actual receipt, clear the native reservation, and request an exact-input swap of:

```text
swapAmount = floor(actualReceived/2)
```

The deployment operation shall record the tick before the swap and after it, settle swap deltas, and add all liquidity supported by idle balances at the post-swap price.

The absolute tick movement shall be compared with `factory.maxZapTickMove()` after deployment. Movement greater than the configured maximum shall revert `ZapMovesPrice`, rolling back the operation.

No separate minimum swap-output parameter exists.

### PT-ZAP-004 — Zap share amount

Let `used0,used1` be the deployment operation’s returned net-consumption amounts defined in PT-CB-005. Zap shares shall be:

```text
s0 = mulFloor(used0,S,R0)
s1 = mulFloor(used1,S,R1)
shares = min(s0,s1)
```

The quote uses pre-zap basket and pre-zap supply, not liquidity added or post-zap reserves.

Zero shares or shares below `minShares` revert `MinShares`. The contract shall then mint to `to` and emit `Deposit` with the returned used amounts and shares. No genesis dead mint applies.

---

## 8. Redemption and retention

### PT-RED-001 — Common redemption checkpoints

Both redemption routes shall reject a zero recipient. `redeemZap` shall also validate `tokenOut` before compounding; an address other than token0 or token1 reverts `BadToken`.

The route shall compound first, then capture:

- pre-burn supply `S`;
- idle balances `I0,I1`; and
- caller burn amount `s`.

`s == 0` or `S == 0` reverts `MinShares`. The caller’s `s` shares are then burned. Position liquidity `L` is read after the burn.

### PT-RED-002 — Retained payout and rounding

The retained payout basis shall be:

```text
payout = floor(s * 9_990 / 10_000)
liqOut = mulFloor(L,payout,S)
```

`liqOut` shall be narrowed to `uint128` under checked conversion rules.

If `liqOut > 0`, a separate Remove unlock shall remove exactly that liquidity. Otherwise no removal occurs and removed amounts are zero.

For each currency:

```text
idleOut_i = mulFloor(I_i,payout,S)
amount_i = removedCallerDelta_i + idleOut_i
```

The 10-basis-point unpaid portion remains in collective vault property. Dead shares remain in supply and are not redeemed specially.

### PT-RED-003 — Removal delta conversion

Each returned removal delta shall be converted using the source’s explicit same-width sequence:

```text
uint256(uint128(int128Delta))
```

A negative signed value is therefore reinterpreted at 128 bits before widening; it is not rejected by an explicit sign guard. This is a required source semantic, not an assertion that a negative removal delta is reachable or exploitable under the absent manager implementation.

Removal caller delta may include principal, fee, and applicable hook effects under the manager interface.

### PT-RED-004 — Two-leg redemption

`redeem` shall check:

```text
amount0 >= min0 AND amount1 >= min1
```

Otherwise it reverts `MinOut`.

It shall transfer each positive amount to `to`, then emit `Redeem` with both amounts and burned shares. Token-transfer or manager failures propagate and revert the operation.

### PT-RED-005 — Chosen-leg redemption

`redeemZap` shall identify the unwanted redeemed amount:

- token0 output swaps amount1 into token0;
- token1 output swaps amount0 into token1.

If the unwanted amount is positive, the contract shall request an exact-input swap of that amount with liquidity addition suppressed for the duration of the unlock. The redeemed balances shall not be intentionally redeployed.

The output shall be:

```text
out = wantedRedeemedAmount + swapOut
```

`out < minOut` reverts `MinOut`. The selected currency shall then be transferred to `to`.

`Redeem` shall emit the pre-swap two-leg amounts, not final `out`.

The contract shall not independently assert complete input consumption or strictly positive swap output.

---

## 9. Collective fee collection and protocol routing

### PT-FEE-001 — Collection trigger and returned fees

Public `compound` shall be permissionless and non-reentrant. Compounding shall also run at the start of every paired deposit, zap deposit, and redemption route.

If position liquidity is positive, collection shall perform a zero-liquidity-delta Collect unlock. Otherwise gross collected fees are zero.

The returned `fees0,fees1` shall be the settled collection caller-delta amounts, not a direct allocation from the separately returned `feesAccrued` value. Compounding shall not mint shares or change supply.

### PT-FEE-002 — Protocol configuration

If either gross fee is positive, the contract shall read:

- `factory.feeManager()`; and
- `factory.protocolFeeBps()`.

If the manager is nonzero and the rate is positive, the attempted carve for each currency is:

```text
protocol_i = floor(fees_i * protocolFeeBps / 10_000)
```

Factory getter failures shall propagate.

### PT-FEE-003 — Native carve

For a positive native carve, the contract shall attempt `notify` with native value equal to the carve.

A successful call reports that amount as protocol routed. A caught notify failure reports zero and does not block compounding.

### PT-FEE-004 — ERC-20 carve

For a positive ERC-20 carve, the contract shall first attempt approval of the fee manager for that amount.

A failed or false approval returns zero without calling notify. If approval succeeds, notify is attempted:

- success reports the carve amount;
- a caught notify revert triggers an attempt to clear the approval and reports zero.

Successful notify is not proof that the fee manager pulled the approved tokens. There is no requirement that approval clearing always succeeds or that every malformed external response is caught.

### PT-FEE-005 — Collective remainder

Assets remaining after collection and any carve shall remain vault property. Usable idle balances shall be eligible for ratio swapping and liquidity addition. No per-holder fee claim or sender-retained transfer claim shall be created.

---

## 10. Ratio-swap compounding

### PT-COMP-001 — Compounding trigger

After fee collection and carving, the contract shall inspect current idle balances.

If either `I0 > DUST` or `I1 > DUST`, it shall compute a ratio swap and invoke deployment. Equality with `DUST` on both sides does not trigger this branch.

A zero computed swap shall not itself suppress the subsequent liquidity-add attempt.

### PT-COMP-002 — Fitting liquidity and leftovers

Using current idle balances and price:

1. compute `l`, the liquidity supported by both idle amounts;
2. if `l == 0`, set both required amounts to zero;
3. otherwise compute:
   ```text
   need0 = A0_up(P,PU,l)
   need1 = A1_up(PL,P,l)
   ```
4. compute:
   ```text
   left0 = max(I0-need0,0)
   left1 = max(I1-need1,0)
   ```

### PT-COMP-003 — Heavier-side selection

Token0 leftovers shall be valued in token1 units using two sequential full-precision floors:

```text
left0In1 = mulFloor(mulFloor(left0,P,Q96),P,Q96)
```

If `left0In1 >= left1`, select token0 and zero-for-one; otherwise select token1 and one-for-zero. Token0 wins exact ties.

If the selected leftover is at most `DUST`, return the selected direction with zero swap. Otherwise propose:

```text
swapAmount = floor(selectedLeftover/2)
```

### PT-COMP-004 — Active-pool cap

If current active pool liquidity is zero, the swap amount shall become zero.

Otherwise calculate the active-liquidity-implied input reserve at current price:

- zero-for-one: `A0_down(P,PU,activeL)`;
- one-for-zero: `A1_down(PL,P,activeL)`.

Then:

```text
cap = floor(floor(reserve*factory.maxZapBps()/10_000)/4)
swapAmount = min(proposedSwap,cap)
```

This cap uses active pool liquidity, not the vault basket. Compounding shall not apply the user-zap tick-movement guard.

### PT-COMP-005 — Swap and add

Deployment shall:

1. read pre-swap price and tick;
2. if swap amount is positive, perform an exact-input swap using:
   - `MIN_SQRT_PRICE + 1` for zero-for-one;
   - `MAX_SQRT_PRICE - 1` for one-for-zero;
3. settle both swap deltas;
4. refresh price and tick;
5. unless swap-only mode is active, compute liquidity supported by all idle balances at the current price; and
6. add that liquidity if positive.

### PT-COMP-006 — Compounded event

The event shall carry:

- gross collected `fees0,fees1`;
- protocol amounts reported by the carve operations; and
- liquidity added.

It shall be emitted when any gross fee is positive or liquidity added is positive. A ratio swap alone, with zero fees and zero added liquidity, does not satisfy that emission condition.

---

## 11. Idle balances, donations, native value, and token helpers

### PT-BAL-001 — Idle definition

For ERC-20 currencies, idle is the token’s current `balanceOf(vault)`.

For native currency, idle is:

```text
vaultNativeBalance - reservedNative
```

The reservation is operation-scoped ordinary contract state, not a separate asset account.

### PT-BAL-002 — Donations and native receiver

The payable receiver shall accept native transfers without access control.

Direct native or ERC-20 transfers become idle vault property. They enter basket calculations, redemption allocations, and compounding; they are not excluded as donations.

### PT-BAL-003 — Native refunds

Only paired deposit has the explicit unused-native refund path. It refunds `msg.sender`, not the share recipient.

Zap deposit clears its reservation without an equivalent refund function. Redemption and compounding use the current native balance subject to reservation accounting.

### PT-BAL-004 — Vault token transfer helpers

Vault-initiated ERC-20 transfer and transferFrom helpers shall accept:

- a successful low-level call with no return data; or
- a successful call returning boolean `true`.

Call failure or returned `false` shall revert `TransferFailed`. Nonempty malformed return data may revert during decoding.

ERC-20 pulls shall measure the actual balance delta. No general fee-on-transfer-token safety guarantee follows from that measurement.

### PT-BAL-005 — Currency payout behavior

User redemption payouts use the V4 `Currency.transfer` semantics:

- native payout uses a call and propagates failure through the currency library;
- ERC-20 payout requires success with either no return data or boolean `true`.

These payout failures need not have the same error identity as the vault’s `TransferFailed` helper failures.

---

## 12. Manager callback, operations, and settlement

### PT-CB-001 — Unlock model

The vault shall call `poolManager.unlock` for each required operation. A single user action may cause several separate unlocks, such as Collect, Deploy, and Add.

A Deploy callback may itself contain a swap followed by liquidity addition. No single all-encompassing user-operation callback shall be assumed.

### PT-CB-002 — Callback admission

`unlockCallback` shall require `msg.sender == poolManager`; otherwise it reverts `NotPoolManager`.

It shall not require the non-reentrancy guard or an armed, single-use flag. It shall not bind caller, recipient, operation budget, or receiver through an additional admission structure.

Manager equality is the complete explicit callback gate established by the supplied source; this requirement makes no independent safety claim about that gate.

### PT-CB-003 — Callback encoding

The callback payload shall decode as an operation enum followed by operation-specific bytes.

| Value | Operation | Operation data | Result |
|---:|---|---|---|
| 0 | `None` | none | Unhandled; reverts `NotPoolManager` |
| 1 | `Add` | `uint128 liquidity` | Encoded `(used0,used1)` |
| 2 | `Remove` | `uint128 liquidity` | Encoded unsigned `(callerDelta0,callerDelta1)` |
| 3 | `Collect` | no meaningful data | Encoded unsigned `(callerDelta0,callerDelta1)` |
| 4 | `Deploy` | `(bool zeroForOne,uint256 swapAmount)` | Encoded deployment result |

Malformed ABI data shall revert through decoding. A decoded unhandled operation shall revert `NotPoolManager`.

The deployment result fields, in order, are:

| Field | Type |
|---|---|
| `used0` | `uint256` |
| `used1` | `uint256` |
| `swapOut` | `uint256` |
| `tickBefore` | `int24` |
| `tickAfter` | `int24` |
| `liquidityAdded` | `uint128` |

### PT-CB-004 — Modify-liquidity semantics

Add, Remove, and Collect shall call manager `modifyLiquidity` with:

- the stored key;
- stored full-range ticks;
- positive, negative, or zero liquidity delta respectively; and
- zero salt and empty hook data.

The manager returns caller delta and fees accrued separately. Caller delta is the value settled by the vault and may include principal, fees, and applicable hook effects.

### PT-CB-005 — Net-consumption return values

For each currency, the internal used or owed amount returned from an Add shall be:

```text
net_i = int256(feesAccrued_i) - int256(callerDelta_i)
used_i = net_i > 0 ? uint256(net_i) : 0
```

This mathematical definition shall be preserved rather than assuming the returned values always equal gross tokens pulled from the vault.

### PT-CB-006 — Delta settlement

For each signed caller or swap delta:

- a negative delta represents an amount the vault must settle;
- a positive delta represents an amount the vault takes to itself;
- zero causes no settlement action.

For negative native deltas, settlement shall send the required value with manager `settle`.

For negative ERC-20 deltas, the sequence shall be manager `sync`, vault transfer to the manager, then manager `settle`.

For positive deltas, the manager shall transfer the currency to the vault through `take`.

Manager unlock completion is expected to enforce no unsettled nonzero delta under the supplied interface. The concrete manager implementation is not part of this baseline.

### PT-CB-007 — Swap output and hook data

Swaps shall use empty hook data and exact-input negative `amountSpecified` semantics.

For zero-for-one, output is delta1; for one-for-zero, output is delta0. Positive output delta shall be converted to unsigned output; nonpositive output delta produces `swapOut = 0`.

No additional hook-domain restriction, dynamic-fee rejection, complete-fill check, or positive-output check shall be invented.

---

## 13. Events and emission order

### PT-EVENT-001 — Event definitions

| Event | Fields and indexing |
|---|---|
| `Transfer` | `address indexed from`, `address indexed to`, `uint256 value` |
| `Approval` | `address indexed owner`, `address indexed spender`, `uint256 value` |
| `Deposit` | `address indexed sender`, `address indexed to`, `uint256 amount0`, `uint256 amount1`, `uint256 shares` |
| `Redeem` | `address indexed sender`, `address indexed to`, `uint256 amount0`, `uint256 amount1`, `uint256 shares` |
| `Compounded` | `uint256 fees0`, `uint256 fees1`, `uint256 protocol0`, `uint256 protocol1`, `uint128 liquidityAdded`; no indexed fields |

### PT-EVENT-002 — PairToken event ordering

Subject to earlier reversion:

- approval emits `Approval` after updating allowance;
- share transfer emits `Transfer` after balance changes;
- genesis emits the dead-share mint `Transfer` before the recipient mint `Transfer`;
- paired and zap deposits emit `Deposit` after recipient minting;
- paired deposit refunds native before emitting `Deposit`;
- redemption emits the burn `Transfer` before payout and emits `Redeem` after payout;
- any `Compounded` event caused by entry or exit compounding precedes that route’s later mint/burn and lifecycle event;
- public compounding emits `Compounded` last when its emission condition holds.

Manager, hook, fee-manager, and token events are external dependency behavior and are not ordered by this requirement.

---

## 14. Errors and failure propagation

### PT-ERR-001 — Declared error predicates

| Error | Required predicate |
|---|---|
| `AlreadyInitialized` | Initialize while `initialized` |
| `NotFactory` | Declared but unused; no predicate shall be invented |
| `NotPoolManager` | Callback sender differs from manager; also used for a decoded unhandled callback op |
| `Reentrancy` | A guarded function is entered while the guard is active |
| `BadGenesis` | Zero-supply geometric quote `<= 1_000`; zero-supply paired deposit adds zero liquidity; zap has zero supply or either zero basket reserve |
| `MinShares` | Deposit/zap gross shares zero or below `minShares`; redemption with zero shares or zero supply |
| `MinOut` | Paired redemption below either minimum; chosen-leg aggregate output below `minOut` |
| `ZapTooLarge` | Zap input zero or above its pre-pull vault-basket cap |
| `ZapMovesPrice` | Absolute post-deployment tick movement exceeds factory maximum |
| `BadToken` | Zap input or chosen output is neither pool currency |
| `NativeMismatch` | Native/value rules in PT-DEP-001 or PT-ZAP-001 fail |
| `TransferFailed` | Vault token helper fails/returns false, or paired native refund fails |
| `ZeroAddress` | Zero manager at initialization, zero share/token recipient, or zero ERC-20 transfer recipient |

### PT-ERR-002 — Arithmetic and dependency failures

Checked overflow, underflow, invalid full-precision division, narrowing overflow, library errors, manager failures, token payout failures, and factory getter failures shall propagate unless a specific notify catch applies.

A revert shall roll back earlier state changes in the operation. Ordering a check after a burn, swap, or deployment shall not make its failure non-atomic.

### PT-ERR-003 — Limited best-effort boundary

Only the specified fee-manager notify paths are best-effort. The implementation shall not generalize that behavior to user token transfers, manager settlement, factory reads, or malformed approval return data.

---

## 15. Boundary behavior and unsupported assumptions

### PT-EDGE-001 — Zero and small values

- Zero-share or zero-supply redemption reverts `MinShares`.
- A positive burn whose retained payout rounds to zero shall still burn shares and may return zero if configured minima permit.
- Zero `liqOut` shall not independently revert.
- A paired deposit or zap with zero computed shares reverts `MinShares`.
- Zero-output and zero-supply redemption previews return `(0,0)`.
- Zero protocol carve causes no notify.
- A zero ratio swap does not necessarily prevent an add attempt.

### PT-EDGE-002 — Dust

Compounding requires at least one idle balance strictly greater than `1_000`. A selected leftover at most `1_000` produces zero proposed swap.

These thresholds do not exclude smaller balances from basket ownership, redemption, paired `_addAll`-style deployment, or direct donation accounting.

### PT-EDGE-003 — Extreme swaps and partial fills

Exact-input swaps use near-extreme price limits. Reaching a limit, incomplete input consumption, or zero output shall not trigger an additional vault-specific assertion beyond manager behavior, returned deltas, final minima, and the zap tick guard where applicable.

### PT-ABSENT-001 — Absent APIs and properties

The baseline has no:

- `getRate`;
- `redeemTarget`;
- `claimFees`;
- permanent target currency;
- personal fee index or reward debt;
- booked `U` ledger or 10⁹ conversion offset;
- factory-only initialization modifier;
- armed callback flag;
- multi-range position;
- complete-fill guarantee;
- universal deposit-refund guarantee; or
- guarantee that successful fee-manager notify consumed ERC-20 tokens.

---

## 16. Observable acceptance scenarios

These are behavioral acceptance criteria, not executable tests.

| ID | Scenario | Expected observable result |
|---|---|---|
| AC-01 | Initialize with nonzero manager and valid key | Factory equals first caller; key/name/symbol/poolId/full-range ticks initialize; repeat call reverts `AlreadyInitialized` |
| AC-02 | Initialize with zero manager | Reverts `ZeroAddress`; no successful initialization occurs |
| AC-03 | Inspect complete API | Exactly the 17 named functions, receiver, and 17 generated getters are present; no `getRate` or `claimFees` |
| AC-04 | Quote with two positive reserves and `S > 0` | Gross shares equal the smaller proportional quote; used amounts round up and are capped by offered amounts |
| AC-05 | Quote with exactly one zero reserve and `S > 0` | Only the nonempty reserve determines shares; empty-side used amount is zero |
| AC-06 | Quote with zero supply or two zero reserves | Quote is `floorSqrt(a0*a1)` using checked multiplication; both offered amounts are marked used |
| AC-07 | Genesis with gross quote `<= 1_000` | Reverts `BadGenesis` |
| AC-08 | Genesis with gross quote above `1_000` but zero added liquidity | Reverts `BadGenesis`; no net mint survives |
| AC-09 | Successful genesis with `minShares` between net and gross shares | Gross check passes; 1,000 shares go to `DEAD`; recipient receives gross minus 1,000 even though that is below `minShares` |
| AC-10 | Deposit with `S > 0` and both reserves zero | Geometric quote is used without another dead mint or genesis positive-liquidity check |
| AC-11 | ERC-20 paired deposit with actual receipt below quoted pull amount | Used amount becomes measured receipt; shares remain based on pre-pull quote and are not recomputed |
| AC-12 | Paired native deposit with unused native | Current input is excluded from incumbent basket checkpoint; unused native refunds to caller, not share recipient; refund failure reverts |
| AC-13 | Pulled ERC-20 exceeds liquidity that can be added | Excess remains idle and enters subsequent basket/compounding behavior; no universal refund occurs |
| AC-14 | Zap at, above, and below cap | Zero input or input above vault-basket cap reverts `ZapTooLarge`; input exactly at cap proceeds |
| AC-15 | Fee-on-transfer zap input | Swap amount is half of measured receipt, not half of nominal input |
| AC-16 | Zap deployment moves tick beyond configured maximum | Reverts `ZapMovesPrice` after deployment attempt; entire operation rolls back |
| AC-17 | Successful zap | Shares equal minimum of the two pre-zap basket proportional quotes using deployment returned used amounts; no dead mint occurs |
| AC-18 | Compound with gross fees and positive protocol rate | Returned fees remain gross; attempted carve uses floor fee-times-rate/BPS; remaining usable idle compounds without share mint |
| AC-19 | Native or ERC-20 notify failure | Caught notify failure reports zero carve and does not by itself block compounding; ERC-20 path attempts approval clearing after notify revert |
| AC-20 | Successful ERC-20 notify without token pull | Carve is still reported as successful amount; actual idle remains determined by real token balance |
| AC-21 | Ratio compounding with exact tie and dust boundaries | Token0 wins the valued-leftover tie; selected leftover `<= 1_000` gives zero swap but does not inherently suppress add |
| AC-22 | Ratio compounding above cap | Swap equals active-pool cap, not user-zap vault-basket cap; no user-zap tick-movement check applies |
| AC-23 | Ordinary redemption | Burn precedes removal; payout, liquidity, and idle amounts follow the separate rounding equations; 10 bps remains in vault property |
| AC-24 | Small positive redemption with zero rounded payout | Shares burn; zero payout may be returned when minima allow; no independent zero-liquidity rejection occurs |
| AC-25 | Chosen-leg redemption with incomplete or zero swap output | No independent complete-fill/positive-output assertion is added; final `minOut` still applies; event carries pre-swap pair amounts |
| AC-26 | Direct token donation followed by view/redemption | Donation enters idle and basket, affects quotes and redemption, and may later compound |
| AC-27 | Compare previews with execution | Deposit preview is pre-compound and gross at genesis; redeem preview uses total-basket rounding and does not simulate execution or chosen-leg sale |
| AC-28 | Finite and infinite allowance transferFrom | Finite allowance decreases or reverts on overspend; max allowance remains unchanged |
| AC-29 | Callback from non-manager and callback with unhandled op | Both revert `NotPoolManager`; manager-only callback does not require an armed flag |
| AC-30 | Add, Remove, Collect, and Deploy callbacks | Each follows its defined data/result encoding, salt/range, delta settlement, and return-value semantics |
| AC-31 | Guarded external action attempts guarded reentry | Reverts `Reentrancy`; callback and ordinary ERC-20 methods do not acquire the guard implicitly |
| AC-32 | Lifecycle event inspection | Mint/burn `Transfer`, `Deposit`, `Redeem`, and conditional `Compounded` appear in the specified relative order with exact payloads |

---

## 17. Dependency limits and planning relevance

### PT-DEPEND-001 — Settled facts versus unknowns

No unknown below prevents documenting the vault’s own source-equivalent behavior. Unknowns do prevent exact deployed end-to-end predictions and concrete integration certification until resolved.

| Topic | Settled by source | Unknown or not supplied | Planner treatment |
|---|---|---|---|
| Factory | Four getter calls and their call sites | Concrete implementation and live values | Preserve runtime reads; do not hardcode caps, fee rate, or manager |
| Fee manager | Notify signature, native value, approval/notify ordering | Whether notify pulls tokens or has side effects | Keep best-effort semantics; resolve actual integration before deployed validation |
| PoolManager | Unlock/modify/swap/settle/take interfaces and delta usage | Concrete manager/Pool engine | Use returned deltas; do not invent fill, fee, or failure guarantees |
| Hooks | Empty hook data is passed; caller delta may include hook effects | Configured hook implementation | Do not assume hook-free math or add a hook exclusion |
| Pool tokens | Low-level helper and balance-measurement behavior | Actual token contracts and nonstandard behavior | Preserve helper semantics; do not certify all fee-on-transfer or rebasing tokens |
| Deployment | Initializer and ordinary storage are observed; NatSpec describes clone use | Factory implementation and deployed clone transaction/bytecode | Do not claim independent deployment verification |
| Chain state | Static contract behavior | Current supply, liquidity, balances, price, and factory settings | Acceptance algebra must remain parameterized |
| External error surface | Which calls are caught or propagated locally | Complete external error set | Propagate unless specifically caught; do not enumerate invented external errors |

### PT-DEPEND-002 — Provenance and workflow qualification

This document is source-informed. A different downstream agent does not by itself establish an unexposed workflow. Source SPDX markers, exact-match metadata, and document accuracy do not determine legal clearance.

The later planner should not need raw source to understand required vault behavior, but analyst-only provenance and traceability should remain separate from any approved planner-facing handoff.

---

## 18. Analyst-side source traceability and coverage

Baseline source: `src/pair/PairToken.sol` in the admitted 28-file bundle. Original HTTP body SHA-256: `ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98`. The archive’s separately recorded digest reflects one added terminal newline; removing that newline restores the fetched body exactly.

| Requirements | Original PairToken locator | Dependency locators / coverage |
|---|---|---|
| PT-SCOPE, PT-STATE | Contract model lines 35-44; public state/constants lines 47-74 | `PoolKey`, `PoolId`, `Currency` |
| PT-API-001/002/003 | State lines 47-74; declared functions throughout lines 133-574 | Full 17-function, receiver, and 17-getter inventory checked |
| PT-INIT | `initialize`, lines 138-152 | `TickMath.minUsableTick/maxUsableTick`; `PoolIdLibrary.toId` |
| PT-ERC20 | Lines 156-197 | Share events at lines 54-55 |
| PT-MATH | Share math lines 500-529; pool plumbing lines 576-642 | `FullMath`, `SqrtPriceMath`, `LiquidityAmounts`, `PriceMath`, `TickMath` |
| PT-VIEW | Pool getters and views, lines 201-250 | `StateLibrary.getSlot0/getPositionLiquidity`; position-key helper |
| PT-DEP | `deposit` and `_addAll`, lines 256-302; `_quoteShares`, lines 500-519 | Native/pull/refund helpers lines 646-679 |
| PT-ZAP | `zapDeposit`, lines 308-346; `_minShares`, lines 521-529 | Factory interface lines 21-27; deployment helpers lines 533-608 |
| PT-RED | `redeem`, `redeemZap`, `_redeemToSelf`, lines 351-406 | `_swapOnly`, `_deployInLock`, `_modify`, lines 538-626 |
| PT-FEE | `compound`, `_compound`, `_carve`, lines 412-466 | Embedded factory/fee-manager interfaces lines 21-31 |
| PT-COMP | `_ratioSwap`, lines 469-496; `_deployInLock`, lines 576-608 | Active liquidity and amount helpers in `StateLibrary`/`SqrtPriceMath` |
| PT-BAL | Idle/native/pull/refund/token helpers, lines 646-691; receiver line 133 | `Currency.transfer/balanceOfSelf`; `IERC20Minimal` |
| PT-CB | `_deploy`, `_swapOnly`, `_unlock`, callback and settlement, lines 533-642 | `IPoolManager`, `IUnlockCallback`, `BalanceDelta`, `IHooks` |
| PT-EVENT | Share events lines 54-55; lifecycle events lines 116-118 | Emission order traced through each public route |
| PT-ERR | Error declarations lines 102-114; modifiers lines 120-133 | Predicates traced through all calling functions and helpers |
| PT-EDGE/PT-ABSENT | Deposit, redemption, compounding, preview, and callback ranges above | Boundary conditions cross-checked against helper semantics |
| AC-01 through AC-32 | Derived from the corresponding requirement groups | Scenarios are analyst-defined observable criteria, not source quotations |

All 28 supplied files were read in the preceding source-exposed audit. The admitted final audit and its resolution were used as factual secondary checks. No current-run member original was read. This requirements extraction makes no runtime correctness, security, economic-safety, deployment, or legal-clearance claim.
