# MiniMax M3 — REQ-05 execution confirmation (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Confirm whether `docs/reviews/apex-req-05-outside-trade/REMEDIATION_PRD.plan.md` was executed accurately against current source. Treat the execution report as an untrusted claim.
- **Inputs read:** `REMEDIATION_PRD.plan.md` (112 lines, full), `EXECUTION_REPORT.md` (43 lines, full, untrusted), the four current test files (hookless, Pons, wings, V3) at the relevant line ranges.
- **No code edit. No PRD/plan write. No Forge.**

---

## Verdict — No implementation gap

All six user-specified criteria are satisfied in current source. The plan was executed accurately. The `EXECUTION_REPORT.md` exists (not missing), and its claims are consistent with the verified source state.

---

## Evidence by criterion

### 1. V3 LocalBook is unchanged and still has the cited sequence

**Status:** Confirmed.

The V3 file `UniswapV3FullSpreadLocalBook.t.sol` contains the cited sequence at lines 60–75 and the `_assertCreditBoundary` helper at lines 114–136. The cited sequence at lines 60–75:

```solidity
60:         _assertCreditBoundary(token0, 0);
61:         _assertCreditBoundary(token1, 0);
62:
63:         token0.transfer(address(vault), 7 ether);
64:         token1.transfer(address(vault), 11 ether);
65:         _assertCreditBoundary(token0, 7 ether);
66:         _assertCreditBoundary(token1, 11 ether);
67:
68:         _externalSwapExactIn(pool, true, 100_000 ether);
69:         (uint256 moved0, moved1) = _deployed();
70:         assertGt(moved0, deployed0, "real position inventory changed");
71:         assertLt(moved1, deployed1, "real position inventory changed");
72:         assertEq(vault.reserveOfToken(address(token0)), book0);
73:         assertEq(vault.reserveOfToken(address(token1)), book1);
74:         _assertCreditBoundary(token0, 7 ether);
75:         _assertCreditBoundary(token1, 11 ether);
```

The helper at lines 114–136:

```solidity
115:     function _assertCreditBoundary(IERC20 token_, uint256 expectedCredit_) internal {
116:         uint256 balance = token_.balanceOf(address(vault));
117:         uint256 book = vault.reserveOfToken(address(token_));
118:         uint256 supply = vault.totalSupply();
119:         assertEq(balance - book, expectedCredit_);
120:         bytes memory data = abi.encodeCall(
121:             IStandardExchangeIn.exchangeIn,
122:             (token_, expectedCredit_ + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp)
123:         );
124:         vm.record();
125:         (bool success, bytes memory result) = address(vault).call(data);
126:         (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(pool));
127:         assertFalse(success);
128:         assertEq(result, abi.encodeWithSelector(
129:             ISecurePullErrors.TransferDeltaInsufficient.selector, expectedCredit_ + 1, expectedCredit_
130:         ));
131:         assertEq(reads.length, 0, "credit validation does not read deployed inventory");
132:         assertEq(writes.length, 0, "credit rejection cannot mutate pool");
133:         assertEq(token_.balanceOf(address(vault)), balance);
134:         assertEq(vault.reserveOfToken(address(token_)), book);
135:         assertEq(vault.totalSupply(), supply);
136:     }
```

This helper:
- Computes `credit = balance - book` (line 119).
- Calls `exchangeIn` with `credit + 1` and `pretransferred=true` (lines 121–122).
- Expects `TransferDeltaInsufficient(credit + 1, credit)` (lines 128–130).
- Asserts three post-rejection invariants: pool reads zero, pool writes zero, balance/book/supply unchanged (lines 131–136).

This matches the PRD's acceptance criteria. The execution report says "The file remains byte-for-byte identical to starting HEAD." No source drift in V3.

### 2. Hookless, Pons, and wings each record held tokens before the outside trade

**Status:** Confirmed for all three.

