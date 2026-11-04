# Fee-earning Uniswap V4 vaults with single-token entry and exit

Date: 2026-10-29. Authorization: explicit user request for a thorough online council search and comparison. Research and documentation only; no implementation.

## Question

Find several independently useful examples of vaults holding Uniswap V4 liquidity positions exposed to swap trading fees and processing single-token deposits and withdrawals. Explain each example's features and limitations. Search broadly rather than stopping at familiar names.

## Qualification

For every candidate independently verify:

1. Real Uniswap V4 PoolManager liquidity, not V3, a generic roadmap claim, lending only, or merely a hook.
2. Vault custody/accounting and share model, position ownership, ranges, and how trading fees reach holders (collection, reinvestment, distribution, or retention).
3. Single-token deposit mechanism: native vault versus external zap/router, supported tokens, swap venue, refunds, slippage protection, atomicity and prerequisites.
4. Single-token withdrawal mechanism separately: arbitrary token versus either pool token versus fixed settlement asset, native or external conversion, queues or asynchronous constraints.
5. Trading-fee exposure of reserves as well as invested positions, idle balances, out-of-range behavior, and hooks that alter LP fees.
6. Trust, management/rebalance permissions, oracle/TWAP assumptions where documented, price manipulation and economic limitations, liquidity/capacity limits, fees, pause/allowlists, audit and deployment evidence.
7. Status: deployed with cited address and chain, source-only, announcement, or unverified. Do not infer deployment or security from a repository/audit.

Distinguish confirmed matches, conditional matches (e.g. separately verified zap), near matches, and exclusions. A one-sided out-of-range position or launch curve does not establish arbitrary single-token entry and exit into active fee-earning liquidity. Withdrawal in kind is not single-token withdrawal. Do not count multiple products from one code family as independent designs without explaining their relationship.

## Breadth and evidence

Aim for at least five useful candidates/designs if evidence permits, but never fabricate qualifying examples to meet a count. Include public open-source implementations and less established examples, clearly labeled. Search AMM liquidity managers, ERC4626 wrappers, V4 hooks with vault shares, and zap integrations. Possible leads (not assertions): Arrakis Pro/Modular, Bunni V2, Gamma, ICHI, Steer, Revert, Charm, Krystal, Aperture, Mellow, Decay, Arrakis integrations, and public V4 vault repositories. Find additional leads independently.

Use primary public sources: official documentation, official repositories and actual functions, deployment records/explorers, official audit reports. Record exact search queries and URLs, access date, material observed claims, inferences and unverified gaps. Cite precise functions/contracts where available. Marketing is a lead, not proof of both directions. No project tests, shell, Git, installation, deployment, wallets, external messages, config/code edits or further delegation. Do not send private repository content to public search.

Each member independently searches the complete question. No reading peer responses or outputs before the advisory phase. Return a candidate table, detailed feature/limitation profiles, rejected leads with reasons, strongest reusable patterns, and evidence gaps. Write only your assigned response.md using apply_patch, and return a concise summary with sources and coverage. If web access or the assigned write fails, disclose it; never invent evidence or use a forbidden workaround.

## Council

Invoking-agent coordinator. Full requested roster: Astra `chatgpt-subscription/gpt-6-astra:high`, Grok `xai/grok-4.7:xhigh`, MiniMax `minimax/MiniMax-M3` (configured adaptive setting where exposed), Kimi `kimi-coding/k3.1-pro:high`. Ordinary Native council-member role, non-isolated shared research artifacts. No silent substitution. Four originals, one frozen coordinator draft, one advisory pass per available member, coordinator resolution and report. Actual runtime metadata and participation limitations will be recorded.

Run root: `docs/research/v4-single-token-vaults-20261029-01a18660/`.
