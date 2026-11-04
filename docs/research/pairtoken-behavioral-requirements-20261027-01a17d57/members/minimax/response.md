**Tool-gap report:** `apply_patch` is not available in this session — it is absent from my active tool set and a catalog search returns no matching tool. Per the brief, I did not attempt to activate it further and did not use a `write`/`edit` workaround. The complete artifact is returned below for the coordinator to archive at `docs/research/pairtoken-behavioral-requirements-20261027-01a17d57/members/minimax/response.md` with `apply_patch`. No file was written or modified this turn; all prior artifacts are untouched.

Ask: Author the complete detailed functional requirements for the verified PairToken so a different agent can plan a clean-room implementation - wanted: original, standalone candidate requirements with exact math, boundary behavior, acceptance scenarios, dependency limits and analyst-side traceability. For you: the full requirements document below, ready to archive. Now: none - all tasks closed. Next: none from me; the coordinator archives, drafts and runs the single advisory round.

---

# PairToken — candidate functional requirements

**Document status:** analyst original for run `pairtoken-behavioral-requirements-20261027-01a17d57`. Source-informed by explicit user authorization. Not an implementation plan, not a security audit, not a license opinion.

**Tool-gap note:** `apply_patch` is unavailable in this session (absent from the active tool set; catalog search returns no match). Per the brief, this content is delivered inline for coordinator archival instead of being written with an unapproved fallback.

## 0. Provenance, scope, and how to read this document

**0.1 Origin.** Every requirement below is extracted from the verified PairToken source at `0x56C8c249d4c021e93635b120aC68A9a36eb01753` (chain 4663), retrieved from the Sourcify sources endpoint and re-fetched for this run on 2026-10-27 at 14:29:44Z with HTTP 200 and `matchId 55980642` reporting exact creation and runtime matches, verified 2026-10-12. The retrieved HTTP body is byte-identical to the body examined in the preceding fidelity audit. This material is therefore **source-informed and source-exposed**: it is not an unexposed-implementer handoff, and a different agent reading it is not thereby an unexposed implementer.

**0.2 What this document is.** A functional requirements extraction: the externally observable behavior of one deployed contract, expressed as testable requirements with exact arithmetic, ordering, rounding, failure predicates and event/error semantics. Where the source behaves in a way a reader might consider a defect, that behavior is specified **as-is** and flagged as an observable quirk. Nothing here is silently repaired, hardened or redesigned.

**0.3 What this document is not.** It is not a code listing, not executable pseudocode, not a Solidity implementation, not a security assessment, not a statement of legal compliance, and not a re-description of the earlier IndexedEx alternative-vault report (that report is explicitly not a baseline for this run). IndexedEx adaptations — Crane deployment, a product-level `getRate`, fee-policy or retention changes — are **future decisions** and are excluded from the requirement set; where they appear below they are labeled as such.

**0.4 Notation.** `S` = total share supply. `s` = a share amount. `r0`, `r1` = basket reserves for currency0/currency1. `a0`, `a1` = caller-supplied deposit amounts. `L` = the position's current liquidity. `P` = the live pool square-root price in Q64.96. `BPS` = 10 000. `⌊x⌋` = floor, `⌈x⌉` = ceiling. "raw units" means the integer unit of each token with no decimal scaling applied anywhere.

**0.5 Requirement IDs.** `FR-SYS` system and scope · `FR-DEF` domain concepts, units, constants · `FR-INI` initialization and position identity · `FR-API` public interface rules · `FR-MTH` pricing mathematics · `FR-DEP` paired deposit · `FR-ZAP` zap deposit · `FR-RDM` redemption · `FR-FEE` fees, protocol routing, compounding · `FR-CB` manager callback · `FR-HLP` helper semantic contracts · `FR-VIW` views and preview/execution divergence · `FR-ERC` ERC-20 surface · `FR-BAL` balances, native, token helpers · `FR-EVT` events · `FR-ERR` failures · `FR-QRK` observable quirks · `FR-ABS` absent functions · `FR-AC` acceptance scenarios · `FR-UNK` unknowns. IDs are stable and are the join key for the analyst traceability register in §17.

---

## 1. System, property and scope requirements

- **FR-SYS-01** The system is a single smart contract that represents one Uniswap-v4-style concentrated-liquidity position, held directly by the contract itself (no position NFT, no position manager, no external helper), and issues a freely transferable ERC-20 share token against it.
- **FR-SYS-02** The contract holds exactly **one** position: one pool key, one tick range, one salt. There is no path to a second range, a second salt, or a second pool.
- **FR-SYS-03** The share token is a claim on a **two-asset basket** measured at the live pool price, not on a liquidity-unit ledger and not on a single configured target token.
- **FR-SYS-04** Trading fees accrued by the position are **not** held in a separate escrow and **not** tracked per account. They are collected into the contract's balances and redeployed into the position, so they benefit all holders collectively through basket growth.
- **FR-SYS-05** The contract performs **no** vault-initiated swap as part of a paired deposit or redemption. Swaps occur only on the two explicit routes: the zap deposit route and the chosen-leg redemption route, plus the internal balancing swap used when compounding idle balances.
- **FR-SYS-06** All contract arithmetic on user-supplied values is checked (Solidity 0.8.26 semantics): overflow, underflow and division by zero revert rather than wrap, except where a value is deliberately narrowed by an explicit cast.
- **FR-SYS-07** The contract is deployed as a minimal-proxy clone of a shared implementation according to the source's own documentation. Deployment mechanics, the factory implementation and the deployed clone bytecode are **not** supplied; see §16.
- **FR-SYS-08** The contract exposes no administrative, upgradeable, pausable, owner-controlled or governance surface. No function can change the pool key, ticks, salt, or the configured manager after initialization.
- **FR-SYS-09** Token amounts are handled in **raw units**. The contract never converts between token decimals and share decimals; the share token declares 18 decimals as metadata only, and no decimal scaling is applied to any pricing or settlement computation.
- **FR-SYS-10** Prices are handled in Q64.96 square-root form and liquidity in `uint128`; token amounts in `uint256`. The contract performs no price oracle lookup, no time-weighted average, no external valuation, and no off-chain pricing input of any kind.

---

## 2. Domain concepts, units and constants

- **FR-DEF-01 Pool key.** Five fields: currency0, currency1, LP fee (uint24, hundredths of a bip, with the top bit reserved for dynamic-fee pools), tick spacing (int24) and hooks address. The key is fixed at initialization.
- **FR-DEF-02 Pool identifier.** A32-byte value derived from the pool key. Currency ordering inside the key is by ascending numeric address, so the native currency (address zero) is always currency0 when present.
- **FR-DEF-03 Native currency.** The zero address. It is always currency0. A pool with a native leg therefore always has a native currency0 and an ERC-20 currency1.
- **FR-DEF-04 Position identity.** A position is keyed by (owner, lower tick, upper tick, salt). The contract's owner entry is its own address; the salt is the32-byte zero value; the ticks are derived from the tick spacing at initialization.
- **FR-DEF-05 Usable tick range.** Lower tick = the largest multiple of the tick spacing not greater than the minimum representable tick; upper tick = the smallest multiple of the tick spacing not less than the maximum representable tick. The resulting range is the widest the spacing permits, not a chosen band.
- **FR-DEF-06 Basket reserves.** For each currency, the reserve is the amount of that currency currently attributable to the position at the live square-root price (zero if the position has no liquidity), plus the contract's idle balance of that currency. Both components are floored when derived from liquidity.
- **FR-DEF-07 Idle balance.** The contract's actual token balance for that currency, minus (for native only) the operation-scoped native reservation described in FR-BAL-04.
- **FR-DEF-08 Share.** An ERC-20 unit with 18 declared decimals. Shares are minted against the basket and redeemed pro rata against it. There is no liquidity-denominated share, no fee-index share, and no per-account fee entitlement.
- **FR-DEF-09 Constants.** Exactly five public constants exist beyond `decimals`:
  - `BPS` = 10 000 — basis-point denominator for every rate in the contract.
  - `DEAD_SHARES` = 1 000 — shares minted to the dead address at genesis and deducted from the first depositor.
  - `RETENTION_BPS` = 10 — the exit haircut: 10 basis points of every redemption is retained by the vault.
  - `DUST` = 1 000 — the idle-balance threshold below which idle balances are not deployed into the position.
  - `DEAD` = `0x000000000000000000000000000000000000dEaD` — the recipient of the genesis dead shares.
