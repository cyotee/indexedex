# Stage 07 — Multi-Vault Weighted DETF — Phase 2 Natural Supply Expansion

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **07** |
| **Phase** | **Phase 2** — natural supply expansion |
| **Family** | Multi-vault weighted |
| **This file is the sole implementation scope** | |
| **Depends on** | Stage **02** green (family Phase 1); Stage **05** green; **prefer Stage 06 green** (pathfinder) |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) §4, E1–E9 |
| **Sell/claim law** | [`BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md`](../../../../../contracts/vaults/detf/protocols/dexes/balancer/v3/BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md) — new sell/close/`buyClaim` touches realize expansion |
| **Shared lib** | Stage 05 `DETFNaturalExpansionLib` |
| **Pathfinder** | [`06_SingleStandardExchangeDETF_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md`](./06_SingleStandardExchangeDETF_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Gold TestBase** | [`composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol`](./composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol) |

**Conforms to product law; no re-litigation. Phase 1 must stay green (E9).**

---

## 1. Goals / non-goals

Mirror Stage 06 goals for multi-vault weighted wiring only.

**Non-goals:** other families; changing multi-leg primary routes; expansion under Open.

---

## 2. Implementation

Copy Stage 06 pattern:

| Piece | Multi-vault file |
|-------|------------------|
| PkgArgs + resolve | `MultiVaultWeightedDetfDFPkg.sol` |
| Storage | `MultiVaultWeightedDetfRepo.sol` |
| Accrual + mint to bond vault | `MultiVaultWeightedDetfCommon.sol` |
| Call sites | ExchangeIn, Bonding, compound |
| Synthetic | Existing `_syntheticPrice()` + `_isMintingAllowed()` |
| Tests | New `MultiVaultWeightedDetf_NaturalExpansion.t.sol` |

Use **only** `DETFNaturalExpansionLib.computeExpansionMint` — no family formula fork.

---

## 3. Test plan

E1–E9 as Stage 06; use multi-vault price-shift / pool trade helpers already in suite (`MultiVaultWeightedDetf_PriceShift.t.sol` patterns).

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/*NaturalExpansion*' -vvv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/*ProtocolCompound*' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' -vv
```

---

## 4. Acceptance

E1–E9; Phase 1 C1–C8 still green.

---

## 5. Definition of Done

- [x] Green + program index Stage 07