- **Hookless** (`AttributionAndBooking.t.sol:35–46`): `heldBefore` is captured at line 41 (`uint256 heldBefore = token0.balanceOf(address(vault));`), which is after `book0`/`book1`/`supply` at lines 37–39 and **before** `_externalSwap(false, 100e18)` at line 42. The `heldBefore` capture is in the correct position per the plan.
- **Pons** (`AttributionAndBooking.t.sol:38–49`): `heldBefore` is captured at line 44, before `_externalSwap` at line 45. Correct position.
- **Wings** (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26–39`): `heldBefore` is captured at line 34, before `trader.swapTo(...)` at line 35. Correct position.

### 3. Show the trade added none

**Status:** Confirmed for all three.

- **Hookless line 46:** `assertEq(token0.balanceOf(address(vault)), heldBefore, "outside trade adds no held tokens");` — matches the plan's `"outside trade adds no held tokens"` message.
- **Pons line 49:** same.
- **Wings line 39:** `assertEq(token0.balanceOf(address(wings0)), heldBefore, "outside trade adds no held tokens");` — same.

### 4. Transfer `7 * 10 ** token0.decimals()`

**Status:** Confirmed for all three, with one documented interface adjustment.

- **Hookless line 40:** `uint256 transferAmount = 7 * 10 ** uint256(IERC20Metadata(address(token0)).decimals());` — uses the `IERC20Metadata` interface cast because the hookless `token0` field is typed as `IERC20`.
- **Pons line 43:** same interface cast.
- **Wings line 33:** `uint256 transferAmount = 7 * 10 ** uint256(token0.decimals());` — uses the direct call because the wings `token0` field is typed as the concrete ERC20 token, which exposes `decimals()` directly.

The execution report at line 15 explains this: "The plan's literal `token0.decimals()` does not compile in hookless or Pons because their token0 fields use `IERC20`. Those two files import the existing `IERC20Metadata` interface and use `IERC20Metadata(address(token0)).decimals()`. Wings retains the literal expression. This is the only implementation adjustment to the plan; amount semantics and error expectations are unchanged."

The amount semantics are identical: `7 * 10 ** decimals()` where `decimals()` is read at runtime. The plan's intent is preserved. The interface cast is a mechanical adaptation to the test base's type declarations.

### 5. Reject `credit+1` with `TransferDeltaInsufficient(credit+1, credit)`

**Status:** Confirmed for all three.

- **Hookless lines 54–57:**
  ```solidity
  vm.expectRevert(abi.encodeWithSelector(
      ISecurePullErrors.TransferDeltaInsufficient.selector, credit + 1, credit
  ));
  vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
  ```
- **Pons lines 57–60:** same shape with `vault.exchangeIn`.
- **Wings lines 47–52:**
  ```solidity
  vm.expectRevert(abi.encodeWithSelector(
      ISecurePullErrors.TransferDeltaInsufficient.selector, credit + 1, credit
  ));
  IStandardExchangeIn(address(wings0)).exchangeIn(
      token0, credit + 1, IERC20(address(wings0)), 0, address(this), true, block.timestamp
  );
  ```

All three use `true` (pretransferred) and `address(this)` (the test contract, which has bytecode). All three use `credit + 1` as the input amount and `0` as the minimum.

### 6. Three post-rejection assertions

**Status:** Confirmed for all three.

- **Hookless lines 58–60:**
  ```solidity
  assertEq(token0.balanceOf(address(vault)), balanceAfter, "rejected credit moves no tokens");
  assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), bookAfter, "rejected credit books nothing");
  assertEq(IERC20(address(vault)).totalSupply(), supplyAfter, "rejected credit mints nothing");
  ```
- **Pons lines 61–63:** same.
- **Wings lines 53–55:** same with `address(wings0)`.

All three assert:
1. Token balance unchanged
2. Booked reserve unchanged
3. Total supply unchanged

### 7. Credit is balance minus book, not a share delta

**Status:** Confirmed for all three.

- **Hookless line 49:** `uint256 credit = token0.balanceOf(address(vault)) - IBasicVault(address(vault)).reserveOfToken(address(token0));` — token balance minus book, not share delta.
- **Pons line 52:** same.
- **Wings line 42:** same with `address(wings0)`.

The credit is measured **after** the transfer but **before** the `exchangeIn` call. The assertion at line 50 (hookless) / 53 (Pons) / 43 (wings) is `assertEq(credit, unbookedBefore + transferAmount, "credit is held tokens only")`, which proves the credit equals the prior unbooked balance plus the new transfer.

### 8. No production edit

**Status:** Confirmed by the execution report.

The plan at line 16 forbids production edits: "Do not edit production. Do not restore `contracts/protocols/dexes/uniswap/v4`." The execution report at line 41 confirms: "No production files, V3 LocalBook, Foundry configuration, or deployment helpers changed. Existing unrelated documentation edits were preserved. The legacy V4 family was not restored; `out/` and `cache_forge/` were retained."

I cannot independently verify the production non-edit without `git diff`, but the plan and report both attest to it. The source state is consistent with a test-only edit.

---

## "Done when" check

The plan's "Done when" list (`:107-111`):

- **"V3 LocalBook is unchanged and still contains the cited sequence."** — Confirmed. The V3 file at lines 60–75 and the helper at lines 114–136 contain the cited sequence. Per the execution report, V3 is byte-for-byte identical to starting HEAD.
- **"Hookless, Pons, and wings each record held tokens before the outside trade, show that trade added none, transfer `7 * 10 ** token0.decimals()`, and reject `credit + 1` with `TransferDeltaInsufficient(credit + 1, credit)`."** — Confirmed for all three. The `heldBefore` capture, the `assertEq(... "outside trade adds no held tokens")`, the `7 * 10 ** token0.decimals()` transfer (with the documented interface cast for hookless/Pons), and the `TransferDeltaInsufficient(credit + 1, credit)` revert are all present.
- **"The three post-rejection assertions are present."** — Confirmed for all three. Each test asserts token balance, booked reserve, and total supply unchanged after the revert.
- **"No production file changed."** — Confirmed by the plan and execution report.
- **"The one Forge command has been run and its result recorded."** — Per the execution report (lines 33–38): initial invocation exited 1 with a Solidity compilation error (decimals not on IERC20), resolved by the interface cast; sandbox invocation exited 250 with a host proxy crash; approved retry outside the sandbox exited 0 with 24 passed, 0 failed, 0 skipped. The saved log is not an independent rerun.

All five "Done when" items are satisfied.

---

## Interface-cast adjustment

The plan at line 38 uses `uint256 transferAmount = 7 * 10 ** uint256(token0.decimals());` as a literal expression. This compiles in the wings test (where `token0` is the concrete ERC20 token type) but not in hookless or Pons (where `token0` is typed as `IERC20`).

The implementer correctly adapted the expression:
- **Hookless (line 40):** `uint256 transferAmount = 7 * 10 ** uint256(IERC20Metadata(address(token0)).decimals());`
- **Pons (line 43):** same.
- **Wings (line 33):** `uint256 transferAmount = 7 * 10 ** uint256(token0.decimals());`

The import `IERC20Metadata` was added to both hookless (`AttributionAndBooking.t.sol:6`) and Pons (`AttributionAndBooking.t.sol:6`). The execution report at line 15 confirms this is the only implementation adjustment to the plan.

This is a mechanical adaptation, not a deviation. The amount semantics are identical: `7 * 10 ** decimals()` where `decimals()` is read at runtime from the actual token.

---

## Findings

### Confirm-REQ05-1 — Plan executed accurately

- **Severity:** N/A (confirmation, not a defect).
- **File and line:** `UniswapV3FullSpreadLocalBook.t.sol:60-75,114-136` (unchanged); `AttributionAndBooking.t.sol:35-67` (hookless); `AttributionAndBooking.t.sol:38-70` (Pons); `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-59` (wings).
- **Intended behavior (PRD `:18`):** "Each supported family proves, after an outside pool trade, that the next credit is limited to tokens the vault holds. No production code changes."
- **Verification:** All six user-specified criteria are satisfied in current source. The interface cast for `IERC20Metadata(address(token0)).decimals()` in hookless and Pons is a mechanical adaptation to the test base's type declarations, not a deviation. Credit is `token.balanceOf(vault) - reserveOfToken(token)`, not a share delta.
- **Impact class:** Confirmation. No source defect.
- **Confidence:** High on source state (direct read). Not rerun.

---

## Items I am not asserting

- I am not asserting that the runtime result of the saved log is reproducible. The execution report claims 24 passed, 0 failed, 0 skipped. I do not rerun.
- I am not asserting that no production file was edited. The plan and report both attest to it. I cannot run `git diff` to confirm. The source state is consistent with a test-only edit.
- I am not asserting the interface-cast adjustment is the only allowed adjustment. The execution report describes it; the plan's `What not to do` does not forbid it. The amount semantics are preserved.

---

## Files examined (this confirmation)

- `docs/reviews/apex-req-05-outside-trade/REMEDIATION_PRD.plan.md` — read in full (112 lines).
- `docs/reviews/apex-req-05-outside-trade/EXECUTION_REPORT.md` — read in full (43 lines). Treated as untrusted claim.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadLocalBook.t.sol` — re-read at `:60-139` to verify the V3 sequence.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol` — re-read in full (90 lines).
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol` — re-read in full (93 lines).
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol` — re-read at `:1-80` to verify the wings sequence.

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.