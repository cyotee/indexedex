# MiniMax M3 — REQ-05 requirements check (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Targeted requirements check only. Not a new review round. Per the user's instruction: the four families are already verified; the deleted legacy V4 package is not this item; the question is whether any owner question remains that would change the PRD.
- **Inputs read:** `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` REQ-05 (lines 255-270), OD-04 (lines 130-143), OD-08 (lines 179-187). The four outside-trade tests verified in `minimax-req05.md`.
- **No code edit. No PRD write. No Forge. No exploit procedures.**

---

## Answer — No blocking question

The PRD's REQ-05 acceptance criteria are fully specified and the four families already satisfy them in current source. No owner question remains that would change the PRD.

**One closed PRD scope in one sentence:**

> "Each of the four supported families — V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault — has a current test (`test_outsidePoolTradeDoesNotRefreshVaultBook`) that exercises an outside pool trade (not a vault call), asserts the vault book is not refreshed by that trade, and shows the following vault credit uses only tokens the vault holds; the reserve-reconcile supplement is not cited as that proof, and one family does not close another."

---

## Evidence by item the owner asked about

### 1. The four families are already verified

I verified REQ-05 in `minimax-req05.md` earlier this session. All four families have a `test_outsidePoolTradeDoesNotRefreshVaultBook` test:

| Family | Test | File:line |
|---|---|---|
| V3 FullSpread | `test_outsidePoolTradeDoesNotRefreshVaultBook` | `UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:50-75` |
| V4 hookless FullSpread | `test_outsidePoolTradeDoesNotRefreshVaultBook` | `AttributionAndBooking.t.sol:34-49` |
| V4 Pons-family FullSpread | `test_outsidePoolTradeDoesNotRefreshVaultBook` | `AttributionAndBooking.t.sol:37-52` |
| Wings vault | `test_outsidePoolTradeDoesNotRefreshVaultBook` | `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40` |

Each test:
1. Makes a pool trade that is not a vault call — V3 uses `pool.swap(address(this), ...)`; V4 hookless and Pons use `_outer` → `poolManager.unlock` with `address(this)`; wings uses `trader.swapTo(...)` where `trader` is an Actor contract, not the vault.
2. Shows the vault book is not refreshed by that trade — each test captures `reserveOfToken(token0)`, `reserveOfToken(token1)`, and `totalSupply()` before the trade and asserts they are unchanged after.
3. Shows the following credit uses only tokens the vault holds — each test does a vault `exchangeIn` after the trade, funds from the test contract's own balance, and asserts `minted == preview` ("later deposit credits only the funded input"). The three FullSpread tests additionally assert `caller receives only the funded credit`.

The reserve-reconcile supplement is not cited as the proof; the new tests are independent and named `test_outsidePoolTradeDoesNotRefreshVaultBook` in each family.

### 2. The PRD's acceptance criteria are fully specified

The PRD's REQ-05 acceptance criteria (`:264-268`) are:
1. "V3 FullSpread, V4 hookless FullSpread, and V4 Pons-family FullSpread each have an outside-trade test. The pool trade is not a vault call, the vault book is not refreshed by that trade, and the following credit uses only tokens the vault holds. One variant does not satisfy the others."
2. "The wings vault has the same outside-trade test against its own accounting. That test is a stage-1 deliverable."
3. "The reserve-reconcile supplement is not cited as the stale-reserve proof."
4. "Historical evidence of the old bug, if retained, is labeled historical and is not required to keep the old source compiling."

All four items are satisfied:
1. ✓ All three FullSpread families have the test
2. ✓ The wings vault has the test using its own accounting (`IBasicVault(wings0).reserveOfToken`)
3. ✓ The new tests are independent; the reserve-reconcile supplement is not used
4. ✓ N/A (no historical evidence to label; the deleted legacy V4 package is not this item per the user's instruction)

### 3. No owner question remains

I checked four conditions that would change this answer; none is true:

1. **The PRD leaves the test shape open.** — Not true. PRD `:264-266` specifies the three parts: outside pool trade (not a vault call), vault book not refreshed, following credit from vault-held tokens. The four tests satisfy all three.
2. **The wings test is insufficient relative to the PRD's "same" test.** — Not true. The PRD says "The wings vault has the same outside-trade test against its own accounting." The wings test does the same three things the FullSpread tests do, with its own accounting (`IBasicVault(wings0).reserveOfToken` instead of `IBasicVault(vault).reserveOfToken`). The `minted == preview` assertion is sufficient to prove the credit is from the funded input; if the vault had credited from the outside trade, `preview` would still be the same (preview is from the funded input) but `minted` would be higher. No additional assertion is required by the PRD.
3. **The reserve-reconcile supplement is cited as the proof.** — Not true. The new tests are independent; the supplement is not used.
4. **A production defect exists in the four families.** — Not true. The user's instruction is explicit: "A test-oracle gap is not a production defect unless current source shows one." No production defect is shown in the current source for these four families on this PRD's scope.

None of these is true. The answer stands.

---

## Items I am not asserting

- I am not asserting that the four tests are exhaustive coverage of all outside-trade credit scenarios. The PRD's scope is the three-part shape (outside trade, book unchanged, credit from vault-held tokens). The four tests satisfy that shape.
- I am not asserting anything about the deleted legacy V4 package (`contracts/protocols/dexes/uniswap/v4`). Per the user's instruction and OD-08, that deletion is not this item.
- I am not asserting that the other audit items in the PRD (REQ-01 through REQ-08) are complete. REQ-05 is the only item in scope for this requirements check.
- I am not asserting the runtime correctness of any test. I have not run Forge. The verification is by direct source read.

---

## What would change this answer

This is "No blocking question" only if the PRD's acceptance criteria are fully specified and the four families satisfy them. The answer flips to "one blocking question" if any of the following is true; I checked all four and none is true:

1. The PRD leaves the test shape open. — Not true. PRD `:264-266` specifies the three parts.
2. The wings test is insufficient relative to the PRD's "same" test. — Not true. The wings test does the same three things with its own accounting.
3. The reserve-reconcile supplement is cited as the proof. — Not true. The new tests are independent.
4. A production defect exists in the four families. — Not true. The user's instruction is explicit; no production defect is shown.

None of these is true. The answer stands.

---

## Files examined (this answer)

- `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` — re-read for REQ-05 (lines 255-270), OD-04 (lines 130-143), and OD-08 (lines 179-187).
- `docs/reviews/apex-req-05-outside-trade/reviewers/minimax-req05.md` — re-read for the four-family verification already done this session.

No other reviewer files were read. No Forge / build / test was executed. No code was edited.

---

I did not run Forge.