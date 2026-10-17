# MiniMax M3 — REQ-SEP-04 amount-out refund review, replacement-session original

- **Label:** replacement session. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. No peer notes were read. No code edits. No `REMEDIATION_PRD.md`. No Forge. No exploit procedures.
- **Scope:** every in-scope production vault (constant-product DEX, staking, lending, ERC4626, Uniswap V3/V4 FullSpread, Wings, DETF, rebasing, token migration) and every documentation file still stating the withdrawn rule. Out of scope: `contracts/protocols/dexes/uniswap/v4` (being deleted) and Slipstream (deprecated, do not restore).
- **Owner ruling (later text controls):** "Vaults should only process the operation using only the amount needed to meet the requested amount out and refund the rest to the caller. The amount processed should only come from the unbooked amount." Both old Uniswap README sentences are withdrawn: do not credit a declared exact-in amount and keep the surplus, and do not revert merely because the declared amount differs from the surplus. Booked inventory is not spent. A shortfall is not filled from booked inventory.

---

## 1. The exact-out path already conforms on all in-scope families

The exact-out path uses `_refundExactOutCredit(token, credit, used, pretransferred)`. This helper is defined in seven files (one per common family) and follows the same shape everywhere:

- `UniswapV2StandardExchangeCommon.sol:501-507` — `if (used > credit) revert TransferDeltaInsufficient; if (credit > used) { _refundExcess(...) }`.
- `CamelotV2StandardExchangeCommon.sol:240-246` — same shape.
- `AerodromeStandardExchangeCommon.sol:1025-1031` — same shape.
- `SlipstreamStandardExchangeCommon.sol:482-...` — same shape (deprecated, recorded).
- `RocketPoolRETHStandardExchangeCommon.sol:331-342` — same shape (inline, not via `_refundExcess`).
- `LidoWstETHStandardExchangeCommon.sol:462-471` — same shape (inline).
- `EtherFiWeETHStandardExchangeCommon.sol:459-468` — same shape (inline).

The Rocket, Lido, and EtherFi copies cap the refund at `LocalCreditLib.available(token.balanceOf(address(this)), _bookedReserve(token))` to ensure the refund does not pay booked inventory. The V2, Camelot, Aerodrome, and Slipstream copies route through `_refundExcess` (which uses the same `_unbookedSurplus` saturating helper on the D16 active families). Every one of the seven reads as: take only the needed amount from the pretransfer credit and refund the rest, capped at the current unbooked surplus. None spend booked inventory. None revert when the caller's push is greater than the operation's used amount.

The exact-out path is conformant on every in-scope family. This is the positive reference the fix should follow.

---

## 2. The exact-in pretransfer path keeps the caller's pretransfer excess on every in-scope family — defect class

The exact-in pretransfer path uses `_secureTokenTransfer` (constant-product DEX, ERC4626, V3, V4 FullSpread, Aave, Balancer, Aerodrome, DETF) or `_securePull` (staking). I read every active D16 and D-family override of these helpers. They follow the same shape:

- `BasicVaultCommon.sol:80-106` — pretransfer path: `if (amountTokenToDeposit > avail) revert TransferDeltaInsufficient; return amountTokenToDeposit;`. Surplus `avail - amountTokenToDeposit` is **not** refunded. The contract's own NatSpec (`:17`, `:70-71`) documents this: "Unclaimed push surplus is absorbed into `R` at end-of-op full-set sync (not refunded)."
- `UniswapV2StandardExchangeCommon.sol:450-478`, `CamelotV2StandardExchangeCommon.sol:189-217`, `AerodromeStandardExchangeCommon.sol:974-1000`, `AaveV3StataStandardExchangeCommon.sol:258-283` — same shape, no refund.
- `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:864-885`, `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:905-926`, `UniswapV4FullSpreadPonsFamilyHookCommon.sol` (same pattern) — same shape, no refund.
- `ERC4626StandardExchangeCommon.sol:251-272`, `MorphoBlueStandardExchangeCommon.sol:182-204` — same shape, no refund.
- `RocketPoolRETHStandardExchangeCommon.sol:352-371`, `LidoWstETHStandardExchangeCommon.sol:_securePull`, `EtherFiWeETHStandardExchangeCommon.sol:_securePull` — same shape, no refund.
- `RebasingDETFTokenTarget.sol:468-...`, `ComposedStableCommonDetfCommon.sol:769-...` — same shape, no refund.

