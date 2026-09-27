// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/// @dev D46 capped/pausable underlying for ERC-4626 SE capacity tests. Not a SUT mock.
contract CappedPausableERC4626 is SimpleYieldERC4626 {
    uint256 public depositCap;
    bool public paused;

    error DepositsPaused();
    error DepositCapExceeded(uint256 requested, uint256 remaining);

    constructor(MintableERC20Decimals asset_) SimpleYieldERC4626(asset_) {}

    function setDepositCap(uint256 cap) external {
        depositCap = cap;
    }

    function setPaused(bool paused_) external {
        paused = paused_;
    }

    function remainingAssets() public view returns (uint256 remaining) {
        if (depositCap == 0) return type(uint256).max;
        uint256 ta = totalAssets();
        return depositCap > ta ? depositCap - ta : 0;
    }

    function maxDeposit(address) public view override returns (uint256) {
        if (paused) return 0;
        if (depositCap == 0) return type(uint256).max;
        return remainingAssets();
    }

    function maxMint(address) public view override returns (uint256) {
        if (paused) return 0;
        if (depositCap == 0) return type(uint256).max;
        return convertToShares(remainingAssets());
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        if (paused) revert DepositsPaused();
        uint256 remaining = remainingAssets();
        if (depositCap != 0 && assets > remaining) {
            revert DepositCapExceeded(assets, remaining);
        }
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        if (paused) revert DepositsPaused();
        assets = previewMint(shares);
        uint256 remaining = remainingAssets();
        if (depositCap != 0 && assets > remaining) {
            revert DepositCapExceeded(assets, remaining);
        }
        return super.mint(shares, receiver);
    }
}
