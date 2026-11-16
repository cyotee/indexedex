# Frozen original-credit pricing: initial implementation handoff

Date: 2026-11-10.

**Verdict: needs-fix.** The unchanged-code baseline passes. The proposed capture architecture is viable for a bounded set of demonstrated routes, but it is not yet an exact evaluator for an identified Migration configuration. Root may authorize the corrective implementation/test increment in section 5; it may not authorize a claim of general nested-SE support or E3 completion from these initial reports.

**AdversarialVerify: PASS for the initial assessment and bounded handoff; NOT PASS for implemented frozen pricing.** All three required upstream outputs exist and were read. Their raw baseline exits and selected traces were inspected. No missing upstream output was treated as success. No build, test, source edit, consultation, deployment, or operational allocation was performed by this review node.

This is plan-task-2 engineering work. The copied `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` sections 1-6 and task 2 were read, together with the complete phase-two brief. Phase-one `migration/evidence/phase01-verification.md:301-327` permits frozen-quote work on demonstrated routes independently of E2. Fungible ancestry and TokenStaking ownership/custody remain open. Nothing here selects their policy, fixes their ABI, changes eligibility, or completes task 1, task 2, or E3.

## 1. Evidence and findings

Paths in this document are relative to `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`, except where explicitly absolute. These aliases expand to exact paths:

| Alias | Path |
| --- | --- |
| Pricing | `docs/incidents/2026-09-16-dtf-recovery/migration/pricing/` |
| Baseline | `docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/baseline/` |
| DETF | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| Hook | `contracts/hooks/uniswap/v4/standardExchange/weighted/` |
| Receipt | `contracts/vaults/standard/erc4626/` |
| V3 | `contracts/vaults/standard/exchange/protocols/uniswap/v3/` |
| Morpho | `contracts/vaults/standard/exchange/protocols/morpho/blue/` |
| Migration | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |

### Blocking distinctions

1. **Actual-route closure is missing, not disproven.** `Pricing/dependencies.md` sections 2, 5-7 and 9 explicitly leave actual Migration bindings and exact receipt-model recognition unproved. The two gold fixtures establish real local package bindings, not the recovery deployment. Before claiming E3, record both contribution identities, ordered mint routes, resolved pairs, every relevant hook leg, registry/package/selector identities, and the exact underlying implementation/model. Proxy runtime hash alone does not distinguish facets or their implementations. This is a pricing-source requirement, not a request to decide legacy ancestry.
2. **Existing getters do not provide the full buffered hook book.** `Hook/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:176-192,313-318,410-415` returns SE inventory for `nativeReserve` and the synchronized basic-vault reserve on buffered legs. Neither is raw retained cash. The new aggregate getter must return `rawReserves` and `seReserves` directly. Subtracting rounded rated values, using ambient token balances, or relabeling SE shares as raw cash is not exact.
3. **Existing serialized SE quote state is not a frozen evaluator.** Receipt `ERC4626StandardExchangeQuoteTarget.sol:65-136,249-349` still calls the live vault, including `convertToShares(localUnderlying)` after a transition. V3 `UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol:272-367` still reads pool tick state, live reserve policy, and token metadata. Later source changes can alter a call with identical bytes. Keeping those calls is a blocker.
4. **Generic ERC4626 recognition is not established by a few probes.** Receipt `ERC4626StandardExchangeQuoteTarget.sol:213-246` recognizes a virtual/ratio model from selected calls. That is ordinary code behavior, not proof that an arbitrary vault's ordinary preview has that formula for all amounts. The frozen ordinary adapter requires a reviewed implementation identity and exact empty-state, overflow, conversion, and preview semantics. Do not make ordinary ERC4626 operations start rejecting previously supported vaults to satisfy this new capture restriction.
5. **The baseline is not a primary-mint differential oracle.** Both recorded post-first-bond exchange paths take `ownerSwapExactIn`. Reusing their outputs as seigniorage-mint expected values would bless the wrong branch. Missing primary/freeze tests are unrun, not failed gold tests.
6. **A full V3 curve is conditional and unmeasured.** Cross-token conversion, ordinary SE-share redemption, and transition redemption are distinct routes. A sealed full bitmap/tick image can close their pool reads in principle; atomic acquisition and deployment/storage gas are not demonstrated. A 512-step limit, price scalar, small window with live fallback, or multi-block stitched image cannot be called exact. This does not block the demonstrated V3 ordinary pair-deposit route, which needs only complete reserve totals and supply after capturing the provider's actual return.

