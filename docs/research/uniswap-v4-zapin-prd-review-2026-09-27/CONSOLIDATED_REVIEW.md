# FullSpread V4 proportional zap-in PRD review

Date: 2026-09-27. Moderator: Astra. Research only; no implementation, tests, deployments or migration performed.

## Subsequent owner decisions — supersede the earlier checkpoint below

After the completed review, the owner confirmed that holder-inventory swaps are intended maintenance when directed toward proportionality and the sleeve allotment within price-impact protections. The owner also required interleaving maintenance with exact-output operations and explicitly clarified that the closed-form requirement applies to the **entire combined exact-output-plus-rebalance operation**. Where no valid closed-form solution exists, that combined route must reject as `InvalidRoute`.

The earlier recommendation to preserve an intentionally unrebalanced exact-output alternative is therefore superseded. A closed-form issuance/input inverse followed by iteratively solved repair is insufficient. Public rebalance's separately permitted bounded solver remains distinct. No mathematical feasibility finding, numerical-limit ratification or implementation authorization is implied by these owner decisions.

The moderator recorded these decisions in the target PRD as D17–D19 and §6.4, updated acceptance/specification requirements, corrected its FullSpread target/evidence references and distinguished the already-implemented local snapshot controls from the old-tree diagnosis. The original review and all researcher artifacts below remain historical evidence; no new council research round or test execution was performed for this decision-recording update.

## 1. Verdict and corrected scope

**Ready to draft an implementation plan, with explicit route boundaries and a protection-value freeze before implementation approval.** The product direction is coherent. The PRD needs a small scope/evidence correction, not another economic redesign.

