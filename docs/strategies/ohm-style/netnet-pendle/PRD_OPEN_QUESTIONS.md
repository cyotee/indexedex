# NetNet–Pendle PRD — Open Items and Specification-Closure Tracker

| Field | Value |
| --- | --- |
| Last updated | 2026-09-29 |
| Product baseline | [NETNET_PENDLE_DETF_PRD.md](./NETNET_PENDLE_DETF_PRD.md), v0.34 |
| Implementation plan | [NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md](./NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md), v0.10; creator argument and L4 resolved; remaining source integration and fork validation are engineering obligations |
| Review baseline | [All-item closure audit](../../../research/netnet-prd-closure-audit-2026-09-27/COUNCIL_CONSOLIDATION.md); prior reviews retained as history |
| Current readiness | **No remaining concrete owner-level specification question retained by the audit after the 2026-09-29 clarification. Creator PkgArgs and late-excess/no-retirement rules settled. Implementation, fork validation and process maintenance remain; no test completion or execution authorization claimed.** |
| Purpose | Track remaining decisions, technical specifications, feasibility evidence and plan-completeness obligations without reopening settled product choices |
| Authority | The operative PRD controls product behavior. This tracker records work; it does not select new economics, supersede instructions or authorize execution |
| This update | Documentation consolidation only. No item was technically resolved merely by adding it to this register |

## 1. How to use this tracker

**Owner resolution 2026-09-29 — current disposition, superseding older open labels:** creator is supplied as an added main PkgArgs argument. Late excess same-NFT principal inherits the existing unlock, including a satisfied unlock; no fresh wait. There is no explicit NFT retirement process: retirement means user inactivity only. Remove the planned retire selector/terminal transition; retain NFT/holder mapping and future rights. Creator binding and L4/H01/H03 are closed as specification questions. No additional concrete owner-level gap is retained by the latest audit. Remaining source integration, rounding, receipts, wiring and tests are implementation/fork work, not new design votes. Pendle documentation supplies addresses; use the Robinhood mainnet library default fork block. G0 is process-only instruction maintenance. Historical dated entries below remain provenance, not current blockers. Current implementation plan is **v0.10**; this update executes no product code or tests and starts no council round.

- Keep `NN-xx` IDs stable. They supplement, not replace, the PRD's R/O/C/A identifiers and the review's Q01–Q08 findings.
- **OPEN:** deliverable not yet accepted. **IN PROGRESS:** record an assignee and artifact. **NEEDS OWNER:** attach a concrete proposal, alternatives and consequences. **BLOCKED:** name the dependency or demonstrated incompatibility. **CLOSED:** link the accepted normative resolution and evidence. **DEFERRED:** requires an explicit scope decision; omission is not deferral.
- Rows remain **OPEN** unless progress is recorded below. NN-01 residual evidence work and NN-02 discussion are **IN PROGRESS**, coordinated by the council moderator; source/deployment verification execution remains unassigned. Other recommended roles are not actual assignments.
- **F** = feasibility/compatibility; **S** = source-derived specification; **D** = economic/product decision; **P** = plan completeness; **A** = authority/process; **E** = editorial.
- **G1:** address early because feasibility, authority or economics can change the handoff. **G2:** complete before executable-plan freeze. **G3:** documentation hygiene before final handoff. These are work-order priorities, not audited vulnerability severities.
- Missing Solidity, selectors or Repo layouts is not by itself a PRD defect. The plan author may fix mechanical details without an owner vote when they preserve selected behavior. No author may silently choose economics, entitlements, availability or scope.
- Specification closure and implementation validation are separate. Record future test obligations here, but do not describe unwritten/unrun tests as evidence. A design may be specified while its later execution validation remains pending.

**Closure-audit statuses:** `ANSWERED / PLAN` means the requirement is settled and the remaining work belongs to the plan author, not the owner. `EVIDENCE` means verification is pending. `REFERENCE / PLAN` marks a specifically missing source or unfinished derivation, not permission to invent economics. `MAINTENANCE` requires its own authorized process. None of these labels claims implemented or tested completion. Escalate to NEEDS OWNER only after documenting an actual required-case incompatibility or irreducible value/rights choice.

### Owner-question filter — clarified 2026-09-27

This register tracks work, **not a queue of twenty questions for the owner**. `OPEN` on a technical deliverable does not mean an unanswered product decision.

- First apply the operative PRD and recorded answers. Do not re-ask settled reward routing, transfer-failure handling, holder isolation, same-NFT excess principal or old/new reinvestment behavior.
- Ask only when a concrete required behavior, entitlement, economic parameter or release condition remains undefined and cannot be derived without changing the product. Explain the specific consequence, rather than asking for an implementation mechanism.
- Source tracing, ABI/layout selection, call sequencing, numeric derivation, testing and document cleanup are author/engineering work. Do not turn their unfinished state into owner choices.
- Do not add speculative survival/recovery requirements for arbitrary malformed external tokens or deeper failures of essential Pendle dependencies. Dependent operations may be unavailable; this product does not promise immunity to those failures.
- Separate **not reachable under the specified API**, **already resolved**, **out of required failure scope**, and **genuinely unspecified**. Do not call an unlikely failure mathematically impossible or declare unperformed tests passed.
- Normal rollover/history bookkeeping, asset conservation, authorization and actual-funding safety remain required. Raise a normal-operation incompatibility only with concrete evidence; an abstract possibility alone is not another product questionnaire.
- Public pretransfer source attribution is resolved: the next eligible caller may consume positive unbooked raw surplus regardless of origin. Do not ask again for a trusted-payer/receipt/witness layer to protect original senders. Protect booked balances, supported route/caller checks and once-only consumption; keep internal staking principal/reward classification separate.

Current classification: NN-04 timing is resolved; NN-05 weights, Universal NET-numeraire synthetic and existing usage/seigniorage mechanisms are resolved by v0.29. Reference compatibility/custom-unit integration remains engineering work, not a new fee/formula vote. NN-02/NN-15 retain only concrete terminal/late-proceeds details not already answered. Most remaining rows are specification, verification or plan work; conditional escalation is not a standing question. NN-13 is separately handled instruction maintenance, not repeat family approval. NN-03's speculative product question is withdrawn.

## 2. Settled decisions — do not reopen

The custom family is approved. The curve/custody model, public shared HLP, Keep-YT inputs, output destinations and ownership restrictions are not new questions.

- Both NET/sNET inputs enter Keep-YT. Both ordinary outputs use **one eligible held-SY budget, held first and claimed if short**, then redeem to the requested token. NET pricing remains PLP/YT-derived. No ordinary-output principal-liquidation fallback, fee-payable use or complete eligible-inventory drainage.
- The four HLP legs and actual Balancer V3 Weighted unbalanced-liquidity semantics are selected. HLP exits retain their distinct rights; SE-leg HLP exits pay raw SE shares, not unwrapped underlying.
- Liquid DETF does not grant proportional HLP ownership. Standard contraction and dedicated reinvestment use only the DETF's owned-reserve book; the synthetic TWAP chooses the standard swap/burn branch, not its payout.
- Opening price is 1,000 NET/DETF; the ongoing target is 1 NET/DETF. Expansion is `floor(S0*n/200)` once for qualifying pending processed NET epochs. Both TWAPs are 3,600-second arithmetic series; absence takes the above-1 policy branch.
- Participation ordering, fee/creator standing rights, funded staking custody, principal-lock baselines, early reward claims and atomic rollover/collection remain. Pre-maturity reinvestment consumes requested funded principal into a new bond with an independent destination-type lock while retaining old NFT/holder/native rights. Intermediate collections do not restart the old lock; final intended contribution in processed epoch E sets ordinary principal unlock to E+1. Purchase epoch, full-collection checkpoint and unlock target stay distinct; unlock zero means assigned Pendle maturity. These timing choices are resolved, not pending another vote.
- One reusable-Package holder per external-bond NFT is selected. Proxy owner stays the NFT contract; rights follow tokenId; standard whole-PkgArgs hashing includes owner and unchanged `bytes32(tokenId)` supplied salt. Register the actual returned native noteId, preserve one intended purchase and same-NFT installment funding, and support excess receipts. H01–H03 below retain exact excess/release-boundary/retirement decisions; per-target upstream scan remains a residual risk.
- Dedicated reinvestment has no contraction incentive; independently allowed contraction/bond composition retains its selected economics.
- Hold the market interest token; other attributable rewards go to current `feeTo()`. Failed fee forwarding retains its excluded payable and is retried without blocking the surrounding operation under the specified isolation requirement.
- Strict ERC-4626/SY conformance certification is not a prerequisite selected by the owner. Truthful interfaces, views, ownership and actual route behavior still require specification.