### Baseline accepted without rerunning

The following are observed receipts, not commands executed by this node:

| Command | Independent evidence inspected | Finding |
| --- | --- | --- |
| `forge build --use solar` | `Baseline/build-command.txt`, `build-exit.txt:1-3`, `build.log:1-6` | Forge exit 0, tee exit 0; 5,793 files; successful Solar compile with warnings |
| Weighted DETF `forge test --use solar --match-path .../UniswapV4Detf_Weighted.t.sol -vvvv` | `weighted-command.txt`, `weighted-exit.txt:1-3`, `weighted.log:3849-3851` | 4 passed, 0 failed, 0 skipped |
| Production V3 weighted DETF `forge test --use solar --match-path .../prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol -vvvv` | `nested-command.txt`, `nested-exit.txt:1-3`, `nested.log:50119-50121` | 4 passed, 0 failed, 0 skipped |

The recorder selects `/Users/cyotee/.foundry/bin/forge`, explicitly changes cwd, exports all three runtime variables, and records both pipeline exits (`Baseline/run.sh`). Its baseline reports Forge 1.9.1-nightly, Solar 0.3.0-dev and HEAD `90ff0307a7a8e084aa073e02eff125e9c7973933`. The cleanup receipt records equal before/after 5,200-file manifests, empty source diffs, completed recorder PIDs, and preserved shared links/caches. These are the baseline node's provenance receipts; this review did not independently rehash the whole worktree or shared dependencies.

Trace read-back confirms:

- ERC4626 fixture: `weighted.log:1798` calls `ownerSwapExactIn`; `:1902-1904` returns weighted WAD `5268940424990216880`, then native DETF `5268940424`; `:2038` returns that native amount from execution. The test contains no public DETF preview assertion (`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol:30-35`).
- V3 fixture: `nested.log:49062-49063` quotes the unboosted `10000000000000000000`; `:49201-49213` reads fee `50000000000000000` and deposits net `9500000000000000000` into the real SE preview. `:49320-49328` maps this to rated inflow `7027072017498277717` and returns `5617384097` native DETF. Execution uses `ownerSwapExactIn` at `:49506` and returns the same amount at `:50050`.
- The V3 suite's exact public preview/execution assertion is real (`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol:24-36`). It proves the selected ordinary branch, not a different branch.

No baseline failure needs repair. Existing compiler/configuration warnings remain. Rebuild only after actual implementation changes; do not repeat the already valid unchanged build.

## 2. Snapshot contract

### Capture boundary

Capture once, atomically, from the configured funded book. The caller supplies no numerical prices, precomputed credit, arbitrary evaluator address, callback, or source calldata. Production lifecycle ownership/removal belongs to later Migration composition; this increment supplies its capture/evaluation primitive and a test exposure, not a replacement lifecycle.

All source accesses occur during capture through static reads in the canonical caller context. Hook rate/fee/registry reads originate from the hook proxy. The two captured contribution routes come from the configured DETF route table, not whichever route produces more output. Resolve the first matching pair in DETF pair order, as `DETF/UniswapV4DetfCommon.sol:151-181` does. Store the resolved edge and pair index.

Seal only after every required field and supported route has been acquired. Failed acquisition leaves no installed snapshot. Capture must not mint, transfer, approve, unlock, collect, rebalance, settle expansion, or create a bond. No recapture or setter can change sealed dependencies. Snapshot identity domain-separates format version, chain ID, quote-subject/Migration proxy, capture provenance and contents. Store block number/timestamp; `blockhash(block.number)` is not the current block hash.

### Required readable fields

| Group | Required frozen values |
| --- | --- |
| Identity | Version; chain; quote-subject proxy; hook; original ETH/WETH mapping and original DTF identity; capture block/time; deterministic snapshot identity; admitted implementation identities |
| Routes | Two original-contribution edges, accepted membership, selected SE, resolved pair/index, token-in/token-out, conversion mode; retain pair order used for resolution |
| Weighted book, 2-8 ordered legs | Token and SE/provider addresses; weights; inventory/rated scales; raw retained reserves; attributed SE reserves; actual provider response status/length/value where potentially used; input registry registration/disable result where potentially used |
| Fees | Hook `dexSwapFeeOfVault(hook)` WAD; quote subject's seigniorage `p` WAD, including zero-oracle behavior |
| Nested recipes | Closed model/version, exact token-in/token-out direction, holder when relevant, and typed values listed below; never an opaque `bytes` value delegated back to a live SE |

