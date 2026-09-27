# PRD: Uniswap V4 Standard Exchange — Proportional Zap-In with a Liquid Sleeve

**Date:** 2026-09-26  
**Status:** Owner-approved product direction, including proportional ownership priority on skewed books. Execution-protection and funding-attribution specifications remain open. Documentation only; not implementation or deployment authorization.  
**Author:** Astra moderator, consolidating two bounded rounds with the same four researcher sessions.  
**Scope:** `contracts/protocols/dexes/uniswap/v4/`, its quotes, affected consumers and production-path tests. No other SE family refactor or deployment/migration authorization.

## 1. User outcome

After activation, a user repeatedly depositing either pool token should not have to supply the opposite token before their deposit can become productive full-range liquidity. When PoolManager interaction is available, the vault should perform a bounded composition swap when necessary, retain its policy sleeve, and deploy the appropriate remainder. When interaction is blocked, the existing sleeve-only route must remain available.

This is a change to previous product law, not merely a missing call: the old specifications deliberately prohibit rebalance swaps and accept one-sided leftovers.

**Owner decisions, follow-up:** fix the existing single-token `exchangeIn` route; swap only current-call inputs; target a sleeve equal to **20% of this vault's owned deployed reserve**, not external pool reserves. This explicitly replaces the earlier draft's percentage-of-combined-vault-assets policy. Keep public rebalance add/remove-only; arbitrary incumbent inventory is not authorized swap input. Historical one-sided inventory is not guaranteed to clear.

**Owner-approved sequence and skew policy:** swap the current input into a basket proportional to the post-swap incumbent owned book, determine placement, deploy/withdraw as needed for the fee-oracle sleeve policy, and mint shares last against deployed backing plus sleeve. Use the existing proportional equation with the accounting conditions below. **Proportional ownership takes precedence over forcing deployment when the book is skewed.** Retain and disclose material placement residuals rather than deliberately donating caller surplus to incumbents or swapping incumbent inventory.

### 1.1 Accepted decision register

| ID | Owner-approved decision |
|---|---|
| PZ-1 | Fix the existing `exchangeIn` route; an opt-in-only replacement is not the solution |
| PZ-2 | Swap only attributable current-call inputs; do not use incumbent sleeve, donations or deployed principal as swap input |
| PZ-3 | Live Vault Fee Oracle percentage applies to this vault's owned deployed principal, with literal default `0.20e18`; target `F = pD`, equivalently `F* = T*p/(1e18+p)` |
| PZ-4 | Execute composition → sleeve/deployed allocation → mint last; adding/removing liquidity for allocation is permitted |
| PZ-5 | Compose against the post-swap incumbent whole-book ratio; use existing dual proportional min-ratio issuance with explicit rounding and attribution |
| PZ-6 | Credit the caller's entire net contribution, including retained sleeve; incumbent LP repricing and earned fees are not new caller principal |
| PZ-7 | On skewed books, prioritize proportional ownership over forced deployment; accept and disclose material residuals rather than silently donating surplus or selecting a different issuance formula |
| PZ-8 | Preserve blocked sleeve-only operations, dual-funded activation, full-range backing, native/WETH behavior and swap-free public rebalance; no automatic historical-inventory trading |

These decisions record the owner's latest acceptance of the moderator's recommendation. They do not select a swap-bound source, hook-support matrix, pretransfer-provenance mechanism or numerical solver; those remain specification work under §§7, 9–10.

## 2. Observed cause and evidence

Paths abbreviated below as `V4/` mean `contracts/protocols/dexes/uniswap/v4/`.

