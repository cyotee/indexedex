# Plan: Add Restricted RICHIR→RICH Exchange Route

## Context

User wants to add a new `exchangeIn` route that allows addresses in an AddressSet to burn RICHIR and receive RICH directly (not bridged), using the same extraction logic as `bridgeRichir()`.

**Core difference from bridgeRichir():**
- `bridgeRichir()`: Burns RICHIR → extracts RICH → sends RICH cross-chain via bridge
- New route: Burns RICHIR → extracts RICH → sends RICH to local `recipient` address

This enables off-grid, off-chain settlement: trusted parties can redeem RICHIR for RICH locally without requiring bridge infrastructure.

---

## Step 1: Add AllowedAddresses AddressSet to Storage

### Files:
- `contracts/vaults/protocol/BaseProtocolDETFRepo.sol`

### Changes:

In `BaseProtocolDETFRepo.Storage`, add:

```solidity
import {AddressSet} from "@crane/contracts/utils/collections/sets/AddressSet.sol";
import {AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

struct Storage {
    // ... existing fields ...
    
    // NEW: AddressSet of addresses allowed to use the RICHIR→RICH exchange route
    AddressSet allowedRichirRedeemAddresses;
}
```

### Verification:
- `forge build` passes
- No existing storage layout collision (run `forge inspect <contract> storage-layout`)

---

## Step 2: Create New Facet for Allowed Address Management

### Files:
- `contracts/vaults/protocol/BaseProtocolDETFRichirRedeemFacet.sol` (NEW)
- `contracts/vaults/protocol/BaseProtocolDETFRichirRedeemTarget.sol` (NEW - optional intermediate abstract)

### New Files:

**`contracts/vaults/protocol/BaseProtocolDETFRichirRedeemTarget.sol`** (abstract):
```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {OperableModifiers} from "@crane/contracts/access/operable/OperableModifiers.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";

abstract contract BaseProtocolDETFRichirRedeemTarget is OperableModifiers {
    /// @notice Add an address to the allowed list for RICHIR→RICH redemption
    /// @param addr Address to add
    function addAllowedRichirRedeemAddress(address addr) external onlyOwnerOrOperator {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        layout.allowedRichirRedeemAddresses._add(addr);
    }

    /// @notice Remove an address from the allowed list for RICHIR→RICH redemption  
    /// @param addr Address to remove
    function removeAllowedRichirRedeemAddress(address addr) external onlyOwnerOrOperator {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        layout.allowedRichirRedeemAddresses._remove(addr);
    }

    /// @notice Check if an address is allowed to use the RICHIR→RICH route
    /// @param addr Address to check
    /// @return bool True if allowed
    function isAllowedRichirRedeemAddress(address addr) external view returns (bool) {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        return layout.allowedRichirRedeemAddresses._contains(addr);
    }
}
```

**`contracts/vaults/protocol/BaseProtocolDETFRichirRedeemFacet.sol`**:
```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IBaseProtocolDETFRichirRedeem} from "contracts/interfaces/IBaseProtocolDETFRichirRedeem.sol";
import {BaseProtocolDETFRichirRedeemTarget} from "contracts/vaults/protocol/BaseProtocolDETFRichirRedeemTarget.sol";

contract BaseProtocolDETFRichirRedeemFacet is BaseProtocolDETFRichirRedeemTarget, IFacet {
    function facetName() external pure returns (string memory name) {
        return type(BaseProtocolDETFRichirRedeemFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IBaseProtocolDETFRichirRedeem).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](3);
        funcs_[0] = IBaseProtocolDETFRichirRedeem.addAllowedRichirRedeemAddress.selector;
        funcs_[1] = IBaseProtocolDETFRichirRedeem.removeAllowedRichirRedeemAddress.selector;
        funcs_[2] = IBaseProtocolDETFRichirRedeem.isAllowedRichirRedeemAddress.selector;
    }
}
```

### New Interface:
**`contracts/interfaces/IBaseProtocolDETFRichirRedeem.sol`**:
```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IBaseProtocolDETFRichirRedeem {
    function addAllowedRichirRedeemAddress(address addr) external;
    function removeAllowedRichirRedeemAddress(address addr) external;
    function isAllowedRichirRedeemAddress(address addr) external view returns (bool);
}
```

### Rationale:
Following Diamond facet separation of concerns - the allowed address management is orthogonal to bonding operations. A dedicated facet keeps concerns separated and allows independent upgrades.

### Verification:
- `forge build` passes
- `onlyOwnerOrOperator` reverts if called by non-owner/non-operator (add test)

---

## Step 2.5: Add Owner/Operator Infrastructure to BaseProtocolDETFDFPkg

### Rationale:
The `onlyOwnerOrOperator` modifier (from `OperableModifiers`) requires:
1. `MultiStepOwnableRepo._owner()` to be set (via `MultiStepOwnableFacet`)
2. `OperableRepo._isOperator()` to have operators registered (via `OperableFacet`)

