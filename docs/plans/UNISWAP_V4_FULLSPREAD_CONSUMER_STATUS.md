# FullSpread consumer rehoming status

## Latest residual compatibility and verification checkpoint

This section supersedes the older failure counts and performance investigations
below. Final combined QA and five-part independent readiness review are pending.

- Artifact loader scratch compaction passed an independent bounded source review
  and all **13** loader tests, including recursive links, source identity, retained
  caller memory, and repeated-load allocation bounds. It reuses unreachable JSON
  scratch; it does not lower the peak of simultaneously live recursive inputs.
- The real Orbital Pons-v2 product-law suite passed **56/56**, including blocked
  sub-share retention, repeated sweeping, and rejection of unpaid pretransfer.
  Together with the loader: **69 passed**, evidence `tool_0ef425ffd001jJ7nvA0S8ihypf`.
- Preserved V3/Pons consumers now prove zero issuance from a successful full-input
  SE preview when ERC-165 explicitly reports no exact-quantity interface. A failed
  probe is not retention evidence. FullSpread continues using the opaque current
  snapshot's supported inverse; idle inverse rejection remains unsupported.
  All **458** Orbital Pons-v1/mixed-Pons tests passed, including funded later retry.
- Three Quad mixed-Pons D22 failures were exhausted fixture trading inventory:
  the preferred pair's mint gate closed while another pair remained open. Opt-in
  fixture preparation now uses a separate genuinely bonded/claimed/unstaked trader
  and trades against freshly quoted open pairs. All three D22 cases passed with
  the original global mint-gate and exact redemption assertions intact.
- The subsequent broad run passed **12,044**, failed **5**, and skipped **0** across
  482 suites (`tool_0f04f33c8001j57LDjyfysbkEX`). All five were residual proof
  assertions, not failed bonds. They were then corrected and passed focused runs.
  In P18/R6, the full residual previews positive SE shares, unbalanced hook joining
  previews zero LP, and the single-asset join's selected sale leg rejects with the
  exact alignment error. The assertion now follows execution's mode order and
  does not accept arbitrary hook failures or a positive unbalanced quote.
- Added/extended H6 and P18/R6 regressions verify actual alignment rejection,
  unsupported idle inverse, booked custody, no issuance on repeat sweeps, and later
  funded retry. P18/R6's base T7 and new selected-alignment regression both passed.
- Latest H/P artifact checks have no failures; **39/39** consumer runtimes meet
  EIP-170 (`tool_0f0bd17f3001qD7VcNzCVIK0hT`). Tight margins remain: H OutFacet
  24,571 bytes; P OutFacet 24,540; Single CP SE facet 24,526.

The atomic residual self-call rolls back zero-LP attempts while removing the
duplicate successful-path preview. CurveQuad reuses its immediately preceding
single-leg buffering quote; multi-leg quotation stays sequential. Together with
the conservative alignment prefilter, focused CP and Quad burns now pass the
original 30M gates (roughly 17.4M and 24.8M respectively). Fresh combined QA will
record the final measured values. The prefilter's one-unit placement-rounding
bound received an independent bounded PASS; final certification remains in place.

No blanket `InvalidRoute` catch, larger donation allowance, relaxed alignment
guard, or newly supported idle scalar inverse was introduced. The new self-only
`joinResidualAtomic(address,uint256,bool)` brings the DETF surface to 47 selectors;
the maintenance facet exposes eight. Readiness and owner-gated retirement remain
pending the combined evidence and independent review findings.

## Direct resumed verification checkpoint

### Latest owner-ruling implementation and verification

The Quad burn now reports its actual individual execution cost too: **52,748,964
gas**, failing the unchanged 30M test gate and the observed 32M chain cap. Its
trace (`tool_0eebecb09001LZJ4UaE7gdXmKv`) attributes about 47.66M to the post-burn
residual sweep. For each of two roughly 2.30-token residuals, the same SE
composition is quoted repeatedly: direct unmintable-dust detection, the DETF's
unbalanced-join preview, the hook's own join quote, and its buffering minimum,
before the actual exchange. This is the next performance target; omitting guards
or raising test limits is not an accepted fix.

Follow-up optimization reuses the immediately preceding CP residual-buffer quote
as the execution minimum instead of computing that same composition twice. The
measured CP burn dropped from 35,781,321 to **31,331,932 gas**. It is below the
previously observed 32M chain cap but still fails its unchanged **30M** test gate;
do not report that lifecycle test as green. All **39 concrete consumer runtimes**
passed the latest checker after artifact refresh; Single CP SE has only 50 bytes
of EIP-170 headroom.

The optional Orbital minimum-input search hint was experimentally tested but did
not resolve the nested donation failure. It was removed and its affected artifacts
were rebuilt. No speculative search fallback remains from that experiment.

Fresh independent-review delegation timed out without returning a verdict. Review
readiness is therefore still unmet. Existing earlier bounded reviews do not cover
the later owner-approved residual changes.

The owner selected **retain and sweep later** for alignment-rejected residuals
beyond the existing donation allowance. DETF residual sweeps now retain and book
that capital, catch only the exact alignment-domain error, clear any attempted
hook allowance, and retry in future calls. The existing native dust floor applies
before another ratio zap. CP hook post-operation residual rebuffering likewise
treats that specific failure as its existing unmintable-residual case; public
deposit quotes and primary execution still enforce all limits.

`test_alignmentResidualRetainedBookedAndRetried` verifies retained custody,
unchanged SE backing, exact reserve booking, and a later quote attempt over the
accumulated amount. The six-decimal CP product-law suite passed all **53 tests**
after updating its residual assertion to require both the exact alignment error
and full booking rather than clearing mathematically unjoinable capital.

The complete seven-hook matrix passed **74/74 tests** on the updated fixture and
consumer code. Latest broad `prod-se` run: **11,806 passed, 20 failed, zero skipped**
across 482 suites; evidence `tool_0ee0180310014UbK7NHRMmKfqw` under the OpenCode
tool-output directory. These twenty failures remain a failed acceptance gate,
not an approved exclusion list.

Quad mixed-Pons setup now isolates production-SE artifact loading in a self-only
test helper call, preventing its JSON/linking scratch allocation from exhausting
the later hook setup frame. Its focused lifecycle suite passed **4/4**. A later
cached multi-suite run failed setup again; a fresh `--no-cache` run passed **4/4**,
so final combined cache/linking validation is still required.

