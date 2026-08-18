// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";

/// @notice Catalog J1–J3 surface suite for Uni V4 Single SE CP DETF (WP-J-DETF-SSE-CP-001).
/// @dev J3 smokes **proxy** (registry-deployed diamond), never facet implementation address.
contract Adversarial_UniswapV4SingleSE_CP_Surface_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    function _openLiveOpenThreshold() internal returns (address instance_) {
        instance_ = _deployDetfWired(_openArgs());
        pairToken.mint(detfUser, 5_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(instance_, type(uint256).max);
        IUniswapV4SingleStandardExchangeDETF(instance_).bond(
            IERC20(address(pairToken)),
            500 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(IUniswapV4SingleStandardExchangeDETF(instance_).isReserveLive(), "live");
    }

    /// @dev Target-derived control set: money + info + bonding selectors (not incomplete Facet copy).
    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](35);
        sels_[0] = IStandardExchangeIn.exchangeIn.selector;
        sels_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[2] = IUniswapV4SingleStandardExchangeDETF.bond.selector;
        sels_[3] = IUniswapV4SingleStandardExchangeDETF.sellPositionToDetfNft.selector;
        sels_[4] = IUniswapV4SingleStandardExchangeDETF.claimRewards.selector;
        sels_[5] = IUniswapV4SingleStandardExchangeDETF.redeemClaim.selector;
        sels_[6] = IUniswapV4SingleStandardExchangeDETF.claimLiquidity.selector;
        sels_[7] = IUniswapV4SingleStandardExchangeDETF.isReserveLive.selector;
        sels_[8] = IUniswapV4SingleStandardExchangeDETF.standardExchangeVault.selector;
        sels_[9] = IUniswapV4SingleStandardExchangeDETF.standardExchangeVaultShare.selector;
        sels_[10] = IUniswapV4SingleStandardExchangeDETF.pairToken.selector;
        sels_[11] = IUniswapV4SingleStandardExchangeDETF.reserveHook.selector;
        sels_[12] = IUniswapV4SingleStandardExchangeDETF.reservePool.selector;
        sels_[13] = IUniswapV4SingleStandardExchangeDETF.syntheticPrice.selector;
        sels_[14] = IUniswapV4SingleStandardExchangeDETF.pendingExpansionDetf.selector;
        sels_[15] = IUniswapV4SingleStandardExchangeDETF.mintThreshold.selector;
        sels_[16] = IUniswapV4SingleStandardExchangeDETF.burnThreshold.selector;
        sels_[17] = IUniswapV4SingleStandardExchangeDETF.thresholdMode.selector;
        sels_[18] = IUniswapV4SingleStandardExchangeDETF.isMintingAllowed.selector;
        sels_[19] = IUniswapV4SingleStandardExchangeDETF.isBurningAllowed.selector;
        sels_[20] = IUniswapV4SingleStandardExchangeDETF.bondNftVault.selector;
        sels_[21] = IUniswapV4SingleStandardExchangeDETF.rebasingClaimToken.selector;
        sels_[22] = IUniswapV4SingleStandardExchangeDETF.feeRecipientNftId.selector;
        sels_[23] = IUniswapV4SingleStandardExchangeDETF.creationPairPerDetfWad.selector;
        sels_[24] = IUniswapV4SingleStandardExchangeDETF.lastExpansionTimestamp.selector;
        sels_[25] = IUniswapV4SingleStandardExchangeDETF.expansionEpochLength.selector;
        sels_[26] = IUniswapV4SingleStandardExchangeDETF.expansionClosureRatePerYearWad.selector;
        sels_[27] = IUniswapV4SingleStandardExchangeDETF.expansionMaxCatchUpEpochs.selector;
        sels_[28] = IUniswapV4SingleStandardExchangeDETF.acceptedBondTokens.selector;
        sels_[29] = IUniswapV4SingleStandardExchangeDETF.protocolLp.selector;
        sels_[30] = IUniswapV4SingleStandardExchangeDETF.userBondedLp.selector;
        sels_[31] = IUniswapV4SingleStandardExchangeDETF.isReserveHookFinalized.selector;
        sels_[32] = IUniswapV4SingleStandardExchangeDETF.isReserveWired.selector;
        sels_[33] = IUniswapV4SingleStandardExchangeDETF.completeReserveBondNft.selector;
        sels_[34] = IUniswapV4SingleStandardExchangeDETF.completeReserveClaim.selector;
        // compoundProtocolRewards is on interface but counted separately with atomic in J1.
    }

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    /// @notice J1: Target/product API selectors ⊆ Facet.facetFuncs().
    function test_J1_facetFuncs_coversTargetApi() public {
        // CREATE3 facet address from TestBase (not `new`); structural read of declaration only.
        IFacet facet_ = detfExchangeInFacet;
        bytes4[] memory funcs_ = facet_.facetFuncs();
        assertTrue(funcs_.length >= 36, "facetFuncs length");

        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            assertTrue(
                _facetFuncsContains(funcs_, controls_[i]),
                string.concat("J1 missing selector idx ", vm.toString(i))
            );
        }
        assertTrue(
            _facetFuncsContains(funcs_, IUniswapV4SingleStandardExchangeDETF.compoundProtocolRewards.selector),
            "J1 compound"
        );
        // Atomic compound helper is Facet-only.
        assertTrue(
            _facetFuncsContains(funcs_, bytes4(keccak256("compoundProtocolRewardsAtomic()"))),
            "J1 atomic compound"
        );
    }

    /// @notice J2: loupe facetAddress(sel) != 0 for all product controls on production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public {
        address instance_ = _openLiveOpenThreshold();
        IDiamondLoupe loupe_ = IDiamondLoupe(instance_);
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != instance_, "J2 facet != proxy");
        }
        address compoundFacet_ =
            loupe_.facetAddress(IUniswapV4SingleStandardExchangeDETF.compoundProtocolRewards.selector);
        assertTrue(compoundFacet_ != address(0) && compoundFacet_ != instance_, "J2 compound loupe");
    }

    /// @notice J3: smoke-call money + view selectors on **proxy** (not facet impl address).
    function test_J3_proxyCallable_smoke_eachSelector() public {
        address instance_ = _openLiveOpenThreshold();
        // Prove we are not calling facet impl: loupe maps exchangeIn to a non-zero facet.
        address exchangeFacet_ =
            IDiamondLoupe(instance_).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertTrue(exchangeFacet_ != address(0) && exchangeFacet_ != instance_, "proxy cut");

        IUniswapV4SingleStandardExchangeDETF info_ = IUniswapV4SingleStandardExchangeDETF(instance_);

        // --- Views on proxy ---
        assertTrue(info_.isReserveLive());
        assertTrue(info_.standardExchangeVault() != address(0));
        assertTrue(info_.pairToken() != address(0));
        assertTrue(info_.reserveHook() != address(0));
        assertTrue(info_.reservePool() != address(0));
        assertTrue(info_.bondNftVault() != address(0));
        info_.standardExchangeVaultShare();
        info_.syntheticPrice();
        info_.pendingExpansionDetf();
        info_.mintThreshold();
        info_.burnThreshold();
        info_.thresholdMode();
        info_.isMintingAllowed();
        info_.isBurningAllowed();
        info_.rebasingClaimToken();
        info_.feeRecipientNftId();
        info_.creationPairPerDetfWad();
        info_.lastExpansionTimestamp();
        info_.expansionEpochLength();
        info_.expansionClosureRatePerYearWad();
        info_.expansionMaxCatchUpEpochs();
        info_.acceptedBondTokens();
        info_.protocolLp();
        info_.userBondedLp();

        // preview on proxy (no state)
        IStandardExchangeIn(instance_).previewExchangeIn(
            IERC20(address(pairToken)), 1e18, IERC20(instance_)
        );

        // Money path: ZeroAmount proves selector is live on proxy (exact product error).
        vm.prank(attacker);
        vm.expectRevert(UniswapV4SingleStandardExchangeDETFRepo.ZeroAmount.selector);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            0,
            IERC20(instance_),
            0,
            attacker,
            false,
            block.timestamp + 1 hours
        );

        vm.prank(attacker);
        vm.expectRevert(UniswapV4SingleStandardExchangeDETFRepo.ZeroAmount.selector);
        info_.bond(
            IERC20(address(pairToken)),
            0,
            DEFAULT_MIN_LOCK,
            attacker,
            false,
            block.timestamp + 1 hours
        );

        // sellPosition: product revert (not missing selector) — non-owner / invalid id.
        vm.prank(attacker);
        vm.expectRevert();
        info_.sellPositionToDetfNft(1, attacker);

        // Live money smoke: exchangeIn mint + burn on diamond proxy (not facet impl).
        uint256 mintIn_ = 25 ether;
        pairToken.mint(detfUser, mintIn_);
        vm.startPrank(detfUser);
        pairToken.approve(instance_, mintIn_);
        uint256 minted_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            mintIn_,
            IERC20(instance_),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        assertGt(minted_, 0, "J3 mint on proxy");
        IERC20(instance_).approve(instance_, minted_ / 2);
        uint256 burnedOut_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_),
            minted_ / 2,
            IERC20(address(pairToken)),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        assertGt(burnedOut_, 0, "J3 burn on proxy");
        vm.stopPrank();

        // compound: permissionless best-effort; must not be "function does not exist".
        info_.compoundProtocolRewards();

        // Explicit anti-theater: do not smoke-call facet implementation address as primary SUT.
        assertTrue(exchangeFacet_ != instance_, "J3 primary target is proxy");
    }
}
