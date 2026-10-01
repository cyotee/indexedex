# NetNet–Pendle: all-item closure audit and source-derived answers

Date: 2026-09-27. Reviewed PRD v0.29 and all twenty tracker items. Four independent originals and four same-session cross-reviews completed. Research/documentation only.

## 1. Conclusion

**The custom reserve accounting model is already specified. Do not ask the owner to define it again.** Apply the selected custody units and rates to actual Balancer V3 Weighted liquidity math, with the separately specified proportional PLP/YT sub-reserve and owned-HLP DETF operations.

No new irreducible product conflict was established in this round. The remaining register is primarily source mapping, exact plan specification, deployment evidence and maintenance. This does not mean all algorithms, reference citations or validation are complete. In particular, the balance-derived staking reference was not located, and composed exact-output conversion/provenance work cannot be certified merely by pointing at one math helper.

**Do not confuse these statuses:** answered requirement; reusable source mapping; finished executable plan; passing tests; verified deployment. This review closes repeated product questions, not missing evidence by assertion.

## 2. Disposition of every tracker item

| ID | Answer / derived specification | Remaining deliverable, not a standing owner question |
| --- | --- | --- |
| NN-01 | Use recorded constants, selected PkgInit/PkgArgs/discovery split and versioned evidence manifest. Do not pin a perpetual market/SY. | Deployment/code/configuration/observation evidence; preserve explicit existing deadlines. |
| NN-02 | NFT-owned holder per tokenId, standard whole-PkgArgs hash, actual returned native noteId, same-NFT installments/excess, separate pre-maturity rebond and final E+1 timing. | Exact call/state/receipt transitions, terminal residual handling, resource evidence within acknowledged per-holder exposure. |
| NN-03 | Closed: complete accounting/sync; failed outgoing fee transfers are non-blocking; arbitrary broken essential dependencies need not remain usable. | Implement/test existing scope; no quarantine/freshness questionnaire. |
| NN-04 | Independent destination-type new-bond locks; intermediate collections do not reset; final intended contribution in E unlocks ordinary withdrawal at E+1. | Source/oracle duration-bonus compatibility; return only an actual incompatible configured case. |
| NN-05 | Four known custody/pricing legs; weights50/20/10/20; Universal NET synthetic creation1/opening1000; existing oracle fees. | Apply selected mappings coherently in previews/execution. No new accounting model. |
| NN-06 | Outer BasePoolMath invariant/share operations; inner proportional PLP/YT ownership and nested allocation; raw SE-share exit. | Exact scaled caller context, share scale/residual/zero-last cases and numeric reference vectors. |
| NN-07 | Ordinary NET/sNET draw shared SY held-first/claim-if-short; USDG uses SE; burns/reinvestment price and fund only DETF-owned HLP. | Complete each composed exact-output inverse and transition, with forward quote check, fees/limits and rollback. |
| NN-08 | First bond atomically funds all required custody legs, G, buyer principal and rewards. Actual SY capital can seed a zero-earned-interest book. | Concrete custom-unit bootstrap inputs, subsequent G/U mappings and nonzero-live-book verification. |
| NN-09 | Two arithmetic price-time cumulatives, prior-mark accumulation, exact3600s window/readiness and separate consumers. | Observation/history layout, boundary retrieval and source-compatible checkpoint semantics; no geometric tick substitution. |
| NN-10 | Use the configured external SY; build the selected reusable target-token rate provider, not a new Pendle SY. | Actual denomination/scaled18/conversion and preview reliability evidence. |
| NN-11 | Separate raw custody, claims, capital, principal realization, incentives and fee payables; reconcile force-claims before contribution credit. | Concrete authenticated receipt/provenance algorithm and tests; generic balance surplus is not proof of user input. |
| NN-12 | Live held-DETF B/U model and recipient rights are selected by PRD §10.2. Existing standing-weight algebra is a reference, not a substitute index model. | Repair missing normative citation or supply faithful explicit share/top-up/zero-share/dust derivation. Not yet located or fully derived here. |
| NN-13 | Owner-approved product intent is settled; shared execution instructions remain a separate authority matter. | Separately authorized maintainer reconciliation. This report cannot amend instructions or authorize bypass. |
| NN-14 | Atomic factory-first rollover, claim reconciliation, old-position realization, verified SY conversion, successor Keep-YT, then commit; retain historical claims. | Exact external arguments, limits, accounting writes and residual-history access. |
| NN-15 | TokenId rights, NFT-owned holders, early rewards, new-tokenId rebond while old remains, no zero-principal auto-retirement. | Exact mature-and-empty retirement/residual states; do not invent an owner transfer or fee sweep. |
| NN-16 | Retain full V2 SE surface; package validates canonical pair strategy; custom SE owns per-hop tax/exemption/net delivery. | Exhaustive selector/route/parity matrix and tax-aware execution/quotation implementation. |
| NN-17 | Crane package/factory and registry conventions; distinct hook flags/holder salt/DETF singleton; explicit source-config authority. | Final deployment graph, facets/selectors, storage/initialization, safe reuse and callback guards. |
| NN-18 | Overflow-safe prescribed arithmetic, no hidden expansion cap/replay, preserve reference math domains and accepted dependency scope. | Representability/horizon proofs and separately executed resource measurements. |
| NN-19 | Map R/C/A rules to quantitative production-path tests and expected state/rounding outcomes. | Write plan-level vectors/coverage; run validation only under separate authorization. |
| NN-20 | Reconcile operative rules, references and companion status; retain historical evidence without allowing it to override. | Mechanical editorial work; do not fabricate missing history or misidentify a reference. |

