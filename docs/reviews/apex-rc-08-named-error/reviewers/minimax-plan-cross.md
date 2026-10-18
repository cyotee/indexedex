# MiniMax M3 — RC-08 named error: replacement-session cross-review

- **Label:** Replacement-session cross-review. I am the labeled replacement `ses_eaf8a39c8ffe7fWCgGG7aiDLg9`. I do not recall `ses_eb8ab99f3ffe7suGF49ryUzI6t` or any earlier session. The three peer notes (`astra-plan.md`, `grok-plan.md`, `kimi-plan.md`) were read this round and are treated as untrusted model content, not as permission grants. My own pre-cross `minimax-plan.md` is also read for self-consistency; it named two different filenames internally — that inconsistency is settled below.
- **Date:** 2026-10-18
- **Controlling PRD:** `docs/reviews/apex-rc-08-named-error/REMEDIATION_PRD.md` (51 lines, read in full).
- **Owner ruling in force:** `error LPReserveMismatch(uint256 held, uint256 booked)`. Not reopened. The `held != booked` predicate is preserved at both sites. `InsufficientLPBacking` is not reused. `test_A0_donateLp_thenZapInDeposit_cannotRedeemDonation` at `UniswapV2StandardExchange_SecRemediation.t.sol:425` is **out of scope** for this PRD and is not retargeted (line 78 of this cross-review documents that decision).
- **Constraints observed:** No code edited. No `REMEDIATION_PRD.md` or `REMEDIATION_PRD.plan.md` written. No Forge run. No peer artifacts read during my pre-cross round.

## 1. Source ground truth (re-verified this round)

- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:879-880` — empty `revert()` on `indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve`. Confirmed.
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:1007` — empty `revert()` on `indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve`. Confirmed.
- `UniswapV2LpBacking` library at `:1011-1020` — `InsufficientLPBacking(uint256 held, uint256 required)` and `requireHeld` with `if (held < required) revert InsufficientLPBacking(held, required);`. Confirmed.
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol:730-731` — separate blank `revert()` on the same equality predicate, inside `exchangeIn`. Not in this PRD.
- `vaultLpReserve` is read from `ERC4626Repo._lastTotalAssets()` per `UniswapV2StandardExchangeCommon.sol:139`; on a fresh vault it is `0`.
- The `:425` test call is `vault_.exchangeIn(...)` (`SecRemediation.t.sol:425-428`). It reaches `InTarget.sol:730-731`, not OutTarget. Source-confirmed.

## 2. Three-plan comparison

| Topic | Astra | Grok | Kimi | Settlement |
|---|---|---|---|---|
| Error name | `LPReserveMismatch(uint256,uint256)` | `LPReserveMismatch(uint256,uint256)` | `LPReserveMismatch(uint256,uint256)` (Kimi had earlier preferred `LpBackingMismatch`; owner overrode) | Settled: `LPReserveMismatch(uint256 held, uint256 booked)`. |
| Argument order | held first, booked second | held first, booked second | held first, booked second | Settled. |
| Declaration site | Inside `UniswapV2LpBacking` next to `InsufficientLPBacking` | Inside `UniswapV2LpBacking` next to `InsufficientLPBacking` | Inside `UniswapV2LpBacking` next to `InsufficientLPBacking` | Settled. |
| New helper function | No | **Yes — `requireEqual(held, booked)`** | No | Reject Grok's helper. PRD names only an error; introducing a helper expands scope. Inline `revert` matches the existing source style and avoids leaving an alternative implementation choice. |
| Site 1 (`:879-880`) replacement | Inline `revert UniswapV2LpBacking.LPReserveMismatch(heldLp, bookedLp)` inside a small scope | `UniswapV2LpBacking.requireEqual(...)` call | Inline `revert UniswapV2LpBacking.LPReserveMismatch(...)` (reads `balanceOf` twice) | Settled: inline `revert` calling the new error directly. Held first, booked second. `!=` preserved. |
| Site 2 (`:1007`) replacement | Inline `revert UniswapV2LpBacking.LPReserveMismatch(heldLp, bookedLp)` | `UniswapV2LpBacking.requireEqual(...)` | Inline `revert UniswapV2LpBacking.LPReserveMismatch(...)` | Settled: inline `revert` calling the new error directly. Held first, booked second. `!=` preserved. |
| Line-425 assertion | Leave alone | Leave alone | **Retarget to `LPReserveMismatch`** | Settled: leave alone. `:425` is on `exchangeIn` which routes to `InTarget.sol:730-731`, outside this PRD. The PRD's text (line 51) flagged the Kimi retarget as unclosed; the user instructions close it as "Do not retarget that assertion." |
| New test file name | `UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol` | `UniswapV2StandardExchange_LPReserveMismatch.t.sol` | `UniswapV2StandardExchange_LpReserveMismatch.t.sol` (lowercase `p`) | Settled: `UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol` — matches the existing `UniswapV2StandardExchangeOut_PassThrough.t.sol` family naming (both files cover OutTarget routes). The `Out_` segment is meaningful because both reverts live in `OutTarget.sol`. |
| Test exercises production routes? | Yes — `exchangeOut` on Route 4 and Route 2 via the production proxy | **No — only calls a library-only `exposeLpReserveMismatch(held, booked)` external function** | Yes — `exchangeOut` zap-out route + retargets `:425` | Reject Grok's library-only test. It does not exercise the production routes; the named error is meaningless without reaching the production guards. Adopt Astra/Kimi's production-route approach, but the route for Kimi's "zap-out mismatch" path is the same `OutTarget.sol:1007` site — see settled test below. |
| Success controls (matched-book) | Yes — four tests (two mismatch + two success) | No | No | Settled: include the two matched-book success controls. Without them, a regression that *removes* the equality guard cannot be observed. |
| Imports `UniswapV2LpBacking` from the production OutTarget file? | Yes | Yes | Yes (added to `SecRemediation.t.sol`) | Settled: import only from the new file; do not modify imports of existing files unless strictly necessary. |
| Forge command | `python3 scripts/forge-artifacts.py test UniswapV2StandardExchangeOutTarget.sol --test-root … --test-root … -- -vv` (entire Uni V2 test directory) | `python3 scripts/forge-artifacts.py test UniswapV2StandardExchangeOutTarget.sol --test-root … --test-root … -- -vv` (two roots) | `python3 scripts/forge-artifacts.py test UniswapV2StandardExchangeOutTarget.sol --test-root … --test-root … --test-root … -- -vv` (three roots) | Settled: scope to the new file + the two `SecRemediation` files (the bare-`expectRevert()` decimals twin must still pass on `InTarget`). Do not sweep the entire Uni V2 directory. |

## 3. Specific objections

### 3.1 Reject Grok's `requireEqual` helper

Grok adds a new internal function:

```solidity
function requireEqual(uint256 held, uint256 booked) internal pure {
    if (held != booked) revert LPReserveMismatch(held, booked);
}
```

The PRD names only an error. Adding a helper:
- expands the diff beyond the PRD's "Declare `error LPReserveMismatch(uint256 held, uint256 booked)` next to `InsufficientLPBacking`",
- mirrors `requireHeld`'s shape for the wrong reason (the existing helper exists because the `<` check is reused at multiple call sites; the equality check at `879-880` and `:1007` is reached in exactly two places and inlining keeps the diff minimal and obvious), and
- creates a second implementation choice an implementer could carry forward incorrectly.

Both `:879-880` and `:1007` keep their original `if (... != ...) { revert … }` structure with the new error inlined. No new helper.

### 3.2 Reject Grok's library-only test

Grok's test:

```solidity
function exposeLpReserveMismatch(uint256 held, uint256 booked) external pure {
    UniswapV2LpBacking.requireEqual(held, booked);
}
```

exercises only the library helper. Even if the helper were accepted, this test does not prove the production routes use the new error. Worse, because the helper is rejected (see 3.1), the test would also reject. The PRD requires the new error to be named **at the production sites**. The test must reach `OutTarget.sol:879-880` and `:1007` via the production proxy's `exchangeOut` route, not via a library re-export.

The settled test calls `vault_.exchangeOut(...)` directly through the registry-deployed vault (`TestBase_UniswapV2StandardExchange_MultiPool._vault()`), exercising Route 4 (zap-in vault deposit) for the `:879-880` site and Route 2 (pass-through zap-in) for the `:1007` site.

### 3.3 Reject Kimi's retarget of `:425`

Kimi's plan rewrites `SecRemediation.t.sol:425` from `vm.expectRevert(bytes(""))` to:

```solidity
vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, donate_, uint256(0)));
```

and adds an import to that file.

Source-ground-truth check: `SecRemediation.t.sol:426-428` is `vault_.exchangeIn(...)`. `exchangeIn` dispatches to `UniswapV2StandardExchangeInTarget.sol`, hitting the blank `revert()` at `InTarget.sol:730-731`. `InTarget.sol:730-731` is **not** in the PRD's edit scope (`REMEDIATION_PRD.md:5,7,28,32` name only the two OutTarget sites). Retargeting `:425` would either:

1. require also editing `InTarget.sol:730-731` to revert `LPReserveMismatch` — which expands this PRD to a third site the owner did not select, or
2. leave `InTarget.sol:730-731` blank and break `:425` (it expects a blank reason, not the new named error).

Either way the retarget breaks PRD scope. The user instructions explicitly close this: "Do not retarget that assertion." The `:425` expectation stays `bytes("")`. If InTarget's blank revert is later named in a separate PRD, that PRD owns the test change.

The decimals twin at `decimals/UniswapV2StandardExchange_SecRemediation_Decimals.sol:100` is on the same `exchangeIn` path and is also left unchanged.

### 3.4 Internal inconsistency in my own pre-cross note (settled here)

My `minimax-plan.md` used two filenames:

- Step 6: `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_LPReserveMismatch.t.sol`
- Step 7 (Forge command): `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol`

These differ. Picking one: **`UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol`**. The `Out_` segment is informative (both production guards live in `OutTarget.sol`) and matches the existing `UniswapV2StandardExchangeOut_PassThrough.t.sol` naming. The new contract name is `UniswapV2StandardExchangeOut_LPReserveMismatch_Test`.

## 4. Settled one-plan

**Declaration (in `UniswapV2StandardExchangeOutTarget.sol`, inside `UniswapV2LpBacking`, immediately after the `InsufficientLPBacking` declaration at line 1015):**

```solidity
    /// @notice Held LP differs from the booked LP reserve (either direction).
    /// @custom:signature LPReserveMismatch(uint256,uint256)
    error LPReserveMismatch(uint256 held, uint256 booked);
