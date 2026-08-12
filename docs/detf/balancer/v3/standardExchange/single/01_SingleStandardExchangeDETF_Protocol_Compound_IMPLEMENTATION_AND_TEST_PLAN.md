# Stage 01 — Single Standard Exchange DETF — Phase 1 Protocol Compound

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **01** |
| **Phase** | **Phase 1** — protocol seigniorage compound |
| **Family** | Single Standard Exchange (`standardExchange/single/`) — **pathfinder** |
| **This file is the sole implementation scope** | Do not implement Phase 2 expansion or other families |
| **Depends on** | Stage **00** green |
| **Blocks** | Stage **06** (this family’s Phase 2); preferred unblock for Stages 02–04 patterns |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) §3, C1–C8 |
| **Sell/claim law** | [`BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md`](../../../../../../contracts/vaults/detf/protocols/dexes/balancer/v3/BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md) (mature-only sell/close, required claim DFPkg, 4626 `buyClaim`) |
| **Gold TestBase** | [`standardExchange/single/TestBase_SingleStandardExchangeDETF.sol`](./standardExchange/single/TestBase_SingleStandardExchangeDETF.sol) |

**Conforms to product law; no re-litigation.**  
**Role names only** (`rateAsset`, `vaultShare`, `detfToken`, `reservePool`, `detfNFTId`, …).

---

## 1. Goals / non-goals

### Goals

1. Detf-owned bond NFT pending seigniorage DETF is compounded via **`_joinReserveDetfOnly`** → BPT credited to detf NFT principal.
2. **Lazy** `_tryCompoundProtocolRewards` on DETF touch points that update inventory/rewards.
3. **Required** public `compoundProtocolRewards()` (name exact unless interface already uses equivalent — document if aliased).
4. Join failure = **best-effort** on lazy paths; user mint/bond/claim must not fail solely due to join revert.
5. User + fee-recipient still **claim free DETF** while locked.
6. Claim-wired path: protocol compound increases detf-owned BPT so claim redemption rate **can rise** (family wires claim when present).
7. Production-first tests; C1–C8 green for this family.

### Non-goals

- Expansion (Stage 06 / Stage 05).
- Changing mint/burn routes, threshold modes, fee schedules.
- Auto-compound user/fee NFTs.
- Other families.

---

## 2. Current state audit

| Item | Location | Notes |
|------|----------|-------|
| Inventory mint | `SingleStandardExchangeDETFExchangeInTarget._mintDetfFromVaultShares` | `_mintDetf(address(s.bondNftVault), split_.inventoryDetf)` |
| Single-sided join | `SingleStandardExchangeDETFExchangeOutTarget._joinReserveDetfOnly` | Already production join primitive — **reuse** |
| Bond NFT | `s.bondNftVault` / `detfNFTId()` | Shared `DETFNFTVault` package |
| Reward harvest | `reallocateDetfNftRewards` on vault; `DETFBondLifecycleLib._collectDetfNftRewards` | Free DETF to DETF today |
| Synthetic / BPT | `SingleStandardExchangeDETFCommon` owned BPT includes bond vault BPT | Claim rate path depends on principal BPT |
| Public compound | **Missing** | |

---

## 3. Implementation design

### 3.1 Core functions (family)

```solidity
/// @notice Update bond rewards and attempt detf-NFT reward → single-sided DETF join → BPT to detf NFT.
/// @dev Required public surface (PRD). Best-effort: returns false / zero if nothing to compound or join fails.
function compoundProtocolRewards() external returns (uint256 detfIn, uint256 bptOut);

function _tryCompoundProtocolRewards() internal returns (uint256 detfIn, uint256 bptOut);
```

**Algorithm (`_tryCompoundProtocolRewards`):**

1. If `bondNftVault == 0` or reserve not live (if compound only meaningful live — **prefer allow whenever pending > dust**): handle safely.
2. `bondNftVault` update global rewards (call any public that updates, or ensure harvest path updates).
3. `pending = pendingRewards(detfNFTId)` (or vault equivalent).
4. If `!DETFProtocolCompoundLib.isCompoundable(pending)` return (0,0).
5. `detfIn = reallocateDetfNftRewards(address(this))` (msg.sender must be DETF — already authorized).
6. If `detfIn == 0` return.
7. Attempt `_joinReserveDetfOnly(detfIn)`:
   - On success: `bptOut =` balance delta of reserve BPT on DETF (or join return if available); `_addReservePoolBptToDetfNft` / `addToDETFNFT(detfNFTId, bptOut)`.
   - On failure: **must not** leave free DETF stranded without either (a) reversing harvest, or (b) never harvesting until join succeeds.
