// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title LidoWstETHStandardExchangeRepo
 * @notice Diamond storage for Lido SE addresses and withdrawal request bookkeeping.
 */
library LidoWstETHStandardExchangeRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.lido.wsteth.se");

    struct Storage {
        address stETH;
        address wstETH;
        address weth;
        address withdrawalQueue;
        /// @dev Request ids owned by this vault (FIFO bookkeeping for rebalance).
        uint256[] requestIds;
        mapping(uint256 => bool) isTrackedRequest;
        /// @dev Face stETH amount locked per request for NAV.
        mapping(uint256 => uint256) requestFaceStEth;
    }

    function _layout() internal pure returns (Storage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    function _initialize(address stETH_, address wstETH_, address weth_, address withdrawalQueue_) internal {
        Storage storage s = _layout();
        s.stETH = stETH_;
        s.wstETH = wstETH_;
        s.weth = weth_;
        s.withdrawalQueue = withdrawalQueue_;
    }

    function _stETH() internal view returns (address) {
        return _layout().stETH;
    }

    function _wstETH() internal view returns (address) {
        return _layout().wstETH;
    }

    function _weth() internal view returns (address) {
        return _layout().weth;
    }

    function _withdrawalQueue() internal view returns (address) {
        return _layout().withdrawalQueue;
    }

    function _trackRequest(uint256 requestId, uint256 faceStEth) internal {
        Storage storage s = _layout();
        if (!s.isTrackedRequest[requestId]) {
            s.isTrackedRequest[requestId] = true;
            s.requestIds.push(requestId);
        }
        s.requestFaceStEth[requestId] = faceStEth;
    }

    function _clearRequest(uint256 requestId) internal {
        Storage storage s = _layout();
        if (!s.isTrackedRequest[requestId]) return;
        s.isTrackedRequest[requestId] = false;
        delete s.requestFaceStEth[requestId];
        uint256 len = s.requestIds.length;
        for (uint256 i; i < len; ++i) {
            if (s.requestIds[i] == requestId) {
                s.requestIds[i] = s.requestIds[len - 1];
                s.requestIds.pop();
                break;
            }
        }
    }

    function _requestIds() internal view returns (uint256[] memory) {
        return _layout().requestIds;
    }

    function _requestFaceStEth(uint256 requestId) internal view returns (uint256) {
        return _layout().requestFaceStEth[requestId];
    }

    function _pendingFaceStEthTotal() internal view returns (uint256 total) {
        Storage storage s = _layout();
        uint256 len = s.requestIds.length;
        for (uint256 i; i < len; ++i) {
            uint256 id = s.requestIds[i];
            if (s.isTrackedRequest[id]) {
                total += s.requestFaceStEth[id];
            }
        }
    }

    function _isTrackedRequest(uint256 requestId) internal view returns (bool) {
        return _layout().isTrackedRequest[requestId];
    }
}
