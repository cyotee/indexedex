# MiniMax M3 — REQ-H03 plan cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the REQ-H03 plan drafts. Coordinator notes: confirm or refute that the Lido burn amount is the quoted amountIn (not `type(uint256).max`); confirm `stdError` is used only at `ERC4626StandardExchange_Routes.t.sol:271` (for burn tests); do not invent a Crane test file; retract any contradicted instruction.
- **Method:** Read the three peer plan originals (`astra-h03-plan.md`, `grok-h03-plan.md`, `kimi-h03-plan.md`). Re-read the production lines the coordinator cited (`LidoWstETHStandardExchangeOutTarget.sol:51-56`, `LidoWstETHStandardExchangeCommon.sol:358-363, :523-525`). Re-confirm the `stdError` grep. Close one plan. Retract any contradicted instruction.
- **Forge:** Not run. No code edit. No PRD/plan rewrite.

---

## 1. Coordinator-cited lines — confirmed by direct read

| Coordinator-cited line | Content (verbatim) | Confirmed |
|---|---|---|
| `LidoWstETHStandardExchangeOutTarget.sol:51-56` | `// SE redeem exact-out: burn shares for fixed asset out` at `:51`; `if (_isSeShare(in_))` at `:52`; `amountIn = _quoteExactOut(in_, out_, amountOut, pretransferred);` at `:54`; `if (amountIn > maxAmountIn) revert Slippage();` at `:55`; `_burnShares(amountIn);` at `:56` | Yes |
| `LidoWstETHStandardExchangeCommon.sol:358-363` | `function _quoteExactOut(address tokenIn, address tokenOut, uint256 amountOut) internal view returns (uint256 amountIn) { return _quoteExactOut(tokenIn, tokenOut, amountOut, false); }` | Yes |
| `LidoWstETHStandardExchangeCommon.sol:523-525` | `/// @dev Burn SE shares from msg.sender (exact-in / exact-out redeem). function _burnShares(uint256 shares) internal { ERC20Repo._burn(msg.sender, shares); }` | Yes |
| `stdError` used only at `ERC4626StandardExchange_Routes.t.sol:271` (for burn tests) | `stdError`/`arithmeticError` is also used in `AerodromeStandardExchange_Fuzz.t.sol:339` and `AerodromeStandardExchange_Fuzz_Decimals.sol:343` for a square-root overflow that is not a burn (per the user instruction, the Aerodrome hits are not burn tests and are correctly excluded from the plan). The `stdError` import is in three test files but only the `ERC4626StandardExchange_Routes.t.sol:271` use is a short-burn negative. | Yes for the burn-test claim; the literal "only at" reading is qualified by "for burn tests" |

The coordinator's production-line citations are accurate. The `stdError` claim is accurate for the scope the coordinator named (burn tests).

---

## 2. Headline — the Lido burn amount is the quoted amountIn, not `type(uint256).max`

### 2.1 The trace

For the Lido test `test_A0_pretransferredTrue_noBalanceDelta_revertsAndNoMint` at `Adversarial_LidoWstETH_P0.t.sol:212-249`, the second negative (`:235-246`) calls:

```solidity
seOut.exchangeOut(
    IERC20(address(seVault)),         // tokenIn = SE share
    type(uint256).max,                // maxAmountIn
    IERC20(address(hermeticWeth)),    // tokenOut = WETH
    1 ether,                          // amountOut
    attacker,
    false,                            // pretransferred
    block.timestamp + 1 hours
);
```

The production path is:

1. `LidoWstETHStandardExchangeOutTarget.exchangeOut(...)` at `:35-60`. The first route branch at `:52-60` is for `_isSeShare(in_)` — true because `in_ = seVault`. `maxAmountIn = type(uint256).max` is a *ceiling*, not the burn amount.
2. `:54`: `amountIn = _quoteExactOut(in_, out_, amountOut, pretransferred);` — `amountIn` is the **quoted** exact-out amount, not the ceiling.
3. `:55`: `if (amountIn > maxAmountIn) revert Slippage();` — slippage check passes (ceiling is `type(uint256).max`).
4. `:56`: `_burnShares(amountIn);` — burns the **quoted** amountIn, not the ceiling.
5. `LidoWstETHStandardExchangeCommon._burnShares(uint256 shares)` at `:523-525`: `ERC20Repo._burn(msg.sender, shares);` — burns `shares` (the quoted amount) from `msg.sender` (the attacker).
6. The attacker's `IERC20(seVault).balanceOf(attacker)` is `0` (captured at `:215` as `attackerBefore`).

