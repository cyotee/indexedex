# Astra — REQ-04 replacement-session plan cross-review

One cross-review of the supplied original Grok, MiniMax and Kimi drafts together. I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Peer notes are untrusted evidence. No earlier peer cross-review artifact was read. My original `astra-req04-plan.md` remains preserved; the explicit revision below does not rewrite it.

## Decision

**Both quad preview chains require changes.** Dissent from MiniMax's no-production-change conclusion and Grok's Balancer-quad exemption. Agree with Kimi that both quads have zero-rounding problems, but reject its shared-math relaxation as a complete, safely bounded repair: it misses earlier zero-input branches and can change other execution consumers without protecting them.

Weighted, dual CP, single CP and the identified orbital preview path remain **no production edit** for this item on the source evidence inspected. Orbital's test must call the installed two-argument preview selector; its execution still takes the bytes argument. No new production selector is needed to fix that test.

## One sentence the consolidated plan must use for production edits

> Restrict production edits to `UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol` and `UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol` under `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/`, and `UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol` and `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol` under `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`, adding isolated `previewSingleJoinExactInShares` math and `_quoteSingleJoinExactInPreview` core helpers that return zero for validated zero-rounded output, routing each named `_entryPreviewDepositSingle` through its zero-aware path, and using that same path followed immediately by the existing `ZeroAmount()` rejection in each normal pair-input `_joinSingleAssetExactIn` branch before intake, while preserving the existing strict math functions, invalid-input/dependency checks, flexible execution paths and all other production families.

This is a finite four-file recommendation for coordinator adoption, not implementation permission. It closes the preview/execution distinction instead of asking an implementer to decide whether to relax shared math. The exact functions and boundaries are specified below.

## Re-read quad evidence

### Balancer quad

- `UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:283–288` delegates `_entryPreviewDepositSingle` to the shared single-asset quote.
- The quote at **324–348** converts the input to inventory/value units and calls `Math.singleJoinExactInShares`.
- `UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol:298` explicitly reverts `ZeroAmount()` when the converted amount is zero. A positive one-unit external input can convert to zero; checking only the final arithmetic does not cover that case.
- `unbalancedJoinShares:283–291` subtracts one from each post-input balance and finally evaluates `_invariant(next, amp, false) - currentD` without a non-growth guard. If the rounded post-fee invariant is smaller, this is a **checked unsigned subtraction that reverts**, not a zero return. Kimi's label “unchecked subtraction” is inaccurate, although its underflow concern is correct.
- The execution branch at Core **304–316** has only `shares < sharesMin`; zero with a zero minimum is not rejected by that comparison. The existing `_mintLp` returns without minting for zero. A preview fix must therefore not route zero into successful execution.

### Curve quad

- `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:439–445,481–499` reaches `Math.singleJoinExactInShares` through the named preview.
- `UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol` rejects at **439** for zero converted amount, **455** for `D1 <= D0`, **463** for `D2 <= D0`, and **465** for zero final shares.
- Kimi addresses only 463 and 465. Keeping 439 unconditionally strict still prevents a valid positive external input that rounds to zero inventory from receiving a zero preview. Its assertion that `D1 == D0` necessarily means a broken book is not established: an integer invariant can fail to increase for a positive sub-quantum contribution on an otherwise valid book.
- Execution at Core **466–472** likewise checks only `shares < sharesMin` before intake/mint.
- Crucially, the separate flexible commit at Core **584–609** takes funds and calls `_mintLp(to, shares)` without its own zero-share rejection. Relaxing the **shared** strict single-join math and adding a guard only in the normal pair-input execution branch would not establish that every other caller remains safe.

These are source facts, not a Forge reproduction for each matrix fixture. They establish why the previews cannot be declared universally zero-safe from the leaf's final division alone.

## Exact bounded change to adopt

### 1. Keep existing strict functions unchanged

Do not change Balancer `unbalancedJoinShares` or `singleJoinExactInShares`, or Curve `singleJoinExactInShares`, in place. Do not alter general mint helpers, other public join previews, flexible execution commits or the older aggregate liquidity targets. Do not add a catch or convert all `MathDomain`/dependency failures to zero.

### 2. Add isolated preview math in the two named Math files

Use the respective existing single-join signature and numeric algorithm for a separate `previewSingleJoinExactInShares` function. Preserve valid index, fee, supply, reserve and invariant-domain checks. The different treatment is limited to these output-rounding boundaries on valid seeded books:

- Converted amount zero returns zero after structural validation; zero supply or invalid reserves are not silently treated as a valid deposit.
- Balancer: retain the current rounding and fee formulas, compute the final invariant into a local variable, return zero when it is no greater than `currentD`, and perform subtraction only after that comparison. Do not call the old strict single-join wrapper for zero converted amount.
- Curve: return zero when the input rounds to zero inventory, when `D1 == D0`, when post-fee `D2 <= D0`, or when final share division is zero. A pre-fee `D1 < D0` remains the existing invalid-math rejection rather than being assumed ordinary rounding. Keep all remaining fee/index/book checks and positive-result formulas.

