# PRD: Uniswap V4 Standard Exchange — Proportional Zap-In, Liquid Sleeve and Iterative Rebalancing

**Date:** 2026-09-26  
**Updated:** 2026-09-27 — owner assigns matrix, accounting, component/reuse mapping, acceptance tests and removal manifest to the council; accepts Pons documentation/graduated-pool evidence and directs deprecation of old code-linked PRDs.  
**Status:** Owner-approved product direction; council-authored engineering specification in [the implementation and test plan](UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md). Equations and implementation remain subject to the specified tests; no execution is claimed.  
**Scope:** Separate `UniswapV4FullSpreadHooklessStandardExchangeVault` and `UniswapV4FullSpreadPonsFamilyHook` implementations under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/` and `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/`, respectively; affected quotes, accounting, rebalance behavior and tests. Existing FullSpread code is the implementation baseline, not a shared Hookless/Pons dispatcher.  
**Authorization:** Requirements and future implementation scope only. This research/documentation task does not execute implementation, testing or file deletion. The owner-approved future implementation effort includes the gated legacy removal in §3.1; no deployment, live registry action or migration is implied.

## 1. Purpose

The vault must support productive single-token deposits without waiting for another user to supply the opposite token.

When PoolManager interaction is available, the existing deposit route must:

1. Receive or credit the caller's input.
2. Swap an appropriate portion into a proportional basket.
3. Allocate inventory between deployed liquidity and the local sleeve.
4. Mint vault shares against the caller's contribution to the complete owned book.

The public rebalance function must also support incremental repair of imbalanced vault inventory through bounded swaps and liquidity operations.

The liquidity sleeve exists to facilitate funded operations while PoolManager interaction is blocked. It is **not** intended to prevent the vault's normal trading from moving market prices.

## 2. Accepted decisions

| ID | Requirement |
|---|---|
| D1 | Fix the existing `exchangeIn` route; do not substitute an opt-in-only zap interface. |
| D2 | Deposit-composition swaps use only the input credited to that call. |
| D3 | The sleeve target is the live Vault Fee Oracle percentage of **this vault's owned deployed principal**, with a default of 20%. |
| D4 | Deposit ordering is composition swap, then allocation, then share mint. |
| D5 | Compose the caller's basket against the **post-swap incumbent whole-book ratio**. |
| D6 | Use existing proportional dual-token share issuance, with explicit rounding and contribution attribution. |
| D7 | Credit the caller's entire net contribution, including the portion retained in the sleeve. |
| D8 | Proportional ownership takes precedence over forced deployment within the deposit route. Retain and disclose placement residuals. |
| D9 | Public rebalance may swap vault-owned imbalanced inventory and add or remove liquidity. |
| D10 | Successive rebalance calls may execute immediately, including within the same transaction or block. |
| D11 | Do not impose cooldowns, per-block quotas, time-window budgets, cumulative price-travel limits, or turnover or campaign caps. |
| D12 | Once both proportionality and sleeve thresholds are satisfied, public rebalance performs no rebalance trades. |
| D13 | Continue direct PoolManager integration for the managed position. |
| D14 | **Superseded admission policy:** Standard Exchange packages target explicit hook integrations, or no hook. Each package enforces its fixed expected hook identity at instance creation. Generic arbitrary-hook admission based solely on deployer assurance is not supported by the new packages. This is not a mutable administrator-controlled hook list. |
| D15 | Preserve source-agnostic reserve-delta pretransfer law and the existing contract-caller restriction. |
| D16 | Every successful balance-changing workflow fully books all expected locally held balances, including residuals and dust. |
| D17 | **Supersedes the blanket exact-output prohibition:** support an exact-output operation when an applicable closed-form equation exists. Inspect the existing Crane math and FullSpread implementation for that equation; do not reject all exact-output branches merely because an earlier combined candidate was not adopted. |
| D18 | Interleave rebalancing when an applicable closed-form quotation for the operation **including rebalancing** exists. An input-only inverse followed by numerically solved repair is not such a formula. |
| D19 | If no applicable combined closed-form quotation exists and requiring interleaving would eliminate a specific token route in **both exact-in and exact-out modes**, forgo interleaved rebalancing on that specific route. This exception does not create a missing exact-output equation: an exact-output branch without its own applicable closed form remains `InvalidRoute`. Keep previews and availability consistent with the selected behavior. |
| D20 | Enforce 25 bp public-rebalance terminal price impact, 50 bp deposit-composition terminal price impact, and 10 bp execution shortfall versus a fee-inclusive quote. These owner-approved values are requirements, not provisional calibration defaults. The accepted alignment/share-flooring loss bound remains 1 bp. |
| D21 | Public maintenance targets the existing position's token requirements at the current pool price using exact finite-range position math. Sufficient proportionality means normalized composition mismatch of at most 1 bp, separately from depositor alignment/share-flooring loss. Preserve the sleeve deadband, prefer placement without swaps when sufficient, permit safe incremental progress, and stop trades when both thresholds pass. |
| D22 | Use separate hookless and Pons Family V2 Standard Exchange implementations, not merely separate admission packages around shared Hookless/Pons logic. Hookless components use prefix `UniswapV4FullSpreadHooklessStandardExchangeVault` in `v4/fullSpread/hookless/`; Pons components use prefix `UniswapV4FullSpreadPonsFamilyHook` in `v4/fullSpread/ponsFamilyV2Hook/`. Family-specific validation, fees, quotes and execution remain separated. Future hook packages may reuse a compatible implementation, but that does not authorize merging these two families. |
| D23 | The production PoolManager is the canonical Robinhood mainnet manager from `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` in `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`. The Pons reference implementation is `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/`. Do not infer compatibility with another Pons generation from a family name or ABI. |
| D24 | Deprecation and source removal of both legacy V4 vault implementations belong to this effort. Remove the legacy vaults only after both new families are implemented, tested and considered ready for security-audit submission. Preserve the new `v4/fullSpread/hookless/` and `v4/fullSpread/ponsFamilyV2Hook/` trees. Follow the exact boundaries and readiness gate in §3.1; audit completion is not the deletion trigger. |
| D25 | Implement the approved execution-protection limits as fixed constants in each implementation, with no setter or new administrative tuning privilege. The live fee-oracle sleeve percentage remains separate and unchanged by this decision. |
| D26 | Fix the expected Pons Family V2 hook address in the Pons package to `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` (`0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044` on chain 4663). It is the current-stack singleton, not a per-pool hook, an instance-deployer-selected hook, or a mutable runtime list. Reject pools whose hook differs from that package binding. Do not treat this constant as the hook of every historical pons token. |
| D27 | The council defines the route/formula matrix and detailed accounting from the approved requirements and existing implementations. Favor source-supported Astra/Grok equation analysis; mathematical correctness is not established by a vote. Tests validate the selected equations. These are not unresolved owner questionnaires. |
| D28 | The council enumerates both family component sets and permitted hook-independent reuse from Hookless into Pons. D22's prohibition on shared family-specific fee, quote and execution dispatch remains in force. |
| D29 | Official Pons documentation plus validation that graduated pools use the hook are sufficient accepted integration evidence. Use the address already defined by D26. Additional deployed-runtime/local-bytecode equivalence is not a planning or release gate, and equivalence is not claimed. Normal identity, registration, funding, fee, callback and execution checks remain required. |
| D30 | The council specifies acceptance criteria and tests. At identical state, modeled previews must match execution; equivalent in-kind operations exposed through different interfaces must agree in assets, shares, accounting and rounding. A runtime shortfall tolerance is not permission for deterministic preview mismatch. |
| D31 | The council defines the finite legacy-removal manifest. Old PRDs tied to the deprecated code are deprecated, not reconciled into new product law. Preserve historical provenance and unrelated/shared product law; source removal remains gated by D24 and §3.1. |

Earlier council recommendations for pretransfer provenance, mandatory pull-only funding, mutable discretionary hook lists, and cumulative or time-based repair budgets are withdrawn. The owner's later hook-specific package direction supersedes the former arbitrary-hook/deployer-assurance admission policy; see D14, D22 and §10.

## 3. Preserved requirements

This change preserves:

- Actual dual-token funding for initial activation.
- Full-range ordinary and converted imported backing.
- Subsequent single-token deposits.
- Native-currency and WETH interface and settlement behavior.
- PoolKey token ordering.
- Complete-book accounting, with fees counted once.
- Funded sleeve-only operations while PoolManager interaction is blocked.
- Existing route authorization, recipient, deadline, and minimum-output requirements.

It does not authorize a new single-token bootstrap mechanism, arbitrary tick recasting, a new one-token net-asset-value policy, or an in-place migration of existing instances.

The owner selected the **new FullSpread V4 implementation** as the baseline and subsequently required two separate implementations at the scope paths above. Both the older protocol-tree vault and the unsegmented FullSpread vault are legacy implementations to be deprecated and removed **within this effort**, after the readiness gate below. They remain available as development/comparison baselines until that gate is met. Source removal does not deactivate, upgrade or migrate existing on-chain instances and does not authorize live registry actions or deployment.

### 3.1 Gated legacy deprecation and source removal

The implementation plan must include a final legacy-removal work package with these boundaries:

| Location | Disposition after readiness gate |
|---|---|
| `contracts/protocols/dexes/uniswap/v4/` | Remove the legacy V4 vault implementation and its obsolete vault-specific components. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/` | Remove the legacy unsegmented V4 vault implementation and its obsolete vault-specific components, **excluding the two retained subtrees below**. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/` | Retain the complete new hookless family. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/` | Retain the complete new Pons Family V2 hook family. |

