// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {IMixedBufferMultiVaultStableDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfDFPkg.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfInfo.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";

/// @dev P8: nested MixedBuffer DETF as one share leg of outer MixedBuffer DETF.
///      Nested accepts+produces outer bufferToken (DAI) via mint/burn buffer routes.
contract MixedBufferMultiVaultStableDetf_Nested_Test is TestBase_MixedBufferMultiVaultStableDetf {
    address internal nestedUser;
    address internal directUser;
    address internal nestedDetf;
    address internal outerDetf;

    function setUp() public virtual override {
        super.setUp();
        nestedUser = makeAddr("nestedUser");
        directUser = makeAddr("directUser");
    }

    function test_nestedDetf_asLeg_outerMintBurnBond() public virtual {
        nestedDetf = _deployDetfN(1, 0, 0);
        _bootstrapDefault(nestedDetf, alice);
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(nestedDetf).isReserveLive(), "nested live");
        assertEq(IMixedBufferMultiVaultStableDetfInfo(nestedDetf).bufferToken(), address(_fixtureBufferToken()), "nested buffer");

        outerDetf = _deployOuterOverNested(nestedDetf);
        _assertOuterWiring(outerDetf, nestedDetf);
        _bootstrapOuterWithNested(outerDetf, nestedDetf, bob);
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(outerDetf).isReserveLive(), "outer live");

        _outerMintFromNestedShares();
        _outerMintFromBufferAndBurn();
        _outerBondNestedShares();
        _nestedStillServesDirectUsers();

        _assertNoFreeInventory(outerDetf);
        _assertNoFreeInventory(nestedDetf);
    }

    function _deployOuterOverNested(address nested_) internal returns (address outer_) {
        _ensureSeVaults(2);
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory outerArgs;
        outerArgs.name = "Outer MBMV Nested";
        outerArgs.symbol = "omvN";
        outerArgs.bufferToken = IERC20(address(_fixtureBufferToken()));
        outerArgs.standardExchangeVaults = new IStandardExchange[](2);
        outerArgs.vaultShareRateProviders = new IRateProvider[](2);
        outerArgs.standardExchangeVaults[0] = IStandardExchange(nested_);
        outerArgs.standardExchangeVaults[1] = IStandardExchange(address(seVaults[1]));
        outerArgs.amplificationParameter = MBMVS_AMP;
        // Both layers use the mandatory default primary gates and reserve-swap fallback.
        outerArgs.mintThreshold = 0;
        outerArgs.burnThreshold = 0;

        vm.startPrank(owner);
        outer_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(outerArgs)
        );
        vm.stopPrank();
    }

    function _assertOuterWiring(address outer_, address nested_) internal view {
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(outer_);
        assertEq(info_.vaultCount(), 2, "two legs");
        assertEq(info_.underlyingVaults()[0], nested_, "leg0 is nested DETF");
        assertEq(info_.vaultShares()[0], nested_, "nested share is diamond");
        assertEq(info_.underlyingVaults()[1], address(seVaults[1]), "leg1 production SE");
    }

    function _bootstrapOuterWithNested(address outer_, address nested_, address user) internal {
        uint256 nestedShares_ = _mintDetfFromBuffer(nested_, user, _fixtureAmount(400e18));
        nestedShares_ += _mintDetfFromVaultShare(nested_, 0, user, 200e18);
        require(nestedShares_ > 50e9, "nested shares for bootstrap");

        uint256 se1Shares_ = _fundVaultShares(1, user, 500e18);
        _fundBuffer(user, _fixtureAmount(BOOTSTRAP_BUFFER));

        uint256[] memory amts_ = new uint256[](2);
        amts_[0] = nestedShares_;
        amts_[1] = se1Shares_;

        vm.startPrank(user);
        IERC20(nested_).approve(outer_, nestedShares_);
        seShares[1].approve(outer_, se1Shares_);
        IERC20(address(_fixtureBufferToken())).approve(outer_, _fixtureAmount(BOOTSTRAP_BUFFER));
        (uint256 outerBondId_,,) = IMixedBufferMultiVaultStableDetfBonding(outer_).bootstrapFirstBond(
            _fixtureAmount(BOOTSTRAP_BUFFER), amts_, DEFAULT_MIN_LOCK, user, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(outerBondId_ > 0, "outer bootstrap bond");
    }

    function _outerMintFromNestedShares() internal {
        uint256 nestedIn_ = _mintDetfFromBuffer(nestedDetf, nestedUser, _fixtureAmount(80e18));
        if (nestedIn_ > 20e9) nestedIn_ = 20e9;

        uint256 preview_ =
            IStandardExchangeIn(outerDetf).previewExchangeIn(IERC20(nestedDetf), nestedIn_, IERC20(outerDetf));
        vm.startPrank(nestedUser);
        IERC20(nestedDetf).approve(outerDetf, nestedIn_);
        uint256 outerOut_ = IStandardExchangeIn(outerDetf).exchangeIn(
            IERC20(nestedDetf), nestedIn_, IERC20(outerDetf), 0, nestedUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(preview_, outerOut_, "outer mint nested leg preview==exec");
        assertTrue(outerOut_ > 0, "outer minted from nested shares");
    }

    function _outerMintFromBufferAndBurn() internal {
        uint256 bufOut_ = _mintDetfFromBuffer(outerDetf, nestedUser, _fixtureAmount(40e18));
        assertTrue(bufOut_ > 0, "outer mint from buffer");

        uint256 bal_ = IERC20(outerDetf).balanceOf(nestedUser);
        uint256 burnAmt_ = bal_ / 4;
        if (burnAmt_ == 0) burnAmt_ = bal_ / 2;
        uint256 burnBuf_ = _burnDetfToBuffer(outerDetf, nestedUser, burnAmt_);
        assertTrue(burnBuf_ > 0, "outer burn to buffer");
    }

    function _outerBondNestedShares() internal {
        uint256 moreNested_ = _mintDetfFromBuffer(nestedDetf, nestedUser, _fixtureAmount(50e18));
        vm.startPrank(nestedUser);
        IERC20(nestedDetf).approve(outerDetf, moreNested_);
        (uint256 tid_, uint256 principal_) = IMixedBufferMultiVaultStableDetfBonding(outerDetf).bond(
            IERC20(nestedDetf), moreNested_, DEFAULT_MIN_LOCK, nestedUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tid_ > 0 && principal_ > 0, "outer bond nested shares");
    }

    function _nestedStillServesDirectUsers() internal {
        uint256 direct_ = _mintDetfFromBuffer(nestedDetf, directUser, _fixtureAmount(30e18));
        assertTrue(direct_ > 0, "nested still mints directly");
        uint256 directBurn_ = _burnDetfToBuffer(nestedDetf, directUser, direct_ / 2);
        assertTrue(directBurn_ > 0, "nested still burns directly");
    }
}