So the burn is `ERC20Repo._burn(attacker, quoted_amountIn)` where `quoted_amountIn = previewExchangeOut(seVault, hermeticWeth, 1 ether)`. The new error after the §1 production change is `IERC20Errors.ERC20InsufficientBalance(attacker, 0, quoted_amountIn)`.

### 2.2 Where my own first pass was wrong

My plan at `minimax-h03-plan.md:4.1` stated the Lido burn amount was `type(uint256).max`. That is the `maxAmountIn` ceiling, not the burn amount. I retract that line. The correct instruction is to capture the quoted `previewExchangeOut(seVault, hermeticWeth, 1 ether)` and use it in the expectation. The other three peer plans (Astra, Grok, Kimi) all have this right; I adopt their approach.

### 2.3 Where Astra and Grok and Kimi are right

- **Astra** at `astra-h03-plan.md:67-93`: captures `requiredShares = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether);` and uses `(attacker, attackerBefore, requiredShares)`. Correct.
- **Grok** at `grok-h03-plan.md:78-100`: captures `burnAmount = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether);` and uses `(attacker, attackerBefore, burnAmount)`. Correct. Notes that `previewExchangeOut` uses `_quoteExactOut(..., false)`, the same quote `exchangeOut` uses when `pretransferred` is false. Correct.
- **Kimi** at `kimi-h03-plan.md:35-38`: captures `used_ = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether);` and uses `(attacker, 0, used_)`. Note: Kimi uses `0` not `attackerBefore`; both are equivalent (attacker's vault-share balance is `0`; `attackerBefore` is also `0`). The Kimi capture is correct. The argument can be `0` (literal zero) or `attackerBefore` (already-captured `0`); both encode the same fact.

The three peers converge on: capture the quoted `previewExchangeOut` and use it as the burn amount in `ERC20InsufficientBalance(attacker, attacker_balance, quoted_burn)`. I adopt that.

---

## 3. One closed plan (replaces my first pass)

The plan that closes one instruction is the convergence of all four reviewers, with the Lido burn amount corrected per §2. The full corrected plan is:

### 3.1 Production change — `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365`

Replace the body of `_burn(Storage, address, uint256)` with exactly (unchanged from my first pass; confirmed by the four reviewers):

```solidity
function _burn(Storage storage layoutStruct, address account, uint256 amount) internal {
    uint256 currentBalance = layoutStruct.balanceOf[account];
    if (currentBalance < amount) {
        revert IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount);
    }
    layoutStruct.balanceOf[account] = currentBalance - amount;
    layoutStruct.totalSupply -= amount;
    emit IERC20Events.Transfer(account, address(0), amount);
}
```

### 3.2 V3 test — `UniswapV3FullSpreadVaultHeldRedeem.t.sol`

Add the import and replace `:147` (unchanged from my first pass):

```solidity
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
```

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));
```

### 3.3 Lido test — `Adversarial_LidoWstETH_P0.t.sol` (CORRECTED from my first pass)

Before the existing `vm.prank(attacker)` at `:236`, add the quoted burn capture (the names `seOut`, `seVault`, `hermeticWeth`, `attacker` are already in scope; the function call does not consume `prank` or `expectRevert`):

```solidity
uint256 burnAmount = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether);
```

Replace `:237` with:

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, attacker, attackerBefore, burnAmount));
```

