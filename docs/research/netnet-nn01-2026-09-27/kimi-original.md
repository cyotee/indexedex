# Kimi K3 — ORIGINAL: NN-01 Dependency and evidence manifest, explained with closure proposal

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`, variant high) — routing metadata only, not provider attestation |
| Date | 2026-09-27 |
| Round | Bounded follow-up, item NN-01 only. No peer outputs from this new round read. Prior session history retained. |
| Sources read this round | `PRD_OPEN_QUESTIONS.md` (full, NN-01 at lines 44, 67–72); re-used prior full reads of PRD v0.23 §§4.1/8/12.1/16, CLAUDE.md; `lib/crane/.claude/skills/crane-deployment/SKILL.md` (new this round) |
| Scope | Explanation + resolution suggestions only. No PRD edit, no code, no RPC, no live-chain claims. |

## 1. NN-01 in plain English

**The problem.** The PRD says what the system must do, and it names many things the system will be wired to: real tokens (NET, sNET, USDG), a real Uniswap V2 pool, real NetNet contracts (Staking, BondDepository), a real Pendle factory/market/router/SY, an existing fee oracle, and existing math/bond/vault code to reuse. Right now those names appear scattered across §§4.1, 8, 12.1 and the §16 evidence register, and they sit at very different levels of certainty:

- Some are **design decisions** ("the fee oracle address goes in PkgInit and never changes").
- Some are **local source inspections** ("we read `BondDepository.sol` and vesting is 2 days") — true of files on disk, not proven true of what is deployed on chain 4663.
- Some are **unverified live claims** (the pair address `0x59F9…B54`, current tax/exemption state, actual SY implementation).
- Some are **things that don't exist yet** (the custom hook, custom SE, sNET-DETF, NFT) and therefore cannot have addresses today.
- Some **change over time** (the Pendle market and SY change at rollover; `feeTo()` rotates; tax exemptions queue and activate).

NN-01 says: before anyone writes an executable plan, produce **one manifest** that lists every such dependency, states exactly where its value comes from, and states what evidence exists versus what is still only assumed — without pretending a local file read is an on-chain fact, and without demanding that deployment happen before design is allowed to finish.

**Why it is G1 (do first):** NN-02 (note liveness), NN-04 (duration terms), NN-10 (SY provider) and NN-13 (authority) all quote facts about these dependencies. If the manifest is wrong or vague, every downstream item inherits the error.

## 2. What is already selected (dependency taxonomy from the operative PRD)

**PkgInit — fixed at Package construction, immutable (PRD §4.1, R55):** existing Robinhood-chain Vault Fee Oracle; NET; sNET; USDG; canonical NET/USDG V2 pool; trusted Pendle Market Factory; custom NetNet V2 SE. These are *configuration slots*: the PRD fixes the slot and its immutability, not yet the verified live value.

**PkgArgs — three instance addresses:** initial Pendle Market; NetNet Bond Depository (shared by purchase and claims); NetNet Staking (distinct from sNET and sNET-DETF).

**Discovered, never caller-supplied:** PT/YT/SY from the factory-validated market (§4.1, §11); market reserves/index/fee state; oracle terms (bond terms, seigniorage p/f/c, usage fees) resolved per §7.2's three-tier rule; current `feeTo()`.

**New custom components (no addresses exist today):** custom Weighted-behavior V4 hook (CREATE2, flag-constrained — hook flag mining, distinct from the DETF instance salt), NET-DETF proxy (CREATE3, fixed salt "NET-DETF"), sNET-DETF rebasing child, NFT child, custom NetNet V2 SE instance, reusable SY rate provider, TWAP series implementation. Addresses are *computable/predictable* at deploy time (CREATE3/CREATE2), so the manifest records derivation method and post-deploy verification, not live facts.

**Source-reference pins (revisions, not addresses):** Balancer `BasePoolMath.sol:277–342` + vendored `WeightedMath.sol`; the Weighted wrapper math/target; the `DETFFundedBondTarget`/`UniswapV4DetfCommon`/`DETFMintSplitLib`/`DETFBondNFTMathLib` bond chain; `UniswapV2StandardExchangeDFPkg` baseline; `BasicVaultRepo`/`BasicVaultCommon`; Pendle router/static/market/YT sources (§7.1.2, §11.4, §16 — currently *unpinned* local snapshots, YT v6 / market v7, pragma `^0.8.17`, net vendor snapshot 2026-08-28).

## 3. The five evidence classes the manifest must keep separate

| Class | Examples | What "closed" means |
| --- | --- | --- |
| **A. Fixed source/interface design** | Repo commit hash of the working tree; vendored Pendle/Balancer revisions; interface/ABI expectations per dependency; the PkgInit/PkgArgs/discovery table itself | Citable now. A git commit hash + file:line is a real pin; a pragma, package name or "main/master" link is not |
| **B. Live deployment verification** | Pair `0x59F9…B54` tokens/factory/fees (§8 "verify before implementation"); NET `taxEnabled`/exemption live state (queued vs active, 2-day delay); depository vesting (2-day code vs 5-day prose, §12.1); actual SY conversion/`getTokensOut`; factory recognition of the initial market; deployed code hash vs local source | Cannot close at design time. Close by writing, per fact: method (named RPC call / verified-source match), acceptance predicate, observation block field, and blocking-gap status if unobtainable |
| **C. New components without addresses** | Hook, DETF, sNET-DETF, NFT, custom SE | Close with: deploy path (factory, salt/flag derivation), predicted-address computation method, post-deploy verification step. Absence of an address today is expected, not a gap |
| **D. Rollover-changing dependencies** | Active market, PT/YT/SY | Close with a *re-validation procedure* (factory-first recognition, token-relationship checks per §11) invoked at every rollover — not a one-time pin. SY is deliberately not Package-immutable |
| **E. Dynamic external state** | `feeTo()`, p/f/c, usage fees, tax enabled/exemption membership, bond terms min/max, oracle TWAP windows | Close by recording the *resolution rule* (who is authoritative, when read, three-tier fallback, zero-as-unset) plus an observation-block field. Values are sampled at execution, never frozen into the manifest |

Mixing these classes is the failure mode NN-01 exists to prevent: class B facts masquerading as class A pins, or class E values hard-coded as if class A.

## 4. Recommended closure criteria (no false certification, no deployment-before-design)

1. **Two-tier manifest artifact.** *Tier 1 (design-time):* one dependency table — role, class A–E, source of truth (PkgInit / PkgArgs / validated discovery / computed deploy / dynamic oracle), source-revision pin (commit hash + file:line), required capabilities (e.g., "SY must list NET and sNET in `getTokensOut`"). *Tier 2 (pre-deployment checklist):* every class-B fact with verification method, acceptance predicate, observation-block placeholder, and OPEN/BLOCKED status.
2. **NN-01 closes on Tier 1 completeness + Tier 2 enumeration.** Tier 2 *execution* is scheduled pre-deployment work, explicitly pending — recording it is not claiming it passed (tracker line 21 already states this principle).
3. **Explicit blocking gaps are valid closure content.** E.g., "deployed NetNet SY conversion unverified — blocks NN-10 until RPC/source-match evidence exists." A named gap satisfies the tracker's "cited evidence or an explicit blocking gap" rule.
4. **Every pin carries provenance:** repo commit hash for local files; vendor snapshot date + upstream URL + upstream commit where known for vendored trees; "unverified" label otherwise.
5. **Nothing in the manifest asserts deployed equivalence, live fees, live exemption state, or Robinhood bytecode identity with inspected source** until Tier 2 evidence exists.

## 5. Proposed PRD wording — **UNAPPROVED DRAFT** (council proposal; no PRD edit made)

> **§4.1.1 Dependency and evidence manifest (new).** Before executable planning, the integration specification author SHALL publish a dependency manifest with two tiers. Tier 1 records, for every dependency: role; evidence class (fixed source/interface design; live deployment verification; new component; rollover-changing; dynamic external state); source of truth (PkgInit, PkgArgs, validated market discovery, computed deployment, or dynamic oracle resolution); a source-revision pin as repository commit hash with file and line range; and required capabilities. Tier 2 records, for each live-deployment fact: verification method, acceptance predicate, observation-block field, and status (verified / open / blocked). Class values MUST NOT be conflated: a package name, token symbol, pragma, historical address or unpinned `main`/`master` link is not a release pin; a local source inspection is not deployed-chain equivalence; a resolved oracle value at one block is not a configuration constant. Rollover-changing dependencies (market, PT/YT/SY) are pinned by re-validation procedure, not by address. New custom components are recorded by deployment path, salt/flag derivation and post-deploy verification step. The manifest closes NN-01 when Tier 1 is complete and every Tier 2 item carries evidence or an explicit blocking gap; Tier 2 execution remains separately scheduled pre-deployment work and is not certified by this record.

## 6. Narrow human checkpoint

**One question only:** *"Is the five-class dependency taxonomy and the two-tier closure rule (manifest closes on design-time completeness + enumerated live-verification checklist, with explicit blocking gaps allowed) acceptable as the NN-01 closure standard?"* This approves a documentation standard, not any address, parameter or economic value. Per the tracker, a further owner trigger arises only if the manifest reveals a required dependency/capability that is unavailable or materially different — that would return as a separate, specific proposal.

## 7. Metadata and limits

Model metadata is observable routing only (`kimi-code-plan-global/k3`), not provider verification. No Context7/external lookups were needed this round — NN-01 makes no new external library claims; the only external claim referenced (Pendle SY preview warning) was verified against primary docs earlier this session (2026-09-27). No live addresses are asserted; `0x59F9…B54` is quoted as the PRD's own unverified claim. All local file facts cited were read directly this session or in the immediately prior rounds of this preserved session. No missing reads occurred. This document proposes wording; it does not authorize edits, code, tests, RPC calls or deployment.