The V4 hookless, V4 Pons, V3, ERC4626, Morpho, Balancer, Aave, Camelot, V2, Aerodrome, Rocket, Lido, EtherFi, RebasingDETF, ComposedStableDETF, Wings, and TokenStakingMigrationAdapter all keep the caller's pretransfer excess in the vault. The exact-in path does not match the owner ruling.

### 2.1 The surplus that should be refunded

The pretransfer credit is `avail = unbooked_surplus_before` = (caller's pretransfer push) + (any pre-existing unbooked). The vault uses `amountIn` (the declared amount). The "rest" the owner ruling requires refunded is `avail - amountIn` — the part of the unbooked surplus that the operation did not consume. The current code keeps this in the vault's unbooked balance. At end-of-op sync, `_syncAllExpectedHoldReserves()` re-records this surplus as the new booked reserve, which means the caller's excess push effectively becomes part of the next caller's credit (the "donor-risk" model the README documents).

### 2.2 The owner ruling's mapping for exact-in is one choice point

The owner ruling's central sentence is "Vaults should only process the operation using only the amount needed to meet the requested amount out and refund the rest to the caller." For exact-in there is no "requested amount out"; the caller declares an input and a minimum output. Two readings:

1. **The amount needed is `amountIn` itself** (the declared input). The rest is the caller's pretransfer excess above `amountIn`. The fix refunds that excess to the caller.
2. **The amount needed is whatever the router quote actually consumed** (which for a constant-product deposit is `amountIn`). Same conclusion as #1.

The "surplus" in reading #1 is the caller's pretransfer excess. The owner ruling's "do not credit a declared exact-in amount and keep the surplus" confirms reading #1.

But reading #1 has a subtlety: the vault cannot isolate the caller's pretransfer push from any pre-existing unbooked surplus. The whole `avail` is `caller_push + pre_existing_unbooked`. The fix that refunds `avail - amountIn` to the caller would also refund pre-existing unbooked (the donor-risk model). The fix that refunds only the caller's pretransfer excess requires per-caller tracking, which is a contract-shape change. The owner ruling does not say which.

The implementer has a choice unless the PRD closes it. The choice has two sides:

- "Refund `avail - amountIn` (donor-risk model absorbs pre-existing unbooked)." — simple, no contract-shape change, but caller may receive more than they pushed.
- "Refund only the caller's pre-transfer excess." — requires per-caller tracking or a new interface parameter.

The PRD must pick one or the other; otherwise the implementer has a search/scope choice.

### 2.3 The one owner question that must be answered before the plan can be written

> Should the exact-in pretransfer refund transfer only the caller's pre-transfer push excess (a per-call amount the caller can sign, requiring a new interface parameter), or should it transfer the entire unbooked-surplus-minus-amountIn (which may include pre-existing unbooked and matches the README's donor-risk model)?

The sentence that would close it:

> The exact-in pretransfer refund MUST refund the caller's pre-transfer push excess minus `amountIn`, OR MUST refund the entire `avail - amountIn` (including any pre-existing unbooked) per the existing donor-risk model; the implementer MUST do exactly one, the other is closed.

I will not invent this choice in the plan. Until the PRD closes it, the implementer is left to decide between the two. So the plan cannot be written with "no choice" unless the PRD is updated.

---

## 3. The documentation that still states the withdrawn rule — defect list

The following documentation files still state the old (now-withdrawn) rules. Each must be updated per the owner ruling.

### F1 — `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32`

- **Severity:** Low (documentation).
- **Intended behavior:** withdraw both old sentences.
- **Broken invariant:** the file still says "Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds. A short push reverts `TransferDeltaInsufficient`." The "exact-in never refunds" clause is withdrawn.
- **Impact class:** integrator guidance, stale comment.
- **Fix direction:** rewrite the exact-in pretransfer paragraph to match the new rule: the operation uses `amountIn` from the unbooked surplus; the caller's pretransfer excess above `amountIn` is refunded; a shortfall still reverts `TransferDeltaInsufficient`. Same file at line 38 ("An exact-in call whose declared amount differs from that surplus reverts.") is the other withdrawn sentence and must be deleted. The D15 paragraph in `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md:63,202` documents the same old rule and must be updated identically.

### F2 — `contracts/vaults/basic/BasicVaultCommon.sol:17` and `:70-71`