- **FR-DEF-10 Retention factor.** The retained fraction of a redemption is `payout = ⌊s × (BPS − RETENTION_BPS) / BPS⌋ = ⌊s × 9990 / 10000⌋`. The retained 10 bps is **not** paid out; it stays in the contract's property and therefore accrues to remaining holders.
- **FR-DEF-11 Protocol fee rate.** A runtime-read basis-point figure supplied by the factory. When both the fee manager address and the rate are nonzero, that share of collected fees is routed to the fee manager; the rate itself is not stored in the contract.
- **FR-DEF-12 Zap caps.** Two distinct runtime-read limits: a maximum zap size in basis points, and a maximum permitted tick movement for a zap. They are read fresh on every call and are not constants.

---

## 3. Initialization and position identity

- **FR-INI-01** `initialize(manager, key, name, symbol)` is externally callable, non-payable, and callable at most once per contract instance.
- **FR-INI-02** It reverts with `AlreadyInitialized` if the instance was already initialized, and with `ZeroAddress` if the supplied manager is the zero address.
- **FR-INI-03** It records the caller as the factory address. **There is no check that the caller is a factory.** The first successful caller becomes the factory and thereby becomes the source of the protocol-fee and zap-cap configuration. A declared `NotFactory` error exists in the interface surface but is never raised.
- **FR-INI-04** It stores the pool key, derives the pool identifier from that key, derives the lower and upper ticks from the key's tick spacing, and stores the name and symbol.
- **FR-INI-05** It does **not** accept or store: a target currency, a salt, a tick range, a fee rate, a retention rate, or any economic parameter. Those are either derived, constant, or absent.
- **FR-INI-06** After initialization the pool key, both ticks, the pool identifier, the manager and the factory are immutable through every exposed function.
- **FR-INI-07** The initialized flag is set before the caller's work is committed, so a re-entrant or repeated call cannot re-initialize the instance.

---

## 4. Public interface requirements

### 4.1 Complete surface

The contract declares exactly seventeen named public or external functions, one payable receiver, and exposes seventeen generated getters. There are no overloads and no additional public members.

| # | Entry point | Mutability | Payable | Returns | Caller / recipient rule |
|---|---|---|---|---|---|
| 1 | `initialize(manager, key, name, symbol)` | external | no | — | any address may call; first successful caller becomes factory |
| 2 | `approve(spender, amount)` | external | no | `bool` (always true) | allowance owner is `msg.sender`; spender may be any address including zero |
| 3 | `transfer(to, amount)` | external | no | `bool` (always true) | debits `msg.sender`; `to` must be non-zero |
| 4 | `transferFrom(from, to, amount)` | external | no | `bool` (always true) | debits `from`; `to` must be non-zero; spender is `msg.sender` |
| 5 | `poolKey()` | external view | no | the five-field pool key | — |
| 6 | `token0()` | public view | no | address | — |
| 7 | `token1()` | public view | no | address | — |
| 8 | `positionLiquidity()` | public view | no | `uint128` | — |
| 9 | `basket()` | public view | no | `(uint256 reserve0, uint256 reserve1)` | — |
| 10 | `previewDeposit(amount0, amount1)` | public view | no | `(uint256 shares, uint256 used0, uint256 used1)` | — |
| 11 | `previewRedeem(shares)` | external view | no | `(uint256 amount0, uint256 amount1)` | — |
| 12 | `deposit(amount0, amount1, minShares, to)` | external | yes | `uint256 shares` | mints to `to`; refund, if any, goes to `msg.sender` |
| 13 | `zapDeposit(tokenIn, amountIn, minShares, to)` | external | yes | `uint256 shares` | mints to `to`; no refund path |
| 14 | `redeem(shares, min0, min1, to)` | external | no | `(uint256 amount0, uint256 amount1)` | burns **only** `msg.sender`'s shares; pays `to` |
| 15 | `redeemZap(shares, tokenOut, minOut, to)` | external | no | `uint256 out` | burns **only** `msg.sender`'s shares; pays `to` in one leg |
| 16 | `compound()` | external | no | `(uint256 fees0, uint256 fees1)` | permissionless |
| 17 | `unlockCallback(data)` | external | no | `bytes` | callable **only** by the configured manager |
| — | `receive()` | external | yes | — | accepts native currency with no accounting or validation |

Generated getters, in declaration order: `name`, `symbol`, `decimals` (constant, 18), `totalSupply`, `balanceOf(address)`, `allowance(address,address)`, `BPS` (constant), `DEAD_SHARES` (constant), `RETENTION_BPS` (constant), `DUST` (constant), `DEAD` (constant), `factory`, `poolManager`, `poolId` (32-byte value), `tickLower`, `tickUpper`, `initialized`.

### 4.2 Interface rules

- **FR-API-01** `deposit`, `zapDeposit`, `redeem`, `redeemZap` and `compound` are guarded by a re-entrancy latch: a call made while the latch is held reverts with `Reentrancy`. The latch is released when the guarded function returns, including on a revert.
- **FR-API-02** `approve`, `transfer`, `transferFrom`, `initialize` and `unlockCallback` are **not** re-entrancy guarded. A token whose transfer hook calls back into `transfer` will succeed.
- **FR-API-03** `unlockCallback` reverts with `NotPoolManager` unless `msg.sender` is exactly the configured manager address. No other authorization exists: there is no armed flag, no single-use token, no binding of caller, recipient, pool, range or amount budget.
- **FR-API-04** `initialize`, `approve`, `transfer`, `transferFrom` and `unlockCallback` are not payable; sending value with them reverts. `deposit` and `zapDeposit` are payable and enforce their own native-value rules.
- **FR-API-05** Every function that takes a `to` address rejects the zero address with `ZeroAddress` — this covers `deposit`, `zapDeposit`, `redeem` and `redeemZap`. `approve` does **not** reject a zero spender.
- **FR-API-06** The payable receiver accepts native currency unconditionally, records nothing, and does not mint shares. It is a donation path (see FR-BAL-01).

---

## 5. Pricing mathematics

Let `r0`, `r1` be the basket reserves read at the moment of quoting and `S` the total share supply at that moment. Define:

- `Q(x, y, d) = ⌊x · y / d⌋` (floor multiply-divide; reverts on overflow or zero denominator)
- `QR(x, y, d) = ⌈x · y / d⌉` (ceiling multiply-divide; reverts on overflow or zero denominator)

### 5.1 The quote engine

- **FR-MTH-01** A quote request `(a0, a1; r0, r1, S)` resolves to exactly one of four branches, evaluated in this order.

- **FR-MTH-02 Branch G — genesis/geometric.** Selected when `S = 0` **or** (`r0 = 0` **and** `r1 = 0`).
  - `shares = ⌊√(a0 · a1)⌋`, computed as the integer square root of the **checked** product `a0 · a1`.
  - If additionally `S = 0` and `shares ≤ DEAD_SHARES`, the quote reverts with `BadGenesis`.
  - Consumed amounts are `used0 = a0` and `used1 = a1` — both legs in full.
  - The integer square root is an exact floor of the real square root.
  - The product is a multiplication of two **raw-unit** quantities from two different tokens, so the result is sensitive to the two tokens' decimal representations and to their ordering-independent product. This is a raw-unit arithmetic property, not a unit-converted geometric mean.

- **FR-MTH-03 Branch Z0 — currency0 empty.** Selected when `S > 0` and `r0 = 0` (and therefore `r1 > 0`).
  - `shares = Q(a1, S, r1)`; `used0 = 0`; `used1 = a1`.
  - The whole quote is priced against currency1 alone.

- **FR-MTH-04 Branch Z1 — currency1 empty.** Selected when `S > 0` and `r1 = 0` (and therefore `r0 > 0`).
  - `shares = Q(a0, S, r0)`; `used0 = a0`; `used1 = 0`.

- **FR-MTH-05 Branch T — two-sided.** Selected when `S > 0` and `r0 > 0` and `r1 > 0`.
  - `s0 = Q(a0, S, r0)`, `s1 = Q(a1, S, r1)`, `shares = min(s0, s1)`.
  - `used0 = min(a0, QR(shares, r0, S))`, `used1 = min(a1, QR(shares, r1, S))`.
  - The consumed amounts are rounded **up** relative to the proportional share, then clamped to the supplied amounts. The depositor is therefore charged at least the pro-rata value of the shares issued, and possibly one raw unit more per leg.

