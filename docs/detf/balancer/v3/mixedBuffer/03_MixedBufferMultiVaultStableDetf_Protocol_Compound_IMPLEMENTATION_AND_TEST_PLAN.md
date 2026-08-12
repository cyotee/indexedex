# Stage 03 — Mixed-Buffer Multi-Vault Stable DETF — Phase 1 Protocol Compound

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **03** |
| **Phase** | **Phase 1** — protocol seigniorage compound |
| **Family** | Mixed-buffer multi-vault stable (`composed/stable/mixedBuffer/`) |
| **This file is the sole implementation scope** | Do not implement Phase 2 or other families |
| **Depends on** | Stage **00** green; **prefer Stage 01 green** |
| **Blocks** | Stage **08** |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) §3, C1–C8 |
| **Sell/claim law** | [`BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md`](../../../../../contracts/vaults/detf/protocols/dexes/balancer/v3/BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md) (mature-only sell/close, 4626 `buyClaim`; close has no `tokenOut`) |
| **Gold TestBase** | [`composed/stable/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol`](./composed/stable/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol) |
| **Pathfinder** | Stage 01 Single SE plan |
| **Family PRD** | [`composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_PRD.md`](./composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_PRD.md) — buffer burn rules **unchanged** by compound |

**Conforms to product law; no re-litigation.**

---

## 1. Goals / non-goals

### Goals

1. Protocol detf-NFT rewards → single-sided **DETF** join into MixedBuffer reserve → detf-owned BPT ↑.
2. Lazy + required `compoundProtocolRewards()`; best-effort join failure.
3. User/fee rewards remain claimable free DETF.
4. **Do not** change buffer-only burn, bootstrapFirstBond, or mint routes (PRD non-goal).
5. C1–C8 green.

### Non-goals

- Expansion; changing MixedBuffer route set; auto-compound user/fee; other families.

---

## 2. Current state audit

| Item | Location |
|------|----------|
| Inventory mint | `MixedBufferMultiVaultStableDetfBondingTarget` / ExchangeIn — `_mintDetf(address(s.bondNftVault), split_.inventoryDetf)` |
| Joins | Family helpers `_joinReserveBufferAndDetf`, `_joinReserveShareAndDetf`, and DETF-leg patterns in Common/targets — **add or reuse DETF-only unbalanced join** matching peer `_joinReserveDetfOnly` |
| Bootstrap | `bootstrapFirstBond` — do not break; compound after live preferred |
| Claim tests | `MixedBufferMultiVaultStableDetf_Claim.t.sol` |

**Audit action:** grep for DETF-only join; if missing, implement `_joinReserveDetfOnly` analogous to Single SE / multi-vault (prepay unbalanced DETF index only).

---

## 3. Implementation design

Same pipeline as Stage 01. Family-specific notes:

| Topic | Law |
|-------|-----|
| Reserve type | Stable / mixed-buffer pool — still **single-sided DETF join** (weight/amp skew accepted, PRD §9) |
| Bootstrap | First bond synthetically ungated; compound may no-op pre-live if no pending; once live + rewards, compound works |
| Buffer burn | Untouched |

Lazy hooks: mint, bond, bootstrap completion paths that deposit inventory, public compound.

---

## 4. Files to touch

| File | Action |
|------|--------|
| `MixedBufferMultiVaultStableDetfCommon.sol` | compound + optional `_joinReserveDetfOnly` |
| `MixedBufferMultiVaultStableDetfExchangeInTarget.sol` | lazy hook |
| `MixedBufferMultiVaultStableDetfBondingTarget.sol` | lazy hooks |
| `MixedBufferMultiVaultStableDetfInfoTarget.sol` | public API |
| `MixedBufferMultiVaultStableDetfExchangeInFacet.sol` | selectors |
| `TestBase_MixedBufferMultiVaultStableDetf.sol` | helpers |
| New `MixedBufferMultiVaultStableDetf_ProtocolCompound.t.sol` | C1–C8 |

---

## 5. Test plan

| Focus | Detail |
|-------|--------|
| Live path | `bootstrapFirstBond` → live → mint seigniorage → compound |
| C3 | Claim while locked |
| C5 | Claim package if in TestBase |
| C8 | Best-effort join failure |
| Regression | Existing mint/burn/bootstrap/routes suites |

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/*ProtocolCompound*' -vvv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**' -vv
```

---

## 6. Acceptance

PRD C1–C8; MixedBuffer product routes unchanged.

---

## 7. Definition of Done

- [x] Green tests + program index Stage 03

**Shipped 2026-07-29:** `_tryCompoundProtocolRewards` / `compoundProtocolRewards` / atomic pull pattern on MixedBufferMultiVaultStableDetf; lazy hooks on mint + bond + bootstrap + sell; facet selectors + C1–C8 suite green.
