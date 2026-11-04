# Council brief: complete V4 fee-earning vault design

## Run

- Run ID: v4-wings-complete-design-20261025-01a171a0
- Date: 2026-10-25
- Profile: research
- Council kind: full
- Question: Recommend the entire replacement design for the Uniswap V4 Upper Lower Wings Standard Exchange vault, including ownership, deposits, share issuance, fees, compounding, maintenance, withdrawals, previews, getRate, and use in external liquidity pools.
- Brief path: docs/research/v4-wings-complete-design-20261025-01a171a0/brief.md

## Authorization

- Source: explicit council directive.
- User request: "What does the council recommend for the entire vault design, everything. How to deposit, and withdrawal."
- Authorized work: read relevant evidence and publish this council's research documents. Recommend changes to any previous design expectation, explicitly naming the changes and their costs.
- Not authorized: implementation, project test execution, installation, deployment, wallets, Git staging/commits/pushes, configuration changes, credentials, or further delegation by members.
- Inherited permissions: accepted; assignment boundaries are not a filesystem sandbox.

## Coordinator

- Requested mode: invoking-agent.
- Requested role: current coding agent acting as council coordinator.
- Requested model and reasoning: retain invoking model; reasoning metadata not exposed.
- The coordinator is not an independent vote.
- Use the installed Native council workflow, not the historical OpenCode-only dispatch instructions in docs/agent/RESEARCH_COUNCIL.md.
- Procedure: four independent originals, one identified coordinator draft, one advisory continuation per member, then a resolution and final report. Advisory members may read all four originals with that draft, but must not read peer feedback.

## Requested roster

Paths in this table are relative to this run root.

| Label | Role | Requested model/reasoning | Owned initial | Owned feedback |
| --- | --- | --- | --- | --- |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | members/astra/response.md | members/astra/feedback.md |
| grok | council-member | xai/grok-4.7:xhigh | members/grok/response.md | members/grok/feedback.md |
| minimax | council-member | minimax/MiniMax-M3; configured adaptive thinking | members/minimax/response.md | members/minimax/feedback.md |
| kimi | council-member | kimi-coding/k3:high; global route | members/kimi/response.md | members/kimi/feedback.md |

No provider/account/model substitutions. Runtime metadata, not signatures, establishes actual routes. Missing participants remain named. All requested initial tasks must settle before synthesis; at least three substantive originals are required for a labeled partial-full result.

## Admission

- Required evidence: this brief, CLAUDE.md, the audit's APEX-2026-012/024/025/026/040 sections, and the current V4 Wings source family listed below.
- Required tools: local text read and assigned Markdown creation through apply_patch. The ordinary role is registered in the parent tool schema and user configuration. No member subagents or shell commands.
- Optional tools: generalized primary-source public research, local glob/grep/LSP for relevant dependencies. A missing optional search tool is a disclosed gap, not permission to invent evidence.
- Public-query boundary: only public concepts, identifiers, or URLs; do not send private source, local paths, or conversation excerpts to public search services.
- Depth preflight: invoking root has already admitted direct children in this session; council-member has configured max_depth 2. This run launches only direct members and forbids member fan-out. Current effective runtime admission is checked by the ordinary task call; no settings are changed.
- Effective isolation: request shared workspace, isolated false; no automatic merges.
- MiniMax preflight: the installed agent model override contains forceAdaptiveThinking true for MiniMax-M3. This observes configuration, not a captured effective provider payload or billing source.
- Admitted read scope: relevant project sources, interfaces, test sources, product documents and prior reports; public primary sources. Do not read credentials, private session files, unrelated runtime state, or peer initial/feedback files before permitted.

## Current conversation: supplied evidence, not a finalized design

The user began with two business needs: a reserve exposed to trading fees, and a single-target-token exit quote/rate allowing shares to be used in liquidity. The user subsequently said: "What do you suggest to allow us to fully credit imbalanced contributions? I am open to any internal accounting process. Do not limit your recommendation in any way, assume you have full authority to change any requirement or expectation."

This grants freedom to recommend changes, not authority to implement. Do not mistake candidate statements for settled product law. Evaluate independently; the parent has not proved a design.

Current preferences and proposals:

1. Exact proportional zap-in sizing was considered too gas-expensive. The earlier strategy accepted target only and let trading move single-sided wing liquidity into range.
2. A newer candidate swaps approximately 49%-51% of a target-only deposit, adds matched full-range core liquidity, and deposits either token's overage into its appropriate wing. The exact percentage is undecided; it is a fraction of target input, not a raw-token ratio.
3. The user wants full economic credit for retained overage, not silent donation under a limiting-token mint rule.
4. User ownership includes every core/wing position, both idle balances and all accrued fees.
5. The intended exit withdraws the holder's actual proportional claim and sells only that claim's opposing inventory. Payout is actual target recovered, subject to user slippage protection, not a fixed promise based on a hypothetical sale.
6. The user intends to compound fees into the appropriate upper and lower wings. Ownership of cross-section reinvestment must be explicit.
7. The user explicitly retained getRate as a decimal-normalized one-whole-share target exit preview. Arbitrary-size previews quote their actual size. A rate read does not execute the quoted swap.
8. The parent proposed independent-reference portfolio valuation for issuance, with actual-proceeds exits and execution-quoted getRate. The user agreed with the proposal but corrected the parent's claim that getRate had to change. No reference-price source has been chosen. Do not silently assume an oracle exists for arbitrary token pairs.
9. The parent clarified that issuance NAV is NOT zap-out valuation, and that approximate entry/exit swaps alone do not prove the original attack closed.
10. Latest alternative: separate section share accounts for core/upper/lower. Distinguish internal bookkeeping behind one ERC20 from genuinely separate transferable claims. This alternative has not been selected.

Older PRDs/tracker entries describe no-oracle historical settled-target counters and other restrictions. They are historical evidence, not constraints overriding this request. Separate the prior immutable-deployment facts from source redesign. Do not restore deleted V4 FullSpread or other retired products.

## Required repository evidence

Paths below are relative to /Users/cyotee/Projects/indexedex.

- CLAUDE.md: current family routing and repository boundaries.
- docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md: APEX-2026-012 (starts near line 268), 025 (1109), 026 (1173), 024 (1605), 040 (2141). Verify current locators before citing.
- contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/: read the Money, Accounting, LiquidationQuote, Inventory, Geometry, Harvest, Repo, EconomicTarget and relevant query/projection/SY/DFPkg surfaces as needed.
- contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol: relevant direct rate-adapter evidence. It currently derives its rate from a full-supply exit preview; do not assume it consumes the vault's canonical getRate unchanged.
- Relevant direct Uniswap V4 buffer-hook rate consumers under contracts/hooks/uniswap/v4/: inspect enough to state whether they value shares without redemption.

Optional historical context, not binding approval:

- docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md
- docs/security/audit/second_review/APEX-2026-012-OPEN-QUESTIONS.md
- docs/security/audit/second_review/REMEDIATION_TRACKER.md
- docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md
- docs/plans/records/uniswap-v4-upper-lower-wings/
- docs/reviews/apex-012-design-recommendation-20261024/REPORT.md
- Existing production-first test sources, read only, where useful for the eventual validation requirements.

## Decision-complete questions for every member

Give ONE preferred complete architecture, not just a menu. Explain the strongest counterargument. Compare at least:

- Fungible portfolio shares, independent-reference valuation of each position for issuance, actual-proceeds exits, execution-quoted getRate.
- Oracle-free strictly proportional position ownership with externally/off-chain supplied zap sizing and cheap on-chain verification/refund, rather than an on-chain iterative solver.
- Separate section/range claims (multiple ERC20s/ERC1155/NFT or fixed-basket wrapper), including cross-section compounding and liquidity usability.
- Any credible invariant-based alternative you prefer. Do not assume sqrt(aggregate actual token reserves product) is a manipulation-resistant invariant for heterogeneous ranges.

For the preferred design, cover ALL of these:

1. Asset/share units, state, fungibility, ownership fraction, initial liquidity, bootstrap, decimals, rounding, dust, direct donations, fees and liabilities.
2. Precise share issuance equations, both tokens, how all retained imbalance is credited or explicitly returned, and the point at which ownership is established. Distinguish token custody from reference-valued hypothetical composition.
3. Full deposit sequence: harvest/checkpoint, quote or reference snapshot, swaps, core and wing additions, actual credit, share mint, refunds, minimum shares, deadlines and failure/partial-fill handling.
4. Charge entry execution costs to the entrant. Existing LPs' accrued fees and fees earned during the entrant's own swap remain with existing holders; avoid double-counting them as contribution. If recommending a different allocation, state why.
5. Full withdrawal sequence: slice every relevant asset and fee, burn/remove liquidity, sell opposing inventory, retain or refund swap residuals, actual payout, minimum target out, deadline, last-holder exit and liquidity failure. State whether in-kind fallback is necessary and what changes.
6. Quote implementation, one-whole-share getRate normalization, size-dependent price impact, projected-state rate queries, exact-input/exact-output interfaces, and consistency between preview and the actual stateful flow.
7. Fee compounding and maintenance: target/opposing fees, section attribution, range creation/replacement, rebalance swaps, who bears costs and whether callers can force harmful actions.
8. Gas: no invented gas measurements. Distinguish bounded arithmetic over three positions from actual swap tick traversal and quote tick walks. Explain where solving happens and whether a view/off-chain solver removes the original gas objection.
9. Independent-price availability and oracle design if used, or the precise reason no price is needed if not. Do not value live-spot-derived LP principal at an independent price and call the result spot-independent; evaluate the LP range at the reference price itself when appropriate.
10. Full attacker economics: deposit before/after spot/depth changes, settled and unsettled JIT, actual swap proceeds, attacker LP inventory changes/unwind, fees, share issuance, and remaining holders. Distinguish illustrative math from demonstrated production exploits.
11. GetRate consumers: accurate execution quotes can still be unsafe pricing oracles for a pool that pays without redeeming. Establish what the preferred integration can honestly guarantee, what needs bounds/independent pricing/actual-size settlement, and whether raw target and shares can be treated as economically identical.
12. APEX-012/024/025/026/040 implications, reentrancy/read-only reentrancy and nested manager-unlock contexts, quote liveness and dust ticks. No static proposal closes a finding without runtime evidence.
13. A production-first validation plan with invariants, attacker round trips and integration checks. Do not run those tests in this research assignment.
14. Explicit changes from current user preferences, practical limitations, deployment eligibility, decisions genuinely left to the owner, and the simplest implementation surface. Focus on V4; do not expand this run into V3 implementation.

If no design meets all preferences, select the tradeoff you recommend and state the incompatibility plainly. A single scalar rate cannot generally equal actual execution proceeds per share for every redemption size; define its quote size rather than hiding the distinction.

## Output requirements

- Use the member-response structure: identity with unavailable fields labeled not exposed; question; evidence; assumptions; coverage; conclusions; preferred complete design; alternatives and strongest objection; limitations.
- Label source observation, coordinator-supplied evidence, inference and unverified claims. Cite actual local path/symbol/line or public primary source read. No invented runtime evidence, gas measurements or consensus.
- The initial pass is independent. Do not read any current-run peer responses or draft before submitting your own response.
- No project code/config edits, shell, project tests, installs, wallets, deployments, Git operations, or subagents.
- Use apply_patch for assigned Markdown creation. Write only your assigned response path on the initial pass and only your assigned feedback path on the advisory pass.
- Keep the response substantive and readable: the owner needs a deposit-to-exit machine, not slogans or unexplained formulas.

## Artifact root and delivery

- Admitted new root: docs/research/v4-wings-complete-design-20261025-01a171a0/
- Delivery: both report files and an owner-facing synthesis in chat.
- Intended final: REPORT.md.
- Cooperative publication target: none. Do not alter existing PRDs, audit findings, trackers or old council reports.
- Coordinator owns brief.md, RUN.md, coordinator/draft.md, coordinator/resolution.md and REPORT.md.
- Members own only their response/feedback paths in the roster.

## Attempt caps and settlement

- Member logical assignment caps: three council-issued attempts, including initial; synthesis caps at two. No retries for disagreement or auth/policy failure.
- No discretionary council token/time/silence deadline.
- Native settlement, not a file appearing, completes a member turn. Preserve originals, feedback and dissent.
- After all initial turns settle, the coordinator drafts, requests one feedback continuation from each requested member, resolves all substantive feedback, and publishes a clearly labeled coordinator final revision.

## Tool-availability delivery clarification

One initial member reported that apply_patch was absent from its exposed tools. This does not authorize a different file-editing method. If apply_patch is unavailable, return the substantive assigned original or feedback inline in the final task response instead of writing a file. The coordinator may preserve that member-authored text, clearly labeled as an inline receipt rather than a member-written artifact, under coordinator/received-originals/<label>.md or coordinator/received-feedback/<label>.md using apply_patch. These receipt paths are coordinator-owned. Existing member originals remain unchanged. This changes delivery mechanics only, not independence, roster, scope or phase order.
