// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/**
 * @title UnderConsumeERC4626
 * @notice On deposit of `assets`, only pulls `assets - leaveDust` (if assets > leaveDust).
 * @dev Leaves residual underlying on the depositor (SE) for dust-absorb tests.
 */
contract UnderConsumeERC4626 is SimpleYieldERC4626 {
    uint256 public leaveDust;

    constructor(SimpleMintableERC20 asset_) SimpleYieldERC4626(asset_) {}

    function setLeaveDust(uint256 d) external {
        leaveDust = d;
    }

    function deposit(uint256 assets, address receiver) external override returns (uint256 shares) {
        uint256 pull = assets;
        if (leaveDust > 0 && assets > leaveDust) {
            pull = assets - leaveDust;
        }
        shares = convertToShares(pull);
        require(assetToken.transferFrom(msg.sender, address(this), pull), "pull");
        totalAssetsStored += pull;
        _mintShares(receiver, shares);
    }
}