- **Severity:** Low (NatSpec).
- **Intended behavior:** the NatSpec must match the new rule.
- **Broken invariant:** `:17` says "Unclaimed push surplus is absorbed into `R` at end-of-op full-set sync (not refunded)." `:70-71` says "Unclaimed surplus (`U - claimed`) is **not** refunded here; it is absorbed into `R` when the route ends with `_syncAllExpectedHoldReserves()`." The new rule refunds the unclaimed surplus; the absorption rule is withdrawn.
- **Impact class:** integrator guidance, stale NatSpec on the base.
- **Fix direction:** rewrite these two NatSpec lines to state the new exact-in pretransfer refund rule.

### F3 — `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21`

- **Severity:** Low (PRD).
- **Intended behavior:** withdraw the old exact-in pretransfer sentence.
- **Broken invariant:** "Exact-in pretransfer credits exactly `amountIn` and refunds nothing." The "refunds nothing" clause is withdrawn.
- **Impact class:** PRD guidance still authorizes the old behavior.
- **Fix direction:** update the table cell to match the new rule.

### F4 — `docs/audits/apex-2026-09-17-evidence.md:61`

- **Severity:** Low (audit evidence).
- **Intended behavior:** withdraw the old exact-in pretransfer sentence.
- **Broken invariant:** "Exact-input pretransfer requires unbooked `available >= amountIn`, credits exactly `amountIn`, and refunds nothing. Excess unbooked is not this operation's input." The "refunds nothing" clause is withdrawn.
- **Impact class:** audit evidence still authorizes the old behavior.
- **Fix direction:** update to match the new rule.

### F5 — `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:124`

- **Severity:** Low (PRD).
- **Intended behavior:** withdraw the old exact-in pretransfer sentence.
- **Broken invariant:** "D17 / D28: false-flag exact-out pulls quoted used; exact-in credits exactly `amountIn` when available is sufficient and does not require the whole surplus to equal the request." The "credits exactly `amountIn`" / "does not require the whole surplus to equal the request" clauses are withdrawn.
- **Impact class:** PRD guidance still authorizes the old behavior.
- **Fix direction:** update to match the new rule.

### F6 — `docs/reviews/apex-2026-09-17-remediation-council/grok-original.md:54` and `docs/reviews/apex-2026-09-17-remediation-council/minimax-original.md` and `docs/reviews/apex-2026-09-17-remediation-council/kimi-original.md:51` and `docs/reviews/apex-2026-09-17-second-audit-readiness/grok-original.md:22` and `docs/research/uniswap-v4-open-items-2026-09-27/MINIMAX_ORIGINAL.md:73` and `docs/research/uniswap-v4-single-token-wings-2026-10-03/minimax-original.md:155` and `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md:282` and `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-kimi-original.md:70,92` and `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-minimax-original.md:296` and `docs/plans/apex-2026-09-17-remediation-council/grok-original.md:225` and `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-minimax-cross.md:140,155,162` and `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:165` and `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:538` and `docs/agent/INDEXEDEX_AGENT_LAW.md` and `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` and `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md` and `contracts/protocols/staking/token/TOKEN_STAKING_MIGRATION_ADAPTER.md`

- **Severity:** Low (stale comments / audit evidence / research notes / agent law / PRD / plans).
- **Intended behavior:** all of these documents assert "exact-in credits exactly `amountIn`" and "exact-in never refunds" or equivalent. The owner ruling withdraws both. They must be updated to the new rule.
- **Broken invariant:** the documents still teach / authorize the old behavior.
- **Impact class:** stale documentation in audit/plan/research/agent-law.
- **Fix direction:** sweep every document that states the old rule and replace it with the new rule. The plan must name this sweep explicitly or it leaves the implementer to find them.

### F7 — `docs/reviews/apex-remediation-application-2026-10-14/reviewers/minimax-cross.md:61`

- **Severity:** Low (review note).
- **Intended behavior:** this review note already identifies lines 32 and 38 of the README as the stale-comment defect. It is consistent with the owner ruling.
- **Broken invariant:** the note treats line 38 as a separate RC-04 stale-comment defect that the REQ-C05 PRD did not cover. The owner ruling now says both lines are withdrawn and the new rule applies. The note should be updated to reflect the new owner ruling.
- **Impact class:** review note.
- **Fix direction:** update the note to state that both lines 32 and 38 are withdrawn by the new owner ruling and replaced by the new exact-in pretransfer refund rule.

---

## 4. Production code that keeps the surplus — defect list

The following production `_secureTokenTransfer` and `_securePull` pretransfer branches do not refund the caller's pretransfer excess on the exact-in path. Each must be fixed to refund the rest, subject to the owner question in §2.3.

