# Astra — independent initial review of Universal V4 expansion PRD v0.5

Date/access date: 2026-09-25. Research only; original first pass, preserved before any cross-review.

## Identity, scope and evidence limitations

- Assigned identity: **Astra / openai/gpt-6-astra**, as stated in the session instructions. No independently authenticated runtime model-ID metadata is available to me. I cannot attest the actual backend model or assert a verified match.
- One read returned **`RC_UNAVAILABLE: attribution or metadata unavailable; report the failure, do not bypass it`** for `contracts/vaults/detf/common/claimToken/DETFFundedStakingMath.sol`. I did not retry that source through another path/tool. Successful Repo/Target reads import the math library from `common/core/`, but its exact allocation implementation was not independently inspected. Claims about retained allocation below distinguish specification semantics from verified callers.
- No peer artifacts were read. No shell, tests, implementation, configuration, deployment, signing, browser, or delegation was used. Only this assigned Markdown report was authored. No exploit was executed.
- Reviewed target: `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md`, version **0.5**, 313 lines. Below, **P:Lx–y** means that file's lines x–y.
- Read `CLAUDE.md`, relevant agent product law, alignment §24, routing §16, NetNet v0.17's controlling requirements, and canonical Crane architecture/deployment/testing/adversarial and IndexedEx testing/adversarial/hook-package skills directly. Older skill examples do not override current product law (for example, the hook skill's package-specific profile example conflicts with CLAUDE's two-profile rule).
- Local source evidence is a checkout snapshot, not a pinned commit/deployed revision. Inspected Solidity sources declare `^0.8.0`; agent law reports configured compiler 0.8.35, but no runtime compiler/version verification was performed. External documentation is current, unpinned Uniswap v4/v2 documentation, not proof of the vendored version.

## Verdict

**Good architectural direction, but not requirements-complete or internally consistent.** Keep the selected intent; reopen the document's “no open questions” claim. Two mathematical assertions are false, the low-precision share rules permit donation inflation, and the proposed synthetic sampler is not a faithful time average of the underlying state between DETF operations. Those are blockers to treating this as implementation-ready, even though implementation is explicitly unauthorized.

Strengths: clear actual/projected separation; distinct Universal and NetNet economics; explicit cold-start consumption and clock behavior; fee receipts versus standing rights; immutable-deployment boundary; rollback and production-path expectations; named hook inventory and requirement/test mapping. The old linear expansion evidence is accurate in the inspected code.

## Confirmed intent versus document assertions

**Confirmed by the current user request:** compound catch-up; live-backing staking; retain fee shares; all new shared-source families; hook trading-spot and DETF synthetic TWAPs; one-hour expansion window; skip cold epochs; zero-share donations assigned to fees, using configured percentages when standing weights are absent.

**Written in v0.5, but not independently established as separately owner-approved here:** exact two-floor recurrence; frozen highest per-leg average for all missed epochs; arithmetic versus geometric averaging (not actually specified); unbounded quiet carry-forward; one sample per transaction; D07 transfer rounding; D09 zero-weight reward suppression; D13 creator remainder and current oracle-feeTo fallback/zero-address revert; exact allocation/share rounding; aggregate/split equivalence; literal 1:1 internal-share deposits after donation clearing. These may be reasonable proposals or retained law, but cannot all be promoted to confirmed owner decisions by the status text at P:L9,25,285,291–303.

Do not reopen the already selected high-level intent or universal weird-token law. Resolve the detailed contradictions and engineering gates below.

## Prioritized original findings

### A1 — BLOCKER: D07's transfer guarantee is mathematically false; low share precision also enables donation inflation

**Evidence:** P:L101–121,132,297; deposit/transfer/rounding acceptance P:L267,271. Existing `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:101–124,127–166` spends allowances in displayed native amounts and promises 1:1 route quotes; those consumers cannot silently assume the new rounding is equivalent.

**Confirmed arithmetic:** Let live backing `B=100`, total internal shares `U=1`, sender shares 1, recipient shares 0. Request transfer `A=1`. D07 moves `ceil(1*1/100)=1` share. Sender loses 100 displayed units and recipient receives 100, **not A or A−1**. Generally the moved entitlement is `q*B/U`, where `q=ceil(A*U/B)`; its excess over A is less than `B/U`, not necessarily less than one native DETF unit. Even when `B/U<1`, receiver gains can be A+1 depending on its fractional balance. Self-transfer also cannot satisfy an unconditional “sender decreases by at least A.”