A generic capture request must distinguish `(SE, tokenIn, tokenOut, holder, mode)`. The proposed upstream `(SE, asset, holder, mode)` shorthand is insufficient unless the missing direction is explicitly derived and validated. Use modes for ordinary conversion, ordinary buffering deposit, ordinary redemption and transition redemption; do not deduplicate distinct directions or operations merely by SE address.

Absent, failing, malformed, zero and successful provider results are distinct. ClaimLib `_readRate` requires exactly 32 returned bytes and a nonzero value for a nonzero provider (`:93-99`); absent provider returns zero in that helper, while held buffered shares separately require a provider (`:87-89`). Preserve branch-specific behavior. Do not evaluate an unused failing recipe or reject an unused provider merely because an aggregate capture visited it. All held legs are nevertheless rated before a swap, including legs other than input/output.

Do not capture synthetic gate/creation prices or expansion projections as evaluator inputs. Funded/live setup and supported routes are acquisition preconditions. Ordinary gate, first-bond, expansion and fallback behavior remain ordinary; frozen pricing deliberately selects the stipulated mint branch.

### Closed initial family payloads

The first increment may certify only these demonstrated shapes, with an explicit supported-route manifest:

1. **Direct pair contribution:** `pairEq = amount`; no SE conversion. ETH is only a configured ETH-to-WETH identity normalization for quoting, not an additional contribution or a conversion trade.
2. **Reviewed direct ERC4626 receipt model:** store wrapper identity, protocol receipt identity, underlying identity, wrapper issued supply `S`, held receipts `H`, booked underlying `L`, underlying total assets `A`, supply `V`, and exact model identity. For the existing `SimpleYieldERC4626` fixture, the model is:
   - `convertToShares(x) = x` if `V == 0 || A == 0`, otherwise checked `x * V / A`.
   - `convertToAssets(y) = y` if `V == 0`, otherwise checked `y * A / V`.
   - Its `previewDeposit` and `previewRedeem` call those respective conversions.
   - Wrapper backing is `H + convertToShares(L)` when `L != 0`, otherwise `H`. Do not cap booked backing by ambient cash.
   - Reuse `ReceiptBackedERC4626AccountingLib.sharesFromReceiptUnits` and `receiptUnitsFromShares`; their multiplication is checked native multiplication, not silently widened `mulDiv`.
   - Preserve the ordinary route table, zero-input rejection and zero-claim early return of `ERC4626StandardExchangeCommon`. Ordinary tuples have refund zero.
   - This certifies the named fixture model, not all ERC4626s. Immutable asset addresses affect runtime identity. Implementation must document the exact reviewed-code recognition mechanism; neither self-reported model tags nor one successful ratio probe are sufficient for production admission. Keep test-dependency identification in test setup; do not import the test vault into production code.
3. **V3 ordinary pair-to-SE deposit:** store SE, token0/token1, supply, exact `_totalVaultReservesForShareMath()` totals and minimum-liquidity input if the zero-supply branch needs it. Reuse `StandardExchangeConstantProduct._initialShares` / `_sharesForDeposit`, including zero-side cases and ceil-before/floor-after square roots. The ordinary preview returns zero refund. This route does not need a frozen pool curve, holder redemption, liquid-reserve policy, or a rebalance simulation.

Receipt anchors: `Receipt/ERC4626StandardExchangeCommon.sol:34-75,99-101,130-138`; `Receipt/ReceiptBackedERC4626AccountingLib.sol:19-30,45-80`; `contracts/test/stubs/SimpleYieldERC4626.sol:100-145`; `Receipt/ERC4626StandardExchangeInTargetExt.sol:12-18`.

V3 anchors: `V3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:21-43,64-74`; `V3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:299-395,624-640`; `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:16-64`; `V3/UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol:11-17`.

In the two required fixtures the output DETF leg is raw. The first increment must reject a configured buffered output requiring an unimplemented recipe, rather than silently descale its budget. Likewise reject unimplemented V3 conversion/redemption and unknown refund models when those operations are reachable. An unsupported capture is a named E3 blocker for that configuration, not permission to drop its entitlement or to change the reserve configuration.

## 3. Evaluator and rounding contract