One CP burn failure was measured without suppressing the acceptance assertion:
**35,781,321 gas** for the individual operation, which fails the retained 30M
test budget and exceeds the previously observed 32M chain cap. This is a real
remaining consumer liveness blocker, separate from the passing underlying SE
repair gas tests. The test now reports the actual operation cost rather than
only a nested out-of-gas revert. No gas limit was increased to pass acceptance.

Other remaining clusters include the Orbital Pons nested-donation quantity
projection, a few retained-residual assertions, and Quad/CP lifecycle execution.
No final independent review, audit readiness, legacy retirement or post-removal
validation is claimed.

### Subsequent broad consumer evidence

The matrix fixture now supplies 500,000 units of real external liquidity so the
existing 500-token donation success cases fit the unchanged composition impact
limit. Eight focused donation/router tests passed. The Balancer-quad H row uses
its supported unbalanced exact-input join for positive lifecycle/rollback checks
and separately asserts that the idle proportional join's exact-share dependency
rejects atomically; all eleven tests in that row passed.

Broad artifact-first consumer verification initially produced 11,203 passes and
898 failures across 496 suites (log `tool_0ec57a7e30010cqF538ESIvYMP` under the
OpenCode tool-output directory). A representative one-wei residual failed in
DETF maintenance because the SE now reports alignment failure rather than zero.
The sweep now recognizes only that exact error for its existing independently
bounded sub-ten-share donation rule, and observes its existing ten-native-unit
residual floor before attempting another ratio zap. Other errors still bubble.
The 18-decimal and all-six-decimal representative D15 tests passed afterward.

Latest `prod-se/**/*.t.sol` run: **11,615 passed, 210 failed, zero skipped**, 482
suites, log `tool_0ec902ee7001SGvE9LnCOAChzo`. This is not consumer closure.
Remaining failures include CP decimal residuals, nested Orbital Pons donations,
several lifecycle routes, and nine Quad PonsMix setup MemoryOOG failures.

Concrete unresolved ownership boundary: `UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6`
`test_D15_1_previewEqualsExecute` leaves 28 raw pair units. FullSpread rejects
depositing them with AlignmentNotAchievable; the reverse ten-share quote returns
16 raw units, so the existing donation allowance cannot cover the remainder.
The trace is `tool_0eca21b620014ZQJAeuB3t3lyF` (not a claim every remaining
alignment failure has that cause). Do not increase that allowance, weaken the
SE's one-bp bound, or discard the residual as an implicit remediation.

The parent resumed verification directly when delegated continuations stopped
recording activity. Artifact-first family validation passed **313 tests**;
existing rate-provider compatibility controls passed **33 tests**. The generic
context helper now uses the optional exact-output quantity surface for withdrawals
and exposes projected exact-share input amounts. Passthrough public exact-output
previews use those quantities. Its facet loader now passes its CREATE3 factory
to `ArtifactCreationCode` for required library linking.

After these fixes, `FullSpreadSameManagerConsumers.t.sol` passed **36/36 tests**
across all six H/P ordinary/native/mixed-decimal suites. No formula, funding guard,
or quote-parity assertion was weakened.

The subsequent seven-row matrix result was **65 passed, 8 failed, 0 skipped**:
four large-resting-donation joins hit alignment protection; Balancer quad has
three remaining inverse/domain failures; Weighted's raw-output reserve test
incorrectly demanded an unchanged raw trading reserve. That last assertion has
now been corrected to require the reserve decrease to equal the exact payout,
while keeping the unchanged-dust check for the buffered output. This edit still
requires a passing rerun.

Matrix evidence: `/Users/cyotee/.local/share/opencode/tool-output/tool_0ebdfd33e001EXzAmSgltr8gfz`.
Further PM exact-output call-site integration, matrix remediation, broader DETF/
script regression closure and final independent review remain required. Legacy
removal is still gated; this checkpoint does not declare audit readiness.

## Bounded consuming-hook runtime closure (2026-09-28)

**Runtime extraction completed; writer returned to the parent.** This supersedes
the four over-limit size observations below, not the separately owned nine matrix
failures or the pending context/quantity/rate API integration.

| Concrete facet | Before | After | EIP-170 headroom |
|---|---:|---:|---:|
| Weighted Hooks | 25,062 | 23,084 | 1,492 |
| Orbital Hooks | 26,913 | 23,656 | 920 |
| Orbital SE | 25,364 | 21,925 | 2,651 |
| CurveQuad Hooks | 24,636 | 22,500 | 2,076 |

Affected siblings also fit: Weighted SE **22,480**, CurveQuad SE **21,921**.
The existing checker inspected **all 39 concrete consumer facets/packages** with
**zero failures**. Source-declared abstract InitFacets alone were excluded; no
meaningful zero runtime was accepted. Linked ClaimLib runtimes are Weighted
**14,460**, Orbital **9,846**, and CurveQuad **13,847** bytes.

### Narrow source change

The exact-input view coordinators and their valuation helpers now execute through
the existing family-specific ClaimLibs. Thin target wrappers retain their original
arguments and `(amountOut, sharesOut)` results. Orbital's existing composed-input
search was moved unchanged into its ClaimLib. No equation, rounding, floor, cap,
context-manager choice, fee lookup policy, min/max guard or economic route was
changed. No selector/interface array or FactoryService was edited. Linked artifact
loading and the existing CREATE3 fixtures were retained.

The six production files changed by this bounded task, with final SHA-256:

| Path relative to `contracts/hooks/uniswap/v4/standardExchange/` | SHA-256 |
|---|---|
| `weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol` | `425348c38646ea1d5966d5d2ca82570ad0f6d3fd277175b00fdda3f2f3a92f9f` |
| `weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol` | `82bc68de6b6e4bfadb3fa8e6100d380938328b10b1424c6e34df19923dce4587` |
| `orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol` | `e1fba75f37ea8f8b2f647e4f6575f57b3732ae835e2cf0cca18609a66632f6c5` |
| `orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` | `34a1841330d176a3f2cc3fa2438694a7fe73aa90bea3b7b27f7d3cb60175dfc8` |
| `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol` | `ee30653832706e78c4b6fa612f153dd631efb68083e56242e7a2f604efe070e2` |
| `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget.sol` | `421657fe7f9755396854a1431d616460ad072a96377a8ab4736f37fe125fdec0` |

### Executed validation

- File-level diagnostics: no errors for the six changed production files.
- `scripts/forge-artifacts.py build` on those six sources: successful, followed by
  `python3 -B scripts/check-fullspread-consumer-artifacts.py`: **39 checked, 0 failures**.
