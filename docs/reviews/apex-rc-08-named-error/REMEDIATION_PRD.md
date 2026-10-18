# Remediation PRD — RC-08 named error

- **Status:** DRAFT. Requirements closed by owner ruling, 2026-10-18. Not a four-member council close. Writing this file does not authorize implementation.
- **Date:** 2026-10-18
- **Review target:** The two blank equality reverts in `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`.
- **Inputs:** RC-08 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Current source at lines 879-880 and 1007, and `UniswapV2LpBacking.InsufficientLPBacking`.
- **Astra participation:** Substantive original. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. No cross-review was started.
- **Grok:** Substantive original. `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **Kimi K3:** Substantive original. Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **MiniMax M3:** Did not answer. Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The first call and one same-session retry wrote no report. This is not four-member consensus.
- **Execution evidence:** No Forge run.

Writing this note does not authorize implementation.

## Required outcome

Use `LPReserveMismatch(uint256 held, uint256 booked)`. The owner chose this name on 2026-10-18. Do not use `LpBackingMismatch`. Do not reuse `InsufficientLPBacking`.

## Agreed by the three completed passes

- Lines 879-880 and 1007 revert with an empty `revert()` when the vault's LP balance is not exactly `vaultLpReserve`.
- `InsufficientLPBacking(uint256 held, uint256 required)` means `held < required`. Do not reuse it for the equality check.
- No other existing error means "held LP is not exactly the booked LP reserve."
- The new error carries held first and booked second.
- The comparison stays `held != booked`. Do not weaken it to `held < booked`.
- The less-than helper stays unchanged.

## RC-08-F1 — Name the equality stops

- **Severity:** Low
- **File and line:** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:879-880` and `:1007`.
- **Intended behavior:** When held LP is not exactly the booked LP reserve, revert `LPReserveMismatch(held, booked)`.
- **Broken requirement or invariant:** Both sites still use an empty `revert()`.
- **Acceptance criteria:**
  - Declare `error LPReserveMismatch(uint256 held, uint256 booked)` next to `InsufficientLPBacking` in `UniswapV2LpBacking`.
  - At both sites, keep `held != booked`. Revert `LPReserveMismatch` with the LP balance first and `vaultLpReserve` second.
  - Do not change `InsufficientLPBacking` or its `held < required` check.
  - A mismatch still rolls the transaction back. Booked LP is not spent.
- **Non-goals:** Do not weaken the comparison. Do not change refund amounts. Do not rename the less-than error.

## Dissent

Kimi proposed `LpBackingMismatch`. The owner chose `LPReserveMismatch`. MiniMax did not participate in the requirements round. No cross-review was held.

## Plan round

Plan written 2026-10-18 after a fresh MiniMax replacement, `ses_eaf8a39c8ffe7fWCgGG7aiDLg9`. It does not recall `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Plan: `REMEDIATION_PRD.plan.md`. Writing the plan does not authorize implementation.

The cross-review closed the test choice. Leave `UniswapV2StandardExchange_SecRemediation.t.sol:425` unchanged. Kimi withdrew the proposal to retarget it. That test calls `exchangeIn`, which reaches `UniswapV2StandardExchangeInTarget.sol:730`, outside this PRD.
