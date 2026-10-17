# MiniMax M3 — REQ-H03 owner-question answer (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Targeted requirements check only. Not a new review round. Per the user's framing: the owner ruling supersedes the earlier panic-only agreement; the question is whether any requirement still leaves the implementer a choice.
- **Inputs read:** `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md` in full (59 lines). No peer files were read.
- **No code edit. No PRD rewrite. No Forge.**

---

## Answer — No blocking question

The PRD's two requirements (REQ-H03-1 production, REQ-H03-2 test) are fully specified. Every aspect the implementer would need to choose is pinned by the PRD's acceptance criteria, the owner ruling, or the non-goals. No product, scope, selector, parameter, code shape, import path, or stop condition is left open.

---

## Evidence by item the owner asked about

### 1. REQ-H03-1 — production change in `ERC20Repo._burn`

The PRD's acceptance criteria pin every line of the production change (`:30-36`):

- **Read order:** read `currentBalance` before changing storage. (`:31`.)
- **Condition:** `currentBalance < amount`. (`:32`.)
- **Revert:** `IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount)`, with the selector from `lib/crane/contracts/tokens/ERC20/IERC20Errors.sol:16`. (`:32, :28`.)
- **Write order on pass:** set `balanceOf[account] = currentBalance - amount`, then `totalSupply -= amount`, then emit the existing `Transfer` to `address(0)`. (`:33`.)
- **Delete both:** the commented `_decreaseBalanceOf` call and the inline `balanceOf[account] -= amount`; do not keep both. (`:34`.)
- **Do not call `_decreaseBalanceOf`.** The PRD explicitly names the reason — the helper also reverts `ERC20InvalidSender` for `address(0)`, and this item does not add that check. (`:35`.) The implementer is told **not** to add the `address(0)` guard.
- **Out of scope:** `_mint`, `_transfer`, and `_decreaseBalanceOf` are not changed. (`:36`.)

The non-goals (`:37`) further pin: do not weaken the burn, do not add a `catch`, do not add a separate supply-short error, do not edit the withdrawn V4 twin, do not treat this as evidence the holder argument is wrong. The PRD explicitly acknowledges the supply-subtraction panic edge case ("A supply subtraction that is shorter than the checked balance may still panic") and chooses **not** to fix it; the implementer keeps `totalSupply -= amount` as-is.

The `address(0)`-vs-helper choice is the one place a reader could wonder whether the implementer should add the `address(0)` check. The PRD closes it explicitly at `:35`: "Do not call `_decreaseBalanceOf`. … This item does not add that check."

### 2. REQ-H03-2 — test change at `UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`

The PRD's acceptance criteria pin every aspect of the test edit (`:46-50`):

- **Import:** `IERC20Errors` from `@crane/contracts/interfaces/IERC20Errors.sol`. (`:46`.)
- **Replacement at line 147:** `vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));`. (`:47`.)
- **Leave unchanged:** the redeem call and the three balance assertions at `:149-151`. (`:48`.)
- **Leave unchanged:** the code-less ordinary-success tests; do not substitute a contract caller. (`:49`.)
- **Stop condition:** if the run reverts with different bytes, stop and report those bytes. Do not broaden the expectation. (`:50`.)

The non-goals (`:51`) further pin: do not expect `Panic(uint256)`, do not edit the withdrawn V4 twin. The owner ruling at `:22` withdraws the earlier panic-only agreement.

The three arguments of the selector — `(holder, 0, 1)` — are fully specified by the test's local variables (`holder = makeAddr("v3Short")` at `:143`, `vault.balanceOf(holder) = 0` at `:144`, `redeem(..., 1, ...)` at `:148`). The selector itself is named in REQ-H03-1 `:28, :32` and is the one declared at `lib/crane/contracts/tokens/ERC20/IERC20Errors.sol:16`.

### 3. Shared-library effect

The production change is at `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365`, a Crane library that backs every share token using `ERC20Repo._burn`. The PRD implicitly accepts the shared-library effect by placing the fix at the library level rather than at a vault-specific facet. Per the user's note, "A shared-library effect that the PRD already states is not a question." Not a question.

### 4. Stop conditions

Two stop conditions are explicit, both in the PRD:

- REQ-H03-2 `:50`: "If the run reverts with different bytes, stop and report those bytes. Do not broaden the expectation."
- The PRD's "Unverified" block (`:57-59`): "If it does not [reach the burn before another revert], stop and report the actual bytes."

Both are stop conditions the implementer honors; neither is an open choice about what to build.

---

## Items I am not asserting

- I am not asserting the runtime result. The PRD's "Unverified" block states no Forge run was performed. I do not rerun.
- I am not asserting the production edit compiles or that the test passes. The PRD pins the shape; runtime is a separate authorized step.
- I am not asserting the supply-subtraction panic edge case is benign or a defect. The PRD explicitly chooses not to address it in this item.
- I am not asserting the import `IERC20Errors` is present in `ERC20Repo.sol` today. The PRD states it "already imports it through `@crane/contracts/interfaces/IERC20Errors.sol`" (`:28`); if that statement is wrong, the implementer adds the import — a mechanical fix, not a product/scope decision.

---

## What would flip this answer

This is "No blocking question" only if every implementer decision is determined by the PRD. The answer flips to "one blocking question" if any of the following is true; I checked all four and none is true:

1. The PRD names a selector or value that is not in the current source and not pinned by production. — Not true. The selector `IERC20Errors.ERC20InsufficientBalance(address,uint256,uint256)` is named in the PRD and exists in the named error library.
2. The PRD requires a code shape that is not fully spelled out. — Not true. REQ-H03-1's acceptance criteria give the exact read/check/write/delete order, the exact revert selector, the exact arguments, the exact three-line emit/write sequence, and what to delete.
3. The PRD leaves a product decision open (e.g., whether to add the `address(0)` check, whether to add a supply-short check, whether to add a `catch`, whether to edit the V4 twin). — Not true. Every one of these is closed by the PRD's non-goals or its explicit "do not" lines.
4. The PRD contradicts itself. — Not true. The "Dissent" block (`:53-55`) is historical and is explicitly superseded by the owner ruling at `:20-22`.

None of these is true. The answer stands.

---

## Files examined (this answer)

- `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md` — read in full (59 lines).

No other reviewer files were read. No Forge / build / test was executed. No code was edited.

---

I did not run Forge.