- `scripts/forge-artifacts.py test` on the same sources, with nine exact test roots:
  each of weighted, orbital and CurveQuad's existing `Swap.t.sol`,
  `OwnerDuringLock.t.sol`, and `SeBufferAbi.t.sol` suites (full family filename
  prefixes). Result: **74 passed, 0 failed, 0 skipped, 9 suites**.
- The consumer runtime checker ran again after tests and passed. ClaimLib size
  checks also passed. No test assertion, selector, compiler setting or code-size
  flag was removed or relaxed.

Exact expanded commands, exit codes, hashes and size rows:

`/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode/consumer-runtime-kzkhgytx/result.json`

Full build/test/checker output:

`/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode/consumer-runtime-kzkhgytx/output.log`

The first successful size-only run is retained in sibling directory
`consumer-runtime-1hcrzkfo/`.

This is not a green FullSpread economic matrix claim: the nine findings below
were not fixed or reclassified by this task. H/P family trees,
`UniswapV4SeBufferHookContextQuoteLib`, and StandardExchangeRateProvider were not
edited. No commits, broadcasts, live actions, cache clearing or source deletions
occurred. Single-CP SE remains narrowly under the limit at 24,526 bytes and must
be rechecked after the next reserved-context changes.

The detached runtime worker exited normally; no build/test remains scheduled by
this worker. The parent may give the next serialized compiler slot to the API worker.

## Compiler release / Oracle handoff (2026-09-28)

**Edits to context/rate consumers are paused at the parent's request. The sole
compiler writer is released.** The detached matrix job completed normally;
there is no consumer Forge/solc job left running. No compiler was killed.
This is a failing integration handoff, **not** phase-4 completion or readiness.

### Latest completed results

| Gate | Result / evidence |
|---|---|
| H/P optional unlock-context gate | **14 passed, 0 failed**; `.scratch/fullspread-context-gate.log`, exit 0. |
| Initial arithmetic + same-manager suite, before context integration | **32 passed, 2 failed / 34**. Both failures are mixed-decimal CP consumer sequences; historical result, not current-tree certification. |
| Latest artifact-refreshed seven H matrix rows | Production and test compilation succeeded. **55 passed, 9 failed / 64**, no skipped; `.scratch/fullspread-consumer-matrix-6.log`, exit 1. |
| Consumer EIP-170 inspection after that build | **39 concrete facet/package runtimes inspected; 4 over limit**. Abstract InitFacets are excluded by source declaration, not waived. |
| Offline Python | **37 inventory/config + 19 shell fake-CLI sequencing tests passed**. No actual transaction submission. |
| Shell syntax | Five relevant entrypoints passed `bash -n`. |

Matrix breakdown: Orbital **10/10**; Single-CP **9/10**; Dual-CP **9/10**;
Weighted **11/13**; CurveQuad **9/10**; BalancerQuad **7/10**; non-CP single
fails setup (**0/1**).

Remaining concrete matrix findings:

1. Non-CP single setup: `ArtifactCreationCode: linking requires factory ...HookFacet`.
   Root: `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol:29-31`.
   `deployProductFacet(create3Factory)` still uses the factory-less
   `ArtifactCreationCode.creationCode(string)` overload, but its new contextual
   query dependency is linked. Pass the already available factory through the
   loader on resumption; do not suppress the loader check.
2. Single-CP, Dual-CP, Weighted and CurveQuad
   `test_row_bufferFirst_restingFace_notPaidToJoiner` hit
   `AlignmentNotAchievable()` (`0x4735ea42`). The inherited large-resting-donation
   case needs a domain-specific disposition/positive control, not removal or a
   relaxed H protection. No assertion has been deleted.
3. BalancerQuad buffer-first, preview/execution and failure-injection tests hit
   `InvalidRoute`; the failure-injection case sees that before `DependencyRejected`.
   These need tracing of the exact join/inverse boundary; no speculative fallback
   has been applied.
4. Weighted PM row fails `no output dust subsidy`. The shared test helper currently
   also applies a flat-balance dust check to the **raw output reserve**, which
   legitimately decreases by its payout. Correct the observer's raw-versus-buffered
   accounting; retain the buffered 10-wei bound and exact payment assertions.

Over-limit runtimes: Weighted Hooks **25,062**; Orbital Hooks **26,913**;
Orbital SE **25,364**; CurveQuad Hooks **24,636** bytes. Single-CP SE is **24,526**
and Weighted SE **24,532**, both close to the limit. The already-applied extraction
improved other facets, but the new context wiring added size; further linked-library
extraction remains required. Checker: `python3 -B scripts/check-fullspread-consumer-artifacts.py`.

### Exact context/rate API issue for the Oracle/P worker

Existing selectors (computed locally from canonical signatures, no deployment):

| Signature | Selector | Source |
|---|---|---|
| `quoteStateWithUnavailableUnlock(bytes,address)` | `0xb90a9cec` | `contracts/interfaces/IStandardExchangeUnlockContextQuote.sol` |
| `quoteState(address,address)` | `0x844c633c` | `contracts/interfaces/IStandardExchangeTransitionQuote.sol` |
| `quoteAssets(bytes,uint256)` | `0xdedbf308` | same transition interface |
| `quoteTransition(bytes,uint8,uint256)` | `0x2fb41732` | same interface; enum canonical ABI type is `uint8` |
| `getRate()` | `0x679aefce` | configured rate provider |
| `quoteRate(address,address,bytes)` | `0x69a3d621` | `IStandardExchangeRateQuote` in the transition-interface file |

Minimal required **capabilities**, with candidate names for Oracle adjudication
(not implemented/approved ABI declarations):

1. `quoteDepositExactOut(bytes state,uint256 sharesOut) -> assetsIn`: selected
   snapshot asset into exact SE shares, including ordinary route fees/rounding.
   Blocked F1 is valid; idle R4 stays `InvalidRoute`. No numerical inversion.
2. `quoteRedeemExactIn(bytes state,uint256 sharesIn) -> assetsOut`: ordinary
   quantity-preview domain/cover checks at the supplied state, independent of the
   snapshot holder's current share balance. This is **not** a redefinition of
   the existing cover-independent inventory valuation `quoteAssets`.
3. `quoteWithdrawExactOut(bytes state,uint256 assetsOut) -> sharesIn`: ordinary
   output inverse at the supplied state without requiring the passthrough wrapper
   to own shares before funding. Retain linear-only eligibility and reject any
   positive opposing backing; no F3 substitution.

These may be combined into a smaller optional amount-query ABI if the Oracle
chooses. Keep the existing transition enum/interface ID unchanged. Consumer code
must not decode or patch the opaque snapshot, synthesize ownership by swallowing
errors, search for an inverse, or fall back to idle context.

