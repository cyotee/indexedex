# Astra — ORIGINAL full closure audit

2026-09-27. Read **all 1,276 lines of PRD v0.29** and **all 328 tracker lines**, current CLAUDE, relevant alignment/routing law and canonical skills. Prior session retained; no new-round peer reports read. Assigned routing `openai/gpt-6-astra`, not provider attestation. No execution/delegation or code/configuration changes; only this Markdown report written.

## Verdict

**The tracker is primarily an engineering/evidence register, not twenty unanswered owner questions.** The selected custody units, Weighted accounting, weights, fee/synthetic equations, locks and failure scope determine the architecture. Proceed to a concrete specification/implementation plan with the mappings below; do not claim execution readiness where dependency evidence or exact derivations are still absent.

No new owner questionnaire is justified by this pass. There are concrete **reference-reuse limits**, notably the tick-based oracle, generic gons staking and approximate hook exit math. Those identify what must be adapted or independently specified—not permission to change the product. No executed safety/economic proof is claimed.

## All twenty dispositions

**A** already answered; **S** source-derived specification; **P** plan deliverable; **E** deployment/validation evidence; **M** maintenance authority. These are audit classifications, not edits to tracker status.

| NN | Classification | Concrete disposition |
|---|---|---|
| 01 | E | Existing constants/manifest rules stand. Pin actual market/SY/router implementations, observations and oracle terms; preserve canonical-pair verification **before implementation**. No perpetual market pin. |
| 02 | A/S/P/E | One NFT-owned holder, registered returned noteId, actual aggregate receipt, same-NFT principal including excess; retain all-note scan exposure. No global NFT allocation loop or invented native selective claim. |
| 03 | A | Closed scope: full expected-set synchronization; isolate outgoing fee transfer failures; essential failed reads may revert. No quarantine question. |
| 04 | A/S/E | Purchase check distinct; no intermediate reset; final successful contribution E gives E+1 unlock; replacement uses its own type lock. Check oracle-duration arithmetic against actual terms, not another timing vote. |
| 05 | A/S/P | Four native custody coordinates and separately rated swap vector; use §7.1.4 exactly, direct owned HLP and fee dilution. Creation1/opening1000. |
| 06 | S/P | Map outer modes to BasePoolMath and inner allocation to proportional PLP/YT subshares; apply exact rounded transitions below. |
| 07 | S/P/E | Separate ordinary shared-SY settlement from owned-HLP burns. Weighted exact-out exists; conversion inverses need configured-SY/SE evidence, not an unsupported-withdraw substitution. |
| 08 | S/P/E | First transaction funds every leg, including actual SY seed, plus G; principal/rewards minted separately. Existing acquired SY is capital, not invented accrued interest. |
| 09 | S/P | Two arithmetic held-mark cumulative series; use cumulative/history machinery, not truncated mean ticks. Specify external-observation semantics explicitly; no fabricated historical prices. |
| 10 | S/E | Per-SY target-token rate, separate from hook inventory; normalize sample units as selected. Actual NetNet SY implementation/conversion is still evidence work. |
| 11 | S/P/E | Separate physical snapshots, net receivables, fees and authenticated contribution credit; forced claims move receivable to cash once. No economic question absent a real unclassified reward collision. |
| 12 | P/reference gap | B/U model is settled; preserve standing-weight algebra. Intended balance-derived reference was not located; current gons code is demonstrably different, not a substitute. |
| 13 | M | Custom approval is settled intent; shared universal FoT/rebase prohibition remains. Separately authorized maintainer handoff, not council instruction edits. |
| 14 | S/P/E | Factory-first validation; old claims→LP/PT realization→verified SY conversion→successor Keep-YT→atomic commit. Preserve historical claim locators. |
| 15 | A/P | Current NFT authority, early funded rewards, partial/all-principal rebond to new tokenId; do not retire old future rights. Explicit terminal/late-receipt transition remains a plan obligation. |
| 16 | S/P/E | Validate configured V2 LP via `asset()` plus trusted package/registry provenance and canonical pair/factory; retain nine-facet/14-interface reference surface and exact-output routes. |
| 17 | S/P | Standard whole-PkgArgs hashing; owner included; verify reused holders; separate DETF singleton and hook flag-mined address. Produce selector/authority/initialization graph. |
| 18 | S/P/E | Full-precision arithmetic, final representability checks and source-domain bounds; no catch-up cap or epoch replay. Resource measurements remain unperformed. |
| 19 | P/E | Translate A01–A50 into production-proxy vectors/invariants using actual ports/TestBases; no demand for out-of-scope upstream-failure survival. |
| 20 | P | Remove obsolete OPEN wording for answered items, repair exact references, preserve attributed history and distinguish source/implementation/deployment status. |