`evaluateOriginal(snapshot, contributionIdentity, originalAmount)` returns pair-equivalent, gross and user DETF for diagnostics. `evaluateOriginals(snapshot, originalEth, originalDtf)` adds the two user amounts with checked addition. Zero component returns zero before any positive-amount route evaluation. Every component and entitlement starts with identical captured values.

For each positive component, in this order:

1. Run the captured ordinary contribution-to-pair route, or the direct identity. `_pairEq` ignores the conversion refund; non-share zero output is `InvalidRoute`, whereas share zero output reaches the hook's zero-input rejection. Do not validate a refund in this earlier call where canonical `_pairEq` does not.
2. `boosted = Math.mulDiv(pairEq, W + p, W)`, `W = 1e18`. Quote the hook's ordinary exact-input branch with manager zero and output DETF, not hook LP.
3. Preserve zero-input, same-token and index checks, then rate **all** legs in order. Raw/no-provider is raw; raw/provider uses `ratedPairUnits`; buffered zero shares is raw; held buffered shares require a provider and add rated shares to raw. Scale using stored scales and the existing checked multiplication.
4. Reject zero rated input/output, read captured fee, reject fee `>= W`, and call existing `applyTradingFeeNet(boosted, fee)` once. Map that **net** amount:
   - Raw input: identity or `mulDiv(net, rate, W)`, then scale.
   - Registered disabled SE: raw net, scaled; no nested deposit.
   - Enabled SE: exact ordinary `(shares, refund)` at net; validate `refund <= net`; add refund once to rated shares. Zero shares uses refund alone and skips the rate read.
5. Enforce max-in on mapped inflow, then existing `quoteExactIn(ratedIn, weightIn, ratedOut, weightOut, inflow, W, W, 0)`. Keep all original checked products and domain errors. Never apply the fee again.
6. Preserve `_outputBudget`: reject `budget >= ratedOut`; descale using stored rated scale. For raw output reject native output `>= rawReserves`, then reject zero output. For a supported buffered output, use local raw first, exact rated deficit, two `mulDiv` floors to shares, stored-share cap and the proper ordinary/transition redemption with zero refund. This last recipe is not certified by raw-output baseline tests.
7. Reuse `DETFMintSplitLib._splitLiveGross(gross, p)` and keep user only. User is `floor(gross * (W-p)/W)`, not `gross - floor(gross*p/W)`. A computed zero user result is not the same as a nested quote revert.

Source: `DETF/UniswapV4DetfCommon.sol:115-127,151-181,259-263`; `contracts/vaults/detf/common/core/DETFMintSplitLib.sol:19-26`; `Hook/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:39-99,136-168,401-407`; `Hook/UniswapV4StandardExchangeWeightedBufferHookMath.sol:48-104,197-216`; `contracts/utils/ExchangeInAmount.sol:15-22,41-50`.

Use the existing Balancer `WeightedMath`/`FixedPoint.powUp`, including general `LogExpMath` rounding, not a float or 50/50 surrogate. The V3 fixture's 0.3/0.4 exponent is `750000000000000000`. `Pricing/domains.md` explicitly did not execute that general power branch. Its hand-checked shortcut examples are useful unit vectors, not a proxy oracle.

Correction to `domains.md`'s "other legs' balances are not arguments": only two balances enter the final weighted call, but `ClaimLib:45,57-60` first rates the entire book. A failing provider on a third held leg can still make the quote fail. Also, gate/expansion reads are not necessary capture inputs merely because the ordinary entry preview uses them.

## 4. Dependency falsification matrix

These are source-backed closure conditions, not executed mutation tests.