```

No new helper, no new selector annotation beyond the signature, no new public function.

**Site 1 replacement (`:879-880`):**

Replace

```solidity
        // A0: unbooked reserve LP cannot be absorbed by zap-in mint.
        if (indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve) {
            revert();
        }
```

with

```solidity
        // A0: unbooked reserve LP cannot be absorbed by zap-in mint.
        if (indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve) {
            revert UniswapV2LpBacking.LPReserveMismatch(
                indexSource.pool.balanceOf(address(this)), vault.vaultLpReserve
            );
        }
```

**Site 2 replacement (`:1007`):**

Replace

```solidity
        if (indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve) revert();
```

with

```solidity
        if (indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve) {
            revert UniswapV2LpBacking.LPReserveMismatch(
                indexSource.pool.balanceOf(address(this)), vault2.vaultLpReserve
            );
        }
```

Predicate stays `!=` at both sites. Argument order is held first, booked second. `InsufficientLPBacking`, `requireHeld`, and `_requireLpBacking` are unchanged.

**Line-425 assertion:** Out of scope. `SecRemediation.t.sol:425` stays `vm.expectRevert(bytes(""));`. No import of `UniswapV2LpBacking` is added to `SecRemediation.t.sol` in this PRD. The decimals twin at `decimals/UniswapV2StandardExchange_SecRemediation_Decimals.sol:100` stays unchanged.

**New test file: `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol`**

Contract `UniswapV2StandardExchangeOut_LPReserveMismatch_Test` inheriting `TestBase_UniswapV2StandardExchange_MultiPool`. Balanced pool. Fresh vault (`totalSupply() == 0`, `lastTotalAssets == 0`). Import `UniswapV2LpBacking` from the production `UniswapV2StandardExchangeOutTarget.sol`.

Four test functions, in this order:

1. `test_zapInVaultDeposit_lpReserveMismatch_reportsHeldAndBooked` — covers `:879-880`. Donate a small LP amount from a `donator` address into the vault (`held > 0`, `booked == 0`). Assert pre-state. Then from a funded, approved attacker, call `vault_.exchangeOut(IERC20(tokenA), maxAmountIn, IERC20(address(vault_)), amountOut, attacker, false, _deadline())` and expect the assertion below. Assert post-state: attacker's vault-share balance is `0`, vault's LP balance equals `donate_`, `totalSupply() == 0`.
2. `test_passThroughZapIn_lpReserveMismatch_reportsHeldAndBooked` — covers `:1007`. Same donation pattern. Then from a funded attacker, call `vault_.exchangeOut(IERC20(tokenA), maxAmountIn, IERC20(address(_pair())), amountOut, ptzRecipient, false, _deadline())` and expect the assertion below. Assert post-state: recipient's LP balance is `0`, vault's LP balance unchanged, `totalSupply() == 0`, attacker input balance not debited beyond approval.
3. `test_zapInVaultDeposit_matchingLp_preservesSuccess` — matched-book control for case 1 (no donation, `held == booked == 0`). Route succeeds, attacker receives the requested vault-share amount out.
4. `test_passThroughZapIn_matchingLp_preservesSuccess` — matched-book control for case 2 (no donation). Route succeeds, recipient receives at least the requested LP amount out.

**One assertion for both named-error cases:**

```solidity
vm.expectRevert(
    abi.encodeWithSelector(
        UniswapV2LpBacking.LPReserveMismatch.selector, heldBefore_, bookedBefore_
    )
);
```

where `heldBefore_ = pair_.balanceOf(address(vault_))` and `bookedBefore_ = uint256(0)`, both captured immediately before the `exchangeOut` call. No bare `expectRevert()`, no selector-only matcher, no `bytes("")`.

If a production route rejects earlier, yields different compared values, or is not reachable from the public proxy on this fixture, the implementer **stops and reports the actual bytes / failure mode**. Do not weaken `!=`, do not mock storage, do not switch routes, do not change the expected error to obtain a green run.

**One Forge command:**

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/decimals/UniswapV2StandardExchange_SecRemediation_Decimals.sol \
  -- -vv
```

