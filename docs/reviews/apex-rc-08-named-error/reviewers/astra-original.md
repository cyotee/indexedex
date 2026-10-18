# Astra — RC-08 LP equality error requirements

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes were read. The controlling RC-08 section in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:173–185` was freshly read successfully; no guard denial occurred.

## Closed recommendation

No suitable existing error was found that specifically means **held LP is not exactly the booked LP reserve** and carries both values. Define one new error, once in `UniswapV2StandardExchangeOutTarget`:

```solidity
error LPReserveMismatch(uint256 held, uint256 booked);
```

Use it at **both** currently blank equality guards in `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`, original lines **879–880** and **1007**. The exact rejection condition remains **`held != booked`**. Arguments are always **actual held LP first, booked LP reserve second**, in native LP-token units.

Do not reuse `InsufficientLPBacking`: it means `held < required`, not inequality. Do not change the condition to less-than, tolerate excess LP, or modify the older lower-bound helper. There is no implementer choice of error name, argument order or condition.

## Current-source facts and scope

- **879–880**, inside `_exchangeOut_zapInVaultDeposit`: after loading the strategy vault and calculating/minting fee shares, the code compares `indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve` and executes blank `revert()`.
- **1005–1007**, after pass-through LP output/refund and reloading `vault2`: compares the same held LP balance with `vault2.vaultLpReserve` using `!=`, again with a blank revert.
- **1015–1018:** `UniswapV2LpBacking.InsufficientLPBacking(uint256 held, uint256 required)` is explicitly used only when `held < required`. The existing production bridge at **54–55** and the less-than backing call at **592** are a separate guard and remain unchanged.

The older RC-08 text addressed that less-than guard. The owner's present request explicitly selects the two remaining **equality** guards. This is a bounded diagnostic improvement to those guards, not evidence of a payment bug or authorization to weaken their accounting invariant.

## Existing-error search

Searched current `contracts/**/*.sol` declarations for LP/backing/reserve/balance/mismatch errors, then repeated narrower uncapped LP/mismatch and backing/reserve searches after an initial broad search hit its output limit. Also inspected the target's imports/inheritance context and Crane's common `IStandardExchangeErrors` interface.

Relevant candidates were not suitable:

- `InsufficientLPBacking(held, required)` in the target's local library is a **lower-bound** error, directly confirmed by its implementation.
- `InsufficientBacking`, `BackingDeficit` and `InsufficientReserveBpt` denote insufficient collateral/reserve conditions, not surplus-or-deficit equality mismatches.
- `PoolLiquidityFundingMismatch(expected, actual)`, `ReserveSwapFundingMismatch(expected, actual)` and `LiquidationAmountMismatch(expected, actual)` are named for different operations, not this booked-LP invariant.
- `AccountingMismatch()` and `SettlementMismatch()` in other vault families carry no compared values and are not this invariant's existing typed error.
- `IStandardExchangeErrors` declares amount limits, unsupported routes and unknown reserve errors, but no held-versus-booked LP equality error.

A scoped exact-name search found no existing `LPReserveMismatch` declaration in `contracts/`. The recommendation introduces only that new error; it does not rename or overload existing unrelated errors. This is a source-search result, not a claim that every conceivable differently named error in dependencies was semantically audited.

## Exact requirements for the two sites

### First equality guard

Replace only the old blank guard at **879–881** with the following scoped comparison:

```solidity
        {
            uint256 heldLp = indexSource.pool.balanceOf(address(this));
            uint256 bookedLp = vault.vaultLpReserve;
            if (heldLp != bookedLp) revert LPReserveMismatch(heldLp, bookedLp);
        }
```

### Second equality guard

Replace only the old one-line blank guard at **1007** with:

```solidity
        {
            uint256 heldLp = indexSource.pool.balanceOf(address(this));
            uint256 bookedLp = vault2.vaultLpReserve;
            if (heldLp != bookedLp) revert LPReserveMismatch(heldLp, bookedLp);
        }
```

The local blocks bound variable lifetimes and do not change the guard's position. Capture each compared quantity once so the error reports the exact values used by that comparison. Do not move either check across fee calculation, payout, refund or strategy-state loading. Do not add a catch, reconciliation transfer, book overwrite, balance correction or fallback route.

Retain the existing operations before and after each guard. A mismatch continues to revert the transaction; equality continues past the guard. The only intended externally observable change at these rejection sites is nonempty, typed revert data containing both values.

## Acceptance criteria

1. Exactly one `LPReserveMismatch(uint256 held, uint256 booked)` declaration is available to both sites in the target contract.
2. Both named sites reject **either direction** of inequality using that same error and argument order.
3. Equality does not trigger this error. The pre-existing comparison is not weakened to `held < booked` or converted into a repair/book-update action.
4. The lower-bound `InsufficientLPBacking` helper and its callers retain their original meaning and comparison.
5. Any later authorized tests for these two guards assert the full error with the actual compared values; supported successful routes remain unchanged. A focused comparator check is not to be mislabeled as a naturally reached end-to-end mismatch. Do not invent a live-system reproduction or fabricate production state to claim reachability.
6. If the selected guards have drifted before implementation, stop and report rather than applying this error to another check. No selector numeric constant is guessed or required by this requirements report.

No production edit or test execution is authorized by writing this report. No extra error or alternative fix is proposed.

## Astra finding — RC08-EQ-1

- **Title:** Two exact LP reserve guards still discard the compared values in blank reverts.
- **Severity:** Low.
- **Defect class:** Error specificity / diagnostic observability.
- **File and line:** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:879–880,1007`.
- **Intended behavior:** Preserve the existing equality invariant while reporting actual held and booked LP amounts, per the owner's selected follow-up.
- **Broken invariant:** The check still enforces equality, but its blank revert does not identify the mismatch or compared quantities.
- **Impact class:** Debugging/integration error attribution; no payment defect demonstrated.
- **Fix direction:** Use the one new `LPReserveMismatch(held, booked)` error at the unchanged `!=` guards exactly as specified above.
- **Confidence:** High on current guards and the existing lower-bound error's distinct semantics.

## Files examined without another scoped defect

The existing `UniswapV2LpBacking` lower-bound implementation at **1011–1019** and `_requireLpBacking` bridge at **53–56** already name their condition correctly and must not be repurposed. The target's guard contexts and common `IStandardExchangeErrors` interface were read; scoped declaration searches supplied the candidate inventory. All requested input paths were present. The assigned output was absent before writing.

Only this assigned Markdown report was created. No code, tests, PRD, original review, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

Use `LPReserveMismatch(uint256 held, uint256 booked)` when `held != booked`, with held first and booked second.
I did not run Forge.
