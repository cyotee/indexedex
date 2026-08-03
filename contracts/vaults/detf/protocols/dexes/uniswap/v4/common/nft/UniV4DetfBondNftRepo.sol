// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

/// @title UniV4DetfBondNftRepo
/// @notice Storage for Uni V4 DETF bond NFT package (dual OOR + reward ledger).
library UniV4DetfBondNftRepo {
    error AlreadyInitialized();
    error NotOwner(address caller);
    error BondNotMature(uint256 unlockTime);
    error NotBondHolder(address owner, address caller);
    error ProtocolBondRestricted(uint256 tokenId);
    error ZeroAmount();

    bytes32 internal constant STORAGE_SLOT = keccak256("vault.detf.uniswap.v4.bond-nft.repo");

    struct BondPosition {
        int24 pairTickLower;
        int24 pairTickUpper;
        int24 detfTickLower;
        int24 detfTickUpper;
        uint256 pairPrincipal; // original shares / pair deposited at open
        uint256 effectiveShares; // pairPrincipal * lockBonus
        uint256 unlockTime;
        uint256 userRewardPerSharePaid;
        bool active;
    }

    struct Storage {
        address detf;
        IPoolManager poolManager;
        PoolKey poolKey;
        PoolId poolId;
        IERC20 pairToken;
        IERC20 detfToken; // reward token = DETF
        IERC20 rewardToken;
        bool pairIsCurrency0;
        uint24 widthMultiplier;
        address owner; // DETF diamond
        // Reward ledger (peer DETFNFTVault spirit)
        uint256 totalShares; // total effective shares
        uint256 rewardPerShares; // 1e18 scaled
        uint256 lastRewardTokenBalance;
        uint256 nextTokenId; // starts at 1; 0 = protocol ledger id
        uint256 protocolPrincipal; // id 0 principal (bond sell only)
        uint256 protocolEffectiveShares;
        uint256 protocolRewardPerSharePaid;
        mapping(uint256 tokenId => BondPosition) positions;
        mapping(uint256 tokenId => address) ownerOf;
    }

    function _layout() internal pure returns (Storage storage s) {
        bytes32 slot_ = STORAGE_SLOT;
        assembly {
            s.slot := slot_
        }
    }

    function _initialize(
        address detf_,
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
        if (s.detf != address(0)) revert AlreadyInitialized();
        s.detf = detf_;
        s.poolManager = poolManager_;
        s.poolKey = poolKey_;
        s.poolId = poolId_;
        s.pairToken = pairToken_;
        s.detfToken = detfToken_;
        s.rewardToken = detfToken_;
        s.pairIsCurrency0 = pairIsCurrency0_;
        s.widthMultiplier = widthMultiplier_;
        s.owner = owner_;
        s.nextTokenId = 1;
        // Protocol id 0 starts with zero principal (plan §0.3 #23).
        s.protocolPrincipal = 0;
        s.protocolEffectiveShares = 0;
    }

    function _requireOwner(address caller_) internal view {
        if (caller_ != _layout().owner) revert NotOwner(caller_);
    }

    function _saltPair(uint256 tokenId_) internal view returns (bytes32) {
        return keccak256(abi.encode(tokenId_, address(_layout().pairToken)));
    }

    function _saltDetf(uint256 tokenId_) internal view returns (bytes32) {
        return keccak256(abi.encode(tokenId_, address(_layout().detfToken)));
    }
}
