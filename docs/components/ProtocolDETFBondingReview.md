# Code Review Findings: ProtocolDETFBonding Components

## Review Date: 2026-02-15
## Reviewer: opencode
## Status: DISCREPANCIES FOUND - REQUIRES MAINTAINER REVIEW

---

## Executive Summary

After comparing the implementation against the requirements in:
- `docs/components/ProtocolDETFBondingTarget.md`
- `docs/components/ProtocolDETFBondingQueryTarget.md`

**Multiple discrepancies were identified that require maintainer review.**

---

## Critical Issues

### 1. donate() - CHIR Donation Reward Distribution Missing

**Location:** `ProtocolDETFBondingTarget.sol:477-479`

**Requirement (TGT-ProtocolDETFBonding-06):**
> "if CHIR: divide amount in half, burn half, transfer remaining half to Protocol DETF NFT as reward for bond holders"

**Implementation:**
```solidity
} else {
    // CHIR: burn to reduce supply
    ERC20Repo._burn(address(this), amount);
}
```

**Issue:** Only burns 100% of CHIR donation. The requirement specifies:
- Burn 50%
- Transfer remaining 50% to Protocol DETF NFT as reward for bond holders

**Impact:** CHIR donation mechanism does not distribute rewards to bond holders per spec.

---

### 2. previewClaimLiquidity() - Missing 1 Wei Slack Adjustment

**Location:** `ProtocolDETFBondingQueryTarget.sol:151-155`

**Requirement (TGT-ProtocolDETFBondingQuery-04):**
> "preview must be conservative vs `claimLiquidity` execution"

**Execution Target (claimLiquidity):**
```solidity
// Line 212-216 in _calcMinChirWethVaultOutRaw
if (minChirWethVaultOut > 0) {
    unchecked {
        minChirWethVaultOut = minChirWethVaultOut - 1;  // 1 wei slack
    }
}
```

**Query Implementation:**
```solidity
// Line 157-181 - _previewChirWethVaultOutRaw does NOT apply slack
chirWethVaultOutRaw = FixedPoint.divDown(expectedChirWethVaultOutScaled18, chirWethRate);
```

**Issue:** Query returns exact calculated value without the 1 wei slack, making it NON-CONSERVATIVE compared to execution. Per the global policy: "views must be conservative relative to execution."

**Impact:** Preview could return higher values than actual execution, leading to user confusion and potential failed transactions.

---

## Medium Issues

### 3. sellNFT() - Missing BetterMath Conversion

**Location:** `ProtocolDETFBondingTarget.sol:428-429`

**Requirement (TGT-ProtocolDETFBonding-05):**
> "use `BetterMath._convertToSharesDown(principalShares)` to calculate RICHIR shares"

**Implementation:**
```solidity
richirMinted = layout.richirToken.mintFromNFTSale(principalShares, recipient);
```

**Issue:** Implementation passes `principalShares` directly without the `BetterMath._convertToSharesDown()` conversion step specified in requirements.

**Note:** This may be intentional if `sellPositionToProtocol` already returns shares. Need to verify if the NFT vault returns shares or assets.

---

### 4. captureSeigniorage() - CHIR Token Reference

**Location:** `ProtocolDETFBondingTarget.sol:389`

**Requirement (TGT-ProtocolDETFBonding-04):**
> "`transferFrom(protocolNFTVault)` for CHIR"

**Implementation:**
```solidity
IERC20(address(this)).safeTransferFrom(address(layout.protocolNFTVault), address(this), chirBalance);
```

**Analysis:** Uses `IERC20(address(this))` which is correct because CHIR = this contract (per `ProtocolDETFBondingQueryTarget.sol:120-122` and `ProtocolDETFCommon.sol:912-914`).

**Status:** IMPLEMENTATION CORRECT - This appears to be a design decision where the ProtocolDETF contract IS the CHIR token.

---

### 5. lockDuration Bounds Enforcement

