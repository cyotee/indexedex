# Astra — REQ-SEP-01 replacement-session plan draft

Independent plan draft by the labeled replacement, not continuity with `ses_ec412bcc2ffejKLo7nuoEAqbV0`; I do not recall that session. No other reviewers' notes were read for this draft. I read the controlling `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.md` in full and directly spot-checked the current helper, all five invocation sites, and the callback-success/rollback tests.

**No implementer choice remains.** This is a test-oracle identity repair, not a demonstrated production allowance leak. This draft is not `REMEDIATION_PRD.plan.md` and does not authorize implementation.

## Scope

Only this existing test file is an implementation edit target:

`test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`

No production edits, new test file, catch, test-side allowance cleanup, fixture retargeting, deployment change, configuration change or unrelated formatting. Keep all existing assertion values, widths, messages and order.

## Step 1 — validate all original anchors before editing

Check these original locations as one preflight, before changing the helper or shifting lines:

| Original line | Required current text / context |
|---|---|
| 108 | `function _assertNoMaxAllowances(IERC20 token_) internal view {` |
| 110,114,118,120,121 | The five helper allowance-owner expressions are `address(adapter)` |
| 330 | `_assertNoMaxAllowances(bpt);` after the fixture adapter's exact-input liquidation |
| 341 | `_assertNoMaxAllowances(bpt);` after the fixture adapter's exact-output liquidation |
| 374 | `_assertNoMaxAllowances(dai);` after the fixture adapter's join |
| 388 | `_assertNoMaxAllowances(dai);` after the fixture adapter's exact-output join |
| 520 | `_assertNoMaxAllowances(IERC20(address(probe)));` after `locked_.exchangeIn` at 511 |

These anchors matched in this drafting pass. If any named line no longer matches at implementation preflight, **stop and report the file, line and observed discrepancy**. Do not choose another occurrence, assume an earlier partial fix, search for a replacement target or expand scope. After a successful preflight, use the validated anchors to accommodate line shifts caused by this change itself.

Record the starting working-tree state and preserve unrelated changes. A dirty tree is not authorization to reset other work. Existing `IStandardExchange`, `IERC20` and `IPermit2` imports already support the specified helper; no new import is required.

## Step 2 — replace the existing helper with this exact definition

```solidity
    function _assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view {
        assertTrue(
            token_.allowance(address(subject_), address(router)) != type(uint256).max,
            "M3: ERC20 router allowance must not stay max"
        );
        assertTrue(
            token_.allowance(address(subject_), address(permit2)) != type(uint256).max,
            "M3: ERC20 Permit2 allowance must not stay max"
        );
        (uint160 permitAmt_,,) =
            IPermit2(address(permit2)).allowance(address(subject_), address(token_), address(router));
        assertTrue(permitAmt_ != type(uint160).max, "M3: Permit2 packed allowance must not stay uint160.max");
        assertEq(token_.allowance(address(subject_), address(router)), 0, "M3: router allowance reset");
        assertEq(token_.allowance(address(subject_), address(permit2)), 0, "M3: Permit2 ERC20 allowance reset");
        assertEq(permitAmt_, 0, "M3: Permit2 packed amount reset");
    }
```

This changes the signature and **all five** hardcoded owner expressions, including the two repeated ERC20 reads in the exact-zero assertions. Do not change only the initial nonmaximum reads. Keep the six checks; exact zero is not replaced by merely “not maximum.” Keep `internal view`. Do not add an overload or alternative helper.

The packed Permit2 field under test is its allowance **amount**, not nonce or expiry. No additional reset requirement is introduced.

## Step 3 — apply exactly five call-site edits

| Original line | Exact replacement call |
|---|---|
| 330 | `_assertNoMaxAllowances(adapter, bpt);` |
| 341 | `_assertNoMaxAllowances(adapter, bpt);` |
| 374 | `_assertNoMaxAllowances(adapter, dai);` |
| 388 | `_assertNoMaxAllowances(adapter, dai);` |
| 520 | `_assertNoMaxAllowances(locked_, IERC20(address(probe)));` |

The first four routes still exercise the fixture `adapter`; their subject does not change. The callback route exercises `locked_`; only that invocation changes the allowance owner being observed. No assignment to the fixture member `adapter` is made.

## Step 4 — preserve the existing witnesses