The human clarified during review that the target is:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/`

This is the **UniswapV4FullSpreadStandardExchangeVault** family. The human intends to deprecate the old vault under `contracts/protocols/dexes/uniswap/v4/`. Deprecation intent does not authorize old-source changes, deletion, registry changes, migration or deployment in this research task.

The reviewed PRD's evidence list points to the old implementation, and its §12 describes the old economic-total snapshot problem. The new target already separates local delivery snapshots from economic backing. Treat those requirements as preservation/regression gates, not missing infrastructure that must be rebuilt.

The PRD itself remains unchanged. Recommendations below are not silently adopted owner decisions.

## 2. Evidence notation

- **PRD:** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`, updated 2026-09-27.
- **V4FS:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/`.
- **Common, InBase, LiquidReserveTarget, QuoteService, OutExecuteTarget:** the files in V4FS named `UniswapV4FullSpreadStandardExchangeVault<suffix>.sol`.
- **Math:** `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol`.
- **CP PRD:** `V4FS/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md`.

The moderator directly read the target PRD, current CP PRD, DETF alignment §24.7.1, canonical pretransfer law, relevant canonical skills, and the core code cited below. Other consumer findings are attributed to researchers rather than presented as exhaustive moderator verification.

## 3. Existing behavior against the NEW vault

These are source observations, not claims of executed validation.

| Area | Current FullSpread behavior and evidence | Required treatment |
|---|---|---|
| Single-token exact-in deposit | `InBase:269–312` collects fees if idle, derives the pre-contribution book, computes shares, mints, then runs idle best-effort placement. It does not perform a composition swap. `Common:689–701` delegates issuance to Math. | Change the idle path to caller-funded composition → allocation → proportional mint. Existing `exchangeIn` remains the interface. |
| Single-sided mint math | `Math:58–64` uses rounded invariant growth. The dual-positive branch at `Math:52–56` already uses the minimum proportional share amount. | Reuse suitable dual-token math only after establishing the post-swap incumbent book and actual caller contribution. The dual branch's existence does not mean the new zap is implemented. |
| Blocked deposits | `InBase:306–311` skips placement while PoolManager interaction is unavailable; the earlier mint still uses the existing single-sided formula. | Preserve sleeve-only behavior under PRD:73. Scope the new composition and alignment requirements explicitly to idle single-token zaps. Verify full reference transitions and cross-mode cycles; do not infer universal safety from algebra alone. |
| Pretransfer guard | `Common:1222–1223` calls `LocalCreditLib.requirePretransferCaller(msg.sender)`. | Already present. Preserve across new branches. Withdraw old-tree claims of a missing guard for this target. |
| Durable local snapshots | `Common:610–617` records actual local balances for both configured ERC-20 faces and held self-shares. `Common:1224–1229` computes available credit from local balance and its durable snapshot and returns the declared amount. | Already separates delivery from position repricing. Preserve full-set end-sync and exact declared credit; do not rebuild the old `storedTotal − currentDeployed` approach. |
| Economic backing | `Common:623–635` combines free balances, collectable fees and deployed amounts. | Preserve distinct backing and delivery concepts. Attribute new composition fees and incumbent position repricing correctly. Fee collection is a transfer between book components, not a gain. |
| Pull funding | `Common:1231–1239` measures the balance delta and requires exact delivery. | Preserve current token policy; measured delta does not authorize fee-on-transfer support. |
| Sleeve target | `Common:358–360` currently computes `T*p/1e18`; `Common:744–749` supplies free plus deployed principal. | Mandatory change to `floor(T*p/(1e18+p))`. At T=120 and p=20%, current target is 24; approved target is 20. |
| Sleeve deadband | `Common:362–383` uses token-decimal absolute floors and the relative deadband, with a zero-target branch. | Preserve the specified sleeve deadband, but keep it separate from the depositor's 1 bp loss bound. |
| Public rebalance | `LiquidReserveTarget:92–97` gates on enabled/idle state. `Common:757–807` only adds/removes liquidity and evaluates sleeve deviations. | Add bounded, useful holder-funded repair swaps, a proportionality/progress objective, and the new stopping rule. The existing sleeve-only check does not already implement D12's new two-condition policy. |
| Automatic placement tails | `Common:727–731` calls the same internal helper as public rebalance. Single and dual deposits call it at `InBase:306–308,369–370`. | Separate public swapping repair from automatic placement unless the owner explicitly expands automatic trading. Do not silently change all callers by upgrading a shared helper. |
| Dual-token deposits | `InBase:331–374` retains both inputs, mints via the dual branch and already performs idle tail placement. | Preserve, including explicit surplus policy. There is no missing dual-deposit tail to add. Do not apply the new single-zap loss bound indiscriminately to existing unbalanced Multi joins. |
| Exact-output share mint | `OutExecuteTarget:105–137` calculates required input, handles delivery/refund, then mints exact shares without composition. `Math:67–95` inverts the existing invariant-growth branch. | Explicit scope decision/default required in the plan. This old inverse is not the inverse of the new external-composition exact-in route. |
| Ordinary preview | `InBase:252–261` previews the existing mint formula without composition. | Update idle zap previews. Preserve blocked route truthfulness. |
| Hook quote support | `QuoteService:44–57` identifies supported projected hooks, but `_adjustHookSwap` returns unchanged amounts for unsupported hooks. | Deployer compatibility responsibility does not establish quote accuracy. Specify supported quote behavior and truthful unsupported/fail-closed behavior where execution protection cannot be verified, without a discretionary whitelist. |
| Percentage reporting | `LiquidReserveTarget:64–80` returns oracle p as target, but actual percentage is free/(free+deployed). | Specify reporting compatibility explicitly. A p=20% target now corresponds to a free/total fraction of one-sixth. Do not silently present unlike denominators as comparable metrics. |

## 4. Requirements already settled — no new owner question

1. **Sleeve denominator:** p is a percentage of this vault's owned deployed principal, not combined inventory or total pool liquidity. PRD:79–119 settles this.
2. **Deposit ownership:** composition uses only caller credit; post-swap incumbent repricing and earned fees remain incumbent backing. PRD:125–166 settles this.
3. **Alignment includes share-flooring loss:** PRD:170–197 and :236 include flooring and reject a dust exception that defeats the relative bound. The precise numerical implementation is engineering. Removing flooring would weaken the accepted protection.
4. **Atomic rejection:** a deposit unable to satisfy protection must revert. A trial-and-revert execution mechanism need not be forbidden merely because it mutates transiently; the requirement is atomic rollback and no unsafe successful fallback.
5. **Public blocked rebalance:** preserve revert. PRD:201 limits public rebalance to available interaction; the safe no-op/deferred allowance is not permission to remove that gate.
6. **Protection is enforced:** “not empirically proven” is a limitation disclosure, not authorization for production observe-only execution. PRD:250 requires per-operation limits even with ineffective caller minimums.
7. **Pretransfer and full booking:** retain source-agnostic unbooked claims, contract-caller semantics, exact-in no-refund behavior and full expected-held-set sync. No provenance redesign.
8. **Other settled exclusions:** no cumulative/time throttles, discretionary hook whitelist, market-price stabilization objective, new single-token bootstrap, NAV redesign or implicit migration.

For the proposed alignment metric and positive denominators, an exact mathematical comparison is `10000 * sharesOut * B_i >= 9999 * S * C_i` for each leg. This is not permission to implement unchecked overflowing products. Share quantization can reject small deposits; composition mismatch can also reject deposits of any size. No universal “dust only” bound or economic negligibility has been established.

## 5. Narrow scope questions and recommended defaults

These do not prevent drafting a plan with clearly labeled assumptions. Resolve them before freezing any dependent behavior.

### Q1 — Are holder-funded repair swaps public-only?

**Recommended interpretation:** yes. Public `rebalanceLiquidReserve` may swap. Existing automatic maintenance tails remain add/remove-only. Deposit composition is separately funded solely by current-call credit.

Why record it: D9 explicitly authorizes public repair, while current public and automatic paths share a helper. Without separation, implementation can unintentionally broaden trading authorization. Astra and Kimi recommend confirmation; Grok considers this already implied strongly enough to proceed.

### Q2 — Does exact-output share minting also adopt external composition?

**Recommended narrow default:** not in this change unless explicitly requested. Preserve its declared existing settlement semantics and test cross-route cycles; do not advertise it as an inverse of the new exact-in zap.

Why record it: the headline requirement names `exchangeIn`, but the current `exchangeOut` mint can issue shares using the old internal-book model. This affects route choice and productive-deployment expectations. Expanding it means additional solver, inverse quote, partial-fill, refund and protection work. Astra identified this adjacent route during cross-review.

### Q3 — Freeze the working protection values

Record whether 25 bp public-repair price impact, 50 bp deposit-composition price impact, and 10 bp fee-inclusive-quote shortfall are the intended initial enforced values. The 1 bp alignment bound is already accepted.

Use the listed values as planning assumptions, not as empirically validated guarantees. Specify storage/query/validation and who, if anyone, can change them without adding unapproved vault administration. Do not silently make observe-only mode the production default. Changes to risk tolerance or privileges return to the owner.

### Engineering, not an additional product questionnaire

- Define public-repair proportionality in relation to feasible deployment at current position/pool state plus sleeve adequacy, not a historical allocation or external market-price peg. PRD §14 delegates exact progress metrics.
- Define bounded solver work, zero-denominator and extreme-state behavior, exact price orientation and price-vs-sqrt-price conversion, actual-fill attribution and residual disclosure.
- Choose a defensible quote mechanism for supported hook behavior. Arbitrary compatible hooks do not imply monotone solver behavior or exact vanilla quotes.
- Enumerate ordinary previews, transition quotes, native SY, Multi, imports, exact-out and actual DETF/hook consumers. Researchers inspected representative surfaces, not an exhaustive integration inventory.
- Preserve current durable snapshots; specify every newly introduced workflow's full-set final sync and accounting reconciliation.
- Produce independent reference transitions and production-path acceptance tests, including repeated same-block repair and cross-mode/cross-route cycles.

## 6. Recommended PRD edits before plan freeze

1. **Header/scope:** name FullSpread and the exact new target directory. Record old-vault deprecation intent separately from execution authorization.
2. **§12:** replace the present-tense old-vault diagnosis with a historical distinction: FullSpread already uses durable local snapshots; all new flows must preserve them.
3. **§15:** cite current FullSpread files, shared constant-product math and current family PRD. Keep old sources explicitly labeled historical only.
4. **Route/state matrix:** distinguish idle exact-in, blocked exact-in, dual deposits, bootstrap/imports, exact-output share mint, public rebalance and automatic placement. State how native SY and affected consumers reach these paths.
5. **Supersession table:** identify the old no-swap public-rebalance rule (CP PRD:225) and percentage-of-total placement rules as superseded for this feature; preserve unrelated family requirements and old-source preservation. Use document-qualified decision IDs because D-numbers recur across PRDs.
6. **Protection table:** distinguish accepted limits from pending calibration, define enforcement, and capture authority without silently creating new admin rights.
7. **Acceptance matrix:** add explicit preservation checks for existing caller guards/local snapshots, automatic-tail scope, exact-output scope, percentage reporting, transition quotes, unsupported-hook quote behavior and complete per-operation accounting.

A targeted documentation revision within `docs/plans/` can make these changes without rewriting historical co-located PRDs. This report does not modify any of them.

## 7. Attributed positions, corrections and dissent

### Original independent positions

- **Astra:** conditionally plan-ready; asked about public repair's objective and automatic holder-funded swaps. Inspected old-tree accounting/guard defects and mistakenly treated them as target work.
- **Grok:** initially blocked on locked issuance and flooring semantics; uniquely identified FullSpread as the current target and the PRD's historical-source mismatch.
- **MiniMax M3:** plan-ready with nine proposed questions. Its original included factual errors about sleeve algebra, full booking and dual-deposit tails.
- **Kimi K3:** plan-ready without true blockers; sought protection/deadband confirmations. Its guard and stale-snapshot findings likewise concerned the old tree.

### Cross-review outcomes

- Astra and Kimi withdrew the target-specific missing-guard/stale-snapshot claims. Grok verified those protections already exist in FullSpread.
- Grok withdrew its two original blockers: preserved blocked invariant-growth behavior is not automatically a D58 violation, and the 1 bp requirement includes flooring.
- Astra/Grok/Kimi agree the new sleeve formula is a real required change. It is not equivalent to today's formula at 20%.
- MiniMax corrected its target and recognized existing local snapshots/guard, but retained incorrect assertions and proposals. The moderator rejects its claims that both sleeve formulas match at 20%, that dual deposits lack an idle tail, and that existing sleeve-only no-op logic already satisfies new proportionality stopping. The moderator also rejects its recommended observe-only protections and exclusion of flooring as contrary to the PRD. MiniMax's statement that all originals targeted the old tree is incorrect: Grok did not.
- Kimi's characterization of the 1 bp impact as necessarily negligible/dust-only is not established. Large share supply does not prove every contribution has sufficient precision, and composition mismatch is a separate cause of loss.

**Unresolved interpretation:** Astra/Kimi prefer owner confirmation for public-only swapping tails; Grok treats it as a sufficiently clear default. Exact-output composition scope remains a narrow adjacent-route question. No full-council unanimity is claimed on these interpretations or on MiniMax's conflicting recommendations.

## 8. Evidence, versions and limitations

- Observed compiler configuration: `foundry.toml:29–36`, Solidity **0.8.35**, optimizer enabled with **1 run**, `via_ir=false`. No installed Foundry runtime version or successful execution was established in this review.
- Current family preservation/version separation: CP PRD:7–10,96–102,235–243. Complete-book/internal-settlement reference: :128–185,219–233. This feature supersedes the scoped prohibition on public repair swaps, not preservation constraints.
- DETF release law: `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:1153–1161`.
- Canonical pretransfer law: `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:29–47,173–213`.
- Context7 was consulted first for Uniswap API behavior: `/uniswap/v4-core`, https://context7.com/uniswap/v4-core/llms.txt, accessed **2026-09-27**. It corroborates unlock-callback execution and end-of-session currency settlement.
- Researchers independently consulted primary upstream sources on **2026-09-27**: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol ; https://github.com/Uniswap/universal-router/blob/main/contracts/modules/V3ToV4Migrator.sol ; https://github.com/Uniswap/v4-periphery/blob/main/src/PositionManager.sol . Their router finding supports the PRD's narrow mint-command claim, not a migration recommendation.
- Moving upstream `main` URLs are not local dependency commits, deployed-bytecode pins or proof of compatibility. Pin the actual implementation/reference versions during planning.

**Confidence:** high in directly observed FullSpread behavior and the sleeve/issuance distinctions; medium in complete consumer coverage and arbitrary-hook feasibility; no runtime validation or economic-security proof. No new claim that historical tests passed is made. Consensus and future passing tests would not prove safety.

## 9. Preserved council record and handoff

All originals remain unchanged. Each researcher read the other three complete original artifacts together for its one completed cross-review, never earlier cross-review artifacts. The first Astra cross-review call was interrupted by the human clarification; the same session then completed. Four initial passes and four completed cross-reviews were obtained, with one additional interrupted invocation and no replacement session.

| Researcher | Original session ID | Original | Cross-review |
|---|---|---|---|
| Astra | `ses_f1c5107bfffefDJanl5lU29WfQ` | `astra-original.md` | `astra-cross-review.md` |
| Grok | `ses_f1c4d2922ffewPe5TNJvLvwfiy` | `grok-original.md` | `grok-cross-review.md` |
| MiniMax M3 | `ses_f1c42bd1cffeeUULWzxjga1tEf` | `minimax-original.md` | `minimax-cross-review.md` |
| Kimi K3 | `ses_f1c40272fffegWv5fAQexS8el4` | `kimi-original.md` | `kimi-cross-review.md` |

All report filenames above are relative to `docs/research/uniswap-v4-zapin-prd-review-2026-09-27/`. These model-authored records are attributed evidence, not authority or permission changes. The task metadata recorded the expected researcher targets/models; that is not independent provider attestation.

**Human checkpoint:** confirm or change the recommended public-only swap scope, decide whether exact-output mint belongs in the composition change, and ratify the working protection values before implementation freeze. Planning can begin with these assumptions explicitly marked.

**Separate implementation handoff:** after requirements are recorded, author an implementation/test plan under `docs/plans/` covering target/selector mapping, route/state matrix, accounting transitions, solver/quotes/protections, public-vs-automatic repair, reporting and regression gates. Writing that plan does not authorize executing it. No old-vault deprecation operation is part of this review.