- **FR-MTH-06** The quote is a function of the basket **read at quote time**. No price input, oracle, or time-weighted value participates in any branch.
- **FR-MTH-07** Branch G is reachable with `S > 0` whenever the basket is empty (no position liquidity and no idle balances) while shares remain outstanding. In that state a new deposit is priced by the geometric branch with **no** relation to existing supply. See FR-QRK-04.
- **FR-MTH-08** The quote engine is a pure function; it performs no external calls and reads no state other than the four supplied arguments.

### 5.2 Redemption-side arithmetic

- **FR-MTH-09** For a redemption of `s` shares against pre-burn supply `S`:
  - `payout = ⌊s × 9990 / 10000⌋`
  - `liqOut = ⌊L × payout / S⌋`, narrowed to 128 bits
  - the liquidity removed contributes `removed_i`, the manager's own reported amounts for the removal
  - `amount_i = removed_i + ⌊idle_i × payout / S⌋`
- **FR-MTH-10** `S` in the redemption arithmetic is the supply **before** the burn, captured before the burn executes. The burn therefore does not change the divisor.
- **FR-MTH-11** The removal amounts are the manager's signed per-currency deltas reinterpreted through an unsigned 128-bit narrowing and then widened to 256 bits. Under the supplied manager interface, that delta is the total of principal, fee and applicable hook deltas — it is **not** guaranteed to be principal alone.
- **FR-MTH-12** The idle allocation is floored separately per currency and is added to the removal amounts; the two are not combined before rounding.
- **FR-MTH-13** The redemption consumes only the caller's own shares. There is no allowance-based or owner-addressed redemption.

### 5.3 Zap pricing

- **FR-MTH-14** A zap prices its issuance against the **pre-zap** basket: `shares = min(⌊used0 · S / r0⌋, ⌊used1 · S / r1⌋)`, where `used0`/`used1` are the amounts the in-lock liquidity deployment actually consumed and `r0`/`r1` are the basket reserves read **before** the zap's swap.
- **FR-MTH-15** Because the issuance is priced on the pre-zap basket while the swap moves the price before the deployment, the depositor absorbs the price impact of their own swap.

### 5.4 Compounding balance arithmetic

- **FR-MTH-16** Given idle balances `i0`, `i1` and the live price, the contract computes the liquidity those balances can fund, then the **upward-rounded** amounts that liquidity would require (`need0`, `need1`), and the leftovers `left0 = max(i0 − need0, 0)`, `left1 = max(i1 − need1, 0)`.
- **FR-MTH-17** The leftover of currency0 is valued in currency1 terms by two successive multiplications by the square-root price and division by 2^96, i.e. `left0In1 = ⌊⌊left0 · P / 2^96⌋ · P / 2^96⌋`. Both steps floor.
- **FR-MTH-18** If `left0In1 ≥ left1` the heavier side is currency0 (currency0 wins ties); otherwise it is currency1.
- **FR-MTH-19** If the selected side's leftover is `≤ DUST`, the swap amount is zero for that call (direction still reported as selected).
- **FR-MTH-20** Otherwise the proposed swap amount is half the selected leftover, floored.
- **FR-MTH-21** The proposed swap amount is then clipped to `⌊⌊reserve × maxZapBps / 10000⌋ / 4⌋`, where `reserve` is derived from the **pool's active liquidity**, not from the vault's basket. This is a different reference quantity from the user-zap bound in FR-ZAP-05.
- **FR-MTH-22** If the pool's active liquidity is zero, the swap amount is zero for that call, but the deployment attempt still proceeds.

---

## 6. Paired deposit (`deposit`)

- **FR-DEP-01** `deposit(a0, a1, minShares, to)` executes the following ordered steps. The order is observable and load-bearing.
  1. Reject `to = 0` (`ZeroAddress`).
  2. Apply the native-value rule (FR-DEP-02).
  3. Set the native reservation to the value actually received.
  4. Run the collective compounding sequence (FR-FEE-01).
  5. Read the basket and the supply.
  6. Compute the quote (FR-MTH-01…05).
  7. Apply the minimum-share check (FR-DEP-03).
  8. Pull the two legs (FR-DEP-04).
  9. Recompute the native reservation to the refundable remainder.
  10. Deploy idle balances into the position (FR-DEP-05).
  11. Apply the genesis branch if the supply was zero (FR-DEP-06).
  12. Mint the shares to `to`.
  13. Refund any reserved native to `msg.sender` (FR-BAL-05).
  14. Emit the deposit event with the **consumed** amounts, not the supplied ones.
- **FR-DEP-02 Native-value rule.** If currency0 is native, `msg.value` must equal `a0` exactly; otherwise `NativeMismatch`. If currency0 is not native, `msg.value` must be zero; otherwise `NativeMismatch`. The native leg is therefore always currency0 and is always exactly `a0`; there is no native overpayment tolerance.
- **FR-DEP-03 Minimum-share check.** If the quoted share count is zero, or is below `minShares`, the call reverts with `MinShares`. The check is performed on the **gross** quote, before the genesis dead-share deduction. See FR-QRK-01.
- **FR-DEP-04 Pulling the legs.** Only the quoted `used0`/`used1` are pulled. For an ERC-20 leg the contract measures the balance before and after the transfer and treats the **difference** as the received amount. For a native leg the quoted amount is used directly, because the value is already held. A quoted-but-unused ERC-20 remainder is never requested from the caller, so it never needs refunding.
- **FR-DEP-05 Deployment of idle balances.** After pulling, the contract computes the liquidity fundable by the current idle balances at the live price and, if that liquidity is positive, adds it to the position in one manager unlock. Pulled funds that do not fit the resulting liquidity are **not** refunded and **not** reconciled against any ledger; they remain idle and therefore enter the basket. The only position-liveness check in the deposit path is the genesis guard in FR-DEP-06.
- **FR-DEP-06 Genesis branch.** When the supply was zero at quoting time:
  - if the deployment produced zero liquidity, the call reverts with `BadGenesis`;
  - otherwise `DEAD_SHARES` shares are minted to `DEAD` and **deducted from the depositor's share count** before the depositor's shares are minted.
  - The dead shares remain part of total supply permanently and are not redeemable, because the dead address cannot call the redemption routes.
  - The depositor's minimum-share protection was evaluated against the gross quote, so the recipient can receive fewer shares than `minShares`.
- **FR-DEP-07** The compounding sequence in step 4 runs **before** the quote, so the basket used for pricing includes any fees compounded by this very call.
- **FR-DEP-08** The emitted deposit event carries `used0`/`used1` — the amounts consumed — not `a0`/`a1`.

---

## 7. Zap deposit (`zapDeposit`)

- **FR-ZAP-01** `zapDeposit(tokenIn, amountIn, minShares, to)` executes:
  1. Reject `to = 0` (`ZeroAddress`).
  2. Resolve the direction: `tokenIn` must equal `token0()` or `token1()`, otherwise `BadToken`. Equal to `token0()` means the swap proceeds from currency0 to currency1.
  3. Apply the native-value rule: if currency0 is native and the direction is currency0-to-currency1, `msg.value` must equal `amountIn`; in every other configuration `msg.value` must be zero. Otherwise `NativeMismatch`.
  4. Set the native reservation, then run the collective compounding sequence.
  5. Read the basket and the supply.
  6. Reject with `BadGenesis` if the supply is zero, or if either basket reserve is zero.
  7. Apply the size bound (FR-ZAP-05).
  8. Pull the input leg, measuring the ERC-20 receipt; the native receipt is the quoted amount.
  9. Clear the native reservation.
  10. Perform the deployment swap and liquidity addition in one manager unlock.
  11. Apply the tick-movement bound (FR-ZAP-06).
  12. Compute the share count against the **pre-zap** basket (FR-MTH-14).
  13. Apply the minimum-share check on that share count: zero or below `minShares` reverts `MinShares`.
  14. Mint to `to`.
  15. Emit the deposit event with the amounts consumed by the deployment.
