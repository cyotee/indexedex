# FullSpread G6 transition/lifecycle handoff

## Reconciled parent execution checkpoint — 2026-09-30

**Latest lifecycle selection: eight tests per family passed**, including both
partial-fill faces, late-minimum rollback, already-at-limit retention, sequential
transitions/full-range lifecycle and strict direct-EI rejection, in
`tool_0f2ac962b001saQBFZEqpb2RyO` (66 combined passes). Parent additionally reports
**both dedicated work-limit tests passed**. The latter two-test result is
parent-reported here; no new log identifier was supplied for it. Actual sources
and the 66-result log were inspected; this documentation task ran no tests.

The authorized F6 production correction and independent security PASS are
parent-reported completed work, not still-open implementation tasks. Direct
exact-input remains strict. The former expected-QuoteWorkLimit blocker and
pending-follow-up statements below are historical, superseded for these cases.
Successful terminal arrival exactly on step 64 remains an untested optional
boundary, **not a newly added mandatory closure gate**: positive terminal partial
fills, already-at-limit no-conversion and nonterminal 64-step rejection are all
covered by the scoped predicates.

Final family validation (expected 450, refreshed 128 fuzz runs), post-F6 broad
consumer validation, source/artifact/runtime manifests and the owner readiness
checkpoint remain pending. The earlier broad 12,050 green run predates F6 and
cannot certify that change. No retirement authorization is implied. Historical
sections below retain the correction rationale and exact reference limitations.

## Security-follow-up tests — current prepared handoff

The parent reports independent security PASS and the preceding **436-family /
128** validation green. That checkpoint predates the test-only additions here;
this worker has not independently run or reclassified those results.

Added three bounded cases, instantiated for H and P:

- `test_partialConversionLateMinimumRollsBackBothFaces`: executes the real
  partial redemption on a restorable snapshot, reuses the full positive G6
  output/residual/fee/book assertions, restores the identical funded state, then
  requests **actual payout + 1**. Requires the precise late slippage error and
  restoration of full projected fields, holder claim/shares/supply/allowance,
  caller/manager/hook balances, both booked reserves (including the prior
  donation's unbooked status), both global fee-growth values, own-position fee
  checkpoints, all four P fee/tax ledgers and zero self-share custody/booking.
- `test_redemptionAlreadyAtDirectionalLimitRetainsFullOpposingEntitlement`:
  reaches each exact directional endpoint using a real core swap, then obtains
  actual-holder state and executes F6. Requires positive opposing entitlement,
  selected output equal to independent selected entitlement, **zero Swap
  events**, unchanged endpoint price, unchanged P charges, exact burn/payout,
  every projected/live field, exact opposing cash after signed placement/fee
  settlement, and retention of the entire opposing entitlement in backing.
- `test_F6WorkLimitPrefixRollsBackBothFaces`: separate spacing-1 Acceptance
  fixtures following existing `CoreSettlement::test_64StepBoundRejectsTruncationButAllowsMultiStepSuccess`.
  Uses real pool state/full-range ticks and the core quoter with actual
  post-removal liquidity. Requires **exactly 64 steps**, positive but incomplete
  consumption, and a terminal price **different from the limit**. Funded-holder
  state valuation, ordinary F6 preview and real F6 execution must all reject
  `QuoteWorkLimit`; execution restores the full financial snapshot, shares,
  allowance, caller/manager/hook custody, booking, global growth, own checkpoints,
  hook charges and zero self-custody/native balance. No synthetic tick storage,
  conditional success/skip, mocked manager or lowered work cap is used.

The new work-limit helper is
`contracts/test/bases/TestBase_FullSpreadG6WorkLimitRollback.sol`. Dedicated
`HooklessG6WorkLimitRollbackTest` / `PonsG6WorkLimitRollbackTest` contracts live in
the existing two G6 test files. They isolate spacing 1 from the previously green
spacing-60 tests, whose fixtures and positive partial/direct-strict assertions
are preserved. The new negative/endpoint tests use the existing G6 helper.

**Remaining validation:** parent compilation and execution of these additions.
The preceding green results do not cover them. Successful terminal-price arrival
**on exactly step 64** is still **untested**: this bounded patch distinguishes
ordinary successful partial fills from 64-step nonterminal exhaustion but adds
no specially positioned 64th-step terminal-success fixture. No success claim is
made for that boundary. No production changes, Forge, delegation or commits were
performed in this follow-up.

## Authorized F6 correction — current handoff

The parent reported the preceding tests **compiled: 6 passed / 4 failed**, with
both partial-F6 faces in both families failing `QuoteWorkLimit`. This is a
parent-reported checkpoint for the **pre-correction** source, not a result for
the patch below. The owner then explicitly authorized this bounded production
correction under plan §2.7: measured selected payout, retained/booked unspent
opposing entitlement, and remaining-holder ownership of newly earned own fees.

Changed production files are exactly each family's `QuoteService.sol`,
`Common.sol`, and `InBase.sol` (full family prefixes at the established H/P
production paths). The F6 exact-input implementation lives in InBase, despite
being a redemption. No OutBase/OutTarget/EO route change was needed.

- Each separately compiled family now exposes linked-library
  `_redemptionForward`. Its private bounded evaluator accepts full fills **or an
  actual directional terminal-price-limit partial fill**. A 64-step truncation
  elsewhere still fails. Amount and **gross core output** signed-delta bounds
  are retained, including P before its net-output charges. At an already-reached
  directional limit it returns an exact zero-consumption/no-movement result.
- Ordinary `_forward` and public `_tryForward` remain strict full-fill paths.
  Composition/repair refinement counts, core step cap and impact rules are
  unchanged; no idle exact-share or two-backed-leg EO domain was added.
- Ordinary F6 preview after required withdrawal and supplied-state F6/holder
  valuation use the redemption-specific quote. Projection restores exactly
  `opposingEntitlement - swap.amountIn` before storing the resulting book.
- Actual F6 execution submits the **original entitlement budget** to core so
  zero-liquidity travel after the last paid step reaches the same quoted limit.
  It pays only actual selected output and leaves unspent opposing custody in the
  existing booked/repair workflow. Merely resubmitting the smaller consumed input
  could stop at the last liquidity boundary rather than the quoted terminal price.
- `_verifyRedemption` lives in each family's linked QuoteService rather than
  expanding the common execution validator: it retains the 10-bp shortfall guard
  and exact consumed input, net output, terminal price/tick/active liquidity
  checks. Existing Common `_executePlannedSwap` is unchanged. This isolates added
  execution code from the nearly-full OutFacet path; **final byte sizes must
  still be measured by the parent**, not inferred from source. No compiler-limit
  or via-IR workaround is used. No cross-family economic dispatcher was added.

The test helper now independently reconstructs **exact opposing local custody**
from initial local/earned inventory, independently computed entitlement minus
measured consumption, signed actual liquidity changes at event-time prices, and
real inside-growth fee recovery on the post-burn position. The endpoint fixture
requires exactly one conversion swap. This strengthens the original residual
backing lower bound rather than replacing transition/live field parity.
`test_directExactInputStillRejectsPriceLimitedFill` adds both-face strict direct-EI
preview/execution rejection and exact rollback. There are now **six inherited
test functions per family**, all requiring refreshed validation.

**Remaining:** parent artifact-first compile, all G6 execution, relevant existing
core/route/context/EO regressions, and all affected runtime size checks (especially
H OutFacet 24,571 / P OutFacet 24,540 at the supplied prior checkpoint, plus In
facets/delegates and query/library runtimes). No Forge, solc, LSP, delegation or
commit was performed by this worker. G6 remains OPEN until those results exist.

## Original test-only handoff (historical)

Date: 2026-09-30. **Source additions prepared; G6 remains OPEN.** No Forge,
solc, LSP compilation or test execution was performed by this worker. No passing
count or current-tree execution claim is made. The parent owns serialized Forge
validation after all workers are ready.

Authority: `CLAUDE.md`, the FullSpread PRD §13 (especially A12/A20/A29),
implementation/test plan §§2.7, 4, 5 and 8, context/quantity addendum, and
`UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md` G6. The scope is tests and this record.

## Added files and fixtures

- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/TransitionLifecycleClosure.t.sol`
  — `HooklessTransitionLifecycleClosureTest`.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/TransitionLifecycleClosure.t.sol`
  — `PonsTransitionLifecycleClosureTest`.
- `contracts/test/bases/TestBase_FullSpreadG6TransitionLifecycleClosure.sol`
  — unique test-only assertion helper, inherited by both leaves.

Both leaves reuse their existing family Acceptance fixtures, override token
decimals to 6/6, and execute ordinary dual activation. Facets/packages/proxies,
manager, fee oracle and P hook follow those real fixtures. P uses the existing
authorized-registrar fixture with separate 100-bp registered hook/creator rates;
this is **not** new production launch/graduation evidence. No existing TestBase,
production implementation, configuration or acceptance-map file was edited.
No mocked SUT, SUT storage writes or vault impersonation was introduced.

The helper reuses the existing context snapshot shape and campaign fee-ledger
interface. It does not inherit their test functions or call family planners,
inventory/protection helpers or quote services as expected-value references.

## New assertion map (prepared source, not executed evidence)

All five test functions below are inherited independently by H and P.

| Test | Actual assertions and dimensions |
|---|---|
| `test_externalTransitionsPreserveHolderClaimSequentially` | Both accounting/output faces, passive holder with actual transferred shares and a distinct external recipient. Projects **all four** external operations before execution, feeding each opaque next state into the following quote: token0 deposit, opposite-to-selected external swap, token1 deposit, another external swap. Executes each operation in order; asserts ordinary quote = projected quantity = returned quantity, exact payer debit, exact recipient receipt, holder shares unchanged and exact supply. Compares each projected next state against the resulting live book field by field and exact holder claim. |
| `test_redemptionTransitionAndSYMatchAfterExternalSequence` | Both selected faces after a real fee-bearing external trade. Snapshot-restored SE R5 versus SY R9 burn, same payer/recipient and amount. Ordinary/transition quantities equal actual receipt; exact burn/supply and projected next book/remaining claim. Independent `floor(L*burn/S)` removal plus pro-rata local/earned entitlement, first real core Swap input/output and separate P fee floors reconstruct the payout. Remaining-holder repair proceeds cannot enlarge it. Each alias also has full booking and core fee/liquidity checks. |
| `test_partialConversionRetainsOpposingEntitlementAndProjectedBook` | Selected token0 positive F6 partial-fill regression; see blocker below. Actual opposing-token donation `5e31`, full caller-share burn leaving activation sink. Snapshot-isolated real-core control requires positive **partial** input consumption and exact terminal price limit. Required continuation compares transition/ordinary/executed output, exact share burn/receipt/claim, actual first conversion input below independently computed entitlement, positive retained residual dominating tiny sink backing, residual included in opposing economic book, and complete projected/live field parity plus booking. |
| `test_partialConversionRetainsOpposingEntitlementAndProjectedBook_token1` | Independently runnable symmetric selected-token1 regression; not hidden behind a token0 failure in a single loop. |
| `test_fullRangeLifecycleActivationWalkBlockedJoinRepair` | Ordinary activated center bounds are exact min/max usable ticks at salt zero; positive actual core liquidity; old `[-60,60]` center and both legacy wing positions absent, including **both** alternate salts on full-range bounds. Rechecks after each directional real spot walk, blocked single join and idle repair. Spot walk must move tick while owned liquidity/local balances remain exact. Blocked transition quantity and every next-state field equal real outer-unlock execution; exact local credit, supply/shares, unchanged owned liquidity and own fees, zero Swap events. Repair preserves supply/shares/caller funds, reconciles owned liquidity against all real ModifyLiquidity deltas and local custody against token Transfer settlement ledgers, and rechecks core fields/booking/tick/wing absence. |

### Shared exact observations

`_assertG6Fields` checks vault/face/context, supply/holder shares, both local
balances, both uncollected own-fee amounts, position liquidity/bounds, pool
price/tick/active liquidity, sleeve/floors, both endpoint gross liquidities and
capacity. There is no generic book hash. Only cumulative `liquidityDelta` is
excluded from persisted-state equality; fresh live snapshots must have zero
overlay. Sequential quotes retain their overlays and are constructed against the
original manager state before any of the four executions.

`_assertG6Core` independently reads actual ERC20 custody/reserves/self-share zero,
native balance zero, core position liquidity, slot0, active and endpoint gross
liquidity. Own fees equal `floor((insideGrowth-lastCheckpoint)*ownedL/2^128)`
using actual core reads and modular subtraction. `_assertG6Fees` sums the separate
P fee and creator-tax floors from real core Swap event outputs and compares all
four pending-ledger balances. The H fixture has LP fees; P has zero own LP fee
and real registered-hook charges. Directional protocol-fee proof is reused below.

## Existing assertions retained rather than duplicated

Paths below are relative to the H/P test roots used by the acceptance map.

| Existing locator | Reused coverage / limit |
|---|---|
| H/P `CrossModeStatefulCampaign.t.sol`, shared `TestBase_UniswapV4FullSpreadCrossModeCampaign.sol::_assertExitAttribution` | Independent ordinary F6 removal/local/earned entitlement and measured full-fill conversion; `_assertMintAttribution` covers independently reconstructed caller/holder issuance. Existing campaign coverage is not a partial-fill witness. |
| H/P `CoreSettlement.t.sol::test_forwardBothDirectionsMatchesCoreExactly`, `test_compositionPlansSettleBothDirectionsWithExactBookAndShareMath`, `test_directionalProtocolFeesAndOwnLpRecoveryMatchIndependentFloors` | Real core signed settlement, own LP recovery, work bounds and fee splitting. The G6 additions do not duplicate the economic formula/vector suites. |
| H/P `OneBackedLeg.t.sol::test_fundedBlockedLinearExactOutputInNaturallyOneSidedBook`, `test_idleLinearExactOutputWithClosedPlacement`, `test_linearQuantityIgnoresZeroHolderButTransitionRequiresShares`, `test_linearQuantityDoesNotPromiseLocalCover`, `test_oneOpposingWeiInvalidatesFreshQuantityNotOldSuppliedState` | **R6 overlap:** supported natural linear quantity/funding, idle CC, quantity versus holder/local cover, fresh opposing-wei domain rejection and preservation of old supplied-state quantity. These do not establish both natural one-sided orientations or general positive-two-leg EO support. No new inverse or duplicate linear fixture is added by G6. |
| H/P `ExactOutputQuantityQuote.t.sol` and shared `TestBase_UniswapV4FullSpreadExactOutputQuantity.sol` | Both-face F1 supplied-state quantity/real issuance and idle/two-leg domain controls. Quantity-only APIs produce no next state; they must not be described as transition proofs. |
| H/P `UnlockContextQuote.t.sol` and shared context helper | Actual blocked deposit/redemption projection/execution, both faces, complete bytes, amounts and booking. New lifecycle case specifically carries the blocked join into subsequent full-range repair. |
| H/P `EquivalentInterfaces.t.sol`, `BlockedYieldEquivalence.t.sol` | Existing SY custody/internal-balance and blocked aliases. New G6 R5/R9 case adds both-face idle transition fields and independent first-swap entitlement observation after real external trading. |
| P `PonsFeeSemantics.t.sol` | Separate fee/tax floors, 50-unit zero-charge witness and registered terms unaffected by changed defaults. G6 observes those floors on its own actual transitions rather than retesting policy configuration. |

## Exact remaining work / source blocker

1. **Parent compile and execution are still required for every new test.** Static
   inspection is not compiler validation; stack depth, fixture feasibility and all
   runtime assertions remain unverified. There are five new inherited test
   functions per family, not ten claimed passes.
2. **Partial F6 is expected to fail on current source.** In both family
   `QuoteService.sol::_forward`, `!filled` reverts `QuoteWorkLimit()`;
   `_tryForward` requires `quote.fullyFilled`. The underlying real quoter defines
   that as `amountSpecifiedRemaining == 0`, including price-limit truncation.
   Family `Common::_inventoryRedeem` routes the opposing entitlement through that
   function. `quoteState(asset, fundedHolder)` itself values the holder through
   `_inventoryAssets`, so it is expected to reject before the explicit transition
   call in this fixture. This is **source analysis**, not an observed Forge trace.
   Also inspect residual projection when addressing that rejection: both Common
   implementations subtract the entire `out0/out1` entitlement before
   `_inventorySwap`; the latter updates price/own fees and returns output without
   restoring `requestedInput - actualInput`. Simply allowing a partial quote is
   therefore insufficient to establish the required next-book equality.
3. The partial tests deliberately retain positive success assertions, with no
   `expectRevert`, skip, caught-revert success or weakened small full-fill amount.
   A zero-holder live snapshot is used solely to derive the real-core control's
   entitlement; the local reference's holder-share field is never sent back to
   the SUT. The funded transition requires a fresh actual-holder snapshot.
4. The core control runs with pre-removal active liquidity, which is greater than
   F6's remaining active liquidity. It establishes price-limit partial-fill
   reachability, **not** exact post-removal F6 settlement. The required positive
   continuation observes the actual F6 conversion, exact output and complete
   projected book. Those assertions cannot close G6 until that continuation runs.
   Its residual check is an exact computed unspent quantity plus a backing lower
   bound, not an independent reconstruction of every post-repair principal/fee
   unit. No partial-residual ownership PASS is claimed.
5. Full-range repair has no public maintenance-transition quote API. Its new
   checks use actual core liquidity deltas, token settlement and custody; they
   do not claim a nonexistent repair `nextState` or independently certify the
   terminal progress metric. Existing G2 owns that independent progress proof.
6. Additional decimal/native/launch dimensions and the rest of G1–G7 are not
   promoted by this scoped file. R6's outstanding orientation/funding cells
   remain where the acceptance map records them. Retirement remains gated.

The parent can select the two `TransitionLifecycleClosure.t.sol` roots for its
serialized artifact-aware run when all workers are ready. Collect actual compiler
errors/results, particularly both independent partial-fill cases, before changing
this record's status. Production remediation requires the parent's separate scope;
this worker made no production change, delegated work or commit.
