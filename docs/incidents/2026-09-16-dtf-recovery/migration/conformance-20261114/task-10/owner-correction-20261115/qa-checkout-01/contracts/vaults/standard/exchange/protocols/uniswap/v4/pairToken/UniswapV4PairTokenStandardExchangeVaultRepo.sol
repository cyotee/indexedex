// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4PairTokenStandardExchangeVaultTypes as Types
} from "./UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {
    IUniswapV4PairTokenStandardExchangeVault as IVault
} from "./interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultRepo[]
/// @notice The family-owned configuration, custody ledger and cross-facet operation state.
/// @dev ERC20Repo owns supply/balances, EIP712/ERC2612 own domain/nonces, and the
/// PoolManager owns liquidity and fee checkpoints. None are duplicated here.
library UniswapV4PairTokenStandardExchangeVaultRepo {
    // tag::DEFAULT_SLOT[]
    /// @dev Canonical ERC1967-form family namespace, using abi.encode rather than packed bytes.
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.pairToken"))) - 1);
    // end::DEFAULT_SLOT[]

    // tag::Storage[]
    /// @dev operation == None is the idle guard state. callbackHash commits
    /// keccak256(abi.encode(operation, payload)) before each unlock and is consumed
    /// once at callback entry. Clearing that hash does not release the operation guard.
    /// All reservations and callbackHash must be zero at successful external return.
    struct Storage {
        Types.Config config;
        Types.Inventory inventory;
        bool initialized;
        Types.OperationKind operation;
        bytes32 callbackHash;
    }
    // end::Storage[]

    // tag::_layoutStruct(bytes32)[]
    /// @notice Bind the family layout to an explicit storage slot.
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct) {
        assembly ("memory-safe") {
            layoutStruct.slot := slot_
        }
    }
    // end::_layoutStruct(bytes32)[]

    // tag::_layoutStruct()[]
    /// @notice Bind the family layout to its canonical namespace.
    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(DEFAULT_SLOT);
    }
    // end::_layoutStruct()[]

    /// @notice Economic reads cannot observe an in-flight family operation.
    function _requireIdle(Storage storage layoutStruct) internal view {
        if (layoutStruct.operation != Types.OperationKind.None) revert IVault.ReentrantOperation();
    }

    /// @notice Check the canonical family operation guard.
    function _requireIdle() internal view {
        _requireIdle(_layoutStruct());
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultRepo[]
