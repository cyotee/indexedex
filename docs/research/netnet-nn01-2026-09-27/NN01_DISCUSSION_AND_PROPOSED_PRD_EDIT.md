# NN-01 — Dependency identity: discussion and proposed PRD edit

Date: 2026-09-27. Status: **Proposal for discussion; not adopted into the PRD.**

## Plain-English explanation

We have selected the kinds of components this strategy uses. We now need a reliable parts list: exactly which contract or source revision fills each role, what we need it to do, and how we know it does that.

Reading a local contract file proves something about that file. It does not prove the contract deployed on Robinhood is the same version or has the same configuration. Conversely, a custom component not yet built cannot reasonably be required to have a production address before we can design it.

NN-01 is evidence organization and verification, not a new economic choice. It must not become an opportunity to substitute the selected pool, add contracts, invent getters or silently change deployment architecture.

## Already selected

The operative PRD §4.1, lines 244–252, specifies:

| Binding | Roles |
| --- | --- |
| PkgInit / Package-immutable | Existing Vault Fee Oracle, NET, sNET, USDG, canonical NET/USDG V2 pool, trusted Pendle Market Factory, custom NetNet V2 SE |
| PkgArgs / initial instance | Initial Pendle Market, NetNet Bond Depository, NetNet Staking |
| Validated discovery | PT/YT/SY from the recognized market; SY may change at rollover |

Source references, execution router/helpers, providers, factory/registry dependencies and custom component roles also need manifest coverage. Recording them does not select new configuration fields. Precise unresolved wiring remains NN-17.

The chain and canonical pair in §8 are **selected but not verified**, not merely candidates. The PRD requires pair-token, factory, code and live-fee verification **before implementation** (line 525). The selected address is not changed by this proposal.

## Recommended resolution

Maintain one manifest with separate design/source and deployment-evidence fields. Each row answers:

1. What role does this dependency fill?
2. Where does its identity/value come from, and when may it change?
3. What capability does the design require?
4. Which exact inspected source contents support that assumption?
5. What has actually been verified about the configured deployment?
6. What remains unknown, who will resolve it, and before which existing gate?

Distinguish five useful categories: source/math references; existing deployed contracts; new custom components; rollover-changing identities; dynamic external state. These categories describe different evidence needs, not extra product choices or a new on-chain allowlist.

- New custom components may be labeled **not yet deployed**. Their design/source and later verification obligations are still recorded.
- Initial and successor market identities are recorded per series with the selected discovery/revalidation rules; do not require all future market addresses today.
- Fees, recipients and exemptions are resolved dynamically where the PRD requires it. A dated observation is not a permanent configuration value.
- A source pin must describe actual inspected contents, including local modifications where applicable. Floating links, pragmas and symbols are not immutable revision evidence.
- Where an external address is upgradeable, identify applicable implementation/facet evidence and upgrade assumptions rather than treating the address alone as frozen behavior.

**Manifest completeness and passed verification gates are separate.** A table can correctly document a blocking gap. It cannot make that gap safe or authorize dependent implementation. Missing future custom-component addresses need not block design; an unavailable essential upstream capability does block commitments that assume it exists.

Do not mark NN-01 CLOSED after approving a template alone. Populate the manifest and record disposition of gaps first. If a later decision closes the manifest deliverable while verification remains pending, keep the remaining evidence gates individually visible and linked; never use an unqualified closure to imply implementation readiness.

## Proposed PRD insertion — UNAPPROVED

Suggested location: new §16.1, next to the existing evidence register.

