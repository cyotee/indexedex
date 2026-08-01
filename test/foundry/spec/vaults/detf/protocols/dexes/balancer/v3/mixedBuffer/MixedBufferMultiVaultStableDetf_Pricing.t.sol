// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

contract MixedBufferMultiVaultStableDetf_Pricing_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_synthetic_readable_inert() public view {
        // supply 0 → peg 1e18
        assertEq(detfInfo.syntheticPrice(), 1e18, "inert peg");
    }

    function test_synthetic_after_bootstrap() public {
        _bootstrapDefault(detf, alice);
        uint256 p_ = detfInfo.syntheticPrice();
        assertTrue(p_ > 0, "live synthetic");
        // Free seigniorage DETF can push synthetic above peg; still bounded.
        assertApproxEqRel(p_, 1e18, 0.6e18, "near peg after bootstrap");
    }

    function test_gate_coupling_matches_thresholds() public {
        // Default thresholds on default detf after bootstrap.
        _bootstrapDefault(detf, alice);
        uint256 synth_ = detfInfo.syntheticPrice();
        uint256 mintTh_ = detfInfo.mintThreshold();
        uint256 burnTh_ = detfInfo.burnThreshold();
        assertEq(mintTh_, 1.05e18, "default mint th");
        assertEq(burnTh_, 0.95e18, "default burn th");
        assertEq(detfInfo.isMintingAllowed(), synth_ > mintTh_, "mint gate couples to synthetic");
        assertEq(detfInfo.isBurningAllowed(), synth_ < burnTh_, "burn gate couples to synthetic");
    }

    function test_mint_reverts_when_gate_closed() public {
        // Deploy with very high mint threshold so mint is closed after bootstrap.
        address closed_ = _deployDetfN(1, type(uint256).max, 0);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(closed_);
        IStandardExchangeIn ex_ = IStandardExchangeIn(closed_);
        _bootstrapDefault(closed_, alice);

        assertFalse(info_.isMintingAllowed(), "mint closed under max mintThreshold");
        _fundBuffer(bob, 50e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(closed_, 50e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                MixedBufferMultiVaultStableDetfRepo.MintingNotAllowed.selector,
                info_.syntheticPrice(),
                info_.mintThreshold()
            )
        );
        ex_.exchangeIn(
            IERC20(address(dai)), 50e18, IERC20(closed_), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_burn_reverts_when_gate_closed() public {
        // Mint open (mintTh=2 so synth ~1e18 always > 2); burn closed via burnThreshold=1 (synth never < 1).
        // mint==burn is illegal after PRD mint>burn validation - use mint=2, burn=1.
        address closedBurn_ = _deployDetfN(1, 2, 1);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(closedBurn_);
        IStandardExchangeIn ex_ = IStandardExchangeIn(closedBurn_);
        _bootstrapDefault(closedBurn_, alice);

        uint256 minted_ = _mintDetfFromBuffer(closedBurn_, bob, 50e18);
        assertFalse(info_.isBurningAllowed(), "burn closed under burnThreshold=1");

        vm.startPrank(bob);
        IERC20(closedBurn_).approve(closedBurn_, minted_);
        vm.expectRevert(
            abi.encodeWithSelector(
                MixedBufferMultiVaultStableDetfRepo.BurningNotAllowed.selector,
                info_.syntheticPrice(),
                info_.burnThreshold()
            )
        );
        ex_.exchangeIn(
            IERC20(closedBurn_), minted_ / 2, IERC20(address(dai)), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
