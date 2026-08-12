// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/**
 * @title ShortRedeemERC4626
 * @notice ERC-4626 that can under-deliver on redeem (for Slippage exact-out tests).
 */
contract ShortRedeemERC4626 is SimpleYieldERC4626 {
    bool public shortByOne;

    constructor(SimpleMintableERC20 asset_) SimpleYieldERC4626(asset_) {}

    function setShortByOne(bool v) external {
        shortByOne = v;
    }

    function redeem(uint256 shares, address receiver, address owner_)
        external
        override
        returns (uint256 assets)
    {
        assets = convertToAssets(shares);
        if (shortByOne && assets > 0) {
            unchecked {
                assets -= 1;
            }
        }
        _burnShares(owner_, shares);
        totalAssetsStored -= assets;
        // Keep the shorted wei in the vault (totalAssets already reduced by delivered only).
        require(assetToken.transfer(receiver, assets), "pay");
    }
}
