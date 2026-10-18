# MiniMax M3 — REQ-06 requirements check (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Targeted requirements check only. Not a new review round. Per the user: the owner ruling controls; maxRedeem returns the account's share balance; no smaller-share search; no shortfall case; the claimable value follows the deployed reserve; do not reintroduce a receipt cap.
- **Inputs read:** `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` (55 lines, full).
- **No code edit. No PRD write. No Forge. No exploit procedures.**

---

## Answer — No blocking question. Ready.

The PRD's two requirements (REQ-06-1 production, REQ-06-2 tests) are fully specified. Every implementer decision is pinned by the PRD's acceptance criteria, the owner ruling, or the non-goals. No policy, scope, or product decision is left open. The owner is ready to authorize implementation; this requirements check is the last gate before the implementer draft.

---

## Evidence by item

### 1. REQ-06-1 — Return the share balance

The PRD at `:23-30` specifies:

- **File and line:** `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:74-81`. The helpers at `:173-196` exist only for the withdrawn search.
- **Intended behavior:** After `_requireFamily()`, return `ERC20Repo._balanceOf(owner)`.
- **Acceptance criteria:**
  1. "Replace that search with `return ERC20Repo._balanceOf(owner);`." — exact code line pinned.
  2. "Delete `_redeemFitsReceipts` and `_largestRedeemableShares`." — exact helper names pinned.
  3. "Do not add a receipt check, a shortfall branch, or a smaller-share search anywhere in this item." — three prohibitions, each spelled out.

The production change is one line of code plus two helper deletions. There is no product decision left to the implementer: the function body after `_requireFamily()` is exactly `return ERC20Repo._balanceOf(owner);`. The two helper functions are removed wholesale.

### 2. REQ-06-2 — Tests expect the balance

The PRD at `:36-46` specifies:

- **Files and lines:**
  - `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol:202-211` and `:233`
  - `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:183` and `:187-188`
- **Intended behavior:** `maxRedeem` equals the account's share balance.
- **Acceptance criteria:**
  1. "Assert `maxRedeem` equals the owner's share balance in those tests." — exact assertion shape.
  2. "Delete assertions that the result is smaller than the balance or zero because receipts are limited." — exact deletion target.
  3. "Delete the `redeem(1)` expectation of `ERC4626ExceededMaxRedeem` with a maximum of 0." — exact test step to remove.
  4. "Leave `test_maxRedeem_fullBalancePayableAtNonIntegralRate`. It already expects the balance." — preserve.
  5. "Leave `APEX_D46_CapacityFixtures.t.sol:83`. That is a different contract." — preserve.

The test changes are bounded: specific test files, specific line ranges, specific assertion shapes, specific tests to leave. No choice about what to change or what to keep.

### 3. Non-goals

The PRD at `:31, :47` (non-goals):

- REQ-06-1 non-goal: "Do not change `previewRedeem`, `maxWithdraw`, `redeem`, or `withdraw`. Do not add a public selector."
- REQ-06-2 non-goal: "Do not add a shortfall test. Do not change `ShortRedeemERC4626`."

These pin what is NOT to be done. The implementer has no freedom to add a shortfall branch, add a receipt check, introduce a smaller-share search, add a public selector, or redesign `ShortRedeemERC4626`.

### 4. Owner ruling

The PRD at `:17-19` records the owner's ruling:

> "The claimable value already follows the deployed reserve. The vault is not short of receipts. There is no smaller-share search and no shortfall case to handle. `maxRedeem` is the account's balance."

This is a direct statement of the policy. There is no residual case to handle. The owner has closed the design space.

### 5. Dissent

The PRD at `:49-51` records that the earlier draft of this PRD "treated a short receipt balance as a remaining failure. That was wrong. The owner rejected it." The dissent is historical and is explicitly withdrawn by the owner ruling. No open policy question remains from the dissent.

---

## What would change this answer

This is "No blocking question. Ready." only if every implementer decision is pinned. The answer flips to "one blocking question" if any of the following is true; I checked all five and none is true:

1. The PRD leaves the production code shape open. — Not true. REQ-06-1 at `:28` specifies the exact line: `return ERC20Repo._balanceOf(owner);`.
2. The PRD leaves the helper deletion open. — Not true. REQ-06-1 at `:29` names the two helpers to delete: `_redeemFitsReceipts` and `_largestRedeemableShares`.
3. The PRD leaves the test changes open. — Not true. REQ-06-2 at `:42-44` specifies the exact assertion changes and the exact test step to delete.
4. The PRD leaves a policy question open (e.g., shortfall handling, receipt cap, smaller-share search). — Not true. The owner ruling at `:19` and the non-goals at `:31, :47` close every policy question.
5. The PRD leaves a scope question open (e.g., `ShortRedeemERC4626`, public selectors, other functions). — Not true. The non-goals at `:31, :47` close every scope question.

None of these is true. The answer stands.

---

## Items I am not asserting

- I am not asserting the runtime result. The PRD at `:9` states "No Forge run." No execution is claimed.
- I am not asserting the exact line count of the test edits. The PRD specifies what to assert and what to delete; the implementer inserts or removes the exact lines.
- I am not asserting the state of `APEX_D46_CapacityFixtures.t.sol` or `test_maxRedeem_fullBalancePayableAtNonIntegralRate`. The PRD says to leave them. The implementer verifies they are unchanged.

---

## Files examined (this answer)

- `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` — read in full (55 lines).

No other reviewer files were read. No Forge / build / test was executed. No code was edited.

---

I did not run Forge.