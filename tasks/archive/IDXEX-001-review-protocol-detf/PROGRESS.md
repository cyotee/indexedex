# Progress: IDXEX-001-review-protocol-detf

## Status: Complete

## Log

| Date | Update |
|------|--------|
| 2026-01-19 | Started implementation work. Updated Protocol DETF synthetic price oracle to match TASK.md algorithm (Aerodrome synthetic zap-outs + Balancer 80/20 weighted math) and disabled Protocol DETF exact-out routes (WETH→CHIR exact-out, CHIR→RICH exact-out) by reverting with ExchangeOutNotAvailable. |
| 2026-01-19 | Implemented canonical Bond NFT → RICHIR sale plumbing: added ProtocolNFTVault.sellPositionToProtocol() (principal-only share transfer + reward harvest + burn NFT) and updated ProtocolDETFBonding.sellNFT(tokenId,recipient) to mint RICHIR against principal shares. |
| 2026-01-19 | Added/updated Foundry test coverage for Bond NFT → RICHIR (tokenId-based) and fixed the harness setup so the new test passes without requiring full Balancer/Aerodrome deployments. |
| 2026-01-19 | Implemented canonical Bond NFT → WETH redemption plumbing: ProtocolNFTVault.redeemPosition() now routes through ProtocolDETF.claimLiquidity(lpAmount,recipient) and returns WETH out; added ProtocolDETF claimLiquidity/previewClaimLiquidity implementation (single-token Balancer exit → Aerodrome LP burn → pay WETH → reinvest CHIR) and exposed selectors via ProtocolDETFBondingFacet; added a focused harness test asserting redeemPosition calls claimLiquidity and burns the NFT. |
| 2026-01-19 | Validation: `forge build` succeeds (warnings only) and `forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETFRedeemPosition.t.sol` passes. |
| 2026-01-28 | **Full systematic review completed.** All 9 sections of the TASK.md checklist verified. Found 2 HIGH severity bugs in donation flow (IDXEX-018), identified 3 missing features (IDXEX-019, IDXEX-020, IDXEX-021). Core Protocol DETF logic verified correct for all supported routes. |

## Blockers

None

## Notes

### Review Session 2026-01-28

Comprehensive systematic review of Protocol DETF implementation against TASK.md checklist.

**Sections Reviewed:**
1. Peg Oracle - ✓ Verified
2. Donation Flow - ❌ Critical bugs found (IDXEX-018)
3. Token Mechanics - ✓ Verified
4. Redemption Unwind Path - ✓ Verified
5. Route Support - Mixed (3 features missing, tracked in IDXEX-019/020/021)
6. Balancer Reserve Pool - ✓ Verified
7. Access Control - ✓ Verified
8. Testing - Partial (invariant tests missing, tracked in IDXEX-010)

**Tasks Created During Review:**
- IDXEX-018: Fix Protocol DETF Donation Flow (HIGH)
- IDXEX-019: Implement WETH → CHIR Exact-Out Exchange (MEDIUM)
- IDXEX-020: Implement RICH → RICHIR Single-Call Wrapper (LOW)
- IDXEX-021: Implement WETH → RICHIR Single-Call Wrapper (LOW)

**Key Files Reviewed:**
- `contracts/vaults/protocol/ProtocolDETFCommon.sol` - synthetic price calculation
- `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol` - bonding, donation flow
- `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol` - exchange routes
- `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol` - exchange out (disabled)
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol` - NFT vault, lock enforcement
- `contracts/vaults/protocol/RICHIRTarget.sol` - RICHIR token mechanics
- `contracts/vaults/protocol/ProtocolDETFRepo.sol` - storage layout
- `contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol` - pool math