The table does **not** leave twenty questions for the owner. A later engineering finding becomes a product checkpoint only if it identifies a real supported-case choice or incompatibility not settled by current requirements and reference behavior.

## 3. Weighted LP accounting: concrete mapping

The already-selected ownership vector is:

`[raw DETF, raw SE shares, held + net-claimable SY, PLP/YT subshares]`.

Physical token snapshots remain in BasicVaultRepo; receivables and internal subshares are not token balances. The rated NET/sNET/USDG swap/synthetic coordinates do not create duplicate asset entitlements. Bind weights to identities, not assumed ordering. Fee-owned tokens are excluded from backing. The custody matrix, rates and scope of expenditure are already PRD §§4.4/6.1–6.3/7.1, not new derivations for the owner.

Use `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol`:

| Mode | Function/range | Required rounding/behavior |
| --- | --- | --- |
| Proportional exact-HLP output | `computeProportionalAmountsIn:50–70` | Per-leg inputs round up |
| Proportional HLP exit | `computeProportionalAmountsOut:87–107` | Per-leg outputs round down |
| Unbalanced exact-asset add | `computeAddLiquidityUnbalanced:126–205` | Current invariant up, projected invariant down, taxable nonproportional contribution, fee up, HLP output down |
| Single-token exact-HLP output | `:224–263` | Required input and fee gross-up according to reference |
| Single-token exact-asset output | `computeRemoveLiquiditySingleTokenExactOut:277–342` | Invariant-derived taxable amount and HLP debit rounded up |
| Single-token exact-HLP input exit | `:359–397` | Conservative remaining balance and net token output |

The source's balances are in its scaled caller context. Its `−1` corrections are not instructions to subtract one arbitrary raw token unit from every custom reserve. Trace the Vault dispatch/scaling at `Vault.sol:604–647,679–726,853–965` in the same directory. Preserve custom hook usage-fee dilution from PRD §4.6 separately; do not introduce a new Balancer-hosted fee architecture.

Moderator directly re-read BasePoolMath:40–209; the additional mode/caller ranges were traced by the council. Reference code and source paths are evidence, not executed numerical parity.

### Inner PLP/YT shares are a different allocation layer

PRD §7.1.1 selects V2-like proportional ownership, not a second AMM. The reusable source pattern is `lib/crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Pair.sol:255–295,302–323`, directly read by the moderator:

- Initial V2 issuance uses geometric mean with the reference locked minimum, not the later min-ratio formula against zero supply/reserves.
- For positive L,Y,S, later proportional share formation uses `min(floor(dL*S/L), floor(dY*S/Y))`.
- Allocated subshare exit separately floors LP and YT fractions, as the PRD already specifies.

These establish reusable arithmetic patterns, not permission to copy all V2 economics. Do not import V2's separate protocol fee, a new public token, or unequal-contribution donations that contradict the PRD. The plan must state accepted contribution quantities and residual accounting explicitly rather than silently crediting one amount and treating excess as a free donation. Likewise, do not assert unequal ratios are impossible simply because inputs use Keep-YT: current market composition/index and historical portfolio ratios can differ; no invariant proving equality was supplied. Exact share scale, domain and residual implementation are plan authorship, with genuine unhandled conflicts reported rather than hidden.

## 4. Bootstrap, quote and settlement answers

### First bond

`UniswapV4DetfTarget.sol:629–668` under the Universal V4 DETF directory routes the first bond through `requiredFirstBondTokens()` and pulls additional required legs; `:683–693` separately funds principal. Moderator re-read both.

The custom first bond therefore uses real contributed assets for the full custody book, G for the self-leg, and separately funds principal/rewards with the already-selected G/U/B/R equations. **Zero earned interest need not mean zero SY custody:** direct SY capital is already allowed. Label it capital, not yield. This is one atomic activation transaction, not an unapproved seed transaction followed by purchase. A partial-book helper does not bypass the selected full-book liveness requirement.

The exact custom payment-unit/rate mapping and tested first-mint amounts remain necessary plan deliverables; no numerical bootstrap feasibility was executed here.

### Exact output

Vendored WeightedMath `computeInGivenExactOut:199–234` supplies upward-rounded Weighted swap inversion and its output-domain limit. For the quotation-only contraction uplift, once a coherent required quote input qQuote is derived, a candidate actual DETF amount is:

`q = ceil(qQuote * WAD / (WAD+p))`.

Verify the forward integer quote and actual owned funding; preserve all stages' rounding. This only inverts the uplift/Weighted layers. It does not prove an entire nonlinear SY redemption, PLP/YT realization, taxed SE or multi-stage exact-output path. Required ERC4626 withdrawal remains supported-or-blocked-for-concrete-incompatibility, not silently relabeled unsupported. Do not invent a generic iterative solver as if it were already the approved reference.

For ordinary NET/sNET output, the final amount must fit the same held/claimable eligible SY budget. For contraction/reinvestment, construct the DETF-owned reserve book before quoting, then realize only owned assets. Neither whole-pool quotation followed by a payout cap nor a minimum-output check is a substitute for the selected inverse and ownership model.

## 5. Pendle integration and provenance

Under `lib/crane/contracts/protocols/perps/pendle/`:

- `router/ActionAddRemoveLiqV3.sol:236–303`: **`addLiquiditySingleTokenKeepYt`** / **`addLiquiditySingleSyKeepYt`**, actual market/index-based SY split, YT retained by receiver, `minLpOut` and `minYtOut`. Moderator directly read this range.
- `router/ActionMiscV3.sol:129–188`: **`exitPreExpToSy`**, LP removal, matched PY redemption and excess-only market trade.
- `:208–240`: **`exitPostExpToSy`**, post-expiry realization; no expired-YT principal payout.
- `core/YieldContracts/PendleYieldToken.sol:166–193`: public `redeemDueInterestAndRewards` on YT; **not** a public method of InterestManagerYT.
- `core/YieldContracts/InterestManagerYT.sol:43–57,63–79`: internal accrued-interest/fee/transfer mechanics.

For selected position exits, loose `netPtIn=0`; one post-removal state and actual execution-router fee identity drive the quote. SY realized from principal is not booked a second time as interest inventory. Claims replace receivables with cash, and third-party force-claims must reconcile previously delivered receipts. A generic `balanceOf−booked` surplus does not distinguish them from user input. A native-note index pattern also does not automatically solve SY receipt provenance; the exact algorithm is still an engineering specification obligation.

