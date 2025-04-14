# Task IDXEX-084: Implement ERC6909 Token ID Vault & Exchange Interfaces

**Repo:** IndexedEx
**Status:** Blocked
**Created:** 2026-02-08
**Priority:** MEDIUM
**Dependencies:** CRANE-255 (ERC6909 Diamond implementation in Crane)
**Worktree:** `feature/IDXEX-084-erc6909-tokenid-vault-interfaces`
**Origin:** New feature design - ERC6909 multi-token vault support

---

## Description

Implement ERC-6909 (Minimal Multi-Token Interface) support across the IndexedEx vault and exchange infrastructure. This adds token ID parameters to the existing exchange and vault interfaces, enabling vaults that issue multi-token shares (ERC6909 token IDs) backed by configurable reserve tokens.

Token ID 0 is the sentinel value meaning "this address is a plain ERC20 token." Token IDs > 0 indicate the address is an ERC6909 contract. For ERC20 reserves, the default token ID is `uint256(uint160(reserveAddress))` (via Crane's `Address._toUint256()`).

The first implementation supports a single underlying reserve token per token ID (analogous to ERC4626's single-asset model). Future tasks will add multi-token deposit conversion.

## Dependencies

| Dependency | Status | Title |
|------------|--------|-------|
| CRANE-255 | Ready (in Crane) | ERC6909 Diamond Implementation (Repo/Target/Facet) |

This task requires CRANE-255 to provide:
- `ERC6909Repo` (storage layout for multi-token balances)
- `ERC6909Target` (internal logic for mint/burn/transfer)
- `ERC6909Facet` (external-facing Diamond facet)
- `IERC6909` interface from Crane's external/openzeppelin tree

## User Stories

### US-IDXEX-084.1: Define IStandardExchangeTokenIDIn Interface

As a protocol integrator, I want an exchange-in interface that supports ERC6909 token IDs so that I can swap into multi-token vaults.

**Acceptance Criteria:**
- [ ] New interface `IStandardExchangeTokenIDIn` in `contracts/interfaces/IStandardExchangeTokenIDIn.sol`
- [ ] Mirrors `IStandardExchangeIn` but uses `address` instead of `IERC20` and adds `uint256 tokenId` for both tokenIn and tokenOut
- [ ] `TokenIDInArgs` struct:
  ```solidity
  struct TokenIDInArgs {
      address tokenIn;
      uint256 tokenIdIn;      // 0 = ERC20, >0 = ERC6909 token ID
      uint256 amountIn;
      address tokenOut;
      uint256 tokenIdOut;     // 0 = ERC20, >0 = ERC6909 token ID
      uint256 minAmountOut;
      address recipient;
      bool pretransferred;
      uint256 deadline;
  }
  ```
- [ ] `previewExchangeTokenIDIn(address tokenIn, uint256 tokenIdIn, uint256 amountIn, address tokenOut, uint256 tokenIdOut) returns (uint256 amountOut)`
- [ ] `exchangeTokenIDIn(address tokenIn, uint256 tokenIdIn, uint256 amountIn, address tokenOut, uint256 tokenIdOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline) returns (uint256 amountOut)`
- [ ] Extends `IStandardExchangeErrors`
- [ ] Custom function selectors declared via NatSpec `@custom:selector` tags

### US-IDXEX-084.2: Define IStandardExchangeTokenIDOut Interface

As a protocol integrator, I want an exchange-out interface that supports ERC6909 token IDs so that I can perform exact-out swaps from multi-token vaults.

**Acceptance Criteria:**
- [ ] New interface `IStandardExchangeTokenIDOut` in `contracts/interfaces/IStandardExchangeTokenIDOut.sol`
- [ ] Mirrors `IStandardExchangeOut` but uses `address` + `uint256 tokenId` parameters
- [ ] `TokenIDOutArgs` struct:
  ```solidity
  struct TokenIDOutArgs {
      address tokenIn;
      uint256 tokenIdIn;
      uint256 maxAmountIn;
      address tokenOut;
      uint256 tokenIdOut;
      uint256 amountOut;
      address recipient;
      bool pretransferred;
      uint256 deadline;
  }
  ```
- [ ] `previewExchangeTokenIDOut(address tokenIn, uint256 tokenIdIn, address tokenOut, uint256 tokenIdOut, uint256 amountOut) returns (uint256 amountIn)`
- [ ] `exchangeTokenIDOut(address tokenIn, uint256 tokenIdIn, uint256 maxAmountIn, address tokenOut, uint256 tokenIdOut, uint256 amountOut, address recipient, bool pretransferred, uint256 deadline) returns (uint256 amountIn)`
- [ ] Extends `IStandardExchangeErrors`
- [ ] Custom function selectors declared

### US-IDXEX-084.3: Define IBasicVaultTokenID Interface

As a vault developer, I want a basic vault interface with token ID support so that I can query multi-token vault reserves.

**Acceptance Criteria:**
- [ ] New interface `IBasicVaultTokenID` in `contracts/interfaces/IBasicVaultTokenID.sol`
- [ ] Functions:
  - `vaultTokenIds() returns (uint256[] memory tokenIds_)` - all active token IDs
  - `vaultTokenOfId(uint256 tokenId) returns (address token_)` - resolve token ID to its reserve token address
  - `reserveOfTokenId(uint256 tokenId) returns (uint256 reserve_)` - reserve balance for a specific token ID
  - `reservesById() returns (uint256[] memory reserves_)` - all reserves indexed by token ID order
  - `acceptedTokensOfId(uint256 tokenId) returns (address[] memory tokens_)` - tokens accepted for deposit into this token ID
- [ ] Token ID 0 is explicitly invalid (documented in NatSpec)

### US-IDXEX-084.4: Define IStandardVaultTokenID Interface

As a vault developer, I want an extended standard vault interface with token ID support for vault configuration queries.

**Acceptance Criteria:**
- [ ] New interface `IStandardVaultTokenID` in `contracts/interfaces/IStandardVaultTokenID.sol`
- [ ] Extends `IStandardVault` concepts with token IDs
- [ ] `TokenIDVaultConfig` struct:
  ```solidity
  struct TokenIDVaultConfig {
      bytes32 vaultFeeTypeIds;
      bytes32 contentsId;
      bytes4[] vaultTypes;
      address[] tokens;
      uint256[] tokenIds;    // parallel to tokens array
  }
  ```
- [ ] `tokenIdVaultConfig() returns (TokenIDVaultConfig memory)`
- [ ] Custom selectors declared

### US-IDXEX-084.5: Implement Token ID Reserve Manager Facet

As a vault operator, I want management functions to configure which tokens each token ID accepts for deposit/withdrawal.

**Acceptance Criteria:**
- [ ] New facet `TokenIDReserveManagerFacet` in `contracts/vaults/tokenid/TokenIDReserveManagerFacet.sol`
- [ ] Corresponding `TokenIDReserveManagerTarget` with internal implementations
- [ ] Uses `onlyOwnerOrOperator` from `OperableModifiers` for access control
- [ ] Management functions:
  - `setUnderlyingToken(uint256 tokenId, address underlyingToken)` - sets the single underlying reserve token for a token ID
  - `setAcceptedTokens(uint256 tokenId, address underlyingToken, address[] calldata acceptedTokens)` - sets underlying + additional accepted deposit/withdrawal tokens
  - `addAcceptedToken(uint256 tokenId, address token)` - add a single token to the accepted set
  - `removeAcceptedToken(uint256 tokenId, address token)` - remove a token from the accepted set
  - `getUnderlyingToken(uint256 tokenId) returns (address)` - query underlying
  - `getAcceptedTokens(uint256 tokenId) returns (address[] memory)` - query all accepted
- [ ] Default token ID for an ERC20 reserve = `uint256(uint160(reserveAddress))` via `Address._toUint256()`
- [ ] Token ID 0 rejected in all setters (revert with `InvalidTokenId()`)
- [ ] Events emitted for all state changes:
  - `UnderlyingTokenSet(uint256 indexed tokenId, address indexed token)`
  - `AcceptedTokenAdded(uint256 indexed tokenId, address indexed token)`
  - `AcceptedTokenRemoved(uint256 indexed tokenId, address indexed token)`
- [ ] Storage uses `EnumerableSet.AddressSet` for accepted tokens per token ID

### US-IDXEX-084.6: Implement Token ID Repo Storage

As a developer, I want Diamond-compatible storage for token ID vault data.

**Acceptance Criteria:**
- [ ] New library `TokenIDVaultRepo` in `contracts/vaults/tokenid/TokenIDVaultRepo.sol`
- [ ] Storage struct:
  ```solidity
  struct Storage {
      EnumerableSet.UintSet activeTokenIds;
      mapping(uint256 tokenId => address underlyingToken) underlyingTokens;
      mapping(uint256 tokenId => EnumerableSet.AddressSet acceptedTokens) acceptedTokenSets;
      mapping(uint256 tokenId => uint256 reserve) reserves;
  }
  ```
- [ ] Follows Crane Repo pattern: `bytes32 internal constant DEFAULT_SLOT = keccak256(abi.encode("indexedex.vault.tokenid"))`
- [ ] Internal helper functions for storage access
- [ ] `_isValidTokenId(uint256 tokenId)` returns false for tokenId == 0

### US-IDXEX-084.7: First Implementation - Single-Token ERC6909 Vault

As a user, I want a basic ERC6909 vault that works like ERC4626 (one underlying token per token ID) so I can deposit and receive multi-token shares.

**Acceptance Criteria:**
- [ ] New facet `BasicTokenIDVaultFacet` implementing `IBasicVaultTokenID`
- [ ] Corresponding `BasicTokenIDVaultTarget` with internal logic
- [ ] Each token ID maps to exactly one underlying ERC20 reserve token
- [ ] Deposit: user sends ERC20 reserve token, receives ERC6909 shares at the token ID
- [ ] Withdraw: user burns ERC6909 shares, receives ERC20 reserve token back
- [ ] 1:1 share ratio for the first implementation (no fee/yield logic)
- [ ] Integrates with `ERC6909Repo` from CRANE-255 for share minting/burning
- [ ] Only tokens in the `acceptedTokens` AddressSet for a token ID can be deposited

### US-IDXEX-084.8: Spec Tests

As a developer, I want comprehensive spec tests for all new interfaces and implementations.

**Acceptance Criteria:**
- [ ] Test file: `test/foundry/spec/vaults/tokenid/BasicTokenIDVault_Deposit.t.sol`
  - Deposit ERC20, receive ERC6909 shares
  - Deposit with tokenId=0 reverts
  - Deposit with unaccepted token reverts
  - Deposit with correct token ID succeeds
- [ ] Test file: `test/foundry/spec/vaults/tokenid/BasicTokenIDVault_Withdraw.t.sol`
  - Withdraw ERC6909 shares, receive ERC20
  - Withdraw more than balance reverts
- [ ] Test file: `test/foundry/spec/vaults/tokenid/TokenIDReserveManager_Auth.t.sol`
  - Only owner/operator can set underlying/accepted tokens
  - Unauthorized caller reverts
  - Token ID 0 rejected
  - Events emitted correctly
- [ ] Test file: `test/foundry/spec/vaults/tokenid/TokenIDReserveManager_Config.t.sol`
  - Set underlying token
  - Add/remove accepted tokens
  - Default token ID = Address._toUint256(reserveAddress)
  - Query functions return correct data
- [ ] All tests use Crane's IERC20 (not OpenZeppelin's)
- [ ] All tests follow existing test patterns (TestBase, DFPkg deployment)
- [ ] Build succeeds with no new warnings

## Technical Details

### Token ID Convention

```
tokenId == 0          -> INVALID (sentinel for "this is a plain ERC20 address")
tokenId > 0           -> Valid ERC6909 token ID on the specified contract address
tokenId == uint256(uint160(erc20Address)) -> Default ID for wrapping an ERC20
```

### Interface Inheritance

```
IStandardExchangeTokenIDIn   (new, extends IStandardExchangeErrors)
IStandardExchangeTokenIDOut  (new, extends IStandardExchangeErrors)
IBasicVaultTokenID           (new, standalone)
IStandardVaultTokenID        (new, extends IStandardVaultTokenID concepts)
```

### Storage Architecture

```
TokenIDVaultRepo (Diamond storage)
  ├── activeTokenIds: EnumerableSet.UintSet
  ├── underlyingTokens: mapping(uint256 => address)
  ├── acceptedTokenSets: mapping(uint256 => EnumerableSet.AddressSet)
  └── reserves: mapping(uint256 => uint256)
```

### Access Control

- Reserve management: `onlyOwnerOrOperator` from `OperableModifiers`
- Deposit/withdraw: permissionless (anyone can deposit if they have accepted tokens)

### Key Imports

```solidity
import { Address } from "@crane/contracts/utils/Address.sol";
import { OperableModifiers } from "@crane/contracts/access/operable/OperableModifiers.sol";
import { IERC6909 } from "@crane/contracts/external/openzeppelin/interfaces/IERC6909.sol";
import { ERC6909Repo } from "@crane/contracts/tokens/ERC6909/ERC6909Repo.sol"; // from CRANE-255
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
```

## Files to Create/Modify

**New Files (Interfaces):**
- `contracts/interfaces/IStandardExchangeTokenIDIn.sol` - Exchange-in with token IDs
- `contracts/interfaces/IStandardExchangeTokenIDOut.sol` - Exchange-out with token IDs
- `contracts/interfaces/IBasicVaultTokenID.sol` - Basic vault with token IDs
- `contracts/interfaces/IStandardVaultTokenID.sol` - Standard vault with token IDs

**New Files (Implementation):**
- `contracts/vaults/tokenid/TokenIDVaultRepo.sol` - Diamond storage library
- `contracts/vaults/tokenid/TokenIDReserveManagerTarget.sol` - Internal management logic
- `contracts/vaults/tokenid/TokenIDReserveManagerFacet.sol` - External management facet
- `contracts/vaults/tokenid/BasicTokenIDVaultTarget.sol` - Internal vault logic
- `contracts/vaults/tokenid/BasicTokenIDVaultFacet.sol` - External vault facet

**New Files (Tests):**
- `test/foundry/spec/vaults/tokenid/BasicTokenIDVault_Deposit.t.sol`
- `test/foundry/spec/vaults/tokenid/BasicTokenIDVault_Withdraw.t.sol`
- `test/foundry/spec/vaults/tokenid/TokenIDReserveManager_Auth.t.sol`
- `test/foundry/spec/vaults/tokenid/TokenIDReserveManager_Config.t.sol`

## Inventory Check

Before starting, verify:
- [ ] CRANE-255 is complete (ERC6909Repo, ERC6909Target, ERC6909Facet exist in Crane)
- [ ] `Address._toUint256()` exists in `@crane/contracts/utils/Address.sol`
- [ ] `OperableModifiers` exists in `@crane/contracts/access/operable/OperableModifiers.sol`
- [ ] `IERC6909` exists in `@crane/contracts/external/openzeppelin/interfaces/IERC6909.sol`
- [ ] Existing `IStandardExchangeIn.sol` and `IStandardExchangeOut.sol` are unchanged (new interfaces are separate)
- [ ] Existing `IBasicVault.sol` and `IStandardVault.sol` are unchanged

## Completion Criteria

- [ ] All 4 new interfaces compile and have NatSpec documentation
- [ ] TokenIDVaultRepo storage library compiles
- [ ] TokenIDReserveManagerFacet compiles with correct access control
- [ ] BasicTokenIDVaultFacet compiles and implements IBasicVaultTokenID
- [ ] All spec tests pass
- [ ] Build succeeds with no new warnings
- [ ] Token ID 0 is rejected everywhere as invalid

## Future Work (Out of Scope)

- Multi-token deposit conversion (e.g., swap tokenA -> underlying before deposit)
- Multi-token withdrawal conversion (e.g., withdraw underlying -> swap to tokenB)
- Fork tests against live ERC6909 contracts
- Integration with existing StandardExchange infrastructure
- Fee/yield logic on token ID vaults

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