8. **Preferred v1 pull pattern (recommended):** preview pending → if join would work, harvest + join + credit in one try/catch; on catch, leave pending on NFT (no harvest). Implement with low-level try or pre-check join amount > 0.

### 3.2 Lazy hooks (minimum list — implement all that apply)

| Site | File | When |
|------|------|------|
| After inventory mint | `ExchangeInTarget` | After `_mintDetf(..., inventoryDetf)` |
| Bond paths | `BondingTarget` | After reward-affecting bond ops |
| First bond / live | `BondingTarget` | After inventory seigniorage if any |
| Burn path (optional) | `ExchangeOutTarget` | Only if rewards updated |
| Public | Info or Exchange facet | `compoundProtocolRewards` |

Every lazy call uses **`_tryCompoundProtocolRewards`** (best-effort), not a hard-reverting wrapper.

### 3.3 Interface / facet

- Add selector to appropriate facet (`ExchangeInFacet` or Info facet — pick one, keep IFacet test in sync).
- NatSpec on interface used by clients (`IDetf` if shared selectors live there; else family info interface).
- If adding to `IDetf`, Stage 01 may own that additive surface; other families reuse same selector in later stages.

### 3.4 Events

Emit `ProtocolRewardsCompounded(detfIn, bptOut)` on success.

---

## 4. Files to touch

| File | Action |
|------|--------|
| `SingleStandardExchangeDETFCommon.sol` | `_tryCompoundProtocolRewards` |
| `SingleStandardExchangeDETFExchangeInTarget.sol` | lazy hook after inventory mint |
| `SingleStandardExchangeDETFBondingTarget.sol` | lazy hooks |
| `SingleStandardExchangeDETFExchangeOutTarget.sol` | expose/reuse `_joinReserveDetfOnly` visibility if needed (`internal` already) |
| `SingleStandardExchangeDETFInfoTarget.sol` or In facet | public `compoundProtocolRewards` |
| `*ExchangeInFacet.sol` | selector array |
| `IDetf.sol` / family interface | declare function if shared |
| `TestBase_SingleStandardExchangeDETF.sol` | helpers: force inventory rewards, read detf NFT BPT, claim rate preview |
| New tests under `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/` | see §5 |

---

## 5. Test plan (map to PRD C1–C8)

| ID | Criterion | Test idea |
|----|-----------|-----------|
| C1 | Lazy compound on touch | Mint with seigniorage → detf NFT pending → after mint, pending compounded (BPT ↑) without calling public compound |
| C2 | BPT increases | Measure `originalSharesOf(detfNFTId)` or vault BPT principal before/after |
| C3 | User claim free DETF while locked | Create user bond; accrue rewards; `claimRewards` while locked succeeds; user gets free DETF |
| C4 | Fee-recipient claimable | If fee NFT wired: claim still free DETF (not auto-join) |
| C5 | Claim rate path | If claim package deployed in TestBase: compound then preview redeem rate ≥ baseline (or document equality only if no BPT delta) |
| C6 | Public compound + no keeper | Call `compoundProtocolRewards` permissionlessly after seeding rewards |
| C7 | Production-first | No mocks of DETF/manager/registry/SE |
| C8 | Best-effort failure | Force join failure (e.g. pause router / empty join) → user mint still succeeds; pending remains; later successful compound works |

**Suggested files:**

- `SingleStandardExchangeDETF_ProtocolCompound.t.sol` (new)
- Extend `SingleStandardExchangeDETF_Bonding.t.sol` / Mint only if cleaner

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/*ProtocolCompound*' -vvv
forge test --match-contract SingleStandardExchangeDETF -vv
# keep threshold + bonding green:
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**' -vv
```

---

## 6. Acceptance

All PRD **C1–C8** for Single SE. Existing Single SE suites remain green.

---

## 7. Definition of Done

- [x] Implementation + tests green
- [x] Program index Stage 01 green
- [x] Short note of exact public ABI + lazy hook list for Stages 02–04 to copy
