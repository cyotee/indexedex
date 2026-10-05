# Council prompt: search-free Uniswap V4 Hookless redesign

**Date:** 2026-10-03. **Use:** paste the prompt below into a **new** `/council` moderator session. Do not resume September 27 researcher sessions. Those children belong to a different moderator and the guard rejects them with `RC_POLICY` (`continuation must belong to this moderator session`).

Start fresh sessions of the same four agents: `council-astra`, `council-grok`, `council-minimax`, `council-kimi`. Omit `session_id` on the first four calls. Cross-review only the new session IDs. Research and document authoring only. No contract, test, config, or deployment edits.

Assigned originals, if written:

- `docs/research/uniswap-v4-hookless-redesign-2026-10-03/astra-original.md`
- `docs/research/uniswap-v4-hookless-redesign-2026-10-03/grok-original.md`
- `docs/research/uniswap-v4-hookless-redesign-2026-10-03/minimax-original.md`
- `docs/research/uniswap-v4-hookless-redesign-2026-10-03/kimi-original.md`

Moderator consolidation, after cross-review only: `docs/research/uniswap-v4-hookless-redesign-2026-10-03/COUNCIL_SYNTHESIS.md`.

---

## Prompt

Reconsider the entire Uniswap V4 Hookless Standard Exchange vault design. The owner is willing to change accounting, routes, and interfaces if that removes on-chain discovery/sizing searches while keeping full-range liquidity and some useful local liquidity sleeve.

This is a design question, not a new prohibition and not permission to implement. The owner did **not** impose a hard ban on binary search. The owner asked whether a different design can achieve comparable behavior without a discovery loop, and what else would have to change. Challenge every proposal below. Do not treat the moderator's preference as a conclusion.

### Question

Can we redesign the Hookless SE vault so ordinary deposits, redemptions, and quotes do not run an on-chain discovery or sizing search, while still keeping a useful liquidity sleeve and remaining composable with the Orbital hook's own SE/SY surfaces?

If yes, which design should we adopt, and exactly which current behaviors must change? If no design can preserve a behavior, say so and name the behavior. Rank alternatives. Record dissent. Stop at a human decision checkpoint. Do not implement.

"Search-free" means no exploratory sizing loop: no binary search, refinement loop, or probe sequence whose purpose is to discover a swap amount, share amount, or placement amount. It does not forbid the bounded tick traversal required to execute or quote one already-sized swap. Moving the same search into a router, helper, or off-chain planner that an autonomous Orbital call cannot supply is not a solution.

### Why this is being reconsidered

The current plan interleaves caller composition and holder repair with user operations. Composition asks: how much of a single-token credit should be swapped so the caller's resulting basket matches the incumbent whole book **after that swap changes the pool price, the existing position's composition, and accrued fees**? Maintenance separately tries to restore proportionality and the sleeve. The implementation plan permits up to 32 refinements and 64 core steps per exact-input simulation. Exact-output numerical inversion is already rejected.

That work is amplified when the Orbital buffer hook, which is itself an SE/SY, composes nested Hookless full-spread SE vaults. Historical, unverified trace notes said one nested `planDeposit` used about 19,969,279 gas inclusive, with 11 `quoteTransition` calls, 547 `extsload`s, and individual deposit quotes near 1.8M gas, against a 31,000,000 gas SY test cap and a 32,000,000 gas Robinhood chain cap. Those figures are not fresh measurements. The last trace predates later speculative edits. Final Orbital position tests were still failing. Do not claim a gas win without a new measurement, and do not run that measurement in this research round.

Removing optional holder maintenance alone does not remove caller-composition sizing. Those are different operations. Treat them separately.

### Current authority to read directly

Read these before recommending a change. Current source wins over this prompt if they disagree.

