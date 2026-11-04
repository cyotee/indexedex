# Candidate functional requirements — PairToken

- Run: pairtoken-behavioral-requirements-20261027-01a17d57
- Member: grok
- Phase: initial independent response
- Continued source-exposed reviewer. This run's peers were not read.
- apply_patch: not usable. It is not in the active tool set. It was not retried, and no write or edit workaround was used. This message is the archival body.
- Earlier audit artifacts were not modified.
- Origin: source-informed extraction from the admitted verified bundle and the settled fidelity audit. SPDX markers are observations only. This document does not clear a license, certify an unexposed workflow, or authorize implementation.
- IndexedEx adaptations (Crane deployment, a product `getRate`, policy changes) are future decisions. They are not requirements of this baseline.

A later planner should be able to use sections 1 through 20 without opening raw source. Section 21 is analyst traceability and is not planner-facing material.

## 1. Purpose and scope

PT-001. The subject is one contract that is a freely transferable 18-decimal ERC-20 and, at the same time, the direct owner of one Uniswap v4 position. There is no position NFT and no second claim token.

PT-002. The position is one pool key, one full usable tick range derived from that key's tick spacing, and salt zero. The contract does not create the pool, does not change the key, the ticks, or the salt after initialization, and does not hold a second range.

PT-003. Shares are a pro-rata claim on a basket: the position's token amounts at the live square-root price, rounded down, plus the contract's idle balances of the two pool currencies. Uncollected pool fees are not in the basket until a compound collects them. There is no personal fee escrow, no per-account fee index, and no `getRate`.

PT-004. Trading fees that this contract collects are a collective asset. A protocol fraction may be offered to a factory-configured fee manager. The remainder is redeployed into the same position when idle balances are large enough. Compounding does not mint shares.

PT-005. Entry is either a paired deposit or a single-currency zap. Exit is either a paired redemption or a caller-chosen single-currency redemption. Both exits burn the caller's shares and retain 10 basis points of the burned claim inside the vault.

PT-006. This baseline specifies observable behavior, including quirks. It does not repair them. A conforming implementation reproduces the quirk. A product change that removes a quirk is a future decision and must be labeled as one.

PT-007. Reverts roll the whole call back. No requirement below describes a partial commit after a revert.

## 2. Units, constants, and state

PT-010. Share amounts use 18 decimals. One whole share is `10^18`. Underlying currency amounts are raw units of that currency. Nothing in the share, dust, retention, or zap math rescales by the underlying token's decimals.

PT-011. Integer division is floor unless a requirement says ceiling. Ceiling of `a*b/d` is floor plus one when `d` does not divide `a*b`, and reverts if the ceiling would overflow. Floor multiplication-division reverts if the mathematical floor does not fit in 256 bits or the divisor is zero. Products and subtractions that are not explicitly wrapped use checked 256-bit arithmetic and revert on overflow or underflow.

PT-012. Constants, all immutable:

| Name | Value | Role |
| --- | --- | --- |
| `BPS` | 10000 | Denominator for retention, protocol fee, and zap caps |
| `DEAD_SHARES` | 1000 | Shares minted to the dead address at genesis |
| `RETENTION_BPS` | 10 | Share-claim retained on every burn redemption |
| `DUST` | 1000 | Raw-unit idle threshold, not 1000 whole tokens |
| `DEAD` | `0x000000000000000000000000000000000000dEaD` | Genesis share recipient |
| `decimals` | 18 | ERC-20 decimals |

PT-013. Tick bounds used to derive the range are `MIN_TICK = -887272` and `MAX_TICK = 887272`. For a positive tick spacing `t`, the stored lower tick is `(MIN_TICK / t) * t` and the stored upper tick is `(MAX_TICK / t) * t`, using checked integer division. Spacing zero reverts at initialization. These ticks are not caller arguments.

PT-014. Square-root price bounds used as swap limits are the admitted tick-math minimum and maximum. Exact values: minimum `4295128739`, maximum `1461446703485210103287273052203988822378723970342`. A downward swap limit is one unit above the minimum. An upward swap limit is one unit below the maximum. The fixed-point scale `Q96` is `2^96`.

PT-015. Persistent public state: name, symbol, decimals, total supply, balances, allowances, factory, pool manager, pool id, lower tick, upper tick, initialized flag, and the constants above. The pool key is persistent and readable through `poolKey`. It is not a separate public variable.

PT-016. Three ordinary state variables are operation-scoped, not a second public ledger. A native reservation excludes in-flight native value from idle. An entered flag is zero outside an active guarded call and one during it. A skip-add flag is false except during a chosen-leg redemption swap. None of these is a transient-opcode claim. After a successful call they are back to zero or false. A revert restores the pre-call values.

PT-017. There is no stored liquidity ledger, no stored fee index, no stored target currency, and no stored snapshot of factory parameters. Position liquidity is reread from the manager on each use. Factory parameters are reread on each use.

## 3. Public surface

PT-020. Seventeen named public or external functions, one unrestricted receiver, and seventeen generated getters. No other external function is part of this baseline.

| Symbol | Kind | Payable | Guard | Returns |
| --- | --- | --- | --- | --- |
| `initialize` | external | no | one-shot | none |
| `approve` | external | no | none | `true` |
| `transfer` | external | no | none | `true` |
| `transferFrom` | external | no | none | `true` |
| `poolKey` | external view | no | none | stored pool key |
| `token0` | public view | no | none | currency0 address |
| `token1` | public view | no | none | currency1 address |
| `positionLiquidity` | public view | no | none | `uint128` manager read |
| `basket` | public view | no | none | `(reserve0, reserve1)` |
| `previewDeposit` | public view | no | none | `(shares, used0, used1)` |
| `previewRedeem` | external view | no | none | `(amount0, amount1)` |
| `deposit` | external | yes | entered-flag | net shares minted to `to` |
| `zapDeposit` | external | yes | entered-flag | shares minted to `to` |
| `redeem` | external | no | entered-flag | `(amount0, amount1)` paid |
| `redeemZap` | external | no | entered-flag | single-currency `out` paid |
| `compound` | external | no | entered-flag | `(fees0, fees1)` collected, before protocol carve |
| `unlockCallback` | external | no | manager equality only | operation-specific bytes |
| `receive` | external payable | yes | none | none |