| Observed fact | Evidence in current checkout |
|---|---|
| A single-token deposit calculates shares from total reserves, mints, then invokes rebalance when interaction is available; it does not perform a composition swap | `V4/UniswapV4StandardExchangeInBase.sol:273–315` |
| Per-token deployable budgets are free balances minus each token's target; rebalance only adds/removes liquidity | `V4/UniswapV4StandardExchangeCommon.sol:751–805` |
| A zero-liquidity plan simply returns without deploying | `V4/UniswapV4StandardExchangeCommon.sol:822–858` |
| Current issuance distinguishes empty-supply geometric-mean issuance, dual min-ratio issuance, and subsequent single-sided invariant growth | `V4/UniswapV4StandardExchangeCommon.sol:685–712` |
| The helper called “best effort” does not catch arbitrary downstream reverts | `V4/UniswapV4StandardExchangeCommon.sol:730–739` |
| Current imports collect actual delivered assets and convert to managed full-range backing | `V4/UniswapV4StandardExchangePositionImportTarget.sol:77–94` |
| Existing sleeve assertions permit much more than the nominal deadband | `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_LocalLiquidBuffer.t.sol:492–514`: additional 25%/50% of total plus dust |

**Inference from the liquidity math:** in-range liquidity takes the limiting contribution of the two tokens. If the opposite token has no deployable excess, incoming unilateral excess cannot increase liquidity. Repeating the same deposit does not cure this structural imbalance.

Example of **old behavior**, ignoring fees/rounding and at a matching pool ratio: total `(100,100)`, deployed `(80,80)`, free `(20,20)`, target 20% of combined vault assets. A deposit of 10 token0 leaves free `(30,20)` and targets `(22,20)`. Budgets are `(8,0)`: no additional in-range liquidity. The reserve is accounted for, but it remains idle. This example is diagnostic, not the revised denominator policy.

## 3. Authority and supersession

Current authority is `CLAUDE.md` and `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:1153–1161,1270–1272` (D57–D59, §24.7.1, A34–A36). Preserve full-range ordinary/imported backing, actual dual-funded activation, subsequent single-token deposits, complete-book accounting and funded lock-safe operations. Do not resurrect historical single-token bootstrap, narrow imported backing, sum-of-assets issuance or native exclusion.

The owner follow-up governs this revision's recorded decisions. Co-located PRDs remain unedited in this research task. A separately authorized documentation/implementation task must reconcile these clauses without silently applying the V4-specific denominator change to other oracle consumers:

| Earlier rule | Change under accepted product direction |
|---|---|
| Local liquid-buffer D17, §5.2, target computations and 100%-liquid narrative | Owner supersedes total-based policy with `F = pD`; retain literal default `p = 0.20e18`; `p = 1e18` now means equal free/deployed, not all-liquid |
| Local liquid-buffer D27, §6.2 | Idle composition belongs to the deposit route and precedes final issuance; retain sleeve-first custody, not unconditional mint-before-swap |
| Local liquid-buffer D24 | User previews include composition effects on credited shares; pure later placement may remain excluded where demonstrably economically neutral |
| Local liquid-buffer D28 | Clarify a bounded user deposit-composition exception; public/tail inventory rebalance remains swap-free |
| Local liquid-buffer D10/D11/D13 | Reconcile ordering and economic attribution; required composition failure is not a silently successful uncomposed deposit |
| Full-range D32 and related leftover narrative | One-sided idle deposits must compose when required and feasible; only explicitly permitted dust/policy residuals remain |
| Multi D45/D47 | No new Multi composition swap; existing exactly-two-token join/exit law remains |

D59 dual activation stays unchanged. Existing single-token routes must still reject one-sided activation atomically, even if an external pool could supply the missing token through a swap.

## 4. Terminology and sleeve definition

- **Interaction available:** PoolManager is idle, called “locked” by V4; the vault may initiate `unlock`.
- **Interaction blocked:** PoolManager is already in an unlock session; do not initiate nested `unlock` or join another caller's settlement.
- **LP placement ratio:** exact amounts required by the existing full-range position at the actual post-swap price. Not raw 50/50 token units.
- **Proportional ownership ratio:** the incumbent whole-book token ratio after the caller's swap, excluding the caller's actual contribution. This may differ from the LP placement ratio when sleeve inventory is skewed. Owner-approved composition targets this ownership ratio; see §6 for the accepted residual trade-off.
- **Ownership book:** exact deployed token amounts plus held tokens plus earned fees counted once. A composition ratio is not an issuance valuation formula.

Read the live fee-oracle WAD parameter `p`, retaining the owner's literal default **`0.20e18`**. For each token define:

