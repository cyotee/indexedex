# MiniMax M3 — REQ-04 plan draft (replacement-session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity.
- **Controlling PRD:** `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.md`. Read in full.
- **Files read:** PRD; six `*SeMatrixBehavior.sol` rounding controls at cited lines; six production `previewDepositSingle` entry points (one per family) and the internal previews they delegate to (`weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:_quoteSingleJoinExactIn`, `dual/.../Common.sol:_previewDepositSingle`, `constantProduct/single/.../Target.sol:previewDepositSingle`, `orbital/.../DepositQueryTarget.sol:previewDepositSingle`, `stable/quad/balancer/.../QueryTarget.sol:previewDepositSingle`, `stable/quad/curve/.../JoinQueryTarget.sol:previewDepositSingle`).
- **No production edit unless stated below.** No `catch`. No new revert selector invented.
- **Excluded:** `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` is not in the PRD table. Do not touch it.
- **Forge:** Not run.

---

## Per-family: does `previewDepositSingle` already return 0?

One sentence per family, naming the exact function only if a production edit is required.

- **Weighted.** `UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget.previewDepositSingle` → `_entryPreviewDepositSingle` → `_quoteSingleJoinExactIn` → pure math (`Math.singleJoinExactInShares[Uncapped]`). Math returns 0 for a zero-rounded output and does not revert. **Preview already returns 0.** No production edit.
- **Dual.** `UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget.previewDepositSingle` → `Common._previewDepositSingle` → `DepositQuoteLib.preview(...)` / `DepositQuoteLib.previewLegacy(...)`. The guards `_requireZapEligible()` and `_requireNonZero(amountIn)` are satisfied for `amountIn == 1` on a buffered pair. The library returns 0 for a zero-rounded output and does not revert. **Preview already returns 0.** No production edit.
- **Single-CP.** `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.previewDepositSingle` (line 1338) explicitly returns 0 via `if (otherOut == 0 || kept == 0) return 0;` (line 1344). **Preview already returns 0.** No production edit.
- **Orbital.** `UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget.previewDepositSingle` → `_entryPreviewDepositSingle` (in `…/OrbitalBufferHookDepositCore.sol`). The preview path is math-only (no guard that would revert on a zero-rounded three-leg zap). **Preview already returns 0.** No production edit.
- **Balancer-quad.** `UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget.previewDepositSingle` → `_entryPreviewDepositSingle` (in `…/BalancerQuadStableBufferHookJoinCore.sol`). The four-leg stable math returns 0 for a zero-rounded single-asset zap and does not revert. **Preview already returns 0.** No production edit.
- **Curve-quad.** `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget.previewDepositSingle` → `_entryPreviewDepositSingle` (in `…/CurveQuadStableBufferHookJoinCore.sol`). Same shape as Balancer-quad. **Preview already returns 0.** No production edit.

**Production rule:** none of the six previews require a code change for the zero-rounded case. If, at execution time, any preview reverts instead of returning 0, **stop and report** (do not edit production under this plan).

---

## Test edits — ordered, six identical-shape changes plus one weighted-only edit

The pattern is identical in shape across all six files. Apply per family.

### A. Rounding-control helper (`_roundingToZeroControl`) — all six

For the **five siblings** (dual, single-CP, orbital, balancer-quad, curve-quad):

1. Delete the `bool previewMatch = !previewOk && previewRet.length >= 4 && sel == bytes4(previewRet);` line.
2. Change `assertTrue(named || previewMatch, "dust rejection is ZeroAmount or InsufficientTokenOut");` to `assertTrue(named, "dust rejection is ZeroAmount or InsufficientTokenOut");`.
3. Replace the `if (!previewOk) { vm.expectRevert(previewRet); … return; }` branch with the shape used by `previewOk && preview == 0`: call the deposit, expect `InsufficientTokenOut()` or `ZeroAmount()` (the named selectors are already pinned in each file at the cited line).
4. The success branch already handles `if (shares == 0) { … hook balance OR book retains dust }` for siblings. Per the PRD owner ruling, **delete it**: a successful zero-share retention is not allowed. Sibling dust outcomes are revert-only.

