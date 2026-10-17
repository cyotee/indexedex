# MiniMax M3 — REQ-04 plan cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One cross-review on which production functions must change for REQ-04. Test edits are the PRD's six files (consensus). Production edits are the open question.
- **Method:** Read all three peer plan originals (`astra-req04-plan.md`, `grok-req04-plan.md`, `kimi-req04-plan.md`). Re-read the cited quad preview lines and the underlying math that the previews delegate to. Update my first-pass plan's incorrect verdict on the quad families.
- **Forge:** Not run.

---

## 1. The disagreement — which production functions must change

Three of four reviewers (Astra, Grok, Kimi) say two of the six previews need production changes. My first-pass plan said none need changes. The majority is correct; I was wrong on the quad families. The disagreement is on the exact shape of the edit, not on whether one is needed.

| Family | Astra | Grok | Kimi | Mine (first pass) | Verdict |
|---|---|---|---|---|---|
| Weighted | no edit | no edit | no edit | no edit | **consensus: no edit** |
| Dual | no edit | no edit | no edit | no edit | **consensus: no edit** |
| Single-CP | no edit | no edit | no edit | no edit | **consensus: no edit** |
| Orbital | no edit (test fix only) | no edit | no edit | no edit | **consensus: no edit** |
| Balancer-quad | **edit** (new `previewSingleJoinExactInShares` Math fn + `_quoteSingleJoinExactInPreview` Core wrapper) | **no edit** | **edit** (`Math.unbalancedJoinShares:291` guard + execution `ZeroAmount` guard) | no edit | **edit required** |
| Curve-quad | **edit** (same as Balancer) | **edit** (`_entryPreviewJoinSingleAssetExactIn` zero-rounding guard) | **edit** (`Math.singleJoinExactInShares:463-465` → return 0; + execution `ZeroAmount` guard) | no edit | **edit required** |

I update my view to agree with the three peer reviewers: **both quad math paths revert for a one-unit zero-rounded input and must be changed to return 0.** Evidence re-read this period:

- `UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol:455` — `if (D1 <= D0) revert MathDomain();`
- `UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol:463` — `if (D2 <= D0) revert MathDomain();`
- `UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol:465` — `if (shares == 0) revert ZeroAmount();`
- `UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol:291` — `return FixedPointMathLib.fullMulDiv(supply, _invariant(next, amp, false) - currentD, currentD);` — unchecked underflow path; in Solidity 0.8.x the subtraction reverts on a negative post-fee invariant (the fee trim at lines 287–290 can drive it negative for tiny inputs).
- The Balancer-quad preview delegates through `_entryPreviewDepositSingle` (`:283-289`) → `_entryPreviewJoinSingleAssetExactIn` → `Math.singleJoinExactInShares` → `Math.unbalancedJoinShares` at the same Math file.
- The Curve-quad preview delegates through `_entryPreviewDepositSingle` (`:439-445`) → `_entryPreviewJoinSingleAssetExactIn` → `Math.singleJoinExactInShares` at lines 431–465 of the same Math file.

My first-pass plan was wrong on both quad families. I retract "no production edit" for Balancer-quad and Curve-quad.

---

## 2. Disagreement on shape — how the edit should be done

The three peer reviewers propose different edits for the quad families. The choices differ on whether the edit lives in shared Math or in a preview-only path, and whether the execution guard is added.

- **Astra** — adds a new `previewSingleJoinExactInShares` in each Math file with the same numeric formula, plus `_quoteSingleJoinExactInPreview` in each Core that dispatches to it. Does not modify the existing strict execution math. Does not add an execution guard; the existing execution math is unchanged and keeps its current revert path.
- **Grok** — addresses only Curve-quad. Says change `_entryPreviewJoinSingleAssetExactIn` so zero-rounded returns 0; does not add an execution guard (the existing execution still reverts `ZeroAmount`).
- **Kimi** — surgical edits to the existing Math functions: Balancer-quad `Math.unbalancedJoinShares:291` adds a pre-subtraction `if (nextD_ <= currentD) return 0;`; Curve-quad `Math.singleJoinExactInShares:463` becomes `if (D2 <= D0) return 0;` and line 465 is deleted. Because the Math is shared by execution, Kimi also adds `if (shares == 0) revert ZeroAmount();` in each Core's `_joinSingleAssetExactIn` to preserve the named selector on the execution side.

All three are valid. The cleanest, least-invasive shape is **Kimi's**: edit the existing Math to return 0 in the zero-rounded path, and add a small `ZeroAmount` guard in each Core's execution so the test's named selector is preserved. Astra's two-track approach is cleaner conceptually (separate preview vs. execution math) but introduces two new functions per family. Grok's coverage is incomplete (Curve-quad only) and conflates preview and execution shapes.

I adopt Kimi's shape as the consensus resolution and pin the one sentence accordingly.

---

## 3. The one sentence the plan must use for production edits

> Edit `UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.unbalancedJoinShares` to return 0 when the post-fee invariant is not strictly greater than the current invariant (guard placed before the unchecked subtraction at line 291), edit `UniswapV4StandardExchangeCurveQuadStableBufferHookMath.singleJoinExactInShares` to return 0 instead of reverting `MathDomain` at lines 455 and 463 and `ZeroAmount` at line 465, and insert `if (shares == 0) revert ZeroAmount();` in `_joinSingleAssetExactIn` of each Core (`UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore` after the quote at line 304; `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore` after the quote at line 466) so the execution still reverts with the test's named selector.

