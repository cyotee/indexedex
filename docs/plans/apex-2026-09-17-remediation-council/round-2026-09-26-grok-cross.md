# Grok cross-review — APEX RC-01..08 implementation plan

- **Author:** Grok (`xai/grok-4.7`). One cross-review. Not a rewrite of the first pass.
- **Date:** 2026-09-26.
- **Own original, preserved by the moderator:** `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-grok-original.md`. Left untouched here. `docs/plans/apex-2026-09-17-remediation-council/grok-original.md` was not opened beyond the identity mismatch already recorded, and was not edited.
- **Peers read in full, as untrusted model evidence:** `astra-original.md`, `round-2026-09-26-minimax-original.md`, `round-2026-09-26-kimi-original.md`. No cross-review files and no older council originals were read.
- **Authority:** current `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Source re-reads below override peer claims where they conflict.

MiniMax's artifact copies session `ses_f25dce4b0ffeJ52QXMtLXQMGVW`. The moderator's live tool metadata for this round is `ses_f21876c95ffewRUeqEI4w575Oy`. That is provenance, not proof of provider identity, and it is not a reason to discard the technical text. The copied ID is the historical PRD ID, not this round's session.

## Agreements

All four recommend, and I still recommend:

- RC-01: Crane `ReentrancyLockModifiers.nonReentrant` on both adapter money entries; approve the route spend, not maxima; clear router, Permit2 ERC-20, and packed Permit2 allowances on success; no `try`/`catch`; no extraction claim; callback fixture plus ordinary-token control. The router lock is not a substitute.
- RC-02 default: `vault.withdraw(shortfall, recipient, address(this))` in `ERC4626StandardExchangeCommon.sol:80-92`. Do not pay remainder to `feeTo`. Do not add an exact-in refund.
- RC-03: one shared backing helper that includes booked non-receipt, non-underlying expected-hold reserves, then `ReceiptBackedERC4626AccountingLib.receiptUnits`. Absent aToken contributes zero. Do not change reward forwarding at `AaveV3StataStandardExchangeCommon.sol:182-198`.
- RC-04: comment and README edits only. Balancer line 262 ships with RC-01.
- RC-05: delete `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.exchangeOut` (`736-768`). Do not delete the file or recut `HookSeFacet`.
- RC-08: named error carrying both compared values at `UniswapV2StandardExchangeOutTarget.sol:578-580`. Same comparison. Do not wait for an owner question. Reachability is low.
- Hermetic profile, `solc` pin `0.8.35`, `via_ir = false`, no SUT mocks, no storage fabrication, fresh deployments only. Installed Forge was not observed.

## Corrections to my original

1. **RC-01 zero-allowance claim was too weak.** `Adversarial_BalancerV3SinglePoolSE.t.sol:103-118` already asserts all three allowances are zero after success, not merely "not max." Astra is right. Those tests still do not prove in-flight authorization or reentry. Keep them. Add the lock cases beside them.

2. **RC-03 missed a live SY bypass.** `quoteState` seeds transition state from `_stataBacking()` (`AaveV3StataStandardExchangeInTarget.sol:149-156`), and `quoteTransition` (`200-226`) consumes that state. SY `deposit` / `redeem` / `previewDeposit` / `previewRedeem` call the installed exchange (`NativeStandardYieldTarget.sol:20-76`). Those follow `_stataBacking` once it is shared. `AaveV3StataStandardYieldTarget.exchangeRate` (`26-35`) does not. It recomputes held Stata plus booked underlying and omits aToken. PRD L105 requires one backing calculation for IERC4626, SE, SY, and transition quotes. `exchangeRate` must call the same helper. Astra's "edit only if it bypasses" is the right rule, and this function bypasses. MiniMax and Kimi, and my original, omitted it.

3. **RC-07 global helper edit is the wrong historical-preservation mechanism.** My original changed `BasicVaultCommon._unbookedSurplus` for every caller and then updated `BasicVaultCommonHarness`. That changes non-D16 deficit semantics from panic to zero. Astra's virtual override is the better reading of PRD L163-168. I adopt it.

4. **RC-07 Camelot companion was too broad.** Requiring `measured >= amountOut` at `CamelotV2StandardExchangeOutTarget.sol:430` would reject short-surplus payouts that already succeed when `balance >= book`. The comment at 429 pays measured surplus, not the quote. Only the former panic case (`balance < book`) must stop being a successful zero transfer.

5. **RC-06 truthful-return test is not production-observable.** `_unwrapExactTokenOut` is internal. No existing public selector returns it. A new selector is not authorized. I change the recommendation to removal. The truthful-return alternative remains allowed only if an existing observer is found. Do not add one.

6. **RC-02 preview equality was overclaimed.** Crane `IERC4626.sol:157-159` says `withdraw` returns the same or fewer shares than `previewWithdraw`, not equal shares on every implementation. EIP-4626, accessed via Context7 `/websites/eips_ethereum` on 2026-09-26, guarantees exact assets from `withdraw`, not universal share equality. Assert share equality only on `SimpleYieldERC4626.sol:168`, which sets the burned shares to `previewWithdraw`.

7. **RC-02 orbital suite.** `UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol` exists. `test_R6_swapExactIn_noLeftoverFace` (`188-195`) and `test_R6_cappedUnwrap_fundedSuccess` (`223`) are the composing scaffold. They do not yet force a non-unit SE shortfall. Prefer extending Apex008, or the ERC-4626 matrix row, with that precondition. My earlier matrix-only pointer was incomplete, not wrong.

## Settled recommendations

### RC-07 — preserve base panic; saturate only D16; reject Camelot's deficit payout

**Choose Astra's isolation, plus a narrow reject I still require.**

- Make `BasicVaultCommon._unbookedSurplus` virtual and leave its checked body unchanged.
- Override it in the four production `BasicVaultCommon` heirs so D16 refunds use `LocalCreditLib.available`: Uni V2 `420`, Camelot `158`, Aerodrome `946`, Stata `200`. Inherited `_refundExcess` then saturates on those diamonds.
- Do not edit the base pull at `98`. Do not add `requirePretransferCaller` there. Prove the four overrides, and that Slipstream, FullSpread, hooks, and DETF do not inherit `BasicVaultCommon`, so public D16 entries cannot reach the unguarded branch. An EOA `pretransferred=true` revert of `EOAPretransferNotAllowed` is that proof.
- Do not rewrite `BasicVaultCommon_{TokenTransfer,TrustFlags,Permit2}.t.sol` or the fork Permit2 harnesses. Do not run forks. Hermetic only.

**Camelot zero payout.** Line 430 transfers the helper result as the whole tokenOut delivery and then returns `used` (`437`). Today `balance < book` panics. After a saturating override, `safeTransfer(..., 0)` succeeds. That is not "zero credit that the caller then rejects" (PRD L169). It is a new successful underpayment.

- If `tokenOut.balanceOf(this) < _bookedReserve(tokenOut)`, revert the family's existing insufficient-credit error with the owed and available amounts. Do not transfer.
- If `balance >= book`, keep the current measured-surplus transfer, including a zero transfer when surplus is zero. Do not add an `amountOut` floor.

Refund paths are different. `_refundExcess` (`120-135`) caps a refund. A zero cap does not pay booked inventory. If a positive unused claim meets a mid-route deficit, revert `TransferDeltaInsufficient(claimedUnused, 0)` rather than committing the swap with a silent zero refund. That is the panic's atomicity, expressed as the named error. It is not a new economics rule.

**Reject MiniMax A and Kimi's base-pull edit.** Both change `U = B0 - R` (`98`) for every direct base caller, including the harness. MiniMax's "purely additive" and "no accounting change when `balance >= book`" claims do not cover Camelot 430, where the deficit branch changes from revert to success. Kimi's sentence that Camelot "changes from panic to zero-credit, which is the intended D16 semantics" omits that zero-credit here is paid out as a successful route.

**Reject a global body edit**, including my original. It is an allowed alternative only after a complete non-D16 consumer list proves no semantic change. The harness and fork files already fail that test.

### RC-06 — remove the unused return

**Choose Astra's removal.** Change `_unwrapExactTokenOut` (`550-565`) to return nothing. Delete `seIn = maxIn`. Keep the approval cap, the approve-back-to-zero, and the short-delivery revert at `564`. All seven statement callers ignore the return: common `586`, `604`, `1899`; SeTarget `125`, `185`, `250`; WithdrawTarget `177`. Compile those files. No caller-expression rewrite is required.

PRD L235 allows a production-hook assertion of the return only if the return remains. Observing an internal return on the production proxy needs a new selector. Do not add one. Green is the existing unwrap test: quoted token out, allowance cleared, short delivery rolls back, plus a source check that `seIn = maxIn` is gone.

Kimi's and my truthful-return choice remains allowed, not recommended. MiniMax undercounted callers as three in one file. That does not change the removal recommendation, but the compile set is seven sites, not three.

### RC-03 — one helper, including SY rate and transition seed

**Choose a storage-reading library function**, called by:

- `ReceiptBackedERC4626Target._totalReceiptBacking` (`183-198`)
- `AaveV3StataStandardExchangeCommon._stataBacking` (`52-58`)
- `AaveV3StataStandardYieldTarget.exchangeRate` (`26-35`), replacing the duplicated formula
- generic `ERC4626StandardExchangeCommon._receiptBacking` (`64-68`) with the extra term gated off unless the Stata marker is set

`quoteState` (`155`) then carries the shared value into `quoteTransition`. Do not give transition quotes a second formula. Do not self-call fee-bearing SE entries to read backing. Do not inherit the ERC-4626 target into the Stata facet.

**Test:** nonzero booked aToken, created by a real transfer plus a completed production route that syncs the expected-hold set. Compare adapter `totalAssets` / conversions, SE preview and execution, `exchangeRate`, and a `quoteState` plus `quoteTransition` on that same state. Later deposit must use the larger basis. Generic mode, including a generic wrapper over a Stata receipt without the marker, has no extra term. Fee adjustment must be explicit so dilution is not mistaken for a backing mismatch.

MiniMax's local-only duplicate (alternative B) is allowed only if the library move cycles. It is not preferred. MiniMax's "no external contract reads `_stataBacking`" is false for this purpose: `exchangeRate` is a separate external quote with its own copy.

### RC-01 — bound the amount; do not require extraction

**Choose** Crane `nonReentrant` on `exchangeIn` and `exchangeOut`. Approve `actualAmountIn`, `actualBptIn`, or exact-out `spendable` (`credit` if pretransferred, else `quotedUsed`). If the amount does not fit in `uint160`, revert. Do not truncate. Clear all three allowances after the router returns and before refund, payout, and sync. Keep Permit2 expiration at `type(uint48).max`. A shorter `deadline + buffer` is not in the PRD and is a behavior change. MiniMax's alternative B, lock only and keep max approval, contradicts PRD L79. It is not allowed.

The adapter already calls `LocalCreditLib.requirePretransferCaller` (`156`, `231`). MiniMax's claim that these are not public pretransfer entries is false. Do not remove those checks. Do not add sender attribution.

**Red/green:** a callback-token fixture on a production CREATE3 adapter. Nested In/Out combinations during funding and during the router token move revert `IReentrancyLock.IsLocked`. Assert that error. Do not treat a stale-reserve delta as the required oracle, and do not claim extraction. If the fixture swallows the nested revert so the outer call can finish, the test must still record that the nested call reverted the lock error. Outer revert leaves balances and books unchanged. Success keeps the existing zero-allowance assertions (`115-117`) and post-settlement `_tokenReserve == balanceOf`. Ordinary tokens still complete.

Reusing `LocalCreditLib.available` for the adapter's already-saturating copy (`218-221`) is optional cleanup, not part of the defect.

### RC-02 — exact assets; safe remainder custody

**Choose** `withdraw(shortfall, recipient, address(this))`. Recipient asset delta equals `due`. On `SimpleYieldERC4626`, also assert burned shares equal `previewWithdraw(shortfall)`. Do not require that equality for every external vault.

**Allowed alternate:** `redeem` to `address(this)`, transfer exactly `shortfall` to the recipient, leave the asset remainder on the SE, and let the existing end sync book it. That is the only safe alternate.

**Reject MiniMax B.** Redeeming to the recipient and then `deposit`ing the over-delivery back can hit the cap or pause, mint shares to the SE, and change backing. That is not "remainder stays booked."

Orbital green: extend Apex008, with a non-unit ERC-4626 SE leg and an explicit rounding precondition, so a successful capped unwrap does not leave operation-created face above the opening balance. Pre-existing D12 face is measured separately. Establish the rounding failure against current redeem behavior before the withdraw edit, then rerun the composed case after.

## Other objections

- MiniMax RC-05 step in the implementation order deletes `_unwrapExactTokenOut`. That is RC-06. RC-05 deletes HookTarget `exchangeOut` only.
- MiniMax RC-05 alternative B points at ERC-4626 `_securePull`. The installed guarded helper is `HookSeTarget._pullExactOutInput` (`862-864`). Do not couple the unused hook to the ERC-4626 vault.
- MiniMax RC-04 regression suite (`StandardExchangeBufferPoolTarget` or the Balancer adversarial file) is the wrong family. Rerun `ERC4626StandardExchange_APEX_R14.t.sol` and one FullSpread exact-out suite, as the PRD says. Do not preserve README `min(max - used, actualIn - used)` or the V3 buffer / V4 max / dual max-share sentences. Those are the stale claims (`README.md:32-36`).
- MiniMax RC-08 says this OutTarget is consumed by FullSpread packages. It is not. FullSpread is `contracts/vaults/standard/exchange/protocols/uniswap/`. Do not edit that tree for RC-08.
- Empty `revert()` at Uni V2 OutTarget `859` and `980` are real and out of scope. Do not fold them into RC-08.
- Astra's RC-08 fallback, a small internal pure comparison called by the production site and asserted with both values, is the right way to "assert the production check itself" if a supported route cannot reach the branch. Adopt it. Do not `vm.store` the vault. Record that this is not end-to-end reachability.
- `HookTarget.exchangeIn` (`700-711`) still skips the caller check and credit cap. All four left it out of RC-05. It stays out of scope. Record it so an implementer does not silently expand, and so it is not mistaken for a closed item.

## Unresolved

- Whether a supported zap-out can make pool-token balance fall below `vaultLpReserve` without a vault mock or storage write. Low confidence it can. The named-error edit does not wait on that proof.
- Whether a hermetic Aave pool can book aToken through a normal deposit, or only through donation plus end sync. The test may use donation plus a completed production route. That does not attribute the donation to a depositor.
- Whether Apex008's current legs are already non-unit ERC-4626 SEs. The file exists. The rounding precondition may still have to be added. Not a product question.
- Error identifiers for RC-08 (`ZapOutBackingShortfall`, `InsufficientLpBacking`, `PassThroughBackingDeficit`, `InsufficientLPBacking`) are implementer names. The requirement is a named error with both values. Selector comes from `scripts/foundry/ComputeNatSpecValues.s.sol`, not a hand value.
- No dissent remains on including booked aToken, forbidding `try`/`catch`, deleting the unused HookTarget `exchangeOut`, or not demonstrating RC-01 extraction.

## Evidence limits

No Forge run. No installed compiler observation. Audit PDF not read. D16 membership line in the older remediation PRD was truncated at 2000 characters in the first pass and was not re-read in full here. Peer text was not treated as permission to change product law. Consensus is not proof of security or economic soundness.

Moderator consolidation remains `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md`.