- **FR-ZAP-02** Exactly **half** of the received input, floored, is offered to the swap. The remainder plus whatever the swap yields is added to the position in the same unlock.
- **FR-ZAP-03** The swap requests exact input with a square-root price limit one unit inside the extreme price bound of its direction.
- **FR-ZAP-04** The zap performs **no** native refund: the reservation is cleared before the deployment, so the entire native input is consumed by the swap and the position.
- **FR-ZAP-05 Size bound.** The input is bounded by `⌊reserveIn × maxZapBps / 10000⌋`, where `reserveIn` is the **pre-zap vault basket reserve** of the input currency. A zero input, or one above the bound, reverts with `ZapTooLarge`. This bound uses the vault's own basket; the compounding clip in FR-MTH-21 uses the pool's active liquidity. The two are different quantities.
- **FR-ZAP-06 Tick-movement bound.** The absolute difference between the pre-swap and post-swap tick must not exceed `maxZapTickMove`; otherwise the whole call reverts with `ZapMovesPrice`. The bound is not applied to the compounding swap.
- **FR-ZAP-07** The zap requires an existing, non-empty basket and existing supply; it cannot create a position.

---

## 8. Redemption

### 8.1 Paired redemption

- **FR-RDM-01** `redeem(s, min0, min1, to)` executes:
  1. Reject `to = 0` (`ZeroAddress`).
  2. Run the collective compounding sequence.
  3. Perform the self-redemption (FR-RDM-03).
  4. If `amount0 < min0` or `amount1 < min1`, revert `MinOut`.
  5. Transfer each leg to `to` if its amount is positive.
  6. Emit the redemption event with the two leg amounts and the burned share count.
- **FR-RDM-02** The two minima are independent. A caller must set `min0 = min1 = 0` to accept a zero-amount leg; there is no "at least one leg" rule.
- **FR-RDM-03 Self-redemption.** Capture the pre-burn supply; snapshot the two idle balances; **burn `s` shares from `msg.sender`**; compute `payout`; compute `liqOut` from the position's current liquidity and the pre-burn supply; if `liqOut > 0`, remove exactly that liquidity in one manager unlock and take the manager's reported amounts; add the floored idle allocations.
- **FR-RDM-04** A zero `liqOut` is **not** independently rejected. A positive burn may therefore produce zero output on both legs if the idle allocations floor to zero and the removal is skipped. Such a call succeeds when the minima permit. See FR-QRK-05.
- **FR-RDM-05** The burn precedes the removal, so the position is reduced after the supply has already fallen. The retention haircut is applied to the redeemer's slice only; the retained amount stays in the contract's property.
- **FR-RDM-06** Only the caller's own shares can be redeemed. A third party cannot redeem another holder's shares, and there is no allowance-gated redemption.
- **FR-RDM-07** Legs are transferred to `to` with a low-level transfer helper that tolerates tokens returning no data and rejects tokens returning a falsy value or reverting. A transfer failure reverts with `TransferFailed`. The contract emits no per-leg transfer events of its own for these payouts.

### 8.2 Chosen-leg redemption

- **FR-RDM-08** `redeemZap(s, tokenOut, minOut, to)` executes:
  1. Reject `to = 0` (`ZeroAddress`).
  2. Resolve `tokenOut` against `token0()`/`token1()`, otherwise `BadToken`.
  3. Run the collective compounding sequence.
  4. Perform the self-redemption.
  5. Identify the unwanted leg; if it is positive, swap it for the wanted leg in one manager unlock with re-deployment suppressed.
  6. `out` = the wanted leg from the redemption + the swap output.
  7. If `out < minOut`, revert `MinOut`.
  8. Transfer `out` of the wanted currency to `to`.
  9. Emit the redemption event with the **pre-swap** leg amounts and the burned share count.
- **FR-RDM-09** The unwanted leg is never paid to the caller; it is consumed by the swap. The swap is exact-input with an extreme square-root price limit.
- **FR-RDM-10** The emitted event reports the pre-swap pair, not the final single-leg output. See FR-QRK-09.
- **FR-RDM-11** The chosen leg may differ per call; there is no configured target currency and no persistent selection.

---

## 9. Collective fee collection, protocol routing and compounding

- **FR-FEE-01** The compounding sequence executes in this order: (a) collect accrued fees; (b) route the protocol share; (c) balance and deploy idle balances; (d) emit the compounding event. It runs inside `deposit`, `zapDeposit`, `redeem` and `redeemZap` before their principal work, and is exposed permissionlessly as `compound()`.
- **FR-FEE-02 Collection.** If the position has positive liquidity, a zero-liquidity-delta modification is performed in one manager unlock, and the manager's reported per-currency delta is taken as the collected fee amount for each currency. The collection consumes the **settled caller delta of that poke**, not the separately reported fee-only value; under the supplied interface that delta may include hook deltas.
- **FR-FEE-03** Collected fees are taken into the contract's own balances and become idle balances. They are not recorded per account, not credited to any holder individually, and not escrowed.
- **FR-FEE-04 Protocol routing.** If any fee was collected, the contract reads the fee-manager address and the protocol fee rate from the factory. If the manager address is nonzero and the rate is nonzero, it attempts to route `⌊collected_i × rate / 10000⌋` of each currency to the fee manager.
- **FR-FEE-05 Routing is best effort and never blocks a user action.** A reverting notification is caught. For a native currency the notification is made with value; on failure the amount stays in the contract. For an ERC-20 currency the contract first attempts an approval, then notifies; on a caught notification failure it attempts to clear the approval and returns zero. A cleared approval is not confirmed. A **successful** notification is not proof that the fee manager actually took the tokens, and a successful approval is not proof that the tokens were pulled.
- **FR-FEE-06** If the fee-manager address is zero or the rate is zero, no routing is attempted and the full collected amount stays with the holders.
- **FR-FEE-07 Deployment of idle balances.** If either idle balance is strictly greater than `DUST`, the contract computes the balancing swap (FR-MTH-16…22) and performs one manager unlock that optionally swaps and then adds the fundable idle liquidity at the post-swap price. A zero swap amount does not skip the deployment attempt.
- **FR-FEE-08** Fees therefore benefit holders **collectively** by increasing the position's liquidity and hence the basket. A holder who redeems before a collection has occurred receives no share of uncollected fees, because uncollected fees are not yet in the basket.
- **FR-FEE-09** Because the deposit and redemption routes both run the compounding sequence, and that sequence may swap, **a plain deposit or redemption can move the pool price**. The tick-movement bound in FR-ZAP-06 applies only to the user zap.
- **FR-FEE-10** The compounding event is emitted only when fees were collected, a protocol share was routed, or liquidity was added; otherwise the call is silent.
- **FR-FEE-11** The compounding sequence never mints or burns shares.

---

## 10. Manager callback protocol

- **FR-CB-01** The contract interacts with the pool manager exclusively through an unlock: it calls the manager's unlock entry point with an opaque payload and receives the manager's callback in return.
- **FR-CB-02** The unlock payload encodes an operation tag and an operation-specific argument blob. The four tags are: add liquidity, remove liquidity, collect, and deploy (optional swap plus liquidity addition).
- **FR-CB-03** The callback is guarded only by manager equality. There is no armed flag, no single-use marker, no nonce, and no binding of the callback to a caller, a recipient, an amount, or a specific operation sequence.
- **FR-CB-04** Operation dispatch:
  - **Add** — argument is a 128-bit liquidity amount; the contract modifies liquidity by that amount and returns the two amounts consumed.
  - **Remove** — argument is a 128-bit liquidity amount; the contract modifies liquidity by the negative of that amount and returns the manager's two reported deltas, each narrowed to 128 bits and then widened.
  - **Collect** — no argument; the contract modifies liquidity by zero and returns the manager's two reported deltas, each narrowed to 128 bits and then widened.
  - **Deploy** — argument is a direction flag and a swap amount; the contract performs the optional swap and the liquidity addition and returns a structured result (amounts used, swap output, tick before, tick after, liquidity added).
  - Any other tag reverts with `NotPoolManager`.
- **FR-CB-05** Each user action may perform **several separate unlocks**, not one encompassing callback. A paired deposit performs at least a collection unlock and an addition unlock; a zap performs a collection unlock and a deploy unlock; a paired redemption performs a collection unlock and a removal unlock. There is no single atomic "entry callback" or "exit callback" that spans a user's action.
- **FR-CB-06 Delta settlement.** Every modification and every swap produces per-currency deltas that must be settled inside the same unlock:
  - a positive delta (the contract is owed) is taken from the manager into the contract;
  - a negative delta (the contract owes) is settled: for the native currency by sending value with the settle call, for an ERC-20 currency by syncing, transferring to the manager, and settling.
  - a zero delta requires no action.
