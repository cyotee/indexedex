# Astra — Remaining open items, independent original

**Date:** 2026-09-27. **Verdict:** No unconditional human-policy blocker identified. The remaining work is principally a decision-complete engineering specification, verification evidence and documentation reconciliation—not another vote on settled design. The highest-priority next step is the source-backed route/formula matrix required by §6.4.

Read current CLAUDE.md, the complete current PRD, relevant canonical Crane architecture/deployment/testing and IndexedEx testing guidance, family law and selected formula sources directly. No peer artifacts, shell, tests, code/config changes or delegation. This pass makes no new external API claim or live-chain verification claim.

Below **Z** denotes `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`; **U** denotes `contracts/vaults/standard/exchange/protocols/uniswap/`.

## 1. Human decisions: closed, with conditional escalation only

**Observation:** D1–D26 settle separate implementation families and exact names/paths, fixed protection constants/no setters, production manager, current-stack Pons singleton, formula-based exact-output eligibility, narrow maintenance omission and gated removal (Z:28–53).

Consequently, do not ask again:

- Shared Hookless/Pons dispatcher versus separated implementations: separation wins, including quotes/execution/maintenance (Z:350–361).
- Which Pons address or generation: fixed by D23/D26 and `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`; historical stacks are not admitted (Z:363–375).
- Whether exact-output is blanket-disabled: that older prohibition is superseded (Z:203–233).
- Whether 25/50/10/1 bp values are provisional or configurable: they are fixed, enforced constants (Z:308–342).
- Whether removal needs another project or completed audit: it is this effort's final gated phase; audit-submission readiness is the trigger (Z:74–95).

**Inference:** Owner escalation is necessary only if verification demonstrates a concrete conflict requiring a policy change—for example, the fixed deployed hook does not implement a required reference behavior. Report the discrepancy without substituting another hook, relaxing protections or inventing a fallback. Missing evidence is not an unresolved address choice.

## 2. Priority engineering specifications

### P1 — Complete the route/formula/interleaving matrix first

For each family, token/share direction, exact-in/exact-out mode and idle/blocked state, record the existing helper, fee/reserve semantics, rounding/domain, whether maintenance is included, exception eligibility, consumer/preview surface and exact success/revert behavior (Z:209–233,489).

**Direct source observations demonstrate why names alone are insufficient:**

- `U/StandardExchangeConstantProduct.sol:67–95` contains a closed-form input inverse for the existing invariant-growth mint. Its applicability to a new externally composed route must be established, not assumed.
- The same file's `_sharesForSingleExit` at :113–128 uses bisection.
- `lib/crane/contracts/utils/math/ConstProdUtils.sol:235–256` supplies a constant-product purchase equation, but :579–654 uses search for target-LP zap-in; :733–833 uses a quadratic guess followed by search for target-output zap-out.

These are initial inventory entries, **not** an exhaustive determination of supported routes or proof that another applicable formula does not exist. Do not launch another speculative formula campaign before examining the owner-designated sources.

The omission exception requires that enforcing interleaving would eliminate **both modes of that same direction/family/state**. It cannot manufacture an exact-output equation or skip required composition, removal, settlement or booking (Z:218–225). A formula for the user operation alone is not a combined formula.

### P1 — Freeze family-specific accounting and numerical mechanics

Specify caller/holder budgets; post-swap incumbent backing; own-position LP fees, protocol/hook charges and collection; placement-rounding costs; retained residuals; terminal snapshots. Define the overflow-safe depositor loss comparison, zero/tiny-input behavior, bounded permitted solver and execution budget (Z:160–201,235–264,486–492).

Specify the exact normalized maintenance mismatch and progress ordering **within** the approved target, inclusive 1 bp threshold and sleeve deadband. Evaluate progress after costs, own-fee recovery and placement; partial improvement/no-op are permitted (Z:294–304). These are engineering choices, not reopened thresholds.

### P2 — Produce the implementation/dependency manifest

Enumerate each family's components, selectors, delegates, storage, FactoryServices, package identities, generic reuse and registry discovery. No shared family-model dispatcher; generic primitives remain reusable (Z:357–361,495). Map ordinary previews, transition quotes, SY, Multi, imports and consumers to execution semantics and availability. Preserve source-agnostic pretransfer and complete local booking rather than rebuilding the old flawed reserve derivation (Z:393–445).

## 3. Verification gates—not human-policy questions

**Production provenance:** The local constants are observable: `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:37,169,441` records chain 4663, canonical manager and hook `0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044`. That does not prove deployed runtime matches the Pons reference. Capture deployed runtime/source equivalence, relevant immutable bindings, manager agreement and relevant mutable-state/fee behavior. Label hermetic evidence separately from production evidence (Z:365,377–387,475).

**Behavior and integration:** Establish independent arithmetic/accounting checks, quote/execution parity, supported-route domains, invalid-route-before-funding behavior, mixed decimals/native mapping, hostile callbacks, fee attribution, repeated repair/no-churn and booked-inventory negatives. Exercise real registry-deployed proxies, not mocks. Canonical `lib/crane/.claude/skills/crane-testing/SKILL.md:151–171` requires target-derived selector/package/proxy coverage; `.claude/skills/indexedex-testing/SKILL.md:144–163` requires parity and current artifact builds. Z:451–480 is the release acceptance map, not evidence it passed.

## 4. Documentation and removal

Reconcile old co-located law without treating old “open questions” as new owner decisions. For example, `U/v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md:291–301` retains older questions/preservation language; Z:95–97 establishes supersession.

Prepare the exact legacy file/reference/removal manifest and rehome still-needed generic dependencies. Preserve both new subtrees, historical revisions/provenance and regression assertions. Record both replacements' audit-submission readiness **before** removal, then rebuild artifacts and rerun replacement/consumer suites on the **post-removal revision** (Z:85–93,496). No deletion is authorized in this research pass.

## Highest-priority next step and confidence

Author the §6.4 source/formula matrix as the first implementation-plan work product, while preparing the parallel runtime-provenance evidence checklist. Then lock arithmetic/accounting and family manifests; do not ask the owner to select every helper or selector behavior already governed by the rules.

**Confidence:** High on policy closure and cited source distinctions; medium on eventual route coverage because the exhaustive formula inventory and validation have not been performed. Deployed-runtime equivalence, practical execution budgets and final audit-readiness remain unproven. No tests, security guarantee or mathematical nonexistence claim is made.

**Saved:** `docs/research/uniswap-v4-open-items-2026-09-27/ASTRA_ORIGINAL.md`.
