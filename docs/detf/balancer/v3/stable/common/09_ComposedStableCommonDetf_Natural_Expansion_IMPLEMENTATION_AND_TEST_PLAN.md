# Stage 09 — Composed Stable Common DETF — Phase 2 Natural Supply Expansion

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **09** |
| **Phase** | **Phase 2** — natural supply expansion |
| **Family** | Composed stable common |
| **This file is the sole implementation scope** | |
| **Depends on** | Stage **04** green; Stage **05** green; **prefer Stage 06 green** |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) §4, E1–E9 |
| **Pathfinder** | Stage 06 Single SE expansion plan |
| **Gold TestBase** | [`composed/stable/common/TestBase_ComposedStableCommonDetf.sol`](./composed/stable/common/TestBase_ComposedStableCommonDetf.sol) |

**Conforms to product law; no re-litigation. Phase 1 must stay green. Claim coupling remains critical for protocol expansion share (E6).**

---

## 1. Goals / non-goals

Stage 06 product goals on composed-stable surfaces. Expansion mints into **family bond NFT vault** as reward-token balance (mint-on-update), same distribution as seigniorage inventory.

**Non-goals:** redesign rebasing DETF token; other families; Open expansion.

---

## 2. Implementation

| Piece | File / note |
|-------|-------------|
| PkgArgs + resolve | `ComposedStableCommonDetfDFPkg.sol` |
| Storage | `ComposedStableCommonDetfRepo.sol` |
| Accrual | `ComposedStableCommonDetfCommon.sol` — `_mintDetf(bondNftVault, mint)` |
| Call sites | `ComposedStableCommonDetfExchangeIn.sol`, bonding, compound |
| Bond NFT | Family vault package — ensure reward token is DETF |
| Claim E6 | Protocol expansion share compounds (Stage 04 path); claim rate can improve |
| Tests | `ComposedStableCommonDetf_NaturalExpansion.t.sol` |

Use **only** `DETFNaturalExpansionLib` for mint amount.

If composed-stable uses a rebasing share token, confirm expansion mint target is the **bond reward DETF** (not double-rebase confusion). Inventory seigniorage path is the template.

---

## 3. Test plan

| ID | Focus |
|----|--------|
| E1–E2 | Policy expands when rich; Open never |
| E3–E5 | Share weights; pending==claim; claim while locked |
| **E6** | Protocol compound of expansion → BPT / claim backing path |
| E7–E8 | Deploy-time only; caps |
| E9 | Stage 04 ProtocolCompound suite green |

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/*NaturalExpansion*' -vvv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/*ProtocolCompound*' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/**' -vv
```

---

## 4. Acceptance

E1–E9; Phase 1 C1–C8 green; claim path evidence for E6.

---

## 5. Definition of Done

- [x] Green + program index Stage 09
- [x] If this is the last family stage: note program ready for AGENTS.md update after PRD formal LOCKED