- **FR-CB-07** The contract never leaves a non-zero unsettled delta at the end of a callback; the manager's unlock is expected to revert if a delta remains outstanding.
- **FR-CB-08 Hook data passed to the manager is always empty** on both modification and swap calls. The contract therefore requests no hook-specific behavior and does not adapt to hook-provided deltas, other than reflecting them in the deltas it settles.
- **FR-CB-09** The position owner recorded by the manager is the contract itself, because the contract is the unlock caller and the position key is derived from the contract's own address.

---

## 11. Helper semantic contracts, units and rounding

- **FR-HLP-01** Square-root prices are Q64.96 fixed point. A price of 1.0 is 2^96.
- **FR-HLP-02** Amounts derived from liquidity and price are floored when the contract computes a reserve or a requirement, and the upward-rounded variant is used only where the contract computes what a liquidity amount *requires*.
- **FR-HLP-03** The floor/ceiling multiply-divide helper reverts on division by zero and on a result that does not fit 256 bits; the revert carries no message data. The ceiling variant additionally reverts if the incremented result overflows.
- **FR-HLP-04** The liquidity-from-amounts helper selects the binding side by price: below the range, only currency0 constrains; inside the range, the smaller of the two side-derived liquidity values constrains; above the range, only currency1 constrains.
- **FR-HLP-05** The liquidity-from-amounts helper reverts with a dedicated overflow error when the computed liquidity does not fit 128 bits.
- **FR-HLP-06** The integer square root helper returns the exact floor of the square root and is used only by the geometric quote branch.
- **FR-HLP-07** The price/amount delta helpers revert with a division-by-zero panic when the inputs are degenerate; the contract's own guards (zero liquidity, zero amounts) normally prevent this.
- **FR-HLP-08** No helper performs decimal normalization. Amounts, prices and liquidity are compared and combined in their native integer representations.

---

## 12. Views, previews and preview/execution divergence

- **FR-VIW-01** `basket()` returns the two reserves as defined in FR-DEF-06. It is a pure read of the live pool state and the contract's balances; it performs no collection, no compounding and no settlement.
- **FR-VIW-02** `previewDeposit(a0, a1)` runs the quote engine against the current basket and the current supply and returns the share count together with the two consumed amounts. It does **not** run the compounding sequence, so its result can differ from the result of an immediately following deposit.
- **FR-VIW-03** `previewDeposit` returns the **gross** quote. At genesis it reports the geometric share count, which exceeds the shares the recipient actually receives by exactly `DEAD_SHARES`.
- **FR-VIW-04** `previewRedeem(s)` returns `(0, 0)` when the supply is zero or `s` is zero. Otherwise it returns `⌊r0 × payout / S⌋` and `⌊r1 × payout / S⌋`, where `r0`, `r1` are the current basket reserves, `payout = ⌊s × 9990 / 10000⌋` and `S` is the current supply.
- **FR-VIW-05** `previewRedeem` does not simulate a liquidity removal, does not simulate a swap, does not check that the caller holds the shares, and does not apply any revert domain.
- **FR-VIW-06 Preview/execution divergence.** The preview allocates the **whole** basket proportionally, floored. Execution allocates a **liquidity slice** (floored) and an **idle slice** (floored) separately, and the manager's reported removal amounts include principal plus fee and hook deltas and are subject to the manager's own rounding. Consequently the executed amounts need not equal the previewed amounts, and pending compounding between the preview and the transaction changes the basket again.
- **FR-VIW-07** `positionLiquidity()` reports the manager's liquidity for the contract's own position (owner = the contract, lower tick, upper tick, zero salt).
- **FR-VIW-08** There is **no** view that reports the share price, the net asset value, a normalized single-token rate, the fees owed to any account, the protocol fee that would be routed, or a preview of a zap or of a chosen-leg redemption.

---

## 13. ERC-20 surface

- **FR-ERC-01** The share token implements `approve`, `transfer` and `transferFrom` with standard signatures and returns `true` on success. It does not implement `increaseAllowance`, `decreaseAllowance`, `permit`, or any transfer hook.
- **FR-ERC-02** `approve` sets the allowance unconditionally, emits the approval event with the owner, spender and amount, and does not reject a zero spender.
- **FR-ERC-03** `transferFrom` reads the allowance of `msg.sender` for `from`. If the allowance is the maximum 256-bit value it is treated as infinite and left unchanged; otherwise it is decremented by the transferred amount **before** the transfer executes. An allowance below the transferred amount causes a checked-arithmetic underflow revert, and the whole call, including the decrement, is reverted.
- **FR-ERC-04** `transferFrom` does not emit an approval event for the allowance it consumes.
- **FR-ERC-05** `transfer` and `transferFrom` reject the zero address as recipient with `ZeroAddress`. They do not reject a zero amount, and they do not emit an event for a zero-amount transfer beyond the standard transfer event.
- **FR-ERC-06** A transfer debits the sender with a checked subtraction, so an insufficient balance reverts; it credits the recipient with an unchecked addition, so a recipient balance that would overflow 256 bits wraps rather than reverting.
- **FR-ERC-07** Transfers do not move, crystallize, accrue or settle any fee entitlement. There is no per-account fee state in the contract; the only per-account state is the balance and the allowance.
- **FR-ERC-08** The share token's transfer semantics are those of a plain token: a holder's claim is the proportional basket claim, and a transfer simply moves that claim.
- **FR-ERC-09** The contract's own share mints and burns emit the standard transfer event with the zero address as the counterparty.

---

## 14. Balances, donations, native handling and token helpers

- **FR-BAL-01** Idle balances are the contract's **actual** balances. Any currency sent to the contract by any means, including a direct transfer or the payable receiver, immediately becomes part of the basket and therefore benefits all holders proportionally. Donations are not filtered, segregated, or credited to a donor.
- **FR-BAL-02** A donation changes the basket without changing the supply, so it changes subsequent quotes and subsequent redemption entitlements without any mint.
- **FR-BAL-03** The payable receiver is unrestricted: it accepts native currency of any amount from any sender and takes no action.
- **FR-BAL-04 Native reservation.** During the deposit routes the contract tracks the native value that is pending refund, and excludes it from the idle balance used for pricing, deployment and redemption. The reservation is ordinary operation-scoped state; it is cleared before the deposit's completion and is zero outside the deposit routes.
- **FR-BAL-05 Refund.** On a paired deposit, the unconsumed native remainder is returned to **`msg.sender`**, not to the share recipient `to`. The refund is sent with a plain value-bearing call; if it fails, the whole deposit reverts with `TransferFailed`. The recipient of the refund and the recipient of the shares may therefore be different parties.
- **FR-BAL-06** ERC-20 legs are pulled with a low-level call that tolerates tokens returning no data and rejects tokens returning a falsy value or reverting; a failure reverts with `TransferFailed`.
- **FR-BAL-07** The approval helper used for protocol-fee routing returns a success flag instead of reverting, and tolerates tokens returning no data. It is the only token helper that does not revert on failure.
- **FR-BAL-08** The contract never sweeps, sweeps-to-zero, or otherwise reclaims stray balances. Stray balances are ordinary idle balances.

---

## 15. Events, errors and failure semantics

- **FR-EVT-01** Five events exist.
  - **Transfer** — indexed sender, indexed recipient, value. Emitted by share transfers, share mints (zero-address sender) and share burns (zero-address recipient).
  - **Approval** — indexed owner, indexed spender, value. Emitted only by `approve`.
  - **Deposit** — indexed sender, indexed recipient, amount0, amount1, shares. Emitted by both deposit routes. The amounts are the **consumed** amounts. On the zap route they are the amounts consumed by the in-lock liquidity deployment, not the swap input.
  - **Redeem** — indexed sender, indexed recipient, amount0, amount1, shares. Emitted by both redemption routes. On the chosen-leg route the amounts are the **pre-swap** leg amounts, not the final single-leg output.
  - **Compounded** — fees0, fees1, protocol0, protocol1, liquidityAdded. **No indexed fields.** `liquidityAdded` is 128-bit. Emitted at the end of the compounding sequence when fees were collected, a protocol share was routed, or liquidity was added.