**Donation counterexample, no expansion needed:** attacker stakes 1 (U=1, B=1), donates 99 (B=100), victim deposits 199. Deposit rule gives `floor(199/100)=1` new share. B becomes 299 and U becomes 2. Each holder displays 149. Attacker withdraws 149 after spending 100, gaining 49; victim then holds backing 150 after paying 199. This is a positive-share deposit, so the zero-share revert does not stop it. Increase donation/victim amounts while keeping the attacker's initial one native share to amplify the loss. D12/D13 fix U=0 capture, **not** this U>0 inflation path.

**Resolution needed:** approve explicit internal precision and a bounded user-loss policy (deposit min credited amount/share output, transfer debit and allowance semantics, full-exit behavior). A precision multiplier can mitigate quantization but requires a bound/proof; it is not an unconditional cure for arbitrarily large donations. Specify real credited output in previews/events/exact-output routes. Do not quietly invent virtual/dead shares because they change entitlement policy.

**Confidence:** high, algebraic counterexamples. **Counterargument:** high internal precision makes ordinary losses tiny; however v0.5 explicitly opens with shares equal to deposited native amounts, and does not bound B/U.

### A2 — BLOCKER: aggregate/split reward equivalence contradicts ordinary participation of prior fee receipts

**Evidence:** P:L115,184,190,243,258 (T07),293; `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:958–973,1003` explicitly lets previously issued fee receipts participate in later distributions. `DETFFundedStakingRepo.sol:164–174,185–201` passes total ordinary gons and standing weights to allocation and separately issues fee receipts. `DETFSeigniorageShareLib.sol:18–33` tops weights up from ordinary ownership.

**Concrete arithmetic before display flooring:** initial B=U=300, one original holder owns all 300 shares, standing fee weight=300, creator weight=0, configured fee fraction=50%.

| Realization choice | Result |
| --- | --- |
| One reward R=600 | Ordinary gets 300; fee gets 300. At B'=900, issue fee shares `300*300/(900−300)=150`; U'=450. Original holder owns 600 backing. |
| Two rewards R=300 each | First: ordinary/fee allocations 150/150; B'=600; issue 100 fee shares; U'=400; top fee weight to 400. Second: ordinary/fee allocations again 150/150; B'=900; issue `400*150/(900−150)=80` shares; U'=480. Original holder's unrounded backing is 562.5, displayed 562. |

No participant deposited, withdrew or transferred. The first fee receipt properly earns part of the second ordinary allocation. This difference is economic, not display rounding. Keeping the standing weight fixed instead of topping up also does not generally restore equality. Allocation floors introduce further partition dependence.

**Recommended resolution:** retain “one catch-up = one allocation” and D40 participation; delete/narrow T07 and P:L190 to a genuinely equivalent bookkeeping split with allocation inputs frozen and new recipients excluded until the entire logical distribution ends. State that separate realizations can have different holder outcomes. If timing-independent outcomes are required, that is a different economic design requiring owner approval, not an optimization.

**Confidence:** high under the PRD's specified weight allocation; exact `_allocate` source remains unverified due to the read limitation. The example has exactly representable half allocations under the stated fixed-point model.

### A3 — BLOCKER / economic decision: DETF-only sampling can preserve a flash-manipulated synthetic value for an entire hour

**Evidence:** P:L170–178,246,269; `UniswapV4DetfCommon.sol:324–340` values actual supply and owned LP through current hook `previewSynthetic`; `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:114–139` uses rated reserves, weights, LP supply and DETF supply. These inputs can change without a DETF call. `UniswapV4DetfMaintenanceTarget.sol:16–27` exposes permissionless synchronization outside the lock. Agent law L233–241 confirms externally supplied rate valuation.

**Scenario (inference about proposed implementation):** a warm DETF series is near 1.00. At t0, a public hook trade skews the relevant synthetic input to 2.00; an attacker calls an eligible DETF operation/sync to record 2.00; the attacker reverses the hook trade without another DETF operation. Actual synthetic returns near 1.00, but the DETF series holds 2.00. At t0+3600 the selected carry-forward consult reports 2.00 for the entire hour. Expansion consults that history before writing the corrected sample. The attack need not maintain a distorted market for an hour.

