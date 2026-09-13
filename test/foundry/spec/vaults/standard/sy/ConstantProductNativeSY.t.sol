// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {CamelotFactory} from "@crane/contracts/protocols/dexes/camelot/v2/stubs/CamelotFactory.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {TestBase_UniswapV2StandardExchange} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol";
import {TestBase_CamelotV2StandardExchange} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";
import {TestBase_AerodromeStandardExchange} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol";
import {UniswapV2StandardExchangeInFacet} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInFacet.sol";
import {UniswapV2StandardExchangeOutFacet} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutFacet.sol";
import {CamelotV2StandardExchangeInFacet} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeInFacet.sol";
import {CamelotV2StandardExchangeOutFacet} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutFacet.sol";

abstract contract ConstantProductNativeSYBehavior is TransitionQuoteAssertions {
    IStandardizedYield internal nativeSY;
    IERC20 internal nativePairA;
    IERC20 internal nativePairB;
    address internal nativeUser = address(0x5A123);
    function _expectedShareDecimals() internal pure virtual returns (uint8) { return 18; }

    function _newNativeTokens() internal {
        nativePairA = IERC20(address(new ERC20PermitMintableStub("SY pair A", "SYA", 18, nativeUser, 10_000 ether)));
        nativePairB = IERC20(address(new ERC20PermitMintableStub("SY pair B", "SYB", 18, nativeUser, 10_000 ether)));
    }

    function _fundLpQuoteCaller() private returns (IERC20 lp, uint256 payment) {
        lp = IERC20(nativeSY.yieldToken());
        vm.startPrank(nativeUser);
        payment = nativeSY.redeem(nativeUser, nativeSY.balanceOf(nativeUser) / 5, address(lp), 0, false);
        lp.transfer(address(this), payment);
        nativePairA.transfer(address(this), 200 ether);
        nativePairB.transfer(address(this), 200 ether);
        nativeSY.transfer(address(this), nativeSY.balanceOf(nativeUser) / 10);
        vm.stopPrank();
        nativePairA.approve(address(nativeSY), 10 ether);
        IStandardExchangeIn(address(nativeSY)).exchangeIn(
            nativePairA, 10 ether, nativePairB, 0, address(this), false, block.timestamp
        );
    }

    function test_lpAccountingSequentialCustodyWithAccruedFees() public {
        (IERC20 lp,) = _fundLpQuoteCaller();
        _assertQuoteSequence(address(nativeSY), lp, address(this), 1 ether);
    }

    function test_lpAccountingExternalDepositsPreserveBothLegsAndDonation() public {
        (IERC20 lp, uint256 payment) = _fundLpQuoteCaller();
        _assertExternalDepositQuote(address(nativeSY), nativePairA, lp, 13 ether + 7, nativeUser);
        _assertExternalDepositQuote(address(nativeSY), nativePairB, lp, 11 ether + 3, nativeUser);
        lp.transfer(address(nativeSY), payment / 7);
        _assertExternalDepositQuote(address(nativeSY), lp, lp, payment / 4, nativeUser);
    }

    function test_lpAccountingExternalConversionsRetainOwnLiquidity() public {
        (IERC20 lp,) = _fundLpQuoteCaller();
        _assertExternalExchangeQuote(address(nativeSY), nativePairA, lp, 7 ether + 13);
        _assertExternalExchangeQuote(address(nativeSY), nativePairB, lp, 5 ether + 17);
    }

    function test_nativeLPMetadataAndCompleteSelectors() public view {
        address lp_ = nativeSY.yieldToken();
        assertEq(lp_, IERC4626(address(nativeSY)).asset());
        (IStandardizedYield.AssetType kind_, address asset_, uint8 decimals_) = nativeSY.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.TOKEN));
        assertEq(asset_, lp_);
        assertEq(decimals_, IERC20Metadata(lp_).decimals());
        assertEq(nativeSY.decimals(), _expectedShareDecimals(), "existing SE decimals are preserved");
        assertEq(nativeSY.getTokensIn().length, 3);
        assertEq(nativeSY.getTokensOut().length, 3);
        assertTrue(nativeSY.isValidTokenIn(address(nativePairA)));
        assertTrue(nativeSY.isValidTokenOut(address(nativePairB)));
        assertTrue(nativeSY.isValidTokenIn(lp_) && nativeSY.isValidTokenOut(lp_));
        assertEq(nativeSY.getRewardTokens().length, 0);
        assertEq(nativeSY.accruedRewards(nativeUser).length, 0);
        assertEq(nativeSY.rewardIndexesStored().length, 0);
        uint256 expected_ = IERC20(lp_).balanceOf(address(nativeSY)) * 1e18 / nativeSY.totalSupply();
        assertApproxEqAbs(nativeSY.exchangeRate(), expected_, 2);
        address facet_ = IDiamondLoupe(address(nativeSY)).facetAddress(IStandardizedYield.deposit.selector);
        assertGt(facet_.code.length, 0);
        assertLe(facet_.code.length, 24_576);
    }

    function test_nativeLPWrapRoundTripUsesExistingShares() public {
        address lp_ = nativeSY.yieldToken();
        uint256 burn_ = nativeSY.balanceOf(nativeUser) / 4;
        uint256 quoted_ = nativeSY.previewRedeem(lp_, burn_);
        vm.startPrank(nativeUser);
        uint256 received_ = nativeSY.redeem(nativeUser, burn_, lp_, quoted_, false);
        assertEq(received_, quoted_);
        IERC20(lp_).approve(address(nativeSY), received_);
        uint256 expected_ = nativeSY.previewDeposit(lp_, received_);
        uint256 before_ = nativeSY.balanceOf(nativeUser);
        uint256 minted_ = nativeSY.deposit(nativeUser, lp_, received_, expected_);
        vm.stopPrank();
        assertEq(minted_, expected_);
        assertEq(nativeSY.balanceOf(nativeUser), before_ + minted_);
        assertEq(IERC20(lp_).balanceOf(nativeUser), 0);
    }

    function test_nativePairDepositAndOtherPairRedemption() public {
        uint256 input_ = 5 ether;
        uint256 quoted_ = nativeSY.previewDeposit(address(nativePairA), input_);
        vm.startPrank(nativeUser);
        nativePairA.approve(address(nativeSY), input_);
        uint256 minted_ = nativeSY.deposit(nativeUser, address(nativePairA), input_, quoted_);
        assertEq(minted_, quoted_);
        uint256 expected_ = nativeSY.previewRedeem(address(nativePairB), minted_);
        uint256 before_ = nativePairB.balanceOf(nativeUser);
        uint256 received_ = nativeSY.redeem(nativeUser, minted_, address(nativePairB), expected_, false);
        vm.stopPrank();
        assertEq(received_, expected_);
        assertEq(nativePairB.balanceOf(nativeUser), before_ + received_);
    }

    function test_nativePartialInternalRedemptionPreservesOtherHeldShares() public {
        uint256 deposit_ = nativeSY.balanceOf(nativeUser) / 2;
        uint256 burn_ = deposit_ / 2;
        address lp_ = nativeSY.yieldToken();
        vm.startPrank(nativeUser);
        nativeSY.transfer(address(nativeSY), deposit_);
        uint256 quoted_ = nativeSY.previewRedeem(lp_, burn_);
        assertEq(nativeSY.redeem(nativeUser, burn_, lp_, quoted_, true), quoted_);
        vm.stopPrank();
        assertEq(nativeSY.balanceOf(address(nativeSY)), deposit_ - burn_);
    }

    function test_nativeSlippageAndUnsupportedTokenAreAtomic() public {
        uint256 quoted_ = nativeSY.previewDeposit(address(nativePairA), 5 ether);
        uint256 before_ = nativePairA.balanceOf(nativeUser);
        vm.startPrank(nativeUser);
        nativePairA.approve(address(nativeSY), 5 ether);
        vm.expectRevert();
        nativeSY.deposit(nativeUser, address(nativePairA), 5 ether, quoted_ + 1);
        assertEq(nativePairA.balanceOf(nativeUser), before_);
        vm.expectRevert();
        nativeSY.deposit(nativeUser, address(0xBAD), 1, 0);
        vm.stopPrank();
    }
}