## Derived specification and reuse map

### 1. Outer HLP: use actual Balancer flow, not a new accounting model

Map balances by identity to **[raw DETF, raw SE shares, held+net-claimable SY, internal PLP/YT subshares]**, scaled consistently for the arithmetic. Apply weights by identity, not presumed array sorting. Keep physical BasicVault snapshots separate from the SY receivable and internal subshares. Rated NET/sNET/USDG values drive swap/synthetic pricing, not a second ownership claim.

`lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol` provides:

- `50–70`: proportional exact-BPT add uses `ceil(balance*bptOut/supply)`.
- `87–107`: proportional exit uses floor per leg.
- `126–205`: unbalanced exact-input add computes current invariant **up**, tentative/new invariant **down**, taxable above-proportional deltas, swap fees **up**, then BPT **down** from the fee-adjusted invariant change.
- `224–263`: single-token exact-BPT output computes input with upward ratios/fee gross-up.
- `277–342`: single-token exact-asset output computes invariant-derived taxable portion and BPT debit **up**.
- `359–397`: exact-BPT-input single-token exit computes conservative remaining balance, fee **up**, delivered output net of fee.

Do not copy `balance-1` corrections without their scaled caller context. `Vault.sol:604–647,679–726` dispatches modes, rounds non-exact raw inputs up, checks limits, updates balances, then mints BPT. `:853–965` rounds non-exact raw outputs down, checks allowance/limits, updates balances and burns BPT. Preserve the selected hook's usage-fee dilution separately; do not import an additional Balancer-hosted fee policy. This is reusable arithmetic/ordering, not a claim the custom hook already implements it.

### 2. Inner reserve and initialization

`lib/crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Pair.sol:255–295` supplies the V2 ownership reference: initial geometric-mean issuance with locked minimum, later `min(floor(dL*S/L), floor(dY*S/Y))`; `302–323` pays both reserves proportionally and burns shares. Use actual acquired contributions, not whole-balance donations as caller credit. Match accepted contribution ratios and explicitly refund/account unmatched residuals; blindly copying pair.mint's unequal-contribution donation behavior would not satisfy this PRD's no-unpriced-donation requirement. No inner swap AMM or new public token is needed. Outer HLP allocates subshares; inner realization retains the two rounding stages in PRD §7.1. Rollover changes backing under continuing ownership; it does not mint a second entitlement.

`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:629–668` joins G plus lead and required additional payments atomically; `683–693` separately funds purchased principal. Thus zero **earned** interest does not mean an unfunded SY leg: direct SY contribution is already allowed. Source `UniswapV4DetfCommon.sol:258–289` determines opening/live G/U; `DETFMintSplitLib.sol:45–52` fixes principal/pot floors. Record unit mapping for non-NET additional payments, not invented example FX rates.

### 3. Pendle entry, output and rollover

Under `lib/crane/contracts/protocols/perps/pendle/`, `router/ActionAddRemoveLiqV3.sol:236–303` provides `addLiquiditySingleTokenKeepYt`/`addLiquiditySingleSyKeepYt`, splitting SY by the actual market ratio and enforcing `minLpOut/minYtOut`. Direct caller amounts/limits supply irreducible execution inputs; market/SY/PT/YT/expiry come from validated discovery.

`router/ActionMiscV3.sol:129–188` supplies `exitPreExpToSy(receiver,market,netPtIn,netYtIn,netLpIn,minSyOut,limit)`: remove LP, redeem matched PY, trade only excess. Here loose `netPtIn=0`. `208–240` supplies post-expiry SY exit without YT principal payout. Quote on the same post-LP-removal state, with the execution-router fee identity. Keep principal-exit SY distinct from the ordinary income book. For rollover, retain share ownership while replacing active position backing; preserve old earning-address/YT/SY references for later claims. Unsupported conversion or empty successor fails atomically under the already-selected scope.

