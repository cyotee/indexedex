// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

/// @title UniV4DetfRebasingClaimRepo
/// @notice Storage for Uni V4 DETF rebasing claim package (ERC-20 + managed listing LP).
library UniV4DetfRebasingClaimRepo {
    error AlreadyInitialized();
    error ZeroAmount();
    error SlippageExceeded(uint256 minOut, uint256 actual);
    error UnsupportedToken(address token);
    error NotOwner(address caller);

    bytes32 internal constant STORAGE_SLOT =
        keccak256("vault.detf.uniswap.v4.rebasing-claim.repo");

    struct Storage {
        IPoolManager poolManager;
        PoolKey poolKey;
        PoolId poolId;
        IERC20 pairToken;
        IERC20 detfToken;
        bool pairIsCurrency0;
        uint24 widthMultiplier;
        address owner; // DETF diamond
    }

    function _layout() internal pure returns (Storage storage s) {
        bytes32 slot_ = STORAGE_SLOT;
        assembly {
            s.slot := slot_
        }
    }

    function _initialize(
        IPoolManager poolManager_,
        PoolKey memory poolKey_,
        PoolId poolId_,
        IERC20 pairToken_,
        IERC20 detfToken_,
        bool pairIsCurrency0_,
        uint24 widthMultiplier_,
        address owner_
    ) internal {
        Storage storage s = _layout();
        if (address(s.poolManager) != address(0)) revert AlreadyInitialized();
        require(widthMultiplier_ >= 1, "widthMultiplier");
        s.poolManager = poolManager_;
        s.poolKey = poolKey_;
        s.poolId = poolId_;
        s.pairToken = pairToken_;
        s.detfToken = detfToken_;
        s.pairIsCurrency0 = pairIsCurrency0_;
        s.widthMultiplier = widthMultiplier_;
        s.owner = owner_;
    }

    function _requireOwner(address caller_) internal view {
        if (caller_ != _layout().owner) revert NotOwner(caller_);
    }
}