```text
D_i = this vault's deployed position principal at the current price
F_i = actually held, spendable local inventory
E_i = earned but uncollected position fees
ownershipBook_i = D_i + F_i + E_i
placeableTotal_i = T_i = D_i + F_i

desired steady state: F_i = p * D_i / 1e18
placement target: targetFree_i = floor(T_i * p / (1e18 + p))
```

The policy denominator is **vault-owned deployed principal**, never total pool liquidity. The equivalent combined-inventory fraction is `p/(1+p)`: at 20%, free is one-sixth of `D+F`. Do not freeze the target at `p * deployedBeforePlacement`: placement itself changes that denominator. For example, `D=100, F=40, p=.2` requires deploying `16⅔`, ending at `D=116⅔, F=23⅓`, not deploying 20 and leaving free at 20.

Recommended fee treatment: collect fees before idle planning where possible. Fee collection converts `E` to `F` once; it is not a gain in the ownership book. Newly uncollected fees remain in share valuation but are not spendable sleeve cover or deployed principal. Reconcile newly collected fees before final placement targets; do not count `E` in placeable `T` before collection.

**Endpoints:** resolved `p=0` targets zero sleeve, but stored oracle zero remains “unset/fallthrough.” `p=1e18` targets equal free and deployed, or half combined inventory. There is no all-liquid setting in the existing bounded parameter range under this interpretation; do not retain the old 100%-liquid exception or invent a sentinel. No change to `0.25e18` is authorized to preserve the prior 20%-of-total headroom.

**V4-local compatibility impact:** preserve the oracle field, cascade and stored units; change this family's interpretation, all placement/transition projections, tests, NatSpec and consumer labels together. Do not change staking-SE or other-family semantics. Current `actualLiquidReservePercentage` reports free/total (`V4/UniswapV4StandardExchangeLiquidReserveTarget.sol:69–81`); that is no longer directly comparable to policy `p`. The implementation specification must explicitly retain/relabel that ratio or expose a deployed-relative ratio with defined zero-deployed behavior. Never divide by zero or mislabel an all-free book as on-target. Release documentation must disclose changed meaning of existing V4 settings; no live-instance migration is authorized here.

Preserve the policy deadband: `max(10^max(0, decimals_i - 6), targetFree_i * 5%)`. Tests must not quietly widen it by a large fraction of total inventory.

## 5. Functional requirements

### ZR-1 — Routing and compatibility

**Owner resolved:** modify idle single-token pool-token-to-share `exchangeIn` behavior while preserving its selector and the blocked branch. Direct token-to-token swaps, Multi joins/exits, import activation and withdrawals retain their route economics; their shared V4 sleeve-placement helpers must use the new denominator consistently.

An additive opt-in zap selector is not the selected solution. Do not silently add mandatory arguments to the existing ABI; specify how composition bounds are enforced within the selected existing-route interface and approved policy.

### ZR-2 — Idle deposit

1. Validate route, funding, authorization, recipient, deadline and user limits through the existing security model.
2. Establish a consistent incumbent-book snapshot and actual current-call contribution. Fees, donations, pretransfers and callback-time transfers must not masquerade as newly supplied principal.
3. Determine the composition required by the selected ownership-ratio policy. Sufficient old counter-token inventory is not permission to credit that inventory to the caller. A no-swap shortcut must preserve the same approved economic result, not silently choose a different issuance branch.
4. Compose only an attributable portion of the current deposit through the bound pool and with approved bounds. Required target: current-call basket proportional to the **post-swap incumbent ownership book**, not pool-wide reserves. Solving must account for the swap changing this vault's own LP amounts and fees. Do not trade old sleeve/donations or liquidate incumbent positions to enlarge the swap input budget.
5. Measure actual fills and post-swap backing, then add/remove liquidity toward `targetFree = T*p/(1e18+p)`. Holding the contribution in the sleeve is valid when policy requires it. Removing incumbent liquidity to refill the sleeve is allowed placement, not permission to swap incumbent assets. Avoid unnecessary deploy-then-immediate-withdraw churn; no tick recast.
6. Reconcile contribution, incumbent backing, fees and placement effects; calculate proportional shares under §6, enforce `minSharesOut` and mint last. The caller receives ownership credit for their **entire net basket**, including the portion retained in the sleeve.

