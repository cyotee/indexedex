// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/// @notice T7.19 / T7.20 R19 diamond dust sweep.
abstract contract UniswapV4Detf_Dust_Decimals is TestBase_UniswapV4Detf_Decimals {
    function test_T7_19_afterMint_diamondHasNoJoinableBalances() public {
        _firstBond(_uPair(80));
        vm.startPrank(detfUser);
        IStandardExchangeIn(address(detfInfo)).exchangeIn(IERC20(address(pairToken)), _uPair(10), IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        _assertNoJoinableDust();
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.rebasingClaimToken()), 0, "no LP on claim");
    }

    function test_T7_20_sweepDust_joinsPairDust_unassignedLp() public {
        (uint256 tokenId,) = _firstBond(_uPair(80));
        IDetfBondNFT nft = IDetfBondNFT(detfInfo.bondNftVault());
        bytes32 positionBefore = keccak256(abi.encode(nft.positionOf(tokenId)));
        IStakedDETF staking = IStakedDETF(detfInfo.rebasingClaimToken());
        bytes32 fundingBefore = keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking))));
        uint256 nftLpBefore = IERC20(reserveHook).balanceOf(address(nft));


        pairToken.mint(detf, _uPair(5));
        assertGt(IERC20(address(pairToken)).balanceOf(detf), 0, "dust parked");

        detfInfo.sweepDust();

        assertEq(IERC20(address(pairToken)).balanceOf(detf), 0, "pair dust joined");
        uint256 nftLpAfter = IERC20(reserveHook).balanceOf(address(nft));
        assertGt(nftLpAfter, nftLpBefore, "NFT LP up");
        assertEq(keccak256(abi.encode(nft.positionOf(tokenId))), positionBefore, "sweep preserves fixed principal and attributed staking");
        assertEq(keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking)))), fundingBefore, "reserve dust creates no staking funding");
        _assertNoJoinableDust();
    }

    function test_T7_20_afterBond_noJoinableDust() public {
        _firstBond(_uPair(50));
        _assertNoJoinableDust();
    }
}
