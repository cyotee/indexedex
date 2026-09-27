# Implementation Plan — APEX 2026-09-17 Remediation Council (Round 2026-09-26)

**Author:** MiniMax M3 (independent first pass)
**Date:** 2026-09-26
**Session:** ses_f25dce4b0ffeJ52QXMtLXQMGVW (resumed)
**Status:** DRAFT — independent pass; not yet cross-reviewed.
**Allowed output root:** `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md` (moderator consolidates).
**This file:** `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-minimax-original.md` (preserved original; overwrites prior version on submission; will not be touched again by me after I emit the substantive findings to the moderator).

## Scope guardrails (from PRD, restated for the plan)

- Fresh deployments only. No migration of live inventory, no fork replay, no `via_ir`, no mocks of the SUT.
- Preserve `contracts/protocols/dexes/uniswap/{v3,v4}/` historical trees; do **not** select their bytecode for a new deploy.
- Production-first TestBases (`CraneTest → IndexedexTest → protocol TestBase`).
- Foundry profile `default` (hermetic). No fork RPC. `via_ir = false` (`foundry.toml:36`).
- Solc `0.8.35`, optimizer on, runs `1`, fuzz/invariant runs `16` (`foundry.toml:29-45`).
- No new economic ruling; no feeTo dust reintroduction; no donation of D12 resting inventory; D32 pretransfer lock preserved; no change to Aave LM rewards forwarding.
- RC-05, RC-06, and the named RC-08 error are implementer choices. RC-03 reading (include booked aToken) is settled.

## Severity / dissent reminders I will not relitigate

- RC-01: Severity set Medium in PRD; implementation still required.
- RC-07: Severity set Low in PRD; Kimi Medium is informational.
- RC-06: PRD allows either "make return truthful" or "remove return". I treat both as implementer choices.

---

## RC-01 — Standalone Balancer adapter: reentrancy guard + bounded approvals