One unlock containing swap and liquidity addition is a preferred engineering direction, not a required unverified helper composition. Authenticate callbacks and settle all currency deltas. An implementation specification must explain ordering of fee collection, snapshots, settlement, share calculation and liquidity addition.

For a post-swap book and contribution aligned with the LP ratio, sufficient depth, supported hooks and non-dust input, successful placement must reach policy within explicit rounding tolerance. When net deployment is feasible, assert positive liquidity growth; a genuinely underfilled sleeve can instead retain input or require liquidity removal. A swap's price movement can itself change alignment, so small-deposit tests cannot assume pre-swap alignment remains exact afterward. Skewed-book fixtures must assert the constrained feasible placement and disclose material residuals; current-call-only composition cannot promise global repair.

### ZR-3 — Blocked operations

Existing `exchangeIn` accepts funded post-activation input into the sleeve and mints using the existing blocked-route economics. It does not swap, modify liquidity or initiate unlock. Existing withdrawals pay only when every requested token is sufficiently funded locally; otherwise they revert. No promise of unlimited output liquidity is added.

### ZR-4 — Failure and exceptions

Required composition, slippage, funding, settlement or supported-hook validation failure must revert the transaction atomically. Do not report a successful composed zap after silently skipping a failed swap.

Specify any allowed no-composition cases explicitly, including approved dust behavior or a demonstrated economically equivalent route. These are not swap failures. The prior all-liquid exception is removed: `p=1e18` now means half of combined inventory held free. Holding an otherwise valid deposit to refill the sleeve is successful allocation, not a failed deployment.

Partial fills may only succeed if actual amounts meet the same issuance, sleeve and deployment requirements; otherwise revert. Mandatory deployment failure is not excused by a helper named “best effort.” Pure optional housekeeping must have separately specified soft-failure semantics.

### ZR-5 — Backlog and public rebalance

Public `rebalanceLiquidReserve` remains idle-only and add/remove-only. Ordinary tail rebalance may place eligible inventory, but no unrestricted trading of incumbent free inventory is authorized. Blocked deposits and donations can therefore remain imbalanced until counter-token inventory arrives or a separately approved repair mechanism is introduced.

Do not claim this narrow release restores every arbitrary historical book to `F/D=20%` in both currencies. If whole-book recovery is required, specify who pays its trading costs, independent price protection, trigger authority and liveness before broadening scope.

### ZR-6 — Native currency and imports

Preserve the current WETH ERC20 face, PoolKey ordering, callback settlement unwrap and native-take rewrap. Do not add a payable ETH deposit interface. Current imported launches convert to full-range managed backing; do not add special narrow/out-of-range imported-position zap rules based on superseded documents.

## 6. Proportional issuance — existing equation, precise attribution

**Answer to the owner's proposed simplification: yes.** Placement does not need a new valuation policy. Shares represent the caller's contribution to combined deployed-plus-held backing, including earned fees counted once. Use the existing dual proportional equation when composition is aligned to that book; minting last is compatible with it.

Let `S` be pre-mint supply, `C_i` the entire actual caller basket after swap costs, and `A_i` the measured post-swap ownership book. Define incumbent backing `B_i = A_i - C_i`. `B` includes incumbent LP repricing and earned fees, not just the call-start token amounts.

For positive `B0`, `B1`, the existing branch in `V4/UniswapV4StandardExchangeCommon.sol:700–704` is:

```text
m = min(floor(S * C0 / B0), floor(S * C1 / B1))
```

If `C0/B0 = C1/B1 = a`, this issues approximately `a*S` shares with only integer rounding. Incumbents retain their prior post-trade token entitlements because for each token:

```text
S * (B_i + C_i) / (S + m) >= B_i
```

The inequality is an issuance property relative to **post-trade B**, not protection from the swap's market effects. Without proportional alignment, the min-ratio formula conservatively benefits incumbents by leaving some caller contribution uncompensated. That is not a universally neutral result.

### 6.1 Measurement and conservation

