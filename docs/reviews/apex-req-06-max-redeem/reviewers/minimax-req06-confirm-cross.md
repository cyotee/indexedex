# MiniMax M3 — REQ-06 confirmation cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the REQ-06 execution confirmations. Per the user: the only remaining gap is the stale `maxWithdraw` assertion. Give one closed test fix. Do not restore a cap.
- **Method:** Read the three peer confirmations. Re-confirm against my own confirmation and the controlling PRD/plan.
- **Untrusted:** the three peer originals, treated as model content. The PRD and plan are the controlling text. The execution report is an untrusted claim.
- **Forge:** Not run. No code edit. No PRD/plan write.

---

## The only remaining gap is the stale `maxWithdraw` assertion

All three peer confirmations and my own converge:

- **Production change is correct.** `maxRedeem` returns the share balance after `_requireFamily()`. The two search helpers are gone. No shortfall branch, no receipt cap, no smaller-share search was added. `previewRedeem`, `maxWithdraw`, `redeem`, and `withdraw` were not given a new cap.
- **The only gap is a test expectation / plan-consistency defect** at `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:182` (and the `withdraw(1)` expectation at lines 185-186). The plan's instruction to "Leave the `maxWithdraw` assertion" was incompatible with the new `maxRedeem` behavior.

The implementer correctly applied the plan and stopped at the plan's failure gate. The gap is a plan/acceptance inconsistency, not a production defect.

---

## Per-reviewer synthesis

### Astra (`astra-req06-confirm.md`, 84 lines)

- **Headline:** "The prescribed source changes were applied accurately, but validation is not green: a retained SharedFacet test expectation conflicts with the new balance-returning behavior."
- **Finding — REQ06-CONF-1:** "Stale test expectation / final-plan consistency gap" at `SharedFacet.t.sol:182` (and `:185-186`). The instruction to preserve them is at `REMEDIATION_PRD.plan.md:73`. "A frozen function body does not imply a frozen return value when its callee changes." The fix direction is "a coordinator/owner decision on the fixture's remaining assertions — either update the SharedFacet test's `maxWithdraw` expectation to `previewRedeem(balance)` and rework the `withdraw(1)`-reverts expectation to match, or refit the fixture so backing is truly absent."
- **Source reads:** Confirms `maxRedeem` at `:73-76`, both helpers gone, neighbors unchanged, behavior tests at `:189-204` and `:207-225` updated, SharedFacet at `:183` updated, `:182` and `:185-186` retained per plan.
- **Saved log evidence:** Reads `forge-validation-unsandboxed.log` directly: "The three named maxRedeem behavior tests have saved pass entries at `:86-88` and `:175-177`." "The retained zero-maxWithdraw test fails at `:204` and `:236`, showing `99900099900099900099 != 0`." Aggregate 173/2/0 at `:271`.

### Grok (`grok-req06-confirm.md`, 27 lines)

- **Headline:** "One test gap remains. The production change matches the ruling."
- **Finding:** "Stale test expectation" at `SharedFacet.t.sol:182` and `:185-186`. "The prescribed directory run cannot pass. After the 100 ether deposit, the unchanged `maxWithdraw` is the preview of the share balance, not a receipt cap of 0."
- **Fix direction:** "Expect `maxWithdraw(u)` to equal `previewRedeem` of that share balance, and expect the withdraw rejection to use that maximum. Do not change production. Do not add a shortfall branch or a receipt cap."

### Kimi (`kimi-req06-confirm.md`, 44 lines)

- **Headline:** "the source edits match the plan, but a gap remains — the plan's retained zero-`maxWithdraw` assertion is incompatible with the amended rule, and validation is red."
- **Finding — F1:** "plan/acceptance inconsistency surfacing as a failing test — not a production defect." File/line: `SharedFacet.t.sol:182` (`assertEq(maxWithdraw(u), 0)`), with `:185-186` failing next in line. "In this fixture the user deposited 100 ether into a paused wrapper with local booked backing — so `previewRedeem(balance)` prices against `_totalReceiptBacking()` and returns ≈ `99900099900099900099`, not 0."
- **Fix direction:** "a coordinator/owner decision on the fixture's remaining assertions — either update the SharedFacet test's `maxWithdraw` expectation to `previewRedeem(balance)` and rework the `withdraw(1)`-reverts expectation to match, or refit the fixture so backing is truly absent (both are test-side; production stays). Not a silent edit: the plan currently says 'leave' those lines, so the plan text must be amended by the coordinator first."

### Mine (this session's `minimax-req06-confirm.md`)