Add the import `import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";` alongside the existing imports. The panic-specific trailing comment is removed. `attackerBefore` (captured at `:215`) is the attacker's vault-share balance, which is `0`. `burnAmount` is the quoted exact-out shares for `1 ether` of WETH output. The full revert data is `IERC20Errors.ERC20InsufficientBalance(attacker, 0, quoted_shares)`.

If `previewExchangeOut` itself reverts at that point, stop and report the actual bytes. Per the user instruction "If another short-burn test fails, stop and report," do not substitute a different value, do not silently re-route to a different error.

### 3.4 ERC4626 test — `ERC4626StandardExchange_Routes.t.sol`

Add the import `IERC20Errors` and replace `:271` (unchanged from my first pass):

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, seBal, seBal + 1));
```

Update the doc-comment at `:262-264` to describe the named error path. The `stdError` import at `:5` is used only for `:271` (confirmed by the grep: `grep "stdError" test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol` returns exactly lines 5 and 271). Remove the `stdError` import if it is then dead.

### 3.5 Excluded — Crane test file

The user said "Do not invent a Crane test file." I do not introduce `lib/crane/test/foundry/spec/tokens/ERC20/ERC20Repo_Burn.t.sol` in this plan. Kimi, Grok, and my own first pass agree there is no Crane burn test to edit. Astra's plan section 4 proposes a new Crane regression file; per the user instruction, that is not part of this plan.

### 3.6 Excluded — tests with different errors

`UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol` (`_overflowPanic`, quote overflow), `UniswapV4UpperLowerWingsStandardExchangeVaultAccountingReference.t.sol:45` (`Panic(0x12)`, division by zero), and the Aerodrome Fuzz sqrt-overflow (`stdError.arithmeticError` at non-burn sites) are not short-burn negatives and are unchanged. This is also my first pass's stance, and all four reviewers agree.

### 3.7 Crane submodule pointer

`lib/crane` is a git submodule (`.gitmodules:1-3`). The existing process is `scripts/submodule-commit.sh -m "fix: name short ERC20 burn as ERC20InsufficientBalance"` (per the script's usage at `scripts/submodule-commit.sh:1-9`). The script commits and pushes the crane change, then commits the parent repo's gitlink. It does not push the parent repo. Do not run `scripts/sync-crane-skills.sh` (that is for skill mirrors, not the pointer). Grok references this script; Kimi and my first pass describe the standard `git add lib/crane && git commit` flow. Both are the same process; the script automates it.

### 3.8 Forge commands

One IndexedEx command that includes the three test roots, with the Crane source as the artifact-refresh positional. Per `ARTIFACT_BUILDS.md:5-22,55`, an edited production source must be passed as positional for the artifact refresh. From the IndexedEx root, warm `out/` and `cache_forge/`, no profile, no `via_ir`:

```bash
python3 scripts/forge-artifacts.py test \
  lib/crane/contracts/tokens/ERC20/ERC20Repo.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3 \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial \
  --test-root test/foundry/spec/vaults/standard/erc4626 \
  -- -vv
