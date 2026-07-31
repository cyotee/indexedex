# Stage 05 — Shared Natural Supply Expansion Foundation

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **05** |
| **Phase** | Shared foundation for **Phase 2** (natural supply expansion) |
| **This file is the sole implementation scope** | Do not wire family facets/DFPkgs beyond what pure lib tests need |
| **Depends on** | Stage **00** green; **at least Stage 01 Phase 1 green recommended** (compound path exists for protocol share of expansion) |
| **Blocks** | Stages **06–09** |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) §4, E1–E9, premium-closure + mint-on-update locks |

**Conforms to product law; no re-litigation.**

---

## 1. Goals / non-goals

### Goals

1. Own **cross-family pure math** for premium-closure expansion accrual and catch-up caps.
2. Define the **mint-on-update** accounting contract families implement:
   - When live + Policy + synthetic mint-allowed, mint free DETF **into bond reward vault** so existing `rewardPerShares` index absorbs it (same as seigniorage inventory).
3. Deploy-time parameter resolution helpers (defaults, validation) — **not** fee oracle.
4. Pure Foundry unit tests for formula edge cases (zero time, Open mode → zero, cap, dust).
5. Document storage field names families must add (canonical list).

### Non-goals

- Family PkgArgs / facet wiring (Stages 06–09).
- Keepers; post-deploy setters; Open-mode expansion.
- Separate user-facing expansion token or second weight scheme.
- Changing Threshold Modes Policy/Open encoding.

---

## 2. Product formula (locked shape; numbers = plan defaults)

### 2.1 When accrual is non-zero

All must hold:

1. Instance **live** (family).
2. `thresholdMode == Policy` (Open ⇒ **zero** expansion always).
3. `synthetic > mintThreshold` (same strict inequality as primary mint allow).

### 2.2 Premium-closure (canonical math)

Let:

- `S` = synthetic price (1e18-scaled abstract peg units; peg = `1e18`)
- `M` = resolved `mintThreshold` (1e18-scaled)
- Premium above peg: `P = S > 1e18 ? S - 1e18 : 0`  
  (If synthetic is below peg, expansion is already gated off by mint threshold in normal Policy configs where `mintThreshold >= 1e18`; still require mint-allowed gate.)
- `rate` = deploy-time **closure fraction per second** in 1e18 fixed point  
  (e.g. close `X` of premium per year ⇒ `rate = X / secondsPerYear` in 1e18).
- `dt` = `block.timestamp - lastExpansionTimestamp`, capped by catch-up.

**Expansion supply to mint** (into reward vault), plan-default shape:

```text
// Conceptual — implement carefully with mulDiv, no overflow
// Target: mint free DETF such that dilution moves synthetic toward peg at ~rate * premium
// v1 closed form used by pure lib (families must call this, not invent forks):

maxMint = min(
  catchUpCapAbsolute,                                    // deploy-time absolute DETF cap per update
  mulDiv(totalDetfSupply, catchUpCapBps, 10_000)         // optional supply-relative cap; may set 0 to disable
)

// Premium fraction closed over dt:
// closed = premium * rate * dt / 1e18   with premium = (S - 1e18) when S > 1e18 else 0
// Convert closed premium into DETF mint amount using current totalSupply as dilution lever:
// mint ≈ totalSupply * closed / S
// (document exact formula in NatSpec; unit tests lock vectors)

mint = min(computedMint, maxMint)
if mint <= dust: mint = 0
```

**Plan defaults (numeric — families may use unless PRD revised):**

| Param | Default | Storage / PkgArgs |
|-------|---------|-------------------|
| `expansionClosureRatePerSecond` | `0` means **off** OR resolve to a documented non-zero default | Prefer: `0 → DEFAULT` like thresholds. **Default proposal:** close **10% of premium per year** ⇒ `rate = 0.10e18 / 365 days` |
| `expansionCatchUpMaxSeconds` | `1 days` | Cap `dt` |
| `expansionCatchUpCapBps` | `50` (0.50% of totalSupply per update) | Absolute dilution brake |
| `expansionDust` | `1` | Skip mint |

**Open mode:** ignore expansion fields; never mint expansion.

**Validation:** rate ≥ 0; catch-up seconds > 0 if expansion enabled; bps ≤ 10_000.

---

## 3. Target API — `DETFNaturalExpansionLib.sol` (new)

Path: `contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol`

