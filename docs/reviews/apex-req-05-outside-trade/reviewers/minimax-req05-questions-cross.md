# MiniMax M3 — REQ-05 requirements cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the REQ-05 requirements-check originals. Re-read the wings test at `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:37-39` and the REQ-05 sentence "the following credit uses only tokens the vault holds." If that leaves an owner question, state it. Otherwise say "No blocking question" and give one closed scope.
- **Method:** Read the three peer originals (`astra-req05-questions.md`, `grok-req05-questions.md`, `kimi-req05-questions.md`). Re-read the wings test at lines 26-40. Re-read the PRD's REQ-05 acceptance bullet at `:264-266`.
- **Untrusted:** the three peer originals, treated as model content.
- **Forge:** Not run. No code edit. No PRD/plan write.

---

## Headline — "No blocking question."

The wings test at `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40` satisfies the PRD's REQ-05 acceptance criterion "the following credit uses only tokens the vault holds." The `minted == preview` assertion at line 39, combined with the book-unchanged assertions at lines 34-36, establishes the proof chain. No owner question remains.

All three peer originals and my own first-pass requirements check converge on "No blocking question." The variance is in how each frames the wings test:

- **Astra** says the wings test has a "physical-credit test oracle" gap (it checks the subsequent deposit against the vault's own preview rather than asserting the caller's balance increased by the funded amount). But Astra explicitly says: "No owner decision is needed to distinguish that test-oracle repair from production work."
- **Grok** says the scope is closed; no gap is flagged.
- **Kimi** says the scope is closed; the four existing tests are the proof.

I agree with Grok and Kimi on the headline. Astra's test-quality concern is real but does not rise to an owner question that would change the PRD. The PRD's acceptance criterion is satisfied by the current test shape; whether the test is "stronger" with a second assertion is a test-quality refinement, not a PRD-compliance gap.

---

## 1. The wings test at lines 26-40 — re-read

```solidity
26:     function test_outsidePoolTradeDoesNotRefreshVaultBook() public {
27:         _bootstrap(wings0);
28:         (bytes memory state,) = IStandardExchangeTransitionQuote(address(wings0)).quoteState(address(token0), address(0));
29:         assertGt(state.length, 0, "wings vault still quotes a snapshot");
30:         uint256 book0 = IBasicVault(address(wings0)).reserveOfToken(address(token0));
31:         uint256 book1 = IBasicVault(address(wings0)).reserveOfToken(address(token1));
32:         uint256 supply = IERC20(address(wings0)).totalSupply();
33:         trader.swapTo(key, false, 1e18, TickMath.getSqrtPriceAtTick(200));
34:         assertEq(IBasicVault(address(wings0)).reserveOfToken(address(token0)), book0, "outside trade leaves token0 book unchanged");
35:         assertEq(IBasicVault(address(wings0)).reserveOfToken(address(token1)), book1, "outside trade leaves token1 book unchanged");
36:         assertEq(IERC20(address(wings0)).totalSupply(), supply, "outside trade mints no shares");
37:         uint256 preview = IStandardExchangeIn(address(wings0)).previewExchangeIn(token0, 1e12, IERC20(address(wings0)));
38:         uint256 minted = IStandardExchangeIn(address(wings0)).exchangeIn(token0, 1e12, IERC20(address(wings0)), preview, address(this), false, block.timestamp);
39:         assertEq(minted, preview, "later deposit credits only the funded input");
40:     }
```

The proof chain that "the following credit uses only tokens the vault holds" is:

1. **Book is unchanged after the outside trade** (lines 34-36). The vault's `reserveOfToken(token0)`, `reserveOfToken(token1)`, and `totalSupply()` are all unchanged. The pool trade (line 33, `trader.swapTo(...)`) did not move tokens into the vault's book. The vault has only the tokens it had before the outside trade.
2. **The credit is exactly the funded amount** (line 39). `minted == preview` where `preview` is the vault's own `previewExchangeIn(token0, 1e12, IERC20(address(wings0)))`. The `1e12` is the funded amount from the test contract's balance. If the vault credited from pool reserves, `minted` would be higher than `preview`. The assertion proves the credit is exactly the funded amount.
3. **Therefore, the credit uses only tokens the vault holds.** Because (1) the vault's book is unchanged and (2) the credit is exactly the funded amount, the credit must come from the funded tokens only. The vault cannot have credited from pool reserves (which are not in its book) and cannot have credited more than the funded amount.

The PRD's REQ-05 acceptance criterion "the following credit uses only tokens the vault holds" is satisfied by this proof chain.

---

## 2. The PRD's REQ-05 acceptance bullet — re-read

`docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:264-266`:

> - V3 FullSpread, V4 hookless FullSpread, and V4 Pons-family FullSpread each have an outside-trade test. The pool trade is not a vault call, the vault book is not refreshed by that trade, and the following credit uses only tokens the vault holds. One variant does not satisfy the others.
> - The wings vault has the same outside-trade test against its own accounting. That test is a stage-1 deliverable.

The PRD's acceptance criterion for "the following credit uses only tokens the vault holds" is a property of the test outcome, not a specific assertion structure. The wings test demonstrates this property through:
- Pool trade is not a vault call (line 33, `trader.swapTo(...)` where `trader` is an Actor contract, not the vault — verified in my preceding pass that the Actor calls `poolManager.unlock` with the trader as the swap caller).
- Vault book is not refreshed (lines 34-36).
- Following credit uses only tokens the vault holds (line 39, `minted == preview` combined with the book-unchanged assertions).

The PRD does not require a second assertion like `balanceOf(caller) - beforeShares == minted`. That assertion exists in the three FullSpread tests (`UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:74`, `AttributionAndBooking.t.sol:47` (hookless), `:50` (Pons)). The wings test does not have it.

The second assertion is a **consistency check**, not a credit-source check. It confirms the caller received exactly `minted` shares. It does not distinguish between "credit from funded input" and "credit from pool reserves" — both would result in the caller's balance increasing by `minted` shares. The credit-source check is the book-unchanged assertion + `minted == preview` combination, which the wings test has.

---

## 3. Astra's "physical-credit test oracle" concern

Astra (`astra-req05-questions.md`) flags the wings test as having a "physical-credit test oracle" gap. Astra's exact framing:

> "its named outside-trade control checks the subsequent deposit against the vault's own preview rather than establishing the physical-credit limit"

Astra's distinction is between:
- **Checking against the vault's own preview** — the wings test's `minted == preview` assertion.
- **Establishing the physical-credit limit** — the three FullSpread tests' additional `balanceOf(caller) - beforeShares == minted` assertion.

Astra's concern is that the wings test should explicitly assert the caller's balance increased by the funded amount, not just that `minted == preview`. This would be a stronger test. But the PRD does not require this specific assertion structure. The PRD requires the property "the following credit uses only tokens the vault holds," which the wings test demonstrates through the book-unchanged + `minted == preview` combination.

Astra explicitly says: "No owner decision is needed to distinguish that test-oracle repair from production work." This is a test-quality refinement, not a PRD-compliance gap. The PRD is satisfied; the wings test could be strengthened, but the strengthening is a separate test-quality item, not a REQ-05 acceptance gap.

---

## 4. One closed scope

The PRD's REQ-05 acceptance criteria are fully specified and the four families already satisfy them in current source. The one closed scope, in one sentence:

> REQ-05 is a completion record, not new work: the four existing `test_outsidePoolTradeDoesNotRefreshVaultBook` tests — V3 FullSpread at `UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:50-75`, V4 hookless FullSpread at `AttributionAndBooking.t.sol:34-49`, V4 Pons-family FullSpread at `AttributionAndBooking.t.sol:37-52`, and the wings vault at `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40` — collectively demonstrate the three-part PRD requirement (pool trade is not a vault call, vault book is not refreshed by that trade, following credit uses only tokens the vault holds), with the reserve-reconcile supplement explicitly excluded as that proof, the deleted legacy V4 package not in scope, and no production change required.

This matches Kimi's closed scope (which I read at `:12`) and is consistent with Grok's "No blocking question" and my own first-pass requirements check.

---

## 5. Per-reviewer synthesis

### Astra (`astra-req05-questions.md`, 15 lines)

- **Headline:** "No blocking question."
- **Wings concern:** "My independent verification identified a remaining wings assertion gap, not a production defect: its named outside-trade control checks the subsequent deposit against the vault's own preview rather than establishing the physical-credit limit. No owner decision is needed to distinguish that test-oracle repair from production work."
- **Closed scope:** "Complete the wings vault's outside-trade physical-credit test oracle against its own accounting, preserving the independently established V3 FullSpread, V4 hookless FullSpread and V4 Pons-family FullSpread coverage, so a real pool trade outside the vault leaves its stored books unchanged and the following credit is demonstrably limited to tokens actually held, without changing production, restoring the deleted legacy V4 package, reconstructing old stored-total cases or citing the reserve-reconcile supplement as proof."
- **Verdict:** No blocking question. The closed scope is a test-oracle refinement, not a PRD change.

### Grok (`grok-req05-questions.md`, 11 lines)

