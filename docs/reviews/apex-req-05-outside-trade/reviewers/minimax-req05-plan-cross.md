# MiniMax M3 — REQ-05 plan cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the REQ-05 plan drafts. Retract the share-delta-as-credit shape. Close one plan.
- **Method:** Read the three peer plan originals (`astra-req05-plan.md`, `grok-req05-plan.md`, `kimi-req05-plan.md`). Re-read the PRD at `docs/reviews/apex-req-05-outside-trade/REMEDIATION_PRD.md`.
- **Untrusted:** the three peer originals, treated as model content.
- **Forge:** Not run. No code edit. No PRD/plan write.

---

## Coordinator's note — retracted

The coordinator's note is correct. My first-pass plan at `minimax-req05-plan.md` used the share-delta-as-credit shape:

```solidity
uint256 beforeCallerShares = IERC20(address(vault)).balanceOf(address(this));
...
vault.exchangeIn(token0, 7e18, IERC20(address(vault)), 0, address(this), true, block.timestamp);
uint256 credit = IERC20(address(vault)).balanceOf(address(this)) - beforeCallerShares;
assertEq(credit, beforeBalanceToken0 - beforeReserveToken0, "credit equals balance minus book");
```

This is the wrong shape. The `credit` variable was defined as the share-delta after a pretransferred `exchangeIn` — that is, the number of shares minted to the caller. The PRD at `:37` defines credit differently: "Available credit is `token.balanceOf(vault) - vault.reserveOfToken(token)`. Assert it equals the fixed transfer plus any unbooked balance recorded before the transfer."

The correct `credit` is the **token-unbooked** amount, measured directly from the vault's balance and book, **without** first calling `exchangeIn`. The proof is:

1. Capture `preUnbooked = token0.balanceOf(vault) - reserveOfToken(token0)` **before** the transfer.
2. Transfer `amount` to the vault.
3. Compute `credit = token0.balanceOf(vault) - reserveOfToken(token0)` **after** the transfer.
4. Assert `credit == preUnbooked + amount`.
5. Expect `TransferDeltaInsufficient(credit + 1, credit)` on `vault.exchangeIn(token0, credit + 1, IERC20(vault), 0, address(this), true, block.timestamp)`.

This is a pretransfer credit-bound proof, not a post-deposit share-delta proof. I retract the share-delta shape.

The coordinator also flags the wings decimal issue. Wings sorts tokens by address; `token0` is not statically guaranteed to be 18-decimal. I had hardcoded `7e18` for wings, which is wrong if `token0` is 6-decimal. The correct amount is `7 * 10 ** token0.decimals()`.

---

## Per-reviewer synthesis

### Astra (`astra-req05-plan.md`, 140 lines)

- **Token/amount:**
  - Hookless/Pons: `token0`, `7 ether`
  - Wings: `token0` (the target of `wings0`), `7 * 10 ** uint256(token0.decimals())` (`:87`). Correctly computes decimals, not hardcoded.
- **Pre-trade capture:** Adds `uint256 heldBeforeTrade = token0.balanceOf(address(vault))` (or `address(wings0)`) **before** the outside swap. This anchors the unbooked custody independently of pool movement.
- **Credit shape:** `uint256 credit = held - booked` (`:63`, `:92`), where `held = token0.balanceOf(vault)` and `booked = IBasicVault(...).reserveOfToken(token0)`. This is the PRD-correct `credit = balance - book` shape.
- **Assertion:** `assertEq(credit, unbookedBefore + 7 ether, "credit is only held excess plus transfer")` (`:64`, `:93`). Correctly asserts `credit == unbookedBefore + amount`.
- **Revert:** `TransferDeltaInsufficient(credit + 1, credit)` on `vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp)` (`:65-68`, `:95-99`).
- **Rollback:** Asserts `token0.balanceOf`, `reserveOfToken`, and `totalSupply` are unchanged after the revert (`:69-71`, `:100-102`).

