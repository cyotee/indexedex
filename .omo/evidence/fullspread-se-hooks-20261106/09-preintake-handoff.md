# Task 9 ORBITAL strict pre-intake join handoff

Date: 2026-11-07.

Status: source-complete handoff for the assigned strict FS-HOOK-07 change, not runtime verification or completion of implementation-plan task 9. The parent owns compilation, artifact generation, execution, integration and task closure.

## Authority and interpretation

Read `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and its coding/deployment/testing documents, the FullSpread PRD's FS-HOOK-05 through FS-HOOK-10, the co-located implementation/test plan's Orbital integration section, and `.omo/plans/fullspread-se-hooks-implementation-testing-20261106.md`, including task 9.

The sole product authority is `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. Applied the parent's explicit interpretation: snapshot literal pre-intake quantities, assemble from caller-owned assets only, and never execute paid incumbent-inventory swaps before the snapshot to supply missing caller components. Actual underlying SE mint/redemption/refund processing of caller inventory remains allowed.

## Production changes

All production paths below are under `contracts/hooks/uniswap/v4/standardExchange/orbital/`.

- `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol`: introduced a memory `JoinBook` containing actual LP supply and all three SE-share/local component pairs. Every funding root captures it before pulling tokens. Contribution sizing, the common gross mint limit, and accepted ceil quantities use that same book through SE conversion and refund settlement. Removed partial-basket incumbent trades and the single-input zap's incumbent trades. Missing positive incumbent legs quote zero and reject atomically with `ZeroAmount()`. Zero booked components still require zero, so valid two-raw-leg joins with an empty SE leg remain supported. Single-input Permit2 and ordinary funding still enforce actual received amounts before admission.
- `UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol`: single pair/share joins now snapshot before pulling and pass the original input as caller-owned inventory directly to component assembly. They no longer redeem the caller's entire SE input into a pair token and then run incumbent swaps. Deadline, amount, recipient, owner, live-book and reentrancy checks remain in force.
- `UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol`: removed deposit-only post-swap book projections. Share-input, SE receipt, and external-deposit composition quotes now apply caller conversion quantities against unchanged incumbent components. An impossible single-input basket reports zero LP and the original input as unaccepted. Withdrawal and bond/swap quote mechanisms remain.

Traced installed execution/query facets and package routing for direct, flexible, proportional, unbalanced, single-input, SE, Native SY and Permit2 surfaces. The separate flexible target delegates to the same changed common root. SE and Native SY deposits dispatch through `InExecutionBase` to the changed single-input engine. Owner-only checks remain on those roots. No selectors, package configuration or shared routing contracts were changed.

The ordinary sphere swap engine, radius checks, exit conversion engine, share-funded 5% genesis, locked floor and backed mint-fee split were retained. `_internalSwapExactIn` remains reachable for allocated single-token exits, not join assembly.

## Test source changes

All test paths below are under `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/`.