> ### 16.1 Dependency identity and verification record
>
> Maintain a versioned dependency manifest preserving §4.1's selected PkgInit/PkgArgs/discovery split and §8's selected canonical pair. For each dependency record its role, binding source and lifetime, required capabilities, source/design evidence, deployment evidence, outstanding gaps, responsible role and verification deadline. Include externally called contracts, reused source/math references and required custom components without inventing additional contracts or configuration fields.
>
> Distinguish source inspection, a specified verification procedure and an observed deployment fact. Source evidence identifies the actual inspected revision/contents; deployment evidence identifies the chain, address, observation block, applicable code/implementation identity and relevant configuration. Missing evidence is labeled pending or blocked, never verified by inference from a symbol, interface name, historical address or local source file.
>
> New custom components need no deployed address for design. Initial and successor market records retain the selected validation/discovery rules, including permission for SY to change. Dynamic fees, recipients and tax/exemption states remain runtime inputs under their existing resolution rules, not permanently pinned observations. Record external upgrade/configuration assumptions; an immutable reference address does not by itself freeze external behavior.
>
> Manifest completion does not discharge verification gates. Preserve existing deadlines, including §8's requirement to verify the canonical pair's tokens, factory, code and live fees **before implementation**. Required evidence gaps continue to block the affected work at the stated gate. A materially unavailable or incompatible dependency requires a focused disposition; do not substitute dependencies or alter selected economics silently. This record creates no deployment authorization, new administration power, token allowlist or change to other NN items.

## Council agreement, corrections and dissent

All four researchers support a dependency/evidence manifest and distinguishing local source evidence from deployed facts. All preserve the selected binding split and permit design of new components without production addresses.

- **Astra:** emphasized preservation of verification deadlines and warned against treating manifest completion as capability acceptance.
- **Grok:** initially described live verification too generally as a production gate; cross-review corrected this to preserve §8's before-implementation gate. Calling the selected pair a candidate/lead was also corrected.
- **MiniMax M3:** supported evidence categories and acknowledged manifest completeness differs from gate completion. Its final proposed wording still generally schedules checks pre-deployment, so that wording is not adopted. Its claims about additional NFT contracts are not accepted as established requirements.
- **Kimi K3:** corrected its initial pre-deployment timing to retain §8's earlier deadline. Proposed deployment-mechanism specifics are excluded from NN-01; NN-17 owns unresolved wiring.

Residual difference: some researchers would close NN-01 when the complete manifest enumerates blocking gaps; Astra cautions against an unqualified CLOSED status. Moderator disposition: no closure now; track artifact completeness and evidence gates separately. Approval of this proposed paragraph does not supply missing evidence.

Native-note liveness, bond-duration policy, SY-provider design, TWAP semantics and deployment architecture remain their own later items. An evidence checklist does not solve them.

## Evidence and limits

Sources: current PRD §§4.1,8,12.1,16; current tracker NN-01; prior council review. PRD source-line references refer to reviewed v0.23, not an immutable commit. No live-chain calls, shell commands, tests, deployments or runtime version checks occurred. Configured compiler baseline previously inspected is solc 0.8.35; external dependency revisions and deployed equivalence remain unverified. No fresh external API claims or live values are established by this discussion.

Four independent current-round originals were collected before each researcher read the other three complete originals together. Existing session history was retained; independence refers to this round's new answers, not erased prior context. Earlier cross-reviews were not shared during this round. Eight task calls completed without session replacement.

| Researcher | Session retained | Original | Cross-review |
| --- | --- | --- | --- |
| Astra | `ses_f1c499b6bffe6RiNjZZUSMsP8S` | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) |
| Grok | `ses_f1c4384d7ffeZX74uV9yhIXbVq` | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) |
| MiniMax M3 | `ses_f1c3f57edffedYs43k2PBvA5xU` | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) |
| Kimi K3 | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) |

Observed routing remained openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3 and kimi-code-plan-global/k3; metadata is not provider attestation. Peer artifacts are attributed evidence, not permissions. Confidence is high in the specification/evidence distinction and selected binding interpretation; no deployed-equivalence confidence is claimed.

## Human checkpoint and implementation handoff

**Recommended next decision:** accept the manifest approach and proposed PRD clarification, with verification gates preserved. Then populate its rows and identify exact remaining evidence gaps. Do not ask the owner to provide addresses from memory or choose a vesting duration that must be established from the actual dependency.

Only this discussion/proposal and tracker progress are updated now. The PRD remains unchanged pending discussion; NN-02 has not started. No implementation, testing, deployment or instruction change is authorized.