```solidity
library DETFNaturalExpansionLib {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant DEFAULT_CLOSURE_RATE_PER_SECOND = /* 0.10e18 / 365 days */;
    uint256 internal constant DEFAULT_CATCH_UP_MAX_SECONDS = 1 days;
    uint256 internal constant DEFAULT_CATCH_UP_CAP_BPS = 50;
    uint256 internal constant DEFAULT_EXPANSION_DUST = 1;

    struct AccrualInput {
        bool isLive;
        bool isPolicyMode;          // false if Open
        bool isMintAllowed;         // synthetic > mintThreshold under Policy; false if not
        uint256 syntheticPrice;     // 1e18 peg scale
        uint256 totalDetfSupply;
        uint256 lastExpansionTimestamp;
        uint256 nowTimestamp;
        uint256 closureRatePerSecond; // resolved
        uint256 catchUpMaxSeconds;    // resolved
        uint256 catchUpCapBps;        // resolved
    }

    /// @notice Pure: expansion DETF to mint now (0 if gated off).
    function computeExpansionMint(AccrualInput memory in_)
        internal
        pure
        returns (uint256 mintAmount_, uint256 newTimestamp_);

    function resolveExpansionParams(
        uint256 rateArg_,
        uint256 catchUpSecondsArg_,
        uint256 catchUpCapBpsArg_
    ) internal pure returns (uint256 rate_, uint256 catchUpSeconds_, uint256 capBps_);
}
```

Exact mulDiv formula must be implemented once and unit-tested; **families must not fork the formula**.

---

## 4. Mint-on-update contract (families implement in 06–09)

```text
_updateExpansionAndRewards():
  1. mintAmount, newTs = DETFNaturalExpansionLib.computeExpansionMint(...)
  2. if mintAmount > 0:
       _mintDetf(address(bondNftVault), mintAmount)   // same sink as seigniorage inventory
       lastExpansionTimestamp = newTs
  3. // bond vault: next _updateGlobalRewards sees balance increase → rewardPerShares ↑
  4. _tryCompoundProtocolRewards()  // protocol share of expansion → BPT (Phase 1)
```

**Preview:** `pendingRewards` already includes unindexed balance delta via vault `_earned` — after mint-on-update, views must stay claim-consistent (call update in claim; view may virtually include expansion if family adds view-time preview — prefer update-on-read for pending if needed for E4).

**Open:** skip step 1–2 always.

---

## 5. Files to touch (this stage)

| File | Action |
|------|--------|
| `contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol` | **Create** |
| `test/foundry/spec/vaults/detf/common/core/DETFNaturalExpansionLib.t.sol` | **Create** pure tests |
| Optional: short NatSpec docblock linking PRD §4 | |

Do **not** edit family DETF packages in Stage 05.

---

## 6. Pure test vectors (minimum)

| # | Case | Expect |
|---|------|--------|
| T5.1 | `!isLive` | mint 0 |
| T5.2 | `!isPolicyMode` (Open) | mint 0 |
| T5.3 | `!isMintAllowed` | mint 0 |
| T5.4 | `synthetic == mintThreshold` | mint 0 (deadband) |
| T5.5 | rich synthetic, `dt = 0` | mint 0 |
| T5.6 | rich synthetic, small `dt` | mint > 0, deterministic |
| T5.7 | huge `dt` | capped by max seconds + bps cap |
| T5.8 | `totalSupply = 0` | mint 0 |
| T5.9 | resolve zeros → defaults | |
| T5.10 | rate 0 after resolve-off policy | document whether 0 means off vs default — **lock: arg 0 → default rate; use max uint or explicit bool only if needed. Prefer: separate `expansionEnabled` not required; Open disables. Explicit rate 1 wei still expands slowly.** |

```bash
forge test --match-path test/foundry/spec/vaults/detf/common/core/DETFNaturalExpansionLib.t.sol -vvv
```

---

## 7. Acceptance (Stage 05)

| # | Criterion |
|---|-----------|
| A5.1 | Lib implements premium-closure + caps; pure tests green |
| A5.2 | Open / not live / not mint-allowed → 0 mint in tests |
| A5.3 | Families can integrate mint-on-update without redefining formula |
| A5.4 | No keeper; no fee-oracle params |

---

## 8. Definition of Done

- [x] Lib + pure tests green
- [x] Program index Stage 05 green
- [x] Handoff: canonical `AccrualInput` + defaults for Stages 06–09