For each, the intended behavior is: the operation uses `amountIn`; the caller's pretransfer excess above `amountIn` is refunded; a shortfall still reverts; the refund comes from the unbooked surplus, never the booked reserve.

### F8 — `BasicVaultCommon._secureTokenTransfer` (line 80-106, base)

- **Severity:** Low.
- **Intended behavior:** the pretransfer path refunds `avail - amountTokenToDeposit` to `msg.sender` (or implements the per-caller alternative once §2.3 is closed).
- **Broken invariant:** the base returns `amountTokenToDeposit` and absorbs the surplus into `R` at sync. The new rule refunds the surplus.
- **Impact class:** base helper used by every family that does not override the pretransfer path.
- **Fix direction:** after the `if (amountTokenToDeposit > avail) revert ...;` line, transfer `avail - amountTokenToDeposit` to `msg.sender` when `pretransferred == true` and the surplus is positive. The exact-in pull (false flag) path is unchanged. The base change auto-fixes every concrete override that delegates the pretransfer branch, but V2/Camelot/Aerodrome/Aave override the entire function (so each must be updated independently).

### F9 — `UniswapV2StandardExchangeCommon._secureTokenTransfer` (line 450-478)

- **Severity:** Low.
- **Intended behavior:** refund the caller's pretransfer excess on the exact-in path.
- **Broken invariant:** same as F8 base.
- **Impact class:** active D16 V2 family.
- **Fix direction:** add the surplus refund after the `if (amountTokenToDeposit > avail) revert ...;` line in the V2 override, scoped to `pretransferred == true`.

### F10 — `CamelotV2StandardExchangeCommon._secureTokenTransfer` (line 189-217)

- **Severity:** Low.
- **Impact class:** active D16 Camelot family.
- **Fix direction:** same as F9.

### F11 — `AerodromeStandardExchangeCommon._secureTokenTransfer` (line 974-1000)

- **Severity:** Low.
- **Impact class:** active D16 Aerodrome V1 family.
- **Fix direction:** same as F9.

### F12 — `AaveV3StataStandardExchangeCommon._secureTokenTransfer` (line 258-283)

- **Severity:** Low.
- **Impact class:** Aave V3 Stata lending family.
- **Fix direction:** same as F9.

### F13 — `UniswapV3FullSpreadStandardExchangeVaultCommon._secureTokenTransfer` (line 864-885)

- **Severity:** Low.
- **Impact class:** V3 FullSpread.
- **Fix direction:** same as F9.

### F14 — `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon._secureTokenTransfer` (line 905-926)

- **Severity:** Low.
- **Impact class:** V4 FullSpread hookless.
- **Fix direction:** same as F9. Note the `address(tokenIn) == address(this) ? ERC20Repo._balanceOf(address(this)) : tokenIn.balanceOf(address(this))` ternary; the refund must use the same balance source.

### F15 — `UniswapV4FullSpreadPonsFamilyHookCommon._secureTokenTransfer` (same shape as hookless)

- **Severity:** Low.
- **Impact class:** V4 FullSpread Pons.
- **Fix direction:** same as F14.

### F16 — `UniswapV4UpperLowerWingsStandardExchangeVaultInTarget` and its Common (Wings In base)

- **Severity:** Low.
- **Impact class:** Wings family.
- **Fix direction:** apply the same F9 fix to the Wings InTarget / Common. Wings `_secureTokenTransfer` was not in the list above because it inherits the pretransfer pattern from BasicVaultCommon; the base fix (F8) propagates if Wings does not override. Verify by reading the current Wings In source before fixing.

### F17 — `ERC4626StandardExchangeCommon._secureTokenTransfer` (line 251-272)

- **Severity:** Low.
- **Impact class:** ERC4626 wrapper family.
- **Fix direction:** same as F9.

### F18 — `MorphoBlueStandardExchangeCommon._securePull` (line 182-204)

- **Severity:** Low.
- **Impact class:** Morpho Blue lending family.
- **Fix direction:** same as F9, in the `_securePull` pretransfer branch (line 198-203).

### F19 — `RebasingDETFTokenTarget._secureTokenTransfer` (line 468-...)

- **Severity:** Low.
- **Impact class:** RebasingDETF DETF family.
- **Fix direction:** same as F9.

### F20 — `ComposedStableCommonDetfCommon._secureTokenTransfer` (line 769-...)