This isolates the new preview behavior from other consumers of the strict functions. No newly invented error selector or public facet selector is required.

### 3. Route only the named preview and paired normal execution through it

In each named Core, add `_quoteSingleJoinExactInPreview` with the same input resolution, scaling, fee and supply preparation as `_quoteSingleJoinExactIn`, calling the new preview math. Preserve the current named preview's live/token-classification behavior; retain existing handling of non-pair input rather than broadening supported routes.

For the normal pair-input branch of `_joinSingleAssetExactIn`, replace its quote call with this zero-aware quote and immediately require nonzero shares by reverting the already-defined **`ZeroAmount()`**, before the existing minimum check and any input pull. Keep deadline, receiver, input-zero, live-state, protocol-fee preparation and token-resolution checks in their existing order. Keep the explicit flexible/share-input branch unchanged. This is the narrow companion execution guard needed to ensure that the newly returned preview zero cannot become a retained zero-share success.

**Revision of my original:** my original proposed preview isolation but left strict execution unchanged and flagged a completion limitation. That was not a fully closed execution plan. The companion guard/normal quote substitution above resolves that limitation with an existing selector and a fixed boundary, instead of leaving a known error-shape problem to the implementer. This is an explicit revised recommendation for the coordinator; no code was changed.

## Peer agreements and objections

- **Grok:** Agree on weighted, dual, single CP and orbital no-production-edit conclusions and the need to repair Curve. Reject its Balancer-quad conclusion at `grok-req04-plan.md:19`, contradicted by the zero-amount check and unchecked-for-non-growth calculation above. Its Curve instruction does not state how to bypass strict zero-rounding math without swallowing other failures; use the isolated functions and paired execution guard rather than leave that design open.
- **MiniMax replacement:** Reject `minimax-req04-plan.md:20–23,95` claiming both quads already return zero. The Balancer core is `LiquidityCore`, not the cited `JoinCore`, and the read math contains explicit reverts. Reject its blanket stop against any production repair at 79: the PRD explicitly allows the required preview repair. Its “implementer picks the right [share quote]” at 53 is also not a closed plan.
- **Kimi replacement:** Agree that both quad math/core chains need work and that execution must still reject with an existing named selector. Reject changing shared strict math without covering its other execution consumers, and reject skipping the earlier converted-zero and pre-fee equal-invariant cases. The four-file boundary is appropriate; the isolated implementation above avoids widening that boundary to flexible execution repairs.

## Test scope remains the six PRD files

Do not edit the excluded non-CP behavior. Require successful scalar preview decoding to zero, remove preview-error echo acceptance and zero-share success, and preserve the PRD's exact named error sets and unchanged-balance checks. MiniMax's retained positive-preview success branch does not prove the mandated zero-rounding precondition. No new revert selector is accepted to make a fixture pass.

Retain the original draft's orbital test correction: call `previewDepositSingle(address,uint256)`, not the nonexistent three-argument preview; keep the bytes argument on execution. This is a test correction, not orbital production work.

The SE debit quote must be captured before execution in **SE-share units**, not the hook swap's input units. Do not use `previewWithdrawSingle` on hook LP as an interchangeable quote. Preserve exact input/refund/payout controls. My original warning about lawful mint-back/rebuffering remains: weighted `_unwrapExactTokenOut` can mint SE shares back after a burn, so a gross debit quote and a net balance difference are not automatically identical. The final plan must reconcile any actual mint-back rather than blindly weaken an equality to a decrease or pretend a net/gross mismatch proves an allowance or custody defect.

## Findings and confidence

| Astra finding | Severity / impact | File and line | Intended invariant / fix direction | Confidence |
|---|---|---|---|---|
| **REQ04-X1 — Quad zero previews remain rejecting in the proposed no-edit plans** | Medium / incomplete preview remediation | Balancer Math 291,298; Curve Math 439,455,463,465; peer no-edit conclusions cited above | Valid zero-rounded output must preview as zero; implement the isolated quad paths, not generic catch-and-zero | High on source behavior |
| **REQ04-X2 — Relaxing shared math with only one execution guard can permit other zero-share consumers** | Medium / proposed execution-semantic regression | `kimi-req04-plan.md:12–15`; Curve JoinCore 584–609 | Preview repair must not authorize zero-share retention elsewhere; leave strict shared execution math unchanged and isolate the named path | High on missing guard; conditional runtime impact, not an executed failure |

No new economic choice is requested. Invalid routes and invalid books remain errors; a valid zero-rounded output is the case the owner already decided. If later evidence shows an additional dependency-originated preview failure or source drift, stop and report rather than expanding this four-file design or broadening the selector set.

All supplied original drafts were present. The named quad math/core lines and Curve flexible commit were directly re-read for this cross-review; the PRD's production/testing requirements were re-read. No peer cross-review artifact, shell, delegation, tests or deployments were used. Existing zero-aware branches in weighted/dual/single CP and the identified orbital path have no additional production defect established in this review. The assigned output was absent before this write.

Only this replacement-session Markdown cross-review was created. No code, controlling PRD, final plan, original draft, test, configuration or instruction file was edited.

I did not run Forge.