contract AerodromeNativeSYTest is TestBase_AerodromeStandardExchange, ConstantProductNativeSYBehavior {
    function _aeroProjectionFeesAndInventory() private {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(nativeSY), 7e16);
        vm.startPrank(nativeUser);
        nativePairA.transfer(address(this), 300 ether);
        nativePairB.transfer(address(this), 300 ether);
        nativeSY.transfer(address(this), nativeSY.balanceOf(nativeUser) / 10);
        nativePairA.approve(address(nativeSY), 10 ether);
        IStandardExchangeIn(address(nativeSY)).exchangeIn(nativePairA, 10 ether, nativePairB, 1, nativeUser, false, block.timestamp);
        nativePairB.approve(address(nativeSY), 7 ether);
        IStandardExchangeIn(address(nativeSY)).exchangeIn(nativePairB, 7 ether, nativePairA, 1, nativeUser, false, block.timestamp);
        vm.stopPrank();
        assertGt(IPool(nativeSY.yieldToken()).index0() + IPool(nativeSY.yieldToken()).index1(), 0, "real pool fees accrued");
    }

    function test_aeroProjectionSelectorsAndComponentSizes() public view {
        address exchange = address(nativeSY);
        assertTrue(IERC165(exchange).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId));
        assertTrue(IERC165(exchange).supportsInterface(type(IStandardExchangeExternalQuote).interfaceId));
        bytes4[7] memory selectors = [
            IStandardExchangeTransitionQuote.quoteState.selector,
            IStandardExchangeTransitionQuote.quoteAssets.selector,
            IStandardExchangeTransitionQuote.quoteShareBalance.selector,
            IStandardExchangeTransitionQuote.quoteTotalSupply.selector,
            IStandardExchangeTransitionQuote.quoteTransition.selector,
            IStandardExchangeExternalQuote.quoteExternalDeposit.selector,
            IStandardExchangeExternalQuote.quoteExternalExchange.selector
        ];
        for (uint256 i; i < selectors.length; ++i) {
            address facet = IDiamondLoupe(exchange).facetAddress(selectors[i]);
            assertGt(facet.code.length, 0, "installed projection component");
            assertLe(facet.code.length, 24_576, "deployed component fits EIP-170");
        }
    }

    function test_aeroProjectionSequentialBothAssetsAndCompoundedLpFees() public {
        _aeroProjectionFeesAndInventory();
        uint256 snapshot = vm.snapshotState();
        _assertQuoteSequence(address(nativeSY), nativePairA, nativeUser, 1 ether);
        assertTrue(vm.revertToState(snapshot));
        _assertQuoteSequence(address(nativeSY), nativePairB, nativeUser, 1 ether);
    }

    function test_aeroProjectionExternalDepositsAndLiveLpPayment() public {
        _aeroProjectionFeesAndInventory();
        _assertExternalDepositQuote(address(nativeSY), nativePairA, nativePairB, 11 ether + 13, nativeUser);
        _assertExternalDepositQuote(address(nativeSY), nativePairB, nativePairA, 7 ether + 17, nativeUser);
        nativePairA.approve(address(nativeSY), 10 ether);
        uint256 lp = IStandardExchangeIn(address(nativeSY)).exchangeIn(
            nativePairA, 10 ether, IERC20(nativeSY.yieldToken()), 1, address(this), false, block.timestamp
        );
        _assertExternalDepositQuote(address(nativeSY), IERC20(nativeSY.yieldToken()), nativePairB, lp, nativeUser);
    }

    function test_aeroProjectionExternalSwapsAndLpRedemptionPreserveOwnShares() public {
        _aeroProjectionFeesAndInventory();
        _assertExternalExchangeQuote(address(nativeSY), nativePairA, nativePairB, 3 ether + 11);
        _assertExternalExchangeQuote(address(nativeSY), nativePairB, nativePairA, 2 ether + 13);
        nativePairA.approve(address(nativeSY), 10 ether);
        uint256 lp = IStandardExchangeIn(address(nativeSY)).exchangeIn(
            nativePairA, 10 ether, IERC20(nativeSY.yieldToken()), 1, address(this), false, block.timestamp
        );
        _assertExternalExchangeQuote(address(nativeSY), IERC20(nativeSY.yieldToken()), nativePairB, lp);
    }

    function test_aeroProjectionCompoundPaysActualLpWithoutIssuingSeFees() public {
        _aeroProjectionFeesAndInventory();
        address recipient = address(indexedexManager.feeTo());
        IERC20 lp = IERC20(nativeSY.yieldToken());
        uint256 feeLpBefore = lp.balanceOf(recipient);
        uint256 feeSharesBefore = nativeSY.balanceOf(recipient);
        _assertExternalDepositQuote(address(nativeSY), nativePairA, nativePairB, 11 ether + 13, recipient);
        assertGt(lp.balanceOf(recipient), feeLpBefore, "compound pays funded LP fees");
        assertEq(nativeSY.balanceOf(recipient), feeSharesBefore, "compound does not issue SE shares");
    }

    function test_aeroProjectionDonationRemainsBackingBeforeLpPayment() public {
        _aeroProjectionFeesAndInventory();
        nativePairA.approve(address(nativeSY), 10 ether);
        IERC20 lp = IERC20(nativeSY.yieldToken());
        uint256 acquired = IStandardExchangeIn(address(nativeSY)).exchangeIn(
            nativePairA, 10 ether, lp, 1, address(this), false, block.timestamp
        );
        uint256 donated = acquired / 3;
        lp.transfer(address(nativeSY), donated);
        _assertExternalDepositQuote(address(nativeSY), lp, nativePairB, acquired - donated, nativeUser);
    }

    function test_aeroProjectionExternalLpBurnIncludesPoolHeldLpAndUnsyncedTokens() public {
        _aeroProjectionFeesAndInventory();
        nativePairA.approve(address(nativeSY), 10 ether);
        IERC20 lp = IERC20(nativeSY.yieldToken());
        uint256 acquired = IStandardExchangeIn(address(nativeSY)).exchangeIn(
            nativePairA, 10 ether, lp, 1, address(this), false, block.timestamp
        );
        uint256 poolHeld = acquired / 5;
        lp.transfer(address(lp), poolHeld);
        nativePairA.transfer(address(lp), 17);
        nativePairB.transfer(address(lp), 29);
        uint256 reserve = lp.balanceOf(address(nativeSY));
        uint256 supply = lp.totalSupply();
        _assertExternalExchangeQuote(address(nativeSY), lp, nativePairB, acquired - poolHeld);
        assertEq(lp.balanceOf(address(lp)), 0, "actual pool burns its complete held LP balance");
        assertEq(lp.totalSupply(), supply - acquired, "submitted and previously pool-held LP both burn");
        assertEq(lp.balanceOf(address(nativeSY)), reserve, "SE-held LP is not external payment");
    }

    function test_nativeExactOutputAssetADepositAfterFees() public { _fundedExactOutputCase(0, true); }
    function test_nativeExactOutputAssetBDepositAfterFees() public { _fundedExactOutputCase(1, true); }
    function test_nativeExactOutputLpDepositAfterFees() public { _fundedExactOutputCase(2, true); }
    function test_nativeExactOutputAssetAWithdrawalAfterFees() public { _fundedExactOutputCase(0, false); }
    function test_nativeExactOutputAssetBWithdrawalAfterFees() public { _fundedExactOutputCase(1, false); }
    function test_nativeExactOutputLpWithdrawalAfterFees() public { _fundedExactOutputCase(2, false); }
    function test_nativeExactOutputAssetAToLpAfterFees() public { _passthroughExactOutputCase(0, true); }
    function test_nativeExactOutputAssetBToLpAfterFees() public { _passthroughExactOutputCase(1, true); }
    function test_nativeExactOutputLpToAssetAAfterFees() public { _passthroughExactOutputCase(0, false); }
    function test_nativeExactOutputLpToAssetBAfterFees() public { _passthroughExactOutputCase(1, false); }

    function _fundLpAndAccrueFees() private returns (IERC20 lp_) {
        lp_ = IERC20(nativeSY.yieldToken());
        vm.startPrank(nativeUser);
        nativeSY.redeem(nativeUser, nativeSY.balanceOf(nativeUser) / 4, address(lp_), 0, false);
        nativePairA.approve(address(nativeSY), 10 ether);
        IStandardExchangeIn(address(nativeSY)).exchangeIn(nativePairA, 10 ether, nativePairB, 0, nativeUser, false, block.timestamp);
        vm.stopPrank();
        assertGt(IPool(address(lp_)).index0() + IPool(address(lp_)).index1(), 0);
    }

    function _fundedExactOutputCase(uint256 route_, bool deposit_) private {
        IERC20 share_ = IERC20(address(nativeSY)); IERC20 lp_ = _fundLpAndAccrueFees();
        IERC20[3] memory payments_ = [nativePairA, nativePairB, lp_];
        if (deposit_) _assertFundedExactOutput(payments_[route_], share_, 1 ether);
        else _assertFundedExactOutput(share_, payments_[route_], 1 ether);
    }

    function _passthroughExactOutputCase(uint256 route_, bool deposit_) private {
        IERC20 lp_ = _fundLpAndAccrueFees();
        IERC20 payment_ = route_ == 0 ? nativePairA : nativePairB;
        if (deposit_) _assertFundedExactOutput(payment_, lp_, 1 ether);
        else _assertFundedExactOutput(lp_, payment_, 1 ether);
    }

    function test_nativeExactOutputLpPrepaidMaximumRefundsOnlyItsSurplusAfterFees() public {
        IERC20 lp_ = _fundLpAndAccrueFees();
        IStandardExchangeOut exchange_ = IStandardExchangeOut(address(nativeSY));
        uint256 target_ = 1 ether;
        uint256 required_ = exchange_.previewExchangeOut(lp_, IERC20(address(nativeSY)), target_);
        uint256 maximum_ = required_ * 2;
        uint256 balance_ = lp_.balanceOf(nativeUser);
        uint256 shares_ = nativeSY.balanceOf(nativeUser);
        vm.startPrank(nativeUser);
        lp_.transfer(address(nativeSY), maximum_);
        assertEq(exchange_.exchangeOut(lp_, maximum_, IERC20(address(nativeSY)), target_, nativeUser, true, block.timestamp), required_);
        vm.stopPrank();
        assertEq(lp_.balanceOf(nativeUser), balance_ - required_);
        assertEq(nativeSY.balanceOf(nativeUser), shares_ + target_);
    }

    function test_nativeExactInputLpUnfundedPrepaymentCannotSpendNewlyCompoundedFees() public {
        IERC20 lp_ = _fundLpAndAccrueFees();
        uint256 held_ = lp_.balanceOf(address(nativeSY));
        uint256 shares_ = nativeSY.balanceOf(nativeUser);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1), uint256(0)));
        vm.prank(nativeUser);
        IStandardExchangeIn(address(nativeSY)).exchangeIn(lp_, 1, IERC20(address(nativeSY)), 0, nativeUser, true, block.timestamp);
        assertEq(lp_.balanceOf(address(nativeSY)), held_);
        assertEq(nativeSY.balanceOf(nativeUser), shares_);
    }

    function test_nativeDonatedLpExactInputWithdrawalsHonorActualBacking() public { _donatedLpWithdrawalCase(false); }
    function test_nativeDonatedLpExactOutputWithdrawalsHonorActualBacking() public { _donatedLpWithdrawalCase(true); }

    function _donatedLpWithdrawalCase(bool exactOutput_) private {
        IERC20 lp_ = IERC20(nativeSY.yieldToken());
        vm.startPrank(nativeUser);
        nativeSY.redeem(nativeUser, nativeSY.balanceOf(nativeUser) / 4, address(lp_), 0, false);
        lp_.transfer(address(nativeSY), 1 ether);
        vm.stopPrank();
        assertEq(IPool(address(lp_)).index0() + IPool(address(lp_)).index1(), 0, "donated LP is tested without fee compounding to update the book");
        IERC20[3] memory outputs_ = [nativePairA, nativePairB, lp_];
        for (uint256 i_; i_ < outputs_.length; ++i_) {
            uint256 snapshot_ = vm.snapshotState();
            if (exactOutput_) _assertFundedExactOutput(IERC20(address(nativeSY)), outputs_[i_], 1 ether);
            else {
                uint256 quote_ = nativeSY.previewRedeem(address(outputs_[i_]), 1 ether);
                uint256 before_ = outputs_[i_].balanceOf(nativeUser);
                vm.prank(nativeUser);
                assertEq(nativeSY.redeem(nativeUser, 1 ether, address(outputs_[i_]), quote_, false), quote_);
                assertEq(outputs_[i_].balanceOf(nativeUser), before_ + quote_);
            }
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function test_nativeExactOutputLpUnfundedPrepaymentCannotSpendNewlyCompoundedFees() public {
        IERC20 lp_ = _fundLpAndAccrueFees();
        uint256 held_ = lp_.balanceOf(address(nativeSY));
        uint256 shares_ = nativeSY.balanceOf(nativeUser);
        // No LP is pushed. Even a single unit must fail against the pre-compound book.
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1), uint256(0)));
        vm.prank(nativeUser);
        IStandardExchangeOut(address(nativeSY)).exchangeOut(lp_, 1, IERC20(address(nativeSY)), 1, nativeUser, true, block.timestamp);
        assertEq(lp_.balanceOf(address(nativeSY)), held_);
        assertEq(nativeSY.balanceOf(nativeUser), shares_);
    }

    function test_nativeExactInputAssetAPrepaymentValidatedBeforeFees() public { _unfundedRawPrepayment(false, false); }
    function test_nativeExactInputAssetBPrepaymentValidatedBeforeFees() public { _unfundedRawPrepayment(true, false); }
    function test_nativeExactOutputAssetAPrepaymentValidatedBeforeFees() public { _unfundedRawPrepayment(false, true); }
    function test_nativeExactOutputAssetBPrepaymentValidatedBeforeFees() public { _unfundedRawPrepayment(true, true); }

    function _unfundedRawPrepayment(bool pairB_, bool exactOutput_) private {
        IERC20 lp_ = _fundLpAndAccrueFees();
        IERC20 payment_ = pairB_ ? nativePairB : nativePairA;
        uint256 held_ = lp_.balanceOf(address(nativeSY));
        uint256 shares_ = nativeSY.balanceOf(nativeUser);
        uint256 tokens_ = payment_.balanceOf(nativeUser);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1), uint256(0)));
        vm.prank(nativeUser);
        if (exactOutput_) {
            IStandardExchangeOut(address(nativeSY)).exchangeOut(payment_, 1, IERC20(address(nativeSY)), 1, nativeUser, true, block.timestamp);
        } else {
            IStandardExchangeIn(address(nativeSY)).exchangeIn(payment_, 1, IERC20(address(nativeSY)), 0, nativeUser, true, block.timestamp);
        }
        assertEq(lp_.balanceOf(address(nativeSY)), held_);
        assertEq(nativeSY.balanceOf(nativeUser), shares_);
        assertEq(payment_.balanceOf(nativeUser), tokens_);
    }

    function test_nativeExactOutputAssetAPrepaidMaximumRefundsOnlyItsSurplusAfterFees() public { _rawPrepaidMaximum(nativePairA); }
    function test_nativeExactOutputAssetBPrepaidMaximumRefundsOnlyItsSurplusAfterFees() public { _rawPrepaidMaximum(nativePairB); }

    function _rawPrepaidMaximum(IERC20 payment_) private {
        _fundLpAndAccrueFees();
        IStandardExchangeOut exchange_ = IStandardExchangeOut(address(nativeSY));
        uint256 target_ = 1 ether;
        uint256 required_ = exchange_.previewExchangeOut(payment_, IERC20(address(nativeSY)), target_);
        uint256 maximum_ = required_ * 2;
        uint256 balance_ = payment_.balanceOf(nativeUser);
        uint256 shares_ = nativeSY.balanceOf(nativeUser);
        vm.startPrank(nativeUser);
        payment_.transfer(address(nativeSY), maximum_);
        assertEq(exchange_.exchangeOut(payment_, maximum_, IERC20(address(nativeSY)), target_, nativeUser, true, block.timestamp), required_);
        vm.stopPrank();
        assertEq(payment_.balanceOf(nativeUser), balance_ - required_);
        assertGe(nativeSY.balanceOf(nativeUser), shares_ + target_);
    }

    function _assertFundedExactOutput(IERC20 input_, IERC20 output_, uint256 target_) private {
        IStandardExchangeOut exchange_ = IStandardExchangeOut(address(nativeSY));
        IStandardExchangeIn forward_ = IStandardExchangeIn(address(nativeSY));
        uint256 required_ = exchange_.previewExchangeOut(input_, output_, target_);
        assertGt(required_, 0);
        assertGe(forward_.previewExchangeIn(input_, required_, output_), target_, "quoted input funds the exact output");
        assertLt(forward_.previewExchangeIn(input_, required_ - 1, output_), target_, "one unit less is insufficient");
        uint256 inputBefore_ = input_.balanceOf(nativeUser); uint256 outputBefore_ = output_.balanceOf(nativeUser);
        assertGe(inputBefore_, required_);
        vm.startPrank(nativeUser); input_.approve(address(nativeSY), required_);
        vm.expectRevert(); exchange_.exchangeOut(input_, required_ - 1, output_, target_, nativeUser, false, block.timestamp);
        assertEq(input_.balanceOf(nativeUser), inputBefore_); assertEq(output_.balanceOf(nativeUser), outputBefore_);
        assertEq(exchange_.exchangeOut(input_, required_, output_, target_, nativeUser, false, block.timestamp), required_);
        vm.stopPrank();
        assertEq(input_.balanceOf(nativeUser), inputBefore_ - required_);
        assertGe(output_.balanceOf(nativeUser), outputBefore_ + target_);
    }

    function test_nativeDepositsAfterAccruedFeesUsePostCompoundPool() public {
        IStandardExchangeIn exchange_ = IStandardExchangeIn(address(nativeSY));
        vm.startPrank(nativeUser);
        nativePairA.approve(address(nativeSY), 10 ether);
        assertGt(exchange_.exchangeIn(nativePairA, 10 ether, nativePairB, 0, nativeUser, false, block.timestamp), 0);
        vm.stopPrank();
        IPool pool_ = IPool(nativeSY.yieldToken());
        assertGt(pool_.index0() + pool_.index1(), 0, "actual pool swap accrued fees before deposit");
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 snapshot_ = vm.snapshotState();
            IERC20 input_ = i_ == 0 ? nativePairA : nativePairB;
            uint256 amount_ = 8 ether;
            uint256 quote_ = nativeSY.previewDeposit(address(input_), amount_);
            uint256 balance_ = nativeSY.balanceOf(nativeUser);
            uint256 tokens_ = input_.balanceOf(nativeUser);
            uint256 rate_ = nativeSY.exchangeRate();
            assertGt(quote_, 0);
            vm.startPrank(nativeUser);
            input_.approve(address(nativeSY), amount_);
            vm.expectRevert(); nativeSY.deposit(nativeUser, address(input_), amount_, quote_ + 1);
            assertEq(input_.balanceOf(nativeUser), tokens_);
            assertEq(nativeSY.balanceOf(nativeUser), balance_);
            assertEq(nativeSY.deposit(nativeUser, address(input_), amount_, quote_), quote_);
            vm.stopPrank();
            assertEq(input_.balanceOf(nativeUser), tokens_ - amount_);
            assertEq(nativeSY.balanceOf(nativeUser), balance_ + quote_);
            assertGe(nativeSY.exchangeRate(), rate_, "funded fee compounding raises held LP per share");
            assertTrue(vm.revertToState(snapshot_));
        }
    }
    function setUp() public override {
        TestBase_AerodromeStandardExchange.setUp();
        _newNativeTokens();
        vm.startPrank(nativeUser);
        nativePairA.approve(address(aerodromeStandardExchangeDFPkg), 1_000 ether);
        nativePairB.approve(address(aerodromeStandardExchangeDFPkg), 1_000 ether);
        nativeSY = IStandardizedYield(aerodromeStandardExchangeDFPkg.deployVault(
            nativePairA, 1_000 ether, nativePairB, 1_000 ether, nativeUser
        ));
        vm.stopPrank();
    }
}

