// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultRepo[]
/// @notice Family-isolated immutable configuration, booked custody and authenticated operation state.
library UniswapV4UpperLowerWingsStandardExchangeVaultRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.standard.exchange.uniswap.v4.upperLowerWings");
    struct Position {
        int24 lower;
        int24 upper;
        uint128 liquidity;
    }
    struct Storage {
        bool initialized;
        bool busy;
        uint8 mutations;
        bool target0;
        IPoolManager manager;
        PoolKey key;
        IVaultFeeOracleQuery oracle;
        bytes32 callbackHash;
        uint256 local0;
        uint256 local1;
        Position[3] positions;
        address registry;
    }
    function _layout() internal pure returns (Storage storage state_) {
        bytes32 slot = STORAGE_SLOT;
        assembly ("memory-safe") { state_.slot := slot }
    }
    /// @dev Slots have distinct salts even when ranges coincide at protocol extremes.
    function salt(uint256 slot_) internal pure returns (bytes32) {
        return keccak256(abi.encode(STORAGE_SLOT, slot_));
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultRepo[]