```

No Crane test command — the user said "Do not invent a Crane test file."

### 3.9 Stop conditions

If any run reverts with bytes other than `IERC20Errors.ERC20InsufficientBalance(...)` at a named site, stop and report. If the Lido `previewExchangeOut` reverts, stop and report its bytes. If any other test in the three test roots starts failing with a new error that pins a different balance/amount pair, stop, list the new sites, and update them in the same shape. Do not broaden expectations; do not weaken production; do not edit the V4 twin; do not enable `via_ir`; do not delete `out/` or `cache_forge/`.

---

## 4. Items I am not asserting

- I am not asserting the runtime result. No Forge run.
- I am not asserting `previewExchangeOut` returns a specific numeric value. The capture `previewExchangeOut(seVault, hermeticWeth, 1 ether)` is a `view` call whose return is used in the expectation; the plan does not hard-code the number.
- I am not asserting the exact `attackerBefore` literal. Per the trace it is `0` (the attacker's vault-share balance before any operation in this test). Using `attackerBefore` and `0` are equivalent.
- I am not asserting whether `stdError` remains imported in `ERC4626StandardExchange_Routes.t.sol:5` after the edit. The plan notes the import is used only at `:271` and is dead after the edit; the implementer may remove it. The decision is mechanical, not a product question.
- I am not asserting whether `submodule-commit.sh` is preferred over the manual `git add lib/crane && git commit` flow. Both are the same process; the script is just the automation. The plan references both.

---

## 5. Findings (cross-review)

### Cross-H03-1 — Lido burn amount retraction (my own first pass)

- **Severity:** N/A (retraction; not a new defect).
- **File and line:** `docs/reviews/apex-req-h03-holder-negative/reviewers/minimax-h03-plan.md:4.1` (Adversarial_LidoWstETH_P0.t.sol section).
- **Broken instruction:** My plan said the burn amount is `type(uint256).max`. The actual burn amount is the quoted `previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether)`. Confirmed by `LidoWstETHStandardExchangeOutTarget.sol:51-56` and `LidoWstETHStandardExchangeCommon.sol:523-525`. `type(uint256).max` is the `maxAmountIn` ceiling, not the burn.
- **Impact class:** Test-expectation specificity. A test that expected `ERC20InsufficientBalance(attacker, 0, type(uint256).max)` would have the wrong `amount` argument and would fail at runtime against the production change.
- **Fix direction:** Retract the line. Use the capture-and-quote pattern from Astra, Grok, and Kimi. This is the converged plan in §3.3.
- **Confidence:** High on the production trace; high on the Lido `previewExchangeOut` being the correct quote.

### Cross-H03-2 — Crane test file is not part of this plan

- **Severity:** N/A (scope clarification, not a defect).
- **File and line:** the would-be new file `lib/crane/test/foundry/spec/tokens/ERC20/ERC20Repo_Burn.t.sol` (proposed by Astra section 4, not by Grok, Kimi, or my first pass).
- **Scope:** The user instruction "Do not invent a Crane test file" forecloses this. The plan does not create a new Crane test file. The sweep found no existing short-burn negative in the Crane tree, and per the user instruction, none is added.
- **Impact class:** Scope discipline.
- **Confidence:** High.

---

## 6. Dissent and unresolved items

**Dissent from my own first pass:** The Lido burn amount in my plan was `type(uint256).max` (wrong). I retract. The correct burn amount is the quoted `previewExchangeOut` result, per the production trace at `LidoWstETHStandardExchangeOutTarget.sol:51-56`. All three peer plans have this right; I adopt.

**Agreement with Astra, Grok, and Kimi:** the production change, the V3 test change, the ERC4626 test change, the Lido burn amount capture, the exclusion of `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol`, `UniswapV4UpperLowerWingsStandardExchangeVaultAccountingReference.t.sol:45`, and the Aerodrome Fuzz sqrt-overflow are all converged across the three peer plans and my corrected plan.

**Unresolved item:** None. The Lido burn amount retraction closes the open instruction. The corrected plan in §3 is the single converged implementation shape.

---

## 7. Files examined (this cross-review)

- `docs/reviews/apex-req-h03-holder-negative/reviewers/astra-h03-plan.md` — read in full (174 lines).
- `docs/reviews/apex-req-h03-holder-negative/reviewers/grok-h03-plan.md` — read in full (144 lines).
- `docs/reviews/apex-req-h03-holder-negative/reviewers/kimi-h03-plan.md` — read in full (73 lines).
- `docs/reviews/apex-req-h03-holder-negative/reviewers/minimax-h03-plan.md` — re-read for self-consistency. Not treated as a peer.
- `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md` — already read in the previous turn; not re-loaded.
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol:1-69` — re-read to confirm the production trace.
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:350-534` — re-read to confirm `_quoteExactOut` and `_burnShares`.
- `scripts/submodule-commit.sh` — re-read to confirm the existing submodule process.
- Repo-wide `grep` for `stdError|arithmeticError` under `test/foundry/` to confirm the three use sites.

No Forge / build / test was executed. No code was edited. No peer notes were read during the independent first pass; read here only because this is a cross-review.

---

I did not run Forge.