- **FR-EVT-02** Emission order for a deposit: the share mint events (zero-address to dead address first, then zero-address to the recipient) precede the deposit event; the native refund, if any, occurs between the mint and the deposit event and emits no contract event.
- **FR-EVT-03** Emission order for a redemption: the burn event (sender to zero address) precedes the leg payouts, and the redemption event is emitted last.
- **FR-EVT-04** The contract emits no events for the manager interactions, the protocol-fee notifications, the native refund, or the token-helper calls.
- **FR-ERR-01** Thirteen custom errors are declared: `AlreadyInitialized`, `NotFactory`, `NotPoolManager`, `Reentrancy`, `BadGenesis`, `MinShares`, `MinOut`, `ZapTooLarge`, `ZapMovesPrice`, `BadToken`, `NativeMismatch`, `TransferFailed`, `ZeroAddress`. `NotFactory` is declared but never raised; the remaining twelve are raised on the conditions listed in this document.
- **FR-ERR-02** Failures that are not custom errors: checked-arithmetic overflow or underflow reverts with the standard panic; division by zero in a helper reverts with the division-by-zero panic or with an empty-data revert depending on the helper; a liquidity helper overflow reverts with its dedicated error.
- **FR-ERR-03** Failures originating in the pool manager, in the factory getters, in the fee manager (outside the caught notifications) or in the underlying tokens propagate to the caller with their original revert data, except where this document states the failure is caught.
- **FR-ERR-04** Because a paired deposit runs the compounding sequence first, a failure inside compounding (for example a manager revert) aborts the deposit entirely.

---

## 16. Absent functions and unsupported assumptions

- **FR-ABS-01** The contract has **no** normalized rate function. There is no `getRate`, no `redeemTarget`, no NAV, no share price, no per-share value, and no single-token valuation of a share. Any requirement for such a function is a future decision, not a description of this source.
- **FR-ABS-02** The contract has **no** per-account fee accounting: no fee index, no accrued-fee balance, no fee-owed mapping, no fee claim function, and no crystallization on transfer.
- **FR-ABS-03** The contract has **no** liquidity-denominated mint or redeem function, and no function that books a liquidity ledger.
- **FR-ABS-04** The contract has **no** owner-parameterized or allowance-based redemption, no burn function exposed to holders, and no way to redeem another party's shares.
- **FR-ABS-05** The contract has **no** administrative surface: no owner, no pause, no upgrade, no fee-parameter setter, no factory-parameter setter, no rescue or sweep.
- **FR-ABS-06** The contract has **no** hook-aware quoting, no simulation entry point, and no preview for the zap or the chosen-leg redemption.
- **FR-ABS-07** The contract has **no** multi-range support, no rebalancing, no position migration, and no second salt.
- **FR-ABS-08** The contract does **not** accept a native deposit for currency1, does not accept a native overpayment, and does not expose a native-only deposit route.
- **FR-ABS-09** Unsupported assumptions to be rejected by a planner: that the vault's shares are priced independently of the pool price; that fees are separately claimable by a holder; that a share's value is fixed; that the contract can be relied upon to have converted its position's liquidity into a target token on exit; that the protocol fee is a fixed fraction rather than a runtime value; that the zap size bound and the compounding clip use the same reference quantity; that any documented deployment pattern (clone, factory, manager address, fee manager) is verifiable from this source.

---

## 17. Observable quirks (specified as-is, not repaired)

- **FR-QRK-01 Gross minimum-share check.** On a genesis deposit the minimum-share test is applied to the gross geometric quote; the dead-share deduction happens afterwards. A deposit can therefore succeed with a recipient amount strictly below the caller's `minShares`, by exactly `DEAD_SHARES`.
- **FR-QRK-02 Measured receipt without recomputation.** For an ERC-20 leg the received amount is measured as a balance difference, but the share count is **not** recomputed from the measured amount; it is the quote computed from the *requested* amount. For a fee-on-transfer or otherwise non-standard token the issued shares can exceed the value actually received.
- **FR-QRK-03 Two different swap caps.** The user-zap size bound is computed from the vault's basket reserve of the input currency; the compounding swap clip is computed from the **pool's active liquidity**. Two different reference quantities govern two different internal swaps.
- **FR-QRK-04 Geometric branch with live supply.** The geometric quote branch is selected when the basket is empty, even if shares are still outstanding. In that state a new deposit is priced by the geometric mean of the two legs with no reference to the existing supply, and the existing holders' relative claim changes accordingly.
- **FR-QRK-05 Zero payout burns.** A redemption may burn shares and return nothing: the removal is skipped when the floored liquidity slice is zero, and the idle allocations can floor to zero. The burn is not rolled back.
- **FR-QRK-06 No complete-fill or positive-output assertion.** The internal swap requests exact input with an extreme price limit but does not assert that the input was fully consumed, and a non-positive swap output is coerced to zero rather than rejected. The chosen-leg route can therefore complete with less than the ideal output, and the only floor on the result is the caller's `minOut`.
- **FR-QRK-07 Signed-to-unsigned narrowing.** The removal and collection results are the manager's signed per-currency deltas narrowed to 128 bits and then widened to 256 bits. A negative delta would be reinterpreted as a large unsigned value. No reachable negative-delta case is exhibited by the source; this is stated as an arithmetic property of the conversion.
- **FR-QRK-08 Manager equality is the only callback guard.** The callback accepts any operation payload from the manager, with no armed flag, no single-use marker and no amount budget.
- **FR-QRK-09 Event payload mismatch on the chosen-leg route.** The redemption event reports the pre-swap leg amounts, not the single-leg output actually delivered.
- **FR-QRK-10 First successful initializer becomes the factory.** There is no factory-membership check on initialization, so the factory identity — and therefore the protocol-fee rate, the zap caps and the fee-manager address — is determined by whoever initializes first.
- **FR-QRK-11 Notification success is not proof of settlement.** A successful fee-manager notification is not proof that the ERC-20 tokens were pulled, and the approval-clearing attempt after a failed notification is itself unverified.
- **FR-QRK-12 Refund goes to the caller.** On a paired deposit the unconsumed native remainder is returned to the transaction sender, not to the share recipient.
- **FR-QRK-13 Deposits can move the price.** A paired deposit or redemption can trigger the compounding sequence, which may perform an internal balancing swap, without any zap being involved and without the tick-movement bound being applied.
- **FR-QRK-14 Unconsumed deposit funds stay idle.** Funds pulled during a paired deposit that do not fit the resulting liquidity are neither refunded nor reconciled; they remain idle and enter the basket, so they accrue to all holders rather than only to the depositor.
- **FR-QRK-15 Deadline-free swap limits.** The internal swaps use price limits one unit inside the extreme bounds of their direction, so a swap is bounded by the pool's price range rather than by a caller-chosen limit.
- **FR-QRK-16 No dead-share recovery.** The genesis dead shares are permanently outstanding and reduce the redeemable supply without ever being redeemable.

---

## 18. Boundary, extreme and degenerate cases

| Case | Required observable behavior |
|---|---|
| Deposit with `to = 0` | Revert `ZeroAddress` |
| Deposit with `msg.value` ≠ `amount0` on a native pool | Revert `NativeMismatch` |
| Deposit with `msg.value` > 0 on a non-native pool | Revert `NativeMismatch` |
| Deposit where the quote yields zero shares | Revert `MinShares` |
| Deposit where the quote is below `minShares` | Revert `MinShares` |
| Genesis deposit whose geometric quote ≤ `DEAD_SHARES` | Revert `BadGenesis` (from the quote) |
| Genesis deposit whose liquidity deployment is zero | Revert `BadGenesis` |
| Genesis deposit with `a0 = 0` or `a1 = 0` | Product zero → quote zero → `MinShares` (or `BadGenesis` if supply is zero, since zero ≤ `DEAD_SHARES`) |
| Deposit whose `a0 · a1` overflows 256 bits | Checked-multiplication panic |
| Zap with a token that is neither leg | Revert `BadToken` |
| Zap with zero input | Revert `ZapTooLarge` |
| Zap above the size bound | Revert `ZapTooLarge` |
| Zap whose tick movement exceeds the bound | Revert `ZapMovesPrice` |
| Zap with no supply or an empty basket | Revert `BadGenesis` |
| Redemption of zero shares, or with zero supply | Revert `MinShares` |
| Redemption whose leg is below its minimum | Revert `MinOut` |
| Redemption whose floored liquidity slice is zero | No revert; may pay nothing while still burning (FR-QRK-05) |
| Redemption with `to = 0` | Revert `ZeroAddress` |
| Chosen-leg redemption with an unknown token | Revert `BadToken` |
| Chosen-leg redemption whose output is below the minimum | Revert `MinOut` |
| Transfer to the zero address | Revert `ZeroAddress` |
| Transfer exceeding the balance | Checked-subtraction panic |
| `transferFrom` beyond a finite allowance | Checked-subtraction panic on the allowance |
| `transferFrom` with a maximum allowance | Allowance unchanged; transfer proceeds |
| Re-entering a guarded route | Revert `Reentrancy` |
| Callback from a non-manager | Revert `NotPoolManager` |
| Fee-manager notification reverting | Caught; the slice stays with the holders; the user action continues |
| Idle balances at or below `DUST` | Not deployed; remain idle and enter the basket |
| Pool with zero active liquidity during compounding | Swap amount zero; the deployment attempt still runs |
| Direct currency transfer to the contract | Becomes idle balance; changes the basket without changing supply |