Family-local implementation touchpoints for the P worker:

- H root: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`;
  `UniswapV4FullSpreadHooklessStandardExchangeVaultInQueryTarget.sol`:
  `quoteAssets`, `quoteTransition`, `quoteStateWithUnavailableUnlock`;
  matching `InQueryFacet.sol`, `DFPkg.sol` declaration controls.
- P root: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/`;
  matching `UniswapV4FullSpreadPonsFamilyHookInQueryTarget.sol`, `InQueryFacet.sol`,
  `DFPkg.sol`, separately implemented under the same approved laws.
- Both family `Common.sol` implementations: `_inventoryAssets`, `_inventoryRedeem`,
  `_linearExitPlan`; `OutBase.sol` for ordinary exact-share issuance quote semantics.
- The existing `quoteTransition(WithdrawExactOut)` checks `amountIn > q.shares`.
  That is correct for a holder transition, but is not a funding-independent amount
  preview for a passthrough wrapper whose pre-funding balance is zero.

Rate discrepancy root:
`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:45-58,61-112,148-161`.
Live `getRate()` calls `_getRate("")`; projected `quoteRate` calls `_getRate(state)`.
The former probes `previewExchangeIn`; the latter probes `quoteAssets`.
Live cover failures halve the probe quantum; inventory valuation intentionally
does not enforce that same cover. The two rates can differ at otherwise matching
blocked state. H `Common.sol:168-177` documents cover-independent inventory value;
do not change that law merely to make the provider test pass.

Consumer touchpoints waiting for the resolved ABI/policy:
`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol`
(`snapshot`, `deposit`, `redeem`, `redeemReceived`, `withdraw`, `rateFromState`, `rate`);
Single-CP and Dual-CP ClaimLib input-gain helpers; per-family PM public quote
wrappers versus ordinary direct/owner plans. The four DETF owner-domain quote
calls have already been routed through ordinary hook SE previews, not PM previews.

### Exact reproduction commands

```bash
# Source/artifact refresh and the seven current rows:
python3 -u .scratch/run-fullspread-consumer-matrix.py

# Recorded mixed-decimal rate discrepancy. The new wrapper loader issue above
# must be fixed before this reaches the same body on the current source tree.
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadSameManagerConsumers.t.sol \
  -- --match-contract '^HooklessMixedDecimalsSameManagerConsumersTest$' \
     --match-test test_sameManager_realOwnerEiBothDirectionsBothUnderlyingFaces -vvvv
```

Original failing trace retained at
`/Users/cyotee/.local/share/opencode/tool-output/tool_0ea58c477001jiuIWP6kIoB6zS`;
lines 18225-18367 show live probe halving, rate return, zero rated gain, and
`InsufficientTokenOut()` (`0x3dec0665`). The analogous P mixed-decimal test failed
in the same initial run. No full DETF prod-SE, fork-source/script compile or
broad sibling-control gate has yet completed in this consumer pass.

## Current validation checkpoint (writer released)

The parent explicitly released the compiler writer to the consumer worker. The
earlier paused sections below are chronological records, not current completion
claims. All original source-preparation blockers 1-6 have now been addressed in
source: single-CP duplicate paths, dual-CP plans and sequential quotes, Balancer
quad, non-CP positive-inverse guards, seven H-specific matrix leaf overrides,
real rejecting-token failures, same-manager H/P production-wrapper and CP owner/
SE/PM tests, and explicit DETF primary/fallback gate cases. No historical suite
was deleted and generic matrix behaviors remain unchanged.

Validation is **not green yet**:

- First artifact-first production build found an Orbital SeTarget stack-depth
  error. Extracting `_finishSwap` fixed it; the subsequent 80-source compile
  succeeded with the unchanged compiler/optimizer settings.
- First focused run: **32 passed, 2 failed, 0 skipped, 34 tests**. Four independent
  arithmetic tests passed (16 fuzz runs for the fuzz case). H/P ordinary/native
  same-manager consumer cases passed. Both mixed-decimal CP consumer sequences
  failed in the PM EI leg after projected-rate probing produced zero rated gain.
  Reproducer: `FullSpreadSameManagerConsumers.t.sol`, contract
  `HooklessMixedDecimalsSameManagerConsumersTest`, test
  `test_sameManager_realOwnerEiBothDirectionsBothUnderlyingFaces`, `-vvvv`.
- The initial seven-row compile exposed stack depth in the test fixture's
  observation digest. Its observer calculations were split into smaller helpers;
  no assertions were dropped.
- Runtime inspection found six over-limit concrete facets (Weighted Hooks/SE,
  Orbital Hooks, CurveQuad Hooks/SE, BalancerQuad SE). Quote calculations are being
  moved into each existing family-specific linked ClaimLib; no code-size limit,
  configuration or formula waiver was introduced. The checker now excludes
  source-declared abstract InitFacets, whose zero runtime is not deployable code.
- Offline Python: **37 inventory/config checks and 19 fake-CLI shell sequencing
  checks passed**. The latter exercise no actual Forge process or RPC writes.
  All five changed/relevant shell entrypoints passed `bash -n`.

### Required context integration discovered during validation

The parent supplied the independently implemented optional
`IStandardExchangeUnlockContextQuote` and the
[context addendum](UNISWAP_V4_FULLSPREAD_CONTEXT_QUOTE_ADDENDUM.md). Historical
270-test H/P results predate that extension; a detached artifact-first context
gate **passed 14/14 tests** via `.scratch/run-fullspread-context-gate.py`, logging to
`.scratch/fullspread-context-gate.log` (`CONTEXT_GATE_EXIT_CODE=0`). Prior matrix runs are retained as
`.scratch/fullspread-consumer-matrix{,-2,-3}.log`; none is a green matrix gate.

Generic integration uses
`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol`.
It discovers the optional interface, keeps snapshots opaque, projects only the
specified manager, and propagates advertised projection/transition errors.
PM-facing EI preview boundaries select this context for both input deposit and
output redemption and for state-aware provider valuation. Direct SE/owner
execution remains on the actual context. The four direct DETF owner-domain quote
calls now use the reserve hook's ordinary `IStandardExchangeIn.previewExchangeIn`
surface rather than its PM-facing `previewSwapExactIn`; no DETF gate, curve,
fee, supply unit or primary-burn rule was changed. Existing composed owner quotes
retain their supplied post-exchange state.

