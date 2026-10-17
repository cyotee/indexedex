# Implementation plan — Balancer callback test checks the exercised adapter

- **Date:** 2026-10-16
- **Status:** DRAFT. This plan does not authorize a test or code edit. A later session must be explicitly asked to implement it.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-SEP-01. One test file only.
- **Council:** Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t` does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi replacement `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No Forge run. Consensus is not proof.
- **Drafts:** `reviewers/astra-sep01-plan.md`, `reviewers/grok-sep01-plan.md`, `reviewers/minimax-sep01-plan.md`, `reviewers/kimi-sep01-plan.md`, and the four `*-sep01-plan-cross.md` files.

## What not to do

- Do not edit a production file.
- Do not add a `catch`.
- Do not add nonce or expiry checks.
- Do not weaken an exact-zero check.
- Do not retarget the fixture member `adapter` to `locked_`.
- Do not change the rollback twin, the probe contract, or the lock and in-flight assertions.
- Do not claim a production allowance leak. If the corrected line 520 fails because `locked_` is not zero, stop and report. Do not edit production to make it pass.

## Step 1 — stop if a named line drifted

In `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`, confirm:

- The helper at line 108 is `_assertNoMaxAllowances(IERC20 token_)`.
- `address(adapter)` appears at lines 110, 114, 118, 120, and 121.
- The calls at lines 330, 341, 374, 388, and 520 are the only five calls.
- `IStandardExchange` is already imported.

If any of that is false, stop and report. Do not choose another line.

## Step 2 — replace the helper

Replace the helper with:

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

## Step 3 — five call sites

- Line 330: `_assertNoMaxAllowances(adapter, bpt)`
- Line 341: `_assertNoMaxAllowances(adapter, bpt)`
- Line 374: `_assertNoMaxAllowances(adapter, dai)`
- Line 388: `_assertNoMaxAllowances(adapter, dai)`
- Line 520: `_assertNoMaxAllowances(locked_, IERC20(address(probe)))`

## Step 4 — run the one file

Record `git status` and preserve unrelated changes. Do not delete `out/` or `cache_forge/`. Do not enable `via_ir`. Do not set `FOUNDRY_PROFILE=fork`.

From the repository root:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol \
  -- -vv
```

Run the whole file. Do not filter to one test name. Record the command and result in `EXECUTION_REPORT.md` in this directory. A present assertion is not a pass until that run is reported.

## Done when

- The helper takes `subject_` and `token_`.
- Line 520 checks `locked_`.
- The other four calls still check `adapter`.
- No production file changed.
- The test command is recorded.

## Dissent

MiniMax would pass `BalancerV3SinglePoolStandardExchange.sol` as a positional source. Astra, Grok, and Kimi reject that. No production source is edited. `--test-root` already makes the test file a runtime-artifact consumer. Kimi's extra `--consumer` flag is redundant and is not used.