All statements outside the helper definition and its five invocations remain unchanged, especially:

- `_deployProbePool`, its CREATE3/artifact deployment, the real pool/router/Permit2 fixture, and the probe contract.
- Callback arming on `locked_`, caller funding/approval, route input, recipient, deadline and the outer operation at 493–512.
- Outer positive output at 513; positive callback attempts at 514; `lockedHits() == attempts()` at 515; unsuccessful nested entry at 516.
- Exact in-flight router and Permit2 route budgets and the nonmaximum guard at 517–519.
- Zero remaining probe input on `locked_` at 521.
- The propagated-lock rollback twin at 525–552, including its exact expected error, restored caller balance and existing `locked_` allowance assertion.
- The four non-callback operation fixtures and their existing amount/payout/supply assertions.

Do not add a catch or an allowance reset before the cleanup assertion. Do not mock the adapter or replace the callback test with a direct helper/unit test. Do not weaken a failure to make the suite green. No production lock or approval routine is part of this task.

## Step 5 — inspect the test-only diff

Before testing, confirm the scoped diff contains exactly:

1. The specified helper parameter addition.
2. Five owner-expression substitutions inside that helper.
3. Five invocation-argument additions, with `locked_` only at the callback-success invocation.

Verify all three allowance channels now use `address(subject_)` and no reference to fixture `adapter` remains inside the helper. Verify all six comparisons and messages are retained. Verify the entire rollback twin, in-flight assertions and deployment/probe code are unchanged. Confirm no production, configuration, instruction or other test file was modified by this task.

If the diff contains anything outside that scope, stop and report; do not silently expand the repair. Diff review identifies source conformance, not runtime success.

## Step 6 — artifact-aware execution for the later authorized session

Use the repository's default hermetic profile. Do not set a fork profile, change `FOUNDRY_TEST`, enable `via_ir`, delete `out/` or `cache_forge/`, or run concurrent writers to those directories. In a new/empty worktree, follow the existing warm-artifact seeding rule before the first compile. Allow long-running compilers to finish rather than terminating them for silence.

From the repository root, run this exact command after the test-only edit:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol \
  -- -vv
```

The production source is an **artifact-refresh input only**, not an edit target. The selected test deploys that artifact by name; refreshing it prevents stale runtime bytecode from being mistaken for current behavior. `docs/testing/ARTIFACT_BUILDS.md` specifies that this helper builds runtime artifacts before running the selected tests and stops before testing if the build fails.

Run the **whole one named test file**, without a test-name filter. This includes the callback success and rollback witnesses and the four fixture-based helper invocation contexts. Do not substitute another test file, an individual helper call or a test count estimate for the required run.

This command is supplied for later authorized execution only. It was not run during drafting.

## Step 7 — acceptance and reporting

The implementation result must record the actual command, toolchain/profile, artifact-build outcome, whole-file test outcome, and test-only diff scope. A pending or failed run is not a pass. A saved log is evidence of that run, not an independent rerun by this reviewer.

Completion requires:

- After the successful callback route, probe ERC20 allowances **owned by `locked_`** to router and Permit2 are exactly zero, and Permit2's packed amount for `(locked_, probe, router)` is exactly zero.
- The original nonmaximum checks also remain and pass.
- The four other helper invocations still inspect their exercised fixture `adapter`.
- Nested-lock, outer-success, in-flight budget and input-consumption assertions remain intact and pass; the rollback twin remains unchanged and runs with the file.
- No production or unrelated test change occurred.

If the new assertion fails, stop and report the actual failing allowance/channel and test result. Do not clear it from the test, add a catch, weaken zero to finite, or modify production under this test-only plan. Investigating any resulting production symptom would require a separately scoped task. Neither this original gap nor a future test outcome is described here as a demonstrated production allowance leak.

## Evidence and review limits

The controlling PRD and current helper/five call-site contexts were read directly this pass. The callback probe and production deployment path were inspected earlier in this replacement session's independent source review. The artifact workflow documentation was re-read. All required paths were present; the assigned output was absent before this write.

No peer artifacts were read for this independent draft. No code, PRD, final implementation plan, test, configuration or instruction file was edited. No shell, delegation, build, tests, deployments or exploit procedures were used. Only this assigned Markdown plan draft was created.

I did not run Forge.
