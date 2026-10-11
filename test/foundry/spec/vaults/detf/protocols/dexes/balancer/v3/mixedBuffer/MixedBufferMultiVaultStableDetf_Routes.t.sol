// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfInfo.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

contract MixedBufferMultiVaultStableDetf_Routes_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public virtual override {
        super.setUp();
        detf = _deployDetfN(2, 0, 0);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
    }

    function test_share_to_share_InvalidRoute() public virtual {
        uint256 s0_ = _fundVaultShares(0, bob, 50e18);
        vm.startPrank(bob);
        seShares[0].approve(detf, s0_);
        vm.expectRevert();
        detfExchangeIn.exchangeIn(
            seShares[0], s0_, seShares[1], 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_unconfigured_token_InvalidRoute() public virtual {
        _fundBuffer(bob, _fixtureAmount(10e18));
        // The other raw SE leg is neither this DETF buffer nor an accepted vault share.
        vm.startPrank(bob);
        IERC20(legTokenB[0]).approve(detf, _fixtureAmount(10e18));
        // Fund the actual other raw leg before exercising the unsupported route.
        vm.stopPrank();
        _mintToken(legTokenB[0], bob, _fixtureAmount(10e18));
        vm.startPrank(bob);
        IERC20(legTokenB[0]).approve(detf, _fixtureAmount(10e18));
        vm.expectRevert();
        detfExchangeIn.exchangeIn(
            IERC20(legTokenB[0]), _fixtureAmount(10e18), IERC20(detf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_exactOut_InvalidRoute() public virtual {
        IERC20 input_ = _fixtureBufferToken();
        IStandardExchangeOut exchange_ = IStandardExchangeOut(detf);
        assertEq(exchange_.previewExchangeOut(input_, IERC20(detf), 1e9), 0, "unsupported exact-output preview");
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 held_ = input_.balanceOf(detf);
        uint256 payer_ = input_.balanceOf(address(this));
        uint256 recipient_ = IERC20(detf).balanceOf(bob);
        for (uint256 flag_; flag_ < 2; ++flag_) {
            vm.expectRevert(abi.encodeWithSelector(MixedBufferMultiVaultStableDetfRepo.InvalidRoute.selector, address(input_), detf));
            exchange_.exchangeOut(input_, 1e18, IERC20(detf), 1e9, bob, flag_ == 1, block.timestamp);
            assertEq(IERC20(detf).totalSupply(), supply_, "no issuance");
            assertEq(input_.balanceOf(detf), held_, "held input unchanged");
            assertEq(input_.balanceOf(address(this)), payer_, "payer unchanged");
            assertEq(IERC20(detf).balanceOf(bob), recipient_, "no payout");
        }
    }
}