**Coordinated API gap:** PM-facing genuine EO with a buffered input and raw output
needs blocked F1 exact-share issuance, but the transition enum has no
`MintExactOut`. The consumer worker requested a narrow optional opaque-state
exact-share amount quote from the parent. It has not decoded the snapshot,
invented a numerical inverse, or silently disabled that supported route. This
contextual EO integration and subsequent fresh tests are still pending.

There is a second concrete projected-rate constraint: the current standard rate
provider's live `getRate()` probes `previewExchangeIn`, while `quoteRate(state)`
probes `quoteAssets`. The latter deliberately values inventory without local-cover
enforcement. On the blocked mixed-decimal reproduction, the live probe halves to
a smaller payable share quantum than the projected probe, producing different
rates and then a zero projected input gain. No rate value or assertion has been
relaxed to hide this. The parent has been given the quantity/context API evidence
for coordinated resolution. A passthrough wrapper's contextual linear EO query
also needs funding-independent quantity semantics, since it owns no reserve
shares before receiving the caller's input.

Mainnet backend export now includes `uniV4PonsSeHook` from
`ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`, alongside the exact H/P package-name metadata.
Testnet does not fabricate P fields. No frontend or address artifact was edited.

## Latest hook-routing handoff: edits paused for parent validation

2026-09-28, after Oracle session `ses_f17545a03ffea1Tewyo4hwVmmS` authorized
consumer-route changes. This section supersedes the earlier checkpoint's
"no consuming-hook economics edited" description. **The full hook/consumer
closure is not complete.** The parent requested a stable prepared tree rather
than more edit-triggered diagnostics while the gas worker owns the artifact
writer. No compiler, Forge, solc or LSP command was invoked by this consumer
worker or its read-only research agents. Two attempted implementation-agent
launches failed before starting; they made no edits.

### Prepared economic changes (uncompiled)

All paths below start at `contracts/hooks/uniswap/v4/standardExchange/`.

| Touchset | Prepared behavior |
|---|---|
| `weighted/UniswapV4StandardExchangeWeightedBufferHook{ClaimLib,HooksTarget,SeTarget}.sol` | EI carries `ExactInOutput(amountOut, sharesOut)`. Curve output is rated inventory, converted conservatively through rate and share decimals; forward SE redemption quotes the face payout. PM/direct/owner EI redeems those shares, measures recipient payout, and enforces the quote/minimum. EO previews validate the output inverse and input exact-share inverse before funding; rated caps use the share debit rather than the face payout. |
| `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook{ClaimLib,HooksTarget,SeTarget}.sol` | Same EI share-plan separation. Removed `bufferInputForShares` doubling/bisection rescue: unsupported SE inverse propagates. EO output inverse and input inverse are checked in preview, before pulls/takes. |
| `orbital/UniswapV4StandardExchangeOrbitalBufferHook{Common,SeTarget,WithdrawTarget,ExitQuoteLib}.sol` | Retains existing `sharesForNativeUp` rounding as explicitly directed. Carries both results of `previewUnwrapForEffectiveOut`; validates spendable-share cap without clamping. PM/direct/owner/internal-zap/residual-withdraw EI redeems known shares, measures output and checks bounds. EO no longer clamps an over-budget inverse; its input-side inverse eligibility is checked before the existing composed input solver. Sequential `ExitQuoteLib` uses `RedeemExactIn(shares)` and refreshes the projected output state before subsequent swaps. |
| `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook{Math,ClaimLib,SeTarget}.sol` | Added decimal-aware floor share-budget and ceil rated-debit arithmetic. Active SeTarget PM/direct/owner EI paths carry the share plan and use measured forward redemption. True EO validates output/input inverse eligibility before funding; SeTarget no longer falls back from EO to a clamped EI redemption. **Independent deposit/withdraw/monolithic copies remain outstanding below.** |

No family-specific H/P names, addresses or F3 fallback were added to generic hook
economic paths. Held-reserve valuation remains balance/rate based; SE liquidation
quotes are used only for the specific planned payout. No DETF money-path, primary
burn, price-gate or nine-decimal unit change was made.

### Prepared regression additions

- `test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadHookShareBudgetMath.t.sol`:
  independent 6/18 and 18/28 decimal controls, nonunit rates, zero-rounded share
  spending, conservative EO debit and bounded fuzz reference.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`:
  added `test_consumer_halfBookSleeveIsActuallyFunded`,
  `test_consumer_exactInputUsesShareBudgetNotTwoLegInverse` and
  `test_consumer_unsupportedExactOutputRejectsBeforeFundingBothDirections`.
  These use the real H fixture/hook, measure SE share debit and supply burn,
  restore the same state to check the inner EI quote, and require the standard
  EO domain error for an unfunded/no-allowance caller. They are **not executed**.
  This is separate-manager H coverage, not same-manager blocked H/P coverage.

### Exact remaining blockers -- do not call this release-ready

1. **Single-CP duplicate implementations:**
   `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol`,
   `...DepositCommon.sol`, `...DepositPreviewTarget.sol`, and `...WithdrawTarget.sol`
   still contain old face-output/EO inversion for EI zap/residual routes.
   `_executeZapInSwap`, `_quoteExactInZap`, `_quoteZapUnwrap`,
   `_withdrawSingle`, `_saleQuoteRawToPair` and monolithic `_execZapOutSellRaw`
   need the known-share plan and sequential post-redemption state. Existing
   all-spendable-share fallback for a zero zap quote must not survive. Preserve
   one-unit swap floors versus ten-unit proportional-exit floors; enforce the
   final minimum without resting-dust subsidy.
2. **Dual-CP not edited:** Common `_swapExactIn`, `_executeZapSwap`,
   `_executeBookSwap`, duplicate previews, SeTarget owner/direct paths,
   WithdrawTarget residual sale, and DepositQuoteLib `_swap` plus legacy preview
   still need share-budget execution/transition changes. True EO must validate
   both underlying inverse domains before funding. Use the mapped research
   session `ses_f17187972ffezI4aqOHAgGwiiy`; no work was delegated successfully.
3. **Balancer quad not edited:** its HooksTarget `_swapExactInExecute` and
   SeTarget `_swapExchangeIn` still use `_unwrapExactTokenOut`. It needs the
   analogous rated-share/forward-payout plan. Do not confuse its genuine
   exact-output liquidity routes with EI routes or rewrite unrelated liquidity
   economics.
4. **Non-CP single:** existing EI already calls the SE forward route. Its
   `Common._previewWrapExactOut` / `_previewUnwrapExactOut` still need explicit
   nonzero-inverse checks for positive requests; failures must precede `take`.
5. **Seven matrix rows:** keep all existing assertions, but specialize old EO
   success/refund expectations for unsupported H domains without disabling
   supported generic SE controls. Replace the inherited operative `vm.mockCallRevert`
   with a targeted real token failure, and replace old capacity/all-local
   assumptions with funded-state proofs. Existing EO test helpers preview before
   executing: negative tests must call execution directly so they cannot pass by
   testing only preview. The new weighted tests do not close these shared rows.
6. **Full required regressions still pending:** real same-manager blocked H/P EI
   redemption both directions and all surfaces; shortage rollback/no nested
   unlock; raw/identity/linear controls; exact share-budget boundaries; projected
   nonunit-rate/decimal transitions; DETF passed/failed gates. Existing H/P tests
   remain gas-worker-owned. Add consumer-side fixtures rather than editing those
   trees without coordination. Preserve V3/Morpho/Pons-v1 and generic ERC4626
   success/refund controls.
7. **Validation:** edited hook code has not compiled or executed. Check
   stack-depth, runtime sizes, artifact linking, post-swap positive rated/native
   floors, identity paths and sequential parity. Do not solve failures by via-IR,
   caps/clamps, weakened assertions, legacy fallback or broader math domains.

Read-only maps: Orbital `ses_f17187f7fffeUEWA9n1ky436ze`; CP
`ses_f17187972ffezI4aqOHAgGwiiy`; matrix `ses_f17186fa9ffektkzSRckiLs386`.

After explicit writer release, a focused first check (not a closure claim):

```bash
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadHookShareBudgetMath.t.sol