- Measure actual current-call principal and swap deltas; do not infer caller principal from aggregate reserve growth. Self-LP fees and repricing are incumbent effects.
- Align the swap basket to `B(x)`, the incumbent book resulting from that swap size `x`. A frozen pre-swap denominator generally gives a different result. Quote and execution must use the same definition.
- Keep a conceptual contribution/ownership attribution through placement. Adding/removing liquidity moves assets between D/F; collecting fees moves E/F. None of these movements alone changes ownership.
- `C` includes both deployed and sleeve-retained contribution. Never subtract the caller's sleeve allocation from their share credit.
- Reconcile `final ownership book = attributed incumbent book + attributed caller contribution`, with costs, rounding, intervening fees and donations explicitly accounted for. Callback-induced trades can change the book again; unsupported effects must fail closed or be correctly modeled before issuance. Do not assume placement is always neutral merely because it occurs in one transaction.
- Existing share math includes E (`Common.sol:619–643`), whereas local cover uses actual balances. Do not conflate those quantities.
- Zero-reserve states, insufficient depth and rounding-to-zero require defined handling; the positive-reserve formula must not divide by zero or silently use invariant growth as a fallback for composed dual input.
- Preserve dual bootstrap and existing blocked-route issuance. This is not a new one-token NAV or DETF formula.

**Funding evidence gap:** `_secureTokenTransfer` uses a measured pull delta for `pretransferred=false`, but `pretransferred=true` checks the claimed amount against unbooked face balances (`Common.sol:1270–1288`), not source identity. A prior unbooked donation can satisfy that local check. End-to-end exploitability was not tested. The implementation specification must resolve attribution for legitimate push-based consumers without letting arbitrary old donations become “current-call” swap budgets. Do not silently remove the pretransfer ABI or claim its provenance is already proven.

### 6.2 Worked aligned example

At actual post-swap state, suppose incumbent backing is `(120,120)`, supply is 120, and the caller's net basket is `(12,12)`. Shares minted are 12. Final per-token total is 132; at `p=.2`, place 110 and retain 22. Existing holders retain 120 token units per side in aggregate, and the new shares represent 12 per side. These are post-fill quantities; the example does not assert a zero-fee or zero-impact swap.

### 6.3 Skewed-book limitation and accepted policy

Suppose actual post-swap incumbent backing is `(200,100)`, supply 100, and the LP placement ratio is 1:1. A book-aligned basket `(20,10)` mints 10 shares neutrally. Final totals are `(220,110)`. At `p=.2`, the scarce side can support only `91⅔` deployed per token with `18⅓` free. Free token0 is then `128⅓`—material surplus, not dust. Add/remove alone cannot fix this ratio.

Conversely, an LP-aligned basket `(10,10)` against incumbent `(200,100)` mints only 5 shares under min-ratio. The surplus token1 benefits incumbents. Extending invariant-growth issuance to such composed dual baskets would credit imbalance differently (approximately 7.47 shares here) and change token-specific entitlement economics; it is not an automatic fallback authorized by this PRD.

**Resolved by owner:** compose to the post-swap owned-book ratio and retain existing proportional issuance; accept and disclose material placement residual where the whole book is skewed. Current-call-only swaps cannot simultaneously guarantee neutral proportional issuance, full productive deployment and exact per-token sleeve policy for every skewed book. Proportional ownership takes precedence. Do not choose LP alignment plus deliberate surplus donation or substitute an imbalance formula to force deployment. Integer alignment/rounding tolerances must be specified and tested; they are not permission for material uncompensated caller surplus.

The earlier broad formula blocker and skew-policy decision are resolved. Remaining specification work is precise attribution, a bounded solver and rounding tolerance, residual reporting, pretransfer handling and execution protection—not inventing a new NAV or reopening the accepted ownership priority.

## 7. Quotes and trading protection

