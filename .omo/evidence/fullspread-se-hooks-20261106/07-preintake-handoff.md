# Task 7: CP SINGLE strict pre-intake source handoff

Date: 2026-11-07.

Status: source-complete handoff only. No build, test, runtime, gas, deployment,
or task-wide completion claim. Parent owns runtime validation.

## Authority and interpretation

Read `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and its coding, deployment and
testing documents; the authoritative FullSpread PRD FS-HOOK-05 through
FS-HOOK-10; and task 7 plus its accounting contract in
`.omo/plans/fullspread-se-hooks-implementation-testing-20261106.md`.

The current instruction resolves the snapshot choice: incumbent books and
actual LP supply remain unchanged throughout caller basket assembly. Paying
the hook for incumbent components before taking a later ownership snapshot is
not an accepted join implementation.

## Source changes

Production directory:
`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`.

For the first six filenames below, prepend
`UniswapV4SingleStandardExchangeBufferConstantProductHook`.

| Filename suffix | Change |
| --- | --- |
| `ClaimLib.sol` | Removed `_singleTrade`. Single-input execution and preview use the literal component book and caller-only input. Pair/share input may use the existing caller-only SE assembler when no raw contribution is required. All positive pre-intake components limit gross LP. Exact-net still grosses up the fee and caps acceptance against that original book. No join emits a fictitious incumbent `ZapSwap`. Claim-after-join returns zero for an impossible raw-only mint; split preview reports no incumbent sale. Share-based composed projections retain the original book and redeem only caller shares for local contribution. |
| `DepositCommon.sol` | Existing-supply dual/share routes permit zero input quantities and defer feasibility to component acceptance, instead of imposing genesis positive-leg rules. First-join topology is keyed to actual zero supply. Single-input deposits retain the public minimum-supply/owner-floor policy without requiring a two-sided swap-live book for a component join. |
| `DepositPreviewTarget.sol` | Exact-net execution permits existing-supply partial books and explicitly rejects a zero requested output. Positive missing-basket requests still fail before funding. The installed exact-output inverse preview retains its existing zero/unsupported contract. |
| `DepositProjectionTarget.sol` | Unbalanced previews distinguish genesis from existing-supply zero components. `previewJoinAfterDeposit` returns zero when shares alone cannot supply the incumbent raw component, without first invoking an unnecessary SE transition quote. |
| `InExecutionBase.sol` | SE, generic exact-in and SY joins require existing LP supply rather than a two-sided swap-live book; they still use the common component engine, permission policy and reentrancy lock. |
| `InQuoteBase.sol` | Corresponding exact-in join previews use actual supply, allowing supported partial component books rather than blanket zeroing them because swaps are not live. |

Also changed, within the same directory:

- `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol`
- `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals.sol`

Both contain an exact rollback digest of caller/hook custody, component reserve
views, LP supply and balances, underlying share supply/custody, and ERC20
approvals. These are test helpers, not new deployed production selectors.

## Installed facade audit

Inspected `DFPkg.sol` production cuts and the Deposit, DepositSingle,
DepositPreview and Se facet selector declarations, as well as their targets,
PullLib, shared liquidity execution routing and native SY execution.

- ERC20 and Permit2 `depositSingle` aliases reach `_depositSingle`, then
  `ClaimLib.singleComponentJoin`.
- `joinSingleAssetExactIn`, LP-directed `exchangeIn` and native SY `deposit`
  reach `_joinLiquidityExactIn`, then the same component engine.
- `joinSingleAssetExactOut` reaches that engine with an exact-net gross cap.
- Ordinary, proportional, unbalanced and SE-share-funded joins reach
  `ClaimLib.joinComponents`, whose pre-conversion book and supply remain the
  ownership denominators.
- Preview selectors follow component acceptance, including the composed
  share-funded join and raw claim-after-join projections.
- Owner joins do not bypass these engines. Owner swaps, SE swaps and
  PoolManager swaps remain separate trading operations.

The old aggregate `Target.sol` and uncalled legacy zap helpers are not installed
join engines in the inspected package. They were not edited.

## Supported partial books

This is not blanket single-input disablement:

- With `bookedRaw == 0`, caller pair input may acquire SE shares and retain its
  own pair tokens/refunds; caller SE shares may be redeemed in part to supply
  the local component. The remaining caller shares and actual local proceeds
  constrain the common mint.
- With both SE components zero and positive booked raw, raw input can fund the
  whole required basket.
- A zero local component requires no local contribution. A raw-plus-share join
  remains valid without a needless local redemption.
- All-zero backing with outstanding supply still supports no mint through the
  existing shared arithmetic.
- Disabled share requirements still need caller-owned shares. Disabled
  pair-only input cannot manufacture the required share component.

The first two topologies can mathematically support positive exact-net issuance
when the caller basket and fee permit it. Their natural reachability from the
current positive-leg bootstrap was not established here; no SUT storage
injection was added to fabricate a live example. A real zero-local positive
multi-input test was authored instead. The ordinary full three-component book
cannot support any single-input join under this ownership contract.

## Exact tests authored or migrated

Test directory:
`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/`.
Unless otherwise stated, each filename below has prefix
`UniswapV4SingleStandardExchangeBufferConstantProductHook_`.

| File suffix | Exact test names / assertions |
| --- | --- |
| `ComponentAccounting.t.sol` | Added `test_strictPreintake_fullSpread_singleInputFacades_restoreExactState`. Tests raw, pair and preowned-share input through generic exact-in, SE and SY facades; each must return the exact `ZeroAmount()` rejection and preserve the complete FullSpread caller/incumbent/underlying-position/manager snapshot. All corresponding exact-in previews, composed share join and raw claim-after-join must be zero. |
| `Liquidity.t.sol` | Migrated `test_Zi1_depositSingle_bothDirections` to exact full-book rollback, and `test_Zi2_previewZapSplit_sumsToAmountIn` to no incumbent sale. Added `test_zeroLocalBook_shareFundedJoin_preservesRawAndShareFractions`: an ordinary separate swap establishes zero local backing, then a complete caller-funded share/raw join must positively mint with independent ceil component equations and preview parity. |
| `FeeCapital.t.sol` | Migrated `test_singleRawDeposit_missingComponentsMintsNoProtocolFee`, `testFuzz_singleDeposit_afterYield_previewMatches`, `test_singleQuote_minimumAboveOutput_revertsAtomically`, `test_realGrowth_exactOutQuoteDoesNotCountPendingFeeTwice`, and `test_realGrowth_exactOutMissingBasket_rejectsAtomically`. Unapproved post-trade positive expectations are replaced with missing-component/zero-preview/exact-state or pre-funding rejection assertions. |
| `Permit2.t.sol` | Migrated `test_R1b_depositSingleWithPermit2Allowance` to exact custody and Permit2 allowance/expiration/nonce preservation. Added `test_singlePermit2Signature_missingBasket_restoresNonceAndCustody`, using a real signed permit and requiring the component-engine rejection, restored custody and unspent nonce. |
| `SeBufferAbi.t.sol` | Migrated `test_T1_7_afterLive_joinSingleAsset_pairAndShare` to zero previews and exact rollback for both caller pair tokens and preowned SE shares when raw is required. |
| `OwnerDuringLock.t.sol` | Migrated `test_D89_ownerDepositSingle_atMin_requiresCallerBasket` and `test_D89_ownerDepositSingle_atMin_whileUnlocked`. Owner access cannot spend locked-floor components. The former also positively rejoins with a complete raw/share-funded basket. |
| `ZapReserveOrder.t.sol` | Retained all four `test_zapRaw_currency0_independentLpAccounting`, `test_zapPair_rawCurrency0_independentLpAccounting`, `test_zapRaw_currency1_independentLpAccounting`, and `test_zapPair_rawCurrency1_independentLpAccounting` cases. Their independent requirement is now a positive pre-intake raw/share/local book with a missing caller component, zero mint/sale quote and exact rollback. Removed only the obsolete post-trade expectation helpers. |
| `decimals/UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals.sol` | Migrated inherited `test_Zi1_depositSingle_bothDirections` to zero previews and exact native-unit rollback in every existing decimals adapter. |

Positive multi-input/share/bootstrap fee tests remain, including
`test_balancedDeposit_newCapitalMintsExactProtocolFee`,
`test_balancedSeShares_newCapitalMintsExactProtocolFee`,
`test_joinProportional_newCapitalMintsExactProtocolFee`,
`test_joinUnbalancedSeShares_newCapitalMintsExactProtocolFee`,
`test_permit2Allowance_newCapitalMintsExactProtocolFee`, and the liquidity B6
bootstrap/subsequent/share-withdrawal controls.

All original FullSpread matrix swap positives remain untouched and inherited.
The four independent exit-curve cases in `ZapReserveOrder.t.sol` remain
unchanged. Parent's `SeTarget.sol` raw-book fixes and owner swap regression
remain untouched. No tests or behavior inheritance were skipped or removed.

## Static checks and remaining parent work

- Requested read-only Solidity LSP diagnostics with severity `all` on all
  sixteen edited Solidity files: every request returned `No diagnostics found`.
  This is not compiler or runtime evidence.
- Source search confirms `_singleTrade` is absent from the CP SINGLE tree.
- Reviewed edited engine, facade guards, projection and test bodies plus
  installed selector metadata.
- A separate LSP reference request timed out; source tracing supplied the
  caller inventory. No successful LSP reference-graph claim is made.
- No builds, tests, compiler/artifact writers, Git, installs, deployment,
  delegation, or memory operations were performed.
- No shared library, shared behavior, other family, PRD, plan or configuration
  edits were made.

Parent must compile the changed runtime artifacts before running the CP SINGLE
suites, then validate the real facade, Permit2, owner-unlock, zero-local positive,
FullSpread matrix, fee/bootstrap and exit regressions. The new signed Permit2
case and exact owner/unlock error propagation have only source/LSP evidence.
Partial-book positive exact-net execution remains a conditional source path,
not an observed runtime result.

`HookExactNetComponentAccountingBehavior` inheritance and the adapter methods
are retained. Its full-book positive single-input exact-net expectation is
parent-owned and must reflect the strict missing-basket contract, as the parent
already indicated. No other necessary shared assertion change was identified.
