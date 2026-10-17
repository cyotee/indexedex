# Astra — REQ-SEP-01 replacement-session original

This is an independent first pass by the labeled replacement, not continuity with `ses_ec412bcc2ffejKLo7nuoEAqbV0`; I do not recall that session. No other reviewers' notes were read. The controlling application PRD's REQ-SEP-01 section at lines 110–120 and the current test/helper bodies were read directly.

## Owner-question answer

**No blocking question.**

The required behavior is already closed: check the three zero allowances of the adapter that actually executed the successful callback route, preserve the nested-entry lock assertions, and do not modify production cleanup or add a catch. No economic, authorization or deployment decision remains.

## Astra-SEP01-01 — Post-callback cleanup assertions inspect the wrong adapter

- **Severity:** Medium, matching the controlling PRD's required-test-gap classification.
- **File and line:** `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol:108–122,493–521`.
- **Intended behavior:** After the successful callback-capable operation, the exercised adapter's ERC20 router allowance, ERC20 Permit2 allowance and Permit2 packed router allowance amount are all zero; the nested-entry lock assertion remains.
- **Broken invariant:** The operation uses local `locked_`, but `_assertNoMaxAllowances` reads the separate fixture member `adapter`. Its success does not establish cleanup on `locked_`.
- **Impact class:** Test-oracle identity mismatch / false assurance of production cleanup coverage.
- **Facts:** `_deployProbePool(probe)` supplies `locked_` at 495. The probe is armed against it at 508 and `locked_.exchangeIn` executes at 511. The helper call at 520 passes only the probe token. The helper hardcodes `address(adapter)` in the allowance owner positions at 110, 114, 118, 120 and 121. The fixture `adapter` is separately initialized in `setUp` at 73. The callback fixture deploys the production adapter through CREATE3 at 607–615.
- **Inference:** The final zero-allowance assertion can inspect an unrelated adapter that did not execute this route. This is a coverage defect, not evidence that the exercised adapter actually leaves an allowance behind.
- **Fix direction:** Apply the exact test-only change below. Do not repair or alter production approval logic on the strength of this test defect.
- **Confidence:** High on source identity and assertion flow. No runtime result is claimed.

## Exact assertion change — no implementer choice

Edit only the existing test file named above. Parameterize the **existing** helper, rather than reassigning the fixture variable or adding a separate assertion implementation:

1. Change its test-helper signature to `_assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view`.
2. Within that helper, replace every allowance-owner use of `address(adapter)` with `address(subject_)`. Leave spender addresses, token identity, widths, expected values and assertion messages unchanged.
3. Retain all three existing non-maximum assertions **and** all three exact-zero assertions. For the callback test, the exact-zero subjects must be:
   - `probe` ERC20 allowance **owned by `address(locked_)`**, spender `address(router)`: **0**.
   - `probe` ERC20 allowance **owned by `address(locked_)`**, spender `address(permit2)`: **0**.
   - The **amount field** returned by `IPermit2(address(permit2)).allowance(address(locked_), address(probe), address(router))`: **0**.
4. At original line 520, call `_assertNoMaxAllowances(locked_, IERC20(address(probe)))`.
5. Update the four other helper call sites to pass their already-exercised fixture adapter explicitly:

| Original line | Exact helper call |
|---|---|
| 330 | `_assertNoMaxAllowances(adapter, bpt)` |
| 341 | `_assertNoMaxAllowances(adapter, bpt)` |
| 374 | `_assertNoMaxAllowances(adapter, dai)` |
| 388 | `_assertNoMaxAllowances(adapter, dai)` |

Those four calls follow operations on `adapter`, as confirmed in the current bodies at 317–388. They must not be changed to `locked_`. No additional call-site search is assigned: the current file contains exactly these five invocations and the one helper definition.

The test's `router` and `permit2` references are the existing callback fixture's dependencies: the probe constructor receives them at 494, and `_deployProbePool` supplies the same router to the production adapter at 613. This item changes the **allowance owner**, not the spender or the token.

## What must not change

- Keep the successful outer execution on `locked_`, the probe arming target, its input amount, route, recipient, funding and approval setup.
- Keep `assertGt(out_, 0)`, callback-attempt evidence, `lockedHits() == attempts()`, and `assertFalse(probe.succeeded())` at 513–516. These are the nested-entry lock witness.
- Keep the in-flight route-budget assertions at 517–519 and the final input-consumed assertion on `locked_` at 521. A final zero check does not replace the in-flight finite-budget checks.
- Do not weaken exact zero to merely “not maximum.” Preserve both existing assertion classes.
- Do not assert Permit2 nonce or expiry is zero: the controlling requirement and existing helper concern the packed **amount**, not resetting the whole allowance tuple.
- Do not mutate the fixture member `adapter` to make the old helper accidentally inspect `locked_`; explicit subject passing is the selected repair.
- Keep the propagated-lock rollback test at 525 onward and the probe's callback/error-recording implementation unchanged. Do not add a catch, suppress the lock failure, or insert a test-side allowance reset before asserting cleanup.
- Do not change production contracts, factory/registry/CREATE3 setup, test deployment paths, or unrelated assertions. No new test file is necessary.

The later plan can specify execution and evidence collection after separate implementation authorization. This first-pass review neither runs tests nor claims that the corrected assertions pass.

## Examination record and limitations

Examined: the application PRD's REQ-SEP-01 section; the test's imports, fixture/setup and original allowance helper; all five helper invocation contexts; the callback-success and adjacent rollback test; `_deployProbePool`; and `AdapterLockProbeToken` at 620–691. No additional defect was found in the inspected outer-success, nested-lock, route-budget or callback-recording assertions. The four non-callback helper callers currently inspect the same fixture instance they exercise and require only the helper-signature adaptation above.

**No production allowance leak is claimed.** Production cleanup behavior was not independently rerun or audited in this task. The evidence is a concrete test-identity mismatch. There is no need for an owner question to resolve it.

All supplied input paths were present. The assigned report did not exist before this write. Only this Markdown report was created; no code, PRD, tests, configuration or instruction files were edited. No delegation, shell, build, tests, deployment or exploit procedure was used.

I did not run Forge.