python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol \
  -- --match-test '^test_consumer_'

python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol \
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital

python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookSeTarget.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve
```

Then run the full consumer commands below **after closing the listed routes and
test expectations**. Prior 5-test Python success does not validate hook economics.

## Checkpoint and authority

2026-09-28. Phase 4 **source preparation**, not a green Solidity validation or
audit-readiness declaration. Authority: the [implementation plan](UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md)
and [finite removal manifest](UNISWAP_V4_FULLSPREAD_REMOVAL_MANIFEST.md).

The resumed consumer worker did not run Forge, solc, LSP, deploy, broadcast,
change compiler/profile settings, clear artifacts, or edit H/P family code or
consuming-hook economics. The family gas worker owns the compiler/artifact writer
until the parent explicitly releases it. Frontend work belongs to the parent.
Automatic edit-tool diagnostics are not fresh validation evidence.

HEAD when inspected: `b019f232a1a109868da81be2d81f94d00a8a0be7`. Changes are uncommitted.
This SHA preserves the tracked legacy baseline, not the current dirty tree or
untracked candidate/research. Preserve those separately before any removal.
User research, candidate, council tooling, unrelated docs and `lib/crane` changes
were not reverted. The strict later removal gate remains **80 Solidity files and
six documents**, not a recursive deletion. Nothing is retired in this checkpoint.

## Prepared maintained consumer replacements

Paths are repository-relative. H means
`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`;
P means its sibling `ponsFamilyV2Hook/`. These are separately compiled economic
families, not modes of one implementation.

| Consumer / exact entry point | Old dependency | Prepared replacement / status |
|---|---|---|
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol`: `deployUniv4SePkg`, `deployUniv4Vault` | Protocol-tree V4 factory/package | H typed factory/package; helper rejects nonzero hooks. Generic SE money-path interfaces remain opaque. |
| Same library: `deployPonsV2SePkg`, `deployPonsV2Vault` | Generic V4 package used for Pons keys | Separate P typed factory/package. Hermetic constructor binding is taken from the real `PonsV2Stack`, not inferred from an arbitrary pool key. P validates hook identity/registration; production uses the canonical fixed hook. |
| `contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol` | Legacy V4 TestBase | P TestBase via `_initializePonsHook` and `_positionManagerForTests`, keeping real factory/graduation, same manager and actual dual funding. |
| DETF `TestBase_UniswapV4Detf_Weighted_PonsV2Se.sol`, `TestBase_UniswapV4Detf_Weighted_PonsMix.sol` and their `_Decimals.sol` counterparts | Generic V4 fixture package | Real Pons stack first, P package second; P vault calls only for Pons-v2 legs. |
| DETF `TestBase_UniswapV4Detf_Orbital_PonsV2Se.sol`, `TestBase_UniswapV4Detf_Orbital_PonsMix.sol` and their `_Decimals.sol` counterparts | Generic V4 fixture package | P package bound to the existing real stack. |
| DETF `TestBase_UniswapV4Detf_Quad_ProdSe.sol` and `_Decimals.sol` | One V4 package for vanilla and Pons legs | Separate cached H and P packages. `_deployVanillaUniv4Se` remains H; `_deployPonsV2Univ4Se` is P. |
| `contracts/test/bases/TestBase_FeeAccrualComposition.sol`: `_nativePonsPool`, `setUp` | Pons native key sent to now-H helper | Retain the actual stack returned by `_nativePonsPool`; bind P to that hook/PositionManager and deploy the native key. Seed, custody, weighted reserve and migration economics unchanged. |
| `scripts/foundry/anvil_robinhood_main/Phase_05_Stage_03_UniswapV4StandardExchangePkg.sol` | One generic V4 package | Distinct H and P facet/delegate/package deployments through typed FactoryServices and manager registry. P fixes `expectedHook` to `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`. |
| Main `LaunchState.sol`, `LaunchIo.sol`, Stage 05-03 wrapper, `Script_SimulateArchitecture.s.sol` | Single generic package state/export | `uniV4SePkg` is H; **new `uniV4PonsSePkg` is P**. Both are exported together; loading checks package names. No old address was rewritten or reused as a new family. |
| Main `Phase_07_Stage_01_FeeAccrualLiquiditySe.sol` and `.s.sol` | Generic package | P typed package, name check and fixed-hook check before deterministic lookup/deployment. |
| `scripts/shell/lib/rh_4663_fee_accrual.py`: `PACKAGE_MANIFESTS` | Fee-accrual read `uniV4SePkg` | `.packages.uniswapV4Se` now resolves from **`uniV4PonsSePkg`** in the same Stage 05-03 manifest. Existing live configurations/journals are not migrated. |
| Testnet Stage 05-03, `LaunchState.sol`, `LaunchIo.sol`, `UniV4SeInstanceLib.sol` | Generic V4 package | H for zero-hook pools, including stale-family refusal in loaders. No P fixture is fabricated on testnet. |
| Main/testnet `Phase_04_Stage_01_FeeCollectorAndManager.sol` | Legacy liquid-reserve interface ID | Matching H interface's unchanged selector-set ID. Existing default amounts/cascade are preserved. |
| Main/testnet `Phase_09_Stage_01_ExportFrontend.s.sol` | Ambiguous V4 export | Backend export producers emit family-name metadata; main also emits P address. No files under `frontend/` were edited. |
| `scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol` | Legacy V4 factory/package | H typed wiring, registry deploy, stale-family refusal when loading a saved package. Balancer DETF sibling functionality not refactored. |
| `scripts/shell/lib/rh_4663_stages.sh`: `build_rehearsal_artifacts` | Legacy implementation roots only | Both H/P implementation roots included for future artifact preparation. This function was edited, **not executed**. |
| `scripts/shell/lib/rh_4663_verify_inventory.py` | Old package inferred from `uniV4SePkg` | Explicit H/P name mappings. JSON keys require matching `<key>Name` metadata; ambiguous historical keys are warned/omitted, not relabeled. Broadcast/registry can recover historical identities and override JSON inference. |
| `test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol`: `_deploySe(backend == 2)` | Incompatible old package argument | H interface plus package-name assertion. Its Stage 05-03 producer is migrated above; this is not a blind cast. V2/V3/Morpho branches retained. |

