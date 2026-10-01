# Astra — independent original: concrete open-items audit

**Access date: 2026-09-28.** Current authority: human correction in this request; `NETNET_PENDLE_DETF_PRD.md` v0.33; implementation/test plan **v0.9**; current `PRD_OPEN_QUESTIONS.md`. Research only. No peer artifacts for this round or historical council reports were read. Retained session conclusions were treated as historical and are expressly reconsidered below.

## 1. Result

**Most alleged remaining “gaps” are implementation/source-integration/test obligations, not missing product decisions.** I withdraw independent address verification/block selection as research blockers; I also withdraw broad blockers for force-claim provenance, provider rounding, generic Keep-YT chronology, and a hypothetical exact-output residual problem without a demonstrated required-domain incompatibility.

I find **two narrowly identifiable specification issues in the current text**:

1. **Creator beneficiary binding:** the plan expressly requires creator allocation but expressly says the source of that address is not established, while the selected instance arguments contain only three other addresses. This is a missing configuration contract, not a request to reconsider creator economics.
2. **The external-wrapper terminal edge:** already resolved installments, partial reinvestment and E+1 timing do not specify treatment of newly collected excess after final intended completion, nor authority/rights for receipts after irreversible NFT retirement. The PRD expressly reserves these edges. This is not a reason to block ordinary claims/reinvestment or require protection against all future donations.

No new pricing, fee, weight, staking, reserve, lock-baseline, address-authority or certification question is warranted. Before asking the owner anything, the moderator should attempt the minimal configuration/lifecycle text repairs identified below. A technical source trace is not an owner questionnaire. If existing intended meaning supplies the answer, record it instead of reopening it.

This is **not** a claim that implementation is complete, tested or safe. It is a classification of what the current specification already determines.

## 2. Method, evidence and tool limitations

Abbreviations throughout:

- **PRD** = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md`.
- **Plan** = same directory, `NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`.
- **Tracker** = same directory, `PRD_OPEN_QUESTIONS.md`.

Read current operative accounting/configuration/claim/chronology/staking/rollover/lifecycle/acceptance sections directly, rather than treating L3/L4 or OPEN labels as proof. Read `CLAUDE.md`, skill catalog, canonical Crane testing and architecture, and local IndexedEx testing guidance. Source checks covered current Weighted scaling helper, StandardExchange rate-provider sample, BasicVault input/refund handling, Universal package creator binding, local native depository, and Robinhood constants. These are local source facts, not executed behavior.

Fresh-path check: initial exact-name glob failed with an ordinary tool ENOENT; direct read of the assigned destination then returned **File not found**. No existing report was overwritten. An attempted source search at `.../detf/IUniswapV4DetfDFPkg.sol` returned ordinary missing-file error; I did not retry that missing path or treat it as a policy denial. The concrete package's `creator: args.creator` assignment is sufficient for the limited observation made here; no unseen interface contents are claimed.

No network/library documentation claim is newly made. Accordingly no external search or Context7 call was needed. Pendle documentation is the human-selected address authority; this audit does not refetch it to make the human's ruling conditional. Source URLs already recorded in PRD§16.1 are provenance references, not newly accessed evidence.

## 3. Address authority and G1 — withdraw research gate

**Classification: RESOLVED authority; IMPLEMENTATION/TEST validation.**

The human has selected:

1. Pendle documentation as source of truth for addresses.
2. The standard Robinhood-mainnet library default block.
3. Later fork tests for deployment/behavior validation.

Observed local constant: `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:36–53` sets chain4663 and `DEFAULT_FORK_BLOCK = 20_714_383`. Its Pendle constants are at195–201. Use the named constant in later tests rather than inventing a separate research-time block or latest-block investigation.

**Superseded blocker wording:** Plan:67,82,519,668,922–937,1002,1037 and PRD:612,1119–1138/Tracker:89–98,216 contain pre-implementation observation/verification language. Under this request it must not create an independent address-discovery/code-hash/block-pinning prerequisite for research progression. The moderator should reconcile the process wording to the human's address/default-block/fork policy. Runtime token relationships, actual selector behavior, fees, decimals and source compatibility still get tested; they are not fabricated as already validated.

Concrete transition: later fork fixture chooses a documented Pendle market/router and exercises claim/redeem at the library default. **Nothing missing for research:** authority and test block are specified. Minimal next deliverable: a fixture/test row using those sources and the existing constant, in separately authorized implementation. If that test demonstrates an incompatible required operation, escalate the specific incompatibility then—not an unobserved hypothetical before coding.

**Explicit withdrawal:** my earlier statements that unknown implementation identity/block observations broadly blocked source-composition research or plan readiness were too strong under the current human ruling. They are implementation/fork evidence obligations. Local source remains local source, but no independent certification campaign is required.

## 4. Challenged allegations and their actual disposition

### 4.1 Force-claim reconciliation and public surplus

**Classification: RESOLVED policy; IMPLEMENTATION/TEST mechanics.**

**Existing answer:** PRD:26,320,425–441,820,838; Plan:330–336,499–505,612–638; Tracker:229–234. Public supported credit is max(raw−booked,0), regardless of origin; capture declared credit before sync; refund only authorized unused credited input; synchronize the full expected token set after refunds; keep native receivables current and never count consumed cash twice.

Concrete transition: R=100, raw B=110 following a third-party claim; native claim has cleared; a supported caller declares7 pretransferred units. Credit7 if other route/caller guards pass, refresh C from native state, account actual route movement, refund only within the selected helper's bounds, and sync the final raw balance. Do not keep the extinguished C, label the same7 as both user contribution and inherited interest, demand who sent the10, or sync first to deny the7.

Direct source: `contracts/vaults/basic/BasicVaultCommon.sol:58–78,85–105,108–137` specifies exact claimed credit and bounded unused-input refund; unclaimed surplus is absorbed into the raw book on end-of-operation sync (:69–70,113–116). The active family uses the nonnegative LocalCredit rule specified by the PRD, not a copied historical subtraction panic.

**Why the alleged blocker is not demonstrated:** Plan:629 correctly notes that a raw balance and zero accrued value do not reveal arbitrary historical provenance. But the selected public credit policy does not require reconstructing provenance to admit that credit, and full sync is already mandatory. Missing internal helper/Repo implementation is not missing economics. Known booked fee payables remain excluded; in-operation claims have their own receipt windows. No concrete selected operation has been shown impossible under those rules. A hypothetical inability to distinguish every unsolicited receipt must not produce a new notification/witness requirement or reopen L2.

Minimal next deliverable: implement the per-operation raw/eligible/receivable/payable updates and tests for full/partial/no credit, force-claim before input, force-claim after an earlier checkpoint, different reward tokens and final full sync. If a **specific** required prior fee receipt cannot be reconciled without conflicting entitlements, show the actual source/state counterexample before calling it a product gap. Do not infer that conflict merely from “no past-event access.”

**Withdrawal:** I no longer support an independent “historical receipt provenance mechanism must be designed before work can proceed” blocker. I retain once-only accounting and the rule that physical sync is not itself permission to sweep fee payables or exclusive principal.

### 4.2 Provider/caller rounding

**Classification: RESOLVED selected convention; IMPLEMENTATION/TEST application.**

PRD:328–336 selects a reusable per-SY target provider and explicit whole-token normalization; PRD:284–296 selects existing Weighted caller units/rounding. Plan:511–513 now supplies the actual binding's one-whole-SY sample, current-sNET index and rate, while specifically rejecting substituting whole-book redemption flooring for provider valuation. Plan:399–401 fixes exact-output wrapper fee/scaling order.

Concrete transition: for SY18/sNET9, sample q=10^18; a=Ic; rateWad=Ic*10^9. Value a native SY balance with that rate using the selected caller adapter. Separately derive executable native token delivery/SY debit with Plan§6.5.3. Do not first floor the entire book to native sNET simply because that looks like a cash quote.

Source checked: `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:48–81` supplies baseScale, `ratedPairUnits` with combined denominator/full mulDiv, and directed scale/descale routines. `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:63–132` is an existing behavior reference, with its own sample/fallback logic. The new SY-specific sample is explicitly selected in the plan; it is not necessary to copy unrelated SE supply-dependent probes.

**Missing item:** implementation expression/adapter and parity tests, not an owner-selected rate formula. Minimal next deliverable: unit-annotated adapter calls plus tests demonstrating the selected reference order at dust boundaries. No competing permitted pricing convention or incompatible required amount is demonstrated. Withdraw “pin caller rounding” as a free-standing economic/specification gate; retain it as a code-review/test criterion.

### 4.3 Owned-HLP / Keep-YT / rollover chronology

**Classification: RESOLVED behavior; IMPLEMENTATION/TEST composition.**

Citations answering the alleged broad gap:

- PRD:467–481: full proportional outer allocation and selected-leg BasePoolMath, then nested position allocation.
- PRD:489–514: exact pre/post-expiry position quote branches, one mutable post-burn state/index/router-fee identity, aggregate final SY conversion.
- PRD:555–583: owned-book-before-quote, quote-only incentive, actual-q burn and no outside-HLP funding.
- PRD:672–682: settlement before participation-sensitive operations.
- PRD:852–860: atomic ordered rollover, concrete Keep-YT split, empty-target rejection.
- Plan:286,338–370,403–417,470–472,497–507,631–642,674–703,850–862: call modes, rounding, actual index chronology, claim phase, guards and commit.

Concrete required transitions: NET input→SY deposit→Keep-YT LP/YT acquisition→accepted inner shares/residual return; below-peg exact-output sNET withdrawal→owned reserve quote→appropriate owned HLP debit/realization→SY conversion→actual-q burn/payment; expired rollover→old claim/LP/PT realization→same/new SY→successor Keep-YT→commit.

The sources/plan supply the allowed transformations, ownership, fee sequence, snapshot discipline and failure result. Mapping those into actual service calls is work W3/W4/W6/W11, not by itself a missing owner waterfall. In particular ordinary NET output **cannot** select principal liquidation, while authorized owned-HLP realization **can** use its actual modes. A reader must not confuse these to manufacture an ambiguity.

Minimal next deliverable: implement typed operation snapshots and per-hop source calls under the existing phases, with differential/refund/epoch/rollback tests. If two genuinely permitted realizations yield different unspecified rights, identify that exact required branch and its conflict; none is demonstrated by the bare phrase “complete call graph pending.” No new route cap, loop or solver is authorized.

**Withdrawal:** my earlier broad use of “unfinished owned-HLP/Keep-YT composition” as a specification blocker is narrowed to implementation integration and tests unless a specific unanswerable transition is produced.

### 4.4 Exact-output representation and rounding residuals

**Classification: IMPLEMENTATION/TEST; no demonstrated new owner question.**

PRD:453,593,598 requires exact net sNET withdrawal and truthful limits, with full revert on genuine inability to deliver. Plan:334,368,407–419,479–495 covers bounded input refunds, operation-owned ingress residuals, inverse/forward checks, source arithmetic domains and actual net receipts. Existing reference rounding is not optional. No “unsupported ERC4626 withdraw” shortcut or gift of an invented virtual bonus is allowed.

The arithmetic distinction remains true: for 0<I≤10^18 the SY minimum inverse hits each valid native output exactly; I>10^18 can skip outputs (Plan:487). But the old toy I=2*10^18,y=1 is **not proof of a reachable required configured route at the chosen fixture/operating domain**, nor proof that existing intermediate custody/refund/rounding handling cannot deliver the requested exact final amount. The external supply cap alone is not that reachability proof either.

Concrete required transition to test: `withdraw(y,receiver,owner)` at supported ordinary/burn state, calculate rounded-up input once and deliver y under actual source domains, with existing unused-input refund bounds. Distinguish **unused user input** from **converted output excess**; the former's refund helper is not automatically authority to send the latter to a new beneficiary. Nevertheless no unresolved beneficiary decision should be requested until implementation identifies a reachable required output gap after applying the selected reference paths.

Minimal next deliverable: boundary/domain tests and a traced exact-output adapter using existing final-delivery and residual rights. Where the source cannot execute, preserve truthful max/domain/revert semantics. If a supported, funded, required case demonstrably requires a new residual-rights choice, present that one case then. Do not impose an unsupported index cap or remove the route to make the test pass.

**Withdrawal:** my earlier residual warning is retained as an arithmetic/test condition, but withdrawn as an already demonstrated product-specification blocker. An example of a floor jump is not alone an owner question.

### 4.5 G0 and custom-family approval

**Classification: PROCESS ONLY.**

Approval is explicit in PRD:24–36,627; custom release/staking/interface deviations are selected in §§7/9/10/12. Plan:66 and Tracker:249–253 correctly distinguish maintenance from renewed approval. Current `CLAUDE.md:45–46` still states generic token/DETF rules that differ from this selected custom family. Research reports cannot edit instructions or grant implementation permission.

Concrete transition: an authorized implementer needs an unambiguous scoped instruction handoff before editing product code. Missing deliverable: maintainer reconciliation of that instruction scope and separate execution authorization. Nothing about it requires another vote on using NET/sNET or the custom family. Do not call G0 an economic/specification gap or a reason to continue researching addresses. No instruction edit is performed here.

## 5. Actual narrow specification issues supported by concrete transitions

### A. Creator recipient configuration

**Classification: ACTUAL SPEC GAP — configuration binding, not allocation policy.**

**Citations:** PRD:55,73,724,736 selects creator participation; PRD:260 specifies three PkgArgs addresses and listed PkgInit dependencies. Plan:125–129 explicitly says the authoritative creator-address source is not established and forbids guessing deployer/current feeTo; Plan:203 repeats it. Tracker:279–282 requires every recipient's source.

**Reachable required transition:** first funded bond/expansion allocates the creator's standing share and must initialize/send the corresponding receipt to its authorized identity. A correct fraction does not choose the recipient.

**Why references do not yet supply the answer:** the Universal reference at `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol:250–259` passes `creator: args.creator`. The custom selected three-address PkgArgs omits that field. Reusing arithmetic/recipient roles does not authorize guessing a different identity or silently adding a fourth public argument contrary to the stated interface. A creator address may already exist in intended supporting package configuration, but the reviewed current text does not connect that source.

**Minimal next deliverable:** one explicit immutable creator-binding row/initialization statement identifying the existing authoritative source, propagated into the recipient state. Prefer locating and citing the intended existing role binding over requesting a new identity. Only if there is genuinely no selected source should the human choose that beneficiary/binding location. No change to creator weights, allocation formula or normal rights is requested. This blocks only initialization that needs the recipient, not source/math work.

**Confidence:** high that current plan expressly leaves this unanswered; medium that a new owner answer is needed rather than a small author correction referencing an intended existing source.

### B. Late native excess and terminal retirement

**Classification: ACTUAL SPEC GAP — narrow L4 edge; ordinary lifecycle RESOLVED.**

**Citations:** PRD:935 says actual native-redemption excess funds same old NFT principal;943 retains future native proceeds;945 establishes final intended completion E→unlock E+1 and calls final retirement a separate mature-and-empty action;955/957 reserve late timing and terminal handling. Plan:709–716 specifies through drained candidate and expressly withholds the irreversible transition. Tracker:109–111 distinguishes resolved H02 from H01/H03 terminal edges.

**Concrete required transition 1 (before retirement):** intended note completes and funds principal at epoch106; unlock target107 is reached. At epoch109 an unsolicited note already attributed to the same holder becomes collectable; owner collects it and the mandatory atomic contribution funds new old-NFT principal. Beneficiary is settled: old NFT. Does that newly funded principal use the already-satisfied107 target or require a later processed epoch? The final-intended-installment rule only names the event at106; “no intermediate reset” addresses pre-final installments; new destination lock applies to a **new** reinvestment bond, not this same old NFT collection. General source math cannot choose the additional release restriction.

**Concrete required transition 2 (retirement):** intended note complete, E+1 passed, recognized principal/rewards/obligations drained; holder has an unsolicited future native note, or receives one after `retire(tokenId)` burns the NFT. The selected native source accepts arbitrary recipients (`lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–139`) and aggregate redemption belongs to the holder address (:143–165). The holder's permanent controller remains the NFT contract (PRD:919/927). After tokenId ceases to have a current owner, the existing tokenId-authorized collection rule no longer determines a beneficiary/authorized caller for later proceeds.

**Why existing rules are not enough:** partial reinvestment explicitly retains the *existing NFT*, while irreversible retirement removes it. Keeping a record is a possible mechanism, not a selected entitlement after burn. Funded-gons position-local dust retirement (PRD:738; Plan:803) settles an already funded fractional receipt; it does not settle future native-note property. Public hook pretransfer L2 is not a license to award/sweep the exclusive holder's future note. Requiring proof that no future gift can ever arrive would invent an impossible liveness gate; waiting for every unsolicited note or permanently never burning is also not already selected.

**Minimal next deliverable:** a short lifecycle rule with (i) unlock treatment of post-completion same-NFT principal, and (ii) what entitlement/control ends or survives at irreversible retirement, including already-known pending unsolicited proceeds versus genuinely later gifts. It must not change ordinary interim/final E+1 timing, old/new reinvestment rights or permanent NFT-contract holder ownership. The moderator can propose a minimal interpretation of the intended mature-and-empty lifecycle, but cannot silently select forfeiture, last-owner perpetual rights, new treasury beneficiary or eternal dormant NFT.

**Scope limit / withdrawals:** no reopening of purchase epoch, intermediate no-reset, final E+1, partial funded-principal reinvestment, new independent locks, aggregate native scan adoption or reward claims. Do not turn potential future gifts into a blanket block on all withdrawals. Per-holder gas measurements remain tests, not another product choice.

**Confidence:** high that these edges are expressly unassigned in current operative clauses; this is the strongest actual decision-bearing issue found. It is not a new economic questionnaire beyond the PRD's retained narrow terminal scope.

## 6. Other named items — classification without new blockers

| Item / exact current location | Classification | Concrete next work, not another owner question |
|---|---|---|
| L1 funded-gons + notification, Plan§9:775–848; PRD§10.2 | RESOLVED / IMPLEMENTATION/TEST | Implement complete transfer/mint notification, principal context and allowed callbacks; tests for source dust/weights and exact native debits. No B/U reference hunt. |
| Claim phase booleans/upstream failure, Plan:595–610,631–642 | RESOLVED / IMPLEMENTATION/TEST | Combined required claim phase, actual receipts, only downstream forwarding isolated. Do not reopen interest-only versus dropped reward collection. |
| YTv1 versus YTv2, Plan:555,668 | IMPLEMENTATION/TEST source integration | Use documented address selection, inspect actual dependency body as needed, test correct getter/formula against fork. Same selector is not proof of equivalent layout; absence of this test now is not an owner choice. |
| Same-token incentives, PRD:65,967; Plan:569 | IMPLEMENTATION/TEST conditional | Check actual token identities in fixture. Escalate spendability only if a real configured collision lacking an existing rule is demonstrated. No blanket invented eligibility or advance decision. |
| Bond duration near epoch/maturity, PRD:755,1010; Plan:769 | IMPLEMENTATION/TEST conditional | Read actual oracle terms, implement selected reference validation/bonus and selected release; test seconds-to-boundary cases. No demonstrated live incompatibility here, no invented min duration or lock extension. |
| Bootstrap, PRD§10.4; Plan:356–370,769 | RESOLVED / IMPLEMENTATION/TEST | Actual direct SY capital can fill an initially zero-earned-interest book. Trace selected G/U/B/R and required additional payments. No new seed-policy question. |
| TWAP interface/history, Plan:722–748 | RESOLVED / IMPLEMENTATION/TEST | Interface,3601 coalesced timestamps, piecewise-constant integrand, wide cumulative and exact consultation are specified. Tracker NN09 wording asking for these is stale, not a new missing oracle design. |
| Expansion horizon, Plan:752–767 | IMPLEMENTATION/TEST | Full-width formula, checked final supply and failure defined. Calculate range/horizon for actual inputs; report a real practical incompatibility if one arises, no hidden caps or guarantee of infinite representability. |
| Complete V2 SE parity, PRD:270–278; Plan:177–192 | IMPLEMENTATION/TEST | Inventory inherited selectors and validate tax-aware parity. Missing code/tests does not request permission to drop features. |
| Immutable initialization, Plan:133–151,290–308 | IMPLEMENTATION/TEST | Actual factory callbacks, reciprocal Ready predicate, safe existing-instance adoption and proxy surface tests. Only creator binding above is a concretely missing configuration source. |
| Rollover/history, PRD:798–862; Plan:850–864 | RESOLVED / IMPLEMENTATION/TEST | Factory-first→claims→old realization→conversion→Keep-YT→commit; retained historical references. No second policy for new SY or empty target. |
| NN03 failure scope, PRD:423,971–973 | RESOLVED | Required dependency failure may revert; forwarding failure is isolated. No quarantine, emergency admin or arbitrary broken-token-survival design. |
| Documentation/status maintenance, PRD:10 vs Plan:7; Tracker NN20 | PROCESS ONLY | Update obsolete version/extraction/binding-blocker prose and redundant “write design” tasks to current references. Preserve historical originals without treating them as current law. |

## 7. Explicit withdrawals and recommended narrow handoff

I withdraw the following as **unsupported present research blockers**:

- Independent current address/code-hash/block pinning before research can continue; Pendle docs and `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK` are selected, with later fork validation.
- Another public-pretransfer provenance/notification design or generic historical-event reconstruction requirement. Origin-independent credit and end-of-route full sync already govern.
- Another provider valuation/rounding policy vote. The sample, normalization and selected reference caller order are already specified; implement them.
- Generic “full chronology not done” as a product gap without naming a required transition not answered by the operative call/order rules.
- A universal exact-output residual ownership question inferred solely from an I>D toy example. Demonstrate the operative required-domain incompatibility first; retain existing refund/domain/exact-delivery law.
- A repeat owner approval for the custom family, continued L1/L2 questions, NN03 survival requirements or reopening resolved H02 timing.
- Treating an unexecuted test, missing Solidity file/selector control, source-version adaptation or measurement as automatically missing specification.

**Minimal next moderator deliverable:** revise the classification/status language (not product economics), assign source integration and standard-default-block fork tests to implementation work, and request only the two narrow configuration/lifecycle clarifications above if they cannot be resolved from the already intended binding/lifecycle. No new reserve, fee, timing baseline or dependency-certification program is proposed.

No fork ran, no source incompatibility was experimentally demonstrated, and no economic/security certification is made. Facts are quoted current text/source behavior; classification and the two gap determinations are Astra's reasoned inference. I am confident the broad old blocker list overstates remaining design work; confidence is lower on whether creator binding needs a human decision rather than a simple existing-source citation. The original is saved at the assigned fresh path and submitted for the bounded council/human checkpoint.