### Grok (`grok-req05-plan.md`, 65 lines)

- **Token/amount:** All three families use `token1`, `7 ether`. Says "The token is `token1`. It has 18 decimals in all three fixtures." I am uncertain this is correct for wings (Kimi notes wings `token0` is 6-decimal). Grok's claim that token1 is 18-decimal in wings may be wrong.
- **Credit shape:** `uint256 credit = token1.balanceOf(address(vault)) - IBasicVault(address(vault)).reserveOfToken(address(token1))` (`:31`). PRD-correct shape.
- **Pre-unbooked capture:** "Record `unbooked` as `token1.balanceOf(vault) - reserveOfToken(token1)` before the transfer."
- **Assertion:** `assertEq(credit, unbooked + 7 ether)` implied.
- **Revert:** `TransferDeltaInsufficient(credit + 1, credit)`.
- **No rollback assertions** in the block (differs from Astra and Kimi).

### Kimi (`kimi-req05-plan.md`, 63 lines)

- **Token/amount:**
  - Hookless/Pons: `token0`, `7 ether`
  - Wings: `token0`, `7 * 10 ** 6` (`:24`). This **hardcodes** the 6-decimal assumption. The coordinator's note says "do not hardcode 7 ether or 7 * 10**6." Kimi's wings amount is wrong by the coordinator's instruction.
- **Credit shape:** `uint256 credit_ = token0.balanceOf(address(<vault>)) - IBasicVault(address(<vault>)).reserveOfToken(address(token0))` (`:31`). PRD-correct.
- **Pre-unbooked capture:** `uint256 preUnbooked_ = ...` (`:29`).
- **Assertion:** `assertEq(credit_, preUnbooked_ + <amount>, "credit is the held surplus only")` (`:32`).
- **Revert:** `TransferDeltaInsufficient(credit_ + 1, credit_)`.
- **Rollback:** Asserts `token0.balanceOf`, `reserveOfToken`, `totalSupply` unchanged (`:38-40`).

### Mine (this session's `minimax-req05-plan.md`)

- **Retracted.** I used the share-delta-as-credit shape (after a pretransferred `exchangeIn` minted shares) and hardcoded `7e18` for wings. Both are wrong per the coordinator's note and per the PRD at `:36-37`.

---

## One closed plan

The converged plan adopts:

- **Credit shape (from the PRD `:37`):** `credit = token.balanceOf(vault) - reserveOfToken(token)`. This is measured **before** the caller's `exchangeIn` attempt, not after. The proof is a pretransfer credit-bound, not a post-deposit share-delta.
- **Wings decimal (from the coordinator's note):** `7 * 10 ** token0.decimals()`. Do not hardcode `7 ether` or `7 * 10**6`. The token's decimals are read at runtime.
- **Token/amount (from the three families' acceptance bases):**
  - Hookless: `token0` is 18-decimal. Amount: `7 ether`.
  - Pons: `token0` is 18-decimal. Amount: `7 ether`.
  - Wings: `token0` is the wings0 target. Amount: `7 * 10 ** token0.decimals()` (computed at runtime).
- **Caller (from the user):** `address(this)` (the test contract, has bytecode). No EOA.
- **Pre-unbooked capture (from the PRD `:37`):** `preUnbooked = token0.balanceOf(vault) - reserveOfToken(token0)` is captured **before** the transfer, so the assertion `credit == preUnbooked + amount` proves the credit equals the held surplus plus the new transfer, not the outside trade's pool movement.

### The exact new block — per file

#### Hookless file (`AttributionAndBooking.t.sol`)

Insert after line 42 and before line 43:

```solidity
        // REQ-05-1 held-token credit: contract caller (address(this) has
        // bytecode) transfers token0, is credited exactly the held surplus
        // plus the new transfer, and cannot redeem one more share.
        uint256 preUnbookedHookless = token0.balanceOf(address(vault)) - IBasicVault(address(vault)).reserveOfToken(address(token0));
        assertTrue(token0.transfer(address(vault), 7 ether), "token0 transfer");
        uint256 creditHookless = token0.balanceOf(address(vault)) - IBasicVault(address(vault)).reserveOfToken(address(token0));
        assertEq(creditHookless, preUnbookedHookless + 7 ether, "credit is only held surplus plus transfer");
        uint256 postBalHookless = token0.balanceOf(address(vault));
        uint256 postBookHookless = IBasicVault(address(vault)).reserveOfToken(address(token0));
        uint256 postSupplyHookless = IERC20(address(vault)).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector,
            creditHookless + 1,
            creditHookless
        ));
        vault.exchangeIn(token0, creditHookless + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
        assertEq(token0.balanceOf(address(vault)), postBalHookless, "rejection preserves held tokens");
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), postBookHookless, "rejection preserves book");
        assertEq(IERC20(address(vault)).totalSupply(), postSupplyHookless, "rejection preserves supply");
```

#### Pons file (`AttributionAndBooking.t.sol`)

Insert after line 45 and before line 46, same shape with `vault` instead of hookless's `vault`:

```solidity
        uint256 preUnbookedPons = token0.balanceOf(address(vault)) - IBasicVault(address(vault)).reserveOfToken(address(token0));
        assertTrue(token0.transfer(address(vault), 7 ether), "token0 transfer");
        uint256 creditPons = token0.balanceOf(address(vault)) - IBasicVault(address(vault)).reserveOfToken(address(token0));
        assertEq(creditPons, preUnbookedPons + 7 ether, "credit is only held surplus plus transfer");
        uint256 postBalPons = token0.balanceOf(address(vault));
        uint256 postBookPons = IBasicVault(address(vault)).reserveOfToken(address(token0));
        uint256 postSupplyPons = IERC20(address(vault)).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector,
            creditPons + 1,
            creditPons
        ));
        vault.exchangeIn(token0, creditPons + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
        assertEq(token0.balanceOf(address(vault)), postBalPons, "rejection preserves held tokens");
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), postBookPons, "rejection preserves book");
        assertEq(IERC20(address(vault)).totalSupply(), postSupplyPons, "rejection preserves supply");
```

#### Wings file (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol`)

Insert after line 36 and before line 37. The amount is `7 * 10 ** token0.decimals()` (computed at runtime, not hardcoded):

```solidity
        uint256 wingsTransferAmount = 7 * 10 ** uint256(token0.decimals());
        uint256 preUnbookedWings = token0.balanceOf(address(wings0)) - IBasicVault(address(wings0)).reserveOfToken(address(token0));
        assertTrue(token0.transfer(address(wings0), wingsTransferAmount), "token0 transfer");
        uint256 creditWings = token0.balanceOf(address(wings0)) - IBasicVault(address(wings0)).reserveOfToken(address(token0));
        assertEq(creditWings, preUnbookedWings + wingsTransferAmount, "credit is only held surplus plus transfer");
        uint256 postBalWings = token0.balanceOf(address(wings0));
        uint256 postBookWings = IBasicVault(address(wings0)).reserveOfToken(address(token0));
        uint256 postSupplyWings = IERC20(address(wings0)).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector,
            creditWings + 1,
            creditWings
        ));
        IStandardExchangeIn(address(wings0)).exchangeIn(
            token0, creditWings + 1, IERC20(address(wings0)), 0, address(this), true, block.timestamp
        );
        assertEq(token0.balanceOf(address(wings0)), postBalWings, "rejection preserves held tokens");
        assertEq(IBasicVault(address(wings0)).reserveOfToken(address(token0)), postBookWings, "rejection preserves book");
        assertEq(IERC20(address(wings0)).totalSupply(), postSupplyWings, "rejection preserves supply");
```

The wings amount uses `7 * 10 ** uint256(token0.decimals())` because wings sorts tokens by address and the fixture's `token0` may be 6-decimal or 18-decimal. Reading decimals at runtime avoids hardcoding either value. This is the coordinator's instruction.

---

## One Forge command for the three files

From the IndexedEx root, hermetic profile, no `via_ir`, warm `out/` and `cache_forge/`:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol \
  -- -vv
```

V3 LocalBook is not in the command per the user's instruction. No `via_ir`. Warm artifacts preserved.

---

## Where I agree

1. **Credit = token.balanceOf(vault) - reserveOfToken(token).** This is the PRD-correct definition. All three peer plans and the corrected version of my own plan agree.
2. **Wings amount = `7 * 10 ** token0.decimals()`.** Computed at runtime, not hardcoded. This matches the coordinator's instruction.
3. **Caller = `address(this)`** (the test contract, has bytecode). No EOA. All three peer plans agree.
4. **Expected revert = `TransferDeltaInsufficient(credit + 1, credit)`.** On a true-flag `exchangeIn` (`pretransferred=true`). All three peer plans agree.
5. **Rollback assertions** (Astra and Kimi add them; Grok does not). The closed plan includes them as a stronger check.

## Where I add precision

1. **Grok's choice of `token1` is unsupported by the fixture evidence.** The wings fixture at `TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol:35` creates one 6-decimal and one 18-decimal token, then sorts them. The smaller-address token is `token0`. Whether `token1` is 6- or 18-decimal depends on the sort. Grok claims `token1` is 18-decimal in all three fixtures; this is not verified by any base that I can see. The safer choice is `token0` (the target of `wings0` per the wings test base at `:49`) with a runtime-decimals amount, which is what Astra, Kimi, and the corrected plan do.
2. **Kimi's hardcoded `7 * 10 ** 6` for wings is wrong per the coordinator's instruction.** Kimi correctly identified that wings `token0` is 6-decimal, but the coordinator says "do not hardcode 7 * 10**6." The correct approach is `7 * 10 ** token0.decimals()`, which works for any decimal.

---

## What would change this answer

I would re-open the answer only if:

1. The PRD defines `credit` differently from `token.balanceOf(vault) - reserveOfToken(token)`. — Not true. PRD `:37` is explicit.
2. The wings fixture's `token0` is statically 18-decimal. — Not true. Kimi and Astra both note wings `token0` is 6-decimal; the fixture sorts by address.
3. An EOA caller is required. — Not true. The user said "do not use an EOA" and "a caller that has bytecode."
4. The reverted call does not produce `TransferDeltaInsufficient(credit + 1, credit)`. — Not established. The implementer verifies; if different bytes appear, the plan records them and stops.

None of these is true. The closed plan stands.

---

## Dissent or unresolved items

**Dissent from my own first-pass plan.** The share-delta-as-credit shape and the hardcoded `7e18` for wings are both wrong. I retract.

**Agreement with the three peer plans' converged shape.** All three peers use `credit = balance - book`. Astra and Kimi add rollback assertions; Grok does not. The closed plan includes rollback assertions for a stronger check.

**Unresolved item:** None. The closed plan is the single converged shape.

---

## Files examined (this cross-review)

- `docs/reviews/apex-req-05-outside-trade/REMEDIATION_PRD.md` — re-read in full (50 lines).
- `docs/reviews/apex-req-05-outside-trade/reviewers/astra-req05-plan.md` — re-read in full (140 lines).
- `docs/reviews/apex-req-05-outside-trade/reviewers/grok-req05-plan.md` — re-read in full (65 lines).
- `docs/reviews/apex-req-05-outside-trade/reviewers/kimi-req05-plan.md` — re-read in full (63 lines).
- `docs/reviews/apex-req-05-outside-trade/reviewers/minimax-req05-plan.md` — re-read for self-consistency. Not treated as a peer.

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.