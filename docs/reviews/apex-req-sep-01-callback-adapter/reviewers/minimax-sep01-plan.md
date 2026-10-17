# MiniMax M3 — REQ-SEP-01 implementation plan (replacement-session draft)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Controlling PRD:** `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.md`. Read in full. The PRD's parameter name is `subject_`; my first pass used `adapter_`. This plan adopts `subject_` per the PRD's "Dissent" note and explicitly records the change.
- **Other reviewer files:** Not read.
- **Scope:** Test-only edit. No production code. No `catch`. No claim of a production allowance leak.
- **Forge:** Not run.

---

## 0. Preconditions — spot-check the current tree before editing

The plan depends on the following current-state observations. If any of these lines no longer matches, **stop and re-read the PRD; do not proceed**. Do not paper over a mismatch.

| Line (current) | Expected content |
|---|---|
| `:108` | `    function _assertNoMaxAllowances(IERC20 token_) internal view {` |
| `:110` | `            token_.allowance(address(adapter), address(router)) != type(uint256).max,` |
| `:114` | `            token_.allowance(address(adapter), address(permit2)) != type(uint256).max,` |
| `:118` | `            IPermit2(address(permit2)).allowance(address(adapter), address(token_), address(router));` |
| `:120` | `        assertEq(token_.allowance(address(adapter), address(router)), 0, "M3: router allowance reset");` |
| `:121` | `        assertEq(token_.allowance(address(adapter), address(permit2)), 0, "M3: Permit2 ERC20 allowance reset");` |
| `:330` | `        _assertNoMaxAllowances(bpt);` |
| `:341` | `        _assertNoMaxAllowances(bpt);` |
| `:374` | `        _assertNoMaxAllowances(dai);` |
| `:388` | `        _assertNoMaxAllowances(dai);` |
| `:493–522` | `test_RC01_callback_nestedMoneyEntry_hitsAdapterLock_outerSucceeds` body, with `locked_` declared at `:495`, executed at `:511`, and `:520` calling `_assertNoMaxAllowances(IERC20(address(probe)));` |
| `:525–552` | `test_RC01_callback_propagatedLock_rollsBack` (rollback twin; `:552` already asserts `probe.allowance(address(locked_), address(router)) == 0` and is not edited) |
| `:569–617` | `_deployProbePool(probe)` returning `(IStandardExchange locked_, address pool_)`. Do not touch. |

Five-line grep confirmations required before editing:

```text
grep -n "_assertNoMaxAllowances" test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol
```

Expected output: one definition at `:108` and five call sites at `:330`, `:341`, `:374`, `:388`, `:520`. No other call sites exist in this file. If a sixth appears, stop.

---

## 1. Edit 1 — helper signature and body

### 1.1 Signature change (line 108)

Replace:

```solidity
    function _assertNoMaxAllowances(IERC20 token_) internal view {
```

with:

```solidity
    function _assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view {
```

Order: PRD specifies `subject_` first, then `token_`. This appends a typed subject parameter without re-flowing the original token-first order; the new parameter is added before the existing one. Do not rename `token_`. Do not change the visibility (`internal view`).

### 1.2 Body changes — five `address(adapter)` → `address(subject_)` substitutions

Inside the helper body (lines 109–122), replace every `address(adapter)` with `address(subject_)`. The five positions are exactly:

| Line | Current text (allowance-owner position) | Replacement |
|---|---|---|
| `:110` | `token_.allowance(address(adapter), address(router)) != type(uint256).max,` | `token_.allowance(address(subject_), address(router)) != type(uint256).max,` |
| `:114` | `token_.allowance(address(adapter), address(permit2)) != type(uint256).max,` | `token_.allowance(address(subject_), address(permit2)) != type(uint256).max,` |
| `:118` | `IPermit2(address(permit2)).allowance(address(adapter), address(token_), address(router));` | `IPermit2(address(permit2)).allowance(address(subject_), address(token_), address(router));` |
| `:120` | `assertEq(token_.allowance(address(adapter), address(router)), 0, "M3: router allowance reset");` | `assertEq(token_.allowance(address(subject_), address(router)), 0, "M3: router allowance reset");` |
| `:121` | `assertEq(token_.allowance(address(adapter), address(permit2)), 0, "M3: Permit2 ERC20 allowance reset");` | `assertEq(token_.allowance(address(subject_), address(permit2)), 0, "M3: Permit2 ERC20 allowance reset");` |

### 1.3 Body content that must not change

- The two `assertTrue` `!= type(uint256).max` guards at `:110–112` and `:113–115` — message strings unchanged.
- The `assertTrue(permitAmt_ != type(uint160).max, ...)` at `:119` — message unchanged. (The `permitAmt_` is the amount field of the `(owner, token, spender)` Permit2 packed slot — the helper still extracts the same slot.)
- The three exact-zero `assertEq` lines at `:120`, `:121`, `:122` — message strings unchanged, expected values unchanged (0).
- No nonce check, no expiry check. The Permit2 packed read stays a 3-tuple `(amount, expiration, nonce)` with only the amount bound to `permitAmt_`. The PRD explicitly forbids adding nonce/expiry checks.
- No `try/catch`. No allowance-reset path.
- The helper remains `internal view`. No return value.