Even without an attacker, a sample 1.20 at time 0 followed by an external change to 0.80 at minute 10, with no DETF operation, produces a sampled hour average 1.20 instead of the underlying-state average `(10*1.20+50*.80)/60 = .866666…`.

**Important distinction:** this is a valid TWAP of an explicitly *sample-and-held DETF series*, but not necessarily a TWAP of continuously changing synthetic value. A one-hour window alone supplies no one-hour manipulation-cost guarantee. Recording after expansion protects against the current call's own new sample, not against an earlier poisoned sample.

**Owner clarification:** is operation-sampled, arbitrarily stale synthetic history the intended economic input, with this risk accepted? If not, require an architecture that accounts for material external reserve/rate/LP changes or defines freshness/validity limits. Keep synthetic and trading spot distinct; substituting hook spot is not the selected solution. Proving exploit profitability requires real routes, liquidity, fees and borrower access; none was executed or established here.

**Confidence:** high on sampling incompleteness; medium on exploitable profitability in a specific deployed market.

### A4 — HIGH: the oracle specification does not yet define one deterministic, adequately retained series

**Evidence:** P:L79,138,170–180,244–246,269. External Uniswap docs confirm v4 has no built-in oracle and hooks can implement custom accounting/curves; PoolManager slot/tick prices therefore must not be assumed to be these hooks' actual trading prices.

Required missing definitions:

1. **Average and orientation:** arithmetic price integral or geometric/tick average; whole-token WAD scale; quote/base direction; fee-inclusive or fee-exclusive marginal price; valid pair discovery; raw/share/rate-provider translation. With half an hour at prices 1 and 4, arithmetic average is 2.5, geometric average is 2; arithmetic inverse-price average is .625, not `1/2.5=.4`. “One shared observation facility” is sensible; eleven different curves still need correctly specified marginal-price adapters.
2. **Causal integral:** advance cumulative value with the old sample through timestamp t, then install the final new price for future time. A new sample must never price elapsed time retroactively. Define left boundary interpolation and counterfactual current cumulative values.
3. **Same-time/multicall:** “one sample per transaction” does not say first or last state; several top-level calls in a transaction can each finalize different states, and internal callbacks can occur mid-operation. Specify per-timestamp coalescing/last-state semantics and no duration for zero-time states. Do not rely on first-write-only deduplication.
4. **Mutation coverage:** hook spot can move on unbalanced joins/exits, owner swaps, rate updates and shared-book operations, not only public swaps. In a multi-token book, one trade can move other configured pair prices. Define all affected pair updates and distinguish unavailable/empty book from a genuine zero price. A continuously changing external rate cannot be made historically exact merely by observing swaps.
5. **History retention:** a fixed-count ring does not guarantee one hour under arbitrary high-frequency writes. For example 64 one-second observations evict the one-hour boundary in roughly a minute. Define timestamp granularity/coalescing, capacity and supported-chain assumptions, eviction rules and gas/storage budgets. “Unchanged prices don't grow history” does not bound alternating-price history.
6. **Consult contract:** `secondsAgo=0`, >retained history, unsupported pair, pre-live, missing/failed rate provider, timestamp/cumulative overflow, and mixed warm/cold legs. Cold missing history and provider failure are not automatically the same condition. Silent classification as cold can permanently consume earned epochs; unconditional failure can block exits.

**Recommended resolution:** a normative oracle algorithm/ABI and per-product sampling matrix are engineering deliverables; the owner must choose average economics and acceptable external-change/staleness behavior. Add exact-value oracle tests, not merely “deterministic for stored history.” Retain the selected cold-skip and one-hour policy without confusing initial availability with bounded retention.

**Confidence:** high that these details are absent; curve-specific adapters and feasible capacity are unproved.

### A5 — HIGH: fee-share issuance is underdefined, especially rounding, prior fee balances and tiny rewards

**Evidence:** P:L111–117,123,184,257; alignment L947–975. The PRD says recipient “funded balances must equal” allocated fee amounts, although a recipient can already own principal/receipts and can own both NFTs.

