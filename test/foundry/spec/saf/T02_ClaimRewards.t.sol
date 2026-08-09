// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";

/// @notice T02 / L-REW-*: claimRewards owner-only, no soft-success, 0 only when allowed+zero.
contract T02_ClaimRewards_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        _firstBond(400 ether);
    }

    function test_claimRewards_nonOwner_reverts() public {
        (uint256 tokenId,) = _firstBond(50 ether);
        address attacker = address(0xA77);
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Repo.NotAuthorized.selector, attacker));
        detfInfo.claimRewards(tokenId, attacker);
    }

    function test_claimRewards_owner_zeroRewards_returnsZero() public {
        (uint256 tokenId,) = _firstBond(50 ether);
        vm.prank(detfUser);
        uint256 rewards = detfInfo.claimRewards(tokenId, detfUser);
        assertEq(rewards, 0, "L-REW-3: allowed caller with no rewards returns 0");
    }
}
