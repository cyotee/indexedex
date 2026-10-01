# Astra — One combined cross-review

**Date:** 2026-09-27. Read all three complete original reports (Grok, MiniMax M3, Kimi K3) together, as untrusted evidence, then checked disputed claims against current product documents and source. No cross-review artifacts were read. `astra-original.md` is unchanged. Research only: no shell, tests, implementation, configuration changes or delegation.

**Human clarification incorporated in this same session:** the target is explicitly the NEW FullSpread V4 vault under `contracts/vaults/standard/exchange/protocols/uniswap/v4/`. The owner intends to deprecate the old vault. That overrides the older README's “not deprecated” characterization, but does not authorize old-code edits, deletion, deployment changes or migration. This completes the single combined cross-review; it is not a second peer-review round.

## Verdict and material correction to my original

**Ready to write an implementation plan, after correcting its baseline to FullSpread.** Do not edit the preserved implementation. Most proposed owner questions are already answered by the latest PRD or are expressly engineering work. A conservative scope reading leaves no mandatory new economic decision before drafting. One narrow confirmation about automatic repair swaps is useful before plan freeze; numerical calibration needs a recorded specification, not renewed permission to enforce protection.

**Grok's FullSpread finding changes my assessment substantially.** I inspected the old tree and incorrectly framed its missing local-snapshot separation and caller guard as current implementation work. Those observations remain accurate about the preserved sources, but are not findings against FullSpread. MiniMax and Kimi made the same baseline mistake.

### Citation abbreviations

- **Z** = `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`.
- **U** = `contracts/vaults/standard/exchange/protocols/uniswap/`.
- **CP** = `U/v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md`.
- **FCommon / FInBase / FLiquid** = `U/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol`, `...InBase.sol`, `...LiquidReserveTarget.sol`.

## 1. FullSpread versus preserved-tree scope — Grok is correct

**Verified facts:** CP:7–10,26–35,96–102 identifies the new implementation and forbids modifying the preserved `contracts/protocols/dexes/uniswap/v4/` tree. The shared remediation PRD (`U/UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md:13–20`) repeats this boundary. CP:235–243 requires distinguishable artifacts, delegates, salts and registry identities.

FullSpread already:

- Writes actual local token balances, separately from economic backing: FCommon:610–635.
- Checks the contract caller and declared credit against locally unbooked inventory: FCommon:1218–1239.
- Synchronizes even a no-movement rebalance: FCommon:757–765,802–810.

**Corrections:** Retract my implication that this epic must introduce those features into the old code. Preserve and regression-test them in FullSpread. Reject MiniMax's proposed old-tree edit manifest and Kimi's claim that the current target lacks a caller guard. Z:381–387 and :338 should distinguish historical evidence from the active baseline. That documentation defect is not permission to repair the preserved tree.

**Unresolved evidence:** whether particular FullSpread CREATE3 identities are deployed/frozen on the intended target chain. Planning must inventory identity/provenance and select an appropriate distinct successor identity if necessary. This is not an owner choice between editing the preserved tree and the new tree; the former is already forbidden.

## 2. Blocked issuance — preserve the existing route; prove its economics

**Verified facts:** Z:73 preserves existing sleeve-only blocked deposits. Z:134 scopes composition execution to when interaction is available; :166 prohibits silently falling back when *composed* alignment fails. FullSpread's blocked deposit receives one token and calls shared invariant-growth issuance (FInBase:269–311; FCommon:689–701; `U/StandardExchangeConstantProduct.sol:37–64`).

CP:164–185 expressly permits algebraic/internal settlement if the full reserve transitions and holder claims are equivalent; CP:219–233 requires funded blocked routes and no silent change in share ownership policy. Thus Grok's statement that retaining invariant-growth issuance necessarily needs a D58 exception is not established. CP itself says square-root growth can be valid.

**Independent algebra:** For a zero-fee same-book Y deposit `d`, set `a = sqrt(Y*(Y+d)) - Y`. Conceptually swap `a` Y for `X*a/(Y+a)` X. Post-swap incumbent reserves are `(X*Y/(Y+a), Y+a)`. The conceptual contribution ratios both equal `a/Y`; proportional issuance is `S*a/Y`, and final total backing is `(X,Y+d)`. No net X payout occurs during this internally settled deposit. Requiring physical sleeve X transfers solely to represent a net-zero internal leg is an extra mechanism, not established owner law.

**Resolution:** Preserve blocked issuance, document its internal settlement/fee model and independently verify integer-rounding and cross-mode cycles. Do not universally apply idle dual-basket min-ratio checking to raw single-token blocked credit. Do not offer blanket blocked-deposit rejection as an equally authorized option. Escalate only a demonstrated incompatibility with the required holder claims; none of the originals demonstrated one. This is stronger substantiation of my original preservation recommendation, not proof all current arithmetic is correct.

## 3. The 1 bp bound includes flooring — do not reopen it

Z:170–179 specifies a proposed metric including flooring; :189–197 forbids a dust escape and requires atomic rejection; :236 explicitly names **alignment and share-flooring loss**. Calling the implementation metric “proposed” permits a sound equivalent specification, not dropping the accepted loss component. I disagree with Grok's recommendation to switch to pre-floor composition error unless the owner affirmatively revises the requirement.