- Update ordinary preview, transition-inventory projections and affected SE/SY consumer quotes to the selected composed route and approved issuance equation.
- Use hook-adjusted actual semantics. Unsupported or non-projectable hook behavior must not silently receive a vanilla-pool guarantee; define a supported set or fail-closed behavior.
- For identical state and supported deterministic hooks, verify quote/execution parity within explicit integer-rounding tolerances. State changes between quote and execution remain protected by user limits.
- Require final share minimum and deadline plus meaningful composition swap bounds. Near-global tick limits are not adequate price protection.
- Choose the source and units of bounds before implementation: user-specified limits, incremental impact bounds, and an independent-reference deviation gate protect different things. A cap relative to manipulated spot does not establish fair price.
- The presence of a TWAP accessor does not prove oracle robustness. DETF mandatory price-gate law does not independently mandate TWAP gating on this SE. Any selected reference needs freshness, manipulation and availability requirements.
- Existing direct-swap helpers may transfer output away and rebalance; they are not approved as drop-in internal zap primitives.

## 8. Acceptance matrix

Use real vault diamonds, fee oracle, registry/manager and PoolManager through existing production TestBases. No mock SUT. This document requests future evidence; no tests were run by the council.

| ID | Required acceptance evidence |
|---|---|
| ZA-1 | Repeated unilateral idle deposits deploy when feasible, preserve neutral proportional credit and demonstrate both feasible strict-policy and material-residual cases; no unconditional post-swap alignment assumption |
| ZA-2 | Composition aligns caller basket to post-swap incumbent ownership ratio; placement uses exact CL ratio. No-swap shortcuts prove equivalent economics rather than consuming incumbent counter-token as caller credit |
| ZA-3 | Blocked deposits mint without PM mutation or nested unlock; generic unlock harness and at least one real buffer-hook integration |
| ZA-4 | Requested-token sleeve cover pays; short or wrong-token-only sleeve reverts atomically |
| ZA-5 | One-sided activation still rejects; dual activation and imported full-range conversion remain valid |
| ZA-6 | Swap-input attribution cannot consume old sleeve/donations; backlog remains explicitly visible; public rebalance does not swap |
| ZA-7 | Fee ownership, incumbent book, deposit contribution, issued shares and resulting withdrawals reconcile under independent reference calculations |
| ZA-8 | Ordinary/transition/SY quotes agree with execution and reflect composition fees, actual fills and chosen limits |
| ZA-9 | Slippage breach, price-limit hit, insufficient depth, unsupported hook and failed add roll back principal, shares and PM effects |
| ZA-10 | Dynamic/hook fees, callback reentrancy across all exposed facets, unsolicited callback transfers and pretransfer replay cannot steal or misattribute inventory |
| ZA-11 | Mixed 6/9/18 decimals, extreme prices, varied tick spacing, tiny amounts, rounding boundaries and large inputs remain bounded and safe |
| ZA-12 | Native currency0/WETH with non-address-sorted ERC20 faces settles correctly and leaves sleeve custody in WETH |
| ZA-13 | `F*=T*p/(1e18+p)`, live cascade, stored-zero fallthrough, effective-zero target, `p=1` half-total endpoint, fee collection, public rebalance and ratio reporting agree; other families remain unchanged |
| ZA-14 | Multi/direct-swap/withdrawal/import behavior and package selectors do not regress; current full-range ticks remain unchanged |
| ZA-15 | Solver iterations/gas are bounded; actual deployed liquidity and per-token sleeve are independently measured, not inferred from shares > 0 |
| ZA-16 | Reproduce `D=100,F=40,p=.2` fixed-point example; do not target stale `pD_pre`; strict final ratio where feasible and explicit constrained residual otherwise |
| ZA-17 | Caller sleeve receives full ownership credit; own-LP swap repricing/fees are not minted to caller as principal; post-swap denominator differs correctly from pre-swap under meaningful price impact |
| ZA-18 | Honest pretransfer integrations remain supported under a specified funding-attribution policy; unbooked donations, replay and callback transfers cannot be silently treated as proven current-call delivery |
| ZA-19 | Skewed-book regression confirms proportional ownership takes priority: retain/disclose material residual, do not switch to LP-ratio composition with material uncompensated surplus or silently select invariant-growth dual issuance |

No APR guarantee follows from greater deployment. Fees, price impact, adverse selection and inventory risk remain.

## 9. Decision status and remaining specification checkpoint

