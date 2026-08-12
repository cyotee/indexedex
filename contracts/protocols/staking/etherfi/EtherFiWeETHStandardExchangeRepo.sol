// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title EtherFiWeETHStandardExchangeRepo
 * @notice Diamond storage for ether.fi SE addresses and withdrawal request bookkeeping.
 */
library EtherFiWeETHStandardExchangeRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.etherfi.weeth.se");

    struct Storage {
        address eETH;
        address weETH;
        address weth;
        address liquidityPool;
        address withdrawRequestNFT;
        address redemptionManager;
        /// @dev Request ids owned by this vault (FIFO bookkeeping for rebalance).
        uint256[] requestIds;
        mapping(uint256 => bool) isTrackedRequest;
        /// @dev Face ETH amount locked per request for NAV.
        mapping(uint256 => uint256) requestFaceEth;
    }

    function _layout() internal pure returns (Storage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    function _initialize(
        address eETH_,
        address weETH_,
        address weth_,
        address liquidityPool_,
        address withdrawRequestNFT_,
        address redemptionManager_
    ) internal {
        Storage storage s = _layout();
        s.eETH = eETH_;
        s.weETH = weETH_;
        s.weth = weth_;
        s.liquidityPool = liquidityPool_;
        s.withdrawRequestNFT = withdrawRequestNFT_;
        s.redemptionManager = redemptionManager_;
    }

    function _eETH() internal view returns (address) {
        return _layout().eETH;
    }

    function _weETH() internal view returns (address) {
        return _layout().weETH;
    }

    function _weth() internal view returns (address) {
        return _layout().weth;
    }

    function _liquidityPool() internal view returns (address) {
        return _layout().liquidityPool;
    }

    function _withdrawRequestNFT() internal view returns (address) {
        return _layout().withdrawRequestNFT;
    }

    function _redemptionManager() internal view returns (address) {
        return _layout().redemptionManager;
    }

    function _trackRequest(uint256 requestId, uint256 faceEth) internal {
        Storage storage s = _layout();
        if (!s.isTrackedRequest[requestId]) {
            s.isTrackedRequest[requestId] = true;
            s.requestIds.push(requestId);
        }
        s.requestFaceEth[requestId] = faceEth;
    }

    function _clearRequest(uint256 requestId) internal {
        Storage storage s = _layout();
        if (!s.isTrackedRequest[requestId]) return;
        s.isTrackedRequest[requestId] = false;
        delete s.requestFaceEth[requestId];
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

    function _requestFaceEth(uint256 requestId) internal view returns (uint256) {
        return _layout().requestFaceEth[requestId];
    }

    function _pendingFaceEthTotal() internal view returns (uint256 total) {
        Storage storage s = _layout();
        uint256 len = s.requestIds.length;
        for (uint256 i; i < len; ++i) {
            uint256 id = s.requestIds[i];
            if (s.isTrackedRequest[id]) {
                total += s.requestFaceEth[id];
            }
        }
    }

    function _isTrackedRequest(uint256 requestId) internal view returns (bool) {
        return _layout().isTrackedRequest[requestId];
    }
}