### Touch set
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:22` (contract decl); `:69-107` (`exchangeIn`); `:131-196` (`exchangeOut`); `:218-226` (`_unbookedSurplus`); `:228-245` (`_receiveExactIn`); `:262-276` (`_approvePermit2ToRouter`).
- Recommended add: import `ReentrancyLockModifiers` from `@crane/contracts/access/reentrancy/...` (same import family used by `ERC4626StandardExchangeOutTarget.sol:8`).
- Test touch set:
  - `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` (file already exists; PRD names it directly).
  - Optional new fixture: a callback-capable ERC-20 used as a pool token (per PRD allowance: "A callback-capable token fixture is allowed. Ordinary fixed-behavior tokens remain a negative control.").

### Recommended approach (A) — operation-wide lock + precise approvals
1. Add `nonReentrant` to both `exchangeIn` and `exchangeOut` via the Crane `ReentrancyLockModifiers` mixin. The sibling D16 routes already use it; reuse, do not introduce a second lock primitive.
2. Replace the "infinite approve" body in `_approvePermit2ToRouter` (`:262-276`) with a per-operation exact-amount approval:
   - `forceApprove(router, spendable)`; `forceApprove(permit2, spendable)`; Permit2 packed `approve(token, router, uint160(spendable), uint48(deadline + buffer))`.
   - Spendable must equal `quotedUsed` (exact-out pulled leg), `actualAmountIn` (exact-in pulled leg), `credit` (pretransfer exact-out credit), or `actualBptIn` (BPT-in path).
   - Reset path (`amount_ == 0`) zero-outs router, permit2 ERC-20 allowance, and Permit2 packed allowance, as today. The stale `(M3)` comment is updated as part of this change.
3. Do **not** wrap the router call in `try/catch`. PRD is explicit; revert must roll back allowances transactionally.
4. No sender attribution for D12 resting credit; do not add `requirePretransferCaller` to callers that don't already need it (these are not public pretransfer entries).

### Allowed alternative (B) — operation-wide lock only, keep `type(uint256).max` approval
- If the implementer elects to leave the infinite approve as today and only add `nonReentrant`, the M3 allowance-zeroed-after-success test will continue to pass (the existing `_assertNoMaxAllowances` at lines 103-118 of `Adversarial_BalancerV3SinglePoolSE.t.sol` already asserts router/Permit2 allowances are zero after a successful op), but per-call allowance exposure during the window widens. The PRD explicitly wants (A); (B) is listed only because tests must still pass.

### Non-goals (PRD-fixed)
- No public pretransfer on D32 surfaces.
- No downgrade of "downstream router lock as substitute".
- No claim of demonstrated booked-inventory extraction.
- No sender attribution.

### Dependencies
- RC-04 comment edits are co-located (stale `(M3)` comment on line 262). Bundle the comment fix with the approval body change to avoid double-handle.
- Tests cannot ship until `forge build` regenerates `out/` for the touched source; FactoryService reads from `out/` (CLAUDE.md §10).

### Red → green acceptance
- **Red (current source).** A callback-capable ERC-20 used as a pool token that reenters during `_approvePermit2ToRouter` or `router.addLiquidityUnbalanced` calls `exchangeIn` again: the nested call should succeed in current source (no lock), leaving `_tokenReserve[tokenIn]` stale at the prior booking while the outer transaction completes its own sync. The red proof is a delta between `balanceOf(this)` and `_tokenReserve[tokenIn]` while the inner call still observes the post-funding state.
- **Green (after fix).** The same callback attempts a second `exchangeIn` and either reverts on the lock modifier or, if the outer transaction reverts, leaves `balanceOf` and `_tokenReserve[tokenIn]` unchanged (transaction rollback). Successful non-reentering routes:
  - recipient receives `amountOut` (or `bptAmountOut`),
  - `_tokenReserve[tokenIn] == tokenIn.balanceOf(this)` post-route (post-settlement sync),
  - `tokenIn.allowance(adapter, router) == 0`,
  - `tokenIn.allowance(adapter, permit2) == 0`,
  - Permit2 packed `allowance(adapter, tokenIn, router).amount == 0`,
  - exact-output refund bounded by `min(credit - used, unused U)` (already covered by existing `_refundUnused` at `:248-260`).
- **Negative control.** A non-callback ERC-20 must still complete the same exact-in / exact-out routes with the quoted deltas and zero allowances after.
- Existing `_bookDaiResidual` (lines 91-101) and `_assertNoMaxAllowances` (lines 103-118) in `Adversarial_BalancerV3SinglePoolSE.t.sol` continue to be the assertion backbone; new cases add the callback fixture.

### Historical consumer protection
- `BalancerV3SinglePoolStandardExchange` is a fresh adapter, not a base. The DFPkg family that consumes it (and `ReceiptBackedERC4626_SharedFacet` style shared helpers) does not call `_unbookedSurplus` of this contract — the helper is private to this file. Other D16 routes already use `ReentrancyLockModifiers` (`ERC4626StandardExchangeOutTarget.sol:8`); the new mixin does not shift other consumers.

### Evidence gaps
- A pool token that actually callbacks in production has not been demonstrated (the PRD records this). Red proof uses a callback-capable fixture per PRD allowance; it is a fixture, not a vault/hook mock.
- Live token with a malicious callback is out of scope (no live inventory rule).

---

## RC-02 — ERC-4626 local-first payout: cap to the accounted due amount

### Touch set
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:80-92` (`_payUnderlyingLocalFirst`).
- Callers (already referenced by PRD; do not edit body, only test): `ERC4626StandardExchangeOutTarget.sol:108-115` (unwrap exact-out) and `ERC4626StandardExchangeInTarget.sol:144-151` (unwrap exact-in).
- Composing check (test only, no contract change): `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:559-564`.
- Test touch set: `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol` (file already exists).

### Recommended approach (A) — exact-asset withdrawal capped to `due`
- Replace the body at `:80-92` so it:
  1. Caps `fromLocal = min(due, local)`.
  2. Computes `shortfall = due - fromLocal`.
  3. If `shortfall > 0`, calls `vault.withdraw(shortfall, recipient, address(this))` (not `redeem(previewWithdraw(shortfall), ...)`). EIP-4626 `withdraw(assets, ...)` is the exact-asset path; it charges whatever share count the vault computes internally to deliver `shortfall`.
  4. After the vault call, asserts the recipient's balance delta is exactly `due`; any rounding remainder stays on `address(this)` as booked underlying. Use a follow-up `_syncAllExpectedHoldReserves()` (caller already does this; helper does not need to).
  5. `fromLocal > 0` transfers `fromLocal` to recipient.
  6. Returns the recipient delta (`due`).
- The PRD explicitly allows this: "the route uses an exact-asset withdrawal whose share charge matches the preview" (current acceptance sentence). Mixed local-cash + protocol-vault shortfall is still expected, but the vault call is exact-asset.