For positive denominators, write `q_i = S*C_i/B_i`, `m = floor(min(q_0,q_1))`. Then:

`epsilon = max_i(1-m/q_i) <= 1/10000`

is equivalent to requiring **for each leg**:

`10000*m*B_i >= 9999*S*C_i`.

This is an exact mathematical comparison, not a recommendation to multiply unchecked 256-bit values. MiniMax's suggested inequality in §3.2 loses `S`, exchanges factors, and is not equivalent.

Small deposits may fail even when perfectly aligned: `q_0=q_1=1.5` gives `m=1`, epsilon `1/3`. Conversely `q_0=q_1=1` passes exactly. Therefore neither a blanket “all small deposits fail” nor a universal minimum of 10,000 share units follows. The PRD already accepts protective reverts.

Also distinguish this metric from literal post-mint uncompensated contribution: under a simple final book `B+C`, that loss fraction on leg i is `epsilon_i*S/(S+m)`, so the proposed metric is conservative. This observation does not authorize relaxing the agreed protection.

## 4. Automatic versus public repair — narrow the question

Grok and I agree a swapping automatic tail must not be introduced accidentally. MiniMax's “reuse unchanged”/mandatory post-zap tail advice is unsafe as a specification: the new deposit order is composition → allocation → mint, not old mint → repair.

**Verified facts:** FullSpread's public rebalance and automatic tail share the internal helper (FLiquid:92–96; FCommon:727–731). Automatic tails follow direct swaps, exits and Multi joins (FInBase:87–88,210–211,369–370). CP R7:225 retains add/remove-only repair until superseded. Z D9 and §8 specifically expand **public** rebalance; Z:140 authorizes deposit liquidity placement, not an additional holder-funded composition swap.

**Minimum-scope interpretation:** public repair gains swaps; automatic non-deposit tails retain placement-only behavior; the new deposit has explicit pre-mint placement and no unintended swapping tail. This can be written into the plan without an owner answer. If broader automatic holder-funded trading is desired, ask exactly: **“Does authorization for holder-funded repair swaps extend to automatic tails, or remain public-entrypoint-only?”**

I demote my original public repair-target P1 question to engineering. Z:225,366–375 explicitly assigns progress/proportionality metrics to implementation specification. Planning should define deployability plus sleeve adequacy without a historical allocation or price-stabilization objective; escalate only if that proves insufficient. Kimi's suggestion to reuse 1 bp plus an absolute floor for repair is an engineering proposal, not an accepted requirement, and must not weaken deposit protection.

## 5. Other mathematical and requirements corrections

- **MiniMax's sleeve equivalence is false:** for `T=120`, `p=.2`, old `T*p=24`, new `T*p/(1+p)=20`. At `T=140`, new target is `23⅓`, with `16⅔` deployed from the original 40 free. This is denominator semantics, not rounding discretion. Z:94–119 settles it.
- **Balanced dual min-ratio issuance is already implemented**, not a newly proposed replacement for every formula: `StandardExchangeConstantProduct.sol:52–56`. MiniMax B/C ask again about settled issuance and post-swap attribution (Z:150–166).
- **Blocked public rebalance still reverts.** Z:201 limits availability to idle; :221 permits safe no-op when no useful repair exists within that scope. FLiquid:92–95 enforces the gate. MiniMax A is not a product fork.
- **Protection is enforced, not observation-only:** Z:197,250. Reject MiniMax's “observe only first” default for production. Calibration can precede release without disabling requirements.
- **Atomic rollback, zero-swap optimization and truthful hook quotes are specification tasks**, not owner questions. Existing source does not establish economic safety merely because it calls a synchronization helper.
- **Multi tail already exists:** both preserved InBase:371–372 and FullSpread FInBase:369–370 contradict MiniMax §4.2. Adding a new Multi composition swap is not interchangeable engineering taste; preserve its required behavior absent explicit change.
- **Kimi's monotone fixed-point claim is unproven for arbitrary compatible hooks.** Planner must establish solver assumptions, handle unsupported quoting honestly and bound work; deployer compatibility assurance is not a monotonicity proof.

## Minimum owner burden, remaining dissent and confidence

**No mandatory new owner economics question before plan drafting**, using the conservative scope above. One conditional confirmation about automatic swapping tails is useful before freeze. Record calibrated 25/50/10 bp values and authority; escalate deviations/new privileges, not the already accepted 1 bp/no-dust rule. FullSpread identity selection, blocked reference proofs, overflow-safe comparisons, quote parity, progress tests and solver bounds remain engineering work.

**Dissent:** Grok blocks planning on blocked issuance and flooring; I do not. MiniMax's nine-question list largely reopens settled requirements and includes substantive mathematical/source errors. Kimi's plan-readiness verdict is closest, but its old-tree findings cannot describe FullSpread and its repair tolerance/monotonicity proposals are not approved facts.