| Gate | Recommendation / unresolved choice |
|---|---|
| G1 — surface | **Resolved by owner:** fix existing `exchangeIn` |
| G2 — inventory scope | **Resolved by owner:** swap only current-call inputs; adding/removing incumbent liquidity for sleeve allocation remains permitted |
| G3 — denominator | **Resolved by owner:** literal 20% of vault-owned deployed reserve; keep `0.20e18`, not `0.25e18`; V4-local interpretation |
| G4 — economics | **Resolved by owner:** swap → allocate → mint last; post-swap book-aligned composition and existing min-ratio issuance; proportional ownership takes precedence over forced deployment, with disclosed material skew residual |
| G5 — bounds | Select bound source, exposed controls and hook support/failure policy; do not invent a TWAP mandate |
| G6 — success/funding | Required composition and feasible allocation succeed or revert. Material skew residual is accepted, not a failed zap. Specify dust/tolerances, residual reporting and legitimate pretransfer attribution; no silent fallback to failed uncomposed zap |

Do not reopen resolved owner decisions to preserve older headroom, add an opt-in-only route or force deployment at the expense of proportional ownership. Remaining protection/funding policy choices require explicit specification and approval where they affect economics or compatibility. This PRD update is not execution authorization, automatic backlog repair, a new oracle, deployment or migration.

## 10. Implementation handoff — not execution authorization

After remaining gates are resolved, a separately authorized planning task should specify the selected existing-formula attribution, solver, bounds, pretransfer handling, affected-surface manifest and implementation/test sequence. Expected touch areas: `InBase`, `InTarget`, execution delegates, `Common` unlock/placement operations, liquid-reserve views and interfaces, quote/query/transition targets, affected SY/UI consumers and V4 settings documentation. No global fee-oracle denominator change or new opt-in-only facet is authorized.

The later implementer must reconcile co-located PRDs, verify current source/dependency revisions, read the repository coding/deployment/testing rules, preserve CREATE3/registry deployment, refresh dependent artifacts before tests, and use current default/fork profiles without via-IR. No existing immutable instance upgrade or in-place migration is implied.

## 11. Council record, corrections and dissent

### Round 1 — preserved historical findings

All four independent originals preceded all peer sharing. Each researcher resumed its original session once and read the other three original reports together as untrusted evidence, never earlier cross-reviews. Exactly eight task calls completed this round. Task metadata matched the requested fixed researchers; this is not independent attestation of provider internals.

| Researcher | Preserved original session | Original position and cross-review outcome |
|---|---|---|
| Astra | `ses_f1efcf6c8ffeBLhwkEcra4KQoz` | Caller-funded user-route composition; issuance equation blocks coding. Retained; corrected imported-range and helper-reuse assumptions |
| Grok | `ses_f1ef76907ffeItWV36OmZ1qKlR` | Change existing route; initially proposed post-swap existing issuance. Withdrew that formula shortcut and out-of-range import treatment |
| MiniMax M3 | `ses_f1eee4279ffe2v8tVKBovEhyCu` | Proposed additive selector/helper reuse and bootstrap extension. Cross-review supports dual bootstrap and swap-inclusive previews; retained erroneous historical imported-tick guidance, rejected here against current code/law |
| Kimi K3 | `ses_f1eea464bffeJ26nT4onUJToP3` | Initially mint-first, socialized swap and skip-on-failure. Withdrew these after review; now requires economic specification and swap-inclusive preview, leans opt-in selector |

**Round-1 agreement:** structural cause, lock-safe sleeve preservation, then-current total-based policy, need for bounded composition, and no unrestricted public-rebalance trading. The owner has since superseded that denominator. Do not treat initial claims of four-way agreement as proof: several originals disagreed or misread current authority.

**Round-1 dissent, now owner-resolved:** existing-route change versus opt-in selector. **Round-1 evidence/design gaps:** issuance, solver correctness, bound/reference selection, supported hook fidelity and complete reentrancy tracing. **Moderator resolution from directly read authority/code:** imported backing is converted to full range; single-token activation remains rejected; current native/WETH support is not excluded.

Artifacts: `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/{astra,grok,minimax,kimi}-original.md` and corresponding `*-cross-review.md`. Originals remain unchanged. MiniMax/Kimi reported using their permitted file-write tools because apply_patch was unavailable in their sessions. Their initial discovery gaps are not evidence that tests do not exist; the moderator directly read the test path cited above.