| Changed live dependency after capture | Why an incomplete design fails | Required closure / status |
| --- | --- | --- |
| Hook swaps, donations, raw cash, SE inventory | Two ambient balances miss retained cash and attributed shares | Typed raw/share book; no hook reads during evaluation |
| Provider, subject supply, yield, underlying pool | `getRate` derives a whole-book or initial-deposit rate live | Capture the actual result in hook context. Reuse that primitive; do not call provider or `quoteRate` later |
| Hook fee / seigniorage | Changes net input, uplift and user floor | Two stored WAD values, with original order and invalid domains |
| Registry disable/re-enable or registration | Changes buffering versus raw-input branch | Captured registration/disable outcome; no evaluation-time registry query. Do not apply input disable semantics to output |
| Receipt assets/supply/cash or wrapper supply | Changes conversion and backing at arbitrary amounts | Exact typed reviewed model and captured state; unknown model blocks that route |
| V3 price, position liquidity, free funds or uncollected fees | Changes even a deposit-only share quote | Capture full share-math reserve totals, not principal-only/basic-vault reserves |
| ERC165 / transition provider | Changes ordinary versus transition redemption | Capture branch selection; execute typed state-only recipe. Existing live `quoteTransition(oldBytes, ...)` is rejected |
| V3 curve, fee, protocol-fee byte, unlocked state | Serialized header omits quoter pool reads | For swap/redemption routes only: complete sealed curve/header and exact ordinary/transition orchestration; not in initial allowed increment |
| V3 liquid-reserve policy / decimals | Transition rebalances and computes holderAssetsAfter | Freeze policy and metadata-derived constants; preserve even discarded-return computations that can revert |
| Morpho time, IRM, borrowed amounts, fee recipient | Expected market state accrues; redemption has liquidity constraints | Finite accrued state plus arithmetic offset is plausible, but this family is not in the initial route scope |
| Code/selector/route changes | Same address can select different logic | Bind reviewed immutable evaluation code and copied routes; never dispatch through future live loupe/registry/provider state |

The finite conditional V3 design in `dependencies.md` section 6.2 is credible as a design, not as measured feasibility: `lib/crane/contracts/utils/math/UniswapV3Quoter.sol:109-157,168-271` reads slot0, liquidity, spacing, fee, bitmap and initialized/boundary tick liquidity. `maxSteps == 0` is unlimited. Capture a complete compressed-tick interval plus edge guards and managed boundaries atomically; a sealed getter capsule can reuse this quoter unchanged. Preserve partial price-limit fills, projected boundary flips, protocol fee growth, withdrawal rounding, rebalance and initial/final holder valuation. Do not edit shared Crane or add a second approximate quoter. Actual image size/gas and its exact factory/sealing design remain unresolved before authorizing this conditional track.

For Receipt transition support, distinguish the captured original vault conversion used by `_syncQuoteBacking` from the simulated next-state vault conversion. Replacing the former with the latter changes ordinary behavior. Native nested SE state additionally requires a finite recipe for its named underlying, including share normalization and local-cash conversion. Bytes alone are insufficient.

Morpho `MorphoBlueStandardExchangeQuoteTarget.sol:20-129` captures expected market values but calls conversion helpers using `_offset()` from `MorphoBlueStandardExchangeCommon.sol:73-75,145-178`. That offset is missing from serialized state. Capturing it closes this particular read; it does not authorize adding ordinary liquidity checks or silently equating ordinary redemption with `_quotePay`.

## 5. Exact root authorization and edit boundary

Root may amend the same phase run with **one implementation-and-test node** for: typed capture; the demonstrated direct-pair/raw-DETF-output book; the reviewed direct receipt model and V3 deposit-only recipe; canonical arithmetic reuse; proxy differential, domain and freeze tests; explicit unsupported-route rejection. It may use the read-only baseline as evidence. It must not present that bounded increment as actual-configuration E3 closure until section 7 is satisfied.

The following are the exact candidate authored paths for that node. Root's amendment must name them; this report does not itself authorize edits beyond this file. No directory-wide wildcard is granted.

