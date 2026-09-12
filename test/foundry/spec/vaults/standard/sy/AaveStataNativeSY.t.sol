// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {AaveV3Stata_Component_FactoryService} from "contracts/protocols/lending/aave/v3.6/AaveV3Stata_Component_FactoryService.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";
import {BaseTest as StataProtocolBase} from "lib/crane/test/foundry/spec/protocols/lending/aave/3.6/extensions/stata-token/TestBase.sol";
import {TestBase_AaveV3StataStandardExchange} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {AaveV3StataStandardExchangeDFPkg} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeDFPkg.sol";
import {AaveV3StataStandardExchangeInFacet} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInFacet.sol";
import {AaveV3StataStandardExchangeOutFacet} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutFacet.sol";
import {AaveV3StataMarkerFacet} from "contracts/protocols/lending/aave/v3.6/AaveV3StataMarkerFacet.sol";

contract AaveStataNativeSYTest is TestBase_AaveV3StataStandardExchange, StataProtocolBase, TransitionQuoteAssertions {
    address internal subject;
    IStandardizedYield internal sy;
    address internal constant HOLDER = address(0x5A7A);

    function setUp() public override(TestBase_AaveV3StataStandardExchange, StataProtocolBase) {
        StataProtocolBase.setUp();
        TestBase_AaveV3StataStandardExchange.setUp();
        subject = _deployStataVault(address(stataTokenV2));
        sy = IStandardizedYield(subject);
    }

    function test_stataNativeMetadataAndRealBacking() public view {
        assertEq(sy.decimals(), IERC20Metadata(underlying).decimals());
        assertEq(sy.yieldToken(), address(stataTokenV2));
        (IStandardizedYield.AssetType kind_, address asset_, uint8 decimals_) = sy.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.TOKEN));
        assertEq(asset_, underlying); assertEq(decimals_, IERC20Metadata(underlying).decimals());
        assertTrue(sy.isValidTokenIn(aToken)); assertTrue(sy.isValidTokenOut(aToken));
        assertEq(sy.exchangeRate(), stataTokenV2.convertToAssets(1e18));
        assertEq(sy.getRewardTokens().length, 0);
        address[] memory facets_ = IDiamondLoupe(subject).facetAddresses();
        for (uint256 i; i < facets_.length; ++i) assertLe(facets_[i].code.length, 24_576);
        address[] memory declared_ = aaveV3StataStandardExchangeDFPkg.facetAddresses();
        (,, address[] memory metadata_) = aaveV3StataStandardExchangeDFPkg.packageMetadata();
        assertEq(declared_.length, 9);
        assertEq(abi.encode(declared_), abi.encode(metadata_));
        for (uint256 i; i < declared_.length; ++i) {
            bytes4[] memory selectors_ = IFacet(declared_[i]).facetFuncs();
            for (uint256 j; j < selectors_.length; ++j) {
                assertEq(IDiamondLoupe(subject).facetAddress(selectors_[j]), declared_[i]);
            }
        }

    }

    function _depositBase() internal returns (uint256 shares_) {
        uint256 amount_ = 10 ether; _fundUnderlying(amount_, HOLDER);
        uint256 quoted_ = sy.previewDeposit(underlying, amount_);
        vm.startPrank(HOLDER); IERC20(underlying).approve(subject, amount_);
        shares_ = sy.deposit(HOLDER, underlying, amount_, quoted_); vm.stopPrank();
        assertEq(shares_, quoted_); assertEq(sy.balanceOf(HOLDER), shares_);
    }

    function test_stataBaseDepositAndUnderlyingRedemption() public {
        uint256 shares_ = _depositBase(); uint256 quote_ = sy.previewRedeem(underlying, shares_ / 2);
        uint256 before_ = IERC20(underlying).balanceOf(HOLDER);
        vm.prank(HOLDER); assertEq(sy.redeem(HOLDER, shares_ / 2, underlying, quote_, false), quote_);
        assertEq(IERC20(underlying).balanceOf(HOLDER) - before_, quote_);
        assertEq(sy.balanceOf(HOLDER), shares_ - shares_ / 2);
    }

    function test_stataExistingYieldTokenRoundTrip() public {
        _fundUnderlying(10 ether, HOLDER);
        vm.startPrank(HOLDER); IERC20(underlying).approve(address(stataTokenV2), 10 ether);
        uint256 amount_ = stataTokenV2.deposit(10 ether, HOLDER);
        stataTokenV2.approve(subject, amount_);
        uint256 shares_ = sy.deposit(HOLDER, address(stataTokenV2), amount_, 0);
        uint256 quote_ = sy.previewRedeem(address(stataTokenV2), shares_);
        assertEq(sy.redeem(HOLDER, shares_, address(stataTokenV2), quote_, false), quote_);
        vm.stopPrank(); assertEq(stataTokenV2.balanceOf(HOLDER), quote_);
    }

    function test_stataATokenRouteUsesActualStataConversion() public {
        _fundAToken(10 ether, HOLDER);
        uint256 amount_ = IERC20(aToken).balanceOf(HOLDER);
        uint256 quote_ = sy.previewDeposit(aToken, amount_);
        vm.startPrank(HOLDER); IERC20(aToken).approve(subject, amount_);
        uint256 shares_ = sy.deposit(HOLDER, aToken, amount_, quote_);
        uint256 expected_ = sy.previewRedeem(aToken, shares_ / 2);
        uint256 before_ = IERC20(aToken).balanceOf(HOLDER);
        assertEq(sy.redeem(HOLDER, shares_ / 2, aToken, expected_, false), expected_);
        vm.stopPrank(); assertApproxEqAbs(IERC20(aToken).balanceOf(HOLDER) - before_, expected_, 1);
    }

    function test_stataInternalBalanceConsumesOnlyRequestedShares() public {
        uint256 shares_ = _depositBase();
        vm.prank(HOLDER); sy.transfer(subject, shares_);
        uint256 quote_ = sy.previewRedeem(address(stataTokenV2), shares_ / 3);
        vm.prank(HOLDER); sy.redeem(HOLDER, shares_ / 3, address(stataTokenV2), quote_, true);
        assertEq(sy.balanceOf(subject), shares_ - shares_ / 3);
    }

    function test_stataExactOutputBurnsRequiredSharesAndPreservesMaximumRemainder() public {
        uint256 shares_ = _depositBase();
        uint256 desired_ = sy.previewRedeem(underlying, shares_ / 4);
        uint256 required_ = IStandardExchangeOut(subject).previewExchangeOut(IERC20(subject), IERC20(underlying), desired_);
        assertLt(required_, shares_);
        uint256 before_ = IERC20(underlying).balanceOf(HOLDER);
        vm.prank(HOLDER);
        assertEq(IStandardExchangeOut(subject).exchangeOut(IERC20(subject), shares_, IERC20(underlying), desired_, HOLDER, false, block.timestamp), required_);
        assertEq(sy.balanceOf(HOLDER), shares_ - required_);
        assertEq(IERC20(underlying).balanceOf(HOLDER) - before_, desired_);
    }

    function test_stataSlippageAndUnsupportedTokenRevertAtomically() public {
        uint256 shares_ = _depositBase();
        uint256 quote_ = sy.previewRedeem(underlying, shares_ / 2);
        vm.prank(HOLDER); vm.expectRevert(); sy.redeem(HOLDER, shares_ / 2, underlying, quote_ + 1, false);
        assertEq(sy.balanceOf(HOLDER), shares_);
        vm.prank(HOLDER); vm.expectRevert(); sy.deposit(HOLDER, address(0xBAD), 1, 0);
        assertEq(sy.balanceOf(HOLDER), shares_);
    }

    function test_stataTransitionSequenceAndExternalDepositsPreserveBufferedInventory() public {
        _depositBase();
        vm.prank(owner); IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(subject, 0.07e18);
        _fundUnderlying(100 ether, HOLDER);
        _assertQuoteSequence(subject, IERC20(underlying), HOLDER, 1 ether);
        vm.prank(HOLDER); IERC20(subject).transfer(address(this), 1 ether);
        _fundUnderlying(100 ether, address(this));
        _assertExternalDepositQuote(subject, IERC20(underlying), IERC20(underlying), 10 ether, HOLDER);
        IERC20(underlying).approve(address(stataTokenV2), 20 ether);
        uint256 receipt = stataTokenV2.deposit(20 ether, address(this));
        _assertExternalDepositQuote(subject, IERC20(address(stataTokenV2)), IERC20(underlying), receipt / 2, HOLDER);
        _assertExternalExchangeQuote(subject, IERC20(address(stataTokenV2)), IERC20(underlying), receipt / 2);
        _fundAToken(20 ether, address(this));
        _assertExternalDepositQuote(subject, IERC20(aToken), IERC20(underlying), 10 ether, HOLDER);
    }

    function test_stataCurrentFacetCannotReuseOccupiedLegacyNamespace() public {
        bytes memory otherCode = ArtifactCreationCode.creationCode("ERC20Facet.sol:ERC20Facet");
        IFacet occupied = create3Factory.deployFacet(otherCode, keccak256(abi.encode("AaveV3StataStandardExchangeInFacet")));
        IFacet current = AaveV3Stata_Component_FactoryService.deployAaveV3StataStandardExchangeInFacet(create3Factory);
        assertNotEq(address(current), address(occupied), "legacy occupied namespace cannot select stale implementation");
        assertEq(address(current), address(aaveV3StataStandardExchangeInFacet), "current code deployment is deterministic");
        assertEq(current.facetName(), "AaveV3StataStandardExchangeInFacet");
    }
}
