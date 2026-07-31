# Stage 00 — Shared Protocol Compound Foundation

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **00** |
| **Phase** | Shared foundation for **Phase 1** (protocol seigniorage compound) |
| **This file is the sole implementation scope** | Do not implement family-specific DETF surfaces or Phase 2 expansion |
| **Depends on** | None (first stage) |
| **Blocks** | Stages 01–04 (all family Phase 1 plans) |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) — Phase 1 (§3), locks §0.4 / §12 |

**Conforms to product law; no re-litigation.**

---

## 1. Goals / non-goals

### Goals

1. Provide **shared** helpers and bond-NFT plumbing so every true DETF can:
   - Update global bond rewards.
   - Realize **detf-owned NFT** pending reward DETF.
   - **Single-sided DETF join** into the reserve and credit **detf-owned BPT / principal** (family completes join + BPT credit).
2. Define a **stable internal/external contract** families call:
   - Lazy compound attempt after reward updates.
   - Required public `compoundProtocolRewards` pattern (families expose; shared docs the semantics).
3. **Best-effort join failure:** harvest/debt accounting stays consistent if join cannot complete; pending remains for retry.
4. Pure unit tests for any new **math/accounting helpers** (no diamond required for pure libs).
5. Bond NFT changes that are family-agnostic and production-safe (reentrancy, only authorized callers).

### Non-goals

- Family `PkgArgs`, facet selectors, or DFPkg wiring (Stages 01–04).
- Natural supply expansion (Stages 05–09).
- Auto-compound of **user** or **fee-recipient** NFT rewards.
- Balanced multi-leg joins for compound (v1 = DETF self-leg only).
- Keepers, fee-oracle compound toggles, post-deploy param mutation.

---

## 2. Current state audit (grep-backed baseline)

| Area | Today | Gap |
|------|--------|-----|
| Inventory DETF sink | Mint seigniorage inventory **to** `bondNftVault` address (`_mintDetf(address(s.bondNftVault), inventoryDetf)`) | Accrues as reward-token balance; good for reward index |
| Reward index | `DETFNFTVaultRepo._updateGlobalRewards` — balance delta → `rewardPerShares` | No auto-compound |
| User claim | `claimRewards` / `pendingRewards` while locked | Keep unchanged |
| Detf-owned NFT harvest | `reallocateDetfNftRewards(recipient)` — harvest free DETF to feeTo **or** DETF diamond | Used by `DETFBondLifecycleLib._collectDetfNftRewards` → free DETF, **not** BPT compound |
| Single-sided DETF join | Exists per family, e.g. Single SE `_joinReserveDetfOnly` | Not wired to detf-NFT rewards |
| BPT → detf NFT | `addToDETFNFT` / `DETFBondLifecycleLib._addReservePoolBptToDetfNft` | Not called after reward harvest for compound |

**Product gap:** protocol inventory free DETF can sit claimable; claim redemption tracks **principal BPT**, not free DETF rewards.

---

## 3. Target design (shared)

### 3.1 Semantic pipeline (normative)

```text
1. _updateGlobalRewards (bond NFT vault)
2. Compute detfNFT pending reward DETF (earned)
3. If pending <= dust: return
4. Harvest detfNFT rewards to DETF diamond (zero debt for harvested amount; update lastRewardTokenBalance)
5. DETF: single-sided DETF join into reservePool → BPT out
6. Credit BPT to detf-owned NFT principal (addToDETFNFT / family equivalent)
7. If step 5 fails: do not wipe debt without join; prefer:
   - either harvest only after successful join (pull pattern), OR
   - harvest to diamond only when join succeeds in same atomic DETF call
```

**Preferred atomicity on DETF `compoundProtocolRewards`:**

```text
update rewards → measure earned(detfNFTId) → if 0 return
→ transfer/harvest rewards to DETF only as part of successful compound path
→ join → add BPT to detf NFT
→ on join failure: revert only the compound internal attempt when called standalone if needed,
  BUT when called as lazy hook from a user path: catch/skip join failure and leave pending intact
```

**PRD lock:** lazy user touch must **not** fail solely because join reverts. Implementation pattern:

- `_tryCompoundProtocolRewards()` — internal, **swallows join failures** (or returns false); never corrupts debt.
- `compoundProtocolRewards()` external — **may** return `(bool success, uint256 bptOut)` or only succeed when join works; still must not strand inconsistent debt. Prefer: same try semantics + event `ProtocolCompoundSkipped(reason)` / `ProtocolCompounded(amount, bptOut)`.

### 3.2 New / extended shared artifacts

| Artifact | Path (target) | Responsibility |
|----------|---------------|----------------|
| `DETFProtocolCompoundLib.sol` (new) | `contracts/vaults/detf/common/core/` | Pure helpers: dust check; optional event topic docs; **no** Balancer calls if family-specific |
| Bond NFT service/repo hooks | `bondNft/DETFNFTVault*.sol` | After `_updateGlobalRewards`, optional callback hook **or** documented that **DETF** is sole compound caller (recommended: **DETF-driven** to avoid vault→DETF reentrancy) |
| Inventory policy | `inventory/IDetf*.sol` | Document `reallocateDetfNftRewards` remains free-DETF harvest; compound is DETF-orchestrated |
| Lifecycle lib | `core/DETFBondLifecycleLib.sol` | Add `_compoundDetfNftRewards` helper used by families **or** keep thin and let families call sequence explicitly |

**Recommended architecture (locked for this plan):**

1. **Compound is DETF-orchestrated** (not bond-vault-orchestrated).
2. Bond NFT continues to expose harvest (`reallocateDetfNftRewards`) for the DETF diamond.
3. Shared lib documents the exact call order; optional thin wrapper:

```solidity
// Pseudocode — final names may match existing role naming
library DETFProtocolCompoundLib {
    /// @dev Dust below which compound is a no-op (family may override constant).
    uint256 internal constant DEFAULT_COMPOUND_DUST = 1; // or 1e3; document choice in tests

    function isCompoundable(uint256 pending_) internal pure returns (bool) {
        return pending_ > DEFAULT_COMPOUND_DUST;
    }
}
```

Families implement `_tryCompoundProtocolRewards` using existing `_joinReserveDetfOnly` + `addToDETFNFT`.

### 3.3 Lazy touch points (shared catalog — families wire)

Any path that already calls `_updateGlobalRewards` is a **candidate** lazy compound site **on the DETF side after** operations that deposit inventory DETF or after user harvest paths that return to DETF:

| Touch class | Example |
|-------------|---------|
| Capital-backed mint depositing inventory DETF | Family `ExchangeIn` / mint after `_mintDetf(..., inventory)` |
| Bond create / add | Family bonding targets |
| Claim / harvest (user) | If DETF wraps claim — else bond vault only; DETF still has public compound |
| Sell to detf NFT / unlock | Family bonding |
| Public compound | `compoundProtocolRewards()` **required** |

Bond NFT **need not** call DETF on every `claimRewards` if that creates reentrancy risk; Stages 01–04 must list the **exact** DETF entrypoints that call `_tryCompoundProtocolRewards`. Minimum bar: **mint inventory path + public compound + bond paths that already touch DETF**.

### 3.4 Events (shared shape; declare on family or IDetf)

```solidity
event ProtocolRewardsCompounded(uint256 detfAmountIn, uint256 bptOut);
event ProtocolCompoundSkipped(uint256 pendingDetf, bytes reason); // optional; reason may be empty
```

### 3.5 Dust defaults (plan default — family may match)

| Param | Default | Notes |
|-------|---------|-------|
| Compound dust | `1` wei DETF (or `1000` if join dust forces) | Document in unit tests; PRD allows family dust |

---

## 4. Files to touch (this stage only)

| File | Action |
|------|--------|
| `contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol` | **Create** — dust + any pure helpers |
| `contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol` | **Optional extend** — helper that documents harvest→caller owns join |
| `contracts/interfaces/...` (only if shared interface for compound callback) | Prefer family/IDetf in Stage 01+; Stage 00 may add NatSpec on inventory policy only |
| `contracts/vaults/detf/common/bondNft/*` | **Only if** needed for harvest consistency (e.g. view `pendingRewards(detfNFTId)` already exists — prefer **no** behavior change for users) |
| `test/foundry/spec/vaults/detf/common/core/DETFProtocolCompoundLib.t.sol` | **Create** pure unit tests |

**Do not** modify family DETF Common/Targets/DFPkgs in Stage 00 except if a compile-only shared interface import is required (prefer avoid).

---

## 5. Test plan (Stage 00)

| # | Test | Expect |
|---|------|--------|
| T0.1 | `isCompoundable(0) == false` | |
| T0.2 | `isCompoundable(dust) == false`, `dust+1 == true` | |
| T0.3 | Lifecycle helper (if added) reverts/`NoSeigniorage` on zero still consistent | |
| T0.4 | Existing bond NFT tests still green if bond NFT touched | `forge test --match-path test/foundry/spec/vaults/detf/common/bondNft/**` |

```bash
forge test --match-path test/foundry/spec/vaults/detf/common/core/DETFProtocolCompoundLib.t.sol -vv
# if bondNft edited:
forge test --match-path 'test/foundry/spec/vaults/detf/common/bondNft/**' -vv
```

---

## 6. Acceptance (Stage 00)

| # | Criterion |
|---|-----------|
| A0.1 | Shared compound helper lib exists with documented dust + call-order NatSpec |
| A0.2 | No change to user `claimRewards` product behavior |
| A0.3 | Pure unit tests green |
| A0.4 | Family stages can implement without inventing a second compound law |
| A0.5 | No expansion code |

---

## 7. Definition of Done

- [x] Code + tests for this stage merged / green locally
- [x] Program index Stage 00 marked green
- [x] Handoff note: recommended `_tryCompoundProtocolRewards` pattern for Stage 01

### Stage 01 handoff — `_tryCompoundProtocolRewards` pattern

```text
// Internal lazy hook (best-effort; never fails outer user path on join revert)
function _tryCompoundProtocolRewards() internal returns (uint256 detfIn, uint256 bptOut) {
    // 1. Update global bond rewards on bondNftVault
    // 2. pending = pendingRewards(detfNFTId)
    // 3. if (!DETFProtocolCompoundLib.isCompoundable(pending)) return (0, 0);
    // 4. Preferred pull: only harvest when join will succeed (or harvest+join atomic try)
    //    detfIn = reallocateDetfNftRewards(address(this));  // DETF as authorized recipient
    // 5. try _joinReserveDetfOnly(detfIn) → bptOut
    //    on success: DETFBondLifecycleLib._addReservePoolBptToDetfNft(...); emit ProtocolRewardsCompounded
    //    on failure: leave pending intact (do not wipe debt without BPT credit); return (0,0) / skip
}

// Public surface (required): same try semantics; may return (detfIn, bptOut) + events
function compoundProtocolRewards() external returns (uint256 detfIn, uint256 bptOut);
```

**Locks for Stage 01:** only detf-owned NFT; single-sided DETF join; user/fee-recipient rewards unchanged; dust via `DETFProtocolCompoundLib`; no expansion code.

---

## 8. Out of scope reminders

`composed/single`, `seigniorage/`, `detf/dual/**` — do not touch.
