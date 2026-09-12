// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
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
///      Share leg uses WITH_RATE so underlying trades move synthetic; funded seigniorage dilutes further.
contract MixedBufferMultiVaultStableDetf_PriceShift_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public virtual override {
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
            IStandardExchange(address(seVaults[0])), seShares[0], IERC20(address(_fixtureBufferToken()))
        );
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args = _buildPkgArgs(1, 0, 0);
        args.vaultShareRateProviders[0] = rp_;
        d_ = _deployWithArgs(args);
    }

    function test_defaultThresholds_gate_coupling_afterBootstrap() public virtual {
        uint256 synth_ = detfInfo.syntheticPrice();
        assertEq(detfInfo.isMintingAllowed(), synth_ > detfInfo.mintThreshold(), "mint gate");
        assertEq(detfInfo.isBurningAllowed(), synth_ < detfInfo.burnThreshold(), "burn gate");
    }

    /// @notice Required: open mint then open burn under default 1.05/0.95 via real underlying trades + dilution.
    function test_underlyingSwap_opensMintAndBurn_underDefaultThresholds() public virtual {
        uint256 synth0_ = detfInfo.syntheticPrice();
        emit log_named_uint("synth_after_bootstrap", synth0_);

        // --- Mint regime (synthetic > mintThreshold) ---
        for (uint256 i; i < 10 && !detfInfo.isMintingAllowed(); ++i) {
            // DAI→USDC on aero pool of leg0 moves SE share→DAI rate (WITH_RATE).
            _shiftUnderlyingPrice(0, true, 30_000e18 * (i + 1));
            emit log_named_uint("synth_mint_skew", detfInfo.syntheticPrice());
        }
        assertTrue(detfInfo.isMintingAllowed(), "mint must open under default thresholds");

        uint256 mintOut_ = _mintDetfFromBuffer(detf, bob, _fixtureAmount(100e18));
        assertTrue(mintOut_ > 0, "bob minted detf under default thresholds");

        // Funded DETF seigniorage participates in total supply and dilutes synthetic.
        for (uint256 j; j < 15 && detfInfo.isMintingAllowed(); ++j) {
            _mintDetfFromBuffer(detf, bob, _fixtureAmount(150e18));
        }
        emit log_named_uint("synth_after_mints", detfInfo.syntheticPrice());

        // --- Burn regime (synthetic < burnThreshold) ---
        // Opposite underlying skew (USDC→DAI lowers share→DAI rate) + more dilution.
        for (uint256 k; k < 30 && !detfInfo.isBurningAllowed(); ++k) {
            _shiftUnderlyingPrice(0, false, 100_000e18 * (k + 1));
            if (detfInfo.isMintingAllowed()) {
                _mintDetfFromBuffer(detf, bob, _fixtureAmount(100e18));
            }
            emit log_named_uint("synth_burn_skew", detfInfo.syntheticPrice());
        }

        uint256 synthBurn_ = detfInfo.syntheticPrice();
        emit log_named_uint("synth_for_burn", synthBurn_);
        assertTrue(detfInfo.isBurningAllowed(), "burn must open under default thresholds after skew+dilution");
        assertTrue(synthBurn_ < detfInfo.burnThreshold(), "synthetic below burnThreshold");

        _assertClosedMintSwaps();

        uint256 bobBal_ = IERC20(detf).balanceOf(bob);
        assertTrue(bobBal_ > 0, "bob holds detf to burn");
        uint256 burnAmt_ = bobBal_ / 2;
        if (burnAmt_ == 0) burnAmt_ = bobBal_;

        assertTrue(detfInfo.isBurningAllowed(), "primary burn remains available after fallback swap");
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 burnOut_ = _burnDetfToBuffer(detf, bob, burnAmt_);
        assertTrue(burnOut_ > 0, "burn returned buffer under default thresholds");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_ - burnAmt_, "primary route actually burns DETF");
        _assertNoFreeInventory(detf);
    }

    function _assertClosedMintSwaps() private {
        assertFalse(detfInfo.isMintingAllowed(), "mint gate is closed");
        _fundBuffer(bob, _fixtureAmount(10e18));
        IERC20 raw_ = IERC20(detf);
        IStakedDETF staking_ = IStakedDETF(detfInfo.rebasingClaimToken());
        bytes32 stakingBefore_ = keccak256(abi.encode(staking_.stakingState()));
        uint256 supply_ = raw_.totalSupply();
        uint256 balance_ = raw_.balanceOf(bob);
        uint256 buffer_ = _fixtureBufferToken().balanceOf(bob);
        uint256 quote_ = detfExchangeIn.previewExchangeIn(IERC20(address(_fixtureBufferToken())), _fixtureAmount(10e18), raw_);
        assertGt(quote_, 0);
        vm.startPrank(bob);
        _fixtureBufferToken().approve(detf, _fixtureAmount(10e18));
        assertEq(detfExchangeIn.exchangeIn(
            IERC20(address(_fixtureBufferToken())), _fixtureAmount(10e18), raw_, quote_, bob, false, block.timestamp + 1 hours
        ), quote_);
        vm.stopPrank();
        assertEq(raw_.balanceOf(bob), balance_ + quote_);
        assertEq(_fixtureBufferToken().balanceOf(bob), buffer_ - _fixtureAmount(10e18));
        assertEq(raw_.totalSupply(), supply_, "closed gate swaps without issuance");
        assertEq(keccak256(abi.encode(staking_.stakingState())), stakingBefore_, "no swap seigniorage");
    }
}