| Exact path | Allowed change |
| --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshotLib.sol` | New capture orchestration and original-component evaluation |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol` | New typed snapshot/result/error contract; no ancestry or surrender ABI |
| `contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol` | New closed typed family/direction/mode capture contract |
| `contracts/utils/StandardExchangeFrozenQuoteLib.sol` | New state-only tagged dispatch to existing receipt-accounting and constant-product math; exact reviewed receipt conversion operations; no concrete-vault calls/imports into ordinary DETF |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol` | New separate capture interface, leaving existing interface IDs intact |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol` | Read stored book and capture hook-context dependency outcomes |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol` | Expose aggregate capture read |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol` | Install new selector and advertise separate interface |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol` | Advertise capture interface in explicit package interface list |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol` | Narrow state-input pure helpers for rated units/input, budget and raw output; ordinary wrappers retain live reads and call order |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol` | Add typed ordinary-input capture read without changing existing transition semantics |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacetExt.sol` | Install the read on its actual preview/query facet |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol` | Advertise separate capture interface |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol` | Capture deposit supply/totals directly, without hypothetical holder redemption |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol` | Install typed read and advertise interface |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol` | Advertise separate capture interface |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol` | New real-proxy fixture composition and isolated capture-library exposure; no SUT replacement |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol` | New differential, freeze, unsupported-domain and proxy-surface tests |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet_IFacet_Test.t.sol` | Update existing exact selector/interface controls for the added read only |
| `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` | Implementation evidence: route/model manifest, captured integer vectors, source-read inventory, literal commands/exits and unresolved routes |

The isolated test exposure may be declared in the new TestBase file and deployed through the existing CREATE3 test factories. It calls the real capture library against the configured real DETF/hook/SE proxies and stores its own one-shot snapshot. It is not a fake hook, vault, provider, registry or fee oracle, and is not the final Migration package. Prove real selector routing on source proxies. Full Migration owner/removal/bootstrap wiring remains task 3/later composition.

This is smaller than taking every path in `dependencies.md` section 8. Ordinary receipt accounting already supplies pure share/backing conversion helpers; V3 already supplies pure deposit math. Do not refactor either entire Common contract or transition pipeline just to consume it. A new general state dispatcher avoids importing concrete vault implementations into DETF code. Do not move all ordinary quote reads into an eager captured-book wrapper: that can change error order, caller context and nonzero-manager behavior.

Excluded without a new bounded amendment: frozen V3 capsule/factory, V3 swap/redemption/transition refactors, Morpho capture, arbitrary receipt models, buffered-output family adapters, existing gold test rewrites, source/entitlement/activation/harvest storage or selectors. Also excluded: ordinary DETF Target/Common changes, rate-provider changes, fee/registry policy changes, `lib/crane`, `node_modules`, configuration/lock files, PRD/plan/incident evidence edits, commits and operational actions. If a required declaration control outside the exact list proves stale, return its exact path for a narrow amendment; do not weaken or skip it.

## 6. Test and oracle contract

### Real-proxy differential setup

Reuse the existing weighted ERC4626 and V3 gold bases and their factory/registry paths. They create actual hook/DETF/SE diamonds; the V3 base seeds real protocol-port pools and activates both SEs (`DETF/TestBase_UniswapV4Detf_Weighted.sol:89-169`, `TestBase_UniswapV4Detf_Weighted_Univ3Se.sol:43-66`, `TestBase_UniswapV4Detf_Weighted_ProdSe.sol:84-164`). Use declared 6/9/18-decimal variants from `TestBase_UniswapV4Detf_Weighted_Decimals.sol:43-63`; its comment saying DETF remains 18 decimals is stale. Actual DETF initialization is 9 (`UniswapV4DetfDFPkg.sol:234`).

Establish a funded live book using authorized fixture operations. The old first bond is fixture preparation, not proof of Migration donation bootstrap. No `vm.store`, SUT etching/subclass replacement, mocked hook/SE/provider, or impersonated hook/DETF funding.

At the same pre-mutation state, independently compose the canonical mint oracle:

1. For positive input, call real DETF proxy `peekPairEq(selectedVault, input, amount)` (`UniswapV4DetfQueryTarget.sol:235-238`); for zero, do not call it.
2. Read the real fee oracle's `p` for that DETF, apply the canonical `Math.mulDiv` uplift, call the real hook proxy's `previewExchangeIn(pair, boosted, detf)`, and use `DETFMintSplitLib._splitLiveGross`.
3. Capture and compare the frozen evaluator with this oracle, including pair-equivalent, gross and user. Shared primitives are intentional; independently acquired real-proxy results prevent a test that merely repeats the new snapshot formula.
4. In a naturally gate-open fixture, additionally compare the ordinary public DETF preview. In a gate-closed fixture, demonstrate that the frozen result equals the direct mint oracle, not the public swap fallback. Do not override the gate or modify production code to obtain the expected result.

Caller contexts must match the inspected implementations. The existing `peekPairEq` makes its nested call from the DETF; hook preview makes provider/SE calls from the hook. `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol:147-159,224-234` resolves fees by vault, then type/default fallback, not the evaluator caller. Capture the resolved values, not just per-vault overrides. The fixture fee/provider implementations are inspected deterministic sources, not a certification of arbitrary caller-sensitive bytecode.

### Required assertions

| Test obligation | Exact expected result |
| --- | --- |
| Both components, zero/one/two positive inputs | Native integer equality for every intermediate and final sum; two components and recipients always reuse identical S; reverse evaluation order agrees |
| Entitlement grouping | Separate originals sum already computed credits; a deliberately nonlinear vector differs from quoting the merged amount or re-quoting partial input |
| Fee/split floors | `1000 -> 1050` at p=5%; fee 0.3% gives net `1047`, not `1046`; gross 3 at p=50% gives user 1, pot 1, not user 2 |
| Weighted exponent | General 0.75 exponent through canonical library, plus equal-weight/80-20 controls; zero numerical tolerance |
| Max-in | Predicate is mapped inflow `> floor(ratedIn*0.3)`; equality allowed, next native input crossing the mapped boundary reverts; no chunking |
| Native dust and overflow | Rated budget `1e9-1` versus `1e9` at a 9-decimal raw output; computed zero user versus quote `ZeroAmount`; exact panic/revert data where reachable |
| Fee and p endpoints | Fee zero, below W and W; p zero and W; preserve ordinary successful-zero/revert distinctions, no clamping |
| Route/model failure | Unsupported direction/model/missing capture selector fails atomically; no partial snapshot, live fallback, dropped leg or fabricated zero |
| Registry branches | Capture enabled and disabled real registered SEs separately; later toggles cannot alter either snapshot; unknown registration remains an explicit unsupported capture/quote outcome |
| Receipt backing | Held receipts plus booked cash, differing receipt and input decimals, empty-state formulas, checked multiplication, zero-claim branch; no ambient-cash substitution |
| V3 input | Full reserve totals include unpoked fees and position amounts; canonical nonlinear deposit at exact net amount, not rate times input |
| All-leg rating | A relevant third leg is captured/rated despite not being input/output; branch-specific missing/failed-provider behavior retained |
| Capture immutability | Second capture fails; fields/hash unchanged; capture and evaluation change no source balances, allowances, supply, LP or reward state |

Exercise true production mutations after capture: hook trades/donations, underlying yield, V3 swaps/fee growth, SE deposits changing supply, fee/seigniorage updates and registry disable/re-enable. For each meaningful mutation, first prove the live primitive or canonical quote actually changed, then assert frozen outputs and snapshot identity remain bit-exact. Use a fresh fixture or explicit state restoration between independent mutations. Timestamp changes test frozen accrual independence, not sleep-based synchronization.

Trace evaluation separately from capture and the oracle. Its reachable external targets may be only immutable linked pure math (and, in a later authorized increment, sealed snapshot-owned data). No original hook, SE, provider, pool, fee oracle, registry, metadata or ERC165 query is permitted. A constant-output test with an ineffective mutation is not independence evidence.

For unsupported partial-refund families or buffered output, test exact hook arithmetic using supplied tuples only as a unit test, clearly labeled. That cannot certify a production nested route. End-to-end certification needs its actual adapter and real proxy fixture. Preserve `ExchangeInAmount` refund bounds and output-refund failure; do not invent a nonzero refund for the currently zero-refund fixtures.

### Ordinary behavior and final real-surface invocation

Preserve old selectors/interface identities, default live quote and execution routes, manager-zero and nonzero-manager behavior, caller/error order, 9-decimal DETF, gate/fallback selection, fee application, registry policy, buffered accounting, expansion/rewards, residuals and allowance cleanup. New capture selectors need facet declarations, package cuts, ERC165 and successful proxy invocation. Enforce EIP-170 sizes on changed facets/packages.

After actual source edits, one implementation node owns compilation. Use `scripts/forge-artifacts.py test` with every edited Solidity source as positional inputs and repeated exact `--test-root` arguments; the inspected helper builds affected artifacts first, then runs Solar tests (`scripts/forge-artifacts.py:370-441`). Include the new suite, both unchanged baseline suites, the edited V3 declaration test, and related existing hook/receipt/V3 regressions justified by the actual shared-helper changes. Record literal expanded argv and both build/test exits, not this prose as a run receipt.

The independent verification node must execute this proposed real-surface test on current artifacts:

```sh
forge test --use solar \
  --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol \
  --match-test '^test_MigrationSnapshot_RealProxyCaptureAndFreeze$' -vvvv