This corrects the earlier tracker's overly broad “interest inventory only” wording. Provenance and eligibility must follow PRD §§6.2–6.3; retained same-token incentive spendability remains conditional work in NN-11, not permission to classify every held SY receipt as tradable income.

## 3. Work register — all twenty items reviewed

The [completed audit](../../../research/netnet-prd-closure-audit-2026-09-27/COUNCIL_CONSOLIDATION.md) and PRD §16.2 provide the source-derived answers. No new owner decision was demonstrated. Roles below are recommended work ownership, not claims that an implementation task has been assigned or executed. Sections below preserve detailed acceptance obligations; their “close when” wording means technical completion, not another policy vote.

| ID | Status | Answer already available | Remaining deliverable / role |
| --- | --- | --- | --- |
| NN-01 | EVIDENCE | Constants and binding/discovery rules fixed (§16.1) | Configured source/runtime/metadata/oracle evidence and observation blocks; integration verifier |
| NN-02 | ANSWERED / PLAN + EVIDENCE | Per-NFT holder, actual noteId, same-NFT proceeds, new-bond reinvestment, E+1 release (§12.4) | Exact receipt/callback/terminal state transitions and acknowledged per-holder resource evidence; bond plan author |
| NN-03 | CLOSED | Failure model/full sync and non-blocking outgoing reward transfer settled | Existing-scope implementation/tests only; no renewed survival question |
| NN-04 | ANSWERED / PLAN + EVIDENCE | Timing settled; existing reference bonus chain | Match actual oracle terms to selected locks; only demonstrated incompatibility escalates; bond author |
| NN-05 | ANSWERED / PLAN | Custody/pricing matrix, weights50/20/10/20, Universal NET synthetic and existing fees | Apply the selected units coherently in code-path/preview specification; accounting author |
| NN-06 | ANSWERED / PLAN | Outer BasePoolMath and inner proportional allocation, nested floors and source map (§16.2) | Exact scaled caller context, internal share scale/residual/final-exit equations; liquidity author |
| NN-07 | ANSWERED / SOURCE INTEGRATION | Weighted/native order and SY conversion mapped; §6.6 adds local YTv1 claims, exact net-fee math, cache/expiry, once-only receipt rules and conditional redemption composition | Verify actual YT V1/V2 and its body; finish prior-force-claim reconciliation mechanism, provider rounding, owned-HLP/Keep-YT chronology and exact-output residual/domain proof. No new Weighted inverse; full L3 not closed |
| NN-08 | ANSWERED / PLAN + EVIDENCE | Atomic full-book first bond, G/U/B/R, actual SY capital rather than invented yield | Custom input/rate mapping and numeric bootstrap/live-bond examples; bond/liquidity author |
| NN-09 | ANSWERED / PLAN | Two arithmetic cumulative series, selected windows/consumers, V2-style prior-price/extension pattern | Exact history/checkpoint/boundary/interface specification; oracle author; no tick substitute |
| NN-10 | SOURCE MAPPING RECORDED / EVIDENCE + PLAN | Actual SY target/base/helper bodies reviewed; current-sNET versus projected-NET distinction and whole-SY sample derived in plan §6.5 | Pin provider/caller rounding and prove deployed identity/metadata/state/parity; source mapping is not G1 closure. No substitute external SY |
| NN-11 | ANSWERED / IMPLEMENTATION | Public pretransfer uses max(raw held−booked,0) regardless of origin; no sender/provenance proof. Internal role/claim accounting remains once-only | Implement source amount/refund/sync rules and updated A05, not an authentication layer. Conditional incentive spendability only if a real supported case exists |
| NN-12 | ANSWERED / IMPLEMENTATION + VALIDATION | PRD v0.31 selects existing funded-gons arithmetic, standing allocation/dust, and immediate parent transfer/mint notification; no extra user distribution call | Implement/test new no-pull receipt handler, principal contexts, movement coverage and recursion guards. Former B/U reference/representation requirement is superseded, not unresolved |
| NN-13 | MAINTENANCE | Custom-family approval settled, shared instruction authority unchanged | Separately authorized maintainer reconciliation; no instruction bypass by report |
| NN-14 | ANSWERED / PLAN + EVIDENCE | Factory-first atomic settlement/conversion/Keep-YT/commit and historical claims | Call/argument-source/limit/ledger map and verified SY conversion; integration author |
| NN-15 | ANSWERED / IMPLEMENTATION + TEST | Current-owner authority, retained NFT, early rewards, late excess inherits unlock; no explicit retirement process | Implement/test continued collection after inactivity or empty balances; no retirement burn/terminal flag, fee sweep or holder ownership transfer |
| NN-16 | ANSWERED / PLAN + EVIDENCE | Full reference V2 SE, asset()==canonicalPair plus trusted provenance/relationships, tax in SE | Exhaustive retained selector/route parity and tax execution; integration author |
| NN-17 | ANSWERED / PLAN | Actual Crane deployment conventions, owner-containing args hash, selected config | Complete facets/ABI/Repo/authority graph and safe reuse; architecture author |
| NN-18 | PLAN + EVIDENCE | Selected formulas/domains, no hidden caps, acknowledged external-failure scope | Arithmetic horizon/representability analysis and later resource measurement; math/validation author |
| NN-19 | PLAN + EVIDENCE | Existing acceptance law and production-first workflow | Numeric input/output/state/tolerance matrix and separately executed validation; test-plan author |
| NN-20 | PLAN | Mechanical reconciliation, not economic redesign | Correct genuine citations/stale status/companions without fabricating history; documentation author |

**Do not turn rows back into questions because plan details are unwritten.** Conversely, unanswered reference derivations, composed inverses or live checks cannot be labeled passed. A concrete economic conflict, if one is actually demonstrated, must be preserved and reported rather than hidden by this classification.

## 4. Required deliverables and closure criteria

### NN-01 — Dependency and evidence manifest

**Progress 2026-09-28 — claim implementation version gate:** plan v0.9 §6.6 maps the local YTv1 body only. YTv2's interface keeps the claim selector but changes userInterest layout/semantics; its implementation body was not reviewed. Next binding proof must identify actual configured market/YT code/version and validated SY/PT/YT relationships, then obtain the body if different. Observe factory fees/treasury, cache/expiry/postExpiry and gauge/PENDLE identities at a block; no live values or same-token identity inequality were established by the [claim-funding round](../../../research/netnet-pendle-claim-funding/COUNCIL_CONSOLIDATION.md). NN-01 remains evidence work, not a new owner decision.