---

## 19. Acceptance scenariosEach scenario states an observable pre-state, an action, and the expected algebra, state change or error. Scenarios are sized to requirements and are not executable tests.

**Genesis and pricing**
- **FR-AC-01** With supply `S = 0` and both reserves zero, a deposit of `(a0, a1)` with `a0 · a1 > 10^6` yields a gross quote of `⌊√(a0·a1⌋` > `DEAD_SHARES`; the recipient receives `⌊√(a0·a1)⌋ − 1000` shares, `DEAD` holds1000 shares, and total supply increases by `⌊√(a0·a1)⌋`. (FR-MTH-02, FR-DEP-06)
- **FR-AC-02** With supply `S = 0` and `a0 · a1 ≤ 10^6`, the deposit reverts `BadGenesis` and no state changes. (FR-MTH-02)
- **FR-AC-03** With supply `S > 0` and two-sided reserves, a deposit of `(a0, a1)` mints `min(⌊a0·S/r0⌋, ⌊a1·S/r1⌋)` shares and consumes `min(a0, ⌈shares·r0/S⌉)` and `min(a1, ⌈shares·r1/S⌉)`. The consumed amounts are each at least the proportional value of the issued shares. (FR-MTH-05)
- **FR-AC-04** With supply `S > 0` and `r0 = 0`, a deposit mints `⌊a1·S/r1⌋` shares and consumes none of currency0. (FR-MTH-03)
- **FR-AC-05** With supply `S > 0` and an empty basket, a deposit mints `⌊√(a0·a1)⌋` shares irrespective of `S`. (FR-QRK-04)
- **FR-AC-06** A deposit whose gross quote is exactly `minShares` succeeds; the check is inclusive at the boundary (`< minShares` fails). (FR-DEP-03)
- **FR-AC-07** A genesis deposit whose gross quote equals `minShares + 500` succeeds and the recipient receives `minShares + 500 − 1000` shares, i.e. below `minShares`. (FR-QRK-01)

**Entry mechanics**
- **FR-AC-08** On a native pool, a paired deposit of `(a0, a1)` with `msg.value = a0` consumes `used0 ≤ a0` of native and refunds `a0 − used0` to the transaction sender; the share recipient receives the shares and no refund. (FR-DEP-02, FR-BAL-05)
- **FR-AC-09** A paired deposit against an ERC-20 leg whose transfer delivers less than requested still mints the shares quoted from the **requested** amount. (FR-QRK-02)
- **FR-AC-10** A paired deposit whose pulled funds exceed the liquidity the live price supports leaves the excess idle; the basket rises by that excess and the supply rises by the quoted amount. (FR-QRK-14)
- **FR-AC-11** A zap of `amountIn` on a pool whose pre-zap basket reserve of the input leg is `R` succeeds only when `amountIn ≤ ⌊R · maxZapBps / 10000⌋`; otherwise `ZapTooLarge`. (FR-ZAP-05)
- **FR-AC-12** A zap that moves the tick by more than `maxZapTickMove` reverts `ZapMovesPrice` and leaves no state change, including no swap. (FR-ZAP-06)
- **FR-AC-13** A zap's issued share count equals `min(⌊used0·S/r0⌋, ⌊used1·S/r1⌋)` computed on the **pre-zap** basket, while the position it acquired was deployed at the **post-zap** price. (FR-MTH-14, FR-MTH-15)

**Exit mechanics**
- **FR-AC-14** A redemption of `s` shares against supply `S` and liquidity `L` removes `⌊L·⌊s·9990/10000⌋/S⌋` liquidity and pays `removed_i + ⌊idle_i·payout/S⌋` per leg, where the removal amounts are the manager's reported deltas. (FR-MTH-09)
- **FR-AC-15** A redemption of all outstanding shares leaving the floored liquidity slice at zero completes, burns the shares, and may pay nothing. (FR-QRK-05)
- **FR-AC-16** The retained 10 bps is observable as an increase in the remaining holders' basket claims that is not paid to the redeemer; after a full redemption the retained portion is the residual idle and residual position value. (FR-DEF-10)
- **FR-AC-17** A chosen-leg redemption pays exactly one currency, and the redemption event reports both pre-swap leg amounts, which differ from the paid amount. (FR-RDM-08, FR-QRK-09)
- **FR-AC-18** A chosen-leg redemption whose swap yields zero output still succeeds when `minOut = 0`, paying only the wanted leg from the redemption. (FR-QRK-06)
- **FR-AC-19** A redemption by a party holding no shares reverts `MinShares`; a redemption by a holder of `s` shares cannot redeem a third party's balance. (FR-RDM-06)

**Fees and compounding**
- **FR-AC-20** With fees collected and a fee manager configured, the protocol share `⌊fees_i · rate / 10000⌋` is routed and the compounding event reports it; the remaining fees are redeployed and the basket grows. (FR-FEE-04, FR-EVT-01)
- **FR-AC-21** With a fee-manager notification that reverts, the user action still succeeds, the protocol amounts are reported as zero, and the fee slices remain in the contract's balances and enter the basket. (FR-FEE-05)
- **FR-AC-22** With no fee manager or a zero rate, no routing is attempted and the full collected fees are redeployed. (FR-FEE-06)
- **FR-AC-23** With both idle balances at or below `DUST`, the compounding sequence performs no deployment and emits no compounding event. (FR-FEE-07, FR-FEE-10)
- **FR-AC-24** With one idle balance above `DUST` and a mismatched pair, the balancing swap sells half the heavier leftover, capped at `⌊⌊poolLiquidityReserve · maxZapBps/10000⌋/4⌋`, and no tick-movement bound is applied. (FR-MTH-20, FR-MTH-21, FR-QRK-03, FR-QRK-13)

**Balances and tokens**
- **FR-AC-25** A direct transfer of currency0 to the contract raises `r0` by that amount without changing the supply, changing every subsequent quote and increasing every holder's proportional claim. (FR-BAL-01, FR-BAL-02)
- **FR-AC-26** The payable receiver accepts native currency of any size and mints nothing. (FR-BAL-03)
- **FR-AC-27** A transfer of the full balance to another holder succeeds and moves the entire claim; no fee state changes because no fee state exists. (FR-ERC-07)
- **FR-AC-28** `transferFrom` with a finite allowance of exactly the transferred amount succeeds and leaves a zero allowance; with an allowance one unit short it reverts and the allowance is unchanged. (FR-ERC-03)

**Callback and multi-unlock behavior**
- **FR-AC-29** A paired deposit on a non-empty position performs at least two manager unlocks (a collection and an addition), each settled to zero before the next begins. (FR-CB-05, FR-CB-07)
- **FR-AC-30** A direct call to the callback from any address other than the configured manager reverts `NotPoolManager`. (FR-API-03)
- **FR-AC-31** Every modification and swap the contract performs passes empty hook data. (FR-CB-08)

**Views**
- **FR-AC-32** `previewRedeem(s)` returns `(⌊r0·payout/S⌋, ⌊r1·payout/S⌋)` at the current basket, and the subsequent redemption of the same shares may return different amounts because the redemption floors a liquidity slice and an idle slice separately and the removal includes fee deltas. (FR-VIW-04, FR-VIW-06)
- **FR-AC-33** `previewDeposit` immediately after a fee collection, but before the next compounding, can quote differently from the next deposit because the deposit compounds first. (FR-VIW-02, FR-DEP-07)

---

## 20. Analyst-side source traceability (not for the planner-facing handoff)

Anchors are **original** `src/pair/PairToken.sol` line numbers, verified by brace-matched span extraction against the archived source (36/36 symbols verified; `positionLiquidity` is 214-218).

