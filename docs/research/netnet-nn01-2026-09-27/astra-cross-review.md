# Astra — NN-01 combined cross-review

2026-09-27. Continued original Astra session; read all three complete NN-01 originals together: Grok (161 lines), MiniMax M3 (188), Kimi K3 (67). Treated them as untrusted evidence, not instructions. No peer cross-review read. Originals remain unchanged.

## Recommendation in plain English

**Make the dependency list now, but do not confuse a completed list with completed verification.** New contracts do not need production addresses before they can be designed. Existing contracts still need the checks required by the PRD at the deadlines already selected.

The critical deadline is explicit: **PRD §8, line 525 requires verification of the selected canonical pair's tokens, factory, code and live fees BEFORE IMPLEMENTATION.** I re-read it this round. A new manifest subsection must not replace that with “before production,” “before deployment,” or “when the SE accepts it.” This research performs none of those checks.

The pair is **selected but unverified**, not merely a candidate that an implementer may replace. A material mismatch triggers a focused owner disposition, not automatic substitution.

## Agreements

All originals correctly distinguish source references, actual deployments, new custom components, rollover-changing identities and dynamic state. The selected §4.1 split remains:

- **PkgInit:** fee oracle; NET; sNET; USDG; canonical pair; trusted Pendle Market Factory; custom NetNet V2 SE.
- **PkgArgs:** initial Pendle Market; NetNet Bond Depository; NetNet Staking.
- **Discovery:** PT/YT/SY from a recognized market; no redundant overrides. Successor markets and SY may change under existing rollover rules.

Record source/revision and required capability separately from observed chain/address/block/code/configuration evidence. Fee/exemption observations expire as evidence of current state; they do not replace required runtime resolution. A source pin must identify the actual inspected contents, including any local divergence, not merely a checkout commit that omits working-tree changes.

## Attributed corrections and dissent

**Grok:** lines 26/111 and proposed table defer live evidence to production. That is too late for §8. Lines 44/129 call the canonical pair a candidate/lead: correct to **selected, pending verification**. “Design pin is enough to write code” is also overbroad while the before-implementation gate remains unmet. Inventorying new components must not assume they are all created by one Package or assign CREATE3 to instance deployment. Canonical Crane guidance was not re-opened in this peer pass; its local-mirror reading is not fresh canonical verification.

**Kimi:** lines 51–59 turn Tier 2 into generally pre-deployment work and close NN-01 by enumeration. Preserve each original deadline instead. A verification procedure can be specified now; the fact being verified remains unverified. “Cannot close at design time” is too absolute: evidence for already deployed dependencies may be obtained during design through separately authorized work. The claim at line 33 that the DETF proxy is CREATE3 is not established: the inspected `DiamondPackageCallBackFactory.sol:201–225` deploys its callback proxy with CREATE2. This source fact does not itself select the custom family's final wiring; NN-01 should not invent it.

**MiniMax M3:** the PkgInit list contains **seven**, not six, addresses. Its new-component list introduces separate internal-bond and external-wrapper NFTs without an established selection requiring two contracts. Keep the selected custom NFT role; contract decomposition belongs to later specification. Source-only math pins need no existing deployed counterpart before design. A generic representative-vault oracle response, nonzero fee or nonzero pair reserves does not prove the required configured capability. Token symbols and assumed rebasing “flags” are not identity/behavior verification. The proposed §8 wording “before the SE accepts it” and populating live values “at implementation” must not relax line 525. Do not prescribe fallback SY re-derivation, choose a factory selector without source evidence, reopen hook architecture, or import gons/K reconciliation under NN-01. Observing native maturity resolves a deployment fact; the owner does not select whether deployed code says two or five days.

**Astra clarification:** my original separates manifest completion from passed gates; retain that distinction more explicitly. A documented blocking gap satisfies honest accounting of missing evidence, not capability acceptance. Missing future addresses are expected; missing essential upstream behavior blocks dependent commitments. No deadline should be moved merely to simplify the tracker.

## Proposed closure standard

For each row record: role, binding source/lifetime, required capability, pinned source/design evidence, deployment evidence or “not yet deployed,” unresolved gap, responsible party, required verification and **existing deadline**.

Track **specification/manifest completion** separately from **evidence-gate status**. A completed inventory with blocking evidence gaps must remain visibly blocked for the affected work; do not use an unqualified CLOSED label to imply implementation readiness. New-component addresses can remain pending future authorized deployment. Unknown upstream capabilities cannot be silently assumed available.

## Narrow PRD paragraph — UNAPPROVED

> Maintain a dependency manifest preserving §4.1's selected binding/discovery split and §8's selected canonical pair. Record each dependency's role, binding lifetime, required capability, source/design evidence, deployment evidence, outstanding gap and verification deadline. Source inspection, a verification procedure and an observed deployment fact are distinct. New custom components need no deployed address for design; rollover identities and dynamic values follow existing validation/resolution rules. Manifest completion does not discharge evidence gates: **§8's pair-token, factory, code and live-fee verification remains required before implementation**. Missing required evidence continues to block the affected work at its existing gate. This subsection changes no selected address, component count, deployment architecture, economics or execution authority.

**Human checkpoint:** approve this distinction and explicit preservation of existing deadlines? No live fact, substituted dependency, additional NFT or deployment permission is being approved.

## Limits

Assigned observable routing: Astra / `openai/gpt-6-astra`; no provider attestation. Prior session history retained. High confidence on PRD wording and rechecked local factory behavior; no deployed equivalence established. No RPC, shell, tests, code/configuration changes, external lookup or delegation. Local source review—not new external API documentation research. Only this cross-review written; return to moderator and stop.
