# Stage 02 — Multi-Vault Weighted DETF — Phase 1 Protocol Compound

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **02** |
| **Phase** | **Phase 1** — protocol seigniorage compound |
| **Family** | Multi-vault weighted (`composed/multi-vault-weighted/`) |
| **This file is the sole implementation scope** | Do not implement Phase 2 or other families |
| **Depends on** | Stage **00** green; **prefer Stage 01 green** (copy pathfinder patterns) |
| **Blocks** | Stage **07** (this family’s Phase 2) |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) §3, C1–C8 |
| **Sell/claim law** | [`BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md`](../../../../../contracts/vaults/detf/protocols/dexes/balancer/v3/BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md) (mature-only sell/close, 4626 `buyClaim`) |
| **Gold TestBase** | [`composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol`](./composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol) |
| **Pathfinder reference** | [`01_SingleStandardExchangeDETF_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md`](./01_SingleStandardExchangeDETF_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md) |

**Conforms to product law; no re-litigation.** Copy Stage 01 semantics; specialize multi-leg reserve join only.

---

## 1. Goals / non-goals

### Goals

1. Same product law as Stage 01: detf-NFT rewards → **single-sided DETF join** → detf-owned BPT ↑.
2. Reuse family existing `_joinReserveDetfOnly` (see `MultiVaultWeightedDetfExchangeOutTarget`).
3. Lazy `_tryCompoundProtocolRewards` + required public `compoundProtocolRewards()`.
4. Best-effort join failure; user routes stay claimable for user/fee NFTs.
5. C1–C8 green on multi-vault TestBase (claim package if wired).

### Non-goals

- Expansion; changing multi-leg mint/burn routing; balanced compound; other families.

---

## 2. Current state audit

| Item | Location |
|------|----------|
| Inventory mint | `MultiVaultWeightedDetfExchangeInTarget` — `_mintDetf(address(s.bondNftVault), split_.inventoryDetf)` |
| DETF-only join | `MultiVaultWeightedDetfExchangeOutTarget._joinReserveDetfOnly` |
| Bonding | `MultiVaultWeightedDetfBondingTarget.sol` |
| Common | `MultiVaultWeightedDetfCommon.sol` |
| Tests | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/` |

---

## 3. Implementation design

Mirror Stage 01:

| Concern | Multi-vault action |
|---------|-------------------|
| Join primitive | Existing `_joinReserveDetfOnly(detfAmount_)` |
| Compound orchestration | `_tryCompoundProtocolRewards` in Common or Bonding-adjacent internal |
| Lazy hooks | After inventory mint; bond paths; public entry |
| Facet selectors | `MultiVaultWeightedDetfExchangeInFacet` (or Info) — bump arrays + IFacet test |
| Claim | Existing claim tests under `MultiVaultWeightedDetf_Claim.t.sol` — extend for rate after compound |

Do **not** join vault-share legs for compound (PRD: DETF self-leg only).

---

## 4. Files to touch

| File | Action |
|------|--------|
| `MultiVaultWeightedDetfCommon.sol` | compound internals |
| `MultiVaultWeightedDetfExchangeInTarget.sol` | lazy hook |
| `MultiVaultWeightedDetfBondingTarget.sol` | lazy hooks |
| `MultiVaultWeightedDetfExchangeOutTarget.sol` | visibility if needed |
| `MultiVaultWeightedDetfInfoTarget.sol` | public API if info-scoped |
| `MultiVaultWeightedDetfExchangeInFacet.sol` | selectors |
| `TestBase_MultiVaultWeightedDetf.sol` | compound test helpers |
| New `MultiVaultWeightedDetf_ProtocolCompound.t.sol` | C1–C8 |

---

## 5. Test plan

Map **C1–C8** identically to Stage 01 with multi-leg reserve live after first bond / `initializeReserve` family path.

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/*ProtocolCompound*' -vvv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' -vv
```

**C5:** Use claim suite if claim package is part of gold TestBase; otherwise document N/A for claim rate and still prove detf NFT BPT ↑.

---

## 6. Acceptance

PRD C1–C8 for this family; existing multi-vault suites green.

---

## 7. Definition of Done

- [x] Green tests + program index Stage 02
- [x] No divergence from Stage 01 product semantics (only wiring/join index differences)

**Shipped 2026-07-29:** `_tryCompoundProtocolRewards` / `compoundProtocolRewards` / atomic pull pattern on MultiVaultWeightedDetf; lazy hooks on mint + bond + sell; facet selectors + C1–C8 suite green.
