# Astra — ORIGINAL independent review of NetNet–Pendle DETF PRD v0.23

Date: 2026-09-27. Target: `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` (all 1,101 lines read). This is the original first pass; preserve unchanged.

Attribution: Astra, assigned routing/model label `openai/gpt-6-astra` in the supplied session instructions. I have no independent provider verification or runtime attestation. No other participant's review artifact was opened, searched, or used. Historical dispositions embedded in the required target were encountered but are not authority for these findings. No shell, tests, deployment, code changes, delegation, or skill invocation occurred.

## Verdict

**Good decision record and unusually careful research PRD; not ready for an implementation plan that leaves no decisions to the implementer.** Its own status at lines 9 and 849–870 correctly says specification closure comes first. It is ready for a bounded specification-closure workstream, not an executable feature plan whose unresolved tasks say merely “ensure conservation” or “prove liveness.”

The principal shortfall is not missing owner approval. It is the absence of executable state transitions, exact accounting inputs and quantified feasibility bounds. The v0.23 mandatory full-token synchronization additionally exposes a concrete conflict with bounded historical processing and hostile-reward failure isolation.

### Settled decisions I do not reopen

The custom family's conditional FoT NET/rebasing sNET approval; four HLP custody legs and public/shared ownership; both NET/sNET inputs using Keep-YT and ordinary outputs using the same SY budget; PLP/YT-derived NET pricing despite different funding; actual Balancer V3 Weighted unbalanced behavior; 1,000 NET opening versus 1 NET policy target; `floor(S0*n/200)` aggregate expansion and increased supply at later settlements; two arithmetic one-hour TWAPs and absent-as-above-1; pre-operation participation; fee/creator shares; principal cliffs/early rewards/native maturity; incentive-free dedicated reinvestment but independently allowed contraction/bond composition; atomic rollover; and non-blocking fee forwarding are explicit selections. Direct DETF-as-ERC-4626/SY compatibility surfaces are selected without a strict-conformance certification gate. Unusual economics are not grounds to substitute Universal-family economics.

## Prioritized findings

### B1 — P0 specification conflict: full-set synchronization can defeat failure isolation and bounded history

**Facts.** Target 369–379 and A49 at 924 require registration/tracking of all locally held assets, retained historical assets and failed-forwarding rewards, with a full expected-set sync after every money route. Target 741 forbids unbounded historical traversal on normal operations; 824 and A11 at 886 require hostile reward forwarding not to revert or exhaust the surrounding operation.

`contracts/vaults/basic/BasicVaultCommon.sol:46–54` loops every registered token and performs an unguarded external `balanceOf(address(this))`. Its return is then booked. `BasicVaultRepo.sol:51–80` and `MultiAssetBasicVaultRepo.sol:50–80` expose additive registration. The PRD's same-slot claim is correct: the respective storage constants/layouts are at `BasicVaultRepo.sol:20–27` and `MultiAssetBasicVaultRepo.sol:21–26`.

**Inference.** Isolating a failed reward `transfer` does not isolate that token's later reverting/gas-heavy `balanceOf`. Accumulating old-series tokens/residual expired YT also makes every normal money route increasingly expensive. These are interactions introduced or sharpened by v0.23, not solved by its raw/provenance ledger distinction. Literal tracking of *every* unsolicited ERC-20 is also impossible without discovering the token address; ordinary ERC-20 transfers need not notify the recipient.

**Required resolution.** Specify the known/expected-token boundary, registration and safe retirement lifecycle, archival versus active sync sets, resource bounds, and exact handling of unreadable balances without silently dropping physical custody or classifying payables as backing. If “full set after every route” precludes the only safe design, bring that concrete incompatibility to the owner rather than weaken it in implementation.

**Acceptance additions:** repeated rollovers with nonzero historical dust; failed transfer followed by hostile balance read; tokens that change behavior after registration; unknown donation discovery; maximum active-set cost; maintenance and ordinary-exit liveness. **Confidence: high** in the code interaction, conditional on actual token behavior/history size for practical failure.

### B2 — P0 engineering feasibility: the external-note redemption interface has no demonstrated workload bound