**Readiness gate:** both replacement families must be implemented and tested, with the applicable PRD acceptance criteria satisfied and a recorded determination that the replacements are ready to submit for a security audit. Record the source revision, executed validation evidence and readiness checklist before removal. Do not delete a legacy implementation while its replacement remains incomplete. Readiness for audit is neither audit completion nor a security guarantee.

**Removal and final validation:**

1. Inventory the legacy files and all references before deletion. The two new family subtrees are explicit exclusions; never treat their parent as an unconditional recursive-deletion target.
2. Rehome any still-required generic dependency through a planned, reviewed change before removing its legacy location. Update affected imports, FactoryServices, artifact identifiers, test fixtures, deployment/discovery source references and maintained documentation. Do not leave active consumers dependent on deleted vault types or stale build artifacts.
3. Preserve historical source/provenance evidence in version control and durable records, and retain relevant comparative findings. Port required regression coverage to the replacement families rather than discarding the security/accounting assertions with the old fixtures. Historical references must identify the preserved revision instead of implying the old source remains present.
4. Remove the inventoried legacy vault components once the gate is met, then rebuild the affected runtime artifacts and rerun the required replacement/consumer suites. The security-audit submission must reference the final post-removal source revision and its validation results, not only the pre-removal checkout.
5. Do not expand removal to V3, shared math outside these legacy locations, Crane's Uniswap V4 core/adapters, the Pons reference tree, or either new family. Non-vault files encountered in the listed directories require explicit inventory/disposition; the request to remove old vaults is not a blind deletion of unrelated content.