```

That named test must call capture on the deployed capture exposure, invoke the real source proxies, evaluate both originals, perform real mutations, and evaluate again. A library-only arithmetic harness or fallback-only test cannot stand in for it. The command/test is **proposed and unrun**, not an existing pass. It proves this task-2 library increment, not final Migration lifecycle integration or E4.

All later commands must explicitly `cd` to this worktree, create their own `pricing-NODE.XXXXXX` root under the phase parent, and export `TMPDIR`, `NODE_COMPILE_CACHE`, `BUN_RUNTIME_TRANSPILER_CACHE_PATH` and the selected nightly Forge PATH. Start long commands under monitor subscriptions, retain exit/log receipts, preserve warm artifacts and shared links, and never cancel a quiet cold compile.

## 7. Unresolved facts and exit criteria

- Actual Migration reserve and both original-contribution routes are not pinned by the initial fixture reports.
- Exact production receipt implementation/model recognition is not supplied. The SimpleYield model is a hermetic dependency model, not a production-vault endorsement.
- New capture selectors and raw-reserve accessibility must be demonstrated on newly composed real proxies; source edits cannot add selectors to already immutable deployed instances.
- No primary-mint original-input/freeze differential suite has run; no general-exponent numeric oracle was executed by the domains node.
- Runtime sizes, incremental regression results, capture storage/gas and complete evaluation call-trace independence remain implementation evidence.
- Buffered output, V3 conversion/redemption, native nested receipts, arbitrary refund implementations and Morpho are not certified by the initial allowed increment. Add only the actually needed bounded recipe, or report the exact unsupported configured edge.
- Full V3 curve acquisition remains a conditional gas/storage/atomicity question. A finite design is possible; its feasibility on every possible pool is not asserted.
- Fungible ancestry and TokenStaking remain owner/mechanism questions outside pricing. They are not prerequisites for this bounded quote work and cannot be answered by it.

Root can authorize the section 5 node now as corrective engineering, with these blockers in its acceptance ledger. To turn this handoff's needs-fix into actual pricing readiness, the implementation evidence must name the selected supported configuration/model, prove complete typed capture and canonical parity on it, show post-capture dependency independence, and pass ordinary regressions and proxy routing/size checks. Unknown actual bindings cannot be relabeled as supported. No additional unchanged-baseline build is missing.

## 8. Review checks, cleanup and DoneClaim

Applicable rules read: worktree `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and coding/deployment/testing documents, relevant `INDEXEDEX_AGENT_LAW.md` DETF/testing law, and canonical Crane architecture/deployment/testing plus IndexedEx testing skills. Source inspection covered the actual mint, hook, receipt, V3, provider and conditional Morpho paths cited above.

