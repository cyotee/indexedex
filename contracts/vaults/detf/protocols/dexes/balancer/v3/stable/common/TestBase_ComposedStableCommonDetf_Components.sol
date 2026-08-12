// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {
    WeightedPoolDynamicData
} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IWeightedPool} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol';
import {RebasingDETFTokenPricingTarget} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenPricingTarget.sol';

contract RebasingDETFTokenPricingHarness is RebasingDETFTokenPricingTarget {
    function initializePricing(
        IWeightedPool reservePool_,
        IDETFNFTVault bondNftVault_,
        IRebasingClaimToken rebasingDetfToken_,
        IERC20 detfToken_,
        IERC20 stablePoolBpt_,
        IERC20 commonPoolBpt_,
        IERC20 rateAsset_,
        IStandardExchangeIn stablePoolExitPricer_,
        IStandardExchangeIn commonPoolExitPricer_,
        uint256 detfIndex_,
        uint256 stablePoolBptIndex_,
        uint256 commonPoolBptIndex_
    ) external {
        ComposedStableCommonDetfRepo._initializePricing(
            reservePool_,
            bondNftVault_,
            rebasingDetfToken_,
            detfToken_,
            stablePoolBpt_,
            commonPoolBpt_,
            rateAsset_,
            stablePoolExitPricer_,
            commonPoolExitPricer_,
            detfIndex_,
            stablePoolBptIndex_,
            commonPoolBptIndex_
        );
    }
}

abstract contract TestBase_ComposedStableCommonDetf_Components is Test {
    RebasingDETFTokenPricingHarness internal pricingHarness;

    IWeightedPool internal reservePool;
    IDETFNFTVault internal bondNftVault;
    IRebasingClaimToken internal rebasingDetfToken;
    IERC20 internal detfToken;
    IERC20 internal stablePoolBpt;
    IERC20 internal commonPoolBpt;
    IERC20 internal rateAsset;
    IStandardExchangeIn internal stablePoolExitPricer;
    IStandardExchangeIn internal commonPoolExitPricer;

    function setUp() public virtual {
        pricingHarness = new RebasingDETFTokenPricingHarness();

        reservePool = IWeightedPool(makeAddr('reservePool'));
        bondNftVault = IDETFNFTVault(makeAddr('bondNftVault'));
        rebasingDetfToken = IRebasingClaimToken(makeAddr('rebasingDetfToken'));
        detfToken = IERC20(makeAddr('detfToken'));
        stablePoolBpt = IERC20(makeAddr('stablePoolBpt'));
        commonPoolBpt = IERC20(makeAddr('commonPoolBpt'));
        rateAsset = IERC20(makeAddr('rateAsset'));
        stablePoolExitPricer = IStandardExchangeIn(makeAddr('stablePoolExitPricer'));
        commonPoolExitPricer = IStandardExchangeIn(makeAddr('commonPoolExitPricer'));

        pricingHarness.initializePricing(
            reservePool,
            bondNftVault,
            rebasingDetfToken,
            detfToken,
            stablePoolBpt,
            commonPoolBpt,
            rateAsset,
            stablePoolExitPricer,
            commonPoolExitPricer,
            0,
            1,
            2
        );
    }

    function mockReservePoolDynamicData(uint256[] memory balancesLiveScaled18, uint256 totalSupply_) internal {
        WeightedPoolDynamicData memory data = WeightedPoolDynamicData({
            balancesLiveScaled18: balancesLiveScaled18,
            tokenRates: new uint256[](balancesLiveScaled18.length),
            staticSwapFeePercentage: 0,
            totalSupply: totalSupply_,
            isPoolInitialized: true,
            isPoolPaused: false,
            isPoolInRecoveryMode: false
        });

        vm.mockCall(
            address(reservePool),
            abi.encodeWithSelector(IWeightedPool.getWeightedPoolDynamicData.selector),
            abi.encode(data)
        );
    }

    function mockReservePoolBalance(uint256 reserveBptHeld_) internal {
        vm.mockCall(
            address(reservePool),
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(pricingHarness)),
            abi.encode(reserveBptHeld_)
        );
    }

    function mockDetfTotalSupply(uint256 totalSupply_) internal {
        vm.mockCall(address(detfToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply_));
    }

    function mockDetfOwnedReserveBpt(uint256 detfNftId_, uint256 reserveBptAmount_) internal {
        vm.mockCall(
            address(bondNftVault), abi.encodeWithSelector(IDETFNFTVault.detfNFTId.selector), abi.encode(detfNftId_)
        );
        vm.mockCall(
            address(bondNftVault),
            abi.encodeWithSelector(IDETFNFTVault.originalSharesOf.selector, detfNftId_),
            abi.encode(reserveBptAmount_)
        );
    }

    function mockRebasingShareQuote(uint256 rebasingClaimAmount_, uint256 rebasingClaimShares_, uint256 totalRebasingClaimShares_) internal {
        vm.mockCall(
            address(rebasingDetfToken), abi.encodeWithSelector(IRebasingClaimToken.convertToShares.selector, rebasingClaimAmount_), abi.encode(rebasingClaimShares_)
        );
        vm.mockCall(
            address(rebasingDetfToken), abi.encodeWithSelector(IRebasingClaimToken.totalShares.selector), abi.encode(totalRebasingClaimShares_)
        );
    }

    function mockStablePoolEthQuote(uint256 bptAmount_, uint256 wethValue_) internal {
        vm.mockCall(
            address(stablePoolExitPricer),
            abi.encodeWithSelector(IStandardExchangeIn.previewExchangeIn.selector, stablePoolBpt, bptAmount_, rateAsset),
            abi.encode(wethValue_)
        );
    }

    function mockCommonPoolEthQuote(uint256 bptAmount_, uint256 wethValue_) internal {
        vm.mockCall(
            address(commonPoolExitPricer),
            abi.encodeWithSelector(IStandardExchangeIn.previewExchangeIn.selector, commonPoolBpt, bptAmount_, rateAsset),
            abi.encode(wethValue_)
        );
    }
}