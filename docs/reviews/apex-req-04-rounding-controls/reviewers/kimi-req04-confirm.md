# Kimi K3 — REQ-04 execution confirmation (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. `EXECUTION_REPORT.md` and the in-repo `evidence/` files were treated as untrusted claims; everything marked verified below was checked by direct read of current source. Nothing was edited. I did not run Forge.
- **Inputs:** `REMEDIATION_PRD.plan.md` (96 lines, including the owner-authorized follow-up at `:9-17` that supersedes conflicting original restrictions), `REMEDIATION_PRD.md` (controlling), `EXECUTION_REPORT.md` (102 lines), `evidence/implementation.diff` and `followup-implementation.diff` (file manifests sighted), current production and test sources.

## Verdict: executed accurately, including the owner-authorized follow-up. One Low documentation note (F1); no execution gap.

## Production verification (direct reads this pass)

| Requirement | Result | Evidence |
|---|---|---|
| Balancer-quad preview-only math added; returns 0 before any unsigned subtraction | done | `…BalancerQuadStableBufferHookMath.sol:305-324` — same formula as strict join, `amount == 0 → return 0` (`:311`), `nextD <= currentD → return 0` (`:322`) ahead of the subtraction at `:323` |
| Curve-quad preview-only math added | done | `…CurveQuadStableBufferHookMath.sol:469-504` — strict book validation kept, `amountInWad == 0`/`D1 <= D0`/`D2 <= D0` return 0 (`:484, :494, :502`), no zero-share revert |
| Strict quad math unchanged | done | Curve strict `singleJoinExactInShares` at `:431-466` is byte-identical to my pre-execution read (both `MathDomain` reverts and the `:465` `ZeroAmount` revert intact). Balancer strict `unbalancedJoinShares`/`singleJoinExactInShares` shapes at `:277-302`+ match my pre-execution read |
| `_entryPreviewDepositSingle` routed through the new preview quote | done | Balancer `LiquidityCore.sol:288`; Curve `JoinCore.sol:448` |
| Execution quote routed through the zero-aware quote with `ZeroAmount()` before input transfer (amendment item 1) | done | Balancer `LiquidityCore.sol:305-306` (guard before `_pull`/`_pullAmounts` at `:308-316`); Curve `JoinCore.sol:471-472`. The `_quoteSingleJoinExactInPreview` helpers (`LiquidityCore:352-377`, `JoinCore:507+`) reuse the existing input/scale/supply/fee steps and dispatch to the preview-only math |
| Dual zero-sale early return (amendment item 2) | done | `…DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol:130-131` — `if (sale == 0) return (amountIn, 0);` before the SE `DepositExactIn` transition at `:137` |
| Weighted / single-CP / orbital production not edited | done | Spot-checks match my pre-execution reads exactly: weighted `Math.sol:348-355` (`return 0` comment path), single-CP `InQuoteBase.sol:58-67`, orbital `Common.sol:2156-2162`. Neither evidence diff lists any file in those families |
| No new revert selector | done | The added guards use the already-named `ZeroAmount()`; no new error declaration appears in the diffs' file set |
| Excluded non-CP test file unchanged | done | `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` appears in neither diff and carries none of the new assertion text |

## Test verification (six named behavior files + amendment fixtures)

- All six controls assert the preview succeeds and decodes to 0 (`assertTrue(previewOk)` + `assertEq(abi.decode(previewRet,(uint256)), 0)` — dual `:306-307`, single-CP `:276-277`, orbital `:320-321`, balancer-quad `:350-351`, curve-quad `:276-277`, weighted `:221-222`).
- No `previewMatch` and no `expectRevert(previewRet)` remain anywhere in the six files (repo grep).
- Quad controls require exactly `ZeroAmount()` (balancer `:363`, curve `:289`), per amendment item 4; dual/single-CP/orbital keep the named-selector assertion minus `previewMatch` (`assertTrue(named, …)` at dual `:324`, single-CP `:290`, orbital `:334`); weighted keeps `MinAmountNotMet(uint256,uint256)` `(1, 0)` (`:224`).
- Orbital's preview staticcall now encodes the installed two-argument selector (`:318`) while execution keeps the real six-argument `depositSingle` (`:325-327`) — the arity fix.
- All six share sites use the exact reconciliation: `expectedDebit` captured from the face-leg SE's `previewExchangeOut` before the call, and `seBefore + _faceSharesMintedToHook()` vs `seAfter + expectedDebit` equality (e.g. weighted `:260, :273`; orbital uses `seUT0`/`face0`/`_hookSeShares(0)` at `:374, :383`). No `assertLt` strict-decrease survives in the six.
- The three amendment fixture files (orbital RebasingAware; balancer SimpleYield F6/F9) are in the follow-up diff, as authorized by item 3.

## The stop-condition episode was handled correctly

The original run stopped exactly as the plan ordered: 17 rounding-control failures recorded with selectors (`MathDomain()` `0x00bf0cb2` on curve rows, `Panic(uint256)` `0x4e487b71` on the balancer RebasingAware row — the precise failure modes the plan cross-review predicted from source), no assertion weakened, no selector added, then the owner authorized the follow-up. Procedure was honored.

## Execution evidence status

In-repo evidence (`evidence/followup-results.json`, logs, diffs) is internally consistent: focused 175/175, full 3,642/3,642 across 383 suites, including all 17 previously failing rows. These are recorded claims, not an independent rerun — I ran nothing — but unlike prior rounds the evidence is inside the repository and sighted directly, and every source-level claim I could check independently (the full production and test surface above) matched.

## Finding

### F1 — Plan's "Done when" line conflicts with its own amendment (documentation only)

- **Severity:** Low.
- **File and line:** `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.plan.md:91` vs `:13-14` (amendment items 1–2).
- **Intended behavior:** the plan's acceptance list should reflect the amended scope.
- **Broken invariant:** `:91` still says "Weighted, dual, single-CP, and orbital production are unchanged," while amendment item 2 (which `:11` says supersedes conflicting restrictions) authorizes and the execution performed the dual `DepositQuoteLib._swap` change. The execution followed the amendment; the stale line could confuse a later reader into scoring the dual edit as a violation.
- **Impact class:** documentation accuracy; no code effect.
- **Fix direction:** annotate `:91` as superseded by the amendment (one line; no content change). Optional hygiene.
- **Confidence:** high.

## Conclusion

Complete. Both quad preview paths return zero via the new preview-only functions, both execution joins reject zero shares with the named `ZeroAmount()` before taking input, the six named tests carry the strengthened controls (plus the authorized fixture controls), the orbital preview selector is fixed, weighted/dual/single-CP/orbital production is untouched except the amendment-authorized dual `_swap` guard, and the stop-condition episode was handled by the book. The only residual is F1's stale acceptance line. I do not invent further work.

I did not run Forge.