**Progress 2026-09-27:** following the user's request to record the implementation agent's constants update and proceed, PRD v0.24 §16.1 incorporates the dependency-evidence rules and constants record. The [earlier discussion/proposal](../../../research/netnet-nn01-2026-09-27/NN01_DISCUSSION_AND_PROPOSED_PRD_EDIT.md) remains preserved historical evidence; use current PRD §16.1 for operative wording. Constants subtask is complete; the overall source/deployment manifest and verification remain unfinished. Discussion advances to NN-02 while NN-01 stays IN PROGRESS. §8's **before-implementation** verification deadline is not waived or retrospectively satisfied by the constants update.

**Address research and constants edit 2026-09-27:** [Address findings and implementation record](../../../research/netnet-robinhood-addresses-2026-09-27/ADDRESS_FINDINGS_AND_HANDOFF.md). Core NetNet constants already matched Official Channels. Four published Pendle anchors are observed in `ROBINHOOD_MAIN.sol:195–201`: `PENDLE_MARKET_FACTORY_V6`, `PENDLE_YIELD_CONTRACT_FACTORY_V6`, `PENDLE_ROUTER` and `PENDLE_ROUTER_STATIC`. No expiring market, PT, YT or SY constant was added. The implementation record reports standalone solc 0.8.35 compilation; this council documentation round did not rerun it. Deployed bytecode, factory recognition, conversion, actual oracle terms and depository behavior remain pending. Scaled18 metadata remains an NN-10 input. NN-01 remains IN PROGRESS.

- Record chain, configured addresses, token identities/decimals, deployed implementation/code hashes and observation blocks; distinguish local source snapshots from verified deployed equivalents.
- Pin Pendle market/factory/router/SY, NetNet staking/depository, canonical NET/USDG pair, custom V2 SE, rate providers, fee oracle and the reference Weighted/BasePoolMath revisions. Record upgrade/configuration assumptions and actual oracle terms.
- Cover token direction support, live tax/exemption semantics, native-note maturity and callback/claim behavior. The UI challenge round obtained verification-service compilation evidence for two-day depository vesting; five-day interface prose is stale relative to that compilation. Record that evidence tier without calling it a new current-block runtime/local-build check or asking the owner to choose a duration.
- **Close when:** every required binding/capability has cited evidence or an explicit blocking gap; a package name, symbol, source pragma or historical address is not a release pin.

### NN-02 — External-note liveness

**Latest disposition — partial-reinvestment clarification:** [Completed council round](../../../research/netnet-partial-reinvestment-2026-09-27/COUNCIL_CONSOLIDATION.md), incorporated in PRD v0.26. The user permits requested already-funded principal to be burned incentive-free into a new bond/new tokenId with its destination type's normal lock while the original native note still matures. Keep old NFT/holder/note, remainder/rewards and future proceeds; even zero current principal does not retire future rights. No full-collection prerequisite or unnecessary new native redeem is introduced for this path. Excess native proceeds credit old-NFT principal. Store purchase epoch and preserve its passed-epoch check separately from full collection/final release; unlock epoch zero denotes assigned Pendle maturity. Exact type locks/check ordering remain deferred to the announced review. Earlier broader reinvestment gate wording below is historical.

**Current disposition — holder-proxy round completed:** [Council consolidation](../../../research/netnet-holder-proxy-2026-09-27/COUNCIL_CONSOLIDATION.md) records four originals and four completed same-session cross-reviews after the human-corrected `contracts/fee/collector/FeeCollectorDFPkg.sol` read. Earlier guard failures/partial status remain historical; no participant replacement. PRD v0.25 §12.4 incorporates the user's per-NFT holder Package, permanent NFT-contract ownership, standard PkgArgs hash with owner/providedSalt, actual returned-note registration, same-NFT installment funding and excess acceptance. Principal release now follows full intended-note collection plus the next processed NET epoch, superseding native-maturity-only release. Extra deployment cost and residual per-target exposure are acknowledged, not proven bounded or economically negligible. NN-02 is not closed.

| Detail | Status | Remaining checkpoint |
| --- | --- | --- |
| Holder custody / salt / rights-follow-tokenId | SELECTED | Engineering proof of initialization, one authorized purchase, callback protection and safe exact-config existing-instance reuse; no special salt algorithm |
| H01 — excess | RESOLVED | Same-NFT principal credit; late excess inherits existing/satisfied unlock. No reset or fresh E′+1. Normal actual-receipt/donation accounting is implementation/testing. |
| H02 — epoch boundary | RESOLVED | Intermediate collection does not restart the old NFT's lock; successful final contribution in processed epoch E unlocks ordinary withdrawal at E+1. New reinvestment bonds have their own destination-type locks, independent of old timing. Purchase/completion/unlock semantics stay distinct; unlock zero = assigned Pendle maturity. Engineering ordering/representation remains, not an unanswered policy |
| H03 — replacement/retirement | RESOLVED | No explicit retirement process. User inactivity/zero current principal causes no burn, terminal flag or forfeiture. Old NFT/holder mapping and future receipt rights persist; new bond locks remain independent. |
| Resource and dependency evidence | OPEN | Quantify per-holder upstream scan, deterministic preloads, already-funded-principal release gating and deployment overhead; preserve NN-01 verification limits |

**User-challenge follow-up 2026-09-27:** [Claim-path and UI findings](../../../research/netnet-nn02-ui-2026-09-27/CLAIM_PATH_FINDINGS.md) confirms a narrower distinction: the selected standard BondDepository's verification-service ABI/source exposes only aggregate `redeem(address)`, while RwaDesk and PackDesk ABIs also expose `redeem(address,uint256[] noteIds)`. Those are different products, not a selective helper for standard notes. The actual standard-bond UI write handler remains incompletely traced. Sourcify supplies source/ABI attestation and two-day vesting compilation evidence for NN-01; this is not an independent current-block code check or full local-build equivalence proof. No outage, typical-user note distribution, gas threshold or risk acceptance is established. NN-02 remains IN PROGRESS; no product substitution.

**Earlier discussion (historical):** [NN-02 source review](../../../research/netnet-nn02-2026-09-27/NN02_DISCUSSION.md) established arbitrary-recipient appends and all-note scans without pruning before the user selected holder isolation. Its then-open custody question is superseded by current §12.4, not repeated. No sweep, native-selective selector or quantified gas guarantee has since been invented. Later measurements still require separately authorized execution.

- Finish the selected holder design's exact native-depository propagation, exclusive authority, actual-receipt attribution, bounded intended-note lookup, preview/claim complexity and retirement against the actual native ABI.
- Demonstrate isolation and quantify residual per-target growth including preloads/claimed history. It is not an absolute upstream bound. Separate collection/final-release risk from the selected reinvestment of already-funded principal, which must not acquire a full-collection prerequisite or unnecessary native claim. Other genuine sync/funding failures can still revert; no unconditional availability promise.
- **Close when:** H01–H03 have normative resolutions and a source-valid holder/callback/funding specification plus explicit resource assumptions/evidence gates is accepted. Acknowledged residual exposure is not a measured safety proof. Depends on NN-01; feeds NN-04/NN-15/NN-17/NN-18/NN-19.

### NN-03 — CLOSED: no additional product decision

**Owner disposition 2026-09-27, PRD v0.27 §§6.3/13:** the previous discussion expanded a hypothetical failure concern into an unnecessary product choice. Keep BasicVaultRepo tracking and full expected-set synchronization. Failed outgoing fee-reward transfers retain their excluded payable and do not block the surrounding operation, as already selected. Continued operation through arbitrary broken token balance interfaces or failure of the essential Pendle market is not required. No tiered-sync/stale-value/quarantine/custody-partition decision is requested or adopted.