D24 supersedes older source-preservation requirements **for this gated removal only**. Before the gate, retain the legacy baselines; afterward, historical preservation means recorded revisions/evidence, not keeping obsolete implementations in the active source tree. The route/formula inventory in §6.4 must be completed as part of replacement readiness; an open-ended search for novel closed forms or a completed security audit is not a prerequisite for removal. This document records the future work; the research council does not execute deletion.

Current release authority remains `CLAUDE.md` and `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` D57–D59 and §24.7.1. Pretransfer authority remains `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`. Under D31, the six code-linked historical documents enumerated in [the removal/deprecation manifest](UNISWAP_V4_FULLSPREAD_REMOVAL_MANIFEST.md) are deprecated as current V4 product law. They remain historical evidence, not a reconciliation workstream. This research task records deprecation here and in the manifest; it does not edit or remove documents outside the council's permitted document roots. Preserve unrelated V3/shared requirements.

## 4. PoolManager interaction states

Uniswap's terminology must be stated precisely:

| State | Meaning | Vault behavior |
|---|---|---|
| PoolManager idle; protocol "locked" | The vault may open its own unlock session | Swaps and liquidity operations may execute |
| PoolManager already in-session; protocol "unlocked" | Nested unlock is unavailable | Use the funded local sleeve; do not initiate nested unlock |

Blocked deposits retain the existing sleeve-only behavior.

Blocked withdrawals succeed only if the requested currency balances are sufficiently funded locally. Otherwise, they revert atomically. The sleeve does not promise unlimited withdrawal liquidity.

## 5. Sleeve policy

For each token, define:

- `D`: vault-owned deployed principal, calculated using exact position math.
- `F`: actually held, spendable local inventory.
- `E`: earned but uncollected fees.
- `T = D + F`: currently placeable inventory.

Share backing is:

```text
ownershipBook = D + F + E
```

The policy is:

```text
F = p * D
```

With the oracle parameter expressed in WAD units:

```text
targetFree = floor(T * p / (1e18 + p))
```

At the default `p = 0.20e18`, 120 units of combined inventory correspond to 100 deployed and 20 held locally.

This is **20% of owned deployed principal**, not 20% of combined vault assets and not a fraction of total pool liquidity.

### Policy details

- Read the effective oracle percentage live.
- Preserve stored-zero fallthrough semantics.
- An effective zero targets zero sleeve.
- `p = 1e18` means equal free and deployed amounts, not an all-liquid vault.
- Do not change the default to 25% to preserve the former percentage-of-total behavior.
- Preserve the existing sleeve deadband: the maximum of the absolute token floor and 5% of `targetFree`.

Uncollected fees remain in share backing but are not spendable sleeve cover. Collection moves fees from `E` into `F` once; it does not create an accounting gain.

Do not freeze the placement target at `p` times deployed principal before placement. Placement itself changes that denominator. For example, deployed 100 and free 40 at 20% requires deploying `16 2/3`, ending at deployed `116 2/3` and free `23 1/3`.

## 6. Existing deposit route

### 6.1 Funding

Establish current-call credit before internal fee collection or snapshot updates:

- `pretransferred = false`: credit the measured pull delta.
- `pretransferred = true`: credit exactly the declared amount, provided it does not exceed the unbooked local balance and the caller satisfies the shared caller restriction.

Valid pretransfer credit may originate from any unbooked surplus. Original ownership or transfer provenance is not required.

### 6.2 Composition and placement

When interaction is available:

1. Establish the credited input and incumbent-book accounting.
2. Determine the bounded swap needed to align the caller's basket with the post-swap incumbent whole-book ratio.
3. Execute using only the caller's credited input.
4. Measure actual received amounts and incumbent position changes.
5. Add or remove liquidity toward the sleeve policy.
6. Calculate and mint proportional shares.
7. Finish with full local-balance synchronization.

The swap itself can change the vault's existing liquidity-position token amounts and earn fees. Those changes belong to incumbent backing and must not be mistaken for depositor principal.

Do not consume already-booked incumbent inventory to enlarge a deposit-composition budget.

### 6.3 Share issuance

Let:

- `S` be existing share supply.
- `C0` and `C1` be the caller's complete net contribution.
- `B0` and `B1` be incumbent backing after the swap, excluding that contribution.

For positive incumbent reserves:

```text
sharesOut = min(floor(S * C0 / B0), floor(S * C1 / B1))
```

The caller's contribution includes both deployed assets and assets retained locally.

When the contribution ratios match, issuance is proportional apart from integer rounding. Reconcile any additional fees, donations, costs, or callback effects before final issuance.

Do not silently substitute the single-sided invariant-growth formula when composed dual-token alignment fails.

### 6.4 Exact-output eligibility and route-specific interleaved rebalance

The owner's latest decision **supersedes the previous blanket release prohibition** on the combined route. Determine support per token route, implementation family and PoolManager interaction state from the applicable existing formulas.

#### Existing formulas are the starting point

Inspect both:

- `lib/crane/contracts/utils/math/`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/` — the existing implementation being split, before gated legacy removal.

The owner identifies these as the expected locations of existing closed-form implementations. Reuse applicable formulas rather than initiating another speculative candidate search. Record the exact source/helper, its execution semantics, fees, rounding and supported domain. The existence of an inverse for a different route or a helper that performs numerical search does not establish a closed form for the requested operation. An applicable operation-only inverse also does not establish a combined quotation including maintenance.

#### Support and interleaving rules

1. **Exact output:** support the operation when its applicable closed-form equation exists and its domain, funding and protection conditions are met. Without an applicable closed-form equation, reject that exact-output branch as `InvalidRoute`; do not substitute numerical inversion.
2. **Combined quotation:** when an applicable closed-form quotation includes the operation and its rebalancing, interleave the rebalance according to that quotation. Do not append a separately numerically sized repair while claiming the combined path is closed-form.
3. **Narrow route-preservation exception:** when no applicable combined closed-form quotation exists and enforcing interleaving would eliminate a specific token route in **both exact-in and exact-out modes**, omit interleaved rebalance on that route so otherwise-valid underlying operations remain available. Evaluate this against both modes of the same token direction, family and interaction state, not against unrelated routes.
4. **Limits of the exception:** it does not supply a missing exact-output equation, waive protections or permit a different ownership formula. Exact-out may remain invalid while exact-in is preserved. Do not apply the exception merely because one mode is unavailable or a user requests a cheaper route. Document the route-level exception explicitly in the plan and quote behavior; it is not an unadvertised execution fallback.
5. **Other cases:** if the combined formula is unavailable but at least one mode remains supported without invoking the exception, preserve that supported mode and reject the unsupported branch as appropriate. Do not blanket-disable all operations sharing an `exchangeOut` or other selector.
6. **State constraints:** no nested PoolManager unlocks. Retain funded sleeve-only operations and requested-currency cover checks. A closed-form no-trade case may be supported where its actual complete transition satisfies the requirements; the prior blanket ban on already-balanced cases no longer applies.

Skipping optional interleaved holder maintenance under the exception does not skip caller composition or allocation required by §§6.2–6.3, required liquidity removal for a withdrawal, settlement, fee attribution or full local booking. Public rebalance remains separately available under §8 and can perform subsequent permitted repair.

#### Quotes, failures and implementation evidence

The implementation plan must produce a route matrix covering token/share directions, exact-in/exact-out modes, idle/blocked states and both new families. Each entry identifies its existing formula, whether it includes maintenance, whether the route-preservation exception applies, and its exact supported/revert behavior. This is engineering verification of the owner's rule, not a new owner choice for every selector.

Previews and availability queries must agree with that matrix. Unsupported exact-output/combined branches reject as `InvalidRoute` before funding or economic actions, subject to applicable entrypoint guards. Reverts are atomic; a pretransfer from a separate earlier transaction is not reversed or refunded by the rejected call. Supported paths preserve exact requested output, maximum input, deadlines, funding/refund rules, fee ownership, execution protections and complete held-balance synchronization.

The earlier preliminary candidate results are not a proof of closed-form nonexistence and must not override this source-based review. Validate any selected formula against its actual route, including integer rounding and fee effects. Bounded solvers remain permitted for public rebalance and other separately permitted exact-in work; they do not turn a numerical exact-output inverse into a closed form.

## 7. Best-effort alignment

The accepted alignment tolerance is **1 basis point, or 0.01%**.

A precise proposed implementation metric, including share flooring, is:

```text
epsilon = max_i(1 - sharesOut * B_i / (S * C_i))
epsilon <= 0.0001
```

The implementation must use overflow-safe comparisons and explicitly handle zero denominators.

Best effort permits:

- Bounded solver work where permitted; exact-output eligibility and interleaved maintenance remain subject to §6.4, not an unrestricted best-effort fallback.
- Small mismatch within tolerance.
- Partial feasible liquidity deployment.
- Retained and disclosed placement residuals.
- Further progress through subsequent public rebalance calls.

Best effort does not permit:

- Material uncompensated caller surplus.
- A silent change in issuance formula.
- Unsafe fills or unsettled deltas.
- An absolute-dust exception that defeats the relative loss bound.
- Leaving retained assets unbooked.

If a deposit cannot satisfy the accepted protection and issuance conditions, it reverts atomically. Exact-in deposits do not refund their retained sleeve or placement residuals; those assets remain part of the credited backing.

## 8. Public rebalance

Public `rebalanceLiquidReserve` remains permissionless and available only when PoolManager interaction is available.

It may:

1. Inspect proportionality and sleeve state.
2. Select a useful feasible repair step.
3. Swap vault-owned imbalanced inventory within the per-operation limit.
4. Increase or decrease the existing position.
5. Reconcile the economic book and synchronize all held balances.

Public repair mints no shares. Its net trading costs and own-position fee recovery accrue to the vault book.

The owner confirmed that swapping holder inventory is part of the intended maintenance behavior, provided swaps and liquidity additions/removals pursue proportionality and the sleeve allotment within price-impact protections. Interleaving follows the formula-based rules and narrow route-preservation exception in §6.4. A public-rebalance solver cannot be imported as a substitute for a required combined closed-form quotation. Forgoing interleaving on an eligible route does not remove the separate public repair capability.

### Repeated calls are intentional

Each call evaluates current state independently.

- Multiple successive calls may continue trading immediately.
- Calls may occur in the same transaction or block.
- No temporal or cumulative throttle is permitted.
- When both proportionality and sleeve thresholds are satisfied, no further rebalance trades occur.
- If no safe useful step exists, a truthful no-operation or deferred outcome is acceptable.

Per-operation protection is not a promise to limit aggregate price movement across repeated operations. Vault holders expect regular inventory management.

### Approved proportionality, progress and stopping policy

The owner approved the following policy:

1. Target the existing position's token requirements at the current pool price, calculated with exact finite-range position math. Do not target a historical token allocation or an external market price.
2. Inventory is sufficiently proportional when its normalized composition mismatch is **at most 1 bp (0.01%)**. This is a maintenance threshold distinct from the depositor's contribution/share-flooring loss calculation in §7; neither substitutes for the other.
3. Preserve the sleeve deadband for each token: the greater of its absolute token floor and **5% of its target free balance**.
4. Permit a bounded repair step that improves the final inventory condition after accounting for trading costs, own-position fee recovery and liquidity placement. A successful step need not complete all repair in one call. Evaluate the resulting condition, not merely an intermediate improvement before costs and placement.
5. Prefer liquidity placement without a swap when that suffices. When proportionality and sleeve thresholds both pass, perform no further rebalance trades. If no safe improving step exists, return a truthful no-operation or deferred outcome rather than trade pointlessly.

The implementation plan must specify the exact normalized metric, overflow-safe comparisons, rounding/zero-leg handling and progress ordering under this policy. It must distinguish the maintenance threshold, sleeve deadband and depositor loss bound. Bounded execution work per call remains necessary; it must not become a restriction on successive calls. Neither full convergence in one call nor an absolute-dust waiver of depositor protection is required or permitted by this policy.

## 9. Per-operation protection

The owner-approved, enforced numerical limits are:

| Control | Approved limit |
|---|---:|
| Public rebalance terminal price impact | 25 bp / 0.25% |
| Deposit-composition terminal price impact | 50 bp / 0.50% |
| Execution shortfall versus a fee-inclusive quote | 10 bp / 0.10% |
| Alignment and share-flooring loss | 1 bp / 0.01% |

The owner explicitly approved the 25/50/10 bp values. The 1 bp alignment and share-flooring bound was already accepted. Enforce these limits in successful production execution; observe-only enforcement is not an alternative. Engineering must specify exact calculations, rounding and checks without silently changing the approved values. Any proposed numerical change requires a new owner decision. Validation may identify limitations or infeasible cases, but does not authorize relaxing a limit. These values are not empirically proven safety guarantees or aggregate limits across successive operations.

For consistently oriented token price `P`, an impact metric is:

```text
max(P_after / P_before, P_before / P_after) - 1
```

Apply the limit to **price**, not the same percentage change in square-root price.

A fee-inclusive quote already includes expected fees and price impact. Do not subtract those fees a second time as execution slippage.

Per-operation limits remain effective even when the caller provides a zero or ineffective minimum-share amount.

### Explicit exclusions

Do not add:

- Time-window limits.
- Per-block trading quotas.
- Cumulative price-travel budgets.
- Gross-turnover or campaign budgets.
- Cooldowns.
- An implicit market-price stabilization objective.

The approved execution-protection values are **fixed constants in each implementation**. There is no setter, per-instance override or new administrative tuning privilege. Read-only reporting and exact arithmetic/validation remain implementation details. Changes to these constants require an explicitly approved implementation/package revision, not a runtime update. The sleeve percentage remains the existing live fee-oracle parameter; do not overload it with execution protection or freeze it as part of this decision.

No independent-reference oracle requirement or aggregate fee ceiling is approved merely because a researcher proposed one.

## 10. PoolManager and hook compatibility

The vault continues to use PoolManager directly for the managed position.

### Separate implementation families and fixed reference sources

| Family | Required component naming prefix | Required implementation directory |
|---|---|---|
| Hookless | `UniswapV4FullSpreadHooklessStandardExchangeVault` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/` |
| Pons Family V2 hook | `UniswapV4FullSpreadPonsFamilyHook` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/` |

Apply these exact stems consistently to family-specific packages, facets, targets, repos, execution delegates, quote services, FactoryServices and test infrastructure; interfaces follow the corresponding `I`-prefixed convention. These names and paths supersede the earlier shorter prefixes and directories directly under `v4/`. Do not substitute shortened names or reuse the unsegmented legacy `UniswapV4FullSpreadStandardExchangeVault` product identity for either new family.

The hookless family must not contain Pons fee decoding, Pons hook handling, or runtime selection of a Pons model. The Pons family implements the referenced V2 behavior explicitly and must not fall back to hookless behavior. Separate package wrappers over a combined Hookless/Pons quote or execution dispatcher do **not** satisfy this requirement. It applies to ordinary previews, transition quotes, execution and maintenance, not just deployment checks.

Reuse of genuinely hook-independent protocol math, token/accounting primitives, generic vault facets and deployment infrastructure remains permitted. Such reuse must not hide shared hook-model dispatch or substitute a family-specific delegate behind nominally separate wrappers. The plan must enumerate the two family component sets and identify any generic infrastructure they reuse.

Production binding is `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` on Robinhood mainnet (`ROBINHOOD_MAIN.CHAIN_ID`, currently 4663). The inspected constant is `0x8366a39CC670B4001A1121B8F6A443A643e40951` at `ROBINHOOD_MAIN.sol:169`; the maintained constant is authoritative, not a newly duplicated literal. The Pons hook and package dependencies must agree on that manager. Hermetic production-path tests use the real local PoolManager implementation through existing TestBases; test dependency injection does not expand production manager support.

The Pons behavior reference is `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/`, including `hooks/PonsV2MemeHook.sol` and the associated launch/registration code. This settles the source generation and PoolManager selection. The current production hook binding is the existing constant `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`, not a newly invented literal and not a hook deployed per pool. Official docs and the previously recorded `memeHook()` read identify `0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044`. That identity is the current factory stack. A token launched against an earlier stack keeps the hook it launched with, so this package does not admit every historical pons pool. Under D29, official documentation plus graduated-pool usage is accepted as sufficient evidence; no additional runtime-bytecode equivalence gate is required. This acceptance does not claim binary equivalence or waive implementation testing.

### Package-specific compatibility boundary

New packages are integration-specific, not generic arbitrary-hook vaults:

- **Hookless package:** require `poolKey.hooks == address(0)`.
- **Pons integration package:** require `poolKey.hooks` to equal `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`, using the V2 reference tree and canonical manager binding above. A family name, matching flags, or matching getter ABI alone does not establish that identity. Per-pool validation is equality with that singleton, not discovery of a new hook address.
- **Future hook integrations:** use a separate package for each supported hook binding. Reuse an existing facet/delegate set only when its specific behavior and dependencies support that new integration. This future reuse policy does not override the required Hookless/Pons separation.

The expected Pons Family V2 hook address is **fixed in the Pons package** to `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`, not chosen or weakened by the vault deployer through instance arguments. Bind that constant immutably when the package is constructed, with no setter or runtime hook-list extension. Do not duplicate the literal outside the network-constants library. Enforce admission centrally through package argument validation and initialization. Maintain independently identifiable packages under the repository's deployment identity rules.

Hook flags identify callbacks, not whether arbitrary hook logic will permit an operation. Exact identity binding reduces the supported domain to a reviewed integration; it does not remove the need to validate its relevant mutable state, fees, lifecycle and quote behavior.

Therefore:

- Retain deterministic structural PoolKey validation.
- Do not claim hook flags certify compatibility.
- Reject a pool whose hook does not match its package's integration, even if the deployer asserts compatibility.
- Specify and test the admitted integration's fee and callback model. Treat a new hook revision or changed model as a new integration requiring explicit review and package identity.
- Do not add a mutable discretionary hook whitelist or an unknown-hook vanilla-quote fallback.
- Preserve actual-fill accounting, settlement checks, and execution protection.
- Do not present an inaccurate vanilla-pool quote as exact for unmodelled hook behavior.

Successful Universal Router minting is not proof of this vault's full lifecycle compatibility. In the inspected upstream revision, the Universal Router's V4 PositionManager command rejects increases, decreases, and burns of existing positions; direct PositionManager supports the broader lifecycle. The managed vault uses direct PoolManager calls.

No migration to Universal Router is implied.

## 11. Canonical pretransfer law

Pretransfer is settled product law, not an open security-design question.

For an eligible integrating contract:

```text
unbooked = actual locally held balance - durable local snapshot
require declaredAmount <= unbooked
credit = declaredAmount
```

Requirements:

- No original-sender or provenance verification.
- No nonce-based funding witness requirement.
- No mandatory pull-only restriction.
- Integrators ensure transfer and deposit or withdrawal occur atomically.
- Apply the existing contract-caller guard and its documented account semantics.
- Exact-in refunds nothing.
- Absorb unclaimed surplus into the book at successful workflow completion.
- Already-booked inventory cannot be re-credited without new unbooked balance.

Earlier council suggestions to reject source-agnostic claims are withdrawn.

## 12. Complete local booking

Economic approximation is never accounting approximation.

After every successful balance-changing workflow, synchronize the **full expected held-token set** to actual local balances.

This includes:

- Sleeve balances.
- Undeployed credited contribution.
- Numerical dust.
- Partial-rebalance residuals.
- Compound-pending inventory.
- Retained unused amounts.
- Absorbed unclaimed surplus.

Synchronization occurs after all swaps, liquidity operations, payouts, and applicable refunds.

A residual may remain undeployed, but must not remain unbooked after success.

Maintain distinct meanings for:

1. Durable local snapshots used by pretransfer credit.
2. Deployed principal.
3. Uncollected fees.
4. Complete economic backing used by shares.

The old V4 implementation stored economic totals and subtracted current deployed inventory to infer local credit. The target FullSpread implementation already stores actual local snapshots separately from complete economic backing and applies the contract-caller guard. Preserve those controls across every new workflow; position repricing must not manufacture local pretransfer credit. This is a preservation and regression requirement, not permission to rebuild or modify the old tree.

## 13. Acceptance requirements

Implementation acceptance must demonstrate:

1. Repeated unilateral deposits compose and deploy when feasible.
2. Shares use post-swap incumbent backing and credit the complete caller basket.
3. Sleeve policy uses owned deployed principal.
4. Blocked deposits do not initiate nested unlock.
5. Blocked withdrawals require actual requested-token cover.
6. Initial activation still requires actual funding in both tokens.
7. Public repair performs bounded swaps and permits immediate repeated calls.
8. Rebalance trades stop when both thresholds are satisfied.
9. No time or cumulative throttle blocks otherwise valid progress.
10. Per-operation limits use correct units and do not double-count fees.
11. Alignment loss is measured independently of sleeve deadband.
12. Every successful workflow fully books all retained local inventory.
13. Pretransfer tests distinguish valid unbooked claims from prohibited re-credit of booked inventory.
14. Hook admission enforces the selected package's fixed integration identity, with truthful integration-specific quotes and no unknown-hook fallback.
15. Native and WETH behavior, imports, Multi routes, and affected consumers retain their required behavior.
16. Cross-mode deposit and withdrawal cycles receive adversarial testing; differing quotes alone are not proof of an exploit.
17. Solver work is bounded, and actual economic and accounting results are independently checked.
18. Exact-output support is established per route from an applicable existing closed-form equation with correct fees, rounding and state domain. Unsupported branches reject as `InvalidRoute` before funding/economic actions; no numerical inverse is substituted.
19. Routes with an applicable combined closed-form quotation interleave rebalance. Where requiring interleaving would otherwise eliminate both exact-in and exact-out for a specific token route, tests demonstrate the documented omission exception without waiving core operation requirements or manufacturing exact-output support.
20. Ordinary previews, transition quotes, route availability and execution agree on formula-backed support, interleaved maintenance and each route-preservation exception. Cover both families, token/share directions and idle/blocked states, including eligible no-trade cases and unchanged atomic rejection behavior.
21. Public maintenance uses the current-price finite-range position composition target and the separate inclusive 1 bp proportionality threshold. Test equality and just-outside cases independently of sleeve deadband and depositor alignment loss.
22. Maintenance tests demonstrate placement-only preference when sufficient, safe incremental progress measured after costs and placement, no trading once both thresholds pass, and truthful no-operation/deferred behavior when no safe improving step exists.
23. Hookless packages reject nonzero hooks; Pons-specific packages reject wrong hook identities and incompatible manager bindings. Tests include same-flags/ABI impostors, independent vault state, correct generic-infrastructure reuse and occupied deployment-identity behavior.
24. Family components use the exact prefixes/directories in §10. Neither family reaches a shared Hookless/Pons model dispatcher; hookless paths contain no Pons decoding and Pons paths have no hookless fallback. Cover ordinary/transition quotes and money/maintenance paths in both families.
25. Production package dependency bindings resolve to the canonical Robinhood PoolManager and Pons hook constants; Pons compatibility and fee expectations derive from the specified V2 reference. Record the accepted documentation/graduated-pool evidence and separately label hermetic fixtures versus production evidence. Do not add a runtime-bytecode equivalence pass/fail gate or claim equivalence was proved.
26. Legacy removal occurs only after both new families meet the audit-submission readiness gate in §3.1. Verify the exact removal manifest and preservation of both new subtrees, with durable historical provenance.
27. The final post-removal checkout builds and passes the required replacement/consumer regression suites using refreshed artifacts. No active source, package wiring or maintained build/test path depends on removed legacy vault components; the audit handoff identifies this final revision.
28. Approved execution protections are fixed implementation constants with no mutating configuration surface. The Pons package fixes its expected hook to `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` and rejects an instance's mismatched hook, including a same-flags impostor and a historical-stack hook. Live sleeve-percentage behavior remains intact.
29. At identical operation state, each supported preview agrees exactly with execution's deterministic integer result and each transition quote agrees with the resulting book. Equivalent SE/SY and other in-kind interface paths have the same funding, payout, share, fee and accounting effects. Unsupported branches report the same domain failure. Different economic operations are not falsely treated as aliases.

Use production-path vault, registry, fee-oracle, and PoolManager implementations. No test execution is claimed by this PRD.

## 14. Council-owned engineering specification

The council has supplied [the implementation and test plan](UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md) and [the finite removal/deprecation manifest](UNISWAP_V4_FULLSPREAD_REMOVAL_MANIFEST.md) under D27–D31. They select the following mechanics rather than sending these choices back to the owner. Implementation and executed validation remain future work:

- Read-only reporting and arithmetic for fixed execution-protection constants; their values and absence of a runtime tuning authority are settled.
- Exact price and quote calculations and hook-sensitive execution mechanics.
- Solver convergence where permitted, rounding, and numerical tolerances; no numerical exact-output inverse or separately solved repair presented as a combined closed form.
- Existing-formula inventory from `lib/crane/contracts/utils/math/` and the current unsegmented V4 implementation, with the exact selector/direction/state/consumer matrix under §6.4. Specify formula-backed exact-output support, combined interleaving, justified route-preservation exceptions and early `InvalidRoute` rejection of unsupported branches before legacy removal.
- Exact normalized public-repair metric, arithmetic and progress ordering implementing the owner-approved policy in §8; the 1 bp maintenance threshold, sleeve deadband and incremental-progress objective are settled.
- Caller-funded composition versus holder-funded repair attribution.
- Preservation of FullSpread local snapshot storage and complete workflow synchronization.
- Compatible reserve and residual reporting.
- Affected selectors, packages, consumers, and tests.
- Separate family component/selector/factory maps under the exact D22 prefixes/directories, strict family-specific quote and execution paths, permitted generic infrastructure reuse and registry discovery metadata. D23 fixes the manager and Pons source generation. D26 fixes the current-stack hook to `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`; do not invent another address or admit a historical stack's different hook. Preserve existing deployed instances; no migration is implied.
- Legacy removal manifest, dependency/reference updates, regression preservation, audit-readiness evidence and final post-removal validation under D24/§3.1. This is a gated phase of the same implementation effort, not a separately deferred deprecation project.

Do not reopen settled pretransfer, direct PoolManager integration, separate family logic, hook-specific package admission, fixed protection constants, immediate repeated rebalancing or full booking. Apply the latest formula-based exact-output/interleaving and route-preservation rules; the former blanket exact-output prohibition is superseded.

## 15. Evidence and limitations

Relevant local sources:

The legacy implementation paths below are baseline references until the §3.1 removal gate. After removal, cite their preserved source revision and update active implementation references to the new family trees; do not treat this evidence list as a requirement to keep legacy sources indefinitely.

- `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` — canonical production manager binding and current-stack `PONS_V2_MEME_HOOK`.
- https://docs.ponsfamily.com/v2 — current-stack singleton meme hook, accessed 2026-09-27. A prior factory stack can retain a different hook.
- `lib/crane/contracts/utils/math/` — owner-designated source for existing closed-form math; verify each helper's applicability to the selected route.
- `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/` — owner-selected Pons behavior reference.

- `contracts/vaults/basic/BasicVaultRepo.sol`
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultInBase.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md`
- `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md`

Primary upstream sources inspected September 27, 2026:

- https://github.com/Uniswap/universal-router/blob/main/contracts/modules/V3ToV4Migrator.sol
- https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol
- https://github.com/Uniswap/v4-periphery/blob/main/src/PositionManager.sol

Upstream `main` sources are not deployed-version pins. The observed local compiler configuration was Solidity 0.8.35, optimizer runs 1, with via-IR disabled.

Historical council artifacts remain under `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/`. They are research evidence, not permission to override this document. Council agreement and eventual passing tests are not proof of security or economic soundness.
