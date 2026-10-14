// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeSYExecutionAssertions} from "contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol";

import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_MorphoBlueStandardExchange} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";
import {MorphoBlueStandardExchangeDFPkg} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeDFPkg.sol";
import {MorphoBlueStandardExchangeMarkerFacet} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeMarkerFacet.sol";
import {MorphoBlueERC4626Facet} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueERC4626Facet.sol";
import {MorphoBlueStandardExchangeInFacet} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeInFacet.sol";
import {MorphoBlueStandardExchangeOutFacet} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeOutFacet.sol";

contract MorphoBlueNativeSYTest is TestBase_MorphoBlueStandardExchange, NativeSYExecutionAssertions {
    function _sy() internal view returns (IStandardizedYield) { return IStandardizedYield(se); }

    /// @notice Discovery and native previews read local metadata and the shared internal quote.
    function test_morphoSYPreviewDoesNotSelfCallAssetOrExchange() public {
        IStandardizedYield sy_ = _sy();
        vm.prank(user);
        uint256 shares_ = sy_.deposit(user, address(loanToken), 1_000e18, 0);
        uint256 deposit_ = seIn.previewExchangeIn(IERC20(address(loanToken)), 1e18, IERC20(se));
        uint256 redeem_ = seIn.previewExchangeIn(IERC20(se), shares_ / 10, IERC20(address(loanToken)));
        vm.expectCall(se, abi.encodeWithSelector(IERC4626.asset.selector), uint64(0));
        vm.expectCall(se, abi.encodeWithSelector(IStandardExchangeIn.previewExchangeIn.selector), uint64(0));
        assertEq(sy_.previewDeposit(address(loanToken), 1e18), deposit_);
        assertEq(sy_.previewRedeem(address(loanToken), shares_ / 10), redeem_);
    }
    function test_morphoNativeSYMetadataAndMarketLedger() public view {
        IStandardizedYield sy_ = _sy();
        assertEq(sy_.yieldToken(), address(0)); assertEq(sy_.decimals(), 18);
        assertTrue(IERC165(se).supportsInterface(type(IStandardizedYield).interfaceId));
        (IStandardizedYield.AssetType type_, address asset_, uint8 precision_) = sy_.assetInfo();
        assertEq(uint256(type_), uint256(IStandardizedYield.AssetType.TOKEN)); assertEq(asset_, address(loanToken)); assertEq(precision_, 18);
        assertEq(sy_.getTokensIn().length, 1); assertEq(sy_.getTokensOut()[0], address(loanToken));
        assertEq(sy_.getRewardTokens().length, 0); assertEq(sy_.exchangeRate(), se4626.convertToAssets(1e18));
        address[] memory facets_ = IDiamondLoupe(se).facetAddresses();
        for (uint256 i_; i_ < facets_.length; ++i_) assertLe(facets_[i_].code.length, 24_576);
        assertLe(address(morphoBlueStandardExchangeDFPkg).code.length, 24_576);
    }
    function test_morphoSYRoundTripMatchesExistingSEAndAccruedAssets() public noSelfCalls(se) {
        IStandardizedYield sy_ = _sy(); uint256 amount_ = 1_000e18;
        uint256 quote_ = seIn.previewExchangeIn(IERC20(address(loanToken)), amount_, IERC20(se));
        vm.prank(user); uint256 shares_ = sy_.deposit(user, address(loanToken), amount_, quote_);
        assertEq(shares_, quote_); assertGt(_expectedSupplyOf(se), 0);
        uint256 redemption_ = sy_.previewRedeem(address(loanToken), shares_);
        uint256 before_ = loanToken.balanceOf(user); vm.prank(user);
        assertEq(sy_.redeem(user, shares_, address(loanToken), redemption_, false), redemption_);
        assertEq(loanToken.balanceOf(user) - before_, redemption_); assertEq(sy_.balanceOf(user), 0);
    }
    function test_morphoSYInternalRedemptionPreservesRemainingProxyShares() public noSelfCalls(se) {
        AtomicPretransferCaller atomic = new AtomicPretransferCaller();
        IStandardizedYield sy_ = _sy(); vm.prank(user); uint256 shares_ = sy_.deposit(user, address(loanToken), 1_000e18, 0);
        vm.prank(user); sy_.transfer(se, shares_);
        uint256 portion_ = shares_ / 3; uint256 quote_ = sy_.previewRedeem(address(loanToken), portion_);
        vm.prank(user); assertEq(abi.decode(atomic.execute(address(sy_), abi.encodeCall(IStandardizedYield.redeem, (user, portion_, address(loanToken), quote_, true))), (uint256)), quote_);
        assertEq(sy_.balanceOf(se), shares_ - portion_); assertEq(sy_.balanceOf(user), 0);
    }
    function test_morphoSYRateIncludesUnsettledInterestWithoutASecondRewardLedger() public {
        IStandardizedYield sy_ = _sy(); vm.prank(user); sy_.deposit(user, address(loanToken), 1_000e18, 0);
        _borrowFromMarket(2_000e18, 700e18); uint256 before_ = sy_.exchangeRate();
        vm.warp(block.timestamp + 1 days);
        assertGt(sy_.exchangeRate(), before_); assertEq(sy_.exchangeRate(), se4626.convertToAssets(1e18));
        assertEq(sy_.accruedRewards(user).length, 0); assertEq(sy_.claimRewards(user).length, 0);
    }
    function test_morphoSYRetainsLiquidityFailureAndAtomicSlippage() public {
        IStandardizedYield sy_ = _sy(); uint256 before_ = loanToken.balanceOf(user);
        uint256 quote_ = sy_.previewDeposit(address(loanToken), 1_000e18);
        vm.expectRevert(); vm.prank(user); sy_.deposit(user, address(loanToken), 1_000e18, quote_ + 1);
        assertEq(loanToken.balanceOf(user), before_); assertEq(sy_.totalSupply(), 0);
        vm.prank(user); uint256 shares_ = sy_.deposit(user, address(loanToken), 1_000e18, 0);
        _borrowFromMarket(2_000e18, 700e18);
        vm.expectRevert(); vm.prank(user); sy_.redeem(user, shares_, address(loanToken), 0, false);
        assertEq(sy_.balanceOf(user), shares_);
    }
    function test_morphoSYKeepsSixAndNineDecimalLoanUnits() public {
        for (uint8 decimals_ = 6; decimals_ <= 9; decimals_ += 3) {
            MintableERC20Decimals loan_ = new MintableERC20Decimals("Native Loan", "LOAN", decimals_);
            MarketParams memory params_ = marketParams; params_.loanToken = address(loan_); morpho.createMarket(params_);
            address instance_ = _deployVault(morpho, params_); IStandardizedYield sy_ = IStandardizedYield(instance_);
            uint256 amount_ = 1_000 * 10 ** decimals_; loan_.mint(user, amount_);
            vm.startPrank(user); loan_.approve(instance_, amount_);
            uint256 shares_ = sy_.deposit(user, address(loan_), amount_, sy_.previewDeposit(address(loan_), amount_));
            (,,uint8 reported_) = sy_.assetInfo(); assertEq(reported_, decimals_); assertEq(sy_.decimals(), 18);
            assertEq(sy_.exchangeRate(), IERC4626(instance_).convertToAssets(1e18));
            uint256 quote_ = sy_.previewRedeem(address(loan_), shares_);
            assertEq(sy_.redeem(user, shares_, address(loan_), quote_, false), quote_);
            vm.stopPrank(); assertEq(loan_.balanceOf(user), quote_);
        }
    }
}