This sentence captures: (a) Balancer-quad Math edit, (b) Curve-quad Math edit, (c) both execution guards. It does not introduce a new revert selector. It does not modify `singleJoinExactIn` itself. It does not touch `singleJoinExactInShares` line numbering assumptions beyond what Kimi's plan already cites.

---

## 4. Items I am not asserting

- I am not asserting that Balancer-quad's preview never reverts under any other condition (e.g., `NotFullBook` at `:301`). The PRD's owner ruling is scoped to the one-unit zero-output case; other reverts are out of scope.
- I am not asserting that Balancer-quad's `_invariant(next, amp, false) - currentD` subtraction is wrapped in `unchecked`. It is not — Solidity 0.8.x default checked arithmetic applies. If a future edit wraps this in `unchecked`, the guard at the top of the new shape must keep the existing semantics for the non-zero case.
- I am not asserting any change to the four non-quad families. The consensus is no production edit for weighted, dual, single-CP, and orbital. My first-pass plan is correct for those four.
- I am not asserting any change to `singleJoinExactInShares`'s strict execution semantics on the non-quad families (weighted/dual/curve-quad already return 0 or revert appropriately per their own PRD); the changes here are scoped to the two quad Math files named above.

---

## 5. Test edits — the PRD's six files, all reviewers converge

The test edits are not in dispute. All three peers and my first pass agree on the same shape:

- Siblings (dual, single-CP, orbital, balancer-quad, curve-quad): delete the `previewMatch` allowance; require the static preview to succeed and decode to 0; expect the named selectors `InsufficientTokenOut()` or `ZeroAmount()`; delete the successful zero-share retention branch.
- Weighted: delete the `!previewOk → expectRevert(previewRet)` branch; require preview to succeed and decode to 0; expect `MinAmountNotMet(uint256,uint256)` with `(1, 0)`; success branch already asserts exact shares.
- All six share sites: capture the family's exact-output preview for `wantOut` before the call; replace `assertLt(_hookSeShares…, seBefore, …)` with `assertEq(_hookSeShares…, seBefore - expectedDebit, …)` where `expectedDebit` is the shares the SE would burn for `wantOut`.

Astra adds a `bytes` argument correction to the orbital preview call (the installed selector is two-arg, the test calls three-arg). Kimi and my plan do not flag this. I record it as a noted disagreement; the PRD cites the orbital share site at `:368` and the rounding control at `:308-309` without specifying the selector shape. If the orbital test's staticcall is `previewDepositSingle(address,uint256,bytes)`, then the test should be corrected to `previewDepositSingle(address,uint256)`. **Implementer: re-read the orbital rounding control at `:290-326` and verify the selector; if it is three-arg, change to two-arg.** This is a test-only correction, not a production edit.

---

## 6. Forge-artifacts command — consensus with one open parameter

All three peers agree the test roots are the six family directories (or the test files within them). The disagreement is on positional sources:

- **Astra** — names the four edited production files (the two quad Math files and the two quad Core files) as positional, alongside the six test roots.
- **Grok** — names only the Curve-quad JoinCore as positional (one file), alongside the six test roots.
- **Kimi** — names the four edited production files (the two quad Math files and the two quad Core files) as positional, alongside the six test roots.
- **Mine (first pass)** — no positional sources, only test roots.

The PRD's "Production" section says: "If a named family's `previewDepositSingle` reverts for this one-unit zero-output case, change that preview to return 0." Production IS edited for the two quad families. The canonical `ARTIFACT_BUILDS.md` pattern names edited production sources as positional. Per the cross-PRD evidence from the REQ-SEP-01 cross-review, the canonical pattern is `python3 scripts/forge-artifacts.py test <edited-source.sol> --test-root <test-file-or-directory> -- -vv`.

**The one command the plan must use:**

```bash
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve \
  -- -vv
```

Four positional production sources (the two quad Math files and the two quad Core files). Six test roots. No `via_ir`. No `out/`/`cache_forge/` deletion. Warm seed for new worktrees (CLAUDE.md items 8–9).

---

## 7. Stop conditions — consensus

The stop conditions across the four plans agree on:

1. Line drift at any cited PRD line.
2. Gain/loss of `previewMatch` outside the six files.
3. Gain/loss of the `assertLt(_hookSeShares…, seBefore, "SE shares burned only for the delivered face");` pattern at the six refund-test tails.
4. Gain/loss of the production revert at `Math.singleJoinExactInShares:455/463/465` or the underflow at `Math.unbalancedJoinShares:291`.
5. New revert selector invented.
6. Excluded `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` touched.
7. Zero-share retention re-introduced in any sibling rounding control.

I add one more for the orbital selector discrepancy:

8. The orbital rounding control's `previewDepositSingle` staticcall uses a selector that does not match the installed facet. Stop; change the test call to the installed selector before proceeding.

---

## 8. Files examined (this cross-review)

- `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.md` — read in full.
- `docs/reviews/apex-req-04-rounding-controls/reviewers/astra-req04-plan.md` — read in full.
- `docs/reviews/apex-req-04-rounding-controls/reviewers/grok-req04-plan.md` — read in full.
- `docs/reviews/apex-req-04-rounding-controls/reviewers/kimi-req04-plan.md` — read in full.
- `docs/reviews/apex-req-04-rounding-controls/reviewers/minimax-req04-plan.md` — re-read for self-consistency. Not treated as a peer.
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol` — re-read lines 270–330.
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol` — re-read lines 280–310.
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol` — re-read lines 396–480 and 512–550.
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol` — re-read lines 435–495.

No Forge / build / test was executed.

---

I did not run Forge.