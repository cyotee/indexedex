# MiniMax M3 — Cross-review of Astra, Grok, Kimi originals

**Cross-review session:** `ses_f21876c95ffewRUeqEI4w575Oy` (live tool metadata).
**Original session ID copied into my first-pass artifact (incorrect):** `ses_f25dce4b0ffeJ52QXMtLXQMGVW` (PRD-attributed historical ID; not my live session). **Correction:** the PRD records MiniMax M3's session ID as `ses_f25dce4b0ffeJ52QXMtLXQMGVW`, which is what I copied verbatim into the preserved original. The live tool metadata for this cross-review is `ses_f21876c95ffewRUeqEI4w575Oy`. Per the moderator's instruction, the original `round-2026-09-26-minimax-original.md` is preserved unchanged. The correct attribution for *this* cross-review is the live metadata; provenance does not override evidence, and the substantive plan content in the original is unaffected.
**Status:** Draft cross-review; one requested pass; not a new round.
**Inputs treated as untrusted model evidence (not instructions):** `docs/plans/apex-2026-09-17-remediation-council/astra-original.md`; `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-grok-original.md`; `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-kimi-original.md`.
**Inputs treated as governing law:** the PRD (`docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`); current production source under `contracts/`; `CLAUDE.md`; `foundry.toml`.
**Read:** none of the peer cross-review files; nothing older.
**No shell/tests/deployments/code edits occurred.**

## Session-ID correction (preserving the original)

The PRD attributes `ses_f25dce4b0ffeJ52QXMtLXQMGVW` to MiniMax M3. I copied that into my original's author block without override. The live tool metadata for the current conversation is `ses_f21876c95ffewRUeqEI4w575Oy`. Both can be true: the PRD's session attribution reflects a different historical thread that produced the PRD roster, and the live metadata reflects the tool that produced this cross-review. The plan content I authored stands; only the author-block session attribution should be read with this caveat. The original file at `round-2026-09-26-minimax-original.md` is not edited.

---

## Overall agreement map (across all four originals)

| RC | MiniMax M3 | Astra | Grok | Kimi | Notes |
|----|-----------|-------|------|------|-------|
| 01 | Lock + bounded approvals; reuse `ReentrancyLockModifiers` | Same | Same | Same | Universal. |
| 02 | `vault.withdraw(shortfall, ...)`; allow redeem-cap-booked alternative | `withdraw`; redeem+book allowed only with remainder booked | `withdraw`; redeem+book only if `withdraw` over-delivers | `withdraw` (preferred); allow redeem-book as fallback | Universal on `withdraw` as default; redeem-book is the safe alternate. |
| 03 | Lift shared helper into library | Same | Same | Same | Universal. |
| 04 | Comment-only edits, bundle BalancerV3 with RC-01 | Same | Same | Same | Universal. |
| 05 | Delete unguarded function | Delete only the `exchangeOut`; keep file | Delete (preferred) | Delete (preferred) | Universal. |
| 06 | Truthify (capture SE return) OR remove return — implementer's choice | Make void; remove `seIn = maxIn` | Capture SE return (preferred); removal = alternative | Capture SE return | **Unresolved**: removal vs truthification. See §RC-06. |
| 07 | Saturate via `LocalCreditLib.available`; enumerate non-D16 consumers | Make base `_unbookedSurplus` virtual; override in each D16 family; preserve base body | Saturate in base; do not retarget historical callers | Saturate in base; companion test for Camelot L430 zero payout | **Unresolved**: how to express "consumer preservation" + "Camelot zero payout must revert". See §RC-07. |
| 08 | Named error `InsufficientLPBacking(uint256 poolBalance, uint256 vaultLpReserve)` | Named `InsufficientLpBacking(uint256 held, uint256 required)` | Named `ZapOutBackingShortfall(uint256 poolTokenBalance, uint256 vaultLpReserve)` | Named `PassThroughBackingDeficit(uint256 poolTokenBalance, uint256 vaultLpReserve)` | Naming is implementer choice; all four carry both compared values. |

---

