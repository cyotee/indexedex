# Astra — Original independent PRD review

**Date/access date:** 2026-09-27. **Verdict:** ready to draft a conditional implementation plan, not yet an unambiguous implementation specification. The direction is coherent; two narrow requirements confirmations should precede plan freeze. No settled owner decision needs reopening.

**Scope/assumptions:** Reviewed the September 27 target PRD, CLAUDE.md, canonical skill catalog and relevant Crane architecture/deployment/testing/adversarial/V4 skills, local testing/adversarial skills, both co-located V4 SE PRDs, canonical pretransfer law, and DETF alignment D57–D59/§24.7.1. Current decisions override historical clauses. No peer artifacts, shell, tests, delegation, implementation, or configuration changes. References below use **PRD** for `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` and **V4/** for `contracts/protocols/dexes/uniswap/v4/`.

## Prioritized requirements questions

### P1 — Confirm the public repair target, not the numerical solver

**Fact:** PRD:201–225 requires useful progress and stopping when proportionality and sleeve thresholds both pass; :366–375 delegates metrics to planning. It never explicitly defines what public-repair inventory is proportional *to*. Deposit proportionality is separately and clearly defined against post-swap incumbent backing (:150–166).

**Inference:** the intended repair goal is making spendable whole inventory compatible with the existing full-range position's current/post-trade token requirements, while approaching `F_i = p D_i`. Comparing inventory with its own whole-book ratio would be tautological; preserving a historical ratio would introduce a different trading strategy.

**Owner question/recommendation:** confirm that deployability plus sleeve adequacy is the economic objective, not a historical token allocation or market-price target. Planning can then choose normalized error, fee-aware progress, thresholds, bounded search and truthful no-op outcomes. **Counterargument:** this objective is strongly implied by purpose and sleeve policy; confirmation is a short clarification, not grounds to stop all planning. Immediate repeated calls remain mandatory.

### P1 — Identify which entrypoints may spend holders' inventory on repair swaps

**Fact:** D2 limits deposit-composition swaps to call credit; D9 expressly authorizes *public* rebalance swaps (PRD:29,36). Existing automatic tails and the public method share `_rebalanceLiquidReserveInternal`: `V4/UniswapV4StandardExchangeCommon.sol:734–738`; `V4/UniswapV4StandardExchangeLiquidReserveTarget.sol:90–94`. Tails run after direct swaps, withdrawals and Multi joins (`V4/UniswapV4StandardExchangeInBase.sol:85–86,213–215,368–372`). Older local-buffer D10 requires automatic tails after free-path operations (`V4/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md:153`).

**Owner question/recommendation:** may those automatic tails also perform holder-funded composition repair, or is the new swap capability public-rebalance-only? Prefer explicit separation: caller-funded zap composition, placement-only automatic tails, holder-funded public repair, unless broader automatic trading is intended. This concerns who pays and when trading occurs, not helper organization. Merely upgrading the shared helper silently decides it. No cooldown or cumulative budget is proposed.

### P2 — Working protections need a freeze record, not renewed economics

PRD:229–265 labels 25/50/10 bp values “working,” but fixes 1 bp alignment elsewhere. Planning may propose storage, queries, bounds and calibration as expressly delegated. Record adopted numbers and who may change them before implementation approval. Escalate only a proposal that changes risk tolerance or introduces mutable authority; do not invent vault administration or ask the owner to choose Solidity storage.

## Engineering details safely left to planning

- **Route matrix and supersession.** Preserve blocked single-token sleeve issuance, existing unbalanced Multi joins, dual bootstrap and imports. Explicitly scope the new dual-composition/1 bp rule to idle single-token zaps; applying it indiscriminately would contradict preserved routes. Current single-sided invariant growth and dual min-ratio branches are distinct (`V4/UniswapV4StandardExchangeCommon.sol:685–712`). Multi intentionally retains surplus (`V4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md:152–163`). PRD:62 already establishes precedence; historical document cleanup is separately authorized, not a blocker.
- **Accounting repair is mandatory, not an owner question.** BasicVault reserves are local snapshots (`contracts/vaults/basic/BasicVaultRepo.sol:23–27`). V4 currently stores economic totals (:605–631 of Common) and subtracts *current* deployed amounts to reconstruct booked local balances (:1274–1288). Position repricing can therefore change inferred credit without an inbound transfer. Implement durable local snapshots, distinct economic totals, complete end-sync, and preserve source-agnostic declared credit. Also verify caller guards: the inspected InTarget:37–77 and Common transfer helper contain no bytecode guard. Do not assume mandated behavior is already implemented.
- **Quotes and hook mechanics.** Update ordinary previews and transition-state simulation, not just execution (`V4/UniswapV4StandardExchangeInQueryTarget.sol:15–29,107–127`). Current hook adjustment returns unchanged vanilla output for unsupported hooks (`V4/UniswapV4QuoteService.sol:44–57`). Deployer assurance does not make that an exact fee-inclusive quote. Define truthful unsupported/fail-closed behavior when protection cannot be verified; no discretionary whitelist.
- **Numerics/attribution.** Derive bounded post-swap alignment with exact position repricing, incumbent fee accrual, actual fills, contribution-only swap budgets and final placement reconciliation. Separate principal, fees and hook adjustments: local PoolManager `modifyLiquidity` combines them (`lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:94–132`). Handle zero denominators and tiny inputs without weakening 1 bp; atomic rejection is already approved. Preserve live oracle fallthrough (`contracts/oracles/fee/VaultFeeOracleQueryFacet.sol:322–331`).
- **Acceptance:** independent accounting assertions, mixed decimals, partial fills, own-LP fees, blocked/idle cycles, repeated repair/no-churn, hook callbacks, full-set booking and proxy selector coverage. Tests must exercise registered production packages; passing tests alone establish neither security nor economic soundness.

## Evidence, versions and confidence

**High confidence:** product precedence, existing code mismatches and sleeve algebra. `F=pD` implies `F=T*p/(1+p)`; default 20% means one-sixth of placeable inventory, not one-fifth. DETF alignment §24.7.1:1153–1161 supports exact full-book accounting and dual activation.

**Observed versions:** target PRD updated 2026-09-27; older buffer v1.6/full-range v1.2. `foundry.toml:29–36`: Solidity 0.8.35, optimizer runs 1, via-IR false. Local PoolManager pragma `^0.8.24`; fetched upstream main uses `0.8.26`. No verified dependency commit/deployed-bytecode pin or runtime/gas evidence; no test execution.

Context7 was consulted first (`/uniswap/v4-core`). Primary sources accessed 2026-09-27 corroborate nested-unlock rejection, settled-delta requirement, hook-adjusted liquidity accounting and Universal Router's restricted position command:

- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol
- https://raw.githubusercontent.com/Uniswap/universal-router/main/contracts/modules/V3ToV4Migrator.sol

These are moving-main evidence, not deployment pins. **Medium confidence:** economic convergence and general hook feasibility remain unproven. No demonstrated exploit or performance guarantee is claimed.