Target 808–812/C08/A09 already recognizes this accurately. Independent trace confirms `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–138` permits deposits to arbitrary `to`, appending to `notes[to]`; `:143–153` scans every note of `msg.sender` on every redemption, including already-claimed notes. There is no pagination or pruning in that function. `pendingFor` also scans all notes at `:156–165`.

A dedicated escrow isolates attribution, not adversarial array growth. Atomic harvest/reinvestment means an unredeemable custody address strands the required flow. Native epoch payout capacity (`:183–188`) is not a note-count bound; an amount must be nonzero, but this does not establish a useful upper bound on appended notes.

**Required resolution:** a bounded design using the actual deployed interface and quantified adversarial assumptions, or a demonstrated incompatibility and owner decision on alternatives before marking the wrapper executable. Do not assume upstream changes, note transfer, or selective redemption. **Counterargument:** spam costs/capacity may limit practical attacks; measure them, rather than treating them as a proof. **Confidence: high** for local interface facts; deployed equivalence and attack cost unverified.

### B3 — P0/P1 core specification: prices, owned-book burn funding and initial HLP issuance are not defined sufficiently

Target 270–301, 353–365, 468–494, 689–699 and C07/C11/C12 prescribe models but leave inputs and transitions open. There is no exact synthetic-price equation; no finalized normalized weights/price scaling; no complete PLP/YT subshare mint formula for unequal ratios or last exit; no executable owned-HLP realization waterfall; no complete fee order; and no exact-output inverse including actual SY availability. The fact that an owned book is required does not define its self-leg treatment or how the DETF retires HLP to pay the quote while preserving other holders.

**Source checks:** the PRD correctly rejects copying the hook wrapper's approximate fee formula. `UniswapV4StandardExchangeWeightedBufferHookMath.sol:472–498` grosses up the full output; vendored `BasePoolMath.sol:277–342` computes the taxable nonproportional part and rounds HLP/BPT debit upward. `WeightedMath.sol:32–39,51–70` retains ratio bounds and zero-invariant failure. Reusing those equations cannot resolve the custom cross-coordinate custody mapping by itself.

**Required resolution:** publish one typed state vector, units table and transaction equations for each operation, including fee payables and raw/claimable/eligible SY; choose and approve remaining economic parameters; give worked bootstrap and owned-burn examples with external LP ownership dominant. Explicitly fund the initial SY leg without calling contributed principal earned yield. Define positive residual inventory in native units, not only “never fully drain.” Prove domain handling when whole-position NET valuation is unquotable even though a smaller allocated exit might be executable.

This is not an objection to intentional shared-SY arbitrage. Its economic tests must distinguish authorized compensation from unauthorized outside-LP capture. **Confidence: high** that closure is missing; no assertion that the selected model is necessarily insolvent.

### B4 — P1 oracle semantics: an arithmetic window is selected, but the integrated price process is not

Target 28–39, 577–595 and A44 define arithmetic accumulation and update obligations, but not a complete oracle algorithm. Synthetic price is still unspecified; history retention, boundary interpolation, cumulative widths/overflow, consultation during locks, and invalid-price versus unavailable-history handling remain open.

**Specific issue:** the PLP/YT valuation depends on external Pendle state, time/index and SY conversion. Those can change without a custom-hook transaction. Integrating the last observed mark until the next check is a sample-and-hold arithmetic series, not necessarily the integral of continuously changing executable spot/value. “Capture all price changes” is not implementable merely by adding callbacks on this family's own swaps. Retroactively applying the newly observed external rate to elapsed time would violate the selected pre-change rule.

**Required resolution:** define exactly what `price(u)` means between observations; identify observable versus external changes; pin an implementable update/consultation/history contract and limits. If exact external continuous tracking cannot be supported, expose the concrete semantic choice for approval without changing the settled one-hour arithmetic window or missing-history branch. Distinguish malformed/reverting dependencies from genuine warm-up.

**Acceptance additions:** external Pendle trade/rebase with no hook call, quiet-hour boundary retrieval, many same-block observations, expiry/rollover crossing, truncated history, invalid dependency, and read-only reentrancy. **Confidence: high** in the missing semantics; architectural infeasibility depends on the chosen process.

### B5 — P1 provenance/pretransfer: the known attack is identified, but no reconciliation algorithm exists

