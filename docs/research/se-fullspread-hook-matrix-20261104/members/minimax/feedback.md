# Identity

- Member: `minimax`. Requested role: `council-member`. Profile: `research`. Phase: one advisory review of the frozen draft.
- Run: `se-fullspread-hook-matrix-20261104`.
- Requested model: `minimax/MiniMax-M3` (adaptive thinking not selectable).
- Runtime identity (actual serving provider, route and task id) exposed to this member by Native: not exposed.
- Owned artifact written by this member: `docs/research/se-fullspread-hook-matrix-20261104/members/minimax/feedback.md`.
- Peers read before submission: no. No peer `response.md` and no peer `feedback.md` was opened. No sub-agent was launched. No test, build, install, deploy, wallet or Git command was run.
- This feedback is one advisory round on a frozen draft. It does not authorize implementation and does not replace the draft.

# Draft under review

- Draft ID: `draft-se-fullspread-hook-matrix-20261104-r1`.
- Path: `docs/research/se-fullspread-hook-matrix-20261104/coordinator/draft.md`.
- Coordinator-supplied SHA-256 of the raw file: `0ee55f1e89a984afe5b6f20fe2491b7220f7114bd1ea8120da99aaf57482932c`. Not recomputed; the hash was not used as a review criterion.
- The draft was opened and read whole. It contains: a "Rejected alternatives" list, a "Replacement for plan section 12" with a shared binding section and seven topology blocks, a "Migration" section, a "Sentences outside section 12" section, and a "Limits" section.

# Disposition

**requested-changes**

The draft's binding is materially better than the published plan's section 12: it names the seven real behavior paths, it fixes the one adapter fixture and its three differences from the V3 fixture, it binds the row-only file layout the PRD's FS-TEST-04 asks for, it separates the two rate-target rows from the two-vault proof, and it records the exact-output route as a fail-closed case. The corrections below are six binding defects and one precision point. Each is an internal contradiction or a binding two implementers would copy differently; none reopens a product lock, and none objects to a rejected alternative merely because it differs from my own earlier proposal.

# Concerns

## C1 - "Replacement for plan section 12" (first paragraph) against "Migration": the draft forbids editing the seven behavior contracts and then requires editing them

The draft says "Do not add a sibling behavior contract. Do not edit the seven behavior contracts. Do not weaken their other-family assertions." The "Migration" section says to migrate "every one-word reader of `previewExchangeIn` listed in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md`" and "every one-word decoder of `exchangeIn`, including implementations, overrides, typed ignored-return callers, low-level decoders, the six length gates, the three ABI bindings, helpers, tests, scripts, and generated ABI artifacts", and the shared binding paragraph says "One-word `previewExchangeIn` comparisons in inherited bind tests read `amountOut` after the migration below."

The seven behavior contracts contain one-word `previewExchangeIn` reads - for example `assertGt(IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), _f(1), IERC20(seUT)), 0, "SE quotes the face")` in `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol:212`, in `constantProduct/single/..._SeMatrixBehavior.sol:217`, `dual/..._SeMatrixBehavior.sol:238`, `orbital/..._SeMatrixBehavior.sol:230-232`, `weighted/..._SeMatrixBehavior.sol:158`, `stable/quad/curve/..._SeMatrixBehavior.sol:208` and `stable/quad/balancer/..._SeMatrixBehavior.sol:256`. The draft asserts twice that those inherited bind tests are migrated, and once that the seven files are not edited. Both cannot hold.

Fix direction: narrow the prohibition to the assertions and expected amounts of the other families, and state that the plan's decoder-width change is applied inside those files for the `amountOut` word only - or state that the seven files are outside the migration's "tests" scope and that their one-word reads keep returning `amountOut` because the ABI decoder ignores the trailing refund word. Either resolution is fine; the draft cannot hold both positions.

## C2 - "Replacement for plan section 12", the setUp-override rows: the draft does not say how the row reaches the base TestBase setup, or which inherited state it must populate

The draft's dual, orbital, curve, weighted 3-leg and Balancer 2-leg/5-leg blocks each say "The row overrides `setUp` and does not call `super.setUp()`."