| File | Updated or added assertions |
| --- | --- |
| `UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting.t.sol` | Replaced the reconstructed post-ZapSwap ownership oracle with exact pre-intake rollback assertions. Added missing-basket negatives for SE, SY, direct single, exact-input single, Permit2 single, and SE-share input aliases. Assert no underlying SE `exchangeIn` call occurs during these impossible joins. Check books, custody, user balances, actual supplies, fee LP, allowances, radius and L2; Permit2 allowance rollback is explicit. Added partial flexible/unbalanced/proportional negatives. Added a positive complete share-input basket that requires actual caller-share redemptions and exact pre-intake ceil contributions plus the backed fee split. Existing positive pair-input proportional/flexible/unbalanced/Permit2 component tests remain. |
| `UniswapV4StandardExchangeOrbitalBufferHook_ComponentBoundaries.t.sol` | Replaced the incumbent-trading empty-leg activation premise. Assert the missing-basket operation rolls back, then positively execute joins against the two funded raw legs while the SE leg is disabled and has zero components. Unneeded already-owned shares are returned; re-enable does not create an accepted component. |
| `UniswapV4StandardExchangeOrbitalBufferHook_Liquidity.t.sol` | An isolated third-leg input cannot buy the two incumbent legs. Assert zero preview, exact rejection and restored balances, component books, supply and radius. |
| `UniswapV4StandardExchangeOrbitalBufferHook_ZapIn.t.sol` | Single-input positives that required incumbent sales now assert zero previews and complete rollback. Zap split quotes show zero sales and the whole original residual. Asymmetric and fee variants retain exact assertions. |
| `UniswapV4StandardExchangeOrbitalBufferHook_OwnerDuringLock.t.sol` | Owner privilege at the locked floor cannot bypass component requirements. Missing basket rejects, followed by a positive caller-funded complete-basket rejoin and exact pre-intake ceil checks. Existing owner and unlocked-manager swap positives remain. |
| `UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityPolicy.t.sol` | A rated reserve cannot turn a single input into a full component basket. Exact zero/revert/rollback assertions replace the old zap positive. Independent complete-basket mint reference remains. |
| `UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol` | The missing-basket single deposit rejects while preserving caller funding, ambient pair custody and incumbent SE shares. Other resting-fund and swap tests remain. |
| `UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol` | Installed pair/share single-input aliases reject incomplete baskets. Native SY tests retain positive redemption through every declared output using actual share-funded seed LP, while single-input deposits assert rollback. |
| `UniswapV4StandardExchangeOrbitalBufferHook_SeLifecycle.t.sol` | Single-input rejection preserves books, custody and LP supply. Existing complete-basket lifecycle, fee and buffered-leg swap positives remain. |
| `UniswapV4StandardExchangeOrbitalBufferHook_FundingRecurrence.t.sol` | Fully delivered single input still rejects its missing basket. Taxed direct/Permit2/single facade inputs continue to require the exact transfer-delta error. Existing fully funded multi-input positive controls remain. |

No test was skipped and no tolerance was changed. The original FullSpread matrix file, `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`, was not edited in this assignment: both index orientations, both rate targets, ordinary and PoolManager swap directions, actual SE mints/redemptions, and gas assertions remain for parent execution.

## Parent-owned shared test changes required

These shared behaviors were read but deliberately not edited under the explicit no-shared-behavior restriction:

1. `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol:300`, `_positiveOneUnitDepositControl`, still expects a single input to mint against a three-leg incumbent book. Its positive control should use a complete caller-funded basket and retain exact ownership assertions. The concrete caller is `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_RebasingAwareERC4626.t.sol:20`.
2. The same shared behavior's `_previewDepositSingleRow` at line 560 still executes a single deposit after `_seed`. Its caller `test_row_previewMatchesExecution` must retain the complete-basket, withdrawal and swap positives while asserting the strict impossible-single result. The FullSpread concrete row overrides that public test and retains its original swap directions.
3. `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/decimals/UniswapV4StandardExchangeOrbitalBufferHook_Decimals.sol:108`, `test_partialBook_seedThirdLeg`, still expects isolated third-leg funding to purchase incumbent components. Replace that premise with exact rejection/rollback and retain a positive multi-input proportional join with the unfunded coordinate remaining zero. Do not change the existing decimal tolerances or waive decimal swap tests.

No shared library, shared behavior, fixture, other family, PRD, plan or configuration was edited here.

## Static evidence and limits

- LSP diagnostics returned `No diagnostics found` at severity `all` for each of the three changed production files and all ten changed concrete test files.
- Source inspection confirms all acceptance callers pass the pre-funding `JoinBook`; no join root calls `_internalSwapExactIn`.
- A scoped literal search returned no matches for `_tradePartialBasket`, `_needsBasketTrades`, `_executeDepositSinglePlan`, `_depositSales`, `_depositOutputs`, `_planRawTerminal`, `_grossFromNetQuote`, `previewPartialDeposit`, or the old post-trade ceil assertions.
- The LSP reference lookup for `_acceptJoin` timed out. Literal call-site searches and direct source reads supplied the call-chain inspection; the timeout is not a successful reference check.
- No builds, tests, artifact writes, Git operations, installs, deployments, delegation or memory writes were run. LSP diagnostics are not Solar compilation, runtime, facet-size, gas or integration evidence.
- The parent must handle the shared behavior updates above and then rebuild the changed linked library/facet artifacts before running fresh production-first ORBITAL instances. Runtime preview parity, disabled paths, invariant/gas suites, and the untouched FullSpread swap positives remain unverified in this assignment.