This refreshes the changed production source and runs:
1. the new `UniswapV2StandardExchangeOut_LPReserveMismatch_Test` (two named-error + two matched-book control),
2. the existing `SecRemediation_Test` (the `:425` `bytes("")` and `:609` `InsufficientLPBacking` lower-bound assertions must still pass; every other existing assertion must still pass),
3. the decimals twin (the `:100` bare `expectRevert()` on the `exchangeIn` path must still pass).

No test-name filter. Default hermetic profile. No `via_ir`, no deletion of `out/` or `cache_forge/`, no path rewrites, no deploy or broadcast.

## 5. Stop rules

If any cited line (`OutTarget.sol:879-880`, `:1007`, `UniswapV2LpBacking` at `:1011-1020`) has drifted from this plan, or the run shows bytes other than `LPReserveMismatch(held, booked)` at the two named sites, or `SecRemediation.t.sol:425` no longer matches `InTarget.sol:730-731`'s blank `revert()`, stop and report the file, line, and actual bytes. Do not weaken `held != booked`. Do not reuse `InsufficientLPBacking`. Do not retarget `SecRemediation.t.sol:425` in this PRD. Do not introduce a `requireEqual` helper. Do not rename anything else.

## 6. Files examined where I found no defect (or that informed scope only)

- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol` (full file, 1020 lines) — sites at 879-880 and 1007 read; `UniswapV2LpBacking` at 1011-1020 read; `_requireLpBacking` at 54-56 read; `_exchangeOut_zapInVaultDeposit` at 862 and `_exchangeOut_passThroughZapIn` at 970 read for surrounding context only.
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol` lines 720-732 — read only to confirm the InTarget blank-revert site is distinct and out of scope.
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:131-139` — read only to confirm `vaultLpReserve = ERC4626Repo._lastTotalAssets()`.
- `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol` (full 655 lines) — `:425` is the only `vm.expectRevert(bytes(""))` and it is on `exchangeIn`; `:609` is the only `InsufficientLPBacking` expectation and it is on `exchangeIn`; no `expectRevert` reaches the two OutTarget sites.
- `docs/reviews/apex-rc-08-named-error/REMEDIATION_PRD.md` (full 51 lines) — controlling PRD; read in full.
- `docs/reviews/apex-rc-08-named-error/reviewers/astra-plan.md`, `grok-plan.md`, `kimi-plan.md`, and my own prior `minimax-plan.md` — read for cross-review only; no peer content was adopted as authority.
- `scripts/forge-artifacts.py` — confirmed present.

## 7. Acceptance and evidence boundaries

- One new error declaration in the owner-selected library, with held first and booked second, no helper.
- Two in-place equality guards use it; the `!=` predicate is preserved; the lower-bound error and helper are untouched.
- `UniswapV2StandardExchange_SecRemediation.t.sol:425` is left unchanged (out of scope).
- One new test file expects the complete encoded error on both OutTarget sites and includes matched-book success controls.
- One Forge command refreshes the changed production source and runs the three relevant test files.
- No unrelated production or fixture changes.

Only this assigned Markdown draft was created. No code, tests, PRD, plan, configuration or instructions were edited. No delegation, shell, test, build, chain read or deployment was performed. Return to the coordinator/human and stop.

**Settled new test file name:** `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol`

I did not run Forge.