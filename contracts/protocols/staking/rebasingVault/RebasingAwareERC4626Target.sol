// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC4626Events} from "@crane/contracts/interfaces/IERC4626Events.sol";
import {IERC4626Errors} from "@crane/contracts/interfaces/IERC4626Errors.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {RebasingAwareERC4626Repo} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Repo.sol";
import {RebasingAwareERC4626Common} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol";

/**
 * @title RebasingAwareERC4626Target
 * @notice ERC-4626 whose `totalAssets` is live `asset.balanceOf(this)`.
 */
contract RebasingAwareERC4626Target is ReentrancyLockModifiers, IERC4626Events, IERC4626Errors {
    function asset() public view returns (address) {
        return address(RebasingAwareERC4626Repo._asset());
    }

    function totalAssets() public view returns (uint256) {
        return RebasingAwareERC4626Common.totalAssets();
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return RebasingAwareERC4626Common.convertToShares(assets);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return RebasingAwareERC4626Common.convertToAssets(shares);
    }

    function maxDeposit(address receiver) public view returns (uint256) {
        return RebasingAwareERC4626Common.maxDeposit(receiver);
    }

    function maxMint(address receiver) public view returns (uint256) {
        return RebasingAwareERC4626Common.maxMint(receiver);
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return RebasingAwareERC4626Common.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return RebasingAwareERC4626Common.maxRedeem(owner);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return RebasingAwareERC4626Common.previewDeposit(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        return RebasingAwareERC4626Common.previewMint(shares);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return RebasingAwareERC4626Common.previewWithdraw(assets);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return RebasingAwareERC4626Common.previewRedeem(shares);
    }

    function deposit(uint256 assets, address receiver) public nonReentrant returns (uint256 shares) {
        shares = RebasingAwareERC4626Common.executeDeposit(assets, receiver, 0, false);
    }

    function mint(uint256 shares, address receiver) public nonReentrant returns (uint256 assets) {
        assets = RebasingAwareERC4626Common.executeMint(shares, receiver, type(uint256).max, false);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        nonReentrant
        returns (uint256 shares)
    {
        shares = RebasingAwareERC4626Common.executeWithdraw(
            assets,
            receiver,
            owner,
            type(uint256).max,
            RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner,
            false
        );
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        nonReentrant
        returns (uint256 assets)
    {
        assets = RebasingAwareERC4626Common.executeRedeem(
            shares,
            receiver,
            owner,
            0,
            RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner,
            false
        );
    }
}
