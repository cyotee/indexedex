// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {TestBase_UniswapV4Detf_Quad_Univ4Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Univ4Se.sol";

/// @notice H-QD-GV4 money paths: firstBond / mint / burn / close against three Uni V4 SEs.
contract UniswapV4Detf_Quad_Univ4Se is TestBase_UniswapV4Detf_Quad_Univ4Se {
    function test_H_QD_GV4_firstBond() public {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        assertEq(toks.length, 4, "quad n=4");
        assertEq(detfInfo.creationPairPerDetfWad().length, 3, "n-1");
        (uint256 tokenId, uint256 shares) = _firstBond(100 ether);
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "shares");
        assertTrue(detfInfo.isReserveLive(), "live");
        _assertR19();
    }

    function test_H_QD_GV4_mint() public {
        _firstBond(100 ether);
        uint256 mintIn = 10 ether;
        uint256 userPred = IStandardExchangeIn(address(detfInfo)).previewExchangeIn{gas: 30_000_000}(IERC20(mintToken), mintIn, IERC20(address(detfInfo)));
        vm.startPrank(detfUser);
        uint256 out = IStandardExchangeIn(address(detfInfo)).exchangeIn{gas: 30_000_000}(IERC20(mintToken), mintIn, IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(out, 0, "out");
        assertEq(out, userPred, "previewMint==exec");
        _assertR19();
        _assertSeAllowancesZero();
    }

    function test_H_QD_GV4_burn() public {
        _firstBond(100 ether);
        vm.startPrank(detfUser);
        uint256 minted = IStandardExchangeIn(address(detfInfo)).exchangeIn{gas: 30_000_000}(IERC20(mintToken), 10 ether, IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(minted, 0, "minted");

        uint256 burnIn = minted / 2;
        _assertR19();
        _assertSeAllowancesZero();
        uint256 preview = IStandardExchangeIn(address(detfInfo)).previewExchangeIn{gas: 30_000_000}(IERC20(address(detfInfo)), burnIn, IERC20(mintToken));
        uint256 pairBefore = IERC20(mintToken).balanceOf(detfUser);
        uint256 supplyBefore = IERC20(detf).totalSupply();

        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnIn);
        vm.expectRevert();
        IStandardExchangeIn(address(detfInfo)).exchangeIn{gas: 30_000_000}(IERC20(address(detfInfo)), burnIn, IERC20(mintToken), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(IERC20(mintToken).balanceOf(detfUser), pairBefore, "Hookless quad burn over the chain cap moves no payment");
        assertEq(IERC20(detf).totalSupply(), supplyBefore, "Hookless quad burn over the chain cap burns no shares");
        assertGt(preview, 0, "quote fits; execution does not");
    }

    function test_H_QD_GV4_close() public {
        (uint256 tokenId,) = _firstBond(100 ether);
        vm.startPrank(detfUser);
        IStandardExchangeIn(address(detfInfo)).exchangeIn{gas: 30_000_000}(IERC20(mintToken), 10 ether, IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        _assertSeAllowancesZero();
        _assertFundedMatureClaim(detf, tokenId, detfUser);
        _assertR19();
        _assertSeAllowancesZero();
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) {
                assertLe(IERC20(toks[i]).balanceOf(reserveHook), 10, "hook pair <=10 wei");
            }
        }
    }
    /// @notice The mature-close claim path never starts: Hookless burn does not fit 30M gas.
    function test_claimAfterMatureClose_hooklessBurnExceedsChainGas() public {
        _firstBond(100 ether);
        vm.startPrank(detfUser);
        uint256 minted = detfExchangeIn.exchangeIn{gas: 30_000_000}(
            IERC20(mintToken), 10 ether, IERC20(detf), 0, detfUser, false, block.timestamp + 1 hours
        );
        assertGt(minted, 0, "mint still fits");
        IERC20(detf).approve(detf, minted / 4);
        uint256 supplyBefore = IERC20(detf).totalSupply();
        vm.expectRevert();
        detfExchangeIn.exchangeIn{gas: 30_000_000}(
            IERC20(detf), minted / 4, IERC20(mintToken), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(IERC20(detf).totalSupply(), supplyBefore, "capped Hookless burn is atomic");
    }

}