Target 379/A05/C12 correctly forbids force-claimed SY becoming free pretransfer credit. `BasicVaultCommon.sol:80–105` credits actual-minus-booked balance, not provenance. Pendle `PendleYieldToken.sol:166–193` accepts an arbitrary earning user without caller ownership verification; `InterestManagerYT.sol:43–57` zeros accrued interest and pays SY to that user. Thus an externally forced payment can remove the native receivable and leave an unbooked balance before the hook acts.

An end-of-route sync cannot distinguish this from caller capital. Nor does indiscriminately syncing first preserve a legitimate pretransfer. Same-token donations, incentive receipts and principal realization further complicate attribution. For locally held rebasing sNET, a positive external rebase is another surplus that must not become caller contribution.

**Required resolution:** exact checkpoints/authorizations/attribution evidence for every input mode and receipt class, including historical force-claims and rate/rebase changes. If the source cannot distinguish relevant receipts, present a supported input-mode/provenance design and any concrete compatibility conflict, not a vague “reconcile once.” **Acceptance:** force-claim plus legitimate pretransfer in one transaction, force-claim between transactions, mixed provenance at one token address, and callback interleavings. **Confidence: high** on the gap; no executed exploit against a custom implementation is claimed.

### B6 — P1 reference-duration reuse conflicts conditionally with near/after-maturity contributions

Target 603–612, 660 and C05 acknowledge the conflict but do not resolve it. `UniswapV4DetfCommon.sol:104–109` rejects duration below the oracle minimum. `DETFBondNFTMathLib.sol:17–38` subtracts minimum duration in the ordinary branch. Next-epoch reinvestment may release in seconds; native-note collection after full maturity has no new lock.

**Required resolution:** bind actual oracle terms and specify the quote-duration input for each position class. If reference formula and selected release cannot coexist, request a narrowly framed compatibility decision. Do not fabricate a longer economic duration or extend the lock. Include near-expiry first bonds, already-mature native claims, oracle-term changes and minimum/maximum special cases. **Confidence: high** for conditional incompatibility; actual configured terms were not verified.

### B7 — P1 dependency/ABI/deployment closure remains a deliverable, not evidence

Target 246 fixes PkgArgs to three dependency addresses but leaves no explicit source for the required creator recipient, remaining economic parameters, execution router/static helper, providers and child/facet dependencies. These may legitimately be package constants or discovered configuration; the current text does not map them. The selected creator entitlement must not silently become deployer, registry caller, or zero-address fallback.

Target 258–260's “every feature” requirement needs a pinned exhaustive baseline: the actual V2 package installs ERC20/permit/ERC4626/vault/SE facets (`UniswapV2StandardExchangeDFPkg.sol:77–111`) and has package-level optional pair creation/initial deposit (`:118–180`), so a swap-only checklist is insufficient.

Fixed salt singleton intent is plausible, not inherently broken: `DiamondPackageCallBackFactory.sol:201–218` hashes package plus package salt and returns an existing instance **before** processing changed args. Specify whether conflicting repeat requests must revert or return the original validated instance, and how registry metadata behaves. Separately specify hook address flag mining/deployment and child wiring; do not confuse the DETF fixed salt with a hook mining nonce.

**Required resolution:** pinned address/codehash/block/dependency manifest; configuration source table; target-derived selector/route/events/errors/authorization matrix; immutable authority/callback graph; package/proxy lifecycle and occupied-address tests. No claim that current addresses or runtime equivalence are verified. **Confidence: high** on missing specifications.

### B8 — P1 upstream SY preview warning remains a real integration gate

After Context7 lookup (`/websites/pendle_finance`, whose returned snippets did not answer this narrow question), I fetched the primary documentation on 2026-09-27:

- https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield

It explicitly labels preview functions best-effort, not audited for on-chain use, and intended for off-chain estimation. It also cautions that `assetInfo` is approximate and listed input tokens can have runtime constraints. This corroborates target 299–305 rather than refuting it.

**Required resolution:** pin and inspect the actual SY conversion and support for NET/sNET, prove the selected provider/amount-specific quote's on-chain properties, and define failure/zero/sample/decimal handling and exact-output delivery. “Uses Pendle interface” is not sufficient. Do not replace the selected valuation oracle unilaterally. **Confidence: high** for documentary warning; configured NetNet SY feasibility remains unknown.