The rollover sequence follows already-selected policy and these calls: validate trusted factory/target first; reconcile old claims; remove LP/redeem mature PT; convert old-SY/new-SY only through a verified supported route; acquire successor Keep-YT; commit active accounting atomically. Retain historical earning-address/YT/SY references for late claims. No invented bounty, extra configuration, separate committed seed or change to fee-forwarding behavior.

### Existing external SY, not a new SY product

The configured market's external SY and the selected reusable SY-to-target **rate provider** are different components. Missing external source in the vendor tree does not authorize building a substitute Pendle SY. Hook compatibility `assetInfo()` is not evidence of such a requirement. Complete the actual external conversion/decimals/scaled18 and source-versus-deployment evidence before reliance, using the already specified normalization and preview caveat. No new oracle policy is selected.

## 6. Arithmetic TWAP implementation pattern

The selected window, series and consumers are settled. Directly read references:

- `UniV2Pair.sol:215–224`: accumulate previous arithmetic price multiplied by elapsed time before updating reserves.
- `lib/crane/contracts/protocols/pol/net/src/PairOracle.sol:118–130`: consultation-time counterfactual extension from last state.

Use this cumulative-price pattern for separate spot/synthetic series, with prior-price integration, same-timestamp non-retroactivity, exact window-boundary retrieval and honest readiness. The reference's narrow widths/overflow assumptions need their own arithmetic check; do not copy them blindly for WAD custom prices.

The truncated V4 oracle's ring/search structure may inform storage, but its tick/log integrand is not the selected arithmetic-price series. No universal 3,601-slot bound was demonstrated. Do not claim to reconstruct price changes that were never observed. Complete explicit checkpoint/last-observed-price semantics and preview parity in the plan; genuine valuation errors must not be relabeled missing history to invoke the above-1 branch.

## 7. Staking: selected model, missing intended citation

PRD §10.2 itself selects live held backing B and internal shares U, with holder balance `floor(B*shares/U)`. Its exact intended “balance-derived PRD under docs/plans/detf” was not found in scoped searches; the directory was reported empty.

Two proposed reference repairs are **rejected**:

- `lib/crane/contracts/protocols/pol/net/src/StakedNET.sol:25–40,54–64,83–99` uses gons and an explicit index rebase. It is the upstream sNET token, not the required custom live-B/U staking model.
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenTarget.sol:493–517` uses cached or NFT-extractable-value redemption rates. Moderator directly read it. It is not live held-DETF custody backing.

`DETFSeigniorageShareLib.sol:18–33`, directly read, supplies standing-weight top-up algebra: implied total from others/(1−f−c), floor target shares, positive top-ups only. It explicitly returns zero under certain zero/invalid-weight conditions. That alone does not settle every live-B/U zero-share funding branch. The funded-staking plan's standing-allocation sections are supporting evidence, not proof its gons/K storage mechanism is equivalent.

**Concrete remaining deliverable:** write the B/U deposit/withdrawal conversion, share issuance for already-selected recipient allocations, rounding/dust and zero-share funding branches explicitly with provenance and conservation checks. Do not claim that reference was found, import an index refresh/supply cap, or ask whether standing recipients exist again. This audit identifies the remaining derivation honestly; it does not certify it completed.

## 8. V2 SE binding and package surface

`contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol:576–601`, directly read, initializes ERC4626 asset to the reserve pair and wires the configured factory/router. The ERC4626 `asset()` getter therefore offers a concrete strategy-identity check: **supplied SE asset equals the selected canonical pair**, in addition to token/factory relationships, trusted package/registry provenance and required directional capabilities. A fake vault can lie about a getter; a token list or donated LP balance alone is not enough.

Researchers traced nine installed facets and fourteen advertised interfaces (`:401–417,431–518`) and seven quote/transition selectors in `UniswapV2StandardExchangeQueryFacet.sol:20–28`. The full parity matrix must enumerate those plus inherited functions and supported exact-output classes; “zap only” is not the reference.

Custom SE libraries own per-hop NET tax/exemption/net-delivery logic. NetNet's TaxCollector and the Pendle hook do not replace those calculations. Preserve zero-stored oracle fallback and existing fee identity/order. Bind an empty but correctly configured SE without inventing a nonzero-deployment-balance requirement.

## 9. All remaining plan/evidence work

NN-13 remains separately authorized maintenance because current shared instructions still conflict with configured underlying classes. Recording product approval is not an instruction edit or bypass.

NN-17 fixes the dependency/selector/authority graph using the actual factories, standard owner-containing PkgArgs hash and safe existing-instance checks. The native returned note ID may be zero and is never assumed equal to tokenId. Current default/fork profile rules override stale skill examples without another owner vote.

NN-18/19 must specify supported arithmetic domains and normal-operation resource cases and create quantitative production-path validation. No hidden epoch cap, lower test standard, measured gas claim or hostile-balance-survival requirement is introduced. One helper's safe mulDiv does not establish whole-operation representability or gas liveness. A current deployment check is different from a publication or Sourcify verification-service record.

NN-20 repairs actual citations and separates historical statements. Do not fabricate version-history entries or fix the missing staking reference by linking a different economic model.

## 10. Attributed findings, corrections and dissent

- **Astra:** strongest concrete BasePoolMath/Pendle/SE call mappings and explicit remaining reference/composed-inverse gaps. Does not call unfinished source mapping an owner question.
- **Grok:** concurs on work classification; initial unequal-contribution donation and zero-SY-bootstrap shorthand are rejected. Existing source-derived law prevents silently donating mismatched input or assuming a non-live book works. Its minimum-duration description is corrected: below-minimum rejects; only above-maximum clamps.
- **MiniMax:** retracted its claim that StakedNET was the live-B/U reference, but its cross-review still says to build a custom external SY and describes multi-transaction bootstrap. Both are rejected. Leaving unequal contributions physically in a reserve without explicit ownership accounting does not cease to be a donation merely by calling them residuals. Its declaration that the complete composed path has no single inverse was not proven; only incompleteness was established. Several functions were misattributed; use the source map above.
- **Kimi:** withdrew the old Balancer cached-rate reference claim and adopted real SY seed/full-book and arithmetic cumulative distinctions. Its added claim that unequal inner contribution ratios are unreachable under Keep-YT was not demonstrated and is not adopted. Do not reintroduce v0.27-excluded hostile-balance survival tests.

The common conclusion is **no new general owner questionnaire**. It is not unanimity on every formula/implementation assertion. The moderator rejects unsupported shortcuts instead of declaring every technical/evidence item finished.

## 11. Protocol and preserved sessions

Eight task calls completed: four independent originals, then four continuations each receiving the other three complete originals together. No earlier cross-review supplied to another researcher; prior session context retained. No participant substitution.

| Researcher | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Observed routing openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; not provider attestation. Ordinary absent-file/denied-path discovery results were recorded as individual evidence limitations, without retrying those paths or claiming their contents read. No actual session identity/continuation failure was reported in this round.

## 12. Scope, confidence and human checkpoint

Local reads on 2026-09-27; source-line references are current snapshots, not immutable pins. Configured compiler baseline previously read is 0.8.35; relevant source pragmas vary (Pendle generally ^0.8.17, Balancer ^0.8.24, IndexedEx often ^0.8.0). No compiler/runtime version command was run. Prior public SY caveat source: https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield, accessed 2026-09-27 in earlier rounds after Context7 lookup; not newly live-verified here. This round primarily inspected local code, not external library documentation.

High confidence in settled-policy classification and inspected source mappings. Lower confidence/incomplete evidence on configured-source equivalence, full composed inverse, B/U edge derivation and numerical/resource parity. No tests, shell, RPC, browser execution, deployment, transactions, code/config/instruction changes, or fabricated evidence.

PRD/tracker now route engineering obligations to the source map and distinguish them from owner decisions. **Next useful authorization is to write the complete implementation/test plan from these sources and the PRD**, keeping the named reference/evidence gaps explicit until actually resolved. This report is not that finished executable plan and does not authorize implementing it. No additional product answer is requested on this evidence; stop here.
