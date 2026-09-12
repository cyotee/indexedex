// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_ComposedFundedRoutes} from "contracts/test/bases/TestBase_ComposedFundedRoutes.sol";
import {
    ComposedStableCommonDetfRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

contract RebasingDETFTokenPricingTarget_Test is TestBase_ComposedFundedRoutes {
    function test_stakingReceipt_redeemsFundedDetfAtPar() public {
        uint256 id_ = _buyBond(alice, 10e18);
        _assertBondMaturePreviewEqualsPayment(composedDetf, id_, alice);
        uint256 receipt_ = _staked().balanceOf(alice);
        assertEq(_staked().previewExchangeIn(IERC20(address(_staked())), receipt_, IERC20(composedDetf)), receipt_);
        _assertFundedUnstake(composedDetf, alice, receipt_);
    }

    function test_previewReservePoolDecomposition_returnsProRataLegs() public {
        _live();
        IERC20 lp_ = _bondNft().lpToken();
        uint256 amount_ = lp_.balanceOf(address(_bondNft())) / 10;
        assertGt(amount_, 0);
        (uint256 self_, uint256 stable_, uint256 common_) = composedInfo.previewReservePoolDecomposition(amount_);
        (IERC20[] memory tokens_,, uint256[] memory raw_,) = vault.getPoolTokenInfo(address(lp_));
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            uint256 expected_ = Math.mulDiv(raw_[i_], amount_, lp_.totalSupply());
            if (address(tokens_[i_]) == composedDetf) assertEq(self_, expected_);
            else if (address(tokens_[i_]) == address(composedStable)) assertEq(stable_, expected_);
            else assertEq(common_, expected_);
        }
    }

    function test_syntheticDetfEthPrice_usesExternalBackingOnly() public {
        _live();
        IERC20 lp_ = _bondNft().lpToken();
        (uint256 self_, uint256 stable_, uint256 common_) =
            composedInfo.previewReservePoolDecomposition(lp_.balanceOf(address(_bondNft())));
        uint256 external_ = stableAdapter.previewExchangeIn(IERC20(address(composedStable)), stable_, weth)
            + commonAdapter.previewExchangeIn(IERC20(address(composedCommon)), common_, weth);
        uint256 circulating_ = IERC20(composedDetf).totalSupply() - self_;
        assertGt(external_, 0);
        assertGt(circulating_, 0);
        assertEq(composedInfo.syntheticDetfEthPrice(), Math.mulDiv(external_, 1e9, circulating_));
    }

    function test_previewInnerPoolValues_matchActualRateAssetQuotes() public view {
        assertEq(
            composedInfo.previewStablePoolBptEthValue(1e18),
            stableAdapter.previewExchangeIn(IERC20(address(composedStable)), 1e18, weth)
        );
        assertEq(
            composedInfo.previewCommonPoolBptEthValue(1e18),
            commonAdapter.previewExchangeIn(IERC20(address(composedCommon)), 1e18, weth)
        );
    }

    function test_inertPricing_hasNoBackingOrExpansion() public view {
        assertFalse(composedInfo.isReserveLive());
        assertEq(composedInfo.syntheticDetfEthPrice(), 0);
        assertEq(composedInfo.pendingExpansionDetf(), 0);
        assertEq(composedInfo.previewStablePoolBptEthValue(0), 0);
        assertEq(composedInfo.previewCommonPoolBptEthValue(0), 0);
    }
}