## Contradictions, product choices and editorial quality

- **Actual remaining product choices:** economic weights/rates/opening mappings beyond the settled NET opening, and conditional retained-interest-token incentive spendability if the actual market exhibits that collision (53, 820, C03/C07). Do not classify all O01–O10 “resolved” labels as closure of those numeric/entitlement choices.
- **Engineering specification, not owner economics:** Repo layouts, selector cuts, callback order, bounded history, native-note feasibility, zero-share algebra implementation, SY proof, exact-output inversion, singleton enforcement. A demonstrated impossibility may require an owner decision, but the owner need not design the algorithm.
- **Reference discoverability:** target 637 invokes a “Universal V4 balance-derived staking PRD under docs/plans/detf” without a filename/link/version. Scoped searches for PRD/prd Markdown names under that directory returned no matches. I did not broaden into peer artifacts. This is missing evidence, not proof that no such document exists. Replace with an exact normative anchor and reproduce or link the adopted branches. Recipient existence/zero-share handling is settled, not reopened.
- **Historical editorial drift:** 134 says “stable curve” despite Weighted selection; 1073 says no historical common-interest-output rule remains operative despite the current shared-SY rule; 1079 retains a proposed 1-NET opening description inconsistent with the current selected 1,000 NET. The precedence clause prevents these from becoming operative contradictions, but they burden readers. Mark each local historical sentence explicitly superseded. Prepared date at 8 should be distinguished from current revision date. Do not present these as grounds to reopen owner approval or certification.
- **Acceptance traceability:** A01–A50 is broad and valuable, but many rows demand a proof without a specified oracle of correctness, numeric domain, tolerance, resource budget or expected failure. A43 at 918 does not explicitly include the arithmetic/horizon evidence promised at 85. Add requirement → exact specification → proof/test → gate-owner links and an explicit C-row closure status. Separate quantitative economic scenarios from mandatory safety invariants; passing tests alone cannot certify economic soundness.

## Recommended closure sequence

1. Resolve B1/B2 feasibility first; do not invest in a fully executable wrapper plan over an unbounded upstream operation.
2. Freeze the dependency/configuration and reference revision manifest, including the exact staking normative reference.
3. Publish the canonical book, price functions, bootstrap/subshare algorithms, owned-burn funding, fee order and inverse domains; seek approval only for genuine remaining economics or demonstrated incompatibilities.
4. Specify oracle observation semantics and all custody/provenance/callback transitions, including external changes and native claims.
5. Complete ABI/deployment/parity matrices and quantitative acceptance criteria; close C03/C05–C08/C11/C12 with evidence rather than labels.
6. Only then freeze a no-discretion implementation plan. Implementation and testing remain separately authorized work.

## Evidence and limitations

Read directly: `CLAUDE.md`; relevant `INDEXEDEX_AGENT_LAW.md` sections; skill catalog; canonical Crane architecture/deployment/testing/adversarial skills and local IndexedEx testing/adversarial/V4-hook-package skills; alignment PRD current decisions and §24; I/O routing PRD §16 as a subordinate reference; and the local source ranges cited above. Current custom selections control this review, rather than obsolete Universal eight-hour clocks, linear principal claims, separate raw-DETF SY or exact-output exclusions. The local hook skill's package-specific test profile is superseded by CLAUDE's default/fork-only rule; no commands were executed.

Local evidence is the inspected working-tree snapshot, not a commit pin. Observed source pragmas include `^0.8.0` for BasicVault/bond helpers, `^0.8.17` for Pendle YT, and `^0.8.24` for Balancer WeightedMath and the diamond callback factory. These are compiler constraints, not verified release versions. Target v0.23 is explicit; actual vendored commits and deployed Robinhood bytecode were not verified. No active market, live fee configuration, gas bound, SY conversion, economic profitability, or exploit execution was certified. There were no ordinary file-read failures to retry; the vague staking-reference searches were unsuccessful. Overall confidence is **high on the not-ready verdict and cited local facts, medium on design-level risk projections, and intentionally unclaimed on deployed feasibility/security/economics**.
