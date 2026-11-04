# Council brief: do executed swaps protect same-pool-priced vault issuance?

## Run and authorization

- Run ID: v4-same-pool-swap-evidence-20261026-01a171a0.
- Date: 2026-10-26. Profile: research. Council kind: full.
- Requested mode: invoking-agent coordinator, not a fifth vote.
- Explicit user request: tokens may have liquidity ONLY in the underlying pool; the project's TWAP of that pool is the available reference. Have the council actually research whether deposit/withdrawal swaps capture manipulated-price changes and provide evidence for its conclusion.
- Authorized output: source-linked research, explicit models, mathematical derivations and reproducible standalone numerical evidence inside this new research root.
- Not authorized: production/config changes, project tests/builds, deploying, wallets, credentials, project Git operations or member delegation. No existing report/PRD is to be overwritten.
- Standalone arithmetic/model execution is allowed, but must not be represented as a production vault test or as reproduction of the audit's Foundry runs.

## The question, without assuming the answer

Can an actual entry swap and an actual proportional-slice exit swap make same-pool pricing safe against malicious ownership dilution or reserve extraction, despite there being no independent market price? If so, which EXACT mint/accounting and execution rules make it safe, and under what proved assumptions? If not, exhibit a fully accounted profitable round trip or a precise impossibility argument for the specified rule, not just the statement that a price is manipulable.

Do not answer by requiring an unavailable external feed. Do not treat the prior council's lack of a proof as a proof of impossibility. Also do not treat real execution, numerator invariance, slippage minima chosen by the attacker, or a correctly simulated quote as proof that ownership issuance is fair.

## Requested roster and owned paths

| Member | Native role / exact requested route | Initial path | Feedback path |
| --- | --- | --- | --- |
| astra | council-member / chatgpt-subscription/gpt-6-astra:high | members/astra/response.md | members/astra/feedback.md |
| grok | council-member / xai/grok-4.7:xhigh | members/grok/response.md | members/grok/feedback.md |
| minimax | council-member / minimax/MiniMax-M3, configured adaptive | members/minimax/response.md | members/minimax/feedback.md |
| kimi | council-member / kimi-coding/k3:high, global | members/kimi/response.md | members/kimi/feedback.md |

Members may additionally create only their own members/<label>/model.py with apply_patch if a reproducible standalone calculation is needed. No other writable path. No peer originals during the initial pass. No peer feedback during the advisory pass.

Project-scoped apply_patch was absent for some previous members. If absent now, DO NOT use another writer: return the full response, feedback and any short model source inline. The coordinator can preserve verbatim receipts under coordinator/received-originals/<label>.md and coordinator/received-feedback/<label>.md, and member-supplied model text under coordinator/received-models/<label>.py. These receipt paths are coordinator-owned, not a claim that the member wrote a file.

No provider/account substitution, extra members or discretionary silence deadline. All four initial turns must settle before synthesis. Four distinct originals and one same-draft feedback pass are the goal.

## Admission

- Owner/root session: 01a171a0-0d64-7a6c-b2a0-834fc1e0e7f7.
- Direct member tasks only. Current council-member configuration has max_depth 2; earlier same-root direct admission succeeded. No depth/settings change.
- Shared workspace, isolated false; no merge.
- Configured MiniMax-M3 forceAdaptiveThinking true observed in the installed models override; effective payload/billing source not independently captured.
- Read scope: relevant project source/audit/test-source/documentation and public primary sources. No secrets or private runtime/session files.
- Required tools: text reads, exact reasoning and either patch-only artifact creation or inline delivery. Scratch arithmetic in a resident kernel is allowed; no shell/project tests or package installs.
- Public queries must be generalized, never private snippets, local paths or user conversation excerpts.

## User context and prior work