**Location:** `ProtocolDETFBondingTarget.sol:289-327` and `330-368`

**Requirement (TGT-ProtocolDETFBonding-02 & 03):**
> "lockDuration bounds enforced by NFT vault"

**Implementation:** No explicit bounds check in `bondWithWeth` or `bondWithRich`.

**Analysis:** The requirement states bounds should be "enforced by NFT vault" - this appears correct as the NFT vault's `createPosition` should handle bounds checking.

**Status:** LIKELY CORRECT - Depends on `IProtocolNFTVault.createPosition` implementation.

---

## Query Target Issues

### 6. previewClaimLiquidity() - Execution Path Divergence

**Location:** `ProtocolDETFBondingQueryTarget.sol:144-155` vs `ProtocolDETFBondingTarget.sol:139-187`

**Query Path:**
1. Calculate expectedChirWethVaultOut via Balancer math
2. `IERC4626.previewRedeem(expectedChirWethVaultOut)` → lpOut
3. Calculate WETH from lpOut

**Execution Path:**
1. Exit reserve pool via Balancer router → chirWethVaultOut
2. `IERC4626.redeem(chirWethVaultOut, ...)` → lpOut (ACTUAL redemption)
3. Burn LP in Aerodrome → get CHIR + WETH
4. Return WETH

**Issue:** Query uses `previewRedeem` (simulation) while execution uses `redeem` (actual). These can diverge due to vault accounting.

---

## Summary Table

| Route | Requirement | Implementation | Status |
|-------|-------------|----------------|--------|
| claimLiquidity | Full spec | Matches | ✓ CORRECT |
| bondWithWeth | lockDuration bounds by NFT vault | Delegated to NFT vault | ✓ LIKELY CORRECT |
| bondWithRich | lockDuration bounds by NFT vault | Delegated to NFT vault | ✓ LIKELY CORRECT |
| captureSeigniorage | TransferFrom for CHIR | Uses address(this) | ✓ CORRECT |
| sellNFT | BetterMath._convertToSharesDown | Direct pass-through | ⚠️ NEEDS VERIFICATION |
| donate (CHIR) | 50% burn, 50% reward | 100% burn | ✗ DISCREPANCY |
| previewClaimLiquidity | Conservative vs execution | No 1-wei slack | ✗ DISCREPANCY |

---

## Recommendations

1. **donate() function:** Add logic to split CHIR donation:
   - Burn 50%
   - Transfer 50% to Protocol DETF NFT as reward

2. **previewClaimLiquidity() function:** Add 1-wei slack to match execution behavior:
   ```solidity
   if (chirWethVaultOutRaw > 0) {
       unchecked { chirWethVaultOutRaw--; }
   }
   ```

3. **sellNFT() function:** Verify if `sellPositionToProtocol` returns shares or assets. If assets, add `BetterMath._convertToSharesDown()` conversion as specified.

---

## Test Coverage Recommendations

Based on the requirements, the following tests are explicitly required:

1. **claimLiquidity:**
   - Access control (only NFT vault)
   - Extracted WETH correctness
   - Reinvest path leaves no stray LP
   - Reserve view sync
   - previewClaimLiquidity conservative vs execute

2. **bondWithWeth/bondWithRich:**
   - Lock duration bounds
   - Recipient defaulting
   - Preview parity

3. **captureSeigniorage:**
   - Allowance wiring
   - Permissionless caller cannot redirect funds
   - BPT credited to protocol NFT

4. **sellNFT:**
   - Only NFT owner can sell
   - RICH rewards paid to recipient
   - Principal moved
   - RICHIR minted matches shares

5. **donate:**
   - Donation token gating (WETH/CHIR only)
   - Pretransferred behavior
   - WETH donation increases protocol NFT backing
   - CHIR donation burns 50% and rewards 50%

6. **previewClaimLiquidity:**
   - Preview ≤ Execute
   - Fuzz around lpAmount and rates