### Allowed alternative (B) — cap-redeem and book the difference
- Stay on `redeem(previewWithdraw(shortfall), recipient, address(this))` but additionally cap at the previewed share charge and re-deposit any over-delivery to book: `if (got > shortfall) { vault.deposit(got - shortfall, address(this)); got = shortfall; }`. This preserves the `_payUnderlyingLocalFirst` share semantics and books the rounding remainder on the SE rather than paying it out.
- PRD allows this: "Any protocol-vault rounding remainder stays booked on the SE…".

### Non-goals (PRD-fixed)
- No feeTo residual.
- No exact-input refund reintroduction.
- No new defect against D12 resting face.
- No unbounded-loss claim from rounding.

### Dependencies
- Caller sites (`ERC4626StandardExchangeOutTarget.sol:108-115` and `ERC4626StandardExchangeInTarget.sol:144-151`) are unchanged. They already call `_payUnderlyingLocalFirst(vault, amountOut, recipient)` and rely on the helper to enforce the `due` cap.
- Test must not weaken expected amounts; red/green must use the same assertion.

### Red → green acceptance
- **Setup.** Deploy `ERC4626StandardExchange` with a `CappedPausableERC4626` whose rate is non-unit (e.g. `convertToAssets(1e18) == 1.01e18`) so `previewWithdraw(due)` rounds up.
- **Red (current).** `_payUnderlyingLocalFirst(vault, due, recipient)` returns at least `shortfall`, and recipient balance increases by `got` (>= `shortfall`). The current `_payUnderlyingLocalFirst` makes the recipient receive more than `due`.
- **Green (after fix).** Recipient balance delta == `due`. The over-delivery (if any) is either left as booked underlying on the SE or burned by the vault's `withdraw` exact-asset math. `_booked()` is unchanged from expected (sweep + caller-side booked residual).
- **Mixed case.** `fromLocal = 30, shortfall = 70` (or any `fromLocal < due` mix): recipient receives `due = 100`; SE `balanceOf(underlying)` post-route equals pre-route + `fromLocal` + remaining (because vault delivered exactly `shortfall`).
- **Orbital composing check.** A successful capped unwrap through `_unwrapExactTokenOut` (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-565`) leaves no operation-created face above the opening balance on a non-identity buffered leg. Pre-existing D12 resting face is independent and not consumed by this test.

### Historical consumer protection
- `_payUnderlyingLocalFirst` is only called from two sites (`ERC4626StandardExchangeOutTarget.sol:113` and `ERC4626StandardExchangeInTarget.sol:149`). Both expect recipient delta == `amountOut` and route end-sync. No other consumer.

### Evidence gaps
- "A non-unit receipt rate and a mixed local-cash plus protocol-vault shortfall are both asserted" is a test requirement, not a deployed property. The fixture `CappedPausableERC4626` already supports non-unit rates; tests must construct the non-unit rate explicitly.

---

## RC-03 — Stata SE: include booked aToken in SE backing

### Touch set
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:52-58` (`_stataBacking`).
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:183-198` (`_totalReceiptBacking`, `_bookedATokenEquiv`).
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeDFPkg.sol:245-258` (expected-hold set; only relevant to confirm aToken is in the set when `aToken()` returns non-zero).
- `contracts/vaults/basic/BasicVaultCommon.sol:43-50` (`_syncAllExpectedHoldReserves`; only relevant to confirm aToken end-of-route sync).
- Test touch set: `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol` and `test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_APEX_R14.t.sol`.

### Recommended approach (A) — align `_stataBacking` with the shared helper
- Rewrite `_stataBacking` (`:52-58`) so it matches the `ReceiptBackedERC4626Target._totalReceiptBacking` (`:183-189`) accounting for the Stata marker:
  1. `held = IERC20(stataToken).balanceOf(this)`.
  2. `bookedUnderlying = _bookedReserve(IERC20(stata.asset()))`.
  3. If `_isStata()` (use the shared `ERC165Repo._supportsInterface(type(IAaveV3StataStandardVault).interfaceId)`), `bookedUnderlying += _bookedATokenEquiv(address(stata), stata.asset())` (lift the helper into a shared lib or replicate; PRD allows "the same backing function as the shared adapter").
  4. `return ReceiptBackedERC4626AccountingLib.receiptUnits(stata, held, bookedUnderlying)`.
- This requires `_isStata` and `_bookedATokenEquiv` to be reachable from `AaveV3StataStandardExchangeCommon`. Two concrete options:
  - (A1) Inline-replicate the helper logic in `AaveV3StataStandardExchangeCommon`. `_isStata` would use a static-call to the vault's ERC-165 or a marker that the DFPkg sets.
  - (A2) Move `_isStata` / `_bookedATokenEquiv` to a small library (e.g. `contracts/vaults/standard/erc4626/StataBackingLib.sol`) shared by both contracts. **Preferred** because it eliminates the two-source-of-truth that produced RC-03.

### Allowed alternative (B) — local addition only
- Keep `ReceiptBackedERC4626Target._totalReceiptBacking` and add `+ stata.convertToShares(_bookedATokenEquiv(...))` only inside `_stataBacking`. Test must still show the same share entitlement across the adapter and the SE routes when aToken is booked. This is allowed but re-introduces duplication.

### Non-goals (PRD-fixed)
- Do not change Aave LM reward forwarding (`AaveV3StataStandardExchangeCommon.sol:182-198`); that stream is not this defect.
- Do not add a second share ledger.
- Do not treat an unsolicited aToken transfer as attributable to a depositor.

### Dependencies
- `_bookedATokenEquiv` currently iterates `_vaultTokens` and skips `receipt` and `underlying` (`:191-198`). The Stata expected-hold set already includes the aToken (DFPkg lines 253-258). After the rewrite, the same iteration is used by both surfaces; no new aToken read.
- `MultiAssetBasicVaultRepo._vaultTokens()` must include the aToken (already true when `aToken()` returns one).

### Red → green acceptance
- **Setup.** Deploy one production Stata SE proxy with the real `_deployStataProxy` path used by `TestBase_AaveV3StataStandardExchange`. Seed a nonzero booked aToken balance via the DFPkg init (e.g. by donating aToken, then triggering a partial bookkeeping event so `_reserveOfToken(aToken)` > 0). The fixture needs to be deterministic without manipulating vault storage directly.
- **Red (current).** `IERC4626Metadata(stataAdapter).previewDeposit(x)` and `_stataBacking()` disagree; later depositor priced on the smaller basis receives more shares than the full-backing view.
- **Green (after fix).** `convertToShares` and `_stataBacking()` produce identical underlying-equivalent values. A subsequent `deposit` priced on either function receives the same share count as a same-size deposit priced on the other, both with the larger (correct) basis.
- **Generic ERC-4626 mode.** Generic mode (no Stata marker) still has zero aToken term (the `_isStata()` branch is false).
- Existing `ERC4626StandardExchange_APEX_R14.t.sol` tests must remain green; they do not book aToken and rely on the same `bookedUnderlying == 0` branch.

### Historical consumer protection
- `_stataBacking` is internal to `AaveV3StataStandardExchangeCommon`. Callers are SE routes (`exchangeIn`, `exchangeOut`, `previewExchangeIn`, `previewExchangeOut`) on the Stata vault. No external contract reads it. The shared `ReceiptBackedERC4626Target` already implements the corrected math; aligning the SE does not change other vault proxies.

### Evidence gaps
- Reachability of a nonzero booked aToken in a deployed proxy is inferred (per PRD); tests must construct it via the normal flow (donation → end-of-route sync).

---

## RC-04 — Security-critical comments match executable law

### Touch set (text edits only)
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol:17-20` (header NatSpec dust/feeTo language).
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:201-211` (`_securePull` NatSpec: pull overshoot refund claim) and `:277-281` (`_burnSeShares` NatSpec: leftover free shares refund to owner).
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:126` (overshoot-refund comment).
- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32-38` (pull-max, V3/V4 buffer, dual exits pull max shares).
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:262` (stale `(M3)` infinite-approve comment).

### Recommended approach — comment-only edits
- Bring each cited comment into alignment with the executable body and PRD acceptance:
  - OutTarget header: remove the "residual ≤ MAX_DUST_WEI → feeTo" line. Replace with "no exact-input refund; dust retained as booked reserve (D6/D15)".
  - `_securePull` NatSpec: drop "Pull overshoot is refunded immediately (D38)". The body returns the pull delta only; overshoot is not refunded (FoT-safe).
  - `_burnSeShares` NatSpec: replace "Refund leftover free shares on diamond to `owner`" with "Do not sweep leftover self-shares; honest extras stay on the vault (absorb)".
  - InTarget:126 comment: same `_securePull` NatSpec correction.
  - FullSpread README: align `Delivery and reserves` paragraph with the current pull semantics ("`exchangeIn`, including dual joins, requires `actualIn == amountIn`"; refunds capped by `min(max - used, actualIn - used)`; pull semantics remain route-specific). Drop the lines "excess exact-in deliveries revert, V3 pulls a quote buffer, V4 pulls max, and dual exits pull max shares" if they describe stale refund behavior; replace with the D17/D28 language. Note this is a documentation edit, not a code change.
  - BalancerV3 stale comment: rewrite to match the new RC-01 approval body ("Approve router and Permit2 to the per-operation exact spendable; reset to zero after settlement").

### Non-goals (PRD-fixed)
- No executable refund/fee/pull change.
- No reintroduction of `_absorbDustToFeeTo`.
- No edits to preserved historical Uniswap source under `contracts/protocols/dexes/uniswap/{v3,v4}/`.

### Dependencies
- RC-01 bundles the BalancerV3 stale comment fix with the approval body change.

### Red → green acceptance
- This is a text-only change. There is no red. Acceptance is:
  - Each cited line no longer describes removed behavior.
  - Existing `ERC4626StandardExchange_APEX_R14.t.sol` and one FullSpread exact-out suite (e.g. `StandardExchangeBufferPoolTarget_*.t.sol` or `Adversarial_BalancerV3SinglePoolSE.t.sol`) remain green.
  - A reviewer can grep the cited file/line ranges and confirm no statement of removed behavior remains.

### Historical consumer protection
- Comments are not load-bearing; no contract consumes them.

### Evidence gaps
- None. This is a documentation integrity change.

---

## RC-05 — Unused single-CP HookTarget `exchangeOut` must not retain a second public money implementation

### Touch set
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754` (`exchangeOut`).
- The contract is declared `abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookTarget is IHooks` (line 49). Confirmed by grep: no `is UniswapV4SingleStandardExchangeBufferConstantProductHookTarget` inheritor in `contracts/`. The function is unreachable from production code unless an inheritor is introduced.
- Test touch set: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol` (PRD-named).

### Recommended approach (A) — delete the function entirely
- Remove `:736-754` and any selector it occupies. The function is not part of any IHook selector (the contract is not `IHook`; line 44 of the same file). Deletion does not change the diamond cut; the surface suite still passes.

### Allowed alternative (B) — replace the body with a call to the installed guarded helper
- Body becomes a thin wrapper that delegates to the same `_pullPretransfer` / `_refundCreditMinusUsed` helper used by the installed SE target (`ERC4626StandardExchangeCommon.sol:251-255`, `_securePull` at `:213-235`, `LocalCreditLib` at `contracts/utils/LocalCreditLib.sol:24-28`). Adds `LocalCreditLib.requirePretransferCaller(msg.sender)` and uses `_unbookedSurplus`-based credit.
- PRD explicitly allows a thin entry calling the installed guarded helper.

### Non-goals (PRD-fixed)
- No diamond-cut change to the installed facet.
- No change to `SeTarget` exchange behavior (except sharing the helper if that is the chosen fix).

### Dependencies
- A grep over `contracts/` for any inheritor (already done: zero matches) must be re-run at implementation time as a safeguard.

### Red → green acceptance
- **Red.** If a thin inheritor were ever introduced, it would call the unguarded refund body. The current source exposes two implementations. A source-level search before the fix returns this function with `maxAmountIn - amountIn` refund semantics.
- **Green.** After (A), the function is gone; source search for `exchangeOut` on this contract finds no second unguarded body. After (B), the body uses `LocalCreditLib` + `requirePretransferCaller` + `_unbookedSurplus` (or shares the installed helper); the unguarded refund is no longer present.
- The installed cut's selectors do not change. The surface suite passes.

### Historical consumer protection
- The function is unreachable from production; no consumer is affected.

### Evidence gaps
- Grep verification must be repeated at implementation time; current evidence is "no matches" at this read.

---

## RC-06 — Orbital capped unwrap: honest or removed share return

### Touch set
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-565` (`_unwrapExactTokenOut`).
- Callers (verified): `:586` (`_swapExactInExecute`), `:604` (`_swapExactOutExecute`), `:1899` (a second `_swapExactInExecute`-style path in the same file). All three call without capturing the return value (the call sites use `;` not `=`).

### Recommended approach (A) — make the return truthful (delta-based)
- Modify `:550-565` so:
  1. Capture the SE return: `uint256 actualIn = IStandardExchangeOut(se).exchangeOut(...);`.
  2. Use `delta = actualIn` (or compute `selfBalBefore = IERC20(se).balanceOf(this); ...; actualBurn = selfBalBefore - IERC20(se).balanceOf(this);` if the SE cannot be trusted to report). The cleanest read is the SE return: the SE already returns `amountIn` consumed.
  3. Assign `seIn = actualIn` instead of `seIn = maxIn`.
  4. Keep the `forceApprove(se, maxIn)` / `forceApprove(se, 0)` cycle and the `if (IERC20(token).balanceOf(address(this)) - beforeOut < amountOut) revert InsufficientTokenOut();` short-delivery check.
  5. Update all three call sites if any start capturing the return (none currently do, but consistency requires a decision).

### Allowed alternative (B) — remove the return value entirely
- Change signature to `internal` returning nothing (`function _unwrapExactTokenOut(address token, uint256 amountOut) internal`). Drop `:565`. Update the three call sites (one-line edits).

### Non-goals (PRD-fixed)
- Do not change the exact-output SE call into a surplus-creating unwrap.
- Do not pay the unused share cap to the caller.
- MiniMax dissent preserved as informational (the assignment is unused and therefore not a functional defect); the PRD's "make or remove" requirement applies regardless.

### Dependencies
- (A) requires the underlying `IStandardExchangeOut.exchangeOut` to remain trustworthy on the `seIn` return value (it is, per the rest of the PRD's law). (B) is the lower-touch path.

### Red → green acceptance
- **Red (current).** The function sets `seIn = maxIn`. The return value is unused at all three call sites. A unit test that captures the return (e.g. by adding `uint256 observed = ...;` for one caller) sees `observed == maxIn`, which is the approval cap, not the share spend.
- **Green (A).** A production-hook test asserts `observed == IERC20(se).balanceOf(this) (before) − IERC20(se).balanceOf(this) (after)` (share balance delta). The existing approve-to-cap and approve-back-to-zero sequence remains. A short SE delivery still reverts `InsufficientTokenOut()`.
- **Green (B).** The same orbital unwrap suite asserts the recipient token balance still increases by `amountOut`, the SE allowance is cleared, and the test compiles without trying to capture a return value that no longer exists.

### Historical consumer protection
- All three current call sites use `_unwrapExactTokenOut(...)` as a statement. None capture the return. Changing the return (B) is safe. Changing the value (A) is also safe because no caller consumes it; later code that wants to capture it gets the truthful value.

### Evidence gaps
- None at the unit level. Live effectiveness of the fix depends on the SE remaining well-behaved, which is closed by RC-02 and the rest of the PRD.

---

## RC-07 — Shared vault availability math: zero-credit on deficit, not panic

### Touch set
- `contracts/vaults/basic/BasicVaultCommon.sol:33-36` (`_unbookedSurplus`, the unchecked `balance - reserveOfToken` subtraction).
- `:77-103` (`_secureTokenTransfer` body — the `U = B0 - R` checked subtraction inside the `pretransferred` branch).
- `:120-135` (`_refundExcess`, which calls `_unbookedSurplus`).
- Other in-scope D16 surfaces that consume `_unbookedSurplus` or `_secureTokenTransfer` directly: enumerable only as test work. Concretely, every override that calls `_secureTokenTransfer` from a public entry must be enumerated before any base-helper edit. This list is part of the historical-consumer artifact (see below).
- `contracts/utils/LocalCreditLib.sol:14-21` already returns zero on deficit (`available` returns `balance > booked ? balance - booked : 0`). The fix is to **use it** in `BasicVaultCommon`.
- Test touch set: existing Uni V2, Camelot, and Aerodrome secure-pull suites (PRD-named); direct helper test only if no production route can produce `balance < book`.

### Recommended approach (A) — use `LocalCreditLib.available` for the base helper, keep checked math at the no-deficit envelope
1. Replace `_unbookedSurplus` body (`:33-36`) with `return LocalCreditLib.available(token.balanceOf(address(this)), MultiAssetBasicVaultRepo._reserveOfToken(address(token)));`. This returns zero on `balance < booked` and matches the sibling helper that already exists for this exact purpose.
2. Inside `_secureTokenTransfer` (`:77-103`), replace the inline `U = B0 - R` (line `:98`) with `uint256 U = LocalCreditLib.available(B0, R);`. Keep the `TransferDeltaInsufficient(claimed, U)` revert text. The `B1 - B0` for the non-pretransfer branch stays as the pull delta; do not change that.
3. `_refundExcess` (`:120-135`) calls `_unbookedSurplus`; once (1) is applied, `_refundExcess` already returns zero on deficit and rejects an arithmetic underflow. No additional change needed.
4. D16 public pretransfer entries that override `_secureTokenTransfer` are unchanged; the helper is now deficit-safe.

### Allowed alternative (B) — keep `_unbookedSurplus` checked, route D16 through LocalCreditLib only
- Add an explicit `LocalCreditLib.available(...)` call only at the D16 override pull site (where `_secureTokenTransfer` is invoked). This preserves the existing base helper and minimizes blast radius. PRD-listed tests must still show zero credit (not panic) on deficit. Less safe: leaves the base helper capable of panicking for historical consumers.

### Non-goals (PRD-fixed)
- No mechanical replacement of every historical caller.
- No claim of demonstrated booked-inventory payout.
- No reopen of preserved Uni V3/V4 delivery accounting.

### Historical consumer inventory (must be enumerated at implementation time; PRD lists)
- Every override of `_secureTokenTransfer` and every direct caller of `_unbookedSurplus` and `_refundExcess` outside the D16 override set must be enumerated. The PRD explicitly forbids silently changing them. Implementation must produce a Markdown table in the test/PR evidence file under `docs/audits/apex-2026-09-17-evidence/` listing consumer → caller → semantic preserved.

### Dependencies
- `LocalCreditLib` is already used by `AaveV3StataStandardExchangeCommon._secureTokenTransfer` (`:200-228`). The Crane `ReentrancyLockModifiers` is unrelated.
- The full-set end-of-route sync (`_syncAllExpectedHoldReserves` at `BasicVaultCommon.sol:43-50`) is unchanged.

### Red → green acceptance
- **Red (current).** A direct helper test (if no production route can reach `balance < booked`) or an existing D16 route test must show the arithmetic-underflow revert. For the Uni V2 secure-pull suite (`UniswapV2StandardExchange_SecRemediation.t.sol`), the existing routes do not produce the deficit; a direct helper test is the PRD-acceptable substitute.
- **Green (after fix).** The same call returns zero credit. When the caller requests `> 0`, the route reverts `TransferDeltaInsufficient(claimed, 0)` (or the family equivalent), not an arithmetic underflow.
- **D16 caller matrix.** PRD requires naming the D16 overrides that already guard the base pull. The implementer must enumerate them in the test evidence file. Concretely: every `nonReentrant` D16 public entry (e.g. the constant-product single CP, FullSpread V3/V4, Aerodrome, Camelot) must show a no-bytecode caller still reverts `EOAPretransferNotAllowed()`.

### Historical consumer protection
- Approach (A) is purely additive in safety: a checked underflow becomes a zero-credit result. No caller's accounting changes when `balance >= booked` (the same branch). When `balance < booked`, the prior behavior was an unrecoverable revert; the new behavior is "no new credit authorized, plus a named insufficient-credit error if the caller asks for more than zero."
- Approach (B) is even narrower; no consumer outside the D16 override set is touched.

### Evidence gaps
- Live D16 payout of booked inventory was not shown (PRD records this). Tests must demonstrate the zero-credit and named-error behavior without staging a live exploit.

---

## RC-08 — Uniswap V2 pass-through zap-out backing check: named error

### Touch set
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:578-579` (`if (indexSource.pool.balanceOf(address(this)) < vault.vaultLpReserve) { revert(); }`).
- The same file contains two other empty `revert();` statements at `:859` and `:980` (already searched). They are not the RC-08 site per PRD; do not touch them in this RC.
- Test touch set: `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol` (PRD-named; file exists).

### Recommended approach (A) — named error carrying both compared values
1. Define a new error in the contract scope (or a shared interface):
   ```solidity
   error InsufficientLPBacking(uint256 poolBalance, uint256 vaultLpReserve);
   ```
   PRD wants both compared values carried.
2. Replace the empty `revert();` at `:579` with `revert InsufficientLPBacking(indexSource.pool.balanceOf(address(this)), vault.vaultLpReserve);`.
3. Do not weaken the comparison (`<`), do not change refund amounts on this route.

### Allowed alternative (B) — `require` with a message string
- If the project style elsewhere prefers `require(cond, "message")`, that's acceptable. PRD requires the error to be **named** and to carry both compared values; a string message does not satisfy "named error". Stick with (A).

### Non-goals (PRD-fixed)
- Do not weaken the comparison.
- Do not change refund amounts.
- Do not hold the named-error edit until a later end-to-end trigger is authorized (PRD: "do not hold the named-error edit until a later end-to-end trigger is authorized").

### Dependencies
- Test must decide between two evidence paths the PRD allows:
  - **Path 1 — supported route can produce the deficit.** A test on the production proxy must demonstrate failure before the fix (empty `revert()`) and the named error after the fix, with unchanged LP reserve and a funded success control alongside.
  - **Path 2 — supported route cannot produce the deficit without SUT mocks or storage writes.** Document the attempt preconditions and assert the production check itself reverts the named error. Do not invent a completion gate beyond that.

### Red → green acceptance
- **Red (current).** If Path 1 is feasible, the route reverts with empty revert (no data). If Path 1 is infeasible, the named error is asserted via direct call to the production check (no mocks of the vault or its storage).
- **Green (after fix).** Same call reverts with the named error carrying `poolBalance` and `vaultLpReserve`. Successful zap-out routes still pass; booked LP is not spent; transaction rolls back atomically.

### Historical consumer protection
- `UniswapV2StandardExchangeOutTarget` is consumed by the registered FullSpread vault packages (`UniswapV2StandardStrategyVaultPkg`). The new error is additive; the interface does not change. Off-chain consumers that decode empty reverts will need a decoder update, but no production caller depends on decoding this revert.

### Evidence gaps
- Whether a supported production route can produce `poolTokenBalance < vaultLpReserve` without mocks is the open empirical question. The PRD allows either evidence path; the implementer chooses by attempting and recording.

---

## Cross-cutting items (no separate RC; do not reopen as new findings)

- RC-04 (M3) BalancerV3 stale comment is bundled with RC-01.
- RC-06 (orbital seIn) may be addressed by deleting the return (Approach B) with minimal blast radius.
- RC-08 evidence path is an implementer choice.
- RC-07 historical-consumer inventory is an evidence artifact required by the PRD; the implementer must produce it even if Approach (B) is chosen.

## Implementation order (for the executor; not for me to perform)

1. RC-01 + RC-04 (BalancerV3 stale comment): add lock + bounded approval; rerun `Adversarial_BalancerV3SinglePoolSE.t.sol`; expand it with the callback fixture.
2. RC-02: replace `_payUnderlyingLocalFirst` body with `vault.withdraw(shortfall, ...)`; rerun `ERC4626StandardExchange_APEX_R14.t.sol`; add non-unit rate + mixed local/receipt case.
3. RC-03: lift `_isStata` / `_bookedATokenEquiv` into a shared library or replicate inside `_stataBacking`; rerun `ReceiptBackedERC4626_SharedFacet.t.sol` and `AaveV3StataStandardExchange_APEX_R14.t.sol`; add the nonzero booked-aToken assertion.
4. RC-05: delete `_unwrapExactTokenOut` return value (`_unwrapExactTokenOut` … `seIn = maxIn`) or function entirely per RC-05; rerun the surface suite; assert no unguarded `exchangeOut` body remains.
5. RC-06: delete or truthify the orbital unwrap return per RC-06; rerun the orbital surface suite.
6. RC-07: switch `_unbookedSurplus` and the `_secureTokenTransfer` pretransfer branch to `LocalCreditLib.available`; rerun Uni V2 / Camelot / Aerodrome secure-pull suites; add direct helper test only if needed.
7. RC-08: introduce `InsufficientLPBacking` error and replace the empty `revert()`; rerun `UniswapV2StandardExchange_SecRemediation.t.sol` with documented evidence path.

## Final acceptance gate (the auditor hand-off check)

- All eight required findings have a green production-route test except where the PRD expressly allows comment inspection, source absence, or a focused check on a supported branch.
- All tests run under the hermetic profile (`forge test`); no fork RPC; no `via_ir`; no SUT mocks; no storage fabrication; no live inventory.
- `forge build` succeeds before `forge test` (CLAUDE.md §10); `out/` regenerates from the new sources.
- The FullSpread package tree (`contracts/vaults/standard/exchange/protocols/uniswap/`) and the preserved historical trees (`contracts/protocols/dexes/uniswap/{v3,v4}/`) are not the bytecode selected for any new deploy.
- The `round-2026-09-26-minimax-original.md` file is preserved unchanged.
- The moderator owns final consolidation at `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md`.