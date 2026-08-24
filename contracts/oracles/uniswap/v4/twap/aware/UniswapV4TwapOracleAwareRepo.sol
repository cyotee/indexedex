// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";

library UniswapV4TwapOracleAwareRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.oracles.uniswap.v4.twap.oracle.aware"))) - 1);

    struct Storage {
        IUniswapV4MultiPoolTwapOracle twapOracle;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    function _initialize(Storage storage layoutStruct, IUniswapV4MultiPoolTwapOracle twapOracle_) internal {
        layoutStruct.twapOracle = twapOracle_;
    }

    function _initialize(IUniswapV4MultiPoolTwapOracle twapOracle_) internal {
        _initialize(_layoutStruct(), twapOracle_);
    }

    function _twapOracle(Storage storage layoutStruct) internal view returns (IUniswapV4MultiPoolTwapOracle) {
        return layoutStruct.twapOracle;
    }

    function _twapOracle() internal view returns (IUniswapV4MultiPoolTwapOracle) {
        return _twapOracle(_layoutStruct());
    }
}