Currently `BaseProtocolDETFDFPkg` does NOT include these facets. They must be added and initialized.

### Files:
- `contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol`

### Changes:

**1. Add to `PkgInit` struct** (after line 101):
```solidity
IFacet multiStepOwnableFacet;
IFacet operableFacet;
```

**2. Add immutables** (after line 170):
```solidity
IFacet immutable MULTI_STEP_OWNABLE_FACET;
IFacet immutable OPERABLE_FACET;
```

**3. Assign in constructor** (after line 218):
```solidity
MULTI_STEP_OWNABLE_FACET = pkgInit.multiStepOwnableFacet;
OPERABLE_FACET = pkgInit.operableFacet;
```

**4. Add to `PkgArgs` struct** (after line 129):
```solidity
address owner;
```

**5. Add to `facetAddresses()` array** (update from 11 to 13 entries):
```solidity
facetAddresses_[11] = address(MULTI_STEP_OWNABLE_FACET);
facetAddresses_[12] = address(OPERABLE_FACET);
```

**6. Add to `facetInterfaces()` array** (update from 12 to 13 interfaces):
```solidity
interfaces[12] = type(IMultiStepOwnable).interfaceId;
```

**7. Add to `facetCuts()` array** (update from 11 to 13 cuts):
```solidity
facetCuts_[11] = IDiamond.FacetCut({
    facetAddress: address(MULTI_STEP_OWNABLE_FACET),
    action: IDiamond.FacetCutAction.Add,
    functionSelectors: MULTI_STEP_OWNABLE_FACET.facetFuncs()
});
facetCuts_[12] = IDiamond.FacetCut({
    facetAddress: address(OPERABLE_FACET),
    action: IDiamond.FacetCutAction.Add,
    functionSelectors: OPERABLE_FACET.facetFuncs()
});
```

**8. Initialize in `initAccount()`** (after line 442):
```solidity
// Initialize MultiStepOwnable with owner from PkgArgs
PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
MultiStepOwnableRepo._initialize(args.owner, 1 days);
```

### Verification:
- `forge build` passes
- Facet cut array length matches expected (13 cuts)
- Owner can call owner-gated functions after deployment

---

## Step 3: Add New exchangeIn Route Handler

