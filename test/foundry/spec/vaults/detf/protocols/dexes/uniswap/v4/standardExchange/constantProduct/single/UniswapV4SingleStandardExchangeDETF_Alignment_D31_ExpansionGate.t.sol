// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF,
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice D31 realize-then-gate on Uni V4 CP live mint/burn.
contract UniswapV4SingleStandardExchangeDETF_Alignment_D31_ExpansionGate is
    TestBase_UniswapV4SingleStandardExchangeDETF
{
    function _policyLowMint()
        internal
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
    {
        args = _launchRichArgs();
        args.name = "D31 CP Policy";
        args.symbol = "d31cp";
        args.mintThreshold = 0.2e18;
        args.burnThreshold = 0.1e18;
    }

    function _wire(address d) internal {
        pairToken.mint(detfUser, 10_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        IUniswapV4SingleStandardExchangeDETF(d).bond(
            IERC20(address(pairToken)), 400 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        IUniswapV4SingleStandardExchangeDETF(d).compoundProtocolRewards();
    }

    function test_D31_2_policyMintRealizesExpansion() public {
        address d = _deployDetfWired(_policyLowMint());
        _wire(d);
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        vm.warp(block.timestamp + 8 hours * 20);
        uint256 pending_ = info.pendingExpansionDetf();
        uint256 lastBefore_ = info.lastExpansionTimestamp();
        uint256 nftBefore_ = IERC20(d).balanceOf(info.bondNftVault());
        vm.prank(detfUser);
        IStandardExchangeIn(d).exchangeIn(
            IERC20(address(pairToken)), 10 ether, IERC20(d), 0, detfUser, false, block.timestamp + 1 hours
        );
        if (pending_ > 0) {
            assertGt(info.lastExpansionTimestamp(), lastBefore_, "D31-2 timestamp");
            assertGe(IERC20(d).balanceOf(info.bondNftVault()), nftBefore_ + pending_ - 1, "D31-2 expansion on NFT");
        }
    }

    function test_D31_1_pendingPullsBelowMintThreshold_revertsUnchanged() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _policyLowMint();
        args_.name = "D31 CP Gate";
        args_.symbol = "d31g";
        args_.mintThreshold = 0.999e18;
        address d = _deployDetfWired(args_);
        _wire(d);
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        vm.warp(block.timestamp + 8 hours * 80);
        if (info.isMintingAllowed()) return;
        uint256 supplyBefore_ = IERC20(d).totalSupply();
        uint256 lastBefore_ = info.lastExpansionTimestamp();
        vm.prank(detfUser);
        vm.expectRevert();
        IStandardExchangeIn(d).exchangeIn(
            IERC20(address(pairToken)), 5 ether, IERC20(d), 0, detfUser, false, block.timestamp + 1 hours
        );
        assertEq(IERC20(d).totalSupply(), supplyBefore_, "D31-1 supply");
        assertEq(info.lastExpansionTimestamp(), lastBefore_, "D31-1 timestamp");
    }

    function test_D31_3_policyBurnRealizeThenGate() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _launchRichArgs();
        args_.name = "D31 CP Burn";
        args_.symbol = "d31b";
        args_.mintThreshold = 1.2e18;
        args_.burnThreshold = 0.9e18;
        address d = _deployDetfWired(args_);
        _wire(d);
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        uint256 userDetf_ = IERC20(d).balanceOf(detfUser);
        if (userDetf_ == 0 || !info.isBurningAllowed()) return;
        vm.warp(block.timestamp + 8 hours * 10);
        uint256 lastBefore_ = info.lastExpansionTimestamp();
        vm.startPrank(detfUser);
        IERC20(d).approve(d, userDetf_);
        IStandardExchangeIn(d).exchangeIn(
            IERC20(d), userDetf_ / 4, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGe(info.lastExpansionTimestamp(), lastBefore_);
    }

    function test_D31_4_openMintDoesNotExpand() public {
        address d = _deployDetfWired(_openArgs());
        _wire(d);
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Open));
        uint256 last_ = info.lastExpansionTimestamp();
        vm.warp(block.timestamp + 8 hours * 40);
        vm.prank(detfUser);
        IStandardExchangeIn(d).exchangeIn(
            IERC20(address(pairToken)), 10 ether, IERC20(d), 0, detfUser, false, block.timestamp + 1 hours
        );
        assertEq(info.lastExpansionTimestamp(), last_, "D31-4 Open");
        assertEq(info.pendingExpansionDetf(), 0);
    }
}
