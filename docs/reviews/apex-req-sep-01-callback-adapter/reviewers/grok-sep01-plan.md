# Grok plan draft — REQ-SEP-01

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Controlling PRD:** `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.md`
- **Only file:** `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`

This file does not authorize an edit. It is not `REMEDIATION_PRD.plan.md`.

## Stop

Before the first edit, the named lines must still be the sentences below. If any is gone or already different, stop and report that line. Do not choose another line, another file, or another signature.

- Line 108: `function _assertNoMaxAllowances(IERC20 token_) internal view {`
- Lines 110, 114, 118, 120, and 121 still use `address(adapter)` as the allowance owner.
- Line 330: `_assertNoMaxAllowances(bpt);`
- Line 341: `_assertNoMaxAllowances(bpt);`
- Line 374: `_assertNoMaxAllowances(dai);`
- Line 388: `_assertNoMaxAllowances(dai);`
- Line 520: `_assertNoMaxAllowances(IERC20(address(probe)));`

These were present on the 2026-10-16 spot-check.

## Step 1 — helper

Replace the helper at lines 108–122 with this body. Do not rename it. Do not add a check.

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

`IStandardExchange` is already imported. Do not add an import.

## Step 2 — five call sites

Replace only these calls:

- Line 330: `_assertNoMaxAllowances(adapter, bpt);`
- Line 341: `_assertNoMaxAllowances(adapter, bpt);`
- Line 374: `_assertNoMaxAllowances(adapter, dai);`
- Line 388: `_assertNoMaxAllowances(adapter, dai);`
- Line 520: `_assertNoMaxAllowances(locked_, IERC20(address(probe)));`

No other call. Do not pass `locked_` at lines 330, 341, 374, or 388.

## What must not change

- Lines 513–516: outer success, callback stages, `lockedHits() == attempts()`, and nested entry did not succeed.
- Lines 517–519: in-flight router and Permit2 amounts are the route budget, and that budget is not `type(uint256).max`.
- Line 521: probe balance of `locked_` is zero.
- The rollback twin. It already names `locked_`.
- The fixture member `adapter`. Do not assign `locked_` to it.
- Production files. No `catch`. No new test file. No nonce or expiry check. Do not drop an exact-zero check.

This item does not claim a production allowance leak.

## Step 3 — one test command

From the repository root, after the test edit and no production edit:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol -- -vv
```

Do not pass a production source. Do not pass `--no-consumer-artifacts`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. If the command fails, stop and report the result. Do not edit production to make it pass.

I did not run Forge.