From the row, `super.setUp()` resolves to the behavior's `setUp`, whose own `super.setUp()` is the TestBase's setup. That TestBase setup is not optional: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol:80-140` deploys the PoolManager (`pm`), the hook diamond factory (`hookFactory`), the hook package (`hookPkg`), a default hook, the product pool key, the usage fees and the funded `user`, and it calls `TestBase_ERC4626StandardExchange.setUp();` explicitly at line 81. A row that overrides `setUp` and does not call `super.setUp()` therefore never reaches it: `pm`, `hookFactory`, `hookPkg`, `create3Factory`, `indexedexManager`, `owner`, `permit2`, the facets and `swapRouter` are unset and no row can deploy a hook or fund a user.

Two implementers would copy this differently: one skips the base setup and produces a row that cannot deploy anything; one reaches the base by an explicit qualified call in the same form the TestBase itself uses at line 81.

The same gap covers the inherited state. Because the row replaces the behavior's `setUp`, it must populate the state the inherited assertions read - `fx`, `face`, `seUT`, `faceDec`, `rejectBytes`, and per-topology `faceIdx`, `otherIdx`, the fixture array and the leg decimals - all of which the behavior's `setUp` and its non-virtual `_bindRowHandles()` would otherwise have set. The draft names none of them.

Fix direction: state the route by which the row reaches the base setup, and list the inherited state the row must set. For the constant-product single and the non-CP single rows, which do not override `setUp`, say so explicitly and note that the inherited `_rowPkgArgs()` (non-virtual, `constantProduct/single/..._SeMatrixBehavior.sol:117`) builds the provider through `RateProviderFixtureLib.providerForCp(..., seUT, face)` at line 128, which is the currency0 provider only because that helper is idempotent for the same `(se, rateTarget)` pair.

## C3 - "Weighted" (3-leg row) and "Balancer quad" (2-leg and 5-leg rows): the inherited seed helpers are not virtual and hard-code the leg count, so the inherited bodies cannot run on those pools

The draft's Balancer block is right that `LEGS` is 4, that `_buildLegs` rejects a count above 4, that `_rowPkgArgs` builds `address[4]`, and that overriding `_seLegCount()` to 2 still deploys a four-token constructor. It then says "The V4 rows do not call `_buildLegs` or `_rowPkgArgs`."

That is not sufficient. The inherited seed path is `_seed()` -> `_joinAll()`/`_joinBoth()` -> `_amounts()`, and `_amounts` allocates an array of the inherited length: `new uint256[](2)` in `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:128` and `new uint256[](LEGS)` with `LEGS = 4` in `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol:37,215`. `_seed`, `_joinBoth` and `_joinAll` are `internal` and not `virtual` in both behaviors. Each of the two behaviors has 11 `_seed()` call sites, so every inherited `test_row_*` body that seeds the pool builds an array of the inherited length and joins it against a pool with a different leg count.

The draft names one override for Balancer (`test_row_bind_deploysThroughPackage`, "assert 2" / "assert 5") and none for the weighted 3-leg row, so an implementer would leave the remaining inherited bodies in place and they would fail at the join rather than at an assertion. The curve row is unaffected because four legs is the inherited length.

Fix direction: for the weighted 3-leg row and the Balancer 2-leg and 5-leg rows, name the inherited tests the row overrides and say how the row seeds its own pool. The curve row needs no equivalent sentence.

## C4 - "Common adaptation, every topology": `test_row_partialConsumption_bookedNotRefunded` - the draft does not bind `hasPartialCase()`, `limitCapacity()`, `openCapacity()` or the booked measurement

The draft says the booked-not-refunded body "cannot pass", that the unused declared input "is refunded to `msg.sender`", that the row must "Trace that refund to the entitled caller", "Do not relabel it as booked inventory", "Do not delete the test", "Do not make it pass by booking the refund", and "Include a no-refund control."

The inherited test branches on the fixture's answer before it reaches the booked body: `if (!fx.hasPartialCase()) { _roundingToZeroControl(); return; }` at `weighted/..._SeMatrixBehavior.sol:181` and `stable/quad/balancer/..._SeMatrixBehavior.sol:294`, and the same branch in each of the other five behaviors. The draft never says what `hasPartialCase()` returns for `SeMatrix_FullSpreadV4Fixture`. `false` makes the inherited body unreachable, the rounding-to-zero control runs, and the test passes as inherited - which is consistent with the draft's "cannot pass" only in the sense that the body never executes. `true` requires the row to override the body and to assert the refund. The draft's rejected-alternatives entry rejects "`hasPartialCase() == true` as a way to book the user's unused input", which does not settle the value.

The same paragraph leaves `limitCapacity`, `openCapacity` and `seBooked()` unbound, and the shared binding paragraph forbids the fixture from adding a booked getter. The row therefore has no defined way to assert a booked amount, and the draft's "Donation and compound remainders are booked, so those rows stay" has no observable in this family - the draft itself notes that "None of these seven behavior files contains `donate` or `compound`", which I confirmed against all seven files.

Fix direction: state the value `hasPartialCase()` returns and what the row asserts in each branch, and state the measurement the row uses for a booked amount given that no getter exists. If the fixture's `seBooked()` is the local face balance minus the position-implied reserve, say so.

## C5 - "Other SE" and "Dual": `rateProvider1` for the PairToken leg is not bound, and the draft's own `asset()` conditional fires for that leg

The draft's dual block binds "Package index 1: the PairToken vault and its share" and "`rateProvider1` is that vault's own provider". It does not say how that provider is built.

The PairToken share is the PairToken vault address, so the only in-repo construction path - `RateProviderFixtureLib.providerFor` in `contracts/test/libs/RateProviderFixtureLib.sol` - takes its self-share branch, `if (se == rateTarget) rateTarget = IERC4626(se).asset();`. The PairToken vault exposes `rateAsset()` (selector `0xcf77880f`, `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol:51`, declared at `.../pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol:274`) and no `asset()` at all, so that call does not resolve.

The draft's own condition therefore applies to the canonical proof: "If the current package rejects `token == se` without `asset()`, record the consumer, selector, arguments, and revert under FS-HOOK-04 and do not pass that identity variant." The draft names no fallback bind for leg 1 of the dual row, while PRD FS-HOOK-02 item 2 does name one - "The other leg can still be a raw token or a share transfer that the hook accepts without calling that vault" - and the constant-product row in the same draft does use a raw leg for exactly that reason.

Fix direction: bind the construction of the PairToken leg's provider, or bind the fallback leg-1 token when the identity bind cannot be priced, and say which one the canonical dual proof uses. Note that this is a missing binding only; the draft's choice of the other SE is not itself a defect, and the `asset()` prohibition stands.

## C6 - "Sentences outside section 12" (Section 13 replacement) against the section 12 content: FS-A24 has no home in the draft

The draft replaces the plan's section 13 row with "BufferHookIntegration.t.sol and the row files named in section 12." That row covers "FS-A24 to FS-A30, FS-A38, composed gas". FS-A24 is the acceptance row "An identity bind of `token == this vault` is attempted. If the current package rejects it without `asset()`, the row records that reject under FS-HOOK-04 and does not pass."

No row in the draft's section 12 attempts an identity bind of this vault. The draft's only identity handling is in the "Other SE" paragraph, and that paragraph is about the other vault's share as leg 1. So the draft's own section 13 replacement routes FS-A24 to a set of row files in which FS-A24 is not exercised.

Fix direction: either add to one row the attempted `token == this vault` identity bind and its FS-HOOK-04 record, or say in the "Sentences outside section 12" section that FS-A24 is not covered by the row files and remains with `BufferHookIntegration.t.sol`.

## C7 - precision: the exact-out adaptation is written as a disjunction

"Common adaptation, every topology" says `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` "expects the revert, or a zero `previewExchangeOut`, and does not assert a delivered amount." The two surfaces are different objects with different owners: the vault's `previewExchangeOut` returns zero (plan section 6, line 142), while the hook's exact-out preview reverts `IStandardExchangeOut.ExchangeOutNotAvailable` when that preview is zero (`contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookCommon.sol:103-104,118-119`; `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol:118-120`). Saying which surface each row asserts removes the last place where two implementers would write different tests.

# What was not adopted from others

No peer response and no peer feedback was read before this submission, so nothing was adopted from another member.

Two choices in the draft differ from the proposal I filed in `members/minimax/response.md`, and I do not treat either difference as a defect:

- The draft drops the sibling behavior contract and puts every adaptation in the `.t.sol` row, overriding `setUp` where the inherited setup cannot express the bind. I had proposed a sibling behavior file per topology. The draft's route is the one PRD FS-TEST-04 describes ("It adds a row for this vault beside those contracts"), and I do not press the difference. C2 and C3 are about what the row must do under the draft's own route, not about the route.
- The draft binds the other Standard Exchange in the canonical dual case to a PairToken vault, where I had proposed a second instance of this family. The draft's choice follows FS-HOOK-02 item 2 and its rejected-alternatives list, and I do not press it. C5 concerns only the unbound construction of that leg's provider and the missing fallback leg-1 token.

# Limits

- One advisory round on the frozen draft. No second round is started here, and no request for one is made.
- No Forge run, build, test, install, deployment, wallet operation, configuration change or Git operation was performed. Every statement is read from source; nothing here is observed at runtime.
- The draft was not edited, and neither were the plan, the PRD, `members/minimax/response.md`, or any peer file.
- I did not open `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md`. C1 therefore rests on the draft's own "Migration" section and on its own sentence about the inherited bind tests, not on that index's contents.
- I did not read the coordinator's run record, the resolution, the plan's `IMPLEMENTATION_PLAN_BLOCKERS.md`, the audit evidence files, or the plan's `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`. I did not re-derive the coordinator-supplied SHA-256.
- The vault family does not exist yet; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` holds only the PRD, the plan, the blockers file and the pair-token review file. Every statement about this vault's behaviour is therefore taken from the plan's and the PRD's written rules, not from a running artifact.
- One pre-existing repository condition I ran into while checking C2 and C3, outside the scope of the draft and not a draft defect: the dual and weighted SeMatrix behaviors import their TestBase from `contracts/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol` and `contracts/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol`, and neither file is present at those paths - the TestBases are at `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/` and `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/`. I did not compile and did not determine whether another resolution rule covers those imports. If it does not, the dual and weighted rows in this draft are not runnable as written, which the coordinator should confirm before publication.
- The identity of the PairToken share as the PairToken vault address, which C5 relies on, is the share-as-vault-diamond pattern used throughout this matrix - `IERC20(seUT).balanceOf(hook)` and `IERC20(seUT).totalSupply()` in the shared behaviors read the SE's own diamond as the share token. I did not open the PairToken package's share wiring.
