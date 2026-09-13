// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IMixedBufferMultiVaultStablePool} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfInfo.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

contract MixedBufferMultiVaultStableDetf_Pricing_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_synthetic_readable_inert() public virtual {
        // supply 0 → peg 1e18
        assertEq(detfInfo.syntheticPrice(), 1e18, "inert peg");
    }

    function test_synthetic_after_bootstrap() public virtual {
        _bootstrapDefault(detf, alice);
        IMixedBufferMultiVaultStablePool pool_ = IMixedBufferMultiVaultStablePool(detfInfo.reservePool());
        uint256[] memory live_ = IVault(address(vault)).getCurrentLiveBalances(address(pool_));
        uint256 owned_ = IERC20(address(pool_)).balanceOf(detfInfo.bondNftVault());
        uint256 total_ = IERC20(address(pool_)).totalSupply();
        uint256 value_ = live_[detfInfo.detfIndex()] * owned_ / total_;
        value_ += pool_.virtualBuffer() * owned_ / total_;
        for (uint256 i_; i_ < detfInfo.vaultCount(); ++i_) value_ += pool_.derivedShareDepth(i_) * owned_ / total_;
        assertGt(value_, 0);
        assertEq(detfInfo.syntheticPrice(), value_ * 1e9 / IERC20(detf).totalSupply(), "owned reserve value per native DETF");
    }


    function test_gate_coupling_matches_thresholds() public virtual {
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

    function test_mint_swaps_when_gate_closed() public virtual {
        address instance_ = _deployDetfN(1, type(uint256).max, 0);
        _bootstrapDefault(instance_, alice);
        assertFalse(IMixedBufferMultiVaultStableDetfInfo(instance_).isMintingAllowed());
        _fundBuffer(bob, _fixtureAmount(50e18));
        _assertSwap(instance_, IERC20(address(_fixtureBufferToken())), IERC20(instance_), _fixtureAmount(50e18));
    }


    function test_burn_swaps_when_gate_closed() public virtual {
        address instance_ = _deployDetfN(1, 2, 1);
        _bootstrapDefault(instance_, alice);
        uint256 minted_ = _mintDetfFromBuffer(instance_, bob, _fixtureAmount(50e18));
        assertFalse(IMixedBufferMultiVaultStableDetfInfo(instance_).isBurningAllowed());
        _assertSwap(instance_, IERC20(instance_), IERC20(address(_fixtureBufferToken())), minted_ / 2);
    }

    function _assertSwap(address instance_, IERC20 in_, IERC20 out_, uint256 amount_) private {
        IStandardExchangeIn ex_ = IStandardExchangeIn(instance_);
        IStakedDETF staking_ = IStakedDETF(IMixedBufferMultiVaultStableDetfInfo(instance_).rebasingClaimToken());
        uint256 supply_ = IERC20(instance_).totalSupply();
        bytes32 state_ = keccak256(abi.encode(staking_.stakingState()));
        uint256 input_ = in_.balanceOf(bob); uint256 output_ = out_.balanceOf(bob);
        uint256 quote_ = ex_.previewExchangeIn(in_, amount_, out_); assertGt(quote_, 0);
        vm.startPrank(bob); in_.approve(instance_, amount_);
        vm.expectRevert(); ex_.exchangeIn(in_, amount_, out_, quote_ + 1, bob, false, block.timestamp);
        assertEq(in_.balanceOf(bob), input_); assertEq(out_.balanceOf(bob), output_);
        assertEq(ex_.exchangeIn(in_, amount_, out_, quote_, bob, false, block.timestamp), quote_);
        vm.stopPrank();
        assertEq(in_.balanceOf(bob), input_ - amount_); assertEq(out_.balanceOf(bob), output_ + quote_);
        assertEq(IERC20(instance_).totalSupply(), supply_);
        assertEq(keccak256(abi.encode(staking_.stakingState())), state_, "fallback awards no seigniorage");
    }

}