- Business needs remain fee exposure and target-token exit/rate usability.
- User considered target-only single-sided deposits to avoid costly exact zap sizing; later candidate makes a best-effort approximately 49%-51% entry swap, puts matched amounts into the full-range core and leftovers into wings.
- Full economic credit for retained overage is desired. Every share owns its fraction of core, both wings, both idle balances and fees.
- Exit is actual proportional withdrawal followed by sale of only the holder's opposing slice, paying actual target proceeds, not a quoted payable top-up from stayers.
- Fees compound into the appropriate wings, preserving ownership.
- getRate remains a normalized one-whole-share actual withdrawal-and-sale preview. Quantity-specific previews quote their own size. A view does not execute a trade.
- The user allows recommending changes to any expectation. This is research, not an implementation decision.
- The previous council selected independent-reference final-contribution issuance, but explicitly had no feed for arbitrary pairs and did NOT produce runtime proof that self-executed pricing is unsafe. That architecture is conditional and does not answer the new same-pool-only question.
- Kimi's prior executed-price suggestion was m=S*D/(A_T + p_exec*A_O), p_exec=targetSpent/opposingReceived, C=D identically. It used pre-swap book quantities and admitted an unproved denominator attack. Study this literal rule and fee-corrected/post-swap variants; do not silently change the ownership cut while discussing it.

## Required source targets

Repository root: /Users/cyotee/Projects/indexedex.

1. CLAUDE.md and relevant source rules.
2. Current V4 Wings source under contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/: Money, Accounting, LiquidationQuote, Inventory, Geometry, Harvest, ExecutionDelegate and rate/projection surfaces as needed.
3. docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md: APEX-012 and 024/025/026/040 for context; crucially APEX-050 near line 2763.
4. Actual same-pool oracle:
   - contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol
   - contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol
   - UniswapV4TwapAggregatorV3Adapter.sol and UniswapV4TwapMorphoOracle.sol in that directory.
5. Existing evidence source: docs/security/audit/second_review/indexedex-2ba07631-pocs/test/apex_audit/probe-twap-retroactive/TwapRetroactive.t.sol. Read only; do not run it.
6. Direct PoolManager swap/modifyLiquidity and pool/range math where needed to justify modeled execution.

Optional prior work, evidence of what was claimed rather than proof:

- docs/research/v4-wings-complete-design-20261025-01a171a0/REPORT.md and member originals.
- docs/research/v4-wings-complete-design-20261025-01a171a0/coordinator/resolution.md.
- contracts/oracles/uniswap/v4/twap/UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_PRD.md (historical spec; not assumed safety).

## Coordinator source observations to verify, not a substituted conclusion

The current oracle write integrates the NEW truncated current tick over the elapsed interval, not just future time. The observe tail also uses live truncated tick. Permissionless update resets lastTimestamp/writeAge. Audit APEX-050 reports push-poke-restore backfilling a full idle window with 9116 ticks, approximately 2.488x, and includes a hypothetical lender PoC. Its reported lender is NOT the Wings vault, and no current deployment/use is being verified here.

This is separate from the main swaps-only hypothesis. Analyze both (a) current oracle as implemented and (b) an explicitly idealized correctly anchored/covered historical same-pool TWAP. Do not use APEX-050 as a shortcut to conclude every possible same-pool design fails. Nor assume a corrected sampling oracle reconstructs unobserved between-poke prices.

## Primary public sources already retrieved by the coordinator

These are supplied-source leads, not member fetches. General queries used public concepts only.

- https://developers.uniswap.org/docs/protocols/v2/concepts/oracles
- https://developers.uniswap.org/docs/protocols/v2/guides/building-an-oracle
- https://blog.uniswap.org/uniswap-v3-oracles
- https://developers.uniswap.org/docs/protocols/v4/concepts/flash-accounting
- https://developers.uniswap.org/docs/protocols/v4/concepts/v4-vs-v3

Their general oracle/arbitrage discussions are not evidence that a thin sole-venue token has an external restoring arbitrageur, or that manipulating it costs the same as a deep multi-venue token. State those assumptions explicitly.

## Required comparisons and falsifiable claims

Specify each model and sequence before discussing its security:

1. Current audit baseline: whole-book live liquidation mint/payout, no mandatory corresponding conversion. Clearly distinguish it from the user's proposed actual swaps.
2. Same-pool zap-out-priced issuance plus actual entry and slice exit swaps. Define contribution credit, denominator, pre/post-swap cutoff and any gross versus net amounts.
3. Literal executed-price issuance above, plus corrected variants accounting for old LP fees and the post-swap composition. Test fixed 49/50/51 percent entry and attacker-selected sizing separately.
4. Correctly proportional position-vector entry, with swaps sized externally and actual funding verified, refunding unmatched excess. Is there a real no-oracle safety invariant? What does it give up?
5. A credible same-pool/invariant/internal-AMM accounting design that could retain imbalance, if one exists. Do not dismiss all such designs without analysis; also do not assert sqrt(aggregate reserves product) is conserved for heterogeneous ranges.
6. Same-pool TWAP-gated variants: correctly maintained history versus current library, pre-swap snapshot versus post-swap poke, deviation bands, operation caps, multi-block holding, no outside arbitrage market and oracle update control.
7. Quote-only downstream consumers: separate their risk from whether the vault's own issuance/redemption is safe.

For each supporting or contradicting case:

- Give initial pool price/liquidity/fee, vault ranges/liquidities/idle/fees/supply, attacker assets/shares/LPs/debt and all entry parameters.
- Track every swap, fee, liquidity add/remove, position-composition change, principal/fee checkpoint, share mint/burn and user payout.
- Count the vault's own liquidity filling both entrant and exit swaps and the attacker's JIT LP inventory. A toy with static idle tokens is not an exact Wings reproducer; justify reachable states or label the missing behavior.
- Close debt and attacker LPs/shares. Prefer a fully target-denominated final wallet with zero opposing exposure: this avoids importing the independent fair price that the user says does not exist.
- If assets remain, show them separately and do not call an arbitrary external mark a realized profit. A restored same-pool spot is a comparison convention, not permission to double-count or assume free liquidation.
- Include a matched no-attack/control path and a token-conservation ledger. Distinguish ordinary arbitrage/fees from incumbent dilution or unauthorized inventory extraction.
- Try vault fractions of active liquidity near 0%, 10%, 50%, 90%, 99%; low/high external same-pool depth; core-dominant and wing/idle-heavy portfolios; fixed/default and large deposits; realistic positive fees as well as zero-fee algebra.
- A zero-fee, full-range CP model may be a useful limiting case, but do not advertise it as a realistic fee-earning production exploit. Show whether a margin survives fees and actual placement.

## What counts as evidence

Evidence classes must stay separate:

- Source observation and reported existing PoC output.
- Exact derivation with all assumptions.
- Reproducible standalone numerical witness/control, with code/parameters/action ledger.
- Parameter search with its finite domain and failures disclosed.
- Production behavior that remains UNVERIFIED because no project tests or new vault implementation were run.

Every member must provide at least one substantive exact derivation or fully specified computational case, not merely a recommendation. If unable to find a profitable attack, report the search domain and say "not found", not "impossible." If asserting safety, state a conservation/no-arbitrage invariant and its domain, not "the swap captures the price."

If asserting an attack, count its manipulation/unwind/LP/borrow costs; a raised quote alone is not enough. If asserting a counterexample in a simplified model, state exactly what it disproves and which production behaviors remain unmodeled.

## Deliverable structure

1. Verdict on the specific swap-capture hypothesis, with confidence limited by evidence.
2. Exact model definitions and share cutoffs.
3. Supporting controls and contradicting witness/proof, equations, action ledger and reproducibility.
4. Current TWAP audit/source assessment, and separately a corrected same-pool TWAP's possible guarantees and limits.
5. Best viable no-independent-feed design or explicit unresolved tradeoff.
6. One-share getRate and downstream-consumer implications.
7. Required next production validation, without running it or claiming static closure.
8. Sources actually examined, public queries, assumptions, missing coverage and strongest counterargument.

Use apply_patch only for owned files or inline fallback. Preserve independent originals and dissent. No extra council or subagents. The coordinator will compare all originals, independently check calculations, publish one immutable draft, obtain one advisory pass each and publish a concern resolution/final.