All DETF TestBase names above live under
`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`.
V3, Morpho and Pons-v1 components, dependencies and economic branches were retained.

### Artifact and manifest boundary

Updated source bindings resolve the new full contract-name artifacts via their
family FactoryServices. Existing `out/`, `cache_forge/`, deployment JSON, chain
address bundles and broadcast records were not refreshed or rewritten. Old
immutable deployments remain old deployments. Old JSON lacking explicit family
metadata is not evidence that its package address implements H/P.

Local Script 12 must run on a package-supported chain: the H implementation admits
hermetic 31337/46630 and pinned production 4663. The older local shell default of
11155111 is not newly admitted. No chain/profile workaround was introduced;
use an independently authorized supported local environment when validating.

## Regression source preparation

### Pons real-launch consumers

`test/foundry/spec/protocols/dexes/uniswap/v4/pons/UniswapV4StandardExchange_PonsV2Pool.t.sol`
and `pons/decimals/UniswapV4StandardExchange_PonsV2Pool_Decimals.sol` now use P
interfaces/fixtures. The decimal base no longer inherits the old shared
`UniswapV4SeDecimalsHelpers`; its P18/R6 and P18/R9 wrappers retain their original
decimal selections and real Pons quote-token economics, including creator tax.

- Former `test_T10_5_previewExchangeOut_eq_exchangeOut` required the general
  two-backed-leg share-to-token inverse. Plan R6 supersedes that success domain.
  Replacement `test_T10_5_twoLegExactOutput_rejectsAndRollsBack` establishes both
  positive backing legs, then requires the exact `InvalidRoute(se, output)` payload
  for preview and execution. It compares observable supply/custody, booked
  reserves, allowances, native balances and quoted inventory, and checks locker
  NFT identity/ownership. This is not a claim to enumerate every EVM storage slot.
- `test_T10_5_exactInputShareRedemptionParity` preserves the supported EI route,
  exact preview/payment, caller-share debit and total-supply burn assertions.
- T10.1-T10.4 and T10.6-T10.7 retain manager/key/registration, activation/deposit,
  bidirectional swaps, frozen fee terms and NFT custody assertions. The EI swap
  helper additionally checks failed-minimum input/allowance rollback and exact
  successful input debit.
- T10.4 now prepares small-input parity cases (WETH `1e12`, decimal quote
  `10^decimals/10_000`). These are **unexecuted candidate admissible inputs**, not
  proof of alignment. The former one-whole-quote success expectation is recorded
  here as historical/pending disposition under fixed composition protections;
  do not claim unchanged amount-domain coverage or remove that concern at the gate.
- Direct token-to-token EO parity remains in T10.6. Unlike the two-leg share exit,
  this is not categorically invalid, but first-step and placement certification
  must be checked by execution. Do not convert it to blanket rejection.
- Supported linear EO success belongs to the existing real one-backed-leg suites:
  `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}/OneBackedLeg.t.sol`.
  No token balance/storage manipulation was added to manufacture that domain in
  a two-token Pons fixture.
- `FullSpreadConsumerPolicy.t.sol` independently XORs the historical seven
  liquid-reserve selectors and checks both new interface IDs without importing
  a dead interface solely for its ID. `test_T10_policy_storedZeroInheritsLiveTypeDefault`
  checks the real P proxy's 20% default, live type changes, vault override and
  stored-zero inheritance. These Solidity tests are prepared, not executed.

### SE matrix: economic closure deliberately pending

`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`
now uses H typed interfaces/factory/components and rejects a cached package of the
old family. Its pool is hookless and separate from the real consuming hook's
manager. No consuming hook was changed, no row/assertion removed, and no legacy
vault fallback was added.

**Not complete:** `p=1e18` means local target `T/2`, not all-local custody. The
historical `_openInvestment`, `limitCapacity`, `openCapacity`, operative-revert
mock mechanism and row funding assumptions still need deliberate revision. They
are left visible, not certified or newly introduced. Parent/Oracle must resolve
the consumers' use of unsupported two-leg EO redemption, including from EI
workflows, before an economic change is authorized. Then establish actual funded
local cover and replace the inherited mocked failure setup with real conditions.

All seven concrete rows remain at the common prefix above:

