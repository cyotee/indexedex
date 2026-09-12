// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {TestBase_LidoWstETHStandardExchange} from "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {TestBase_EtherFiWeETHStandardExchange} from "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {TestBase_RocketPoolRETHStandardExchange} from "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {LidoWstETHStandardExchangeDFPkg} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeDFPkg.sol";
import {LidoWstETHStandardExchangeInFacet} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeInFacet.sol";
import {LidoWstETHStandardExchangeOutFacet} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutFacet.sol";
import {LidoWstETHMarkerFacet} from "contracts/protocols/staking/lido/LidoWstETHMarkerFacet.sol";
import {LidoWstETHRebalanceFacet} from "contracts/protocols/staking/lido/LidoWstETHRebalanceFacet.sol";
import {EtherFiWeETHStandardExchangeDFPkg} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeDFPkg.sol";
import {EtherFiWeETHStandardExchangeInFacet} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeInFacet.sol";
import {EtherFiWeETHStandardExchangeOutFacet} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutFacet.sol";
import {EtherFiWeETHMarkerFacet} from "contracts/protocols/staking/etherfi/EtherFiWeETHMarkerFacet.sol";
import {EtherFiWeETHRebalanceFacet} from "contracts/protocols/staking/etherfi/EtherFiWeETHRebalanceFacet.sol";
import {RocketPoolRETHStandardExchangeDFPkg} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeDFPkg.sol";
import {RocketPoolRETHStandardExchangeInFacet} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeInFacet.sol";
import {RocketPoolRETHStandardExchangeOutFacet} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutFacet.sol";
import {RocketPoolRETHMarkerFacet} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHMarkerFacet.sol";
import {RocketPoolRETHRebalanceFacet} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHRebalanceFacet.sol";

abstract contract LiquidStakingSYBehavior is Test {
    address internal constant HOLDER = address(0x51ED);
    function _subject() internal view virtual returns (address);
    function _yield() internal view virtual returns (address);
    function _wrappedEth() internal view virtual returns (address);
    function _fundYield(address to_, uint256 amount_) internal virtual;
    function _sy() internal view returns (IStandardizedYield) { return IStandardizedYield(_subject()); }

    function test_liquidStakingNativeMetadataAndSelectors() public view {
        IStandardizedYield sy_ = _sy();
        assertEq(sy_.yieldToken(), _yield());
        (IStandardizedYield.AssetType kind_, address asset_, uint8 dec_) = sy_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.TOKEN));
        assertEq(asset_, _wrappedEth()); assertEq(dec_, 18);
        assertTrue(sy_.isValidTokenIn(_yield())); assertTrue(sy_.isValidTokenOut(_wrappedEth()));
        assertGt(sy_.exchangeRate(), 0);
        assertEq(sy_.getRewardTokens().length, 0);
        address[] memory facets_ = IDiamondLoupe(_subject()).facetAddresses();
        for (uint256 i; i < facets_.length; ++i) assertLe(facets_[i].code.length, 24_576);
    }

    function _depositYield() internal returns (uint256 shares_) {
        _fundYield(HOLDER, 10 ether);
        uint256 amount_ = IERC20(_yield()).balanceOf(HOLDER);
        uint256 preview_ = _sy().previewDeposit(_yield(), amount_);
        vm.startPrank(HOLDER); IERC20(_yield()).approve(_subject(), amount_);
        shares_ = _sy().deposit(HOLDER, _yield(), amount_, preview_); vm.stopPrank();
        assertEq(shares_, preview_); assertEq(_sy().balanceOf(HOLDER), shares_);
    }

    function test_liquidStakingYieldRoundTripMatchesStandardQuotes() public {
        uint256 shares_ = _depositYield();
        uint256 amount_ = shares_ / 2;
        uint256 quote_ = _sy().previewRedeem(_yield(), amount_);
        assertEq(quote_, IStandardExchangeIn(_subject()).previewExchangeIn(IERC20(_subject()), amount_, IERC20(_yield())));
        uint256 before_ = IERC20(_yield()).balanceOf(HOLDER);
        vm.prank(HOLDER); assertEq(_sy().redeem(HOLDER, amount_, _yield(), quote_, false), quote_);
        assertEq(IERC20(_yield()).balanceOf(HOLDER) - before_, quote_);
        assertEq(_sy().balanceOf(HOLDER), shares_ - amount_);
    }

    function test_liquidStakingInternalRedemptionKeepsUnburnedShares() public {
        uint256 shares_ = _depositYield();
        vm.prank(HOLDER); _sy().transfer(_subject(), shares_);
        uint256 amount_ = shares_ / 3;
        uint256 quote_ = _sy().previewRedeem(_yield(), amount_);
        vm.prank(HOLDER); _sy().redeem(HOLDER, amount_, _yield(), quote_, true);
        assertEq(_sy().balanceOf(_subject()), shares_ - amount_);
        assertEq(_sy().balanceOf(HOLDER), 0);
    }

    function test_liquidStakingSlippageRollsBackCustodyAndShares() public {
        uint256 shares_ = _depositYield();
        uint256 quote_ = _sy().previewRedeem(_yield(), shares_ / 2);
        uint256 held_ = IERC20(_yield()).balanceOf(_subject());
        vm.prank(HOLDER); vm.expectRevert(); _sy().redeem(HOLDER, shares_ / 2, _yield(), quote_ + 1, false);
        assertEq(_sy().balanceOf(HOLDER), shares_);
        assertEq(IERC20(_yield()).balanceOf(_subject()), held_);
    }
}