| Previous concern | Correct disposition |
| --- | --- |
| Failed reward forwarding | Already resolved by §13/A11; implement it, do not re-ask |
| Arbitrary ERC20 spam automatically expands registered token list | Not supported by the inspected explicit-registration code; remove as an alleged vector of this helper |
| Transfer pause necessarily breaks balance reads | Unsupported inference; remove |
| Broken/reverting balance interface or essential market requires continued trading | Outside the required survival model; dependent operations may fail, no fabricated balances or new recovery obligation |
| Normal rollover and residual-token history | Ordinary accounting/resource work under NN-14/NN-18/NN-19; preserve assets and claims, no new hypothetical owner vote |
| Missing archive/quarantine/override implementation | Not a product gap: that design was never selected; remove as an implied deliverable |

Closing this item resolves its **product-question scope**, not a claim that code was implemented, gas measured or tests passed. The [partial research report](../../../research/netnet-nn03-2026-09-27/NN03_PARTIAL_DISCUSSION.md) remains historical; its proposed freshness question is superseded by this owner disposition. That round remains incomplete and has not been silently resumed or called consensus. No further council retry is necessary to record an explicit owner instruction.

### NN-04 — Duration and release compatibility

**Owner timing resolution — PRD v0.28:** a new reinvestment bond's lock is determined by its own issuance/destination type, not inherited from the old bond. Intermediate installments create no new wait on the original NFT. After successful final intended collection/contribution/mint/stake in processed epoch E, original principal remains held until the next processed epoch E+1. The purpose is participation across a subsequent rebase opportunity, not a guaranteed positive rebase or full elapsed eight-hour minimum. Purchase-epoch passage, completion and unlock target stay distinct; unlock zero retains assigned-Pendle-maturity meaning. No full-collection prerequisite is imposed on the selected pre-maturity reinvestment path.

**Example accepted:** purchase in 100, purchase check passed in 101, non-final collection in 105 creates no new old-NFT lock. Final contribution in 106 sets final unlock to 107. A new bond purchased using reinvested principal uses its own normal type lock; it does not inherit any of those old epochs. No owner timing answer remains pending.

- For each position class, tabulate actual oracle minimum/maximum terms, quote-duration input, multiplier, maturity predicate, reward claims and final principal release.
- Cover next-epoch entry seconds before processing, terminal Pendle maturity, zero remaining duration and native proceeds contributed after full native maturity.
- Preserve custom cliffs and early funded reward claims, and implement the settled no-intermediate-reset/final-E+1/independent-new-lock rules. Do not silently extend locks, fabricate duration for a larger bonus, drop the bonus or reject a selected entry class. Complete the ordinary source/formula compatibility work before raising any further question.
- **Close when:** every case has a source-compatible calculation, or a concrete proposal has owner approval. Depends on NN-01; feeds NN-08/NN-15.

### NN-05 — Custody-to-pricing model and parameter decisions

**Owner choices resolved, source checked 2026-09-27:** NET-DETF50%, NET20%, sNET10%, USDG20%. Reuse Universal DETF's Weighted synthetic calculation with NET numeraire and total NET-DETF supply. Use existing hook-proxy vault usage fee and DETF-proxy seigniorage share from the existing oracle. [Completed source-verification round](../../../research/netnet-weights-fees-2026-09-27/COUNCIL_CONSOLIDATION.md); operative PRD §§4.4/4.6/7.1.4. No numeric fee, new oracle or new synthetic model is pending owner selection.

- Deliver the typed unit/ownership mapping for raw DETF, SE shares, held/claimable SY, PLP/YT subshares and residuals, preserving their selected valuation and spendability distinctions.
- Apply the source-mapped marginal nonself mark into NET, actual owned-HLP fraction and projected protocol-fee dilution, native9→WAD once and pending supply once. Creation normalization is1e18 for the 1-NET peg; first-bond opening remains1000e18 in its separate slot.
- Preserve reference hook growth-share protocol-HLP minting, not an extra flat deposit haircut. Preserve separate-floor DETF live/bond splits; oracle stored-zero fallback means vault→type→global. Actual live oracle configuration is NN-01 evidence, not a percentage to invent.
- Complete safe unit/domain/rounding and preview/settlement integration; related zero-interest bootstrap, subshares, SY conversion and observation details remain NN-06/NN-08/NN-09/NN-10 work. Do not import Universal expansion policy, fresh liquid minting or change shared-SY ordinary funding merely to copy a helper.
- **Close when:** the remaining custom mappings and worked transition examples preserve selected reference behavior and conservation. Escalate only a concrete incompatibility. Owner choices are resolved; no executed parity is claimed. Depends on NN-01/NN-10; feeds NN-06–NN-09.

### NN-06 — HLP and position-subshare lifecycle

