# Kimi K3 — independent first-pass review: APEX 2026-09-17 remediation

- **Reviewer:** Kimi K3 (review-council-kimi), independent first pass.
- **Date:** 2026-09-25.
- **Target:** current working-tree production source implementing the APEX 2026-09-17 remediation in `daosys/lib/indexedex`.
- **Documents read:** PRD (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.md`), implementation plan (`...plan.md`), follow-up record (`apex-2026-09-17-followup-fixes.md`), `CLAUDE.md`. The audit PDF (`APEX-IndexedEx-Audit-2026-09-17.pdf`) **could not be read by this model (no PDF input support)**; audit-finding contents were therefore evaluated through the PRD's recorded descriptions and checked against current source. All PDF-internal claims are treated as unverified claims.
- **Skill files:** the two assigned SKILL.md paths were not separately re-read in this pass; the trust-flag / E6 refund rules they encode were evaluated through the PRD's R5–R13 requirements and the code. Flagging this as reduced evidence, not a bypass.
- **Execution:** no `forge`, no shell, no chain reads. Test-count claims in the plan/follow-up (34,909 tests, 33 campaigns, fuzz counts) are unverified claims, not proof. I read production source and a limited set of test/stub file names only.

## Method summary

Searched the production tree for the unsafe patterns listed in the assignment: deployed/pool valuation subtracted from a stored reserve; whole-balance/self-share refunds; exact-input refunds; over-maximum exact-out refunds; missing contract-caller checks on pretransfer credit; `keepBalance == 0` sites (`_refundOrAbsorbAbove`); `try`/`catch` in D16 families; share mint priced against backing that includes the incoming credit; hook face-custody payouts of pre-existing face; double-booking of face and SE shares; D32 surfaces opened to public pretransfer.

Confirmed at the inventory level:

- No `try`/`catch` remains in D16 SE-family, hook (`standardExchange/`), DETF, or Balancer buffer-pool production source. Remaining `try` sites are in explicitly excluded trees: non-SE swap hooks (`hooks/uniswap/v4/{orbital,weighted,stable/quad/*}`), TWAP oracles, `TokenStakingTarget.sol`, the preserved `contracts/protocols/dexes/uniswap/{v3,v4}/` trees, and TestBase/stub files.
- `_refundOrAbsorbAbove` and `_absorbDustToFeeTo` no longer exist anywhere in `contracts/`.
- `LocalCreditLib` exists with `available` / `budget` / `requirePretransferCaller`; `EOAPretransferNotAllowed()` is declared on `ISecurePullErrors.sol:16` and enforced through `BetterAddress.isContract` (extcodesize) — constructor callers rejected, EIP-7702/contract wallets pass (the recorded D44 accepted residual).
- The R13 Crane NatSpec edit is present on `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:63` (dirty-tree edit as specified by D13/D21).
- The preserved V3 tree still contains the vulnerable `storedTotal - deployed` delivery accounting (`UniswapV3StandardExchangeCommon.sol:865-867`), i.e. it was **not** edited as "the fix" — correct per the PRD.
- D41 (`UniswapV4SeBufferHookLegLib.sol:126-143`) and D48 (`StandardExchangeRateProviderFacet.sol:148-162`, `WrappedStandardExchangeRateProviderTarget.sol:107+`) staticcall rewrites are present with no `try`/`catch`.
- `ReceiptBackedERC4626{Target,Facet,AccountingLib}.sol` exist (D45); `AtomicPretransferCaller.sol` / `AtomicPretransferConstructorCaller.sol` stubs exist (D27); `docs/audits/apex-2026-09-17-evidence.md` exists.

## Findings

### K3-1 — Stale NatSpec on ERC-4626 exact-out target promises dust-to-feeTo, contradicting D6

- **Severity:** Low
- **File/line:** `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol:17-20`
- **Intended behavior:** PRD D6 — every protocol residual, dust included, is retained as book or buffered for holders; the fee recipient receives only explicit fees. The family Common (`ERC4626StandardExchangeCommon.sol:36-37`) already records `MAX_DUST_WEI` as test-only.
- **Broken requirement/invariant:** documentation invariant vs decided law. The header comment still states "unrefundable residual ≤ MAX_DUST_WEI → feeTo when non-zero". No code path performs that transfer (grep-verified), so this is a spec/comment defect, not a live payout.
- **Impact class:** spec nonconformance / accounting clarity
- **Fix direction:** rewrite the header NatSpec to the D6/D15 rule actually implemented.
- **Confidence:** high
- **Evidence label:** observed fact

### K3-2 — Stale "pull overshoot refunded" comments contradict the implemented revert-on-overshoot rule

- **Severity:** Low
- **File/line:** `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:207` (comment "Pull overshoot is refunded immediately (D38)") vs the code at `:220-226` which reverts `TransferDeltaInsufficient(amountIn, delta)` on any pull delta not equal to `amountIn`; also `ERC4626StandardExchangeInTarget.sol:126` ("Pull overshoot already refunded in _securePull").
- **Intended behavior:** D15 — exact-input pull: measured `actualIn` must equal `amountIn` or revert `TransferDeltaInsufficient`; never refund.
- **Broken requirement/invariant:** comments describe the removed pre-remediation behavior; code implements D15. Auditors reading the comments will mis-predict behavior.
- **Impact class:** accounting clarity / spec nonconformance
- **Fix direction:** correct or delete the two comments.
- **Confidence:** high
- **Evidence label:** observed fact

### K3-3 — `BasicVaultCommon` availability/refund math is not routed through `LocalCreditLib`; raw subtractions revert on a book deficit instead of yielding zero credit

- **Severity:** Medium (spec nonconformance) / Low (practical impact, see reachability note)
- **File/line:** `contracts/vaults/basic/BasicVaultCommon.sol:34-36` (`_unbookedSurplus` = `balanceOf - reserveOfToken`, checked subtraction), `:98` (`uint256 U = B0 - R` in the base `_secureTokenTransfer`), `:128` (`_refundExcess` custody bound reads `_unbookedSurplus`).
- **Intended behavior:** PRD R9 — "Route every D16 production-change consumer through the library"; "`available` … A deficit authorizes zero new credit and cannot trigger a fallback that returns the entire balance." `LocalCreditLib.available` floors a deficit at 0.
- **Broken requirement/invariant:** on a deficit (`balance < book`) these sites revert with `Panic(0x11)` instead of computing zero availability. The base `_secureTokenTransfer` also lacks the EOA guard and the library call.
- **Reachability (inference):** all four `BasicVaultCommon` heirs in D16 (Uni V2 `UniswapV2StandardExchangeCommon.sol:420-448`, Camelot `CamelotV2StandardExchangeCommon.sol:158+`, Aerodrome `AerodromeStandardExchangeCommon.sol:946-974`, Stata `AaveV3StataStandardExchangeCommon.sol:200-228`) override `_secureTokenTransfer` with guarded, library-based versions, so the base pretransfer branch is unreachable today. `_refundExcess`/`_unbookedSurplus`, however, is live on the Uni V2 / Camelot / Aerodrome exact-out refund paths (via each family's `_refundExactOutCredit`). Those routes hold `reserve <= balance` by construction at refund time (the refund is custody-bounded precisely to avoid paying booked inventory), so a deficit would indicate an already-broken invariant; the observable effect would be a liveness revert with an opaque panic rather than a value payout.
- **Impact class:** error handling / spec nonconformance
- **Fix direction:** implement `_unbookedSurplus` (and the base pull helper) via `LocalCreditLib.available`, or explicitly document and test the `reserve <= balance` invariant at every `_refundExcess` call site.
- **Confidence:** high on the code/spec mismatch; medium on impact
- **Evidence label:** observed fact (code) + inference (reachability)

### K3-4 — Bare `revert()` with no error in the Uni V2 pass-through zap-out backing check

- **Severity:** Low
- **File/line:** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:578-580` (`if (indexSource.pool.balanceOf(address(this)) < vault.vaultLpReserve) { revert(); }`)
- **Intended behavior:** R2/R14 require negative paths to raise the precise intended error; every other short-funding path in this family uses named errors.
- **Broken requirement/invariant:** opaque revert with no diagnostic; inconsistent with the family's error discipline.
- **Impact class:** error handling
- **Fix direction:** raise a named custom error (e.g. an insufficient-LP-backing error with the two quantities).
- **Confidence:** high
- **Evidence label:** observed fact

### K3-5 — FullSpread README documents pre-D17 pull semantics that the code no longer implements

- **Severity:** Low
- **File/line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md` ("Pull semantics remain route-specific: V3 token exact-out pulls its quote plus the existing capped buffer; V4 pulls max. Dual exits pull max shares and refund unused shares.")
- **Intended behavior:** D15/D17 — false-flag exact-output pulls quoted `used` and refunds nothing; dual-exit pulls `sharesToBurn`, not `maxAmountIn`.
- **Broken requirement/invariant:** R13 requires updating docs that state the pull-max-then-refund rule. Current code implements D17 (`UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:80` pulls `quotedIn`; `UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:59` pulls `estimatedAmountIn`; `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:37` pulls `sharesToBurn`), so the README is stale. (The sibling law file `uniswap-se-v2-liquidity-leak-fixes.md:14` was amended correctly.)
- **Impact class:** spec nonconformance (documentation)
- **Fix direction:** amend the README pull-semantics paragraph to the D15/D17 rule.
- **Confidence:** high
- **Evidence label:** observed fact

### K3-6 — Stata SE-side backing (`_stataBacking`) omits booked aToken while the shared ReceiptBacked adapter counts it

- **Severity:** Medium (conditional impact)
- **File/line:** `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:52-58` (`_stataBacking` = held Stata + `convertToShares(booked underlying)` only) vs `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:187-198` (`_totalReceiptBacking` adds `_bookedATokenEquiv`, the booked reserve of every vault token that is neither receipt nor underlying).
- **Intended behavior:** R14/D45 — "Stata also counts any already-booked local aToken value at its underlying-equivalent accounting value", in the *shared* backing calculation used by the adapter **and** the family's SE Common / SY rate / transition-quote code.
- **Broken requirement/invariant:** the SE-side conversions (`_convertSharesToStata`, previews, transition quotes via `StataQuoteState.stataShares = _stataBacking()`) and the IERC4626 adapter disagree on total backing whenever a booked aToken reserve exists, so share entitlement and quotes diverge across interfaces of the same proxy.
- **Reachability (inference):** the aToken input route calls `depositATokens`, which consumes the aToken input fully (`AaveV3StataStandardExchangeInTarget.sol:89-91`), so booked aToken may be unreachable through supported routes; it could still arise if an aToken balance is ever held at an end-of-route `_syncAllExpectedHoldReserves` (which books every registered vault token to balance, including unsolicited transfers).
- **Impact class:** value accounting (cross-interface consistency)
- **Fix direction:** include booked aToken in `_stataBacking` at its underlying-equivalent accounting value (same convention as `_bookedATokenEquiv`), or document and regression-test that a booked aToken reserve is impossible on every route.
- **Confidence:** medium (the spec/code asymmetry is an observed fact; the reachability of a nonzero booked aToken is inference)
- **Evidence label:** observed fact + inference

### K3-7 — Stata Aave LM rewards are forwarded to `feeTo` on every operation

- **Severity:** Informational
- **File/line:** `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:182-198`
- **Intended behavior:** unspecified (pre-existing, documented in-code as "temporary behavior").
- **Broken requirement/invariant:** none identified — D6 governs user-principal residuals, not third-party protocol incentives; the flow is explicit and was not an APEX remediation item. Recorded so external auditors see the economics: holders do not receive Aave liquidity-mining rewards earned on the vault's position.
- **Impact class:** token integration / accounting clarity
- **Fix direction:** none required for this remediation; if unintended, route rewards to holders or document the fee treatment in the family PRD.
- **Confidence:** high (behavior exists); no defect claimed
- **Evidence label:** observed fact

### K3-8 — Accepted residual confirmed in code: non-atomic contract pretransfer (D12) is consumable by any later contract caller

- **Severity:** Informational (accepted residual per PRD, not a defect)
- **File/line:** e.g. `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:426-434` (any unbooked balance creditable by any contract caller); `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2074-2079` (all buffered-leg face treated as unbooked credit); custody `RebasingAwareStandardExchangeTarget.sol:119-120`.
- **Intended behavior:** D12/D28 — staged pretransfer is permitted at integrator risk; the next contract caller may consume resting unbooked credit; booked inventory is never paid out.
- **Broken requirement/invariant:** none — matches the latest recorded owner ruling and the R13 NatSpec on `IStandardExchangeOut.sol:63`. Recorded so the external handoff does not misclassify it.
- **Impact class:** access control (accepted limitation)
- **Fix direction:** none; keep the NatSpec and integration-notes documentation.
- **Confidence:** high
- **Evidence label:** observed fact

## Confirmed remediated sites (no defect found)

- **LocalCreditLib / ISecurePullErrors:** `contracts/utils/LocalCreditLib.sol:14-28`, `contracts/interfaces/ISecurePullErrors.sol:13-16` — arithmetic and guard match R9/D9/D11.
- **ERC-4626 SE:** `ERC4626StandardExchangeCommon.sol:106-122` (D31 reserve-first sweep + capacity re-read), `:213-235` (guarded secure pull, exact-in no-refund), `:251-265` (`credit - used` exact-out refund, false-flag pulls exactly `used`), `:267-294` (self-share exact-out credit/burn/refund; bookedSelfShares = 0 verified via DFPkg vaultTokens at `ERC4626StandardExchangeDFPkg.sol:207-211`); In/Out targets price share mints against backing that excludes the incoming credit (`ERC4626StandardExchangeInTarget.sol:104-109,122`, `ERC4626StandardExchangeOutTarget.sol:78-84,128-139`); receipt exits are inventory-gated (`:159-161`, Out `:100-101`); local-cash-first underlying payout (`Common.sol:82-92`); QuoteState carries `localUnderlying`/`receiptBacking` (`ERC4626StandardExchangeQuoteTarget.sol:57-58,112-133`); no `try`/`catch`.
- **ReceiptBacked adapter (D45):** `ReceiptBackedERC4626Target.sol:173-198` (ERC-165 marker dispatch, both/neither rejected), `:105-171` (nonReentrant money paths, pre-credit backing snapshots, receipt-inventory-bounded exits, end-of-op full-set reserve sync); rounding directions in `ReceiptBackedERC4626AccountingLib.sol:23-57` are standard (floor deposit, ceil withdraw/mint).
- **Morpho Blue SE:** `MorphoBlueStandardExchangeCommon.sol:165-187` (guarded pull, overshoot reverts), `:263-280` (exact-in prices against NAV excluding the credited pretransfer), `:282-318` (exact-out excludes the full bounded credit incl. refund; `TransferDeltaInsufficient(amountIn, credit)` on short funding; refund `credit - used`), `:339-370` (self-share exact-out credit = `budget(available(selfBal,0),max)`; refund `shareCredit - sharesIn`). The reported line-181 exact-in overshoot refund is gone.
- **Uni V2 / Camelot (D35):** pre-consumption `credit = budget(available, maxAmountIn)` and `used > credit` revert at `UniswapV2StandardExchangeCommon.sol:464-477` / `CamelotV2StandardExchangeCommon.sol:202-214`, called before input consumption at e.g. `UniswapV2StandardExchangeOutTarget.sol:456-461,541,618-620,688-697` and Camelot `:411,510,593,660,758`; self-share book verified absent (DFPkg vaultTokens = [LP, token0, token1], `UniswapV2StandardExchangeDFPkg.sol:584-587`).
- **Aerodrome V1:** guarded pull/self-burn and bounded credit at `AerodromeStandardExchangeCommon.sol:946-1003`; exact-out self-share refund via `_refundExcess(self, maxAmountIn, used, …)` is custody-bounded by the post-burn unbooked self-balance, which is algebraically `credit - used` (`AerodromeStandardExchangeOutExecuteTarget.sol:267,371`).
- **Slipstream (deprecated per D57):** `_executeZapOutWithdrawal` no longer uses the always-zero same-tx inbound delta; uses `budget(selfBal, maxSharesToBurn)` with guard, self-burn, and `credit - sharesBurned` refund (`SlipstreamStandardExchangeOutTarget.sol:178-191`).
- **Rebasing custody (003):** asset pretransfer still rejected; share exact-in burns exactly `amountIn` from self with EOA guard and no refund (`RebasingAwareStandardExchangeTarget.sol:77-93`, `RebasingAwareERC4626Common.sol:309-326`); share exact-out credits `budget(available(selfBal,0),maxAmountIn)`, reverts `TransferDeltaInsufficient(needed, credit)`, refunds `credit - burned` (`:117-138`); external SY `redeem(burnFromInternalBalance=true)` guarded (`RebasingAwareStandardYieldTarget.sol:57-58`); false-flag exact-out burns exactly `sharesForWithdraw` (`RebasingAwareERC4626Common.sol:443-455`).
- **FullSpread V3/V4 (001-M replacement):** delivery is booked-ERC20-only (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:852-873`, `UniswapV4FullSpreadStandardExchangeVaultCommon.sol:1219-1240`) — no `deployed` term; EOA guard on pretransfer; V3 token exact-out pulls quoted `used` (`OutExecuteTarget.sol:80`), V4 pulls quoted `estimatedAmountIn` (`OutExecuteTarget.sol:59`); dual-exit pulls `sharesToBurn` (`OutMultiTarget.sol:37-57`, V4 equivalent); D55 pads removed (`OutBase.sol:116-120`, `InQueryTarget.sol:264-268`, V4 `Common.sol:214-218`); zap-out pays exactly the requested amount and books the surplus (`OutExecutionDelegate.sol:65-68`, V4 `:78-81`); exact-out mint prices on a reserve basis excluding the bounded prepaid credit (`OutBase.sol:42-51`); Native SY internal holder-burn context preserved (`Common.sol:907-914`).
- **Preserved V3/V4 trees:** still contain the reported `R - deployed` delivery accounting (`UniswapV3StandardExchangeCommon.sol:865-867`) — not edited as the fix, as required. Live instances are not claimed remediated.
- **Orbital hook (008):** delta-based `_refundConservation` against an opening face snapshot (`Common.sol:2001-2025`) — resting face is never refunded; `_refundBufferedDust` deleted; `_unwrapExactTokenOut` uses SE exact-output bounded by the spendable-share cap with the approve/reset pattern and a balance-delta check (`:550-566`); `_securePull`/`_pullExactOutInput` implement the guard and `credit - used` (`:2040-2070`); custody-aware `_unbookedBalance` (`:2074-2079`); `beforeSwap` takes exactly `amountIn` and settles exactly `amountOut` with no raw transfer to the PoolManager (`HookHooksTarget.sol:272-320`).
- **Other hook families (D36/D9):** weighted `_refundBufferedDust` (`WeightedBufferHookTarget.sol:611-623`) and dual-CP `_refundPairDust` (`DualStandardExchangeBufferConstantProductHookCommon.sol:435-446`) no longer transfer post-buffer remainder; Balancer-quad and the four single-CP `_refundPairDust` copies retain remainder; non-CP `single/` hard-codes `pretransferred=false` on its SE calls (`UniswapV4SingleStandardExchangeBufferHookTarget.sol:201-244`) so no guard is required there; guards present on the six pretransfer-crediting families.
- **Staking SEs:** Lido D47 (`LidoWstETHStandardExchangeInTarget.sol:121-144`, capacity precheck `Common.sol:476-477`); Rocket D39/D42 (`RocketPoolRETHStandardExchangeCommon.sol:189-207,445-459,500-515`); EtherFi D40 four-staticcall precheck and sleeve-preserving stake (`EtherFiWeETHStandardExchangeCommon.sol:470-491,704-721`); all former `try`/`catch` sites removed.
- **Aave Cross-Version Loop (D32):** public pretransfer rejects preserved (`AaveCrossVersionLoopExchangeInTarget.sol:47`, `AaveCrossVersionLoopExchangeBase.sol:195`, `OutTarget.sol:72`).
- **Balancer:** `BalancerV3PoolStandardExchangeTarget.sol:123` keeps `UnsupportedPoolPretransfer()`, preserves the self-call internal-SY path (`:136-137`), and false-flag exact-out pulls exactly the previewed `used` (`:128-131`); `BalancerV3SinglePoolStandardExchange.sol:154-193,229-259` implements guard + `budget` credit + `credit - used` refund + exact-used false-flag pull; native BPT issuance preserved (D38).
- **DETF:** guards on UniV4 DETF entries (`UniswapV4DetfTarget.sol:207,701`, `UniswapV4DetfCommon.sol:392`), bond prepaid pull (`DETFFundedBondTarget.sol:400`), StakedDETF (`StakedDETFTarget.sol:202`), MixedBuffer / MultiVaultWeighted / Single SE / Composed / Rebasing claim token surfaces, with bounded-credit refunds on exact-out routes (e.g. `ComposedStableCommonDetfExchangeOutQueryFacet.sol:49-70`, `RebasingDETFTokenTarget.sol:240-247`); unstake route keeps its hard pretransfer reject (`UniswapV4DetfTarget.sol:215`).

## Audit disposition table

PDF unreadable by this model (recorded above); dispositions are against current source using the PRD's recorded claim descriptions.

| Finding | Disposition | Evidence (file:line read) |
| --- | --- | --- |
| APEX-2026-001-M | Still present in the preserved historical source by design (`contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol:865-867`); refuted in the current FullSpread replacement source (`contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:852-873`, `.../v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol:1219-1240` — booked ERC-20 only, no `deployed` term, EOA guard). Live instances not claimed remediated. | see citations |
| APEX-2026-001-M2 | Unverified. Instance inventory / historical replay requires chain reads at block 64025200 that I cannot perform; the evidence file exists (`docs/audits/apex-2026-09-17-evidence.md`) but I did not validate its fork runs. No separate arithmetic defect exists in source. | n/a |
| APEX-2026-003 | Refuted in current source. `RebasingAwareStandardExchangeTarget.sol:83-93` (exact-in burn-exact, EOA guard), `:117-138` (exact-out `credit - burned`, `TransferDeltaInsufficient`), `RebasingAwareERC4626Common.sol:309-326` (`takeShares`), `RebasingAwareStandardYieldTarget.sol:57-58`. Live custody vault exposure is recorded in the PRD as immutable and is not claimed fixed. | see citations |
| APEX-2026-008 | Refuted in current source. `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2013-2025` (delta-only refunds vs opening snap), `:550-566` (capped unwrap via SE exact-output), `:2040-2079` (guard + bounded credit); `_refundBufferedDust` absent tree-wide. | see citations |
| APEX-2026-009 | Refuted in current source. `ERC4626StandardExchangeCommon.sol:267-294`, `MorphoBlueStandardExchangeCommon.sol:339-370,206-217` — burn exactly used, exact-out refund `credit - burned`, short funding `TransferDeltaInsufficient`. | see citations |
| APEX-2026-004B | Refuted in current source. `_refundOrAbsorbAbove` / `keepBalance == 0` absent tree-wide; exact-in routes never refund; under-consumed underlying is booked and swept reserve-first (`ERC4626StandardExchangeCommon.sol:106-122`, `AaveV3StataStandardExchangeCommon.sol:64-83`). | see citations |
| APEX-2026-005 | Refuted in current source with one reservation. `LocalCreditLib` exists and is routed through the D16 families; reservation: `BasicVaultCommon` internals (`_unbookedSurplus`, base `_secureTokenTransfer`, `_refundExcess`) are not library-routed and revert on book deficit (finding K3-3). | `contracts/utils/LocalCreditLib.sol:14-28`, `BasicVaultCommon.sol:34-36,77-103,120-135` |
| `beforeSwap` guard claim (withdrawn) | Consistent with the withdrawal. The orbital hook retains its real guard (`_onlyPoolManager`, `UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol:277`); no redundant guard was added. | see citation |
| Weighted dust claim (downgraded) | Consistent with the downgrade; behavior now matches D36 — buffer-first retained, post-buffer transfer removed (`UniswapV4StandardExchangeWeightedBufferHookTarget.sol:611-623`), unconvertible remainder stays as D12 credit. | see citation |

## Facts vs inference vs speculation

- **Observed facts:** every file:line citation above; the presence/absence of `try`/`catch`, `_refundOrAbsorbAbove`, `_absorbDustToFeeTo`, guards, credit/refund formulas; the stale comments in K3-1/K3-2/K3-5; the `_stataBacking` asymmetry in K3-6.
- **Inference:** reachability assessments in K3-3 (deficit unreachable when routes hold `reserve <= balance`) and K3-6 (booked aToken may be unreachable through supported routes); the algebraic equivalence of Aerodrome's custody-bounded refund to `credit - used`.
- **Speculation:** none relied upon for any finding. All test-count, campaign, fork-replay, and "independent completion" claims in the plan/follow-up are treated as unverified claims; I could not execute Foundry or read the chain. The audit PDF's internal contents are unverified because this model cannot read PDF input.

## Unverified claims / missing evidence

- Plan/follow-up test counts, red/green logs, matrix results, and historical fork reproduction at block 64025200 — not executed or re-performed here.
- D44 EIP-7702 and contract-wallet acceptance controls — fixtures exist (`AtomicPretransferCaller.sol`, `AtomicPretransferConstructorCaller.sol`); the delegation tests themselves were not read line-by-line.
- Whether every one of the 34 D37-inventoried files had its mapped now-unused errors deleted (e.g. `SeInvertUnavailable`, `InvalidSE`) — not exhaustively re-derived.
- The two assigned adversarial-testing SKILL.md files were not re-read in this pass (noted in the header).

End of review.
