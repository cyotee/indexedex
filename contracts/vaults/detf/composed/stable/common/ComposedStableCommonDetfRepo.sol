// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IPermit2} from '@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol';
import {IStablePool} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol';
import {IWeightedPool} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol';
import {IBalancerV3StandardExchangeRouterProxy} from 'contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol';
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRICHIR} from 'contracts/interfaces/IRICHIR.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IVaultFeeOracleQuery} from 'contracts/interfaces/IVaultFeeOracleQuery.sol';

library ComposedStableCommonDetfRepo {

    error InvalidReservePoolIndices(uint256 detfIndex, uint256 stablePoolBptIndex, uint256 commonPoolBptIndex);

    bytes32 internal constant STORAGE_SLOT = keccak256("detf.composed.stable.common.repo");

    struct RouteConfig {
        IERC20 baseToken;
        IERC20 vaultToken;
        IStandardExchangeIn underlyingVault;
        IStandardExchangeIn stablePoolRouter;
        IStandardExchangeIn commonPoolRouter;
        uint256 stablePoolTokenIndex;
        uint256 commonPoolTokenIndex;
    }

    struct Storage {
        IWeightedPool reservePool;
        IDETFNFTVault bondNftVault;
        IRICHIR rebasingDetfToken;
        IERC20 detfToken;
        IERC20 stablePoolBpt;
        IERC20 commonPoolBpt;
        IERC20 wethToken;
        IStandardExchangeIn stablePoolExitPricer;
        IStandardExchangeIn commonPoolExitPricer;
        uint256 detfIndex;
        uint256 stablePoolBptIndex;
        uint256 commonPoolBptIndex;
        IPermit2 permit2;
        IBalancerV3StandardExchangeRouterProxy balancerV3Router;
        IStablePool stablePool;
        IStablePool commonPool;
        IStandardExchangeIn reservePoolEntryRouter;
        IVaultFeeOracleQuery feeOracle;
        uint256 mintThreshold;
        uint256 burnThreshold;
        RouteConfig[] routes;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initializePricing(
        Storage storage layoutStruct_,
        IWeightedPool reservePool_,
        IDETFNFTVault bondNftVault_,
        IRICHIR rebasingDetfToken_,
        IERC20 detfToken_,
        IERC20 stablePoolBpt_,
        IERC20 commonPoolBpt_,
        IERC20 wethToken_,
        IStandardExchangeIn stablePoolExitPricer_,
        IStandardExchangeIn commonPoolExitPricer_,
        uint256 detfIndex_,
        uint256 stablePoolBptIndex_,
        uint256 commonPoolBptIndex_
    ) internal {
        if (detfIndex_ > 2 || stablePoolBptIndex_ > 2 || commonPoolBptIndex_ > 2 || detfIndex_ == stablePoolBptIndex_
            || detfIndex_ == commonPoolBptIndex_ || stablePoolBptIndex_ == commonPoolBptIndex_) {
            revert InvalidReservePoolIndices(detfIndex_, stablePoolBptIndex_, commonPoolBptIndex_);
        }

        layoutStruct_.reservePool = reservePool_;
    layoutStruct_.bondNftVault = bondNftVault_;
    layoutStruct_.rebasingDetfToken = rebasingDetfToken_;
        layoutStruct_.detfToken = detfToken_;
        layoutStruct_.stablePoolBpt = stablePoolBpt_;
        layoutStruct_.commonPoolBpt = commonPoolBpt_;
        layoutStruct_.wethToken = wethToken_;
        layoutStruct_.stablePoolExitPricer = stablePoolExitPricer_;
        layoutStruct_.commonPoolExitPricer = commonPoolExitPricer_;
        layoutStruct_.detfIndex = detfIndex_;
        layoutStruct_.stablePoolBptIndex = stablePoolBptIndex_;
        layoutStruct_.commonPoolBptIndex = commonPoolBptIndex_;
    }

    function _initializeExchangeIn(
        Storage storage layoutStruct_,
        IPermit2 permit2_,
        IBalancerV3StandardExchangeRouterProxy balancerV3Router_,
        IStablePool stablePool_,
        IStablePool commonPool_,
        IStandardExchangeIn reservePoolEntryRouter_,
        IVaultFeeOracleQuery feeOracle_,
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        RouteConfig[] memory routes_
    ) internal {
        layoutStruct_.permit2 = permit2_;
        layoutStruct_.balancerV3Router = balancerV3Router_;
        layoutStruct_.stablePool = stablePool_;
        layoutStruct_.commonPool = commonPool_;
        layoutStruct_.reservePoolEntryRouter = reservePoolEntryRouter_;
        layoutStruct_.feeOracle = feeOracle_;
        layoutStruct_.mintThreshold = mintThreshold_;
        layoutStruct_.burnThreshold = burnThreshold_;

        delete layoutStruct_.routes;
        for (uint256 i = 0; i < routes_.length; i++) {
            layoutStruct_.routes.push(routes_[i]);
        }
    }

    function _initializeExchangeIn(
        IPermit2 permit2_,
        IBalancerV3StandardExchangeRouterProxy balancerV3Router_,
        IStablePool stablePool_,
        IStablePool commonPool_,
        IStandardExchangeIn reservePoolEntryRouter_,
        IVaultFeeOracleQuery feeOracle_,
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        RouteConfig[] memory routes_
    ) internal {
        _initializeExchangeIn(
            _layoutStruct(),
            permit2_,
            balancerV3Router_,
            stablePool_,
            commonPool_,
            reservePoolEntryRouter_,
            feeOracle_,
            mintThreshold_,
            burnThreshold_,
            routes_
        );
    }

    function _initializePricing(
        IWeightedPool reservePool_,
        IDETFNFTVault bondNftVault_,
        IRICHIR rebasingDetfToken_,
        IERC20 detfToken_,
        IERC20 stablePoolBpt_,
        IERC20 commonPoolBpt_,
        IERC20 wethToken_,
        IStandardExchangeIn stablePoolExitPricer_,
        IStandardExchangeIn commonPoolExitPricer_,
        uint256 detfIndex_,
        uint256 stablePoolBptIndex_,
        uint256 commonPoolBptIndex_
    ) internal {
        _initializePricing(
            _layoutStruct(),
            reservePool_,
            bondNftVault_,
            rebasingDetfToken_,
            detfToken_,
            stablePoolBpt_,
            commonPoolBpt_,
            wethToken_,
            stablePoolExitPricer_,
            commonPoolExitPricer_,
            detfIndex_,
            stablePoolBptIndex_,
            commonPoolBptIndex_
        );
    }

    function _reservePool(Storage storage layoutStruct_) internal view returns (IWeightedPool reservePool_) {
        return layoutStruct_.reservePool;
    }

    function _reservePool() internal view returns (IWeightedPool reservePool_) {
        return _reservePool(_layoutStruct());
    }

    function _bondNftVault(Storage storage layoutStruct_) internal view returns (IDETFNFTVault bondNftVault_) {
        return layoutStruct_.bondNftVault;
    }

    function _bondNftVault() internal view returns (IDETFNFTVault bondNftVault_) {
        return _bondNftVault(_layoutStruct());
    }

    function _rebasingDetfToken(Storage storage layoutStruct_) internal view returns (IRICHIR rebasingDetfToken_) {
        return layoutStruct_.rebasingDetfToken;
    }

    function _rebasingDetfToken() internal view returns (IRICHIR rebasingDetfToken_) {
        return _rebasingDetfToken(_layoutStruct());
    }

    function _detfToken(Storage storage layoutStruct_) internal view returns (IERC20 detfToken_) {
        return layoutStruct_.detfToken;
    }

    function _detfToken() internal view returns (IERC20 detfToken_) {
        return _detfToken(_layoutStruct());
    }

    function _stablePoolBpt(Storage storage layoutStruct_) internal view returns (IERC20 stablePoolBpt_) {
        return layoutStruct_.stablePoolBpt;
    }

    function _stablePoolBpt() internal view returns (IERC20 stablePoolBpt_) {
        return _stablePoolBpt(_layoutStruct());
    }

    function _commonPoolBpt(Storage storage layoutStruct_) internal view returns (IERC20 commonPoolBpt_) {
        return layoutStruct_.commonPoolBpt;
    }

    function _commonPoolBpt() internal view returns (IERC20 commonPoolBpt_) {
        return _commonPoolBpt(_layoutStruct());
    }

    function _wethToken(Storage storage layoutStruct_) internal view returns (IERC20 wethToken_) {
        return layoutStruct_.wethToken;
    }

    function _wethToken() internal view returns (IERC20 wethToken_) {
        return _wethToken(_layoutStruct());
    }

    function _stablePoolExitPricer(Storage storage layoutStruct_) internal view returns (IStandardExchangeIn stablePoolExitPricer_) {
        return layoutStruct_.stablePoolExitPricer;
    }

    function _stablePoolExitPricer() internal view returns (IStandardExchangeIn stablePoolExitPricer_) {
        return _stablePoolExitPricer(_layoutStruct());
    }

    function _commonPoolExitPricer(Storage storage layoutStruct_) internal view returns (IStandardExchangeIn commonPoolExitPricer_) {
        return layoutStruct_.commonPoolExitPricer;
    }

    function _commonPoolExitPricer() internal view returns (IStandardExchangeIn commonPoolExitPricer_) {
        return _commonPoolExitPricer(_layoutStruct());
    }

    function _detfIndex(Storage storage layoutStruct_) internal view returns (uint256 detfIndex_) {
        return layoutStruct_.detfIndex;
    }

    function _detfIndex() internal view returns (uint256 detfIndex_) {
        return _detfIndex(_layoutStruct());
    }

    function _stablePoolBptIndex(Storage storage layoutStruct_) internal view returns (uint256 stablePoolBptIndex_) {
        return layoutStruct_.stablePoolBptIndex;
    }

    function _stablePoolBptIndex() internal view returns (uint256 stablePoolBptIndex_) {
        return _stablePoolBptIndex(_layoutStruct());
    }

    function _commonPoolBptIndex(Storage storage layoutStruct_) internal view returns (uint256 commonPoolBptIndex_) {
        return layoutStruct_.commonPoolBptIndex;
    }

    function _commonPoolBptIndex() internal view returns (uint256 commonPoolBptIndex_) {
        return _commonPoolBptIndex(_layoutStruct());
    }

    function _balancerV3Router(Storage storage layoutStruct_)
        internal
        view
        returns (IBalancerV3StandardExchangeRouterProxy balancerV3Router_)
    {
        return layoutStruct_.balancerV3Router;
    }

    function _balancerV3Router() internal view returns (IBalancerV3StandardExchangeRouterProxy balancerV3Router_) {
        return _balancerV3Router(_layoutStruct());
    }

    function _permit2(Storage storage layoutStruct_) internal view returns (IPermit2 permit2_) {
        return layoutStruct_.permit2;
    }

    function _permit2() internal view returns (IPermit2 permit2_) {
        return _permit2(_layoutStruct());
    }

    function _stablePool(Storage storage layoutStruct_) internal view returns (IStablePool stablePool_) {
        return layoutStruct_.stablePool;
    }

    function _stablePool() internal view returns (IStablePool stablePool_) {
        return _stablePool(_layoutStruct());
    }

    function _commonPool(Storage storage layoutStruct_) internal view returns (IStablePool commonPool_) {
        return layoutStruct_.commonPool;
    }

    function _commonPool() internal view returns (IStablePool commonPool_) {
        return _commonPool(_layoutStruct());
    }

    function _reservePoolEntryRouter(Storage storage layoutStruct_) internal view returns (IStandardExchangeIn reservePoolEntryRouter_) {
        return layoutStruct_.reservePoolEntryRouter;
    }

    function _reservePoolEntryRouter() internal view returns (IStandardExchangeIn reservePoolEntryRouter_) {
        return _reservePoolEntryRouter(_layoutStruct());
    }

    function _feeOracle(Storage storage layoutStruct_) internal view returns (IVaultFeeOracleQuery feeOracle_) {
        return layoutStruct_.feeOracle;
    }

    function _feeOracle() internal view returns (IVaultFeeOracleQuery feeOracle_) {
        return _feeOracle(_layoutStruct());
    }

    function _mintThreshold(Storage storage layoutStruct_) internal view returns (uint256 mintThreshold_) {
        return layoutStruct_.mintThreshold;
    }

    function _mintThreshold() internal view returns (uint256 mintThreshold_) {
        return _mintThreshold(_layoutStruct());
    }

    function _burnThreshold(Storage storage layoutStruct_) internal view returns (uint256 burnThreshold_) {
        return layoutStruct_.burnThreshold;
    }

    function _burnThreshold() internal view returns (uint256 burnThreshold_) {
        return _burnThreshold(_layoutStruct());
    }

    function _routeCount(Storage storage layoutStruct_) internal view returns (uint256 routeCount_) {
        return layoutStruct_.routes.length;
    }

    function _routeCount() internal view returns (uint256 routeCount_) {
        return _routeCount(_layoutStruct());
    }

    function _routeAt(Storage storage layoutStruct_, uint256 index_) internal view returns (RouteConfig storage route_) {
        return layoutStruct_.routes[index_];
    }

    function _routeAt(uint256 index_) internal view returns (RouteConfig storage route_) {
        return _routeAt(_layoutStruct(), index_);
    }

}