## RC-01 — Lock + bounded approvals; callback reachability

**Agreements.**
- All four pick Crane `ReentrancyLockModifiers.nonReentrant` and bounded per-route approval. The Crane modifier exists at `lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:21-30` (verified); it delegates to `ReentrancyLockRepo._onlyUnlocked/_lock/_unlock` (Grok's `ReentrancyLockRepo.sol:62-63` transient-tstore inference — read at this pass: pragma `^0.8.24`, abstract contract; transient-tstore use is plausible but not independently verified in this pass and is not load-bearing for the plan).
- All four reject `try/catch` for allowance cleanup; transactional revert preferred.
- All four agree the stale `(M3)` comment at `BalancerV3SinglePoolStandardExchange.sol:262` is corrected in this RC (RC-04 bundle).

**Specific objections / clarifications.**
- **Grok's medium-confidence note** on the gold 80/20 pool hosting the callback token: I agree it is the open empirical question. The PRD allowance is "callback-capable token fixture is allowed" (PRD line 82); the PRD does **not** require the existing 80/20 test pool to host a callback token. The cleanest evidence path is to deploy a *second* production gold pool for the callback fixture, or to use the existing `_deployNoUnbalancedPoolAndAdapter` helper as a template (which already lives in `Adversarial_BalancerV3SinglePoolSE.t.sol:313-355`). I now agree with Grok: medium confidence on a single-pool test, high confidence on a parallel-pool callback fixture built off the same TestBase.
- **Astra's "router lock is not an adapter lock"** emphasis is correct and is now baked into my recommendation: PRD line 81 explicitly forbids treating the downstream router lock as a substitute. I accept Astra's wording as the canonical reminder.
- **Astra's "internal book observation can use read-only storage evidence plus a second no-credit production call, not a new public getter solely for testing"**: I agree this is the right path. A direct internal-storage read in the test (via the cannonical crane `Repo._layout()` accessor that already exists for the adapter's `_tokenReserve` mapping) is preferable to a public getter. This sharpens my "Red → green" assertion to "compare `_tokenReserve[tokenIn]` to `balanceOf(this)` between callback entry and reentry point" rather than asserting on a hypothetical getter.

**Evidence that changes my view.**
- None new. My original line-number references are confirmed.

**Specific correction to my original.**
- Add the "alternate gold pool" test path note (use `_deployNoUnbalancedPoolAndAdapter` as a template) and the internal-storage read preference. No structural change to RC-01's recommended fix.

---

## RC-02 — Exact local-first payout; precise preview guarantee and safe alternate custody