contract UniswapV2NativeSYTest is TestBase_UniswapV2StandardExchange, ConstantProductNativeSYBehavior {
    function setUp() public override {
        TestBase_UniswapV2StandardExchange.setUp();
        _newNativeTokens();
        vm.startPrank(nativeUser);
        nativePairA.approve(address(uniswapV2StandardExchangeDFPkg), 1_000 ether);
        nativePairB.approve(address(uniswapV2StandardExchangeDFPkg), 1_000 ether);
        nativeSY = IStandardizedYield(uniswapV2StandardExchangeDFPkg.deployVault(
            nativePairA, 1_000 ether, nativePairB, 1_000 ether, nativeUser
        ));
        vm.stopPrank();
    }
}

contract CamelotV2NativeSYTest is TestBase_CamelotV2StandardExchange, ConstantProductNativeSYBehavior {
    function test_camelotProjectionSelectorsUseCurrentQueryFacet() public view {
        address exchange_ = address(nativeSY);
        bytes4[7] memory selectors_ = [
            IStandardExchangeTransitionQuote.quoteState.selector,
            IStandardExchangeTransitionQuote.quoteTransition.selector,
            IStandardExchangeTransitionQuote.quoteAssets.selector,
            IStandardExchangeTransitionQuote.quoteShareBalance.selector,
            IStandardExchangeTransitionQuote.quoteTotalSupply.selector,
            IStandardExchangeExternalQuote.quoteExternalDeposit.selector,
            IStandardExchangeExternalQuote.quoteExternalExchange.selector
        ];
        for (uint256 i; i < selectors_.length; ++i) {
            assertEq(IDiamondLoupe(exchange_).facetAddress(selectors_[i]), address(camelotV2StandardExchangeQueryFacet));
        }
        assertTrue(IERC165(exchange_).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId));
        assertTrue(IERC165(exchange_).supportsInterface(type(IStandardExchangeExternalQuote).interfaceId));
        assertGt(address(camelotV2StandardExchangeQueryFacet).code.length, 0);
        assertLe(address(camelotV2StandardExchangeQueryFacet).code.length, 24_576);
        assertLe(address(camelotV2StandardExchangeInFacet).code.length, 24_576);
        assertLe(address(camelotV2StandardExchangeOutFacet).code.length, 24_576);
    }

    function test_camelotProjectionBothAssetsWithReferralAndHalfOwnerFee() public { _camelotProjectionSequences(50_000); }
    function test_camelotProjectionBothAssetsWithReferralAnd16666OwnerFee() public { _camelotProjectionSequences(16_666); }
    function test_camelotProjectionBothAssetsWithReferralAnd16667OwnerFee() public { _camelotProjectionSequences(16_667); }

    function _camelotProjectionConfigureFees(uint256 ownerShare_) private {
        address beneficiary_ = address(indexedexManager.feeTo());
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(nativeSY), 7e16);
        vm.startPrank(camelotV2Factory.owner());
        CamelotFactory(address(camelotV2Factory)).setOwnerFeeShare(ownerShare_);
        CamelotFactory(address(camelotV2Factory)).setReferrerFeeShare(beneficiary_, 20_000);
        vm.stopPrank();
        ICamelotPair pool_ = ICamelotPair(nativeSY.yieldToken());
        vm.prank(camelotV2Factory.feePercentOwner());
        pool_.setFeePercent(300, 900);
    }

    function _camelotProjectionSequences(uint256 ownerShare_) private {
        _camelotProjectionConfigureFees(ownerShare_);
        uint256 saved_ = vm.snapshotState();
        _assertQuoteSequence(address(nativeSY), nativePairA, nativeUser, 1 ether);
        assertTrue(vm.revertToState(saved_));
        _assertQuoteSequence(address(nativeSY), nativePairB, nativeUser, 1 ether);
    }

    function test_camelotProjectionFeeRecipientReceivesOnlyActualIssuedFees() public {
        _camelotProjectionConfigureFees(16_667);
        address beneficiary_ = address(indexedexManager.feeTo());
        uint256 shares_ = nativeSY.balanceOf(nativeUser) / 10;
        vm.startPrank(nativeUser);
        nativePairA.transfer(beneficiary_, 100 ether);
        nativeSY.transfer(beneficiary_, shares_);
        // A separate pool swap earns fees without resetting the SE checkpoint.
        nativePairA.approve(address(nativeSY), 10 ether);
        IStandardExchangeIn(address(nativeSY)).exchangeIn(
            nativePairA, 10 ether, nativePairB, 0, nativeUser, false, block.timestamp
        );
        vm.stopPrank();
        IStandardExchangeTransitionQuote quote_ = IStandardExchangeTransitionQuote(address(nativeSY));
        Step memory expected_;
        {
            (bytes memory state_,) = quote_.quoteState(address(nativePairA), beneficiary_);
            (expected_.state, expected_.input, expected_.output, expected_.claim) = quote_.quoteTransition(
                state_, IStandardExchangeTransitionQuote.Operation.DepositExactIn, 31 ether + 7
            );
        }
        {
            uint256 tokensBefore_ = nativePairA.balanceOf(beneficiary_);
            uint256 sharesBefore_ = nativeSY.balanceOf(beneficiary_);
            vm.recordLogs();
            vm.startPrank(beneficiary_);
            nativePairA.approve(address(nativeSY), expected_.input);
            assertEq(nativeSY.deposit(beneficiary_, address(nativePairA), expected_.input, expected_.output), expected_.output);
            vm.stopPrank();
            uint256 referral_ = _camelotTransferReceipts(
                vm.getRecordedLogs(), address(nativePairA), nativeSY.yieldToken(), beneficiary_
            );
            assertGt(referral_, 0, "the depositor also receives the actual pool referral payment");
            assertEq(tokensBefore_ + referral_ - nativePairA.balanceOf(beneficiary_), expected_.input, "gross funded deposit reconciles referral receipts");
            assertGt(nativeSY.balanceOf(beneficiary_) - sharesBefore_ - expected_.output, 0, "earned fees issue additional SE shares");
        }
        assertEq(nativeSY.balanceOf(beneficiary_), quote_.quoteShareBalance(expected_.state));
        assertEq(nativeSY.totalSupply(), quote_.quoteTotalSupply(expected_.state));
        (bytes memory actual_, uint256 claim_) = quote_.quoteState(address(nativePairA), beneficiary_);
        assertEq(claim_, expected_.claim);
        _assertProjectedState(actual_, expected_.state);
    }

    function _camelotTransferReceipts(Vm.Log[] memory logs_, address token_, address sender_, address recipient_)
        private pure returns (uint256 received_)
    {
        for (uint256 i; i < logs_.length; ++i) {
            Vm.Log memory entry_ = logs_[i];
            if (entry_.emitter == token_ && entry_.topics.length == 3
                && entry_.topics[0] == keccak256("Transfer(address,address,uint256)")
                && entry_.topics[1] == bytes32(uint256(uint160(sender_)))
                && entry_.topics[2] == bytes32(uint256(uint160(recipient_)))) {
                received_ += abi.decode(entry_.data, (uint256));
            }
        }
    }

    function _camelotProjectionFundCaller() private returns (IERC20 lp_, uint256 amount_) {
        lp_ = IERC20(nativeSY.yieldToken());
        vm.startPrank(nativeUser);
        amount_ = nativeSY.redeem(nativeUser, nativeSY.balanceOf(nativeUser) / 10, address(lp_), 0, false);
        lp_.transfer(address(this), amount_);
        nativePairA.transfer(address(this), 100 ether);
        nativePairB.transfer(address(this), 100 ether);
        nativeSY.transfer(address(this), nativeSY.balanceOf(nativeUser) / 10);
        vm.stopPrank();
        assertGt(nativeSY.balanceOf(address(this)), 0, "projection holder has funded SE inventory");
    }

    function test_camelotProjectionExternalDepositsKeepAccountingLegAndLpPayment() public {
        _camelotProjectionConfigureFees(16_666);
        (IERC20 lp_, uint256 payment_) = _camelotProjectionFundCaller();
        _assertExternalDepositQuote(address(nativeSY), nativePairA, nativePairB, 13 ether + 7, nativeUser);
        _assertExternalDepositQuote(address(nativeSY), nativePairB, nativePairA, 11 ether + 3, address(indexedexManager.feeTo()));
        _assertExternalDepositQuote(address(nativeSY), lp_, nativePairA, payment_ / 4, nativeUser);
    }

    function test_camelotProjectionExternalLpAndDirectionalConversionsPreserveHeldShares() public {
        _camelotProjectionConfigureFees(16_667);
        (IERC20 lp_, uint256 payment_) = _camelotProjectionFundCaller();
        _assertExternalExchangeQuote(address(nativeSY), lp_, nativePairA, payment_ / 4);
        _assertExternalExchangeQuote(address(nativeSY), nativePairB, nativePairA, 7 ether + 13);
        _assertExternalExchangeQuote(address(nativeSY), nativePairA, nativePairB, 5 ether + 17);
    }

    function test_camelotProjectionPoolDonationsFollowMeasuredInputs() public {
        _camelotProjectionConfigureFees(16_667);
        _camelotProjectionFundCaller();
        address pool_ = nativeSY.yieldToken();
        nativePairA.transfer(pool_, uint256(1 ether) / 3 + 7);
        nativePairB.transfer(pool_, uint256(1 ether) / 5 + 11);
        _assertExternalExchangeQuote(address(nativeSY), nativePairA, nativePairB, 5 ether + 17);
        nativePairA.transfer(pool_, uint256(1 ether) / 7 + 3);
        nativePairB.transfer(pool_, uint256(1 ether) / 11 + 5);
        _assertExternalDepositQuote(address(nativeSY), nativePairA, nativePairB, 7 ether + 13, nativeUser);
    }

    function test_camelotProjectionLpDonationRemainsBackingBeforeLpPayment() public {
        _camelotProjectionConfigureFees(16_666);
        (IERC20 lp_, uint256 payment_) = _camelotProjectionFundCaller();
        lp_.transfer(address(nativeSY), payment_ / 7);
        _assertExternalDepositQuote(address(nativeSY), lp_, nativePairA, payment_ / 4, nativeUser);
    }


    function test_camelotLpPassThroughPreviewMatchesExecution() public {
        address lp_ = nativeSY.yieldToken();
        vm.startPrank(nativeUser);
        uint256 payment_ = nativeSY.redeem(nativeUser, nativeSY.balanceOf(nativeUser) / 10, lp_, 0, false);
        IStandardExchangeIn exchange_ = IStandardExchangeIn(address(nativeSY));
        uint256 preview_ = exchange_.previewExchangeIn(IERC20(lp_), payment_, nativePairA);
        IERC20(lp_).approve(address(nativeSY), payment_);
        uint256 before_ = nativePairA.balanceOf(nativeUser);
        assertEq(exchange_.exchangeIn(IERC20(lp_), payment_, nativePairA, preview_, nativeUser, false, block.timestamp), preview_);
        assertEq(nativePairA.balanceOf(nativeUser) - before_, preview_);
        vm.stopPrank();
    }

    function test_camelotCheckpointTracksLiveBookAfterToken0Deposit() public { _assertCamelotCheckpoint(0, true); }
    function test_camelotCheckpointTracksLiveBookAfterToken1Deposit() public { _assertCamelotCheckpoint(1, true); }
    function test_camelotCheckpointTracksLiveBookAfterToken0Redemption() public { _assertCamelotCheckpoint(0, false); }
    function test_camelotCheckpointTracksLiveBookAfterToken1Redemption() public { _assertCamelotCheckpoint(1, false); }

    function _assertCamelotCheckpoint(uint256 tokenIndex_, bool deposit_) private {
        ICamelotPair pool_ = ICamelotPair(nativeSY.yieldToken());
        address asset_ = tokenIndex_ == 0 ? pool_.token0() : pool_.token1();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(nativeSY), 7e16);
        vm.startPrank(nativeUser);
        if (deposit_) {
            IERC20(asset_).approve(address(nativeSY), 5 ether);
            nativeSY.deposit(nativeUser, asset_, 5 ether, 0);
        } else {
            nativeSY.redeem(nativeUser, nativeSY.balanceOf(nativeUser) / 10, asset_, 0, false);
        }
        vm.stopPrank();
        // Yield checkpoints describe the actual pool ownership after settlement.
        // Inspect the existing proxy ledger without mutating or mocking it.
        (uint112 reserve0_, uint112 reserve1_,,) = pool_.getReserves();
        uint256 heldLp_ = pool_.balanceOf(address(nativeSY));
        uint256 supply_ = pool_.totalSupply();
        uint256 mappingSlot_ = uint256(keccak256(abi.encode("indexedex.vaults.constprodreserve"))) + 4;
        uint256 checkpoint0_ = uint256(vm.load(address(nativeSY), keccak256(abi.encode(pool_.token0(), mappingSlot_))));
        uint256 checkpoint1_ = uint256(vm.load(address(nativeSY), keccak256(abi.encode(pool_.token1(), mappingSlot_))));
        assertEq(checkpoint0_, heldLp_ * reserve0_ / supply_, "token0 checkpoint must use post-operation ownership");
        assertEq(checkpoint1_, heldLp_ * reserve1_ / supply_, "token1 checkpoint must use post-operation ownership");
    }
    function _expectedShareDecimals() internal pure override returns (uint8) { return 27; }
    function setUp() public override {
        TestBase_CamelotV2StandardExchange.setUp();
        _newNativeTokens();
        vm.startPrank(nativeUser);
        nativePairA.approve(address(camelotV2StandardExchangeDFPkg), 1_000 ether);
        nativePairB.approve(address(camelotV2StandardExchangeDFPkg), 1_000 ether);
        nativeSY = IStandardizedYield(camelotV2StandardExchangeDFPkg.deployVault(
            nativePairA, 1_000 ether, nativePairB, 1_000 ether, nativeUser
        ));
        vm.stopPrank();
    }
}