| Requirement group | Source symbols | Original lines |
|---|---|---|
| FR-SYS-01…10 | contract header, constants, state, pool plumbing | 31-99, 47-78, 533-642 |
| FR-DEF-01…05 | `initialize`, `poolKey`, `token0`, `token1`, `positionLiquidity` | 138-152, 201-218 |
| FR-DEF-06…08, FR-VIW-01 | `basket`, `_idle` | 221-230, 646-649 |
| FR-DEF-09 | constants block | 59-66 |
| FR-DEF-10, FR-RDM-05, FR-MTH-09 | `_redeemToSelf` | 391-406 |
| FR-DEF-11, FR-FEE-04…06 | `_carve`, factory-view interface | 19-29, 422-433, 447-464 |
| FR-DEF-12, FR-ZAP-05…06, FR-MTH-21 | `_ratioSwap`, `zapDeposit` | 332-339, 469-496 |
| FR-INI-01…07 | `initialize` | 138-152 |
| FR-API-01…03, FR-CB-03 | modifiers, `unlockCallback` | 120-130, 550-571 |
| FR-API-04…06 | payable/non-payable declarations, `receive` | 133, 156-172, 256, 308, 351, 366 |
| FR-MTH-01…08 | `_quoteShares` | 500-519 |
| FR-MTH-09…13 | `_redeemToSelf` | 391-406 |
| FR-MTH-14…15 | `_minShares`, `zapDeposit` | 342, 521-529 |
| FR-MTH-16…22 | `_ratioSwap` | 469-496 |
| FR-DEP-01…08 | `deposit`, `_addAll`, `_pull` | 256-303, 661-668 |
| FR-ZAP-01…07 | `zapDeposit`, `_deploy`, `_deployInLock` | 308-346, 533-536, 576-608 |
| FR-RDM-01…11 | `redeem`, `redeemZap`, `_redeemToSelf`, `_swapOnly` | 351-406, 538-544 |
| FR-FEE-01…11 | `compound`, `_compound`, `_carve`, `_ratioSwap`, `_deployInLock` | 412-496, 576-608 |
| FR-CB-01…09 | `_unlock`, `unlockCallback`, `_deployInLock`, `_modify`, `_resolve` | 546-642 |
| FR-HLP-01…08 | v4-core `FullMath`, `SqrtPriceMath`, `TickMath`; `LiquidityAmounts`; `PriceMath` | bundle: FullMath 14-113, SqrtPriceMath 188-290, LiquidityAmounts 11-66, PriceMath 29-56 |
| FR-VIW-02…06, FR-VIW-08 | `previewDeposit`, `previewRedeem` | 233-250 |
| FR-ERC-01…09 | `approve`, `transfer`, `transferFrom`, `_transfer`, `_mint`, `_burn` | 156-197 |
| FR-BAL-01…08 | `_idle`, `_checkNative`, `_pull`, `_refundNative`, `_safeTransfer`, `_safeTransferFrom`, `_tryApprove`, `receive` | 133, 646-691 |
| FR-EVT-01…04 | event declarations | 54-55, 116-118 |
| FR-ERR-01…04 | error declarations, revert sites | 102-114 and per-function sites |
| FR-QRK-01 | `deposit` quote check vs genesis deduction | 272 vs 285-287 |
| FR-QRK-02 | `_pull` measurement vs `_quoteShares` input | 661-668 vs 500-519, 271 |
| FR-QRK-03, FR-MTH-21 | `_ratioSwap` clip vs `zapDeposit` bound | 494-495 vs 332 |
| FR-QRK-04 | `_quoteShares` first branch condition | 506-509 |
| FR-QRK-05 | `_redeemToSelf` `liqOut` guard | 399-400 |
| FR-QRK-06 | swap output coercion, exact-input request | 585-591 |
| FR-QRK-07 | narrowing at the callback return | 560, 564 |
| FR-QRK-08 | `onlyPoolManager` and `unlockCallback` dispatch | 120-123, 550-571 |
| FR-QRK-10 | `initialize` factory assignment, `NotFactory` absence | 144, 103 |
| FR-QRK-11 | `_carve` notify and approval handling | 447-464 |
| FR-QRK-12 | `_refundNative` recipient | 670-676 |
| FR-QRK-13 | `_compound` call sites and `_ratioSwap` absence of a tick bound | 265, 327, 354, 369, 437-438 |
| FR-QRK-14 | `_addAll` funding from idle | 295-303 |
| FR-QRK-16 | dead-share mint | 286-287 |

---

## 21. Unknowns register: planning-blocking versus settled

**Planning-blocking (dependency behavior not supplied; a plan must treat these as assumptions, not facts)**

- **FR-UNK-01** The pool manager's implementation: whether a zero-delta modification of a zero-liquidity position reverts, how removal amounts are rounded, how the reported delta composes principal, fee and hook deltas, and whether the unlock reverts on an unsettled delta.
- **FR-UNK-02** The factory implementation and its live values: `maxZapBps`, `maxZapTickMove`, `protocolFeeBps`, `feeManager`. The contract reads all four at call time; none is stored, so their values are deployment-specific and can change between calls.
- **FR-UNK-03** The fee manager's behavior: whether it actually pulls ERC-20 tokens, whether it consumes native, and whether it can revert in ways the catch does not cover.
- **FR-UNK-04** Whether the pool has a hook, and if so what the hook does to swap and modification deltas. The contract passes empty hook data and does not adapt.
- **FR-UNK-05** The pool's tick spacing and whether its liquidity is dynamic-fee, which affects price movement and the feasibility of a full-range position.
- **FR-UNK-06** The token implementations' behavior, including transfer-tax behavior, return-value conventions and re-entrancy characteristics.
- **FR-UNK-07** The deployment pattern: how a clone is created, whether initialization is atomic with creation, and whether a front-run initialization is possible in practice. Only the contract's side of this is observable.

**Settled by the source (no further evidence needed)**
- **FR-UNK-08** All arithmetic, rounding, ordering, branch selection, event payloads, error predicates, the re-entrancy scope, the callback guard scope, the native-value rules, the refund recipient, the retention and dead-share mechanics, the two swap caps, and the absence of the functions listed in FR-ABS.

---

## 22. Boundary between source semantics and mathematical idealization

- **FR-UNK-09** The **idealization** is that a share is worth its pro-rata basket. The **source** computes the redemption as a floored liquidity slice plus a floored idle allocation plus the manager's reported removal amounts, which include fee deltas. Where the two differ, the source governs.
- **FR-UNK-10** The **idealization** is that a swap fills completely. The **source** requests exact input with an extreme price limit and does not assert a complete fill or a positive output.
- **FR-UNK-11** The **idealization** is that fees accrue to holders individually. The **source** has no per-account fee state; fees accrue collectively through the basket, and only once collected.
- **FR-UNK-12** The **idealization** is that a deposit is fully deployed. The **source** may leave pulled funds idle; they enter the basket and accrue to all holders.
- **FR-UNK-13** The **idealization** is that the deposit receives the amount it asked for. The **source** measures receipt and does not re-derive the share count from it.
- **FR-UNK-14** Any IndexedEx-side adaptation — Crane diamond packaging, a product `getRate`, a different retention, a different protocol fee, a different deployment — is a **future decision** and is deliberately absent from this requirement set.

---

## 23. Provenance record for this member response

- **Author:** MiniMax (council member), continuing the same source-exposed reviewer identity. Source-informed by explicit user authorization.
- **Basis:** the archived verified source admitted for this run, plus the admitted prior factual audit. No peer response for this run was read. No code, configuration, deployment, wallet, Git, test, build or install action was performed, and no file was written or modified in this turn.
- **Tool gap:** `apply_patch` is unavailable in this session; the content is delivered inline for coordinator archival.
- **Status of statements:** every behavioral statement above is a source observation with an analyst-side locator in §20; every consequence, idealization contrast and planning note is inference by the author. No security vulnerability is claimed: the document specifies observable behavior, including behaviors that a reader may wish to change, and §18 and §17 record them as-is.
- **License observation:** the source files carry SPDX identifiers (BUSL-1.1 for the pair-token files, MIT for the v4-core files). This is recorded as an observation only. No license clearance, grant scope, compliance position or deployment authorization is expressed or implied, and no license opinion is offered.
- **Next:** this is the initial requirements original. One advisory pass on the coordinator's immutable draft will follow.
