# Astra — v0.2 requirement questions, independent original

2026-10-05. Read PRD v0.2 directly, CLAUDE, canonical IndexedEx testing/Crane adversarial skills, current quote interfaces and FullSpread quote source. No peer files, shell/git/tests or PRD edits. Earlier invariant/finite-center discussions are superseded. Confidence: high on document/source distinctions; no new proof, gas or security result claimed.

**Answer:** Yes, a few owner choices remain. Most RV items are work for engineers, not questions asking the owner to prove the design. Target-only flows/bootstrap, whole-book V, full-range core, nearest-outside-to-limit wings, conversion eligibility, withdrawal priority, separate zap-capable rebalance, owned-D target sleeve and blocked requested/available error are settled.

All PRD references below are to `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md`.

## A. Actual blockers: policy questions only where necessary

### 1. What is the explicit failure policy when complete liquidation is impossible? — highest priority

**References:** :140–156,247–255,372.

This is not merely implementation uncertainty. If opposing inventory is positive and removing all owned liquidity leaves no external conversion depth anywhere in the configured pool, the specified sale cannot complete. With opposing inventory zero, this particular issue does not apply: target-only activation can still have a valid V. External LPs can also withdraw after deployment, so initial eligibility alone cannot guarantee perpetual quote availability.

**Question:** May that identified exceptional state return a typed incomplete-liquidation failure, with affected valuation-dependent operations unavailable until depth returns? Or is additional recovery/conversion machinery required under separate approval?

**Recommendation:** Explicit failure—never partial/stale/spot proceeds presented as complete V. Do not add another venue, haircut, queue or basket route by assumption. Engineers must first enumerate the exact failing states and useful supported domain; owner approves the exceptional availability policy, not a mathematical proof. This must not become a blanket excuse to reject ordinary routes (:156).

### 2. Which expenses may reduce user credit or remaining-holder value? — accounting blocker

**References:** :146,170–178,184–198,212–214,240–242.

**Question:** Confirm fee recipients/timing and attribution: should required user-operation placement/removal/conversion costs be charged to that user, while separately invoked rebalance costs are bounded holder expenses? Are any additional holder-paid user-operation costs intended?

**Recommendation:** Approve a fee/cost table, not an unexplained aggregate tolerance. Identify simulated costs already included in V, actual additional costs, retained fees, externally paid fees, and later maintenance separately. No double charging. Preserve the stated V/share condition except explicitly authorized costs and proven rounding. Numeric loss ceilings require an engineering-supported proposal for owner approval; none of the old FullSpread limits transfers automatically.

### 3. Should ordinary idle calls harvest converted wings automatically? — bounded scheduling choice

**References:** :108,112–116,375.

**Options:** observe only and let separate rebalance harvest; or execute a strictly bounded harvest on qualifying idle calls.

**Recommendation:** Observe only during deposits; withdrawals realize positions only as needed by their settled priority; general harvest/zap stays in separate rebalance. This preserves inexpensive ordinary entry. Eligibility at nonzero opposing principal remains settled regardless of scheduling.

## B. Parameters and release scope—not new strategy votes

Request one compact approval table after engineers supply justified proposals:

* **Sleeve:** effective percentage default/range and absolute/relative deadband (:220–232,376). Denominator and target-only sleeve are not questions. Twenty percent and five percent remain proposals.
* **Bootstrap:** share decimals/scale, permanent minimum, minimum accepted target deposit, deterministic metadata and pre-existing residual sink treatment (:162–164,377). Do not ask whether first entry must be dual-token; it must not.
* **Maintenance protections:** permitted impact/holder loss, progress/no-churn condition, and finite work budget (:236–243,378). Permissionless balancing is settled; approval concerns its risk budget.
* **Platform/surface:** launch chains, native ETH/WETH versus ERC20-only, exact-output release scope and proposed90%-of-verified-transaction-cap margin (:268,277,344–350,379). Recommendation: determine required consumer interfaces before deferring exact-output; no unmeasured compatibility claim.

These parameters block a finalized implementation specification, but not continued accounting/source research.

## C. Engineering/proof obligations: do not send these back as owner homework

Engineers must establish the deterministic all-own-removal quote, projected tick/fee state, full-fill detection, issuer-growth accounting, funding under prescribed removal order, overflow-safe integer inverses, useful consumer domains and actual outer-transaction gas. They must propose an effective bounded overshoot rule and test the V/share effect—not ask the owner to invent a solver.

Stage4 mixed-wing/core order (:210) should be proposed deterministically; mixed wings before core best matches the already-stated core-preservation objective. If that cannot meet the requirement, present the specific counterexample instead of silently reversing opposing-wing-before-core.

Current FullSpread's `UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol:45–50,74–99` under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/` can classify arrival at its price limit as acceptable redemption despite unsold input. Its projection at:94 models one liquidity change. Neither behavior is automatically reusable for v0.2's complete, three-position liquidation. This is an engineering compatibility gap, not an owner choice to redefine V.

## D. Wording gaps and unapproved assumptions

1. **Strict outside tick** is only a proposed exact interpretation (:90–98). Propose confirming strict sqrt-price separation including exact aligned boundaries; do not characterize it as already ratified numeric geometry. Token orientation is correct (`LiquidityAmounts.sol:67–75` under Crane's V4 libraries).
2. **“Preserve sleeve” after redemption** (:212) must not mean silently running the separate rebalance or withholding entitlement to maintain a target. Clarify it governs allocation of available residuals; shortage/placement limits do not authorize fabrication or payout haircuts (:188,230).
3. **Requested/available** (:249): distinguish user's net payout from all immediate target outflows when an operation fee goes externally. Capacity must fund the whole obligation once; error arguments need an unambiguous convention.
4. **Preview versus economic rate:** `IStandardExchangeTransitionQuote.sol:20–38` separates valuation and executed state projection; `IStandardExchangeUnlockContextQuote.sol:9–16` models unavailable unlock. Specify which executable previews revert for insufficient local cover while V/S remains an economic view (:251,285). This is ABI semantics to propose, not permission to equate value with capacity.
5. **Historical snapshot prerequisite** (:46) is unnecessary as a proof of this explicitly altered design (:52). Recommend nonblocking provenance research unless the owner requires literal historical source reuse; do not make missing history a reason to stop new requirements analysis.

No apparent contradiction requires reopening the selected valuation or priority strategy. The real tension is demanding complete current liquidation in states without external conversion capacity. Document that exceptional policy honestly, then keep the remaining proof and implementation work with the engineers.