1. `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
2. `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
3. `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
4. `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
5. `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
6. `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
7. `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Their legacy filename suffixes are retained identifiers, not claims that the
shared fixture still deploys legacy bytecode. Their economic success remains a
release blocker, also affecting DETF prod-SE and fee-accrual consumers.

## Remaining legacy-reference disposition

Do not globally rename or delete these trees. They retain assertions that need
mapping before the strict removal gate; presence here is not closure evidence.

| Active source/test reference group | Disposition before removal |
|---|---|
| `contracts/protocols/dexes/uniswap/v4/` manifest A vault files, factory's 13 runtime loads and old TestBases | Retained historical implementation; maintained consumers use H/P. Do not retarget the baseline factory's artifact strings. |
| Direct unsegmented files under `contracts/vaults/standard/exchange/protocols/uniswap/v4/`, factory's 13 runtime loads and old TestBase | Retained implementation baseline. H/P subtrees are excluded from removal. |
| `test/foundry/spec/protocol/dexes/uniswap/v4/` including decimals, H2, native, TWAP, full-range, routes, Multi and adversarial tests | Historical baseline plus regression-port backlog. Port security/custody/surface assertions into new-family domains; do not assume all EO successes or old sleeve formulas survive. |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/` including decimals, reserve reconcile, pretransfer parity | Same pending regression mapping. Old idle token-to-exact-shares parity is unsupported R4; replacement must test rejection and supported blocked F1 funding/refunds, not silently omit it. |
| `release/v4/closed-form/UniswapV4FullSpreadClosedFormPrimitiveParity.t.sol` and candidate source | Unadopted historical candidate, retained untouched. No candidate repair/adoption or retirement yet. Preserve independently required arithmetic assertions before later retirement. |
| `uniswap/remediation/UniswapV4StandardExchange_PreservedBaseline.t.sol` and `StandardExchangePreservedBehavior.sol` | Intentional exploit evidence. Rehoming to H would reverse its purpose; preserve revision-qualified history at removal. |
| `uniswap/adversarial/TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial.sol`, V4 adapters and `F6Diagnostic.t.sol` | Pending H/P regression port. Preserve EI parity; split unsupported two-leg EO success from valid negative-domain and linear-domain coverage. |
| `uniswap/remediation/StandardExchangeDeliveryBehavior.sol`, `StandardExchangeReleaseBehavior.sol`, `uniswap/adversarial/StandardExchangeFullSpreadAdversarialBehavior.sol` | Shared V3/V4 behaviors: retain V3 untouched; do not replace shared expectations globally. Real `FullSpreadLiquidityProvider` is still imported by the matrix and must be rehomed before its historical container is retired. |
| `uniswap/invariants/StandardExchangeHandler.sol` and V4 invariant adapter | Pending family-specific domain adaptation. Preserve actor/state/counter coverage; actions 4-7 and 10-11 assume EO domains requiring revision. No blanket catch or action deletion to obtain green. |
| `uniswap/remediation/StandardExchangeConstantProduct.t.sol`, `StandardExchangeLockedCaller.sol`, `StandardExchangeMarketTrader.sol`, `DeliveryTestToken.sol` | Shared arithmetic or real protocol test callers, not legacy vault implementations. Preserve. |
| `test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol` | Aggregate imports intentionally retain old regressions pre-gate; maintained fixture wiring is separate. Revisit imports only after assertion mapping. |
| `contracts/vaults/standard/exchange/protocols/uniswap/{README.md,VERSION_SOURCE_MAP.json,PRESERVED_SOURCE_SHA256.json,PRESERVED_BUILD_CONTEXT.json,VALIDATION.md,REGRESSION_RESULTS.txt,VALIDATED_ARTIFACTS.json}` | Existing historical baseline/provenance, not new H/P readiness. Do not rewrite old hashes/results. Current authority is the new PRD/plan and this ledger. |
| Names containing `UniswapV4StandardExchange*BufferHook` in current hook packages | Unrelated current consuming-hook identities, not legacy SE vault files. No blanket rename/removal. |

Short `uniswap/` paths in this table mean
`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/`.
Search inventories are retained in agent sessions
`ses_f18d3be03ffeMbpbYMh5CIbIyl`, `ses_f17529ea6ffeYliDo0vQwYfDQo` and
`ses_f1752a042ffecqADlfDWnV59MI`; this file is the durable disposition, not those
sessions alone. Frontend active identifier mapping remains parent-owned.

## Verification and exact pending commands

Executed without EVM compilation:

- Scoped `git diff --check`: passed for changed consumer scripts/contracts/tests.
  Whole-worktree check reports pre-existing Markdown hard-break whitespace in the
  owner's proportional-zap PRD; it was not rewritten.
- `python3 -B -m unittest scripts.test_fullspread_consumer_inventory scripts.test_fee_accrual_checks.FeeAccrualChecks.test_v4_package_resolution_selects_pons_not_hookless`:
  **5 passed**. Tests are offline, no RPC/compiler/contract mocks.
- `bash -n scripts/shell/lib/rh_4663_stages.sh`: passed without executing its
  artifact-build function. Final targeted source searches found no legacy V4
  package/factory/reserve-interface imports in maintained scripts or the migrated
  Pons consumers. The matrix retains only generic Crane V4 imports and its
  explicitly listed historical provider-container dependency.
- Static reviews checked P initialization/types and launch bindings. Two concrete
  findings (omitted H/P artifact roots and ambiguous inventory naming) were fixed.
  No Solidity execution or whole-plan review pass is claimed.

**Do not run the following until the parent releases the artifact writer.**
Run serially; do not start concurrent Forge processes, change profiles/settings,
clear caches or broadcast. These commands are pending, not recorded results.

```bash
# Pons consumer regressions plus deployed fee/default policy checks.
python3 scripts/forge-artifacts.py test \
  contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol \
  --test-root test/foundry/spec/protocols/dexes/uniswap/v4/pons

# Four reserve-host DETF families, mixed V3/Morpho/Pons legs, decimal wrappers.
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se

# Real native Pons fee-accrual consumer; hook-domain closure may still block it.
python3 scripts/forge-artifacts.py test \
  contracts/test/bases/TestBase_FeeAccrualComposition.sol \
  --test-root test/foundry/spec/protocols/staking/token/FeeAccrualCompositionScript.t.sol

# Build source/runtime artifacts only; never execute/broadcast these scripts here.
python3 scripts/forge-artifacts.py build \
  --consumer 'scripts/foundry/anvil_robinhood_main/Phase_05_Stage_03_UniswapV4StandardExchangePkg.s.sol' \
  --consumer 'scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_03_UniswapV4StandardExchangePkg.s.sol' \
  --consumer 'scripts/foundry/anvil_robinhood_main/Phase_07_Stage_01_FeeAccrualLiquiditySe.s.sol' \
  --consumer 'scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol'

# After the parent resolves hook economics/funding: all seven real matrix rows.
python3 scripts/forge-artifacts.py test \
  test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange \
  -- --match-contract '.*SeMatrix_UniswapV4FullSpreadStandardExchangeVault.*'

# Existing genuine linear EO acceptance, not a two-leg inverse substitution.
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/OneBackedLeg.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/OneBackedLeg.t.sol

# Fork run additionally needs a separately prepared local rehearsal with new
# Stage 05-03 manifests. Old public/live deployment pins must fail the name check.
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol
```

Fork defaults are `REHEARSAL_RPC_URL=http://127.0.0.1:18663` and
`REHEARSAL_DEPLOYMENTS_DIR=.scratch/robinhood-mainnet-rehearsal/deployments`.
This work does not authorize creating or broadcasting that rehearsal.
After all closures, record actual source/artifact identities, complete family and
consumer results, and the parent's human readiness checkpoint. Only then consider
the finite removal phase and final post-removal rebuild/regressions.