PT-021. Generated getters, in addition to the view functions above: `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `allowance`, `factory`, `poolManager`, `poolId`, `tickLower`, `tickUpper`, `initialized`, `BPS`, `DEAD_SHARES`, `RETENTION_BPS`, `DUST`, `DEAD`. They return the stored or constant value and do not change state.

PT-022. Caller and recipient rules:

- Initialization: any caller, once. That caller becomes `factory`.
- Paired deposit and zap: pull currency from `msg.sender`; mint shares to `to`; native refund, if any, goes to `msg.sender`, not to `to`.
- Both redemptions: burn `msg.sender`; pay `to`.
- `transfer` moves `msg.sender`'s shares. `transferFrom` moves `from`'s shares using `msg.sender`'s allowance.
- `compound` is permissionless.
- `unlockCallback` reverts unless `msg.sender` is the stored pool manager. It does not check the entered flag, an armed budget, or the original user.

PT-023. The entered-flag guard is on `deposit`, `zapDeposit`, `redeem`, `redeemZap`, and `compound` only. If the flag is already nonzero, those revert `Reentrancy`. The flag is one for the body and zero after success. `approve`, `transfer`, `transferFrom`, `initialize`, `unlockCallback`, and `receive` do not use that guard.

## 4. Share-quote algebra

PT-030. Let `S` be total supply and `(r0, r1)` the basket at the quote checkpoint. Inputs are raw amounts `a0` and `a1`.

PT-031. Opening branch. If `S = 0` or both reserves are zero:

- Shares are the greatest integer whose square does not exceed `a0 * a1`. The product uses checked multiplication and reverts if it exceeds `2^256 - 1`. A zero product yields zero shares.
- Both input amounts are the used amounts. There is no proportional refund in this branch.
- If `S = 0` and shares are less than or equal to 1000, the quote reverts `BadGenesis`. If `S` is nonzero, that 1000-share floor does not apply, even when both reserves are zero.

PT-032. Single-reserve branch. If the opening branch does not apply and exactly one reserve is zero:

- If `r0 = 0`, shares are `floor(a1 * S / r1)`, used0 is 0, and used1 is `a1`.
- If `r1 = 0`, shares are `floor(a0 * S / r0)`, used1 is 0, and used0 is `a0`.
- The empty side is not pulled.

PT-033. Two-sided branch. If both reserves are nonzero and the opening branch does not apply:

- `s0 = floor(a0 * S / r0)` and `s1 = floor(a1 * S / r1)`.
- Gross shares are the minimum of `s0` and `s1`.
- Used amounts are `min(ai, ceil(grossShares * ri / S))` on each side.

PT-034. Zap mint basis, used only after a successful zap deploy, against the pre-zap basket and pre-zap supply, both nonzero:

- Shares are `min(floor(used0 * S / r0), floor(used1 * S / r1))`.
- This is not the two-sided used-amount ceiling rule. The used amounts are the deploy's consumed amounts, defined in PT-076, not the caller's nominal input.

PT-035. No quote uses liquidity units, a decimal offset, a virtual share supply, a virtual liquidity unit, a square-root price in the denominator, or a fee balance. The live price affects a quote only by changing the basket reserves or, for a zap, the consumed amounts.

## 5. Basket, position read, and previews

PT-040. Position identity is this contract, the stored full usable ticks, and salt zero. `positionLiquidity` is the manager's liquidity word for that identity. It is zero when the manager reports none. This contract does not cache it.

PT-041. `basket` reads the manager's current square-root price and ignores the manager's protocol-fee and LP-fee fields. If position liquidity is zero, both position amounts are zero. Otherwise:

- Reserve0 starts as the round-down currency0 amount of that liquidity between the current square-root price and the upper tick.
- Reserve1 starts as the round-down currency1 amount of that liquidity between the lower tick and the current square-root price.
- Each reserve then adds idle of that currency.

PT-042. Idle of a currency is the contract's balance of that currency. For the native currency, subtract the current native reservation. The subtraction is checked. A reservation larger than the native balance reverts. ERC-20 idle is not reduced by the reservation.

PT-043. `previewDeposit(a0, a1)` returns the quote of PT-031 through PT-033 against the current basket and current supply. It does not compound, does not move tokens, and does not subtract genesis dead shares. Its notice that pending fees are excluded is a requirement: uncollected fees are absent from the basket until a later compound.

PT-044. `previewRedeem(shares)` returns `(0, 0)` if supply is zero or shares are zero. It does not revert on those inputs. Otherwise let `payout = floor(shares * 9990 / 10000)`. It returns `floor(r_i * payout / S)` for each current basket reserve. It does not simulate a liquidity removal, a swap, a compound, or the caller's balance. It does not check that the caller holds the shares.

PT-045. Preview and execution are not required to match. Execution of deposit, zap, and both redemptions compounds first. Redemption execution also splits position liquidity and idle before flooring, instead of flooring a share of the summed basket. Pending fees, a compound swap, and that split are sufficient reasons for inequality. A conformance plan must not treat preview equality as an invariant.

## 6. Initialization

PT-050. `initialize(manager, key, name_, symbol_)` reverts `AlreadyInitialized` if the flag is already true, and `ZeroAddress` if the manager is the zero address. Otherwise it sets the flag, stores the caller as `factory`, stores the manager and the key as passed, stores the pool id as the standard 5-field key hash, sets the ticks by PT-013, and stores the name and symbol.

PT-051. The first successful caller is the factory even if that caller is not a contract and even if it does not implement the factory views. `NotFactory` is a declared error and is never raised by this contract. A conforming implementation does not add a factory check that raises it.

PT-052. Initialization does not sort currencies, reject a nonzero hook, initialize the pool, set a target currency, or snapshot factory parameters. An unordered key is stored. Later manager calls may revert. That revert is a dependency outcome, not a local sort requirement.

PT-053. Name and symbol may be empty. No event is emitted. The function is not payable. A second call reverts even if the arguments match.

PT-054. Clone deployment is described by the contract's own notice as an EIP-1167 clone created by a factory. The factory implementation and the deployed creation bytecode are not in the admitted evidence. The notice is not a verified deployment trace. The behavioral requirements are the initializer and the stored identity above. A planner must not treat clone mechanics as settled beyond that notice.

## 7. ERC-20 shares

PT-060. `approve(spender, amount)` sets the caller's allowance for that spender to `amount`, emits `Approval`, and returns true. It overwrites. It does not increase or decrease relative to the old value.

PT-061. `transfer(to, amount)` moves `amount` from the caller to `to` and returns true. `transferFrom(from, to, amount)` does the same from `from`, after allowance handling, and returns true.

PT-062. `transferFrom` reads the allowance of `from` for the caller. If it is the maximum 256-bit word, the allowance is left unchanged. Otherwise it is decreased by `amount`, with checked subtraction. An insufficient finite allowance reverts by underflow, not by a named error.

PT-063. A transfer reverts `ZeroAddress` if `to` is zero. It reverts by underflow if `from` lacks the shares. It does not compound, does not read the manager, and does not change total supply, position liquidity, or idle ownership of currencies. The recipient receives the share claim on the collective basket, not a crystallized fee balance. There is no fee balance to crystallize.

PT-064. Mint increases total supply and the recipient balance, and emits `Transfer` from the zero address. Burn decreases the holder's balance and total supply, and emits `Transfer` to the zero address. Both use checked supply updates. These are internal. External callers mint only through deposit or zap, and burn only through the two redemptions, which burn `msg.sender`.

PT-065. Dead shares are ordinary balances at `DEAD`. They remain in total supply. They dilute later quotes and redemptions. They can be burned only if that address calls a redemption. This baseline does not add a block on that call and does not sweep those shares.

## 8. Paired deposit

PT-070. `deposit(amount0, amount1, minShares, to)` is payable and guarded. Order is mandatory.

1. Revert `ZeroAddress` if `to` is zero.
2. Apply the native-value rule in PT-120 to `amount0`.
3. Set the native reservation to `msg.value`.
4. Compound, with all of section 10.
5. Read basket and supply. Quote PT-031 through PT-033. This checkpoint is after compound and before the pull.
6. Revert `MinShares` if quoted shares are zero or strictly less than `minShares`. This check uses gross shares, before any genesis deduction.
7. Pull the quoted used amounts from the caller. Replace the used amounts with the pull results. ERC-20 results may be smaller than the quote. Shares are not recomputed.
8. If currency0 is native, set the reservation to `msg.value` minus the native used amount. Otherwise set the reservation to zero.
9. Add as much current idle as fits the full range at the current price. The added liquidity may be zero. Non-genesis does not revert on zero added liquidity.
10. If the supply captured in step 5 was zero: revert `BadGenesis` if added liquidity is zero; mint 1000 shares to `DEAD`; subtract 1000 from the quoted shares. The subtraction is safe only because step 5's quote already rejected a genesis result of 1000 or less. Do not move the `minShares` check to after this subtraction. That would repair a quirk.
11. Mint the resulting shares to `to`.
12. Refund any remaining native reservation to `msg.sender`. A failed refund reverts `TransferFailed`. Clear the reservation.
13. Emit `Deposit` with the caller, `to`, the post-pull used amounts, and the shares actually minted to `to`.

PT-071. Excess ERC-20 is never pulled, so it is not refunded. Value that is pulled and does not become liquidity stays idle and later belongs to the basket. It is not a caller refund and not a fee. Native excess is the only refund, and it goes to the caller.

PT-072. A genesis event reports net recipient shares, not the geometric mean. The 1000 dead shares appear only as a `Transfer` to `DEAD` before that event.

## 9. Zap deposit

PT-080. `zapDeposit(tokenIn, amountIn, minShares, to)` is payable and guarded. It is a required entrypoint, not an optional extension.

1. Revert `ZeroAddress` if `to` is zero.
2. If `tokenIn` is currency0, direction is currency0 to currency1. If it is currency1, direction is the opposite. Any other token reverts `BadToken`.
3. Native value is allowed only when direction is currency0-to-currency1 and currency0 is native, and then `msg.value` must equal `amountIn`. Every other case requires `msg.value` to be zero. Otherwise `NativeMismatch`.
4. Set the native reservation to `msg.value`, then compound.
5. Read the post-compound basket and supply. Revert `BadGenesis` if supply is zero or either reserve is zero. Zap cannot be genesis and cannot be the single-reserve quote.
6. Let `reserveIn` be the basket reserve of the input currency. Revert `ZapTooLarge` if `amountIn` is zero or `amountIn > floor(reserveIn * maxZapBps / 10000)`. `maxZapBps` is read live from the factory. It is not clamped to 10000. The reserve is the vault basket, not the pool's active liquidity.
7. Pull `amountIn`. Then set the native reservation to zero. There is no native refund on this path. The pulled native value is idle and eligible to be deployed.
8. Swap `floor(amountIn / 2)` in the input direction and then add fitting idle, in one manager unlock. Consumed amounts, swap output, ticks, and added liquidity are the deploy result defined in PT-076.
9. Let moved be the absolute tick difference between the post-swap tick and the pre-swap tick, using checked 24-bit subtraction. Revert `ZapMovesPrice` if moved is strictly greater than the live `maxZapTickMove`. An equal move is allowed. This check is after the deploy in the call order and still reverts the whole call if it fails.
10. Mint PT-034 shares against the pre-zap basket and pre-zap supply, using the deploy's consumed amounts. Revert `MinShares` if that result is zero or strictly less than `minShares`.
11. Emit `Deposit` with the caller, `to`, the consumed amounts, and the minted shares.

PT-081. The zap does not mint dead shares. It does not use the paired-deposit ceiling rule. Its consumed amounts can include idle that was already in the contract, because the deploy adds all fitting idle, and can include fees collected in the same liquidity change, because consumed amounts are the net figure in PT-076. Shares are still priced on the pre-zap basket, which already included that idle. This is required accounting, not a defect to close.

PT-082. A zap has no tick check on the compound that ran in step 4. Only the zap's own deploy is tick-bounded.

## 10. Compound, protocol routing, and ratio swap

PT-090. `compound()` is permissionless, guarded, and returns the collected fee pair from the same procedure that deposit, zap, and both redemptions run first. Those callers do not emit their own compound event. The procedure emits at most one `Compounded`.

PT-091. Collection. If position liquidity is zero, collected fees are zero and no collect unlock occurs. Otherwise one unlock pokes the position with a zero liquidity change and decodes the two collected amounts as the unsigned reinterpretation of the caller deltas, PT-111. Those amounts are the collected fees. They are not the separate fee-accrued return, and they are not reduced by the protocol carve before the return value is fixed.

PT-092. Protocol offer. Only if at least one collected amount is nonzero, read `feeManager` and `protocolFeeBps` live. If the manager is nonzero and the bps value is nonzero, the offered amount on each side is `floor(collected_i * protocolFeeBps / 10000)`. Otherwise both offered amounts are zero. A reverting factory view reverts the user call. The bps value is not clamped. An offer larger than the balance is still attempted and follows PT-093.

PT-093. `notify` delivery is best-effort for the notification call only.

- A zero offer delivers nothing and contributes zero to the event.
- Native delivery calls `notify` with that value. If the call reverts, delivery is zero and the native tokens stay.
- ERC-20 delivery first attempts `approve` of the offer to the fee manager. If that attempt fails, delivery is zero and `notify` is not called.
- If approve succeeds, `notify` is called without value. If that call succeeds, delivery is the offered amount. Success does not prove the manager pulled tokens, and it does not prove the approval was cleared.
- If `notify` reverts, attempt to set the approval back to zero. Whether that second approve succeeds or fails, delivery is zero and the tokens stay. A failed reset does not revert the user call.

PT-094. Idle redeploy. If either idle balance is strictly greater than 1000 raw units, compute a ratio swap and run one deploy. Otherwise do not deploy in this procedure. The 1000 comparison is per currency, unscaled.

PT-095. Ratio-swap size.

- Let `L` be the full-range liquidity the current idle balances can fund at the current price, using PT-142. Let the needed amounts be the round-up token amounts of that liquidity on each side. Leftover on a side is idle minus needed when idle is greater, else zero.
- Value the currency0 leftover in currency1 units by two successive floors: `floor(floor(left0 * sqrtP / 2^96) * sqrtP / 2^96)`.
- If that value is greater than or equal to the currency1 leftover, currency0 wins the tie. If its leftover is less than or equal to 1000, the swap amount is zero. Otherwise the swap amount is half that leftover, rounded down, and the direction is currency0 to currency1.
- Otherwise the same rule applies to the currency1 leftover, in the opposite direction.
- If the manager reports zero active pool liquidity, the swap amount becomes zero. This pool liquidity is not the vault's position liquidity.
- Otherwise the cap reserve is the round-down amount of that active liquidity from the current price to the far side of the input currency's range. The cap is `floor(floor(capReserve * maxZapBps / 10000) / 4)`. If the proposed swap exceeds the cap, clip it to the cap. Do not revert for size.
- `maxZapBps` is read live here. A reverting read reverts the user call.

PT-096. The ratio deploy swaps the clipped amount, then adds fitting idle at the post-swap price. It does not apply `ZapMovesPrice`. A zero swap still attempts the add. Added liquidity may be zero.

PT-097. Emit `Compounded(collected0, collected1, delivered0, delivered1, added)` if either collected amount is nonzero or added liquidity is nonzero. Delivered amounts are PT-093 results, which may be zero even when an offer was computed. Do not emit when all five fields are zero.

PT-098. Compounding may increase position liquidity without minting shares. That increase is the collective property of the existing supply, including dead shares. It is not a personal claim and not a donation category that must be excluded.

## 11. Paired redemption

PT-100. `redeem(shares, min0, min1, to)` is guarded and not payable. Order:

1. Revert `ZeroAddress` if `to` is zero.
2. Compound.
3. Run the burn payout of PT-101.
4. Revert `MinOut` if currency0 paid is strictly less than `min0` or currency1 paid is strictly less than `min1`. The minima are independent. A zero minimum accepts a zero payout.
5. Transfer each nonzero currency amount to `to`. A zero amount is not transferred. Failure reverts the call through the currency-transfer rule in PT-132.
6. Emit `Redeem` with the caller, `to`, the two paid amounts, and the burned shares.

PT-101. Burn payout, shared with chosen-leg redemption.

- Revert `MinShares` if shares are zero or supply is zero.
- Measure both idle balances, then burn `shares` from `msg.sender`. Supply in the denominator is the pre-burn supply. Idle in the numerator is the pre-burn idle.
- `payout = floor(shares * 9990 / 10000)`.
- Liquidity removed is the low 128 bits of `floor(positionLiquidity * payout / preBurnSupply)`. If that floor exceeds `2^128 - 1`, the conversion keeps the low 128 bits. It is not specified as a reverting cast. Reachability of that truncation is not established.
- If the resulting liquidity is nonzero, remove it in one unlock and take the unsigned reinterpretation of the removal caller deltas, PT-111. If it is zero, both removal amounts are zero. Zero removed liquidity is not its own revert.
- Each paid amount is the removal amount plus `floor(preBurnIdle_i * payout / preBurnSupply)`.

PT-102. One share has payout zero, because `floor(9990 / 10000) = 0`. With both minima zero, the burn is required to succeed and pay nothing. Do not add a revert that repairs this.

PT-103. Retention stays in the position and in idle for the remaining supply, including dead shares. It is not a separate fee token and not a payment to the factory. There is no in-kind disable and no configured target. Both currencies are the redemption property.

## 12. Chosen-leg redemption

PT-110. `redeemZap(shares, tokenOut, minOut, to)` is guarded and not payable.

1. Revert `ZeroAddress` if `to` is zero.
2. `tokenOut` must be currency0 or currency1. Otherwise `BadToken`. The choice is per call. There is no stored target.
3. Compound, then run PT-101. The two amounts are the pre-swap redeemed amounts.
4. The unwanted amount is the other currency. If it is nonzero, swap that entire amount toward `tokenOut`, with redeploy disabled. The swap does not check zap size or tick movement.
5. `out` is the wanted pre-swap amount plus the positive swap output. Revert `MinOut` if `out` is strictly less than `minOut`.
6. Transfer `out` of `tokenOut` to `to` if a transfer of a zero out is not required; a zero out still reaches the minimum check. A nonzero out is transferred.
7. Emit `Redeem` with the pre-swap pair amounts and the burned shares, not with `out`.

PT-111. Unsigned delta encoding. Where a requirement says the unsigned reinterpretation of a caller delta, take each signed 128-bit leg and reinterpret those same bits as an unsigned 128-bit value, then widen to 256 bits. A negative leg becomes `2^128 + leg`. This is required encoding, not a proved reachable failure and not an exploit finding. Do not replace it with a revert-on-negative rule.

PT-112. The swap requests exact input of the stated amount. The price limit is one unit inside the downward bound if currency0 is sold, and one unit inside the upward bound if currency1 is sold. Hook data is empty. Output is the positive received delta on the other currency after the same unsigned widening, or zero if that delta is not positive. The contract does not require the input to be fully consumed and does not require nonzero output. Unconsumed input stays in the contract. It is not paid as the wanted currency and not refunded to the caller.

## 13. Callback, unlocks, and settlement

PT-120. Native value. Currency0 is the only currency that may be native, and only when its address is zero. For a paired deposit, `msg.value` must equal `amount0` if currency0 is native, and must be zero otherwise. For a zap, PT-080 step 3 applies. `redeem`, `redeemZap`, `compound`, and `initialize` are not payable. `receive` accepts native from any caller, including the manager.

PT-121. A guarded user action may perform more than one manager unlock. Compound can unlock to collect and again to deploy. A paired deposit can then unlock again to add. A paired redemption can unlock again to remove. A chosen-leg redemption can unlock again to swap. These are separate unlocks, not one enclosing callback. Each unlock must be settled before it returns, using PT-123. The admitted manager interface defines `CurrencyNotSettled` for a nonzero leftover delta. Whether a particular manager raises it is a dependency. This contract's own settlement rule is PT-123.

PT-122. `unlockCallback` accepts only the stored manager. It interprets the echoed payload as an operation tag plus a payload. Tags are add, remove, collect, and deploy. Any other tag reverts `NotPoolManager`. There is no armed flag, no bound caller, no bound recipient, and no amount budget. The entered flag does not guard this function. A manager call that reaches it while a guarded user call is active will see the entered flag set, so a reentering call to a guarded function reverts `Reentrancy`. A direct manager call while the flag is clear is not rejected by that flag. Sufficiency of the manager check is not established. The requirement is the check that exists, not an added flag.

PT-123. Settlement of one signed currency delta:

- Zero does nothing.
- Negative means the contract owes the manager. The owed amount is the absolute value, with checked negation. Native pays that value to `settle`. Any other currency syncs, transfers the amount to the manager with the local ERC-20 helper, then calls `settle`.
- Positive means the manager owes the contract. Take that unsigned amount to this contract.

PT-124. Liquidity changes use the stored ticks, the requested signed liquidity delta, salt zero, and empty hook data. After settlement, the consumed amount on a side is the greater of zero and the signed fee-accrued leg minus the signed caller-delta leg. Add results report those consumed amounts. Collect and remove results report PT-111 encodings of the caller deltas, not the fee-accrued return and not the consumed-amount figure. The caller delta may include principal, fees, and hook effects. The admitted interface allows a hook to change a swap delta. This contract accepts the returned deltas. It does not require a zero hook.

PT-125. Deploy inside an unlock. Record the tick before. If the swap amount is nonzero, perform PT-112's swap shape for that amount and direction, settle both swap deltas, and record the post-swap tick and the positive output. If the skip-add flag is set, stop. Otherwise add the full-range liquidity that current idle can fund at the post-swap price, when that liquidity is nonzero, and record the consumed amounts and the liquidity added. Redeem-zap swaps set the skip-add flag for that unlock only, so redeemed balances are not put back into the position.

PT-126. Hook data on every swap and liquidity change originated by this contract is empty. The contract does not inspect hook address bits and does not revert because a hook is nonzero.

## 14. Idle, donations, and token movement

PT-130. A direct transfer of either pool currency to this contract increases idle and therefore the next basket, deposit quote, and redemption payout. Native can arrive through `receive` or through a manager `take`. The contract never calls the manager's donate function. It does not classify inbound tokens as excluded donations, fee escrow, or non-share property. A third-party donation on the manager, if the manager later reports it as a caller delta on a poke, is collected by PT-091 and then follows the compound rules. This baseline does not claim that every manager donation becomes a caller delta. That accounting belongs to the absent manager implementation.

PT-131. Pull. A zero amount pulls nothing. Native pull returns the requested amount and does not transfer. ERC-20 pull measures the contract balance, calls `transferFrom` of the requested amount from the caller to the contract, and returns the balance increase. A balance decrease reverts by checked subtraction. The paired-deposit share count is not recomputed from the returned amount. Measured receipt is not a general fee-on-transfer safety guarantee.

PT-132. Two transfer helpers, with different success rules.

- Payout of a redemption uses the currency helper. Native payout is a value call. ERC-20 payout is `transfer`. Success for ERC-20 is a successful call whose return data is empty, or whose return data is longer than 31 bytes and decodes as the word one. Failure reverts the redemption. The helper's wrapped errors are `NativeTransferFailed` and `ERC20TransferFailed`. The exact bubbled payload around those errors is a library detail. The planner-facing requirement is that the redemption reverts and does not emit `Redeem` if the payout fails.
- Manager settlement and the pull use the local helper. A call fails if it reverts, or if it returns nonempty data that does not decode as true. Empty return data is success. Failure of a settlement transfer reverts `TransferFailed`. Failure of a pull transfer reverts `TransferFailed`. The approve attempt used before `notify` uses the same local call shape but returns false instead of reverting, so a failed approve does not by itself revert the user call.

PT-133. Native refund on paired deposit sends the remaining reservation to `msg.sender` and reverts `TransferFailed` if that call fails. Zap does not refund.

## 15. Events and errors

PT-140. Events and index order:

| Event | Indexed | Fields, in order | When |
| --- | --- | --- | --- |
| `Transfer` | from, to | value | mint, burn, transfer |
| `Approval` | owner, spender | value | approve |
| `Deposit` | sender, to | amount0, amount1, shares | after a successful paired deposit or zap |
| `Redeem` | sender, to | amount0, amount1, shares | after a successful paired or chosen-leg redemption |
| `Compounded` | none | fees0, fees1, protocol0, protocol1, liquidityAdded | end of compound when any collected fee or added liquidity is nonzero |

PT-141. Emission order inside a successful call follows the state changes. Mints and burns emit `Transfer` when they happen. `Compounded`, if any, is emitted during the leading compound, before the user mint or burn. Token payouts happen before `Redeem`. `Deposit` is last in a deposit or zap. Chosen-leg `Redeem` carries the pre-swap pair amounts.

PT-142. Named errors and the conditions that raise them. Paths that do not raise an error are part of the requirement.

| Error | Raised when |
| --- | --- |
| `AlreadyInitialized` | second `initialize` |
| `ZeroAddress` | zero manager, or zero `to` on deposit, zap, or either redemption, or zero transfer recipient |
| `NativeMismatch` | native-value rule fails |
| `Reentrancy` | guarded function entered while the flag is set |
| `BadGenesis` | opening quote at zero supply is 1000 or less; genesis add is zero; zap before supply and both reserves are positive |
| `MinShares` | deposit or zap shares fail the minimum, including a zero quote; redemption shares or supply is zero |
| `MinOut` | a redemption minimum fails |
| `BadToken` | zap input or chosen-leg output is not one of the two currencies |
| `ZapTooLarge` | zap input is zero or above the basket cap |
| `ZapMovesPrice` | zap tick movement is strictly greater than the live limit |
| `NotPoolManager` | callback sender is not the stored manager, or the operation tag is not one of the four known tags |
| `TransferFailed` | local transfer or native refund fails |
| `NotFactory` | never raised by this contract |

PT-143. Other failures propagate. Checked arithmetic panics on overflow or underflow, including insufficient balance or finite allowance. The floor and ceiling helpers revert on a zero divisor or a result that does not fit. The liquidity helper reverts its overflow error if a computed liquidity does not fit in 128 bits. A zero square-root price in a round-down currency0 amount reverts the price helper's invalid-price error. Manager and token failures propagate except where PT-093 catches `notify`. Factory view failures are not caught. This list does not invent a manager revert that the admitted interface does not name. Named manager errors that may propagate, if the manager raises them, include `PoolNotInitialized`, `ManagerLocked`, `AlreadyUnlocked`, and `CurrencyNotSettled`. They are dependency outcomes.

## 16. Helper semantic contracts

PT-150. Square-root price at a tick is the admitted tick-math map. This baseline uses it as that map. It does not restate the bit algorithm. Inputs outside the min and max ticks are rejected by that helper.

PT-151. Round-down currency0 amount between two prices is the liquidity-times-difference formula, ordered so the lower price is the divisor, floored twice as the admitted price helper specifies, and rejected if the lower price is zero. Round-up uses the ceiling form of that helper. Currency1 amount is liquidity times the absolute square-root-price difference, divided by `2^96`, floored, plus one on the round-up path when there is a remainder.

PT-152. Liquidity for amounts. Order the price bounds. If the current price is at or below the lower bound, use only the currency0 amount across the full bounds. If it is at or above the upper bound, use only the currency1 amount across the full bounds. Otherwise take the minimum of currency0 liquidity from the current price to the upper bound and currency1 liquidity from the lower bound to the current price. Each side is a floor division. The result must fit in 128 bits or the helper reverts. A zero amount on the only side in use yields zero liquidity.

PT-153. Opening share conversion is floor square root of the checked product. It is not a price, and it is not the pool's square-root price.

PT-154. Pool id is the 32-byte hash of the five-field key: currency0, currency1, fee, tick spacing, hooks. Position identity for reads and writes is the admitted position-key helper applied to this contract, the stored ticks, and salt zero.

PT-155. Slot0 and liquidity reads follow the admitted state-library meanings: square-root price in the low 160 bits, signed tick in the next 24, protocol fee in the next 24, LP fee in the next 24; active liquidity and position liquidity are the corresponding liquidity words. This contract uses the square-root price, the tick, the active liquidity, and the position liquidity. It does not use the protocol-fee or LP-fee fields in its own arithmetic. Swaps still pay whatever fee the manager charges. That fee is not computed locally.

## 17. Required quirks

These are requirements. A conformance plan that "fixes" one of them is not implementing this baseline.

PT-160. `minShares` is compared with gross genesis shares. The 1000-share deduction happens after that check. A caller can demand the gross amount and receive 1000 less.

PT-161. ERC-20 receipt is measured, and paired shares are not recomputed from the measurement. The event amount is the measured receipt. The minted shares follow the pre-pull quote, then the genesis deduction if any.

PT-162. The user-zap cap multiplies the vault basket reserve of the input currency by live `maxZapBps`. The compound cap multiplies a round-down reserve implied by active pool liquidity by live `maxZapBps`, then divides by four. They are not the same cap. Only the user zap has a tick-movement revert.

PT-163. Callback collection and removal amounts are same-width signed-to-unsigned reinterpretations. They are not saturated at zero and not proved to be negative in a reachable call.

PT-164. A positive share burn whose payout floors to zero is a successful burn when the minima allow zero. Chosen-leg and paired swaps do not require complete input consumption or positive output.

PT-165. The callback gate is manager equality plus a known operation tag. There is no armed flag.

PT-166. The first successful initializer is the factory. No later call corrects that.

PT-167. A successful fee-manager `notify` is not proof that ERC-20 was pulled or that approval was reset. A caught failure leaves the offered tokens idle and does not revert the user action.

PT-168. There is no `getRate`, no target-token redemption preview, and no hook-domain guard on a rate. Do not add one inside this baseline.

## 18. Absent behavior and future decisions

PT-170. Absent from this contract, and therefore not requirements: `getRate`, `claimFees`, `permit`, allowance increase or decrease helpers, pause, a rescue that excludes donations, a second range, a position NFT, a stored liquidity ledger, a personal fee index, a target currency, an armed callback, a factory-only initializer, and a share mint on compound.

PT-171. Future decisions, outside this baseline and not to be filled in from this text: Crane or diamond deployment, a product `getRate`, a single-target exit, fee escrow, a different retention, a zap removal, and any repair of section 17. If a later plan adopts one, it must label it as a change from this source baseline.

PT-172. EIP-1167 deployment, as stated in the contract notice, is not independently verified from creation bytecode in the admitted evidence. A planner may treat it as an unverified deployment comment. The initializer behavior in section 6 is the settled identity rule.

## 19. Dependency limits and planning blockers

Settled by the source:

- The formulas, order, errors, events, and quirks in sections 1 through 18.
- The helper meanings in section 16, as semantic contracts of the admitted libraries.
- The factory and fee-manager call shapes: `feeManager()`, `maxZapBps()`, `maxZapTickMove()`, `protocolFeeBps()`, and `notify(token, amount, poolId)`, with value only for the native offer.

Not settled, and must not be invented:

| Unknown | Why it blocks a numerical plan | What is still required |
| --- | --- | --- |
| Factory implementation | Live bps, tick limit, and fee-manager address are unknown | Call them at execution. Do not snapshot them in this baseline |
| Fee-manager implementation | Pull and failure behavior are unknown | PT-093. Success is not a pull proof |
| Pool manager implementation | Hook effects, donate accounting, and which named manager errors actually fire are unknown | Use returned deltas as specified. Do not add a hook ban |
| Hook and token implementations | Fee-on-transfer, callbacks, and hook delta changes are unknown | Measure ERC-20 receipt and do not re-quote. Accept returned deltas |
| Chain state and live parameters | Reserves, price, and factory settings are unknown | Requirements are functions of those reads, not of a guessed number |
| Deployed clone bytecode | Notice is not a trace | Do not add a bytecode requirement |

PT-180. No requirement here is a vulnerability finding. Manager-equality without an armed flag, the unsigned reinterpretation, the zero-payout burn, and the measured-receipt quirk are specified behavior. Their safety is not established and is not claimed.

PT-181. Source-informed origin is a fact. It is not legal clearance and not proof that a different agent is an unexposed implementer. A planner may use this document as the behavioral baseline. That use does not create a clean-room certification.

## 20. Acceptance scenarios

These are observable scenarios and expected algebra. They are not executable tests and not an implementation plan. Unless a scenario says otherwise, the call is the whole transaction and a named error means that error and no state change.

PT-A01. Genesis. Supply is zero, both currencies are ERC-20, and the product of the two amounts has floor square root 1001. `minShares` is 1001. The add produces nonzero liquidity. Result: 1000 shares at `DEAD`, 1 share at `to`, total supply 1001, `Deposit` shares equal 1, and `MinShares` does not fire. The same quote with floor square root 1000 reverts `BadGenesis` before a mint.

PT-A02. Genesis slippage quirk. The quote is 1500 and `minShares` is 1500. The recipient receives 500. The call succeeds. A requirement that checks `minShares` against the net mint is a change, not this baseline.

PT-A03. Two-sided quote. Nonzero supply, both reserves nonzero. Shares are the minimum of the two floored pro-rata values. Each used amount is the ceiling pro-rata amount, clamped to the offer. The side that does not bind is not fully pulled.

PT-A04. One reserve zero, supply nonzero, the other reserve nonzero. Only the nonzero side is pulled. Shares are that side's floored pro-rata value. The opening square-root branch does not run.

PT-A05. Both reserves zero, supply nonzero. The square-root branch runs, both amounts are used, and the 1000-share floor does not apply.

PT-A06. `previewDeposit` on a basket with uncollected fees returns the no-compound quote. A following `deposit` of the same amounts compounds first. The minted shares are not required to equal the preview. `previewRedeem` of zero shares or at zero supply returns `(0, 0)`. `redeem` of zero shares reverts `MinShares`.

PT-A07. `previewRedeem` of a positive share amount equals the retention payout applied to the current summed basket. A following `redeem` of that amount is not required to pay those preview amounts, because execution compounds and splits liquidity from idle before flooring.

PT-A08. Redeem 1 share with both minima zero. Payout is zero. The share is burned. No currency is transferred. `Redeem` is emitted with zero amounts. The same call with either minimum equal to 1 reverts `MinOut` and does not burn.

PT-A09. Zap before the first deposit, or when either basket reserve is zero, reverts `BadGenesis`. A positive zap whose input exceeds `floor(inputBasketReserve * maxZapBps / 10000)` reverts `ZapTooLarge` even if the same input would fit the compound cap. A zap whose tick movement equals `maxZapTickMove` succeeds. Movement one tick greater reverts `ZapMovesPrice`.

PT-A10. Compound with idle above 1000 and a proposed ratio swap above `floor(floor(poolImpliedReserve * maxZapBps / 10000) / 4)` clips the swap and does not revert. It does not use the vault basket as that cap and does not apply the zap tick guard. Active pool liquidity zero forces a zero swap and still attempts the add.

PT-A11. Collected fees nonzero, fee manager nonzero, bps nonzero. If `notify` reverts, the user call succeeds, the event's protocol field for that side is zero, and the tokens remain idle. If `notify` succeeds, the event records the offer, and the requirement does not demand that the manager's balance increased or that the approval is zero.

PT-A12. A direct ERC-20 transfer of a pool currency into the contract increases the next `basket` and can increase the next redemption payout. No share is minted for that transfer.

PT-A13. `transfer` of shares does not change total supply, position liquidity, or currency balances. A maximum allowance is unchanged by `transferFrom`. A finite allowance decreases by the transferred amount. Transfer to the zero address reverts `ZeroAddress`.

PT-A14. `unlockCallback` from any address other than the stored manager reverts `NotPoolManager`. A known tag from the manager is accepted without an armed flag. An unknown tag reverts `NotPoolManager`.

PT-A15. Chosen-leg redemption emits `Redeem` with the two pre-swap amounts. The recipient receives the wanted amount plus nonnegative swap output. If the swap output delta is not positive, output contributes zero and the call still succeeds when `minOut` is met. Unconsumed unwanted input is not paid out.

PT-A16. Paired deposit with native currency0 and `msg.value` not equal to `amount0` reverts `NativeMismatch` before compound. A nonzero `msg.value` when currency0 is not native does the same. Excess native on a successful paired deposit is refunded to the caller, not to `to`.

PT-A17. An ERC-20 pull that delivers less than the quoted used amount does not change the share count computed before the pull. The deposit event shows the delivered amount.

PT-A18. The surface has no `getRate`. A plan that adds one is a future decision, not satisfaction of this baseline.

PT-A19. Second `initialize` reverts `AlreadyInitialized`. The factory value remains the first caller. No path reverts `NotFactory`.

PT-A20. A guarded call that is reentered from a token or manager callback into `deposit`, `zapDeposit`, `redeem`, `redeemZap`, or `compound` reverts `Reentrancy`. That is the guard's extent. It is not a claim that the manager-only callback is a complete safety boundary.

## 21. Analyst traceability

Not planner-facing. Locators are original `src/pair/PairToken.sol` lines in the admitted bundle, unless another file is named. Readable-bundle lines are those numbers plus three. This table records where the requirements were read. It is not an instruction to copy source into the handoff.

| Requirements | Settled behavior | Locator |
| --- | --- | --- |
| PT-001, PT-002, PT-054 | One ERC-20, one full-range position, salt zero, clone notice only | 31-40, 138-152, 214-218, 615 |
| PT-010 to PT-017, PT-021 | Units, constants, public getters, operation-scoped reservation | 47-74, 646-649 |
| PT-020, PT-022, PT-023 | Surface, caller, recipient, entered flag | 120-133, 138, 156, 256, 308, 351, 366, 412, 550 |
| PT-030 to PT-035 | Quote branches and zap mint basis | 500-529, 342 |
| PT-040 to PT-045 | Basket, previews, preview inequality | 214-250 |
| PT-050 to PT-053 | Initialize, unused `NotFactory` | 102-103, 138-152 |
| PT-060 to PT-065 | ERC-20, dead shares | 49, 61, 66, 156-197, 286-287 |
| PT-070 to PT-072 | Paired deposit order and gross minimum | 256-293, 651-676 |
| PT-080 to PT-082 | Zap cap, tick rule, no refund | 308-346, 332, 339 |
| PT-090 to PT-098 | Compound, carve, ratio cap | 412-496, 427, 437, 494 |
| PT-100 to PT-103 | Retention, zero payout, dual minima | 63, 351-364, 391-406 |
| PT-110 to PT-112 | Chosen leg, unsigned encoding, no fill check | 366-388, 538-544, 560-568, 586 |
| PT-120 to PT-126 | Native, separate unlocks, callback gate, settlement | 546-644, 125-130, 550 |
| PT-130 to PT-133 | Idle, pull, two transfer helpers | 133, 646-691; currency helper in `Currency.sol` transfer and `balanceOfSelf` |
| PT-140 to PT-143 | Events, errors, propagated failures | 54-55, 102-118 |
| PT-150 to PT-155 | Helper meanings | admitted `TickMath`, `SqrtPriceMath`, `LiquidityAmounts`, `PriceMath.sqrt`, `FullMath`, `StateLibrary`, `Position.calculatePositionKey`, `PoolId.toId` |
| PT-160 to PT-168 | Quirks, documented not repaired | deposit 272 then 286-287; pull 661-667; zap 332 versus ratio 494; callback 560-568; redeem 397; initialize 144; carve 447-465 |
| PT-170 to PT-172 | Absent surface and unverified clone notice | no `getRate` in the named surface; notice at 35-36 |
| PT-180 to PT-181 | No vulnerability claim; no legal clearance | settled audit resolution on unsigned conversion and manager-equality; SPDX on PairToken line 1 is an observation |

Coverage of the brief's required topics: system and property, sections 1-2; all 17 functions, the receiver, and 17 getters, section 3; genesis and reserve branches, sections 4 and 8; checkpoints, floors, ceilings, checked products, and casts, sections 4, 8-13 and 17; paired and zap deposits, sections 8-9; both redemptions, retention, and dead shares, sections 7, 11-12; collective fees, protocol routing, and ratio swap, section 10; balances, donations, reservation, refund, and token helpers, sections 2, 13-14; allowances and transfers, section 7; callback, unlocks, settlement, and hook data, section 13; helper contracts and raw units, sections 2 and 16; previews versus execution, section 5; events and errors, section 15; zero, dust, extreme, and partial-fill cases, sections 10-12 and 17; absent functions and unsupported assumptions, sections 18-19. Acceptance scenarios are section 20.
