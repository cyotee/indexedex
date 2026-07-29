// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title RocketPoolRETHStandardExchangeRepo
 * @notice Diamond storage for Rocket Pool rETH SE addresses (no queue bookkeeping).
 */
library RocketPoolRETHStandardExchangeRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.rocket-pool.reth.se");

    struct Storage {
        address rETH;
        address weth;
        address depositPool;
    }

    function _layout() internal pure returns (Storage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    function _initialize(address rETH_, address weth_, address depositPool_) internal {
        Storage storage s = _layout();
        s.rETH = rETH_;
        s.weth = weth_;
        s.depositPool = depositPool_;
    }

    function _rETH() internal view returns (address) {
        return _layout().rETH;
    }

    function _weth() internal view returns (address) {
        return _layout().weth;
    }

    function _depositPool() internal view returns (address) {
        return _layout().depositPool;
    }
}
