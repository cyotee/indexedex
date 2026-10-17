# Kimi K3 — REQ-SEP-01 plan draft (replacement session)

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling PRD: `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.md` (63 lines, read in full this round). Nothing was edited. This draft does not authorize edits and is not `REMEDIATION_PRD.plan.md`.
- **Scope:** one test file only — `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`. No production file, no `catch`, no new test file, no claim of a production allowance leak.

## 1. Spot-check (this round)

- Helper `:108-122` is unchanged: `_assertNoMaxAllowances(IERC20 token_) internal view` with five `address(adapter)` reads at `:110, :114, :118, :120, :121` (three allowance reads + two exact-zero comparisons, as the PRD states).
- All five call sites are unchanged at their PRD-cited lines: `:330` `_assertNoMaxAllowances(bpt)`, `:341` `_assertNoMaxAllowances(bpt)`, `:374` `_assertNoMaxAllowances(dai)`, `:388` `_assertNoMaxAllowances(dai)`, `:520` `_assertNoMaxAllowances(IERC20(address(probe)))`. Grep confirms exactly one definition and five invocations — no other call site exists.
- The exercised instance in the RC-01 test is `locked_` (`:495`, `:511`); the fixture `adapter` is set at `:73`. The PRD's "Exact edit" matches the council's consensus signature.

**Stop condition:** before each edit below, the cited line must still contain the cited text. If any does not, stop and report the file, line, and the discrepancy; do not substitute another line, another occurrence, or a paraphrase.

## 2. Ordered plan

**Step 0 — Setup.** Worktree/branch for this item only. `git status` recorded; unrelated changes preserved. Confirm warm `out/` and `cache_forge/` (both are mandatory for the test command below).

**Step 1 — Helper signature and body (`:108-122`).** Replace the whole helper with exactly:

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

Assertion texts, spender addresses, widths, expected values, and the `uint160` destructure are byte-identical to the current body; the only change is `adapter` → `subject_` in the five owner positions and the new first parameter. No nonce or expiry checks are added.

**Step 2 — The five call sites** (PRD `:31-37`, verbatim):
- `:330` → `_assertNoMaxAllowances(adapter, bpt)`
- `:341` → `_assertNoMaxAllowances(adapter, bpt)`
- `:374` → `_assertNoMaxAllowances(adapter, dai)`
- `:388` → `_assertNoMaxAllowances(adapter, dai)`
- `:520` → `_assertNoMaxAllowances(locked_, IERC20(address(probe)))` — the fix: the cleanup assertions now measure the adapter that executed the callback route.

**Step 3 — Verification.** From the repository root:

```bash
python3 scripts/forge-artifacts.py test \
  --consumer test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol -- -vv
```

Zero positional sources (no production file was edited); `--consumer` refreshes the test's runtime artifact dependencies from the warm cache and `--test-root` runs exactly this file with unrelated roots skipped. Do not change `FOUNDRY_TEST`, profiles, or compiler settings; do not delete `out/` or `cache_forge/`. **Pass criterion:** the whole file runs green — both RC-01 tests and the four fixture-call tests. **If the corrected `:520` assertions fail, stop and report:** a zero-allowance failure on `locked_` would be new evidence about production cleanup and is outside this item's scope to fix; do not weaken an exact-zero check to a not-max check, do not add a `catch`, and do not edit production to make it pass. Record the command and its result in the execution report.

## 3. What must not change (PRD `:39-46`, restated as checks)

- Nested-entry lock assertions `:514-516`, in-flight budget assertions `:517-519`, outer success `:513`, consumed-input `:521` (already names `locked_` — do not retarget).
- The rollback twin `:524-552` and the probe contract (`AdapterLockProbeToken`).
- The fixture member `adapter` — never reassigned to `locked_` to make the old helper accidentally pass.
- The four fixture call sites keep measuring `adapter`.
- No other line of the file; no other file.

## 4. No-choice statement

Sites (six), signature (one), body (one), call-site arguments (five), command (one), and stop behavior are all fixed above or verbatim in the PRD. The implementer chooses nothing.

I did not run Forge.