contract LidoNativeSYTest is TestBase_LidoWstETHStandardExchange, LiquidStakingSYBehavior, TransitionQuoteAssertions {
    function _seedLidoQuoteBook() private {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0.07e18);
        _seedVaultInventory(200 ether, 200 ether);
        _dealWeth(address(this), 100 ether);
        _mintWstViaSt(address(this), 100 ether);
    }

    function test_lidoLiquidSleeveSequenceProjectsFundedFeesAndShares() public {
        _seedLidoQuoteBook();
        _assertQuoteSequence(seVault, IERC20(address(hermeticWeth)), address(this), 1 ether);
    }

    function test_lidoWrappedReceiptSequenceProjectsCompleteReserve() public {
        _seedLidoQuoteBook();
        _assertQuoteSequence(seVault, IERC20(address(hermeticWstEth)), address(this), 1 ether);
    }

    function test_lidoExternalWrappedDepositPreservesBufferedHolderAndFeeRecipient() public {
        _seedLidoQuoteBook();
        address feeRecipient = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticWstEth)), IERC20(address(hermeticWeth)), 7 ether + 19, address(this));
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticWeth)), IERC20(address(hermeticWstEth)), 3 ether + 11, feeRecipient);
    }

    function test_lidoExternalConversionsPreserveFundedSEInventory() public {
        _seedLidoQuoteBook();
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticWstEth)), IERC20(address(hermeticWeth)), 3 ether + 17);
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticWeth)), IERC20(address(hermeticWstEth)), 7 ether + 29);
    }

    function _subject() internal view override returns (address) { return seVault; }
    function _yield() internal view override returns (address) { return address(hermeticWstEth); }
    function _wrappedEth() internal view override returns (address) { return address(hermeticWeth); }
    function _fundYield(address to_, uint256 amount_) internal override { _mintWstViaSt(to_, amount_); }
}
contract EtherFiNativeSYTest is TestBase_EtherFiWeETHStandardExchange, LiquidStakingSYBehavior {
    function _subject() internal view override returns (address) { return seVault; }
    function _yield() internal view override returns (address) { return address(hermeticWeEth); }
    function _wrappedEth() internal view override returns (address) { return address(hermeticWeth); }
    function _fundYield(address to_, uint256 amount_) internal override { _mintWeViaE(to_, amount_); }
}
contract RocketPoolNativeSYTest is TestBase_RocketPoolRETHStandardExchange, LiquidStakingSYBehavior {
    function _subject() internal view override returns (address) { return seVault; }
    function _yield() internal view override returns (address) { return address(hermeticReth); }
    function _wrappedEth() internal view override returns (address) { return address(hermeticWeth); }
    function _fundYield(address to_, uint256 amount_) internal override { _mintReth(to_, amount_); }
}
