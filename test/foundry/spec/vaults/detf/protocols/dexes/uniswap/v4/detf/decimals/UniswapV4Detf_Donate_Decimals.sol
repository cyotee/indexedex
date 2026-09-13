// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/// @notice T7.13: actual capital donation increases protocol LP without changing funded bond ownership.
abstract contract UniswapV4Detf_Donate_Decimals is TestBase_UniswapV4Detf_Decimals {
    function test_T7_13_donatePair_Ogt0_unassignedLp() public {
        (uint256 tokenId,) = _firstBond(_uPair(80));
        IDetfBondNFT nft = IDetfBondNFT(detfInfo.bondNftVault());
        bytes32 positionBefore = keccak256(abi.encode(nft.positionOf(tokenId)));
        uint256 ownedBefore = IERC20(reserveHook).balanceOf(address(nft));
        IStakedDETF staking = IStakedDETF(detfInfo.rebasingClaimToken());
        bytes32 fundingBefore = keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking))));

        uint256 donateIn = _uPair(8);
        pairToken.mint(detfUser, donateIn);
        vm.startPrank(detfUser);
        IERC20(address(pairToken)).approve(address(nft), donateIn);
        uint256 lpOut = IDetfNftReserveDonation(address(nft)).donate(
            IERC20(address(pairToken)),
            donateIn,
            0,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(lpOut, 0, "joined LP");
        assertEq(keccak256(abi.encode(nft.positionOf(tokenId))), positionBefore, "gift preserves purchased principal and attributed staking");
        assertGe(IERC20(reserveHook).balanceOf(address(nft)), ownedBefore + lpOut, "actual protocol custody receives donated LP");
        assertEq(keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking)))), fundingBefore, "reserve gift creates no staking funding");
        _assertNoJoinableDust();
    }
}