**Derived ideal formula, not a confirmed implementation choice:** for pre-existing U>0, post-mint backing B', allocation amounts F/C, ordinary backing `H=B'−F−C`, exact new shares are `xF=U*F/H`, `xC=U*C/H`, with both calculated from the same pre-issuance U/H. This leaves pre-existing shares owning H and new fee shares owning F+C in real arithmetic. Independently flooring xF/xC changes both recipients' realized values and the common denominator. Sequentially treating the second issuance against a mismatched backing basis is not equivalent.

Example B'=110, U=1, F=10, C=0 gives ideal xF=.1. Flooring to zero pays the fee recipient zero, leaving all 10 fee units with the existing holder. Thus the residual is not necessarily less than one native token unit; precision and error bounds matter. If the fee owner already holds ordinary shares, it retains those plus ordinary growth plus its new role receipt: an absolute final-balance equality to F is wrong. Same-owner NFTs need two allocations summed once, not two duplicate balance resets.

**Resolution:** specify common denominator, share precision, rounding order, residual bound/beneficiary, zero-share fee outcomes, role-address overlap, fee-weight units and exactly when weights top up. Define “fee receipt entitlement” rather than absolute account balance. Do not claim exact D40 economics and simultaneously allow unbounded conversion loss without an explicit exception.

**Confidence:** high algebraically. Counterargument: “subject to share flooring” acknowledges loss, but supplies no measurable bound and therefore does not close the requirement.

### A6 — HIGH: zero-share donation sequencing contradicts unconditional 1:1 internal-share deposits

**Evidence:** P:L123–134 orders donation assignment → expansion → deposit; P:L267,271,302 promises deposit shares equal to deposit amount.

**Counterexample:** U=0, standing weights=0, donated B=100. D13 assigns 100 shares to fee/creator. Assume configured percentages so small that the top-up floors to zero, and an eligible due reward R=100. U is now positive, so expansion may mint and accrue to those 100 shares: B=200, U=100. Deposit D=10 must receive 5 shares under P:L121, not 10. Issuing 10 would give the depositor more backing than it supplied. With positive weights and a positive ordinary allocation, the same ratio-change issue remains.

**Resolution:** “1:1” can apply only to the empty reset or initial donation assignment, or where the post-expansion ratio actually equals one. Otherwise deposits use post-realization B/U. Make zero-share handling a state machine shared by preview and execute; projecting with only the original U=0 can incorrectly suppress a mint that donation clearing enables. Define U=0 `totalSupply` before clearing as well.

**Confidence:** high. Counterargument: “1:1” may mean displayed token entitlement, not internal shares; the explicit wording in T20/D12 says shares and must be corrected.

### A7 — HIGH engineering gate: exact uncapped recurrence is specified without a proven gas-feasible algorithm or measurable budget

**Evidence:** P:L142–160,207,240–244,262. Baseline `DETFEpochNaturalExpansionLib.sol:33–57` is a constant-cost linear multiplier and therefore does not establish feasibility of exact compounded floors.

The recurrence is coherent; **a naive exponentiation is not equivalent**. At default coefficient `c=floor(10^17/1095)=91,324,200,913,242`, P=2 WAD and S0=10,000 native units, each epoch's nested floor mints zero. Exact supply stays 10,000 forever. Rounding only at the end of `S0*(1+c/(2W))^3` gives 10,001. No remainder accumulator is permitted, so the latter is not acceptable.

There are 1,095 eight-hour epochs per year. Require measured cold/warm view and write budgets and an exact algorithm/complexity argument for the supported numerical domain, including tiny positive increments, zero-increment fixed points, near-threshold P, and overflow. “No external-call loop” does not by itself make an internal loop practical. Zero-increment fixed points can safely fast-forward; this does not prove a general fast method.

Overflow-safe revert is explicitly selected, but mandatory settlement before withdrawals can then prevent exits as well as new issuance. Document that liveness consequence and whether any terminal recovery requirement is desired; do not silently add a cap or skip overflowing issuance. I do **not** claim exact acceleration is impossible—only that feasibility has not been demonstrated.

**Confidence:** high on floor mismatch and missing evidence; algorithmic impossibility is not asserted.

### A8 — MEDIUM/HIGH: shared-family scope and semantic supersession need a narrower, explicit matrix

**Evidence:** P:L29–43,61,215,279; `CLAUDE.md:19,45`; alignment L900,925,947–975,999–1003,1073–1100; agent law L165–188. NetNet v0.17 L9,16,26,46–55,122–124 remains a draft with its own oracle details and policy conflicts, not blanket authorization.

The target expressly replaces shared staking for all new consumers; it does not necessarily reopen excluded Balancer-hosted family launches or move Universal's compounded amount engine into those families. Shared source changes may alter excluded consumers mechanically while their deployment/functional work remains excluded. State that distinction in a consumer matrix. Likewise all eleven hook oracles are in scope, while only the supported reserve-hook bindings are Universal DETF bindings.

Expand the reconciliation list beyond alignment's L977–1005: index/gons rules, unsolicited-balance isolation, exact direct-stake previews, escrow attribution, wrapper exchange rates, withdrawal/final-fraction logic and events require explicit replacement/retention mapping. Live staking balance includes naked donations immediately for U>0, unlike the current accounted-backing model. Fees and ordinary principal deposits must still be distinguished without restoring authoritative stale backing.

Bond principal is fixed in DETF units. Share-floor deposits/ceil transfers must not leave an escrow's attributed entitlement below its remaining principal or make repeated reward claims consume another NFT's shares. Current alignment L1087–1099 expressly disallows hiding that deficit. Global account-level conservation is not enough when many positions share an escrow account.

**Confidence:** high on reconciliation requirements; full consumer/selector inventory was not performed. Do not interpret this finding as permission to revive deprecated functionality.

## Acceptance completeness: required additions/corrections

Existing T01–T20 are a useful outline, not a complete ship gate. Recommended requirements for the separately authorized plan:

| Area | Required additional evidence |
| --- | --- |
| Share conservation | A1 positive-share donation attack; deposits immediately redeemable only for credited principal; zero shares; high B/U; exact-in slippage and exact-out delivery; no user loss beyond explicit bound. |
| Transfer/allowance | A, A±1 and larger quantization cases; full and partial amounts; zero/self transfers; allowance versus actual economic debit; event/return values; transfer round trips. |
| Fee issuance | A2 counterexample; correct logical-distribution partition test; pre-existing fee stake; both NFTs same owner; role transfer; tiny F/C; all/no weights; dynamic fee changes; top-up units and timing; nondecreasing unaffected backing/share ratio. |
| Zero-share state machine | Donation assignment before expansion; projected parity; configured f-only/c-only/both/zero; zero feeTo; reverting ownerOf; feeTo equal to staking (self-transfer would not clear B); recipient overlaps; repeated clear; zero-weight immediate seigniorage, not only expansion. |
| Oracle exactness | Independent known-value integrals; average/orientation/decimals; 3599/3600/3601 seconds; long quiet periods; same timestamp, multi-call and nested callback ordering; ring eviction under alternating prices; per-pair cross-impact; initializer samples; unavailable versus source failure; zero reserves. |
| Oracle security | A3 skew → DETF sample → reverse without DETF call; external rates; LP changes; owner/internal swaps and joins; same-block reversals; attacker-cost and obtainable-expansion bounds or explicit accepted residual risk. |
| Recurrence/performance | Exact default and adversarial floor vectors; differential small-n plus proved acceleration; defined maximum test intervals/domain, gas ceilings and view latency; all numeric overflows; no silent epoch loss; terminal exit liveness documented. |
| Escrows/SY | Multiple bonds in one custody account; early reward claims preserve all unvested principal; full-close fraction isolation; same-time expansion plus immediate seigniorage; projected versus funded wrapper exchange-rate semantics; no donation credited twice. |
| Production integration | Every listed hook, every in-scope staking consumer and all Universal bindings; Target → Facet → package → proxy selector/consult smoke matrix; correct callback address flags; existing callback authentication and no new unauthorized funding/mint surface. |
| Authority/observability | C16 currently maps to T19, but T19 only checks no upgrade. Add actual sync/funding access-control negatives. Name expansion events' P, window, consumed epoch range and skip reason; mint/backing/share/observation rollback together. |

Use real registered production diamonds and hooks per canonical skills; independent pure math references complement, not replace, those tests. Passing tests would not prove profitable manipulation impossible or establish economic soundness.

## Prioritized owner questions and proposed disposition

1. **P0 — Oracle economics:** accept operation-sampled stale synthetic history, including A3's flash-poisoning possibility, or require a different mutation/freshness architecture? Preserve two distinct series and the chosen one-hour/cold-skip policy.
2. **P0 — Share precision and user protection:** what maximum rounding loss is acceptable for deposits, transfers, fee receipts and bond escrow? Approve precise allowance and min-output semantics. Literal D07 is unsatisfiable over its stated domain.
3. **P0 — Distribution timing:** retain D40 and one allocation per catch-up, accepting different outcomes for separate reward realizations? **Recommend yes and correct T07**, rather than changing fee economics to force path independence.
4. **P1 — Average definition:** arithmetic WAD marginal-price average, geometric average, or another explicitly defined statistic? Which quote direction and fee convention? Highest-of-leg-averages is distinct from average-of-the-instantaneous-maximum; confirm the former as v0.5 proposes. For alternating legs (2,1) then (1,2), those choices produce 1.5 versus 2.
5. **P1 — Zero-weight reward case:** does D09 suppress immediate seigniorage as well as expansion when U and standing weights are zero? The prose says reward mint, but its marker instruction is expansion-specific. Is configured-percentage fallback intentionally donation-only? Do not infer a new recipient rule.
6. **P1 — Zero-share normalization:** approve post-expansion deposit pricing rather than literal 1:1 internal shares after donation assignment; define U=0 views and self-recipient/failed-beneficiary outcomes. D13 feeTo=0 revert is written but not independently confirmed by this request.
7. **P1 — Failure/liveness:** cold history is already selected to skip. What happens on invalid price/rate data, lost retained history or arithmetic exhaustion? Distinguish economic choices from a safe implementation's required rollback.
8. **P2 — Scope/status:** confirm “all new shared-source families” changes shared staking without authorizing excluded family launches or changing their expansion rates. Mark the PRD as requiring these clarifications and engineering gates, not “no open questions.”

The owner need not choose data-structure details or invent an exact recurrence accelerator. Those are engineering proof obligations with measurable acceptance, not decisions that approval alone can satisfy.

## External primary evidence and research provenance

All accessed **2026-09-25**. Only generic public protocol questions were sent externally; no proprietary code, credentials or environment values were sent.

1. Context7 resolved **`/uniswap/docs`** after resolving “Uniswap v4”; queried custom accounting/oracle documentation. Returned public custom-accounting and AsyncSwap descriptions supporting the distinction between custom hook curves and core pool state: <https://github.com/uniswap/docs/blob/main/content/protocols/v4/guides/custom-accounting.mdx> and <https://github.com/uniswap/docs/blob/main/content/protocols/v4/guides/hooks/async-swap.mdx>. Current documentation, not version-pinned.
2. Official v4 hook lifecycle/permissions documentation, fetched: <https://docs.uniswap.org/contracts/v4/concepts/hooks>. Initialization, swap, liquidity and donation callbacks are separate; hook addresses encode flags; hook binding is fixed in PoolKey. This supports mutation-coverage and deployment acceptance, not a claim that any particular local hook has oracle coverage.
3. Official v2 oracle documentation, fetched: <https://docs.uniswap.org/contracts/v2/concepts/core-concepts/oracles>. Cumulative price weights price by elapsed time; TWAP is a difference of cumulatives divided by elapsed time. Its manipulation-cost discussion assumes the measured price reflects the market state across that time. It does not validate sparse DETF-only sampling.
4. Primary v4 whitepaper, search-extracted: <https://app.uniswap.org/whitepaper-v4.pdf>, abstract and §6.3: oracles formerly built into core can be hook features; base v4 pools omit the protocol-enshrined oracle. Direct webfetch returned raw/truncated PDF bytes, so I rely only on readable primary-document search extraction, not a claimed full PDF review. Official oracle-page search corroboration: <https://developers.uniswap.org/docs/protocols/v3/concepts/price-oracles>, explicitly says v4 has no built-in oracle.

## Overall confidence and remaining evidence

**High confidence** in the transfer counterexample, donation-inflation exposure of the stated formulas, aggregate/split contradiction, zero-share sequencing conflict and sampling incompleteness. **Medium confidence** in a practical market attack's profitability until real route/capital assumptions are tested. **Unknown** exact gas feasibility of an optimized integer recurrence, complete shared-consumer compatibility, all eleven curve adapters, deployed versions and runtime identity attestation. No conclusion depends on peer agreement; none is presented as an executed test result.

This is Astra's original finding set. No implementation is authorized. Return to the moderator/human for requirement resolution.