For **weighted** (`:216-225`):

1. Delete the `if (!previewOk) { vm.expectRevert(previewRet); … }` branch.
2. Keep the `else { preview == 0 → expectRevert(MinAmountNotMet(1,0)) }` branch.
3. The `else { preview > 0 → success }` branch already asserts `shares == preview`, `1` taken, `shares > 0`. Keep it. The weighted hook's `_commitJoin` already reverts with `MinAmountNotMet(1, 0)` on `shares == 0`; no zero-share branch exists or is added.

### B. Share assertion — all six

For each `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed`, at the cited share site (weighted `:282`, dual `:380`, single-CP `:345`, orbital `:368`, balancer-quad `:397`, curve-quad `:345`):

1. Before the pretransfer call, capture the family's exact-output preview for the delivered output: `uint256 expectedBurn = <family's previewExchangeOut of seUT for wantOut, expressed in shares>`. The shape per family is the SE's standard `previewWithdraw(wantOut)`-equivalent on the SE diamond (`seUT`), or `hook.previewWithdrawSingle(face, …)` (weighted already uses this at line 380 of the join flow). Capture once.
2. Replace `assertLt(_hookSeShares(), seBefore, "SE shares burned only for the delivered face");` with `assertEq(_hookSeShares(), seBefore - expectedBurn, "SE shares burned match the exact-output preview");` (orbital: use `_hookSeShares(0)`).

The exact share-burn expression is a function call on the production code, not a constant; the implementer picks the right one per family.

---

## Forge-artifacts command — one

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve \
  -- -vv
```

Hermetic profile, no `via_ir`, no `out/` or `cache_forge/` deletion, warm seed required for new worktrees (CLAUDE.md items 8–9). No production source is named as a positional because no production source is edited.

---

## Stop conditions

1. **Line drift.** Any cited line in the PRD table (`:216-225`, `:282`, `:321-322`, `:380`, `:286-287`, `:345`, `:308-309`, `:368`, `:338-339`, `:397`) no longer contains the cited text. Stop and report.
2. **Sibling shares sites.** Any of the five sibling files gains or loses the `assertLt(_hookSeShares(), seBefore, "SE shares burned only for the delivered face");` pattern at the refund-test tail. Stop and report.
3. **Production preview reverts.** At test time, any of the six `previewDepositSingle` calls returns a revert for the `amountIn == 1` zero-rounded case instead of returning 0. Stop; do **not** edit production under this plan.
4. **Production edit requested.** If anyone asks to change `_entryPreviewDepositSingle` / `_quoteSingleJoinExactIn` / `DepositQuoteLib.preview` / `DepositQuoteLib.previewLegacy` / `_singlePreviewDeposit` / the orbital/balancer/curve entry previews as part of this item. Stop; this plan says none of them need a change.
5. **New revert selector.** If anyone proposes adding a custom revert selector for the dust case. Stop; the PRD forbids it and the named selectors are already pinned.
6. **Excluded file touched.** If `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` is modified. Stop; the PRD excludes it.
7. **Zero-share retention re-introduced.** If any sibling rounding-control branch is edited to keep `if (shares == 0) { … }`. Stop; the owner ruling forbids successful zero-share retention.

---

## Files examined

- `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.md` — read in full.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` — `:140-241`, `:260-285`, `:340-385`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` — `:300-340`, `:355-385`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` — `:265-305`, `:320-350`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` — `:285-330`, `:345-370`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` — `:315-360`, `:370-400`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` — `:265-305`, `:320-350`.
- Production `previewDepositSingle` entry points and the internal previews they delegate to: six files as named above. Confirmed each preview returns 0 for a zero-rounded output and does not revert; none requires a production change under this item.

No Forge / build / test was executed.

---

I did not run Forge.