- `CLAUDE.md`
- `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`
- `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md`
- Hookless planner, query, inventory, and protection math under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`
- Orbital composition under `contracts/hooks/uniswap/v4/standardExchange/orbital/`
- Crane `UniswapV4Utils.sol`, `UniswapV4ZapQuoter.sol`, and `UniswapV4Quoter.sol` under `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/`
- Failing fixture context: `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol` and `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol`

Use Context7 before library or API claims, then primary sources. Do not send proprietary source or secrets to external services. A missing ordinary file is not a participant failure: record the path, do not retry that exact path, and continue.

### Behaviors the owner still cares about

Preserve these unless a ranked design explicitly trades one away and states the replacement:

- Full-range Uniswap V4 liquidity, not a recast concentrated range.
- Fungible vault shares and complete booking of locally held balances.
- A useful local sleeve for operations while PoolManager is already unlocked. Nested unlock remains forbidden. The sleeve does not promise unlimited blocked withdrawals.
- Single-token entry and exit if a search-free design can support them. If it cannot, say what the caller must do instead, and whether autonomous Orbital calls can still do it.
- Explicit slippage or price-impact protection. Do not replace it with `minOut = 0`.
- Separate Pons Family V2 orchestration and fees. This round redesigns Hookless. State Pons implications. Do not merge the families.
- Dual-token initial activation, unless a proposal shows why a replacement is safer and says the owner must approve it.
- "Retain and sweep later" for identified excess, unless the replacement states a different residual rule.

Current accounting the redesign must either keep or consciously replace:

- Backing `B = D + F + E`: deployed principal, spendable local inventory, and earned uncollected own LP fees. Fees count once.
- Proportional mint `min(floor(S*C0/B0), floor(S*C1/B1))` for a positive two-leg book.
- Caller credit is excluded from incumbent reserves. A swap's repricing and own-LP accrual belong to incumbents, not to the depositor.
- Sleeve target is the live fee-oracle percentage of owned deployed principal, default 20 percent, with the existing deadband. Placement changes the denominator. Do not freeze the target on pre-placement principal.
- Accepted bounds in the current PRD: 1 bp depositor alignment, 50 bp composition impact, 25 bp repair impact, 10 bp execution shortfall. A redesign may propose different bounds only as an explicit owner decision, not as a silent relaxation.
- F0 minimum liquidity and dead-sink shares stay unless the proposal replaces initial funding and says why.

### Designs to evaluate, then improve or reject

These are untrusted moderator sketches. Attack them.

1. **Proportional core, separate conversion.** The core vault accepts a proportional basket and pays in-kind withdrawals. For requested shares `m`, a starting requirement is `C_i = ceil(m*B_i/S)`, subject to collection, placement rounding, and credit rules you must specify. Single-token entry and exit become a conversion around that core. Maintenance is a separate call. A router that still binary-searches, or an off-chain plan the Orbital hook cannot pass, does not count as search-free.

2. **Single-token deposits under different valuation.** Keep arbitrary single-token entry, but price an unbalanced contribution with an explicit invariant or valuation. Deployment can happen later. State who bears imbalance, how redemption cannot extract value, and why spot NAV is or is not acceptable. Oracle dependence is a design cost, not a free fix.

3. **Domain-restricted direct sizing.** Keep more automatic single-token behavior, but only while inventory, fees, sleeve, and price stay inside a domain where one arithmetic formula is correct. Define the out-of-domain behavior: reject, partial accept, or separate maintenance. `getLiquidityForAmounts` alone does not solve arbitrary post-swap whole-book alignment. "Full range" does not by itself make a constant-product zap formula applicable. Finite-range active liquidity, fees, and rounding still matter.

4. **Your alternative.** Propose one if it is better. A search-free design may also be: core vault only, with single-token conversion explicitly unsupported on-chain. Say whether that is acceptable for Orbital.

The moderator's tentative lean was to investigate (1) first, with an explicitly reserved best-effort sleeve rather than purely accidental leftovers, and to treat automatic single-token conversion and Orbital compatibility as required design questions. You may reject that lean.

### What a sleeve can mean

Compare these policies. Do not assume continuous rebalancing is required to have a sleeve.

- Separate maintenance restores a target after user operations have moved inventory.
- Placement reserves local inventory, accepting that both tokens may not meet their targets at once.
- The sleeve is only the residual that could not be deployed. Either side can go to zero.

Blocked operations still pay only from actual local cover.

### External models are leads, not authority

Previous discussion named Charm Alpha / Alpha Pro, Arrakis V1, Arrakis V2, Gamma Hypervisor / UniProxy, and Range Protocol as possible proportional-deposit, separate-rebalance models. Those claims were not fully verified. If you use one, read the primary contract or doc for the version you cite, give the URL and access date, and say whether it is actually a full-range vault or only configurable to full range. Do not repeat exploit history unless you have a primary source. Do not copy a manager-supplied swap amount into an interface Orbital cannot populate and call that a solution.

Candidate starting points, unverified:

- https://learn.charm.fi/charm/technical-references/core/alphaprovault
- https://github.com/charmfinance/alpha-vaults-contracts
- https://github.com/ArrakisFinance/vault-v1-core
- https://github.com/ArrakisFinance/v2-core
- https://docs.gamma.xyz/gamma/lp-vaults/developer-portal
- https://github.com/GammaStrategies/hypervisor
- https://github.com/Range-Protocol/contracts

### Not accepted, and not in scope to implement

- Raising the 31M or 32M gas caps as the fix.
- Planned settlement with `minOut = 0` on nested SE deposits.
- Gas-dependent valuation, including a rate provider that quotes only when `gasleft()` exceeds a threshold and otherwise falls back to live supply.
- Carrying speculative `sharesJ` / `sharesK` quantities as if they were a reviewed accounting fix.
- Numerical exact-output inversion.
- A claim that `UniswapV4ZapQuoter` is cheaper or search-free. Prior inspection said it searches and its quoter reads tick bitmaps. No comparative benchmark was run. You may discuss it. You may not assert a gas result.

### Required output

Return a self-contained original, ideally at most 2000 words, with:

1. A ranked recommendation, or a refusal to rank if the evidence is insufficient.
2. For each design: what stays, what the user sees change, and which PRD decisions (D1–D31) would have to be amended.
3. Exact share, contribution, fee, and residual equations, including empty, one-sided, and already-unlocked domains. Show conservation. Do not say "use a router" without an interface Orbital can call without searching.
4. Sleeve policy and blocked-cover behavior.
5. Orbital and SY consequences: which current calls become invalid, and what replacement call is search-free.
6. Manipulation, donation, fee-ownership, rounding, and same-pool incumbent-repricing risks.
7. An acceptance and benchmark plan for a later implementation agent. Do not execute it.
8. Evidence, source `path:line`, primary URLs, versions, access date, confidence, and gaps.

Do not read another researcher's original during the first pass. Do not claim consensus in the original. Do not claim measured gas improvement.
