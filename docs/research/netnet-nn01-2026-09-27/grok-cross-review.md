# Grok NN-01 cross-review

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Inputs | Own original (untouched). Full `astra-original.md`, `minimax-original.md`, `kimi-original.md`. No peer cross-reviews. |
| Date | 2026-09-27 |

Peers treated as untrusted evidence.

---

## Agreement

All four: NN-01 is an **evidence inventory**, not new economics. **PkgInit / PkgArgs / factory-validated discovery** is already selected (R55, §4.1). **New family contracts need no 4663 address to design.** Symbols, pragmas, and unpinned `main` links are not release pins. Tax/`feeTo()`/oracle terms and successor SY are **rules + dated snapshots**, not frozen constants. Explicit **GAP** is valid tracker content. Do not invent live addresses.

Astra’s two layers (source baseline vs deployment evidence) match Grok DESIGN/CAPABILITY vs LIVE. Kimi A–E and MiniMax 3.1–3.4 are the same taxonomy with extra labels.

---

## Test of the closure standard (the live issue)

PRD §8: verify pair tokens, factory, code and live fees **before implementation**. The pair `0x59F95461…` is **SELECTED and unverified**. That is not an invitation to substitute another pool.

**Pass (Astra, Grok original intent):**  
**Manifest complete ≠ dependency gate passed.** Filling the table with labeled pending checks does not clear §8. New-component “NOT YET DEPLOYED” does not block design. A missing **capability** (required method absent) blocks dependent design. A missing **live hash** is a recorded obligation, not fake verification.

**Fail (Kimi §4.2):** “NN-01 closes on Tier 1 + **Tier 2 enumeration**; Tier 2 **execution** is pre-deployment.” Enumeration is a checklist, not a passed gate. Scheduling live work later **silently postpones §8 past implementation start**. Reject that as the closure rule.

**Fail (MiniMax §5.1 table):** rows such as oracle/pair with “none for closure” while no observation exists **pretend contents are verified**. The amendment must not ship filled LIVE values. MiniMax §5.5 “populate at implementation stage” also collides with §8’s **before implementation** deadline unless that stage is defined as **pre-code** verification.

**Grok original correction:** saying LIVE is only a “later **production** gate” is too late for the canonical pair. Keep: design of *other* NN items may continue with a labeled GAP. Do **not** treat family **implementation** as allowed until §8 evidence exists or the owner explicitly delays that deadline. Spec completion of the **schema** can still happen now.

---

## Corrections (do not carry)

| Source | Claim | Correction |
| --- | --- | --- |
| MiniMax | PkgInit “six addresses” then seven roles | Count is seven roles (oracle, NET, sNET, USDG, pair, factory, custom SE). |
| MiniMax | Hook “DFPkg vs monomorph remains open” inside NN-01 table | Deploy architecture is **NN-17**. NN-01 records a role + “created / not yet deployed,” not a factory choice. |
| MiniMax | Separate “bond NFT for internal bonds” plus wrapping NFT | Do not invent extra NFT contracts. PRD already has DETF-controlled NFT child + wrapping of native notes. |
| MiniMax | Invented `isValidMarket` call shape | Capability is “factory recognition before tokens” (§4.1). Exact selector is interface design, not a new ABI. |
| MiniMax | BondDepository row BLOCKED until duration read, then NN-02 inherits | NN-01 **records** 2-day code vs 5-day prose as GAP. Choosing duration / liveness is **NN-02**, not a hidden NN-01 product pick. |
| Kimi | CREATE2/CREATE3, flag mining, predicted addresses as NN-01 close | Derivation method may be **noted**; freezing hook-factory vs salt math is NN-17. Absence of predicted address is expected. |
| Kimi | Tier 2 enumeration closes NN-01 | Checklist ≠ passed §8 gate. |
| Anyone | Treat §8 address as optional / replaceable | **Selected.** Verify or owner-declared material discrepancy — do not substitute. |

MiniMax “does not close NN-02…NN-13” list is correct as **scope hygiene**.

---

## Spec complete vs evidence that blocks work

| Complete now | Still blocking (labeled, not pretended passed) |
| --- | --- |
| Role list, supply channel, DESIGN pin (path+revision), CAPABILITY list, change protocol for market/SY/fees | §8 pair/token/factory/code/fees **before implementation** |
| “Created” rows with no address | CAPABILITY gap (e.g. depository lacks assumed `deposit`/`redeem`) → owner trigger |
| Vesting 2d vs 5d recorded as unverified | Downstream **NN-02** must not assume either length until LIVE or owner |
| SY discovery rule | **NN-10** still needs conversion evidence; listing SY is not that proof |

Unresolved LIVE on oracle/staking/depository **does not** block writing the manifest. It **does** block claiming those bindings are production-ready. New hook/SE/sNET-DETF/NFT: **no deployed address required for design** (all four agree; keep).

---

## Plain-English recommendation

Accept **two-layer evidence** and **two statuses**:

1. **NN-01 specification complete** when every required role has DESIGN + CAPABILITY + LIVE-or-GAP, with no invented addresses and no extra PkgArgs.
2. **Dependency gate passed** only when cited LIVE evidence exists (or owner accepts a named blocker). **§8 remains a before-implementation gate** on the selected pair.

Do not close NN-01 by enumerating future RPCs. Do not put hook DFPkg, extra NFTs, or live tax bps into the PRD amendment.

**Human checkpoint (one question):** Approve manifest-complete vs gate-passed, and keep §8’s verify-before-implementation deadline on the **selected** pair? No addresses, fees, or later NN items.

---

## UNAPPROVED PRD paragraph (narrow)

*Not operative.*

> **§16.1 NN-01 evidence (draft).** Keep §4.1’s PkgInit / PkgArgs / discovery split. For each role record: binding source and lifetime; required capabilities; pinned source/interface (commit + path), or “created by this family / not yet deployed”; evidence status **required / source-evidenced / deployment-observed / blocked**; upgrade/config assumptions; remaining verification. Source inspection is not deployed equivalence. New custom components need no live address for design. Successor market/SY follow selected rollover discovery; fee/tax/`feeTo()` observations are dated, not constants. **Completing this table does not clear recorded blockers.** Preserve existing deadlines, including §8: the selected canonical pair `0x59F95461E68e0c77605299791E1449f175165B54` stays the pair; verify tokens, factory, code and live fees **before implementation**; do not substitute another pool because it is unverified. Unavailable required upstream **capability** blocks dependent commitments; missing custom-component addresses do not. Later execution remains separately authorized.

---

## Confidence / dissent

High: selected split; no-address-for-new-components; §8 must not be postponed by “enumeration.”  
Medium: MiniMax additive §4.1/`isValidMarket` text.  
Dissent: Kimi (and MiniMax’s “implementation stage” fill) vs Astra/Grok on whether listing live checks **closes** NN-01. Grok sides with Astra: **no**.

Originals unchanged. No PRD edit, RPC, or code.
