# Stage 08 — Mixed-Buffer Multi-Vault Stable DETF — Phase 2 Natural Supply Expansion

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **08** |
| **Phase** | **Phase 2** — natural supply expansion |
| **Family** | Mixed-buffer multi-vault stable |
| **This file is the sole implementation scope** | |
| **Depends on** | Stage **03** green; Stage **05** green; **prefer Stage 06 green** |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) §4, E1–E9 |
| **Pathfinder** | Stage 06 Single SE expansion plan |
| **Gold TestBase** | [`composed/stable/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol`](./composed/stable/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol) |

**Conforms to product law; no re-litigation. Phase 1 must stay green. Buffer burn routes unchanged.**

---

## 1. Goals / non-goals

Same as Stage 06 product goals. **Do not** alter buffer-only burn, bootstrapFirstBond economics, or Open/Policy threshold law beyond expansion gating.

---

## 2. Implementation

| Piece | File |
|-------|------|
| PkgArgs + resolve | `MixedBufferMultiVaultStableDetfDFPkg.sol` |
| Storage | `MixedBufferMultiVaultStableDetfRepo.sol` |
| Accrual mint-on-update | `MixedBufferMultiVaultStableDetfCommon.sol` |
| Call sites | ExchangeIn, Bonding (post-live), compound |
| Live gate | Expansion only when reserve live (after bootstrap) |
| Tests | `MixedBufferMultiVaultStableDetf_NaturalExpansion.t.sol` |

Formula: **only** `DETFNaturalExpansionLib`.

Synthetic richness: use `MixedBufferMultiVaultStableDetf_PriceShift.t.sol` / pool trade patterns.

---

## 3. Test plan

E1–E9; include Open deploy row (E2); catch-up cap (E8); ProtocolCompound regression (E9).

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/*NaturalExpansion*' -vvv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/*ProtocolCompound*' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**' -vv
```

---

## 4. Acceptance

E1–E9; Phase 1 C1–C8 green; MixedBuffer routes unchanged.

---

## 5. Definition of Done

- [x] Green + program index Stage 08