### Round 2 — owner sequence and denominator clarification

Eight additional synchronous continuations used the same four session IDs: four independent follow-up originals, then four combined reviews of the other three originals. No new researcher sessions, substitutions or cross-review-answer sharing. Originals: same research directory, `{astra,grok,minimax,kimi}-round2-original.md`; reviews: `*-round2-cross-review.md`. All sixteen research artifacts were observed in the directory by the moderator.

| Researcher | Round-2 original | Cross-review correction / final position |
|---|---|---|
| Astra | Supports simple min-ratio formula with post-swap attribution; initially favors LP alignment with disclosed surplus donation | Moves to post-swap book alignment plus disclosed material residue; separates D/F/E and rejects stale target/snapshot shortcuts |
| Grok | Post-swap book-aligned basket, existing min-ratio issuance, literal deployed-relative target | Retains; corrects stale snapshots, caller sleeve subtraction, material-residual and uncollected-fee misconceptions |
| MiniMax M3 | Correct fixed-point algebra but pre-swap issuance denominator, caller sleeve subtraction and historical import/native errors | Retracts 25% recalibration and sleeve subtraction, but final report still inconsistently uses pre-call issuance and a target ratio including raw deposit; those equations are **not adopted** |
| Kimi K3 | Supports book alignment but uses stale pre-swap denominator/`pD_pre`, calls residues dust and recommends 25% recalibration | Retracts those positions; adopts post-swap attribution, actual D/F/E distinction, literal 20%, and material residual disclosure |

**Evidence-grounded synthesis, not unanimous formula endorsement:** Astra, Grok and Kimi finish aligned on post-swap book attribution and the existing proportional formula for aligned baskets. MiniMax's contradictory snapshot algorithm remains unresolved dissent/error and is rejected from this PRD based on actual LP repricing and the conservation equation. Do not quote researcher claims of “all four converge” as proof.

**Confidence:** high in sleeve fixed-point algebra and conditional proportional-share proof; medium in safe implementation of dynamic ratio solving/attribution. No solver convergence, end-to-end pretransfer security, hook coverage or runtime behavior was proved. Missing-file claims in MiniMax's discovery are recorded as local evidence gaps, not evidence that the moderator PRD was absent; it was directly read by moderator and peers. No extra task calls were used to repair or replace a participant.

### Owner acceptance after round 2 — documentation update only

The owner accepted the recommendation and requested that the PRD record the decisions so far. G4 and PZ-5–PZ-7 now record post-swap owned-book alignment, existing proportional issuance and ownership priority with disclosed material residuals. No additional council round was requested or performed for this clerical consolidation. Original reports and all four researcher session IDs remain preserved. Source evidence was not revalidated and no implementation/tests/deployments were performed during this update.

## 12. Sources, versions and limits

- Local line citations were inspected in this checkout on **2026-09-26**; no source commit or deployed-bytecode match was established.
- `foundry.toml:29–36`: Solidity **0.8.35**, optimizer enabled/runs **1**, `via_ir=false`. Compiler configuration is observed; no compiler/test runtime was invoked.
- Astra reports Crane package **0.1.0-public-preview**; exact upstream V4 port commit remains unverified.
- Context7 `/uniswap/v4-core`, consulted first for unlock/settlement API claims on **2026-09-26**.
- Primary upstream source fetched **2026-09-26**: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol — `unlock`, `swap`, `modifyLiquidity`, settlement and delta checks; source pragma **0.8.26**. This moving `main` source is not a version pin or proof of local port equivalence.
- Researcher primary liquidity source, accessed **2026-09-26**: https://raw.githubusercontent.com/Uniswap/v4-periphery/main/src/libraries/LiquidityAmounts.sol . Local library path: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:56–76`.
- Canonical V4 liquidity/flash-accounting skills were read directly. Illustrative skill snippets are not production code or authority to override current source/API behavior.

**Confidence:** high in the identified cause and current product constraints; medium in the proposed architecture; unproven in the exact issuance economics and solver until the gated specification and independent validation exist. Council agreement and future passing tests are not proof of security or economic soundness.