The Solidity LSP references request for `previewSwapExactInContext` timed out; no successful LSP analysis is claimed. Literal source search and direct reads established its standard-preview and manager-context callers. An initial wrong WeightedMath path returned ENOENT; the import was followed to `lib/crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol`, whose actual rounding code was read. A combined log search failed and a large-log prefix search was incomplete; direct reads of the actual suite-end and trace ranges supplied the evidence above. None is a test failure. The authored handoff was read back in full; its edit table contains 20 unique exact paths, its verdict and AdversarialVerify are explicit, and its text is ASCII. This was a document audit, not a Solidity test or successful LSP diagnostic.

Owned runtime root:

`/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-handoff.y0qI48`

It was created using the required `mktemp -d` template. Command environment used this root for TMPDIR, `/node-cache` for NODE_COMPILE_CACHE, and `/bun-cache` for BUN_RUNTIME_TRANSPILER_CACHE_PATH, with explicit worktree cwd. Read/search work used the same session environment. No persistent process, child, monitor, server or port was created.

Cleanup read-back at `2026-11-10T14:13:14.043Z`: the owned directory was empty; `rmdir` exit 0; `test ! -e` exit 0; owned persistent processes 0; owned ports 0. `out` and `cache_forge` remained directories. `lib/crane` still resolved to `/Users/cyotee/Projects/indexedex/lib/crane`; `node_modules` still resolved to `/Users/cyotee/Projects/indexedex/node_modules`. No shared cache or other lane's root was removed.

**DoneClaim:** authored only `docs/incidents/2026-09-16-dtf-recovery/migration/pricing/implementation-handoff.md`. Checks are document/source/receipt inspection, not new execution. Baseline build and eight tests are accepted from inspected existing evidence. The initial handoff returns **AdversarialVerify** with verdict **needs-fix**, concrete conditional blockers, exact root authorization boundaries and the required implementation/oracle contract. This is not task-2 completion.