### 1.4 Helper body after edit (target state, for review)

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

This is the only legal shape. Six assertions. Three allowance reads. No nonce/expiry. No `catch`.

---

## 2. Edits 2–6 — five call-site rewrites

The five substitutions are independent. Apply them in the order below; each is a one-line replacement.

| Step | Line | Current text | Replacement text |
|---|---|---|---|
| 2 | `:330` | `        _assertNoMaxAllowances(bpt);` | `        _assertNoMaxAllowances(adapter, bpt);` |
| 3 | `:341` | `        _assertNoMaxAllowances(bpt);` | `        _assertNoMaxAllowances(adapter, bpt);` |
| 4 | `:374` | `        _assertNoMaxAllowances(dai);` | `        _assertNoMaxAllowances(adapter, dai);` |
| 5 | `:388` | `        _assertNoMaxAllowances(dai);` | `        _assertNoMaxAllowances(adapter, dai);` |
| 6 | `:520` | `        _assertNoMaxAllowances(IERC20(address(probe)));` | `        _assertNoMaxAllowances(locked_, IERC20(address(probe)));` |

Step 6 is the bug fix. Steps 2–5 preserve current semantics by passing the storage `adapter`, the fixture exercised by the surrounding tests:

- `:330` and `:341` are inside `_assertLargeLiquidation(IERC20 output)` defined at `:317`. The function exercises the storage `adapter` (e.g., `:321` `adapter.previewExchangeIn`, `:326` `adapter.exchangeIn`, `:336` `adapter.exchangeOut`). The fixture under cleanup is `adapter`. Pass `adapter`.
- `:374` is inside `test_M_allowance_not_max_after_exchangeIn` defined at `:366`. The function exercises the storage `adapter` (`:370`). Pass `adapter`.
- `:388` is inside `test_M_allowance_not_max_after_exchangeOut` defined at `:378`. The function exercises the storage `adapter` (`:383`). Pass `adapter`.

No surrounding lines change. The five call sites remain in their original contexts, on their original lines.

---

## 3. What must not change (full list)

- Lines `:513–516`: outer success, callback stages ran, every nested money entry hit `IsLocked`, nested entry did not succeed. These are the nested-entry lock witness.
- Lines `:517–519`: in-flight router budget, in-flight Permit2 budget, approval is not `uint256.max`. These are the in-flight budget assertions.
- Line `:521`: `assertEq(probe.balanceOf(address(locked_)), 0, "join input was consumed");` — already correctly names `locked_`. Do not retarget to `address(adapter)`.
- The rollback twin `test_RC01_callback_propagatedLock_rollsBack` at `:525–552` is not edited. In particular, `:552` already asserts `probe.allowance(address(locked_), address(router)) == 0` — that is the de-facto template the helper now matches.
- The fixture member `adapter` (storage variable declared at `:58`, initialized at `:73`). Do not reassign it to make the old helper accidentally inspect `locked_`. The PRD forbids this.
- `_deployProbePool` at `:569–617`. Do not touch the deploy bytecode at `:607–616`, the salt `keccak256("BalancerV3SinglePoolStandardExchange-rc01-probe")`, or the constructor args at `:613`.
- `AdapterLockProbeToken` at `:620–691`. The probe constructor inputs at `:494` (`address(router)`, `address(permit2)`) are not changed. The `_probe` implementation at `:677–690` is not changed. The probe's allowance bookkeeping (`inFlightRouter`, `inFlightPermit2`) at `:651–654` is not changed.
- The test name `test_RC01_callback_nestedMoneyEntry_hitsAdapterLock_outerSucceeds` is not changed.
- The file's imports (`:4–29`) are not changed. `IStandardExchange` is already imported (`:15`).
- The PRD's non-goals are honored: no `catch`, no production edit, no weakening of `== 0` to `!= max`.
- A passing run of this test is **not** proof of a production allowance leak. The PRD's "Acceptance criteria" item 4 and "Non-goals" section say so. Do not write any artifact that claims otherwise.

---

## 4. Forge-artifacts.py command for this one file

CLAUDE.md ("Non-negotiables" item 10) requires `forge build` before `forge test` because `ArtifactCreationCode` reads creation bytecode from `out/`. For this edit, the edited source **is** a test file, and there is no production contract change, so the build target is the test file plus its concrete dependencies.

Single command, run from the repo root:

```bash
python3 scripts/forge-artifacts.py test \
    test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol \
    --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol
```

Notes for the executor:

- `--test-root` is the same path as the edited source. For a single-file edit, the test root equals the file. Repeat `--test-root` if more suites are added; this plan covers only one.
- The script's first stage builds concrete dependents and runtime artifacts; the second stage excludes unrelated compilation roots with `--skip` (the script manages that internally — do not add `--skip` flags manually).
- The compile is hermetic (`FOUNDRY_PROFILE` default). No fork URL is needed; nothing on this test file requires a fork.
- CLAUDE.md item 8 (Forge patience) applies: cold or near-cold compiles in this monorepo routinely take 20–40+ minutes. **Wait for process exit.** Do not kill on "no progress lines."

After the artifact build succeeds, the executor runs the targeted test. That step is **not** part of this plan's authoring scope; the executor opens a separate run with appropriate timeouts and notification.

---

## 5. Stop conditions

Stop and surface to the coordinator (do not silently patch) if any of the following is observed either before or after applying edits 1–6:

1. **Line drift.** Any of the precondition lines in §0 no longer matches the listed content. In particular:
   - If `:108` is no longer the helper definition, or the helper's signature has gained/lost parameters beyond `subject_` and `token_`.
   - If any of `:110`, `:114`, `:118`, `:120`, `:121` no longer contains `address(adapter)` (i.e., it has already been edited by someone else).
   - If any of `:330`, `:341`, `:374`, `:388`, `:520` is no longer a call to `_assertNoMaxAllowances`.
   - If `:520` no longer passes `IERC20(address(probe))`.
   - If `:495` no longer declares `locked_` via `_deployProbePool(probe)`.
2. **Sixth call site.** If `grep -n "_assertNoMaxAllowances" test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` returns more than six lines (one definition + five call sites).
3. **PRD drift.** If the controlling PRD at `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.md` no longer pins the helper signature to `_assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_)` or the five call-site arguments.
4. **Production edit requested.** If anyone asks to edit `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` or any production approval/lock code as part of this item. The PRD non-goal forbids it; stop.
5. **`catch` requested.** If anyone asks to wrap the `locked_.exchangeIn` call or its assertions in `try/catch` to "ensure cleanup" or "clear allowances on revert." The PRD non-goal forbids it; stop.
6. **Signature divergence.** If anyone asks for a different parameter type (`address` instead of `IStandardExchange`) or different parameter order. The PRD's "Exact edit" and "Dissent" sections lock the type as `IStandardExchange` and the parameter name as `subject_`. Stop and re-read it.
7. **Fixture retargeting.** If anyone proposes reassigning the storage `adapter` (e.g., `adapter = locked_;`) so that the old helper accidentally inspects `locked_`. The PRD's "What must not change" item 5 forbids it; stop.
8. **Compromise on `== 0`.** If anyone proposes weakening any of the three `assertEq(..., 0, ...)` lines to `assertTrue(..., != type(uint256).max, ...)`. The PRD non-goal "Do not weaken an exact-zero check to a not-max check" forbids it; stop.
9. **Probe retargeting.** If anyone proposes retargeting `:521` (`probe.balanceOf(address(locked_)), 0`) to `address(adapter)`. That line is correct as written and must remain.
10. **Approval gate.** This plan does not authorize the edits. A separate human/owner approval is required before any file is modified.

If a stop condition fires, the executor records the trigger, the exact line or command output, and the time, and returns to the coordinator without bypassing the gate.

---

## 6. Edit application checklist (no implementation by this reviewer)

The following is the human/executor checklist. This review session does **not** apply the edits; it specifies them.

- [ ] §0 precondition lines verified by `grep -n` / line read.
- [ ] Edit 1 applied: helper signature at `:108` and five `address(adapter)` → `address(subject_)` substitutions at `:110, :114, :118, :120, :121`.
- [ ] Edit 2 applied: `:330` → `_assertNoMaxAllowances(adapter, bpt);`
- [ ] Edit 3 applied: `:341` → `_assertNoMaxAllowances(adapter, bpt);`
- [ ] Edit 4 applied: `:374` → `_assertNoMaxAllowances(adapter, dai);`
- [ ] Edit 5 applied: `:388` → `_assertNoMaxAllowances(adapter, dai);`
- [ ] Edit 6 applied: `:520` → `_assertNoMaxAllowances(locked_, IERC20(address(probe)));`
- [ ] Post-edit `grep` confirms exactly six lines reference `_assertNoMaxAllowances`: one definition with the new signature, five call sites with the new arguments.
- [ ] No other file touched. `git status` shows exactly one modified file.
- [ ] `python3 scripts/forge-artifacts.py test …` (command in §4) executed and exited successfully.
- [ ] The targeted test execution step (out of scope for this plan) is opened under separate authorization, with appropriate timeouts.

---

## 7. Notes on the PRD's parameter name choice

The PRD locks the helper parameter name as `subject_`. My first-pass review (`minimax-sep01.md`) used `adapter_`. The PRD's "Dissent" note explains: "`subject_` so the parameter is not one underscore away from the fixture member `adapter`." That is a real readability concern: `adapter_` and `adapter` are visually adjacent in tooling and differ by a single trailing `_`. `subject_` is unambiguous. This plan adopts `subject_` without reservation. No other text in this plan changes because of the rename.

---

I did not run Forge.