### 4. Exact-output and SE binding

Vendored `WeightedMath.sol:199–234` already computes upward-rounded exact-output input, including maximum-out domain. Use it for the appropriate coherent vector; for incentivized burn, invert quote-input adjustment with `ceil(qQuoteRequired*WAD/(WAD+p))`, then verify the forward integer quote. Funding must still debit only owned components. This solves the Weighted layer—not an unverified nonlinear SY/position conversion inverse. Native shared-SY exhaustion retains at least a positive raw residual; it is not two budgets.

`contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:57–113` specifies seven exact-output route classes and uses router `getAmountIn` for pair swaps. The DFPkg `:401–417,431–518` installs ERC20/permit/ERC4626, basic/standard vault, SE and transition-quote surfaces; its `:576–601` binds ERC4626 asset to the actual V2 pair. Crane `ERC4626Target.sol:100–102` exposes that asset. Validate `asset()==canonicalPair`, canonical token identities/factory, trusted registered implementation and directional capabilities—not token symbols or an incidental LP balance. `UniswapV2StandardExchangeQueryFacet.sol:20–28` names seven transition/external quote selectors. Preserve source feature parity while adding per-hop NET-tax net delivery; no hook-side duplicate tax.

### 5. Claims, accounting, oracle and staking

Pendle `InterestManagerYT.sol:63–79` computes fresh accrued gross interest from YT balance and index change; `43–57` deducts the factory fee and pays SY. `PendleYieldToken.sol:166–193` permits third-party claims; `373–404` establishes expiry/index behavior. Therefore reconcile receivable disappearance plus prior delivered cash, then pull/credit independently attributable user input. Do not treat `balance-booked` alone as proof of user contribution or sync away legitimate pretransfers. Receipt authentication/checkpoint design remains a concrete plan requirement, not an invented sweep policy.

Arithmetic observation reference: `UniV2Pair.sol:215–224` accumulates prior reserve price × elapsed time; NetNet `PairOracle.sol:118–130` extends cumulatives counterfactually. **Do not reuse** `UniswapV4TruncatedTwapOracleLib.sol:81–105,158–176` as the selected price oracle: it integrates truncated ticks, not arithmetic NET prices. Reuse history-search structure only. Specify two prior-mark accumulators, same-timestamp updates without retrospective weighting, boundary interpolation, readiness and read-only extension. External valuation changes can be sampled at checkpoints; do not claim this reconstructs an unobserved continuous external trajectory.

For staking, `DETFSeigniorageShareLib.sol:18–33` supplies top-up-only standing-weight algebra. PRD B/U balance-derived funding controls; ordinary shares do not change on reward mint, recipient issuance does. **Reference evidence gap:** `docs/plans/detf/` exists but is empty; scoped balance/staking filename searches in docs/plans and DETF PRDs found no intended reference. `DETFFundedStakingRepo.sol:24–36,72–83` instead uses gons/index/accountedBacking. Do not call it the missing B/U specification. Preserve reward/principal separation from alignment §24.5, restate adopted B/U recipient/zero-share formulas with provenance before freezing this part of the plan; no recipient-policy vote is reopened.

## Residual status and limits

No new demonstrated product incompatibility warrants an owner questionnaire here. NN-01's configured SY/rate/conversion evidence, NN-12's missing intended normative reference, complete composed exact-output derivations and quantitative validation are **not complete**. They prevent an unqualified “all closed/tested” handoff, not specification work under the selected model. A real below-minimum-duration conflict requires actual oracle terms; source alone does not prove those terms apply. NN-13 remains separately authorized maintenance because current CLAUDE/shared law still forbids the configured underlying classes.

Ordinary discovery limits: a broad Crane pair glob encountered broken LayerZero paths; narrowed Uniswap search succeeded. Guessed `UniswapV2StandardExchangeQueryTarget.sol` did not exist; actual QueryFacet imports **QuoteTarget**, so no same-path retry. No identity/attribution guard occurred. Local source snapshots (Solidity constraints ^0.8.0/^0.8.17/^0.8.24), not live/build pins. No external API claim required lookup. Tests, live configuration, gas budgets, actual NetNet SY implementation and whole-book parity were not verified. High confidence in cited source mappings; explicitly limited completeness for the remaining reference/integration proofs.
