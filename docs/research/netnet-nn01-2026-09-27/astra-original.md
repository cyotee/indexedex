# Astra — NN-01 original follow-up (2026-09-27)

## Plain-English explanation

**NN-01 means: write down exactly which external contracts and reference implementations this design relies on, what each must do, and how we know.** It is a dependency inventory with evidence—not a request to redesign the strategy or deploy it now.

Three statements must stay separate: “this is the interface we will support,” “this local source implements it,” and “this particular on-chain contract implements the same behavior.” None automatically proves the next. PRD §16 explicitly calls its current citations unpinned snapshots and historical market addresses leads, not an active-market selection (`931–966`).

## Already selected—not new configuration choices

| Binding class | Selected dependencies / treatment |
| --- | --- |
| Package configuration (`PkgInit`) | Existing Robinhood Vault Fee Oracle; NET; sNET; USDG; canonical NET/USDG pool; trusted Pendle Market Factory; custom NetNet V2 SE. Their addresses are Package immutables. |
| Initial instance configuration (`PkgArgs`) | Initial Pendle Market; NetNet Bond Depository, shared by purchase and claims; NetNet Staking, distinct from both staking tokens. |
| Validated discovery | PT, YT and SY from a factory-recognized market; not redundant caller overrides. Populate proxy Repos from validated configuration/discovery. |
| Reference/dependency inventory | Pendle execution router and required helpers, rate providers, V2 SE reference, Weighted/BasePoolMath revisions, plus factory/registry and custom-component dependencies. Record their binding source; NN-01 does **not** silently add PkgArgs fields or settle later wiring questions. |

Evidence: PRD `246–258`; canonical Crane architecture skill `136–157`; current CLAUDE `93–97`. The chain and canonical pair are already selected in PRD `525`; recording that address is not verifying it.

**Fixed address does not mean fixed behavior:** dependencies may have mutable configuration or external upgrade authority. Record those assumptions (`252`).

**Markets change:** the initial market is not an eternal address pin. Rollover can discover new PT/YT and a different SY under the fixed trusted factory. Preserve old-series identities and evidence; do not require future market addresses in today's manifest or create a new off-chain approval list (`705–725`).

**Runtime values change:** fee-oracle values, recipient resolution and NET exemption/tax predicates must remain runtime inputs where specified. An observation records what was true at a block, not a permanent fee or exemption guarantee. Canonical-pool tax queries belong to the custom SE, not the hook (`527–538`).

## Suggested practical resolution

Maintain one manifest with two evidence layers:

1. **Design/source baseline:** role, existing-versus-new component, binding source/lifetime, required interface/capabilities, repository path plus immutable revision or content digest, relevant configuration assumptions, evidence limitations, and downstream verification obligation. Distinguish copied/reference math from externally called contracts. A Solidity pragma or floating `main` link is not a revision pin.
2. **Deployment evidence:** for existing target contracts, record chain/address, observation block number/hash, runtime code identity, implementation/facet identities where applicable, configuration/token relationships/decimals, and provenance of the source-to-deployment comparison. A proxy code hash alone does not establish implementation behavior. For new components, record **NOT YET DEPLOYED**; add actual addresses/code evidence only after separately authorized construction and deployment. Predictions, if later available, remain labeled predictions.

For each capability, use separate statuses such as **required by design**, **source-evidenced**, **deployment-observed**, **execution-validation pending**, or **blocked**, with evidence and an assignee. These are proposed evidence labels, not new tracker states.

Record directional token support, native-note payment/claim ABI, maturity basis, and callback/claim behavior as evidence inputs. In particular, PRD `775–786` describes an observed ABI and a two-day local-code/five-day historical-prose discrepancy—not a verified deployed maturity. Capture that discrepancy; do not solve note liveness or duration policy under NN-01.

**Design closure:** every dependency has a defined role/binding, a pinned source/interface baseline or explicit deliverable for a new component, and a concrete verification gate. A genuinely unknown required upstream capability blocks the affected design assumption; it is not cured by naming a future test. New custom components need no production address before design.

**Deployment readiness is separate:** actual selected bindings require the specified checks before reliance/activation. Dynamic observations must be refreshed at their relevant use points. This does not authorize verification transactions or deployment now. PRD §8's existing before-implementation verification requirement for the canonical pool is not silently postponed; NN-01 must record it as pending if no authorized evidence exists.

The tracker currently says “close” with evidence **or an explicit blocking gap** (`PRD_OPEN_QUESTIONS.md:67–72`). Recommend distinguishing **manifest complete** from **dependency gate passed** so an honestly documented blocker never reads as deployment readiness. Until this disposition is accepted, NN-01 remains OPEN.

## Proposed PRD wording — UNAPPROVED

> ### NN-01 — Dependency identity and evidence
> Maintain a versioned dependency manifest preserving §4.1's selected PkgInit/PkgArgs/discovery split. For each dependency record its role, binding source and lifetime, required capabilities, pinned source/interface baseline, evidence status, configuration/upgrade assumptions, and unresolved verification obligations.
>
> Distinguish source evidence from deployment evidence and executed validation. Existing deployments require chain/address, observation block, applicable runtime/implementation identity and configuration evidence; unsupported equivalence claims are forbidden. New custom components may be specified before deployment and must be labeled not yet deployed.
>
> Initial and successor market evidence is series-specific; SY is discovered and may change through the selected rollover rules. Fee/exemption observations are dated snapshots, not frozen runtime values. This manifest adds no token allowlist, administration power or redundant configuration.
>
> Manifest completion does not clear recorded blockers. Preserve existing verification deadlines, including §8. Missing future custom-component addresses do not block design; unavailable required upstream capabilities block dependent commitments and require a focused disposition before reliance. Later deployment/execution remains separately authorized.

## Narrow human checkpoint

**Approve this two-layer evidence approach and the distinction between manifest completion and passed dependency gates?** No approval of new addresses, economics, deployments, or later NN items is requested. Return only material dependency/capability discrepancies for further owner decisions.

## Limits

Astra; assigned routing label `openai/gpt-6-astra`, not provider-verified. Prior session history retained; no new-round peer outputs read. Current CLAUDE, required PRD sections, tracker and canonical architecture/deployment/local hook-package guidance read directly on 2026-09-27. No read failures, RPC, shell, tests or external verification. No new external-library claims required documentation retrieval. Confidence: high on selected bindings and proposed evidence separation; deployed equivalence unverified. Only this report was written; no PRD edit or closure claimed.