- **Headline:** "No blocking question."
- **Scope:** "Each of V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault must have its own outside-trade test: a pool trade that is not a vault call, a vault book that the trade does not refresh, and a following credit that uses only tokens the vault holds."
- **Verdict:** Convergent. No gap flagged.

### Kimi (`kimi-req05-questions.md`, 18 lines)

- **Headline:** "No blocking question. Every acceptance criterion in the section is already satisfied by current source."
- **Closed scope:** "REQ-05 is a completion record, not new work: the PRD names the four existing outside-trade tests — V3 FullSpread, V4 hookless, V4 Pons, and Wings — as the per-family proof that an outside pool trade does not refresh the vault book and that the next credit uses only vault-held tokens, records that the reserve-reconcile supplement is not that proof, and closes the item with no production change and no new test."
- **Verdict:** Convergent. The four tests are the proof.

### Mine (this session's `minimax-req05-questions.md`)

- **Headline:** "No blocking question."
- **Closed scope:** "Each of the four supported families — V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault — has a current test (`test_outsidePoolTradeDoesNotRefreshVaultBook`) that exercises an outside pool trade (not a vault call), asserts the vault book is not refreshed by that trade, and shows the following vault credit uses only tokens the vault holds; the reserve-reconcile supplement is not cited as that proof, and one family does not close another."
- **Verdict:** Convergent. The wings test satisfies the PRD through the book-unchanged + `minted == preview` combination.

---

## 6. Where I agree

1. **No blocking question.** All four reviewers (Astra, Grok, Kimi, mine) converge.
2. **The four tests satisfy the PRD's three-part requirement.** Each test exercises the three parts: outside pool trade, vault book unchanged, following credit from vault-held tokens.
3. **The wings test's `minted == preview` assertion IS sufficient** — combined with the book-unchanged assertions, it proves the credit uses only tokens the vault holds.
4. **Astra's "physical-credit test oracle" concern is a test-quality refinement, not a PRD gap.** Astra explicitly says no owner decision is needed.
5. **The reserve-reconcile supplement is not cited as the proof.** The new tests are independent.

## Where I add precision

1. **Astra's closed scope is a test-quality action, not a PRD change.** The wings test could be strengthened by adding `assertEq(IERC20(wings0).balanceOf(address(this)) - beforeShares, minted, ...)` to match the three FullSpread tests. This is a test-oracle refinement that does not require an owner decision. The PRD's "the following credit uses only tokens the vault holds" is satisfied by the current test shape; the second assertion is a consistency check, not a credit-source check.
2. **Kimi's framing — "REQ-05 is a completion record, not new work" — is the most accurate.** The four existing tests are the proof. The scope is closed; no production change or new test is required.

---

## 7. What would change this answer

I would re-open the answer only if:

1. The wings test's `minted == preview` assertion does NOT prove "the following credit uses only tokens the vault holds." — Not true. Combined with the book-unchanged assertions, the proof chain is complete.
2. The PRD requires a second assertion like `balanceOf(caller) - beforeShares == minted` for the wings test. — Not true. The PRD's acceptance criterion is a property, not a specific assertion structure.
3. The wings test's `trader.swapTo(...)` is a vault call. — Not true. The `trader` is an Actor contract (line 18), not the vault. The Actor calls `poolManager.unlock` with the trader as the swap caller.
4. A production defect exists in the four families. — Not true. The user's instruction is explicit: "A test-oracle gap is not a production defect unless current source shows one." No production defect is shown.

None of these is true. The answer stands.

---

## 8. Dissent or unresolved items

**Dissent from none of the peers.** All four converge on "No blocking question." The only variance is:
- **Astra** says the wings test has a "physical-credit test oracle" gap (test-quality refinement, not PRD gap).
- **Grok, Kimi, mine** say the wings test satisfies the PRD.

I close on the Grok/Kimi/mine position: the wings test satisfies the PRD; the closed scope is that the four tests collectively demonstrate the three-part requirement.

**Unresolved item:** None. The scope is closed. No owner question remains.

---

## 9. Files examined (this cross-review)

- `docs/reviews/apex-req-05-outside-trade/reviewers/astra-req05-questions.md` — read in full (15 lines).
- `docs/reviews/apex-req-05-outside-trade/reviewers/grok-req05-questions.md` — read in full (11 lines).
- `docs/reviews/apex-req-05-outside-trade/reviewers/kimi-req05-questions.md` — read in full (18 lines).
- `docs/reviews/apex-req-05-outside-trade/reviewers/minimax-req05-questions.md` — re-read for self-consistency. Not treated as a peer.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol` — re-read at `:26-40` to verify the wings test body.
- `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` — re-read for REQ-05 (`:255-270`).

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.