**Answered model / plan mapping:** PRD §§4.4/7.1/16.2 already select custody units, outer BasePoolMath modes and inner proportional ownership. Use the [audit's concrete function/rounding map](../../../research/netnet-prd-closure-audit-2026-09-27/COUNCIL_CONSOLIDATION.md#3-weighted-lp-accounting-concrete-mapping). This is not a request for another reserve accounting design. The V2 reference supplies geometric initial and min-ratio later share patterns; don't import unpriced unequal-contribution donations or claim unequal ratios impossible without proof. The following equations/edge-case work belongs in the implementation plan.

- Specify initial subshare scale, minting, unequal PLP/YT contributions, residuals/dust, proportional allocation, final exit and rollover reconciliation.
- Price existing earned value into HLP admission; all accrued value follows HLP transfers without a seller-retained claim.
- Use actual Balancer V3 Weighted unbalanced accounting, including taxable imbalance, share rounding and bounds. No h/H shortcut for selected-leg exits, omitted-leg coupon or unapproved wrapper approximation.
- **Close when:** every join/transfer/exit/zero/last-share case has deterministic equations and reference-mapped numeric vectors, preserving remaining holders' rights. Depends on NN-05/NN-11.

### NN-07 — Quote, funding and settlement transitions

**Follow-up progress 2026-09-28 — Pendle claim funding:** [Claim-funding consolidation](../../../research/netnet-pendle-claim-funding/COUNCIL_CONSOLIDATION.md) preserves four new originals/four same-session reviews in existing sessions. Eight calls returned; Grok explicitly read only part of MiniMax's original, so complete four-way review coverage/consensus is not claimed. Moderator checked primary bodies and added plan v0.9 §6.6. Local YTv1 interest pays hook via redeemDueInterestAndRewards; market redeemRewards pays LP incentives, not principal. C includes current WAD-scaled accrual minus one floor-rounded factory fee, not stale gross accrued. Claim iff H<d. Preserve complete required interest/reward collection and propagate upstream failure; only subsequent hook→feeTo forwarding is nonblocking. No new fee, ordinary PLP/YT fallback or percentage floor.

**Narrow remaining blockers:** establish configured YT V1/V2 and source identity; V2 exposes a different three-field userInterest layout despite the same selector. Finish the on-chain mechanism reconciling historical unnotified receipts without erasing declared public credit, inventing receivables or requiring payer provenance. Event monitoring/raw surplus alone is not that mechanism. Provider/caller rounding, full owned-HLP/Keep-YT chronology and exact-output residual/domain proof remain separate. G1 live bindings/fees/cache/treasury/gauge state unobserved; all vectors unexecuted. Local claim graph is mapped, not certified as the deployed implementation. Historical entries below remain intact.

**Progress 2026-09-28 — completed fresh post-extraction round:** [Consolidation and four new session IDs](../../../research/netnet-sy-conversion-post-extraction/COUNCIL_CONSOLIDATION.md). Four originals and four same-session combined cross-reviews inspected actual conversion bodies; plan v0.8 §6.5 replaces obsolete unread-body/extraction blockers. It records four NET/sNET branches, one-step projection, fixed-state minimum-sufficient inverses, hook-held false-flag custody, nominal minOut after payout, actual receipt checks and H<d claim triggering with a positive held-plus-remaining-net-claims remainder. H is eligible booked inventory, **not** public raw-minus-booked surplus. No persistent SY-owned hook reserve, compensating burn-recovery layer, preview correction multiplier, second fee or ordinary PLP/YT fallback is adopted.

**Status separation:** source conversion mapping resolved; **complete L3 composition pending** for actual configured claim/fee/recipient graph, provider/caller rounding, full Keep-YT/owned-HLP chronology and exact-output domain/residual proof. For I>1e18 the minimal SY debit may overshoot a requested native amount; the round does not select a new residual beneficiary or silently drop required ERC4626 withdrawal. G1 runtime/state evidence and later tests remain separate. Dissent and rejected recommendations are preserved in the report rather than labeled unanimous agreement. G0/L4 unchanged; L1/L2 and NN-03 stay resolved. No tests or product implementation executed.

**User-supplied source confirmed:** `lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol:14–49` contains both fee-inclusive directions, including upward exact-output fee gross-up. Existing composed-stable caller uses it at :764–767; the V4 Weighted wrapper already implements native scaling order at :209–227. Plan §6.4 and PRD §4.3 now name these directly. Do not invent an exact-output Weighted solver or charge its fee twice. This resolves the helper-identification task; actual external conversion/funding source mapping remains distinct. No tests were executed.

For every supported join, swap, exit, burn and reinvestment, specify:

1. Coherent starting state and required epoch/TWAP settlement.
2. Reconciliation of claims, prior receipts and ownership.
3. Quote inputs, balances/rates/weights, fee order and rounding.
4. Authorized external operations and actual receipt/expenditure measurement.
5. Custody/provenance updates and exact token/share/supply changes.
6. User limits, final conservation and atomic failure behavior.

- Ordinary NET/sNET outputs share finite eligible SY, held first and claimed if short; USDG output uses SE inventory. Define eligibility and the native-unit retained-inventory floor without relabeling principal or using fee payables.
- Construct the owned-HLP book **before** burn/reinvestment quotation, not by scaling/capping a whole-pool nonlinear quote afterward. Specify the separate owned-reserve realization sequence and HLP/self-leg/supply effects.
- Standard contraction applies the quote-only incentive once and burns actual input; dedicated reinvestment uses actual input without that incentive in every price regime.
- Specify exact-output inversion, supported route domains, `max*`/preview behavior and insufficient-funding rollback. Do not substitute “unsupported” for the selected ERC-4626 exact-output withdrawal.
- **Close when:** all operation rows have deterministic transitions and boundary examples, including sequential NET/sNET budget use and HLP interleavings. Depends on NN-05/NN-06/NN-09–NN-12.

### NN-08 — Bootstrap and subsequent bonds

**Derived answer:** the reference first-bond caller pulls every required full-book leg atomically (`UniswapV4DetfTarget.sol:629–668`). Direct SY capital is permitted by the PRD, so zero earned interest does not require an empty SY custody leg or invented yield. Preserve one atomic activation and separate principal/reward funding; a partial-first-mint helper is not permission to bypass full-book liveness. Finish the exact unit/payment mapping as plan work, not another bootstrap-policy vote.

- Map actual lead/additional payments into four-leg initialization, opening units and reference G/U/B/R split, with nonzero HLP and atomic buyer/reward funding.
- Demonstrate initially zero accrued interest without labeling contributed principal as earned yield or inventing a separate seed mechanism.
- Specify later-bond G/U live-book mappings, not only the first-bond illustration. Preserve native nine-decimal DETF floors and distinguish quote basis U from actual issuance.
- **Close when:** complete initial/live-bond examples and failure cases follow the selected formulas and resolved durations. Depends on NN-04–NN-06/NN-10/NN-12.

### NN-09 — TWAP semantics and standard interface

**Source-derived implementation pattern:** V2 `UniV2Pair._update:215–224` accumulates prior arithmetic price×time; NetNet `PairOracle._currentCumulative:118–130` extends without writing. Adapt those semantics to the two selected series; ring/search utilities are structural references only. No truncated-tick integrand, invented fixed-capacity proof or reconstruction of unobserved external prices. The exact observation contract below remains a concrete plan deliverable.

- Define both `price(u)` processes, including behavior between observations when external Pendle state/index/rates change without hook activity. Do not equate sample-and-hold with continuously changing executable valuation without specifying that semantic choice.
- Specify price units/scales, update triggers, initialization, same-block ordering, boundary retrieval, retention, quiet-period consultation extension, expiry/rollover handling and overflow bounds.
- Define interface results/readiness, projected views and callback-safe consultation in Markdown. Distinguish warm-up from malformed data; preserve the absent-as-above-1 branch policy without inventing a measured price.
- **Close when:** the complete semantic contract and expected boundary vectors determine both series and their consumers. Existing-hook retrofit remains out of scope. Depends on NN-05/NN-10/NN-18.

### NN-10 — Reusable SY provider

**Progress 2026-09-28 — conversion bodies reviewed:** [Post-extraction council](../../../research/netnet-sy-conversion-post-extraction/COUNCIL_CONSOLIDATION.md) and plan v0.8 §6.5 supersede the next-step language in the historical extraction entry below. The target/base/TokenHelper/supply-cap/ERC20 bodies establish source formulas and custody. SY shares are not either metadata wrapper. Direct sNET uses current index; `exchangeRate()` uses projected index in scaled-NET terms. For verified SY18/sNET9, sample q=1e18 raw SY yields a=Ic and normalized rate=Ic*1e9; q=1 raw may yield zero. Pin the provider-to-caller rounding convention separately from full-size redemption funding. Wrapper implementation absence does not block unused raw NET/sNET routes; actual metadata still needs evidence.

**Remaining G1:** current block-pinned proxy/code/immutable/market bindings and decimals; deployed NetNet mirror constants/epoch tuple/rebase order; warmup/immediate backing, enabled/oracle/distributor, actual allowances/balances/pause/cap and tax predicates at real endpoints. Local NetNet bodies remain reference only. Source-level conversion mapping is resolved, **not** complete L3 or deployment validation. The extraction manifest's hashes/round-trip were cited, not rerun. All new test cases remain unexecuted; no new economic question or extraction campaign is requested.

**Actual-source investigation completed; readable extraction completed 2026-09-28:** [L3 council consolidation](../../../research/netnet-sy-conversion-2026-09-27/COUNCIL_CONSOLIDATION.md), four originals/four cross-reviews. The candidate proxy resolves through the verification service to `PendleStakedNetSY` at `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`; exact-match record/compiler details are recorded in plan §6.5. The downloaded public payload is now decoded in [VERIFIED_SY_SOURCE_EXTRACTS.md](../../../research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md), with a successful content round-trip and a matching target keccak256. No 1:1 mint, exact inverse, current exemption/cap or complete conversion review is claimed yet. Next task is inspection of the extracted conversion bodies and their imported dependencies, not another extraction, economic decision or broad web search. Weighted quotation remains separately resolved; public pretransfer policy unchanged.

**Scope correction:** use the configured external Pendle SY and specify the reusable rate provider. Missing external SY source in the vendor tree is an evidence task, not authorization to build a replacement NetNet SY. Do not confuse the hook's SY-compatible interface with the external market's SY contract.

- Verify actual accounting-asset versus target-token denomination, decimals, supported NET/sNET conversion, rebasing/scaled-unit behavior, sample size and zero/failure handling.
- Address the primary-source preview warning using the configured implementation and preview/execution analysis. Neither `exchangeRate()` nor metadata alone establishes an executable sNET quote.
- Keep the reusable per-SY rate separate from hook balances/claims; sampled valuation is not whole-position deliverability.
- **Close when:** a source-verified conversion/rate specification and its later validation requirements are accepted. Depends on NN-01; feeds NN-05/NN-07/NN-11.

### NN-11 — Provenance and contribution credit

- **L2 CLOSED by owner clarification:** public pretransfer integration is caller responsibility. Credit the declared amount from positive unbooked raw surplus under existing route/caller/amount checks, regardless of whether it came from that caller, a donation or a prior forced claim. Do not require an authenticated sender receipt, payer witness or anti-front-running reservation. PRD v0.32 §6.3 and plan v0.5 §6.1 are operative.
- Protect booked reserves and consume available credit once. Pull mode measures its own actual delta; true-flag exact input does not refund unused maximums; true-flag exact-output refunds are bounded by unused credited input and remaining available funds. Refund before full-set sync. Do not sync early solely to take surplus away from a caller.
- Maintain once-only claims/held/payable accounting after recognition; a settled receivable cannot remain counted beside the same cash or caller-consumed input. Transient Keep-YT/principal-exit SY cannot be double-entitled. These bookkeeping requirements are not provenance restrictions on public unbooked credit.
- Internal staking funding contexts remain to classify principal versus rewards for automatic notification, not as a condition on public SE/HLP pretransfer availability.
- Inspect whether a real configured interest-token/incentive collision exists. If it does and spendability remains undecided, present that narrow case to the owner; retention/forwarding destinations remain settled.
- **Implementation complete when:** updated amount/refund/sync tests pass and actual internal claims/roles are once-counted. Product L2 is already resolved; no test is claimed run. Apply NN-03's resolved failure scope and do not recreate a provenance or freshness questionnaire.

### NN-12 — Funded staking, standing recipients and zero-share cases

**Current resolution — v0.31:** the owner permits sNET-style accounting and prefers reward distribution by ordinary NET-DETF transfer. [Completed transfer-funded staking consultation](../../../research/netnet-transfer-funded-staking-2026-09-27/COUNCIL_CONSOLIDATION.md) maps this to the existing IndexedEx funded-gons math/Repo/Target with a new parent movement-notification and already-received funding adapter. Positive ordinary transfers/mints distribute in the same transaction, without a second user call; authenticated principal contexts prevent principal from being distributed. Preserve source allocation/dust/zero-weight behavior and all custom locks/fees/expansion rules. No stock premint/cap/clock. L1 is resolved as a model-specification issue; adapter correctness still needs actual implementation/tests. The prior B/U analyses below are historical and no longer a required model to implement.

**Protocol-source follow-up:** [NetNet/Pendle rebasing consultation](../../../research/netnet-balance-rebase-2026-09-27/COUNCIL_CONSOLIDATION.md) completed after the human-authorized corrected wrapper path. NetNet exact-fragment transfer, wsNET floor conversion and Pendle static-share behavior were inspected; none justifies the rejected rounded-divisor/live-ratio equivalence or reward payout without share debit. Plan §9.3 adds a principal-safe reward-share budget with its precise limitation: it can defer an otherwise displayed native reward and does not by itself resolve fixed-principal admission, receipt transfer or orphan/recipient rounding. No general rebasing-impossibility claim and no false L1 closure. Earlier blanket precision/equivalence assertions remain corrected historical evidence.

**Audit finding:** the intended unnamed `docs/plans/detf/` reference was not located. Upstream StakedNET's gons and old Balancer DETF's cached/NFT-extractable-value receipt are not the selected live-B/U model. `DETFSeigniorageShareLib:18–33` supplies supporting standing-weight algebra, not every zero-share funding branch. PRD §10.2 is authoritative; finish an explicit faithful derivation/reference repair rather than falsely marking the missing source found or asking whether recipient rights exist again.

- Reuse `DETFFundedStakingMath`, `DETFFundedStakingRepo`, `StakedDETFTarget` and standing top-up mechanics as now explicitly selected; do not claim the previously missing B/U reference was found.
- Implement already-received reward funding, not another `fundRewards` pull; notify all custom DETF transfer/transferFrom/internal mint/transfer paths into staking exactly once. Use actual operation receipts, not all held-minus-accounted surplus.
- Establish principal/legacy-pull context before movement, authenticate the callback and distinguish zero/self transfer. Notification never recursively synchronizes. Test allowed sync callback versus forbidden reentry, full backing and local NFT fraction retirement.
- **Implementation complete when:** source allocation/rebase/receipt/top-up/dust behavior and no-extra-user-call integration pass the named tests. No further rebasing-model choice pending; no execution evidence is claimed by this update. Feeds NN-07/NN-08/NN-15.

### NN-13 — Execution-authority handoff

- Record scoped custom-family deviations and their authoritative owner decisions separately from unchanged Universal-family requirements, including token behavior, cliff locks and direct DETF-as-SY.
- Report the mismatch with current shared token instructions and the inherited FoT-negative testing rule. Record the separately authorized maintainer disposition needed for an unambiguous implementation handoff.
- **Close when:** the responsible process provides an authoritative, consistent handoff. This tracker cannot amend instructions or grant permission to bypass them; no instruction changes are authorized by this update. Product approval is not pending again.

### NN-14 — Rollover, historical series and reward retries

- Complete the actual external-call/argument-source table: stored configuration, factory-validated discovery, owned amounts or irreducible caller protections.
- Specify old/new-SY conversion, checkpoints, LP/PT/YT realization, successor Keep-YT allocation, residuals, late claims, safe retirement and callback isolation with one atomic commit.
- Keep required migration failures distinct from best-effort fee-forwarding failures; retries preserve excluded payables and current `feeTo()` resolution.
- **Close when:** accepted transitions preserve HLP/NFT rights, maturities and bounded historical access under the specified operating model, including same/different SY and empty/incompatible successor failure. Depends on NN-06/NN-10/NN-11/NN-18; NN-03 is resolved scope guidance, not an open approval dependency.

### NN-15 — NFT and native-note lifecycle

- Specify purchase payment conversion/limits, note provenance, exclusive custody, holder/operator permissions, transfer of all capabilities and atomic collection → contribution → mint → stake.
- Implement partial/late claims, reward-only claims and principal release without stranding native proceeds or funded stake. Late excess inherits the existing unlock. No explicit retirement method or terminal processing; inactivity leaves NFT rights intact.
- **Close when:** every lifecycle state/action has explicit authorization, custody changes, outputs, maturity invariants and rollback behavior. Depends on NN-02/NN-04/NN-07/NN-12.

### NN-16 — Full-feature custom V2 SE

**Concrete binding/surface map:** the reference DFPkg initializes ERC4626 asset to its reserve pair (`:576–601`), so require `asset()==canonicalPair` together with token/factory identity, trusted package/registry provenance and directional capabilities. Researchers mapped nine facet cuts and fourteen advertised interfaces, plus seven QueryFacet quote/transition selectors; the plan must enumerate inherited functionality too. The custom SE, not upstream TaxCollector or the hook, owns per-hop tax modeling. This resolves the general validation approach without claiming exhaustive parity tests performed.

- Pin and inventory all installed/inherited selectors, standard routes, previews/transition quotes, share/permit behavior, wrappers, joins/exits, fees, pretransfer/refund modes and package deployment behavior.
- Map taxed/untaxed per-hop execution and live exemption predicates to actual endpoints and net delivery, without duplicating tax in the hook.
- Specify a source-backed canonical NET/USDG V2 binding predicate, including a correctly configured empty SE; a token list or incidental LP balance alone is insufficient.
- **Close when:** every reference feature and validation predicate has a concrete design/parity obligation, with incompatibilities explicitly blocked rather than omitted. Depends on NN-01/NN-11; feeds NN-17/NN-19.

### NN-17 — Deployment, ABI and authority graph

- Freeze package/facet/registry/factory/child wiring, hook address flags and salt derivation; distinguish hook flag mining from fixed `NET-DETF` instance salt.
- Map every configuration field and recipient to its source. Specify repeat requests with changed arguments: existing-instance return versus revert, effective-configuration reporting and no second instance.
- List interfaces/selectors, events/errors, allowance/internal-balance modes, caller capabilities, callbacks/reentrancy guards and precise Repo responsibilities.
- **Close when:** the plan fixes these engineering choices consistently with all accepted behavioral specifications. Missing code is not a separate product question. Depends on NN-01/NN-13/NN-16 and applicable operation specifications.

### NN-18 — Arithmetic and execution bounds

- Specify safe intermediates, accumulator/supply representability, final-supply limits, supported numeric domains and a defensible operating horizon.
- Preserve one aggregate expansion calculation independent of missed-epoch count, with no hidden cap, replay or silent epoch discard. A perpetual overflow revert is not an examined recovery design.
- Document work bounds for notes, historical assets, synchronization, claims and atomic rollover. Distinguish analytical/source bounds from later measured gas evidence.
- **Close when:** supported numeric domains and resource bounds are specified for normal operation with justified assumptions. Do not invent recovery from arbitrary essential upstream failure. A demonstrated normal-operation conflict requiring product change needs explicit disposition. Depends on NN-01/NN-02/NN-05 and coordinates with NN-09/NN-14; NN-03 adds no open approval gate.

### NN-19 — Quantitative acceptance and traceability

- Map every R/O/C/A item and NN item to the authoritative specification, plan task, production-first test surface, numeric inputs, expected outputs/invariants, tolerances and failure cases.
- Include non-blocking outgoing reward-transfer failure with functioning reads, normal history growth, unsolicited notes, positive unbooked donation/force-claim pretransfer acceptance, booked-balance/overclaim/refund negatives, external-only oracle changes, bootstrap, last exits, bonds, exact-output capacity, arithmetic horizon and NFT retirement. Do not retain obsolete tests requiring rejection of unbooked surplus based on origin. Broken required reads may revert; no forced survival/quarantine requirement.
- Identify actual TestBases, dependency/reference oracles and separately authorized hermetic/fork validation work. Respect current default/fork-only profiles; stale package-profile examples are not an owner decision.
- **Close when:** coverage has concrete correctness criteria and all later execution gates are visibly pending—not claimed passed. Depends on the relevant NN specifications.

### NN-20 — Document reconciliation

- Repair the staking reference with NN-12; give O09 an explicit policy/specification status; separate preparation from last-revision date.
- Explain missing version history without inventing it; mark superseded historical statements locally; clarify that “sNET-input completion is not inferred” concerns implementation status, not unresolved routing.
- Reconcile companion tracker/matrix language against the current operative PRD; avoid multiple competing formulations of the same rule.
- **Close when:** links/status/terminology and cross-document mappings agree, without changing economics. This update replaces only this tracker; cleanup of the PRD and other companions remains open.

## 5. Evidence and original-scope crosswalk

The [consolidated review](../../../research/netnet-prd-quality-2026-09-27/COUNCIL_REVIEW.md) contains attributed positions, corrections, confidence limits and preserved researcher session IDs. Evidence below refers to inspected local snapshots, not deployment certification.

| Evidence | Relevant item |
| --- | --- |
| `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–165,183–188`: arbitrary note recipients and all-note scans | NN-02 |
| `contracts/vaults/basic/BasicVaultCommon.sol:46–54,80–105`: full registered-token balance reads and delta-based pretransfer credit | NN-03/NN-11 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:104–109`; `contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol:17–50`: duration calculation chain | NN-04 |
| PRD §§4.3–4.5,6–7,10.4 and C07/C11/C12 | NN-05–NN-11 |
| PRD §10.2, reviewed v0.23 line 637: unresolved balance-derived reference | NN-12 |
| `CLAUDE.md:45–46`; `docs/agent/INDEXEDEX_AGENT_LAW.md:89–101`; canonical adversarial skill L2 | NN-13 |
| [Pendle SY primary documentation](https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield), accessed 2026-09-27 in the review after Context7 lookup: preview reliability warning | NN-10 |
| `foundry.toml:1–5,29–36,67–72`: configured solc 0.8.35, optimizer runs 1, no via-IR, default/fork product gates; not a runtime check | NN-17/NN-19 |

The previous six accounting topics are preserved and expanded:

| Previous topic | Tracking IDs |
| --- | --- |
| Map actual holdings to pricing balances | NN-05/NN-10 |
| Separate valuation from spendable inventory | NN-07/NN-11 |
| Quote-and-settlement transition per operation | NN-07/NN-14/NN-15 |
| HLP issuance and exits | NN-06 |
| DETF-owned burn-pricing book | NN-05/NN-07 |
| First-bond initialization | NN-04/NN-08 |

## 6. Suggested sequence and human checkpoints

1. **Evidence and early specification:** NN-01/NN-02, the owner-requested NN-04 lock review, NN-10 and the separate NN-13 process. NN-03 is closed. Separate actual missing requirements from normal engineering work and accepted external-dependency failure exposure.
2. **Accounting and oracle specification:** NN-05–NN-12 and NN-18, iterating mutually dependent definitions as one coherent model.
3. **Lifecycle and plan completeness:** NN-14–NN-17 plus NN-19; complete NN-20 alongside accepted specification updates.
4. **Focused owner checkpoint:** raise only an actual unclassified economic case or demonstrated incompatibility after applying existing rules. C07 weights/reference synthetic/fees are now resolved; do not re-ask them or ask the owner to design storage.
5. **Freeze review:** check the criteria below before handing the plan to an implementer.

### Executable-plan freeze checklist

- [ ] No unresolved economic values, entitlement/availability choices or scope decisions.
- [ ] No missing normative formula reference or unproved upstream capability treated as available.
- [ ] Every operation has units, equations, fees, rounding, custody changes, permissions, limits and failure behavior.
- [ ] Feasibility assumptions and arithmetic/resource bounds are explicit; unresolved incompatibilities remain blocked.
- [ ] Interfaces, state layouts, deployment/configuration and callback ordering are fixed in the plan.
- [ ] R/C/A requirements map to quantitative acceptance specifications and later execution gates.
- [ ] Custom-family execution authority is unambiguous through the appropriate authorized process.
- [ ] Resolution records link to accepted artifacts; no item is closed only because it appears in a plan task.

### Resolution log

| Date | Item(s) | Change / disposition | Evidence or accepted artifact |
| --- | --- | --- | --- |
| 2026-09-27 | NN-01–NN-20 | Registered remaining work from v0.23 and the completed council review; corrected stale ordinary-SY wording; no technical closure claimed | This tracker and linked review |
| 2026-09-27 | NN-01 | OPEN → IN PROGRESS: moderator coordinates first-item discussion; four originals/four cross-reviews completed; proposed wording awaits discussion, manifest/evidence work remains pending | [NN-01 discussion and unapproved PRD edit](../../../research/netnet-nn01-2026-09-27/NN01_DISCUSSION_AND_PROPOSED_PRD_EDIT.md) |
| 2026-09-27 | NN-01 | IN PROGRESS: four published Pendle discovery/integration constants added to `ROBINHOOD_MAIN.sol`; solc 0.8.35 parsed the library. Deployed verification remains pending; no perpetual market pin | [Address findings and implementation record](../../../research/netnet-robinhood-addresses-2026-09-27/ADDRESS_FINDINGS_AND_HANDOFF.md) |
| 2026-09-27 | NN-01 | User-confirmed implementation-agent constants completion recorded in PRD v0.24 §16.1; declarations observed and compile result attributed; manifest rules incorporated, remaining evidence gates stay open | PRD §16.1; address implementation record |
| 2026-09-27 | NN-02 | OPEN → IN PROGRESS: next-item discussion and source review completed; PRD §12.3 clarifies scan/provenance limitations; no technical remedy or weaker guarantee adopted | [NN-02 discussion](../../../research/netnet-nn02-2026-09-27/NN02_DISCUSSION.md) |
| 2026-09-27 | NN-01 / NN-02 | User challenge investigated: standard-depository verified-compilation ABI/source evidence obtained; other desks have selective note-ID overloads; exact standard UI handler remains untraced; no broad deployment closure or product substitution | [Claim-path findings](../../../research/netnet-nn02-ui-2026-09-27/CLAIM_PATH_FINDINGS.md) |
| 2026-09-27 | NN-02 | Holder-proxy consultation completed after authorized recovery; PRD v0.25 records selected per-NFT custody, standard PkgArgs hash, excess acceptance and full-collection/next-epoch principal release. H01–H03 and engineering evidence remain open | [Holder-proxy consolidation](../../../research/netnet-holder-proxy-2026-09-27/COUNCIL_CONSOLIDATION.md); PRD §12.4 |
| 2026-09-27 | NN-02 / NN-04 / NN-15 | PRD v0.26 records pre-maturity reinvestment of actual funded principal into a new bond with old NFT/native rights retained; same-NFT excess principal and unlock-zero maturity meaning settled. Exact locks/order and terminal edges remain open | [Partial-reinvestment consolidation](../../../research/netnet-partial-reinvestment-2026-09-27/COUNCIL_CONSOLIDATION.md); PRD §§10/12.4 |
| 2026-09-27 | NN-03 | OPEN → IN PROGRESS: source-grounded explanation and conditional freshness decision drafted; council round interrupted by Grok continuation response, remaining cross-reviews not called; no policy amendment | [NN-03 partial discussion](../../../research/netnet-nn03-2026-09-27/NN03_PARTIAL_DISCUSSION.md) |
| 2026-09-27 | NN-03 / NN-14 / NN-18 / NN-19 | Owner rejects speculative upstream-survival questionnaire. NN-03 CLOSED as product question; full accounting/sync and prior reward-transfer rule preserved, normal history/resource validation remains engineering work. Question filter and duplicate obligations reconciled | PRD v0.27 §§6.3/13/C03/A11; this tracker NN-03 |
| 2026-09-27 | NN-04 / H02 | Owner timing resolved: no intermediate-installment lock reset, final contribution epoch E unlocks at E+1, new bond's destination-type lock independent of old lock. Reference-duration compatibility remains engineering work; no new council round or validation claim | PRD v0.28 §§10/12.4/H02/A08 |
| 2026-09-27 | NN-05 / C07 | Owner weights50/20/10/20 and reused Universal NET synthetic/usage/seigniorage mechanics recorded after successful source retry and completed council round. Fees/formula/weights not open questions; custom mapping/verification remains engineering work | PRD v0.29 §§4.4/4.6/7.1.4; [source consolidation](../../../research/netnet-weights-fees-2026-09-27/COUNCIL_CONSOLIDATION.md) |
| 2026-09-27 | NN-01–NN-20 | Full closure audit: four originals/four cross-reviews; every row classified as answered requirement, plan/source work, evidence or maintenance. Concrete Weighted/Pendle/SE/bootstrap/TWAP source mappings added; false staking-reference substitutes rejected. No new owner questionnaire or implemented/tested completion claimed | PRD v0.30 §16.2; [all-item closure audit](../../../research/netnet-prd-closure-audit-2026-09-27/COUNCIL_CONSOLIDATION.md) |
| 2026-09-27 | NN-01–NN-20 | Implementation/test plan v0.1 authored beside PRD, with state/route/math contracts, work packages/dependency order, all A01–A50 mapped and explicit G0–G5 gates. No item marked implemented/tested merely by plan authorship | [Implementation and test plan](./NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md) §§2/12–15 |
| 2026-09-27 | NN-06/NN-07/NN-09/NN-11/NN-12/NN-15/NN-17 | Plan-completion round resumed and all four cross-reviews completed. Plan v0.2 incorporates correct inline algorithms/ABI/state/tests, retires blanket future-annex gates and documents narrow L1–L4 plus remaining custom interface/initialization work. Integer B/U counterexamples and receipt-authentication limits prevent a false complete/ready claim | [Completed plan review](../../../research/netnet-plan-completion-2026-09-27/COUNCIL_CONSOLIDATION.md); plan §§2/6/8/9 |
| 2026-09-27 | NN-12 / plan L1 | Corrected-path NetNet/Pendle source round completed: four originals/four cross-reviews; reference promises distinguished, principal-safe local reward construction recorded with deferral/admission limits; no incompatible gons/index import or closure claim | [Rebasing source consolidation](../../../research/netnet-balance-rebase-2026-09-27/COUNCIL_CONSOLIDATION.md); plan §9.3 |
| 2026-09-27 | NN-10/NN-12/NN-17 | Plan v0.3 adds custom ABI/phase contracts and records targeted live-divisor alternative without adopting it. Sourcify identifies candidate SY proxy implementation, but conversion bodies remain uninspected. No false plan-completion or source-inverse claim | [Plan authoring progress](../../../research/netnet-plan-completion-2026-09-27/PLAN_V03_PROGRESS.md); plan §§5.4–5.6/9.4 |
| 2026-09-27 | NN-12 / L1 | Owner-authorized model change recorded: funded-gons source + custom parent movement notification gives transfer-only user reward funding. Four originals/four cross-reviews complete; PRD v0.31/plan v0.4 supersede literal B/U/no-refresh, preserve all other policy. L1 model issue resolved; new adapter implementation/tests pending | [Transfer-funded staking consolidation](../../../research/netnet-transfer-funded-staking-2026-09-27/COUNCIL_CONSOLIDATION.md); PRD §10.2; plan §9 |
| 2026-09-27 | NN-11 / L2 | CLOSED as product issue by owner: unbooked raw balance available to next eligible pretransfer caller regardless of origin; removed added proof/receipt layer and obsolete force-claim rejection criterion; preserved booked protection and staking funding classification | PRD v0.32 §6.3/C12/A05; plan v0.5 §6.1; no new council round or tests |
| 2026-09-27 | NN-07 / L3 | Read user-specified Weighted quote library, underlying math and actual callers. Fee-inclusive exact-in/out functions already exist; PRD v0.33/plan v0.6 map direct reuse and native rounding. No new solver needed; external conversion/funding verification not falsely closed | PRD §4.3; plan §6.4; local source lines cited there |
| 2026-09-28 | NN-07/NN-10 / L3 | Readable extraction of the already-downloaded public source bundle completed. All 25 contents round-tripped; target keccak256 matches the previously reported hash. Conversion-body analysis and L3 closure remain open. No formula invented | [VERIFIED_SY_SOURCE_EXTRACTS.md](../../../research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md); plan §6.5 |

For each subsequent update record the assignee, status transition, artifact section, evidence, acceptance/owner decision if required, and remaining execution validation. Do not delete closed rows or reuse their IDs.

Use PRD v0.32 and plan v0.5: L1 funded-gons and L2 caller-responsibility surplus credit are resolved. Do not re-ask those choices or preserve obsolete provenance tests. L3/L4 and actual implementation/configuration evidence remain separate. This direct documentation amendment authorizes no code, tests, deployment, transactions or instruction changes and starts no new council round.
