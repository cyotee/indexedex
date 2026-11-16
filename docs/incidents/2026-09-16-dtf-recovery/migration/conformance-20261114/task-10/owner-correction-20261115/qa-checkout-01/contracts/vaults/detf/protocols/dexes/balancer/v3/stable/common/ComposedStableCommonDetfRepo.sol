// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWeightedPool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol";
import {IStablePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
library ComposedStableCommonDetfRepo {
    error NotAuthorized(address caller);
    error LockDurationTooShort(uint256 provided, uint256 required);
    error ReserveAlreadyInitialized();
    error InvalidSeedRatio(uint256 suppliedCommon, uint256 requiredCommon);
    bytes32 internal constant STORAGE_SLOT = keccak256("detf.composed.stable.common.funded.repo");
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
        IStakedDETF rebasingDetfToken;
        IStablePool stablePool;
        IStablePool commonPool;
        IERC20 rateAsset;
        IStandardExchangeIn stablePoolExitPricer;
        IStandardExchangeIn commonPoolExitPricer;
        uint256 detfIndex;
        uint256 stablePoolBptIndex;
        uint256 commonPoolBptIndex;
        IBalancerV3StandardExchangeRouterProxy balancerV3Router;
        IVaultFeeOracleQuery feeOracle;
        // Whole stable/common BPT per whole purchased DETF, each scaled by 1e18.
        uint256[2] openingDetfPrices;
        // Proportional native seed amounts: DETF (9), stable BPT (18), common BPT (18).
        uint256[3] reserveSeedAmounts;
        uint256 mintThreshold;
        uint256 burnThreshold;
        uint256 expansionClosureRatePerSecond;
        uint256 lastExpansionTimestamp;
        uint256 epochAnchor;
        bool isReserveLive;
        RouteConfig[] routes;
    }
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage s_) { assembly { s_.slot := slot_ } }
    function _layoutStruct() internal pure returns (Storage storage s_) { return _layoutStruct(STORAGE_SLOT); }
    function _reservePool(Storage storage s_) internal view returns (IWeightedPool) { return s_.reservePool; }
    function _reservePool() internal view returns (IWeightedPool) { return _reservePool(_layoutStruct()); }
    function _bondNftVault(Storage storage s_) internal view returns (IDETFNFTVault) { return s_.bondNftVault; }
    function _bondNftVault() internal view returns (IDETFNFTVault) { return _bondNftVault(_layoutStruct()); }
    function _rebasingDetfToken(Storage storage s_) internal view returns (IStakedDETF) { return s_.rebasingDetfToken; }
    function _rebasingDetfToken() internal view returns (IStakedDETF) { return _rebasingDetfToken(_layoutStruct()); }
    function _stablePool(Storage storage s_) internal view returns (IStablePool) { return s_.stablePool; }
    function _stablePool() internal view returns (IStablePool) { return _stablePool(_layoutStruct()); }
    function _commonPool(Storage storage s_) internal view returns (IStablePool) { return s_.commonPool; }
    function _commonPool() internal view returns (IStablePool) { return _commonPool(_layoutStruct()); }
    function _rateAsset(Storage storage s_) internal view returns (IERC20) { return s_.rateAsset; }
    function _rateAsset() internal view returns (IERC20) { return _rateAsset(_layoutStruct()); }
    function _stablePoolExitPricer(Storage storage s_) internal view returns (IStandardExchangeIn) { return s_.stablePoolExitPricer; }
    function _stablePoolExitPricer() internal view returns (IStandardExchangeIn) { return _stablePoolExitPricer(_layoutStruct()); }
    function _commonPoolExitPricer(Storage storage s_) internal view returns (IStandardExchangeIn) { return s_.commonPoolExitPricer; }
    function _commonPoolExitPricer() internal view returns (IStandardExchangeIn) { return _commonPoolExitPricer(_layoutStruct()); }
    function _detfIndex(Storage storage s_) internal view returns (uint256) { return s_.detfIndex; }
    function _detfIndex() internal view returns (uint256) { return _detfIndex(_layoutStruct()); }
    function _stablePoolBptIndex(Storage storage s_) internal view returns (uint256) { return s_.stablePoolBptIndex; }
    function _stablePoolBptIndex() internal view returns (uint256) { return _stablePoolBptIndex(_layoutStruct()); }
    function _commonPoolBptIndex(Storage storage s_) internal view returns (uint256) { return s_.commonPoolBptIndex; }
    function _commonPoolBptIndex() internal view returns (uint256) { return _commonPoolBptIndex(_layoutStruct()); }
    function _balancerV3Router(Storage storage s_) internal view returns (IBalancerV3StandardExchangeRouterProxy) { return s_.balancerV3Router; }
    function _balancerV3Router() internal view returns (IBalancerV3StandardExchangeRouterProxy) { return _balancerV3Router(_layoutStruct()); }
    function _feeOracle(Storage storage s_) internal view returns (IVaultFeeOracleQuery) { return s_.feeOracle; }
    function _feeOracle() internal view returns (IVaultFeeOracleQuery) { return _feeOracle(_layoutStruct()); }
    function _mintThreshold(Storage storage s_) internal view returns (uint256) { return s_.mintThreshold; }
    function _mintThreshold() internal view returns (uint256) { return _mintThreshold(_layoutStruct()); }
    function _burnThreshold(Storage storage s_) internal view returns (uint256) { return s_.burnThreshold; }
    function _burnThreshold() internal view returns (uint256) { return _burnThreshold(_layoutStruct()); }
    function _expansionClosureRatePerSecond(Storage storage s_) internal view returns (uint256) { return s_.expansionClosureRatePerSecond; }
    function _expansionClosureRatePerSecond() internal view returns (uint256) { return _expansionClosureRatePerSecond(_layoutStruct()); }
    function _lastExpansionTimestamp(Storage storage s_) internal view returns (uint256) { return s_.lastExpansionTimestamp; }
    function _lastExpansionTimestamp() internal view returns (uint256) { return _lastExpansionTimestamp(_layoutStruct()); }
    function _epochAnchor(Storage storage s_) internal view returns (uint256) { return s_.epochAnchor; }
    function _epochAnchor() internal view returns (uint256) { return _epochAnchor(_layoutStruct()); }
    function _isReserveLive(Storage storage s_) internal view returns (bool) { return s_.isReserveLive; }
    function _isReserveLive() internal view returns (bool) { return _isReserveLive(_layoutStruct()); }
    function _stablePoolBpt(Storage storage s_) internal view returns (IERC20) { return IERC20(address(s_.stablePool)); }
    function _stablePoolBpt() internal view returns (IERC20) { return _stablePoolBpt(_layoutStruct()); }
    function _commonPoolBpt(Storage storage s_) internal view returns (IERC20) { return IERC20(address(s_.commonPool)); }
    function _commonPoolBpt() internal view returns (IERC20) { return _commonPoolBpt(_layoutStruct()); }
    function _detfToken() internal view returns (IERC20) { return IERC20(address(this)); }
    function _routeCount(Storage storage s_) internal view returns (uint256) { return s_.routes.length; }
    function _routeCount() internal view returns (uint256) { return _routeCount(_layoutStruct()); }
    function _routeAt(Storage storage s_, uint256 i_) internal view returns (RouteConfig storage) { return s_.routes[i_]; }
    function _routeAt(uint256 i_) internal view returns (RouteConfig storage) { return _routeAt(_layoutStruct(), i_); }
    function _markLive(Storage storage s_) internal {
        if (s_.isReserveLive) revert ReserveAlreadyInitialized();
        s_.isReserveLive = true; s_.epochAnchor = block.timestamp; s_.lastExpansionTimestamp = block.timestamp;
    }
    function _markLive() internal { _markLive(_layoutStruct()); }
}