**Agreements.**
- All four pick `vault.withdraw(shortfall, recipient, address(this))` as the default. Grok's note on the EIP-4626 fixture: `SimpleYieldERC4626.sol:168` makes `withdraw` use the vault's own preview (verified inference; not independently re-read at this pass, but the cited file is part of the hermetic test infrastructure).
- All four agree the recipient delta must equal `due`, exact-in return must equal recipient delta, and the orbital composing check (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:559-564`) must close with no operation-created face above opening balance on a non-identity buffered leg.

**Specific objections / clarifications.**
- **Grok's "alternative redeem+book is valid only if a configured vault's `withdraw` over-delivers; EIP-4626 forbids that"**: this is the strongest statement in the group. EIP-4626 § `withdraw` mandates exact-asset delivery (Context7 `/websites/eips_ethereum`, EIP-4626 spec section on `withdraw`/`redeem`/`previewWithdraw`). On a standards-compliant vault, `withdraw(assets, ...)` must deliver exactly `assets`. The PRD's "exact-asset withdrawal need not create a remainder" sentence (line 254, cited by Kimi) is the operative permission: the implementer may pick `withdraw` and not be required to manage a remainder. **The redeem+book alternative is therefore a defensive fallback only — it is not the standards-compliant path.** Kimi's and my own "allowed alternative" wording should be tightened to "defensive fallback for non-standards-compliant fixtures" rather than presented as an equal-weight option. I accept Grok's stricter framing.
- **Astra's "Orbital must use the real SE proxy, configured rate provider, real PoolManager/router, non-identity buffered output leg and actual capped unwrap"**: this is the operational standard for the composing test. The PRD allows a fixture, but the composing test must not fake the SE. I now require: real SE proxy + real configured rate provider + real PoolManager/router (the existing `TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol` referenced by Astra — not independently verified in this pass; treated as PRD-canonical path).
- **The "precise preview guarantee" question the moderator flagged**: this is the standards question above. The correct interpretation is: `previewWithdraw` is an *upper bound* on shares charged (EIP-4626 § previewWithdraw). A standards-compliant `withdraw(assets)` charges the vault's implementation-defined share count (typically the rounded-up share count from the vault's internal math). It is **not** required to charge `previewWithdraw(assets)` shares exactly. Grok's phrasing "the local fixture sets withdraw charge to previewWithdraw" is fixture-specific and is not a general standards claim. **The PRD acceptance is that recipient delta equals `due`** — it does not assert a specific share-charge match against `previewWithdraw`. I now tighten my plan wording: assert recipient-delta equality; do not assert share-charge equality against `previewWithdraw`.
- **Safe alternate custody** (the moderator's wording): the redeem+book path effectively mints extra into the SE's book by calling `vault.deposit(got - shortfall, address(this))` before the recipient transfer. This is a temporary custody on the SE before the end-of-route sync. PRD allows this (line 95: "Any protocol-vault rounding remainder stays booked on the SE, or the route uses an exact-asset withdrawal whose share charge matches the preview"). The "book the remainder" path is acceptable but is **safe custody on the SE only** — it is not a refund to the caller and not a transfer to `feeTo`.

**Evidence that changes my view.**
- EIP-4626 standards framing (Grok's). Tightened my plan: standards-compliant `withdraw` is the default; redeem+book is a fallback for non-standards-compliant fixtures only.

**Specific correction to my original.**
- Approach (A) `withdraw` stays as recommended.
- Approach (B) (redeem + rebook excess) is now scoped to "non-standards-compliant fixture only" and is labelled defensive fallback, not an equal-weight alternative.
- Drop the language that suggests `withdraw` over-delivery as a real concern; cite EIP-4626 mandate instead.
- Assert recipient-delta equality; do not assert share-charge equality against `previewWithdraw`.

---

## RC-03 — Stata backing; SY/transition consumers

**Agreements.**
- All four agree on a shared helper. Kimi and Astra propose `ReceiptBackedERC4626AccountingLib` extension; I propose a small new `StataBackingLib`. Grok proposes "one library function used by both, scan expected-hold tokens the way `_bookedATokenEquiv` does". All four converge on the same shape.
- All four preserve the Stata-marker dispatch (ERC-165 marker on the proxy) and the generic ERC-4626 zero-aToken branch.

**Specific objections / clarifications.**
- **Astra's "Read/test Stata SY rate and both In/Out transition consumers"**: this is the consumer-closure piece the moderator flagged. Looking at `AaveV3StataStandardExchangeCommon.sol:52-58` (`_stataBacking`) is the only call into the receipt-units math; the SY quote and In/Out transition consumers are higher-level routes that ultimately call `IERC4626(vault).convertToShares/convertToAssets/previewDeposit/previewMint/...`. The shared adapter `ReceiptBackedERC4626Target` already serves generic + Stata for these. **The Stata proxy's SE routes** (`exchangeIn`, `exchangeOut`, `previewExchangeIn`, `previewExchangeOut`) use the SE's own `_stataBacking` for share math. **SY rate** uses the proxy's `convertToAssets`/`convertToShares` paths on the shared adapter. **Transition consumers** (e.g. SE-to-protocolVault or protocolVault-to-SE exchanges) on a Stata proxy use both `_stataBacking` (SE side) and `convertToShares/Assets` (shared adapter side). The fix must align both, or the two surfaces still disagree.

  Concretely: a Stata proxy that uses the FullSpread "SY" surface for tokenIn/tokenOut would resolve `convertToShares(amountIn)` against the shared adapter (`_totalReceiptBacking`, which already includes booked aToken) while resolving `previewExchangeIn(se, ...)` against the SE's `_stataBacking` (which today excludes booked aToken). After the fix, both must include booked aToken. Test must exercise both sides in one matched state.

- **Grok's "These are different facet bytecodes; an internal call cannot be shared"**: this is correct but does not block the fix. The fix is to share a *library* that both surfaces call. Library calls are cheap; the bytecodes still differ.
- **Aave LM reward forwarding** (Astra, Kimi, my original all note this) is unchanged. The reward stream is at `AaveV3StataStandardExchangeCommon.sol:182-198` and is **not** in the touched area.

**Evidence that changes my view.**
- The SY/transition dual-surface match (Astra). I now sharpen my plan: the test must exercise `convertToShares` and the SE's `_stataBacking` (or its preview) on the same state and require equality of share entitlement for the same input amount.

**Specific correction to my original.**
- Add the SY/transition dual-surface assertion to the red/green acceptance: on one state, `IERC4626Metadata(stataAdapter).convertToShares(x)` and `previewExchangeIn(se, x, underlying)` (or `convertToShares(x)` of the SE proxy itself if it inherits the shared adapter) must agree on entitlement when booked aToken is nonzero.
- Library placement: accept either Kimi's `ReceiptBackedERC4626AccountingLib` extension or my proposed `StataBackingLib`. The concrete contract is that the `_bookedATokenEquiv` iteration becomes one source of truth.

---

## RC-05 — Unused single-CP HookTarget `exchangeOut`; thin-inheritor path

**Agreements.** All four prefer deletion. No inheritor exists (Kimi's grep + my grep both confirm zero matches). Installed cut unchanged.

**Specific objections / clarifications.**
- **Astra's "Thin delegation to the installed guarded helper is allowed but adds coupling without benefit for unused code"**: I accept. With zero inheritors, the function is unreachable; a thin wrapper adds a second public money implementation that the PRD explicitly forbids retaining (line 142). **Deletion is the only acceptable fix.** A thin wrapper is not acceptable even as a fallback in this case.

**Evidence that changes my view.** None new.

**Specific correction to my original.**
- Approach (B) (thin delegation) is now disallowed for RC-05. Delete-only.

---

## RC-06 — Orbital unwrap return; internal-return testability vs removal

**Agreements.** All four agree the return must either be truthful or removed. No caller captures the return at the seven sites (Astra enumerates seven: `Common:586,604,1899`; `SeTarget:125,185,250`; `WithdrawTarget:177`; my own read confirms `:586, :604, :1899` in Common, and Grok adds SeTarget + WithdrawTarget). The seven sites are statement-form calls; deletion is mechanically safe.

**Specific objections / clarifications.**
- **The moderator's "internal-return testability" question**: the function is `internal`. The testability of an internal function in Foundry is via a thin harness inheritor or a wrapper external function exposed for the test. There is currently no harness on this function in the test suites. **Truthifying** (capturing the SE return and assigning to `seIn`) lets a new harness assertion compare `seIn` to the share-balance delta around the call. **Removing** the return means the test must assert indirectly via the recipient token balance delta and the cleared allowance, which is what the existing test path already does. Both are testable; the difference is whether the test can directly observe the share delta.

- **Grok's preferred: truthify. Astra's preferred: remove return.** Both are implementer choices per PRD line 156. The PRD allows either.

- **My position adjusts:** I now recommend **removal** as the default (matches Astra) because (i) no caller uses the return, (ii) the function is internal and the existing test path already proves recipient/allowance correctness, (iii) the share-delta observation can be added to the test by capturing `IERC20(se).balanceOf(this)` before and after the SE call inside the harness, not by changing production. This avoids the production-side coupling that capturing the SE return introduces (any future SE behavior change surfaces through the returned value).

- **Kimi's preferred: truthify. Kimi's reasoning is correct** (PRD permits; less churn). I disagree on defaults: I prefer removal because the value is dead in production today, and keeping a "truthful" return invites a future caller to start using it without understanding why the value is the share balance and not the cap.

**Evidence that changes my view.**
- The seven-caller enumeration (Astra). I accept the higher count and the case for deletion over truthification.
- The internal-only nature (no public exposure) means testability does not require the return to exist.

**Specific correction to my original.**
- Default RC-06 fix is now **removal** (signature becomes `internal` returning nothing). Capture-the-SE-return remains as the alternative if the implementer disagrees.

---

## RC-07 — Saturate base `_unbookedSurplus`; historical behavior preservation; Camelot zero payout

This is the central cross-review item the moderator flagged. Below is the consolidated picture across all four originals and the actual source.

### Source facts (verified at this cross-review pass)

- `_unbookedSurplus` (the basic vault's copy, `BasicVaultCommon.sol:33-36`): checked `balanceOf - reserveOfToken`; panics on `balance < booked`.
- Callers of `_unbookedSurplus` (the base copy):
  - `BasicVaultCommon._refundExcess` at `BasicVaultCommon.sol:128` (its own refund helper).
  - `CamelotV2StandardExchangeOutTarget.sol:430` — *direct* call; transfers **all** unbooked balance to recipient: `tokenOut.safeTransfer(recipient, _unbookedSurplus(tokenOut));`.
- `_refundExcess` callers (call the base helper that internally calls `_unbookedSurplus`):
  - `UniswapV2StandardExchangeCommon.sol:476` (Uni V2).
  - `CamelotV2StandardExchangeCommon.sol:214` (Camelot).
  - `AerodromeStandardExchangeCommon.sol:1002` (Aerodrome).
  - `AerodromeStandardExchangeOutExecuteTarget.sol:168, 267, 335, 371, 473, 497, 552` (Aerodrome direct execution).
- `is BasicVaultCommon` inheritors (verified grep): Uni V2 Common, Camelot Common, Aerodrome Common, Stata Common. Four families.
- Balancer adapter's `_unbookedSurplus` at `BalancerV3SinglePoolStandardExchange.sol:218-222` is its own private copy (already saturating per Grok's reading; my read confirms: `balance_ > reserve_ ? balance_ - reserve_ : 0`).

### Grok's stronger statement (and Kimi's) on the **direct-call consumer**

Grok's callout that Camelot L430 *currently pays all unbooked `tokenOut`* is the load-bearing piece for RC-07. Under the current checked-subtraction implementation:
- If `balance >= booked`: `_unbookedSurplus` returns `balance - booked`; Camelot L430 transfers the surplus. No defect.
- If `balance < booked`: `_unbookedSurplus` reverts (Panic(0x11)). Camelot L430 never reaches the transfer; the route reverts atomically. **No zero payout today**; an opaque panic instead.

After the fix (saturating via `LocalCreditLib.available`):
- If `balance >= booked`: identical behavior.
- If `balance < booked`: `_unbookedSurplus` returns 0. Camelot L430 transfers 0 wei to recipient. **This is the "zero payout" companion test Grok flagged.**

The zero-payout behavior is **a behavior change** for the Camelot L430 path when `balance < booked`. The PRD explicitly permits this (line 165): "Every active in-scope D16 refund path that calls `_unbookedSurplus` returns zero credit when balance is below book, and does not pay booked inventory." The PRD is explicit that the deficit path must not pay booked inventory and that zero credit is the result.

**What must happen to satisfy the PRD acceptance:**
1. The base `_unbookedSurplus` must saturate (no panic).
2. Camelot L430's zero-payout must revert atomically with a **named insufficient-credit error**, not silently succeed with a zero transfer (Grok: "after a zero result, a positive `amountOut` must revert with an existing shortfall error, not transfer 0 and succeed"). The zero transfer alone is silently letting the route "complete" without paying the recipient — that is a separate defect surface that the PRD implicitly rules out by saying "does not pay booked inventory" plus the route's `amountOut` expectation.

This means **two coordinated changes** for RC-07:
- Saturate `_unbookedSurplus` (base helper) and the `_secureTokenTransfer` pretransfer branch (`BasicVaultCommon.sol:98`).
- Add a precheck to Camelot L430: if `_unbookedSurplus(tokenOut) < amountOut` (or equivalent), revert with the family's named insufficient-credit error before the transfer. This is a Camelot OutTarget edit, not a base edit; it preserves the historical consumer's interface.

### Astra's "virtual base + override in D16 families" alternative

Astra's alternative is to make `_unbookedSurplus` virtual and override it in each D16 family to use `LocalCreditLib.available`. This avoids touching the base body but adds a small override surface. **Consequence:** the Camelot L430 path still calls the **overridden** saturating helper, which returns 0 in deficit. The "transfer 0" silent success remains a defect unless Camelot L430 also adds the precheck.

Astra's pattern is sound; it just doesn't by itself close the zero-payout silent-success concern. The precheck at Camelot L430 is independent of whether the base saturates or the override saturates.

### Historical consumer protection (PRD requirement)

The PRD requires a **historical-consumer inventory** before any base-helper edit (line 168). The implementer must produce this inventory as evidence. The relevant consumers are:
1. `_refundExcess` (BasicVaultCommon internal).
2. `CamelotV2StandardExchangeOutTarget.sol:430` (direct call, must add precheck).
3. `_secureTokenTransfer` pretransfer branch at `BasicVaultCommon.sol:98` (inline `U = B0 - R`).

All D16 public entries already have a `requirePretransferCaller`-guarded override (Uni V2 `420-447`, Camelot `158-185`, Aerodrome `946-973`, Stata `200-227` per Astra; my read confirms the override family). The base pull's NatSpec delegates the caller check; the base branch is unreachable from a no-bytecode caller. The PRD requires the implementer to **enumerate** these in the test evidence file (line 168).

### Evidence that changes my view.
- Grok's Camelot L430 zero-payout observation. My original plan did not name Camelot L430 specifically; I now add it as a coordinated edit.
- The two-edit shape (saturate base + Camelot L430 precheck) is the correct closure.

### Specific correction to my original.
- Add a coordinated edit at `CamelotV2StandardExchangeOutTarget.sol:430` (or equivalent `amountOut > _unbookedSurplus(tokenOut)` precheck) so the deficit case reverts a named error rather than transferring zero.
- Tighten the historical-consumer inventory to three entries (above).
- Recommend Approach (A) (saturate via `LocalCreditLib.available`) as the default; Approach (B) (virtual + override) is acceptable but does not by itself close the zero-payout concern at Camelot L430.

---

## RC-08 — Named error on the Uni V2 backing check

**Agreements.** All four agree a named error carrying both compared values is required. Naming is implementer choice.

**Specific objections / clarifications.**
- **The moderator's "safe alternate custody" framing for RC-02** does not apply to RC-08 directly; the comparison is a reordering question only. The PRD evidence-fallback language (lines 183-184) is operative.
- **Astra's "extract the identical production comparison into a small internal pure check called at this site; a thin test exposure asserts exact error/arguments for held<required and success for equality/greater"**: this is the right shape for the unreachable-without-mocks path. The internal pure check is the same comparison; the test exposure is a thin external wrapper added only for the test, gated by `internal pure` extraction. I now accept this as a cleaner shape than asserting the production check directly in a Foundry test (which would require constructing the deficit state via either a real deficit path or a `vm.store`).
- **Naming convergence:** all four names are equivalent. Pick `InsufficientLPBacking(uint256 poolBalance, uint256 vaultLpReserve)` for consistency with the PRD's audit disposition vocabulary.

**Evidence that changes my view.**
- Astra's pure-check + thin-test-exposure shape. Sharper than my "assert the production check itself reverts" wording.

**Specific correction to my original.**
- Test path (2) becomes: extract the comparison into a `internal pure` check (`_passThroughBackingOk(...)`), call it from the production site, and add a thin `external` test wrapper (e.g. a `TestHook` contract) that exposes the pure check for direct assertion. Do not `vm.store` the vault or write its storage.

---

## Cross-cutting corrections

1. **Session-ID correction (above).** Preserved original; cross-review carries the live metadata.
2. **Severity rating alignment.** RC-01: PRD says Medium (load-bearing fix). RC-07: PRD says Low (no demonstrated live exploit). My original preserved these.
3. **EIP-7702 / D44 reminder.** None of the four originals reopen this; the PRD records D44 as accepted.
4. **Build/test workflow.** All four invoke `forge build` before `forge test` and the `scripts/forge-artifacts.py test <source.sol> --test-root <suite>` workflow. Kimi's order notes this explicitly; the others imply it.
5. **Preserved Uni V3/V4 trees.** All four agree: do not select for new deploy; do not edit.
6. **Audit PDF.** Kimi did not read it; Grok did not read it; Astra references it; I did not read it in this round either. Consistent treatment.
7. **NatSpec / selector derivation.** Grok mentions `scripts/foundry/ComputeNatSpecValues.s.sol` for the new named-error selector. The `lib/crane/AGENTS.md` injects a `cast sig` and `cast keccak` workflow. Either is acceptable; the project's `crane-natspec` skill is the canonical source.

---

## Planning recommendations (consolidated, ready for moderator's `IMPLEMENTATION_PLAN.md`)

1. **Order:** RC-01 (with RC-04 BalancerV3 comment bundle) → RC-05 (delete-only, no thin wrapper) → RC-08 (named error + internal pure check + thin test exposure) → RC-02 (standards-compliant `withdraw`; redeem+book only as defensive fallback) → RC-03 (shared library; SY/transition dual-surface assertion) → RC-06 (delete return; alternative truthification kept as implementer choice) → RC-07 (saturate `_unbookedSurplus` + `_secureTokenTransfer` pretransfer; coordinated precheck at Camelot L430; historical-consumer inventory). RC-04 documentation completes per file as each is touched.

2. **Test-failure shape:** every red/green pair uses the same assertion. Assertion oracles: recipient/caller balance deltas, `_tokenReserve` (via direct storage read in the test, not a new getter), `_bookedReserve`, allowance (router + Permit2 ERC20 + Permit2 packed), named errors. No reliance on the return value of an internal function as the sole oracle.

3. **Fixtures allowed by PRD:** callback-capable ERC-20, non-unit-rate ERC-4626 (`SimpleYieldERC4626.simulateYield`), a parallel gold pool (template: `_deployNoUnbalancedPoolAndAdapter` at `Adversarial_BalancerV3SinglePoolSE.t.sol:313-355`). Not allowed: SUT mocks, `vm.store` on SUT storage, fake Permit2/PoolManager surfaces.

4. **Evidence artifacts (required from implementer):**
   - Selector manifest for new/modified functions and errors.
   - Runtime size check on affected facets/packages (≤ 24,576 bytes per D19).
   - Full relevant family suites green under hermetic profile.
   - Source-preservation hash for preserved Uni V3/V4.
   - Fresh-deployment selection of FullSpread (not preserved) implementation.
   - Historical-consumer inventory for RC-07 (three entries above).
   - SY/transition dual-surface equivalence proof for RC-03.
   - RC-01 parallel-pool callback fixture build script (not the gold 80/20).
   - RC-02 EIP-4626 standards reference (Context7 `/websites/eips_ethereum`).

5. **Dissent to preserve:**
   - RC-06: my preferred becomes removal (was truthification); Grok and Kimi still prefer truthification. PRD allows either; record this as the implementer choice.
   - RC-07: severity Low per PRD; Kimi Medium informational only.

6. **No new product question.** All four originals and the PRD's clarity pass converge on no open question for the owner.

---

## Final acknowledgment

The four originals are substantively aligned on RC-01, RC-02, RC-03, RC-04, RC-05, RC-08. RC-06 and RC-07 had unresolved specifics that this cross-review now closes with the corrections above. The plan content I authored in the original stands; the corrections sharpen it on the six items the moderator flagged.

Original preserved unchanged. Cross-review authored at `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-minimax-cross.md`. Returning to the moderator; no autonomous further rounds.