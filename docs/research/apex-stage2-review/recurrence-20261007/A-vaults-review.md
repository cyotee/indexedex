# A-vaults recurrence verification

Status: SOURCE_REVIEW_IN_PROGRESS / VERIFICATION_ADDITIONS_READY. Stage 1 remains accepted and complete. Production sources and prior findings are preserved. Tests below were added for the authorized recurrence investigation; no production repair was made. This is a run handoff, not completion of the requested repository-wide recurrence review.

## Coordinator run handoff

The collaboration message tool returned `agent thread limit reached` when sending this handoff. Six new test files are ready for the coordinator's serialized build/run:

- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/ApexRecurrenceExactErrors.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/ApexRecurrenceConsumerConservation.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/ApexRecurrenceInvariantWitness.t.sol`

Match contracts `.*ApexRecurrence.*`; deterministic tests use `^test_review_`. Run `WingsApexRecurrenceInvariantWitnessTest` as an invariant campaign separately. All deployments use existing production TestBases/factory/registry paths; new doubles are external callback observers only. Existing full-build production artifacts suffice; added test compilation is required. No reviewer-run forge process exists.

Tests currently have **not** been compiled or executed. Native SY tests assert observed successful unguarded EOA redemption as a diagnostic reproduction; a green diagnostic is evidence of the missing D9 guard, not conformance. Error-order diagnostics similarly expect the actual credit error and compare it with the independently cited rule.

## Findings being verified

1. Native SY internal-balance redemption: generic `NativeStandardYieldTarget.redeem` does not require the initiating caller's bytecode before self-calling a false-flag standard exit. V3 OutQueryTarget, Hookless/Pons OutMultiQueryTarget and Wings SYTarget inherit the adapter. V3 Common `_secureShareDelivery` at 908 and Hookless/Pons at 952 deliberately accept self-held shares whenever the initiator is nonzero, without checking its bytecode. Wings Money false-flag redemption burns the proxy's own shares. Added all-four-family actual payout probes. Parent coordinator identified this root cause; this lane verifies vault variants. Runtime pending.
2. A-F01 error precedence remains specified by D9/R13.1–2 and indexedex-testing mandatory negatives. Historical disclosure is not a waiver. No policy ruling is necessary to test compliance with current text; a ruling is needed only to accept/change the required diagnostic.
3. A-F02 exact-error gaps: new probes assert inbound/outbound transfer-delta errors, pause/blacklist wrapper error, backing-deficit arguments, exact reentry errors through a callback observer, donation/zero-share rejection, and rollback.
4. A-F03 vacuity: new separate campaign asserts actual seed mint, pool price movement, core-liquidity rebalance progress and paid exit, then `afterInvariant` requires additional successful deposits and withdrawals during fuzzing. Original tests remain untouched.
5. C006: separate five-family consumer suite now measures shares actually returned, exact holder/consumer share conservation, unchanged Wings total supply and no opposing-currency delivery. Original tautological assertion remains untouched for attribution.
6. NEW source-supported candidate: V3 direct token-to-token exact-output does not enforce requested output fill. `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:253–279` discards the quoter's `fullyFilled`/actual-output result and `:500–526` checks only input consumption after pool.swap; OutExecuteTarget `_executeQuotedSwapOut` checks input delivery then returns. Crane `contracts/utils/math/UniswapV3Quoter.sol:141–157` expressly returns partial quotes at the price limit. Added `test_review_directExactOutCanReportSuccessWithPartialOutput` on the real V3 pool requesting more than its output custody, with funded input and exact input/output balance observations. Runtime pending; do not yet report a reproduced failure. H/P strict inverse/planner fill checks are counterevidence against treating this as an all-four-family defect.

## Source-review progress

Full Wings money, common/callback, accounting, inventory, geometry, repository/types, harvest, liquidation quote, projection, in/out/query/economic/SY/transition, rebalance planner/target and DFPkg bodies inspected. H/P normalized-source comparison identifies shared bodies versus separate admission, Pons fee treatment and composition planning; shared-body inspection is ongoing. Full V3 source review is ongoing. No exhaustive completion claim is made while this status remains IN_PROGRESS.

Full Wings inspection now includes all 32 production Solidity files in `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` (excluding its test base): all facets, interfaces and factory service were additionally read. Reviewed admission rejects native currency and hooked underlying pools, requires sorted deployed ERC20 currencies, initialized bound-manager pool and target0/target1; outer same/different-manager consumers remain legal. No newly established Wings production root cause beyond inherited Native SY caller authentication emerged from this body review. This does not prove economic safety for every state or replace the missing matrix execution.

The following additional complete code bodies were read in this continuation (prefixes denote exact repository filenames, not a claim to every sibling):

- V3 root `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault`: `Common.sol`, `InBase.sol`, `InTarget.sol`, `OutBase.sol`, `OutExecuteTarget.sol`, `OutExecutionDelegate.sol`.
- Hookless root `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault`: `Common.sol`, `InBase.sol`, `InTarget.sol`, `InMultiTarget.sol`, `InQueryTarget.sol`, `OutBase.sol`, `OutExecuteTarget.sol`, `OutExecutionDelegate.sol`, `OutMultiTarget.sol`, `PositionImportTarget.sol`, `ExecutionContextRepo.sol`, `TransitionPlanner.sol`, `InventoryMath.sol`, `ProtectionMath.sol`, `QuoteService.sol`.
- Pons-specific `UniswapV4FullSpreadPonsFamilyHookFeeService.sol`; all paired top-level H/P files were read programmatically for a normalized exact-body comparison, and every emitted semantic difference was inspected. Normalization only replaced family identifiers and their folder prefixes; Pons differences include fixed singleton/registration checks, fee additions, and its separately bounded composition search. This comparison supports shared-root-cause propagation; it is not claimed as an independent proof of all Pons math.
- Shared `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` in full, `contracts/interfaces/IStandardExchangeTransitionQuote.sol` in full; Crane `contracts/utils/math/UniswapV3Quoter.sol:70–300` and `contracts/tokens/ERC20/utils/SafeTransferLib.sol:319–337` supporting partial-fill and exact-wrapper-error reasoning.
- Actual new tests' inherited setup and assertions: V3 ReserveReconcile, Hookless/Pons Acceptance, Wings TestBase/Rebalance/Invariant/Security/Tokens/FamilyConsumers/WeightedConsumer/Economic; relevant original test source as cited in the accepted first-wave report remains evidence with its original scope limitations.

Still uncompleted in this continuation: independent full analytic-composition and analytic-swap arithmetic review, the remaining V3 declaration/query/import/package siblings, a full fresh binding inventory, test compilation/execution, runtime classification of new probes, full legal Wings matrix execution and network receipt/gas evidence. The coordinator must not flatten these items into verified. Source readings from the earlier accepted report supplement this list but do not imply all fresh changed bodies were re-reviewed.

## New source-supported finding records pending runtime

### A-R01 — native SY external caller escapes the pretransfer bytecode gate

- Attribution: coordinator identified generic cause; A-vaults traces V3/Hookless/Pons/Wings variants.
- Classification: CODE_DEFECT / root-cause recurrence in newly added adapter / proposed Medium / high source confidence, runtime pending.
- Authority: original plan D9 at :99 includes external SY internal balance. R13.1 :577 and R13.2 :578 require the initiating EOA rejection and exact-error controls. These vaults' generic adapter preserves original payer for normal exits but replaces the initiating caller with the proxy for internal-balance exits.
- Actual: `NativeStandardYieldTarget.sol:33–70` neither invokes `requirePretransferCaller` nor checks caller bytecode. FullSpread's common delivery helper checks only a nonzero transient initiator and sufficient self-held shares. Wings' inherited route burns the proxy's shares without a corresponding external-caller check.
- Impact/precondition: self-held shares previously delivered to the vault can be redeemed for backing by a code-less external caller. This is not authority to burn a third party's wallet-held shares. The accepted D12 ability of integrating contracts/delegated wallets to consume unattached pretransfer credit is material counterevidence against claiming novel universal theft; the specific EOA gate is nevertheless absent.
- Verification: four `test_review_eoaInternalSyRedeemConsumesSelfShares` diagnostic cases require a real funded portfolio, code-less caller, positive payout, exact recipient delta, zero remaining pretransferred shares and supply reduction. Current execution is UNVERIFIED.
- Readiness: retain open until current runtime evidence and explicit disposition; no repair or policy change made. No owner ruling is required merely to enforce existing D9. If the intended new native adapter is explicitly exempt, that exemption must be recorded rather than inferred from self-call mechanics.

### A-R02 — V3 direct exact output ignores partial fill

- Classification: CODE_DEFECT / newly identified original-family recurrence candidate / proposed Medium / high source confidence, runtime pending.
- Authority: exact-output route promises requested output with a caller input maximum; APEX R3.6/D55 exact-output economics. Unlike an exact-input trade, an output shortfall must not be returned as successful fulfillment.
- Actual/location: V3 Common `_quoteSwapOut` :253–279 returns only quote input; `_swapExactOut` :500–526 checks maximum spent input but not the negative output delta. OutExecuteTarget :68–100 checks credit and spend but never verifies output against `amountOut`. Crane Quoter :141–157 intentionally returns partial output and `fullyFilled=false` when the directional price limit stops execution.
- Reachability/precondition: initialized finite-liquidity pool and requested output beyond remaining pool inventory. The pool can accept partial exact-output fills at its price limit; the vault's current code does not reject that result. No stolen third-party reserve is asserted.
- Counterevidence: ordinary small exact-output requests are filled; V3 SE-share exact-output withdrawal checks realized output separately. H/P exact-output quotes require exact amount and strict one-step domain, and verify execution, so this is not generalized to them or Wings.
- Verification: `test_review_directExactOutSupportedControl` asserts a normal exact-output payout. `test_review_directExactOutCanReportSuccessWithPartialOutput` requests above the real pool's output custody, funds quoted input, and measures actual used/paid values. Both are diagnostic production-first tests, currently UNVERIFIED.
- Readiness: do not claim reproduction or close until the coordinator's serialized execution. Corrective objective is to reject incomplete exact-output quote/execution; production remains unchanged.

## Verification provenance and constraints

Only the six new `ApexRecurrence*.t.sol` files and this report were created/updated by this lane in the continuation. Existing dirty test edits were preserved. No forge/build was run by this reviewer, following coordinator serialization. Source assertions and proposed severities are not substitutes for execution logs. Tests may reveal fixture/domain errors and must be triaged without weakening the economic assertions or editing production to hide failures.
