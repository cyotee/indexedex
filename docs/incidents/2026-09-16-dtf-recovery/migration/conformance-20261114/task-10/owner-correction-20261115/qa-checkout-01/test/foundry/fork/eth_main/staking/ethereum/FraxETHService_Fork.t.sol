// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IfrxETHMinter} from "@crane/contracts/protocols/tokens/stable/frax/FraxETH/IfrxETHMinter.sol";
import {IsfrxETH} from "@crane/contracts/protocols/tokens/stable/frax/FraxETH/IsfrxETH.sol";
import {FraxETHService} from "@crane/contracts/protocols/staking/ethereum/frax/services/FraxETHService.sol";
import {SfrxETHRateProvider} from "@crane/contracts/protocols/staking/ethereum/frax/rate/SfrxETHRateProvider.sol";
import {
    TestBase_EthereumStakingFork,
    EthereumStakingAddresses
} from "./TestBase_EthereumStakingFork.sol";

/// @dev Harness so library internal + msg.value paths are exercised on-chain.
contract FraxETHServiceHarness {
    function submitAndDeposit(IfrxETHMinter minter, address recipient) external payable returns (uint256) {
        return FraxETHService._submitAndDeposit(minter, recipient);
    }

    function depositSfrx(IsfrxETH sfrx, uint256 assets, address receiver) external returns (uint256) {
        return FraxETHService._depositSfrxETH(sfrx, assets, receiver);
    }

    function redeemSfrx(IsfrxETH sfrx, uint256 shares, address receiver, address owner)
        external
        returns (uint256)
    {
        return FraxETHService._redeemSfrxETH(sfrx, shares, receiver, owner);
    }

    function convertToAssets(IsfrxETH sfrx, uint256 shares) external view returns (uint256) {
        return FraxETHService._convertToAssets(sfrx, shares);
    }
}

contract FraxETHServiceFork is TestBase_EthereumStakingFork {
    FraxETHServiceHarness internal harness;
    IfrxETHMinter internal minter;
    IsfrxETH internal sfrx;
    SfrxETHRateProvider internal rateProvider;

    function setUp() public {
        if (!_forkEthereum()) return;
        harness = new FraxETHServiceHarness();
        minter = IfrxETHMinter(EthereumStakingAddresses.FRX_ETH_MINTER);
        sfrx = IsfrxETH(EthereumStakingAddresses.SFRX_ETH);
        rateProvider = new SfrxETHRateProvider(sfrx);
        _dealETH(address(this), 100 ether);
    }

    function test_Fork_SubmitAndDeposit_IncreasesSfrxETH() public {
        uint256 amount = 1 ether;
        uint256 beforeShares = IERC20(address(sfrx)).balanceOf(address(this));
        uint256 shares = harness.submitAndDeposit{value: amount}(minter, address(this));
        assertGt(shares, 0, "shares minted");
        assertEq(IERC20(address(sfrx)).balanceOf(address(this)) - beforeShares, shares, "sfrx delta");
    }

    function test_Fork_RateProvider_ConvertToAssets() public {
        uint256 rate = rateProvider.getRate();
        assertGt(rate, 0, "rate > 0");
        uint256 viaService = harness.convertToAssets(sfrx, 1e18);
        assertEq(rate, viaService, "rate provider matches convertToAssets(1e18)");
    }

    function test_Fork_ConvertToAssets_MonotonicAfterSync() public {
        uint256 before = sfrx.convertToAssets(1e18);
        // syncRewards is permissionless; may be no-op mid-cycle
        try sfrx.syncRewards() {} catch {}
        uint256 after_ = sfrx.convertToAssets(1e18);
        assertGe(after_, before, "convertToAssets non-decreasing after sync");
    }
}
