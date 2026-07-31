// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

/// @dev Default-threshold (1.05/0.95) price-shift via real underlying Aerodrome SE pool trades + seigniorage dilution.
///      Share leg uses WITH_RATE so underlying trades move synthetic; free DETF seigniorage dilutes further.
contract MixedBufferMultiVaultStableDetf_PriceShift_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public override {
        super.setUp();
        // Default thresholds + WITH_RATE on leg0 so real SE underlying trades move synthetic.
        detf = _deployDefaultThresholdWithRateN1();
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
    }

    function _deployDefaultThresholdWithRateN1() internal returns (address d_) {
        _ensureSeVaults(1);
        IRateProvider rp_ = rateProviderPkg.deployRateProvider(
            IStandardExchange(address(seVaults[0])), seShares[0], IERC20(address(dai))
        );
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args = _buildPkgArgs(1, 0, 0);
        args.vaultShareRateProviders[0] = rp_;
        d_ = _deployWithArgs(args);
    }

    function test_defaultThresholds_gate_coupling_afterBootstrap() public view {
        uint256 synth_ = detfInfo.syntheticPrice();
        assertEq(detfInfo.isMintingAllowed(), synth_ > detfInfo.mintThreshold(), "mint gate");
        assertEq(detfInfo.isBurningAllowed(), synth_ < detfInfo.burnThreshold(), "burn gate");
    }

    /// @notice Required: open mint then open burn under default 1.05/0.95 via real underlying trades + dilution.
    function test_underlyingSwap_opensMintAndBurn_underDefaultThresholds() public {
        uint256 synth0_ = detfInfo.syntheticPrice();
        emit log_named_uint("synth_after_bootstrap", synth0_);

        // --- Mint regime (synthetic > mintThreshold) ---
        for (uint256 i; i < 10 && !detfInfo.isMintingAllowed(); ++i) {
            // DAI→USDC on aero pool of leg0 moves SE share→DAI rate (WITH_RATE).
            _shiftUnderlyingPrice(0, true, 30_000e18 * (i + 1));
            emit log_named_uint("synth_mint_skew", detfInfo.syntheticPrice());
        }
        assertTrue(detfInfo.isMintingAllowed(), "mint must open under default thresholds");

        uint256 mintOut_ = _mintDetfFromBuffer(detf, bob, 100e18);
        assertTrue(mintOut_ > 0, "bob minted detf under default thresholds");

        // Free DETF seigniorage dilutes synthetic (each mint mints free DETF beyond pool join claim).
        for (uint256 j; j < 15 && detfInfo.isMintingAllowed(); ++j) {
            _mintDetfFromBuffer(detf, bob, 150e18);
        }
        emit log_named_uint("synth_after_mints", detfInfo.syntheticPrice());

        // --- Burn regime (synthetic < burnThreshold) ---
        // Opposite underlying skew (USDC→DAI lowers share→DAI rate) + more dilution.
        for (uint256 k; k < 30 && !detfInfo.isBurningAllowed(); ++k) {
            _shiftUnderlyingPrice(0, false, 100_000e18 * (k + 1));
            if (detfInfo.isMintingAllowed()) {
                _mintDetfFromBuffer(detf, bob, 100e18);
            }
            emit log_named_uint("synth_burn_skew", detfInfo.syntheticPrice());
        }

        uint256 synthBurn_ = detfInfo.syntheticPrice();
        emit log_named_uint("synth_for_burn", synthBurn_);
        assertTrue(detfInfo.isBurningAllowed(), "burn must open under default thresholds after skew+dilution");
        assertTrue(synthBurn_ < detfInfo.burnThreshold(), "synthetic below burnThreshold");

        // While mint closed, prove gate reverts.
        if (!detfInfo.isMintingAllowed()) {
            _fundBuffer(bob, 10e18);
            vm.startPrank(bob);
            IERC20(address(dai)).approve(detf, 10e18);
            vm.expectRevert(
                abi.encodeWithSelector(
                    MixedBufferMultiVaultStableDetfRepo.MintingNotAllowed.selector,
                    detfInfo.syntheticPrice(),
                    detfInfo.mintThreshold()
                )
            );
            detfExchangeIn.exchangeIn(
                IERC20(address(dai)), 10e18, IERC20(detf), 0, bob, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
        }

        uint256 bobBal_ = IERC20(detf).balanceOf(bob);
        assertTrue(bobBal_ > 0, "bob holds detf to burn");
        uint256 burnAmt_ = bobBal_ / 2;
        if (burnAmt_ == 0) burnAmt_ = bobBal_;

        uint256 burnOut_ = _burnDetfToBuffer(detf, bob, burnAmt_);
        assertTrue(burnOut_ > 0, "burn returned buffer under default thresholds");
        _assertNoFreeInventory(detf);
    }
}
