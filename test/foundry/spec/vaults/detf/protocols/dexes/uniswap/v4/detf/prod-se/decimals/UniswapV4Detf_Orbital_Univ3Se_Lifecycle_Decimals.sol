// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals.sol";

abstract contract UniswapV4Detf_Orbital_Univ3Se_Lifecycle_Decimals is TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals {
    function _mintIn() internal view returns (uint256) {
        return _uPair(10);
    }
    function _bondIn() internal view returns (uint256) {
        return _uPair(100);
    }
    function test_H_OR_GV3_firstBond() public {
        (uint256 tokenId, uint256 shares) = _firstBond(_bondIn());
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "shares");
        assertTrue(detfInfo.isReserveLive(), "live");
    }
    function test_H_OR_GV3_mint() public {
        _firstBond(_bondIn());
        uint256 mintIn = _mintIn();
        uint256 userPred = IStandardExchangeIn(address(detfInfo)).previewExchangeIn(IERC20(address(pairToken)), mintIn, IERC20(address(detfInfo)));
        vm.startPrank(detfUser);
        uint256 out = IStandardExchangeIn(address(detfInfo)).exchangeIn(IERC20(address(pairToken)), mintIn, IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(out, 0, "out");
        assertEq(out, userPred, "previewMint==exec");
    }
    function test_H_OR_GV3_burn() public {
        _firstBond(_bondIn());
        vm.startPrank(detfUser);
        uint256 minted = IStandardExchangeIn(address(detfInfo)).exchangeIn(IERC20(address(pairToken)), _mintIn(), IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        uint256 burnIn = minted / 2;
        uint256 preview = IStandardExchangeIn(address(detfInfo)).previewExchangeIn(IERC20(address(detfInfo)), burnIn, IERC20(address(pairToken)));
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnIn);
        uint256 amountOut = IStandardExchangeIn(address(detfInfo)).exchangeIn(IERC20(address(detfInfo)), burnIn, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertApproxEqAbs(amountOut, preview, 1, "previewBurn==exec");
    }
    /// @notice Users can process due epochs and claim directly within the existing gas budget.
    function test_H_OR_GV3_claimProcessesUnsettledEpochsWithinGasBudget() public {
        (uint256 tokenId,) = _firstBond(_bondIn());
        uint256 amount_ = _mintIn();
        vm.prank(detfUser);
        IStandardExchangeIn(address(detfInfo)).exchangeIn(
            IERC20(address(pairToken)), amount_, IERC20(detf), 0, detfUser, false, block.timestamp + 1 hours
        );
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        uint256 principal_ = nft_.positionOf(tokenId).principal;
        vm.warp(nft_.positionOf(tokenId).startTimestamp + nft_.positionOf(tokenId).vestingDuration);
        // Read-only previews do not settle epochs; the claim must perform that work.
        uint256 pending_ = detfInfo.pendingExpansionDetf();
        uint256 supply_ = IERC20(detf).totalSupply();
        IERC20 staking_ = IERC20(detfInfo.rebasingClaimToken());
        uint256 before_ = staking_.balanceOf(detfUser);
        vm.prank(detfUser);
        (uint256 paidPrincipal_, uint256 rewards_) = nft_.claimBond{gas: 30_000_000}(tokenId, detfUser);
        assertEq(paidPrincipal_, principal_, "all matured principal paid");
        assertEq(staking_.balanceOf(detfUser) - before_, paidPrincipal_ + rewards_, "exact funded payout");
        assertEq(IERC20(detf).totalSupply(), supply_ + pending_, "only due expansion changes supply");
        assertEq(detfInfo.pendingExpansionDetf(), 0, "claim consumes completed epochs");
        assertEq(nft_.ownerOf(tokenId), address(0), "fully claimed bond retired");
    }

    function test_H_OR_GV3_close() public {
        (uint256 tokenId,) = _firstBond(_bondIn());
        vm.startPrank(detfUser);
        IStandardExchangeIn(address(detfInfo)).exchangeIn(IERC20(address(pairToken)), _mintIn(), IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        _assertFundedMatureClaim(detf, tokenId, detfUser);
    }
}
