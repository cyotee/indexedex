# Stage 06 — Single Standard Exchange DETF — Phase 2 Natural Supply Expansion

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **06** |
| **Phase** | **Phase 2** — natural supply expansion |
| **Family** | Single Standard Exchange — **pathfinder** |
| **This file is the sole implementation scope** | Do not implement other families; do not weaken Phase 1 |
| **Depends on** | Stage **01** green (this family Phase 1); Stage **05** green (expansion lib) |
| **Blocks** | Preferred pattern source for Stages 07–09 |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) §4, E1–E9 |
| **Sell/claim law** | [`BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md`](../../../../../../contracts/vaults/detf/protocols/dexes/balancer/v3/BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md) — new sell/close/`buyClaim` touches realize expansion |
| **Shared lib plan** | [`05_DETF_Natural_Expansion_Shared_IMPLEMENTATION_AND_TEST_PLAN.md`](./05_DETF_Natural_Expansion_Shared_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Gold TestBase** | [`standardExchange/single/TestBase_SingleStandardExchangeDETF.sol`](./standardExchange/single/TestBase_SingleStandardExchangeDETF.sol) |

**Conforms to product law; no re-litigation.**  
**Phase 1 suite must remain green (E9).**

---

## 1. Goals / non-goals

### Goals

1. While **live + Policy + synthetic mint-allowed**, accrue natural expansion by **minting free DETF into bond NFT vault** (mint-on-update) so `rewardPerShares` distributes like seigniorage.
2. **Open** instances never expand.
3. Preview `pendingRewards` / claim includes expansion after update (E4).
4. Users claim expansion while bond locked (E5).
5. Protocol’s expansion share compounds via Phase 1 path (E6).
6. Deploy-time expansion params on `PkgArgs` → storage only (E7).
7. Idle catch-up respects lib caps (E8).

### Non-goals

- New stake surface; fee-oracle expansion control; fixed-APY default (premium-closure only); other families.

---

## 2. Storage / PkgArgs

Append deploy-time fields (trailing; zeros resolve via `DETFNaturalExpansionLib.resolveExpansionParams`):

```solidity
// PkgArgs (additive)
uint256 expansionClosureRatePerSecond; // 0 → default
uint256 expansionCatchUpMaxSeconds;    // 0 → default
uint256 expansionCatchUpCapBps;        // 0 → default
```

```solidity
// Repo Storage
uint256 expansionClosureRatePerSecond;
uint256 expansionCatchUpMaxSeconds;
uint256 expansionCatchUpCapBps;
uint256 lastExpansionTimestamp; // set to block.timestamp at live transition or first accrual
```

**Open mode:** still store resolved params if desired; **gates ignore them** (never mint expansion).

**Init:** resolve + validate in DFPkg `initAccount`; no post-deploy setter.

---

## 3. Runtime wiring

### 3.1 `_updateExpansionMintOnRewards()` (internal)

```text
in_ = AccrualInput{
  isLive: s.isReserveLive,
  isPolicyMode: s.thresholdMode == ThresholdMode.Policy,
  isMintAllowed: _isMintingAllowed(), // live+mode+synthetic already in Common
  syntheticPrice: _syntheticPrice(),
  totalDetfSupply: totalSupply(),
  lastExpansionTimestamp: s.lastExpansionTimestamp,
  nowTimestamp: block.timestamp,
  ...resolved rates...
}
mint, newTs = DETFNaturalExpansionLib.computeExpansionMint(in_)
if mint > 0:
  _mintDetf(address(s.bondNftVault), mint)
  s.lastExpansionTimestamp = newTs
  // optional event NaturalSupplyExpanded(mint, synthetic, newTs)
```

Call **before** or **with** global reward updates that should see new balances; then `_tryCompoundProtocolRewards()`.

### 3.2 Call sites (minimum)

| Site | Notes |
|------|-------|
| `_tryCompoundProtocolRewards` / public compound | Ensure expansion catches up when someone compounds |
| Capital-backed mint | Before/after inventory mint |
| Bond paths | On reward updates |
| `claimRewards` path if DETF-mediated | Else bond vault claim still works after expansion mint on prior DETF touch; **also** run expansion update at start of public compound and mint |

For **view pending** consistency: if users only touch bond vault, expansion may lag until DETF touch — PRD allows lazy update; ensure at least mint/bond/compound/public paths catch up. Optional: bond vault hook later — not required if public compound exists.

### 3.3 Observability

- Existing: `thresholdMode`, `isMintingAllowed`, `syntheticPrice` (or family equivalent).
- Optional: `lastExpansionTimestamp()` view for tests.

---

## 4. Files to touch

| File | Action |
|------|--------|
| `SingleStandardExchangeDETDFPkg.sol` | PkgArgs + resolve/validate |
| `SingleStandardExchangeDETFRepo.sol` | storage + init |
| `SingleStandardExchangeDETFCommon.sol` | expansion update helper |
| ExchangeIn / Bonding / compound paths | call expansion update |
| Facet / Info | optional getters |
| `TestBase_SingleStandardExchangeDETF.sol` | time travel + rich synthetic helpers |
| New `SingleStandardExchangeDETF_NaturalExpansion.t.sol` | E1–E9 |

---

## 5. Test plan (E1–E9)

| ID | Test |
|----|------|
| E1 | Policy + live + push synthetic above mint threshold (real pool trade) → warp → touch → totalSupply ↑ and bond rewards ↑ |
| E2 | Open mode deploy → warp rich → no expansion mint |
| E3 | Two bonds different effective shares → reward ratio matches share weights (same as seigniorage distribution) |
| E4 | `pendingRewards` after sync == `claimRewards` amount (exact or documented dust) |
| E5 | Claim expansion while lock remaining |
| E6 | Detf NFT share of expansion compounds to BPT (Phase 1 path) |
| E7 | No setter; params from deploy only |
| E8 | Huge warp → mint ≤ cap; second touch does not double-count |
| E9 | Stage 01 ProtocolCompound tests still pass |

Drive synthetic via **real underlying trades** where possible (AGENTS.md), not only extreme thresholds.

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/*NaturalExpansion*' -vvv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/*ProtocolCompound*' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**' -vv
```

---

## 6. Acceptance

All **E1–E9** for Single SE. Phase 1 C1–C8 still green.

---

## 7. Definition of Done

- [x] Green tests + program index Stage 06
- [x] Document exact PkgArgs field order for later families
