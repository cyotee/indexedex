# Wings v0.2 — clarification review consolidation

Date: 2026-10-05. Full bounded round complete: four independent originals, four combined cross-reviews. PRD unchanged. Research only; no tests, shell, implementation, deployment or configuration edits.

## Retained sessions and evidence

| Member | Session | Original | Cross-review |
|---|---|---|---|
| Astra | `ses_ef7c68835ffey58T5UT2G8JDZo` | [Original](astra-original.md) | [Review](astra-cross-review.md) |
| Grok | `ses_ef7c1c50fffe87e6QGupvs3xke` | [Original](grok-original.md) | [Review](grok-cross-review.md) |
| MiniMax M3 | `ses_ef7bc045effeTc96xsW5R2MidY` | [Original](minimax-original.md) | [Review](minimax-cross-review.md) |
| Kimi K3 | `ses_ef7b7b72fffe3JJ0CVG6FmBRGL` | [Original](kimi-original.md) | [Review](kimi-cross-review.md) |

All reviewed the other three complete originals together, never earlier cross-review answers. MiniMax's write succeeded this round; no replacement or restart occurred. Earlier incomplete rounds remain incomplete and are not retrospectively described as complete.

## Moderator conclusion

The immediate owner discussion can be reduced to three questions: exceptional incomplete-liquidation availability, separate maintenance cost authorization/fee details, and normal-call harvest scheduling. A later batch can cover numeric parameters and platform/interface scope. Engineers owe the owner concrete evidence before requesting approval of manipulation mitigations or the candidate mint formula.

### 1. Exceptional incomplete-liquidation availability

PRD V1/V2 (lines140–158 in reviewed version) requires selling all opposing inventory after hypothetical removal of all owned liquidity. With opposing inventory and insufficient reachable external depth to complete that sale, no complete executable liquidation quote exists as presently defined. Zero liquidity at the current tick alone does not prove this: swaps can reach externally funded ticks across gaps.

Ask whether affected valuation-dependent operations may fail with a specific incomplete-liquidation error until conditions change. Recommend explicit failure rather than invented proceeds, partial value labeled complete, stale quotes, queues or another venue. No default basket recovery is authorized. Distinguish this exception from the already-settled insufficient-local-sleeve error during an outer unlock. Engineering must enumerate the failure domain and demonstrate useful normal operation; this is not permission to reject ordinary routes wholesale.

### 2. Costs and fee conventions

The user already assigned user-operation fees to the initiator. Do not ask that again. The new clarification is whether separate permissionless rebalance may spend bounded vault inventory on its trading fees/impact while its caller pays gas, with no new keeper reward. This is the natural funding consequence of swapping vault assets, but requires explicit cost limits and attribution.

Engineering should propose a cost table: simulated liquidation costs already inside V, actual additional costs, retained fees, externally paid fees and maintenance loss. No double charge, no invented feeTo fee or automatic old FullSpread constants. Candidate growth issuance must remain unratified until these details, state ordering and manipulation analysis are checked.

### 3. Harvest scheduling

Nonzero opposing principal already determines eligibility; no new percentage threshold. Clarify whether idle deposits merely observe eligibility or must perform a bounded harvest. Recommend deposits observe, withdrawals remove what their prescribed priority needs, and general harvest/zap stays in separate rebalance. This does not prohibit operation-local overage placement or necessary bounded slot close/reopen.

## Attribution, corrections and dissent

- Astra initially prioritized exceptional availability, expenses and scheduling; cross-review retained that minimal set and separated proof obligations.
- Grok initially recommended ratifying growth issuance immediately; cross-review withdrew that recommendation and agreed evidence must precede ratification.
- Kimi initially proposed a manipulation-loss expression and claimed retained core implies strictly better execution. Cross-review retracted the bound and downgraded the price assertion to an unproven structural intuition. Kimi continues to emphasize a later mitigation-policy decision. Moderator agrees that external price AND depth manipulation require analysis, but does not ask the owner to accept supposedly bounded extraction before evidence exists.
- MiniMax initially proposed a new harvest conversion threshold and restrictions on overage placement. Those reopen settled requirements and are rejected. Its final list still duplicates incomplete-V policy and lists already-settled valuation basis as a blocker; consolidation does not repeat those questions.
- MiniMax/Kimi suggestions that ERC20-only or exact-input-only release is already implied are not adopted. PRD lines268/277 leave native and exact-output scope open. Consumer obligations must be established before scope cuts.
- Fee-oracle sleeve configuration is not a share-rate provider. Consumer-facing V/S valuation and executable local capacity are distinct. No added pricing oracle or removed consumer rate interface is inferred.
- D_target=0 does not imply F_target=0: a target-only deposit can remain local. Do not add a minimum funded-sleeve eligibility gate without separate approval. The existing insufficient-cover policy is settled.
- “Mixed out-of-range wing” can occur if fees are included in a loose label, but principal classification must use exact price/amount rules. For the PRD's principal-based stage classification, use actual mixed in-range principal; do not derive routing from a wing's name alone.
- Incidental LSP diagnostics do not establish that errors are pre-existing. No runtime/compiler evidence was obtained in this review.

## Engineering obligations, not owner questions

Whole-book simulation, post-own-removal tick/liquidity state, complete-fill checks, exact share arithmetic, bootstrap protection, fee attribution, overshoot/remaining-holder invariants, manipulated liquidity witnesses, useful route domains and measured nested-consumer gas are engineering responsibilities. A work-limit rejection is not proof that the market itself lacks liquidity; diagnostics should distinguish them.

Propose mixed in-range wings before core within stage4 as a deterministic interpretation of preserving core; if it fails, present a counterexample. Do not silently reverse the settled opposing-wing-before-core ordering.

Later parameter approval table: sleeve percentage/deadband, share decimals/minimum/residual sink, bounded maintenance limits, exact-output/native scope, launch chains and gas margin. Existing20%,5% and90% figures remain proposals. No new numeric value is ratified by this review.

## Evidence and confidence

Primary reviewed artifact: `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` v0.2, especially §§5G3,7V1–V6,7A,8,9,10,13,15. Researchers cite current Hookless QuoteService lines45–50,74–99 as a warning that partial redemption quote behavior is not a complete-liquidation implementation. Kimi checked Context7/primary V4 SwapMath: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/SwapMath.sol (access2026-10-05; mutable upstream, not a pinned build identity).

High confidence in distinguishing settled choices from remaining policy and in custody/capacity separation. No economic safety proof, exact loss bound, new gas result or production readiness claim. Consensus is not evidence of security.

## Human checkpoint

Answer the three policy questions or correct their interpretation. Afterward, request a separate PRD revision if desired; this round made no PRD edits and authored no implementation plan. Evidence-driven mitigation and parameter proposals can follow without reopening the settled strategy.