**Confidence:** high on preservation, local accounting/guards, code branches and algebra; medium on completeness of the future blocked/internal-settlement proof and hook-general solver feasibility. No tests run, no deployment/bytecode pin established, and no security or economic soundness inferred from agreement or historical test claims. First-pass observed compiler configuration remains Solidity 0.8.35, optimizer runs 1, via-IR false; current math sources use pragma `^0.8.0`. This cross-review introduces no new external API claims; first-pass Context7/primary-source evidence remains dated 2026-09-27.

## Completed NEW-target behavior and consumer checks

All filename abbreviations in this matrix are within **U/v4/** and begin `UniswapV4FullSpreadStandardExchangeVault`; **Math** is `U/StandardExchangeConstantProduct.sol`. These are current source observations, not execution results.

| Surface | Verified NEW behavior | Consequence for the plan |
|---|---|---|
| Single-token deposit | `InTarget.sol:67–72` credits input and delegates. `InBase.sol:269–311` mints first without a composition swap; only idle calls then rebalance. `Common.sol:689–701` uses Math's invariant-growth branch (`Math:58–64`). | Rebuild idle exact-in deposit ordering and quoting; preserve the explicitly retained blocked route. |
| Blocked single-output redemption | `InBase.sol:125–163` uses Math `_singleExit`, checks actual output-token sleeve cover, burns, pays, then syncs. `Math:98–110` includes conversion of the other entitlement against the remaining book. | Do not copy the old vault's one-leg-only payout interpretation. Blocked/idle cycle tests must model the different declared settlement venues and costs. |
| Pretransfer and durable snapshots | `Common.sol:610–635` separates actual local snapshots from complete backing. `Common.sol:1218–1239` checks caller eligibility, unbooked availability and exact pull delivery. `Common.sol:1274–1280` routes self-share delivery through the same guard except the explicit active Native SY self-call context. | My original stale-snapshot/missing-guard findings are NOT current FullSpread defects. Preserve these controls and full end-sync in newly introduced branches. |
| Multi deposit | `InBase.sol:331–374` receives both amounts, uses proportional min-ratio issuance, retains surplus and has an idle tail. | Preserve this behavior; do not introduce a composition swap or universal zap-loss bound by merely sharing a helper. |
| Public and automatic repair | `LiquidReserveTarget.sol:92–96` requires idle; `Common.sol:727–731,757–810` shares the current add/remove helper with automatic tails and synchronizes no-movement outcomes. | Separate the newly authorized public swap behavior from existing automatic placement unless broader trading is explicitly approved. |
| Ordinary deposit preview | `InMultiQueryTarget.sol` exposes `previewExchangeIn` (grep-confirmed :11); actual quote helper is `InBase.sol:252–261`. | Updating only the file called `InQueryTarget` misses the ordinary preview surface. Enumerate proxy selectors, not filenames alone. |
| Transition-state quotes | `InQueryTarget.sol:15–29,61–103,112–168` projects deposits, withdrawals, fees and post-operation placement. | Update the projected book, share supply, pool state, fees and sleeve policy alongside execution. A correct returned share number alone does not establish next-state parity. |
| Hook quote capability | `QuoteService.sol:44–57` restricts projected-hook support but leaves unsupported hook adjustments unchanged; `Common.sol:103–109` rejects unsupported inventory snapshots. | Distinguish strict transition-quote gating from ordinary quote fallback. Do not describe every quote as exact or every hooked pool as supported. Preserve deployer assurance without fabricated execution guarantees. |
| Existing exact-output mint | `OutBase.sol:45–61` inverts the old single-token invariant branch. `OutExecuteTarget.sol:105–136` funds, optionally refunds unused credited input, collects fees and mints exact shares without composition. Math's inverse is :67–95. | This is a real adjacent route, not an absent capability. State explicitly whether it remains the declared internally settled route under this exact-in epic; test cross-route cycles and preview/execution parity. Do not silently claim it is the inverse of the new external-composition exact-in route. |
| Native SY / package surface | `OutMultiQueryTarget.sol:16` inherits `NativeStandardYieldTarget`; `OutMultiQueryFacet.sol:25–26` appends Native SY selectors (grep-confirmed). | Include native SY and selector wiring in the dependency inventory; no claim of complete consumer enumeration or integration testing is made. |

**Further correction to scope confidence:** exact-output mint is an important omitted dependency in my first pass and the originals' short route maps. Different entry venues can be intentional under CP:200, but cannot be hidden behind an unchanged inverse/quote comment. Planning must map this explicitly. If the owner intends *all* idle share issuance, including `exchangeOut` exact-share mint, to become external-composition-only, that is an additional route-scope answer to record; Z's explicit `exchangeIn` instruction alone should not be stretched into that authorization. Under the narrow reading, preserve exact-output behavior with explicit economics and adversarial cross-route acceptance, escalating any demonstrated contradiction rather than assuming differing quotes prove an exploit.

Canonical local testing guidance was directly re-read (`.claude/skills/indexedex-testing/SKILL.md:144–163`): quote parity, real manager/registry deployments, target-derived selector controls and local-credit negatives remain requirements. No new API claim required additional external documentation during this continuation.