### Files:
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol`

### Rationale:
`exchangeIn` already dispatches by token type predicates. We need to add a new route: `RICHIR → RICH` that is gated by AddressSet membership.

### Implementation:

In `BaseProtocolDETFExchangeInTarget.sol`, in the function that executes exchangeIn routing (likely `_executeExchangeIn` or similar dispatch function), add:

```solidity
// NEW ROUTE: RICHIR → RICH (restricted to allowed addresses)
// Token predicates: _isRichirToken(layout, tokenIn) && _isRichToken(layout, tokenOut)
if (_isRichirToken(layout, tokenIn) && _isRichToken(layout, tokenOut)) {
    // GATE: Check sender is in allowed AddressSet
    BaseProtocolDETFRepo.Storage storage detoLayout = BaseProtocolDETFRepo._layout();
    if (!detoLayout.allowedRichirRedeemAddresses._contains(msg.sender)) {
        revert AccessDenied();
    }
    
    return _executeRichirToRich(detoLayout, params);
}
```

### New Internal Function `_executeRichirToRich`:

This should replicate the extraction logic from `bridgeRichir()` but without the bridge call:

```solidity
function _executeRichirToRich(
    BaseProtocolDETFRepo.Storage storage layout_,
    ExchangeInParams memory params_
) internal returns (uint256 richOut) {
    // 1. Pull RICHIR from sender if not pretransferred
    uint256 actualRichirIn = _secureTokenTransfer(
        IERC20(address(layout_.richirToken)),
        params_.amountIn,
        params_.pretransferred
    );
    
    // 2. Convert RICHIR amount to shares
    uint256 richirShares = layout_.richirToken.convertToShares(actualRichirIn);
    
    // 3. Calculate proportional BPT to exit from reserve
    uint256 reserveSharesBurned = _calcRichirBridgeBptIn(layout_, actualRichirIn);
    
    // 4. Burn the RICHIR shares (pretransferred=true since we just pulled them above)
    layout_.richirToken.burnShares(actualRichirIn, address(0), true);
    
    // 5. Exit reserve pool proportionally → get [chirWethVaultSharesOut, richChirVaultSharesOut]
    (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) =
        _exitReservePoolProportionalForBridge(layout_, reserveSharesBurned);
    
    // 6. CHIR/WETH portion → re-add to reserve pool AND mint local RICHIR (same as bridgeRichir)
    if (chirWethVaultSharesOut > 0) {
        uint256 localBptOut = _addToReservePool(layout_, layout_.chirWethVaultIndex, chirWethVaultSharesOut, params_.deadline);
        IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
        reservePoolToken.forceApprove(address(layout_.protocolNFTVault), localBptOut);
        layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, localBptOut);
        // Mint local RICHIR to sender (same as bridgeRichir - this is NOT the bridge difference)
        layout_.richirToken.mintFromNFTSale(localBptOut, msg.sender);
    }
    
    // 7. RICH/CHIR portion → exchange for RICH
    if (richChirVaultSharesOut > 0) {
        IERC20 richChirVaultToken = IERC20(address(layout_.richChirVault));
        richChirVaultToken.forceApprove(address(layout_.richChirVault), richChirVaultSharesOut);
        richOut = layout_.richChirVault.exchangeIn(
            richChirVaultToken,
            richChirVaultSharesOut,
            layout_.richToken,
            0,  // minAmountOut - could add slippage param
            params_.recipient,
            false,
            params_.deadline
        );
    }
}
```

**Note**: The `_secureTokenTransfer` helper (from `BaseProtocolDETFCommon`) handles:
- If `pretransferred == false`: pulls RICHIR from `msg.sender` to `address(this)` and returns actual amount received
- If `pretransferred == true`: validates balance and returns `amountIn` directly

### Alternative Design (Cleaner):

If we want to avoid duplicating the extraction logic, refactor `bridgeRichir()` to use a shared internal function:

```solidity
// Extract RICH from RICHIR (shared between bridge and direct redemption)
function _extractRichFromRichir(
    BaseProtocolDETFRepo.Storage storage layout_,
    uint256 richirAmountIn,
    address recipient,
    uint256 deadline
) internal returns (uint256 richOut) {
    // ... same extraction logic as above ...
}
```

Then `bridgeRichir()` calls `_extractRichFromRichir()` for the extraction step, and the new route does the same but skips the bridge call.

### Verification:
- `forge build` passes
- The `_calcRichirBridgeBptIn` and `_exitReservePoolProportionalForBridge` are already internal - no new dependencies

---

## Step 3.5: Add New Facet to BaseProtocolDETFDFPkg

### Files:
- `contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol`

### Changes:

The new `BaseProtocolDETFRichirRedeemFacet` must be added to the `BaseProtocolDETFDFPkg` package, following the same pattern as the existing bonding facet.

**1. Add to `PkgInit` struct** (after line 101):
```solidity
IFacet protocolDETFRichirRedeemFacet;
```

**2. Add immutable** (after line 170):
```solidity
IFacet immutable PROTOCOL_DETF_RICHIR_REDEEM_FACET;
```

**3. Assign in constructor** (after line 203):
```solidity
PROTOCOL_DETF_RICHIR_REDEEM_FACET = pkgInit.protocolDETFRichirRedeemFacet;
```

**4. Add to `facetAddresses()` array** (update from 10 to 11 entries, after index 9):
```solidity
facetAddresses_[10] = address(PROTOCOL_DETF_RICHIR_REDEEM_FACET);
```

**5. Add to `facetInterfaces()` array** (update from 11 to 12 interfaces, after index 10):
```solidity
interfaces[11] = type(IBaseProtocolDETFRichirRedeem).interfaceId;
```

**6. Add to `facetCuts()` array** (update from 10 to 11 cuts, after index 9):
```solidity
facetCuts_[10] = IDiamond.FacetCut({
    facetAddress: address(PROTOCOL_DETF_RICHIR_REDEEM_FACET),
    action: IDiamond.FacetCutAction.Add,
    functionSelectors: PROTOCOL_DETF_RICHIR_REDEEM_FACET.facetFuncs()
});
```

### Verification:
- `forge build` passes
- Facet cut array length matches expected (11 cuts)

---

## Step 4: Update IStandardExchangeIn Interface (If Needed)

### Files:
- `contracts/interfaces/IStandardExchangeIn.sol`

### Check:
If the new route needs additional parameters (e.g., `recipient` for where RICH goes), the existing `ExchangeInParams` or `InArgs` struct may already accommodate this. Currently:

```solidity
struct InArgs {
    IERC20 tokenIn;
    uint256 amountIn;
    IERC20 tokenOut;
    uint256 minAmountOut;
    address recipient;  // ← recipient is already in the interface
    bool pretransferred;
    uint256 deadline;
}
```

The `recipient` field already exists, so no interface change needed.

### Verification:
- `forge build` passes (interface compatible)

---

## Step 5: Add Tests

### Test File:
- `test/foundry/vaults/protocol/BaseProtocolDETFRichirRedeem_Test.t.sol` (new file)

### Test Cases:

**Admin Functions:**
1. `test_addAllowedAddress_byOwner_succeeds` - owner can add
2. `test_addAllowedAddress_byOperator_succeeds` - operator can add  
3. `test_addAllowedAddress_byRandom_fails` - non-owner/non-operator reverts
4. `test_removeAllowedAddress_byOwner_succeeds` - owner can remove
5. `test_removeAllowedAddress_byOperator_succeeds` - operator can remove
6. `test_removeAllowedAddress_byRandom_fails` - non-owner/non-operator reverts
7. `test_isAllowedAddress_returnsCorrectValue` - returns true for added, false for removed/non-existent

**New ExchangeIn Route:**
1. `test_richirRedeem_byAllowedAddress_succeeds` - happy path, allowed address burns RICHIR, receives RICH
2. `test_richirRedeem_byNonAllowedAddress_fails` - reverts with AccessDenied
3. `test_richirRedeem_byRemovedAddress_fails` - address added then removed cannot use route
4. `test_richirRedeem_slippage_respected` - if minAmountOut is set and not met, reverts
5. `test_richirRedeem_deadline_respected` - expired deadline reverts
6. `test_richirRedeem_chirWethShares_reinvestedToReserve` - CHIR/WETH portion correctly re-added to reserve
7. `test_richirRedeem_richDeliveredToRecipient` - RICH correctly delivered to recipient param
8. `test_richirRedeem_noBridgeInitiated` - no bridge messages sent (check events)
9. `test_richirRedeem_localRichirMinted` - local RICHIR IS minted to sender (same as bridgeRichir)

### Setup Pattern:

```solidity
contract BaseProtocolDETFRichirRedeem_Test is TestBase_Indexedex {
    // Deploy full Protocol DETF stack
    // Set up reserve pool with initial liquidity
    // Create some RICHIR positions for testing
    
    function setUp() public {
        super.setUp();
        // Deploy facets, packages, proxy
        // Initialize reserve pool
        // Seed with WETH/CHIR liquidity
    }
}
```

### Verification:
- All new tests pass: `forge test --match-contract BaseProtocolDETFRichirRedeem_Test -vvv`
- Existing `bridgeRichir` tests still pass: `forge test --match-contract BaseProtocolDETFBondingTargetTest -vvv`

---

## Step 6: Format and Lint

```bash
forge fmt
```

### Verification:
- `forge build` still passes after formatting

---

## Files to Modify/Create

| File | Action |
|------|--------|
| `contracts/interfaces/IBaseProtocolDETFRichirRedeem.sol` | Create - new interface |
| `contracts/vaults/protocol/BaseProtocolDETFRichirRedeemTarget.sol` | Create - new abstract target |
| `contracts/vaults/protocol/BaseProtocolDETFRichirRedeemFacet.sol` | Create - new facet |
| `contracts/vaults/protocol/BaseProtocolDETFRepo.sol` | Modify - add AddressSet to Storage |
| `contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol` | Modify - add new route |
| `contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol` | Modify - add owner/operator infrastructure (Step 2.5) + wire RICHIR redeem facet (Step 3.5) |
| `test/foundry/vaults/protocol/BaseProtocolDETFRichirRedeem_Test.t.sol` | Create - new test file |

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Storage layout collision | Low | Verify with `forge inspect` before testing |
| New facet integration | Low | Verify facet is properly wired into DFPkg and diamond proxy |
| Duplicated extraction logic | Medium | Refactor to shared internal function if code becomes unwieldy |
| AddressSet governance bypass | Low | `onlyOwnerOrOperator` is well-tested in this codebase |
| Slippage protection missing | Medium | `minAmountOut` param already exists in interface; ensure tests verify it |

---

## Implementation Order

1. **Step 1** - Add AddressSet to storage (lowest risk, foundational)
2. **Step 2** - Create RICHIR redeem management facet (interface + target + facet)
3. **Step 2.5** - Add owner/operator infrastructure to BaseProtocolDETFDFPkg (MultiStepOwnable + Operable facets)
4. **Step 3** - Add exchangeIn route (core logic)
5. **Step 3.5** - Wire new facet into BaseProtocolDETFDFPkg (package integration)
6. **Step 4** - Verify interface compatibility
7. **Step 5** - Write tests (TDD optional but recommended)
8. **Step 6** - Format and verify build

---

## Success Criteria

- [ ] `forge build` passes with no errors
- [ ] Admin functions correctly add/remove addresses when called by owner/operator
- [ ] Admin functions revert when called by unauthorized address
- [ ] Allowed address can successfully call exchangeIn for RICHIR→RICH
- [ ] Non-allowed address receives AccessDenied on RICHIR→RICH route
- [ ] RICH is delivered to `recipient` parameter
- [ ] CHIR/WETH portion is correctly re-invested to reserve pool
- [ ] No bridge messages are initiated during local redemption
- [ ] All new tests pass
- [ ] Existing bridgeRichir tests still pass