- **Headline:** "Implementation gap remains."
- **Finding — Confirm-REQ06-2:** "Test gap: `maxWithdraw` assertion at `SharedFacet.t.sol:182`." The plan explicitly said to leave the `maxWithdraw` assertion unchanged. Under the new `maxRedeem` behavior (returns the full share balance), `maxWithdraw(u) = previewRedeem(maxRedeem(u))` is non-zero. The assertion at `:182` expects `0`, but the actual return is `99900099900099900099`.
- **Fix direction:** Update the `maxWithdraw` assertion at `SharedFacet.t.sol:182` to expect `previewRedeem(IERC20(se2).balanceOf(u))` (= `99900099900099900099`).

---

## One closed test fix

The user asked: "If the only remaining gap is the stale `maxWithdraw` assertion, say so and give one closed test fix. Do not restore a cap."

**Yes, the only remaining gap is the stale `maxWithdraw` assertion at `ReceiptBackedERC4626_SharedFacet.t.sol:182` (and the `withdraw(1)` expectation at `:185-186`).**

**One closed test fix:**

In `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol`, change lines `:182`, `:185-186`:

```solidity
182:         assertEq(IERC4626(se2).maxWithdraw(u), 0, "zero receipt-exit capacity");
185:         vm.expectRevert(abi.encodeWithSelector(IERC4626Errors.ERC4626ExceededMaxWithdraw.selector, u, uint256(1), uint256(0)));
186:         IERC4626(se2).withdraw(1, u, u);
```

to:

```solidity
182:         assertEq(
183:             IERC4626(se2).maxWithdraw(u),
184:             IERC4626(se2).previewRedeem(IERC20(se2).balanceOf(u)),
185:             "maxWithdraw follows previewRedeem of the share balance"
186:         );
187:         vm.expectRevert(abi.encodeWithSelector(
188:             IERC4626Errors.ERC4626ExceededMaxWithdraw.selector,
189:             u,
190:             uint256(1),
191:             IERC4626(se2).previewRedeem(IERC20(se2).balanceOf(u))
192:         ));
193:         IERC4626(se2).withdraw(1, u, u);
```

The new `maxWithdraw(u)` is the preview of the user's share balance (≈ `99900099900099900099`). The `withdraw(1)` rejection uses that same maximum as the third argument to `ERC4626ExceededMaxWithdraw`. No receipt cap is restored; no shortfall branch is added.

The rest of the test is unchanged. The test still verifies that `withdraw(1)` reverts, but the revert's `max` argument is the new full-balance preview, not zero.

---

## What would change this answer

I would re-open the answer only if:

1. The production change is wrong (e.g., `maxRedeem` does not return the share balance). — Not true. All four reviewers confirm the production change is correct.
2. The gap is a production defect, not a test expectation. — Not true. The gap is a stale test expectation at `SharedFacet.t.sol:182`. The production change is verified correct.
3. A receipt cap, smaller-share search, or shortfall branch was added. — Not true. The execution report at `:10` and all four reviewers confirm none was added.
4. The fix is a production change, not a test change. — Not true. The fix is a test assertion change at `SharedFacet.t.sol:182`.

None of these is true. The closed test fix stands.

---

## Dissent or unresolved items

**Dissent from none of the peers.** All four converge on "the only remaining gap is the stale `maxWithdraw` assertion." The variance is in emphasis:
- **Astra** explicitly says the plan text must be amended by the coordinator first (the plan said "Leave the `maxWithdraw` assertion," which was incompatible).
- **Grok** is the most direct: "Expect `maxWithdraw(u)` to equal `previewRedeem` of that share balance, and expect the withdraw rejection to use that maximum."
- **Kimi** also says the plan text must be amended by the coordinator first; the fix is a coordinator/owner decision on the fixture's remaining assertions.
- **Mine** specifies the exact line numbers and the exact assertion change.

**Unresolved item:** None. The closed test fix in §"One closed test fix" is the single converged shape.

---

## Files examined (this cross-review)

- `docs/reviews/apex-req-06-max-redeem/reviewers/astra-req06-confirm.md` — read in full (84 lines).
- `docs/reviews/apex-req-06-max-redeem/reviewers/grok-req06-confirm.md` — read in full (27 lines).
- `docs/reviews/apex-req-06-max-redeem/reviewers/kimi-req06-confirm.md` — read in full (44 lines).
- `docs/reviews/apex-req-06-max-redeem/reviewers/minimax-req06-confirm.md` — re-read for self-consistency. Not treated as a peer.

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.