- **Severity:** Low.
- **Impact class:** ComposedStableDETF DETF family.
- **Fix direction:** same as F9.

### F21 — `BalancerV3SinglePoolStandardExchange.sol` (Balancer V3 SE)

- **Severity:** Low.
- **Impact class:** Balancer V3 SE family.
- **Fix direction:** read the current Balancer V3 SE exact-in pretransfer path; apply the same surplus-refund pattern as F9.

### F22 — `UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol` and the other hook products (Orbital, Weighted, Curve-quad, Balancer-quad, single-CP)

- **Severity:** Low.
- **Impact class:** hook families (dual, orbital, weighted, curve-quad, balancer-quad, single-CP).
- **Fix direction:** read each hook's exact-in pretransfer path; apply the same surplus-refund pattern. Many of these hooks already use the V4 FullSpread common pattern, so the base fix (F14/F15) propagates if the hook doesn't override.

### F23 — `TokenStakingMigrationAdapter.sol` (token-staking migration adapter, line 114-...)

- **Severity:** Low.
- **Impact class:** staking migration adapter.
- **Fix direction:** apply the same F9 fix to the adapter's exact-in pretransfer path.

### F24 — Staking `_securePull` functions (Rocket, Lido, EtherFi)

- **Severity:** Low.
- **Impact class:** staking In pretransfer path.
- **Fix direction:** same as F9, in `_securePull` instead of `_secureTokenTransfer`.

The staking Out pretransfer path (which uses `_refundExactOutCredit` for exact-out) is already conformant per §1. Only the In pretransfer path needs the fix.

### F25 — `UniswapV2StandardExchangeInTarget.sol` and equivalents

- **Severity:** Low.
- **Impact class:** the InTarget sites call `_secureTokenTransfer` for exact-in. The `_secureTokenTransfer` fix at F9-F21 propagates to the InTarget sites. No additional InTarget fix is needed once the helper is fixed.

---

## 5. Families that already conform

The exact-out path on the following families already refunds the caller's pretransfer excess. No fix is needed for exact-out.

- V2 (`UniswapV2StandardExchangeCommon._refundExactOutCredit` line 501-507)
- Camelot (`CamelotV2StandardExchangeCommon._refundExactOutCredit` line 240-246)
- Aerodrome V1 (`AerodromeStandardExchangeCommon._refundExactOutCredit` line 1025-1031)
- Slipstream (`SlipstreamStandardExchangeCommon._refundExactOutCredit` line 482-...; deprecated, recorded, no fix)
- Rocket (`RocketPoolRETHStandardExchangeCommon._refundExactOutCredit` line 331-342)
- Lido (`LidoWstETHStandardExchangeCommon._refundExactOutCredit` line 462-471)
- EtherFi (`EtherFiWeETHStandardExchangeCommon._refundExactOutCredit` line 459-468)
- RebasingDETF, ComposedStableDETF, and other DETF families — same pattern via inherited `_refundExcess`/`_refundExactOutCredit`.

The exact-out path on these families takes only the operation's used amount from the pretransfer credit and refunds the rest, capped at the current unbooked surplus (so the refund never spends booked inventory). These families are already conformant on the exact-out path.

---

## 6. The owner question (one question, one sentence to close it)

The owner ruling's exact-in mapping has one choice that the PRD must close before a plan can be written. The implementer is not given a search or scope choice.

**The one question:**

> Should the exact-in pretransfer refund transfer only the caller's pre-transfer push excess (a per-call amount that requires either a new interface parameter or per-caller tracking), or should it transfer the entire `avail - amountIn` (which may include pre-existing unbooked, matching the README's existing donor-risk model)?

**The one sentence the PRD must use to close it (choose one):**

> The exact-in pretransfer refund MUST refund the caller's pre-transfer push excess minus `amountIn` and MUST NOT include any pre-existing unbooked surplus; the caller's push is captured by a new `uint256 pushedAmount` parameter on the `exchangeIn` family, validated against `LocalCreditLib.available(balance - booked, max)`, and the difference is refunded in the same call. Booked inventory is never spent.

or, if the donor-risk model is the intended reading:

> The exact-in pretransfer refund MUST refund the entire `avail - amountIn` from the unbooked surplus, where `avail = LocalCreditLib.available(balanceOf(vault), reserveOfToken(token))` is computed at the start of the call, capped at the current unbooked surplus after the operation; any pre-existing unbooked surplus is absorbed into the next caller's credit per the README's donor-risk model. Booked inventory is never spent.

