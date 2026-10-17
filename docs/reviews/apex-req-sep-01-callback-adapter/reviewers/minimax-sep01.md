# MiniMax M3 — REQ-SEP-01 (replacement-session original)

- **Session:** Labeled replacement. Not continuity. This session does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. Findings are written fresh against the current working tree.
- **Scope:** REQ-SEP-01 only. Controlling text: `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` section "REQ-SEP-01 — Balancer callback regression checks the wrong adapter" (lines 110–120 of that PRD).
- **Source read:** `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`. Helper at lines 108–122. Test at lines 493–520. All five `_assertNoMaxAllowances` call sites inspected.
- **Other reviewer files:** Not read. This is an independent first pass.
- **Forge / build / tests:** Not run. Source-presence observation only.

---

## Finding SEP-01-1 — `_assertNoMaxAllowances` reads storage `adapter`; the RC-01 callback test operates on a different adapter (`locked_`)

- **Severity:** Medium (matches PRD severity).
- **File and line:**
  - Helper definition: `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol:108–122`.
  - Broken call site: `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol:520` (inside `test_RC01_callback_nestedMoneyEntry_hitsAdapterLock_outerSucceeds`, defined at `:493–522`).
  - Other call sites (currently consistent with the helper as-written because they happen to act on the storage `adapter`): `:330`, `:341` (both inside `_assertLargeLiquidation`); `:374` (inside `test_M_allowance_not_max_after_exchangeIn`); `:388` (inside `test_M_allowance_not_max_after_exchangeOut`).
- **Intended behavior (PRD):** September council RC-01. After a successful callback-capable operation on the exercised production adapter, the router and Permit2 allowances of **that** adapter instance must be at zero.
- **Requirement or invariant that appears broken:** The test at `:493–522` calls `_deployProbePool(probe)` at `:495`, which returns a separate adapter instance `locked_` (defined at `:569–617`; deploy bytecode at `:607–616`, salt `…-rc01-probe`). The callback-bearing `exchangeIn` runs against `locked_` at `:511`. Immediately after, at `:520`, the test invokes `_assertNoMaxAllowances(IERC20(address(probe)))`. That helper takes only the token argument and reads `address(adapter)` — the contract's storage variable, which is the adapter set up in `setUp()` (`:73`, via `_deployAdapter`) and is not reassigned in this test. The probe-pool adapter `locked_` and the setUp adapter `adapter` are two distinct CREATE3-deployed instances with different salts and different bindings (locked_ binds to the probe pool; the setUp adapter binds to `daiUsdc8020WeightedPool`). The zero-allowance assertion therefore measures the wrong instance. A passing cleanup assertion does not establish cleanup on the instance under test.
- **Impact class:** Test-oracle correctness. A regression that leaks router/Permit2 approvals on the probe-pool adapter (locked_) would not be observed by this assertion.
- **Fix direction:** See "Exact assertion change" below. The PRD's acceptance criteria specify the assertion must name the adapter that executed the callback route, router and Permit2 allowances for that instance must be zero after success, and the nested-entry lock assertion must remain. The non-goals forbid (a) treating this as a demonstrated production allowance leak and (b) adding a `catch` to clear allowances. Both non-goals apply.
- **Confidence:** High. Source observation only.

### Exact assertion change (no blocking question)

The fix is closed by the PRD's acceptance criteria. There is no remaining owner decision.

1. **Helper signature change.** Change `_assertNoMaxAllowances(IERC20 token_)` (line 108) to `_assertNoMaxAllowances(IStandardExchange adapter_, IERC20 token_)`. Inside the helper body (lines 110, 114, 118, 120, 121), replace each `address(adapter)` with `address(adapter_)`. The three allowance probes and their == 0 / != max semantics stay byte-for-byte identical in shape:

   | Allowance read | Asserter | Assertion |
   |---|---|---|
   | `token_.allowance(address(adapter_), address(router))` | ERC20 | != `type(uint256).max` AND == 0 |
   | `token_.allowance(address(adapter_), address(permit2))` | ERC20 | != `type(uint256).max` AND == 0 |
   | `IPermit2(address(permit2)).allowance(address(adapter_), address(token_), address(router)).amount` | Permit2 packed (`uint160`) | != `type(uint160).max` AND == 0 |

2. **Five call-site updates.** Each becomes `(adapter_, token_)`:

   - `:330` → `_assertNoMaxAllowances(adapter, bpt);`
   - `:341` → `_assertNoMaxAllowances(adapter, bpt);`
   - `:374` → `_assertNoMaxAllowances(adapter, dai);`
   - `:388` → `_assertNoMaxAllowances(adapter, dai);`
   - `:520` → `_assertNoMaxAllowances(locked_, IERC20(address(probe)));` (this is the bug fix; the helper now reads `address(locked_)`, the adapter that executed the callback route)

3. **What must not change (PRD non-goals and invariants):**
   - The `probe.lockedHits()` / `probe.attempts()` equality assertion at `:515` ("every nested money entry hit IsLocked"). The PRD's third acceptance bullet requires the nested-entry lock assertion to remain.
   - The "outer join completes" / "callback stages ran" / "nested entry did not succeed" assertions at `:513`, `:514`, `:516`.
   - The `probe.balanceOf(address(locked_)), 0` "join input was consumed" assertion at `:521` — note this already names `locked_` correctly; do not retarget it to `address(adapter)`.
   - The `inFlightRouter()` / `inFlightPermit2()` budget assertions at `:517–519`. These are properties of the probe token, not the adapter, and the helper change does not touch them.
   - The four other call sites at `:330`, `:341`, `:374`, `:388` retain `adapter` as the first argument. They were internally consistent with the helper as-written and stay that way.
   - No new `try/catch` is added anywhere; no production-side code is changed; no allowance-reset path is inserted. The change is purely test-side.

### What I am not asserting: production allowance leak

The PRD explicitly labels this as a "required-test gap. The production lock and approval cleanup were not re-read in this confirmation and are not claimed defective." I confirm and re-state that boundary: the production adapter `locked_` (and the storage `adapter`) were not re-read for this review. The only claim is that the test at `:493–522` does not measure the instance under test. That is the test-oracle gap the PRD names.

---

## Files examined where no other defect was found

- `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` — read end-to-end (1–691). The helper body, the test body, `_deployProbePool`, and `AdapterLockProbeToken` were all inspected. No additional defect is recorded for this file in this first pass. Note that the file is shared with several other test families (I1, E6, M3 liquidation, R14.8 paused, RC-01 permit2 overflow); those are out of scope for REQ-SEP-01 and were not re-judged.
- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` — read for the controlling text of REQ-SEP-01 and the cross-PRD context.

No other files were re-read. No Forge / build / test was executed.

---

I did not run Forge.