The PRD must pick exactly one. Until it does, the implementer has a choice between the two readings, which violates "we never leave a choice for the implementer."

---

## 7. Scope boundary

Out of scope per the task:
- `contracts/protocols/dexes/uniswap/v4` — being deleted by a separate agent. Not searched.
- Slipstream — deprecated, do not restore. Its pretransfer path is recorded at `SlipstreamStandardExchangeCommon._refundExactOutCredit` line 482-... and `SlipstreamStandardExchangeOutTarget.sol:85`. The exact-in pretransfer path is at `SlipstreamStandardExchangeInTarget.sol:50-...`. No fix is proposed for Slipstream.
- No new economic model. The fix preserves the existing pretransfer credit, exact-out, and donor-risk accounting; it only changes the exact-in pretransfer refund to a new return (or adds a new parameter, per the owner question).
- No facet split. This is a one-line change per helper plus a documentation sweep.

---

## 8. Findings summary

| ID | Severity | File and line | Impact | Fix |
|---|---|---|---|---|
| F1 | Low | `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32` | integrator guidance still teaches withdrawn rule | Rewrite exact-in pretransfer paragraph |
| F2 | Low | `contracts/vaults/basic/BasicVaultCommon.sol:17, :70-71` | NatSpec still teaches withdrawn rule | Rewrite NatSpec |
| F3 | Low | `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21` | PRD still teaches withdrawn rule | Update table cell |
| F4 | Low | `docs/audits/apex-2026-09-17-evidence.md:61` | audit evidence still teaches withdrawn rule | Update sentence |
| F5 | Low | `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:124` | PRD still teaches withdrawn rule | Update D17/D28 cell |
| F6 | Low | multiple documents (F6 list above) | stale documentation | Sweep all references |
| F7 | Low | `docs/reviews/apex-remediation-application-2026-10-14/reviewers/minimax-cross.md:61` | review note still references old state | Update note |
| F8 | Low | `contracts/vaults/basic/BasicVaultCommon.sol:80-106` | base helper used by every family | Add surplus refund |
| F9 | Low | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:450-478` | V2 family | Add surplus refund |
| F10 | Low | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol:189-217` | Camelot family | Add surplus refund |
| F11 | Low | `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:974-1000` | Aerodrome V1 family | Add surplus refund |
| F12 | Low | `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:258-283` | Aave V3 Stata | Add surplus refund |
| F13 | Low | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:864-885` | V3 FullSpread | Add surplus refund |
| F14 | Low | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:905-926` | V4 FullSpread hookless | Add surplus refund |
| F15 | Low | `.../ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol` | V4 FullSpread Pons | Add surplus refund |
| F16 | Low | `.../upperLowerWings/...` | Wings | Verify + apply F8/F14 if no override |
| F17 | Low | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:251-272` | ERC4626 | Add surplus refund |
| F18 | Low | `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol:182-204` | Morpho Blue | Add surplus refund |
| F19 | Low | `.../detf/.../RebasingDETFTokenTarget.sol:468-...` | RebasingDETF | Add surplus refund |
| F20 | Low | `.../ComposedStableCommonDetfCommon.sol:769-...` | ComposedStableDETF | Add surplus refund |
| F21 | Low | `.../balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` | Balancer V3 SE | Add surplus refund |
| F22 | Low | hook products (dual, orbital, weighted, curve-quad, balancer-quad, single-CP) | hook families | Verify + apply F14 if no override |
| F23 | Low | `contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol:114-...` | staking migration | Add surplus refund |
| F24 | Low | staking `_securePull` (Rocket/Lido/EtherFi) | staking In | Add surplus refund |
| F25 | Low | InTarget sites that call the helpers | propagates from F8-F24 | no direct fix |

Plus the owner question in §6 that the PRD must close.

---

## 9. Reading direction summary

The exact-out path on every in-scope family already conforms. The exact-in pretransfer path on every in-scope family does NOT conform: the caller's pretransfer excess is absorbed into the booked reserve at end-of-op sync, not refunded. The documentation across many files still teaches the withdrawn "exact-in never refunds" rule. The fix is mechanical (one surplus-refund line per helper) and the documentation sweep is a list edit.

The one choice the implementer is left with is the exact-in mapping question in §6: per-caller push (interface change) or donor-risk whole-avail (no interface change). The PRD must close this. I have not invented a rule and I have not chosen a side.

I did not run Forge.