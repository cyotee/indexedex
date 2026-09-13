// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {DETFBalancerLiquidityQuoteLib} from "contracts/vaults/detf/protocols/dexes/balancer/v3/common/DETFBalancerLiquidityQuoteLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DETFChildSYRepo} from "contracts/vaults/detf/common/sy/DETFChildSYRepo.sol";
import {IComposedStableCommonDetfInfo} from "./IComposedStableCommonDetfInfo.sol";
import {ComposedStableCommonDetfCommon} from "./ComposedStableCommonDetfCommon.sol";
import {ComposedStableCommonDetfRepo as Repo} from "./ComposedStableCommonDetfRepo.sol";
abstract contract RebasingDETFTokenPricingTarget is ComposedStableCommonDetfCommon, IComposedStableCommonDetfInfo {
    function openingConfiguration() external view returns (uint256[2] memory prices, uint256[3] memory seedAmounts) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        return (s_.openingDetfPrices, s_.reserveSeedAmounts);
    }
    function reservePool() external view returns (address) { return address(Repo._layoutStruct().reservePool); }
    function bondNftVault() external view returns (address) { return address(Repo._layoutStruct().bondNftVault); }
    function rebasingClaimToken() external view returns (address) { return address(Repo._layoutStruct().rebasingDetfToken); }
    function syntheticDetfEthPrice() external view returns (uint256) { return _syntheticDetfEthPrice(); }
    function previewStablePoolBptEthValue(uint256 amount_) external view returns (uint256) { return _poolValue(true, amount_); }
    function previewCommonPoolBptEthValue(uint256 amount_) external view returns (uint256) { return _poolValue(false, amount_); }
    function previewReservePoolDecomposition(uint256 amount_) external view returns (uint256, uint256, uint256) { return _previewProportionalExit(amount_); }
    function mintThreshold() external view returns (uint256) { return Repo._layoutStruct().mintThreshold; }
    function burnThreshold() external view returns (uint256) { return Repo._layoutStruct().burnThreshold; }
    function isMintingAllowed() external view returns (bool) { return _isMintingAllowed(); }
    function isBurningAllowed() external view returns (bool) { return _isBurningAllowed(); }
    function isReserveLive() external view returns (bool) { return _isReserveLive(); }
    function epochAnchor() external view returns (uint256) { return Repo._layoutStruct().epochAnchor; }
    function lastExpansionTimestamp() external view returns (uint256) { return Repo._layoutStruct().lastExpansionTimestamp; }
    function expansionClosureRatePerSecond() external view returns (uint256) { return Repo._layoutStruct().expansionClosureRatePerSecond; }
    function pendingExpansionDetf() external view returns (uint256) { return _pendingExpansionDetf(); }
    function rawSY() external view returns (address) { return DETFChildSYRepo._layoutStruct().rawSY; }
    function stakingSY() external view returns (address) { return DETFChildSYRepo._layoutStruct().stakingSY; }
    function tokensIn() external view returns (address[] memory) { return _tokensIn(); }
    function tokensOut() external view returns (address[] memory) { return _tokensOut(); }
    function synchronizeRewards() external returns (uint256 minted_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (ReentrancyLockRepo._isLocked()) {
            if (msg.sender != address(s_.rebasingDetfToken) && msg.sender != address(s_.bondNftVault)) revert Repo.NotAuthorized(msg.sender);
            return 0;
        }
        ReentrancyLockRepo._lock(); minted_ = _updateExpansionMintOnRewards(); ReentrancyLockRepo._unlock();
    }
    function previewStakingGonsPerUnit(IERC20 in_, uint256 amount_) external view returns (uint256) {
        uint256[] memory pots_ = new uint256[](2); pots_[0] = _pendingExpansionDetf();
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (amount_ != 0 && address(in_) != address(this) && address(in_) != address(s_.rebasingDetfToken) && _previewPrimaryMint()) {
            (RoutedPoolSelection memory path_,,uint256 bpt_) = _previewRoutedPoolBpt(in_, amount_);
            pots_[1] = _previewMintSplit(bpt_, path_.depositToStablePool).inventoryDetfOut;
        }
        return s_.rebasingDetfToken.previewDistributions(pots_).gonsPerUnit;
    }
    function previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_) external view returns (uint256) {
        if (in_ == out_) revert InvalidRoute(address(in_), address(out_));
        IERC20 staking_ = IERC20(address(Repo._layoutStruct().rebasingDetfToken));
        if ((address(in_) == address(this) && address(out_) == address(staking_)) || (in_ == staking_ && address(out_) == address(this))) return amount_;
        _requireReservePoolInitialized();
        if (address(out_) == address(this) || address(out_) == address(staking_)) {
            (RoutedPoolSelection memory path_,,uint256 bpt_) = _previewRoutedPoolBpt(in_, amount_);
            return _previewPrimaryMint() ? _previewMintSplit(bpt_, path_.depositToStablePool).userDetfOut : _quoteReserveSwap(bpt_, path_.depositToStablePool, true);
        }
        if ((address(in_) == address(this) || address(in_) == address(staking_)) && _isFamilyBurnToken(out_)) {
            return _previewPrimaryBurn() ? _previewExitSettle(_bptForDetfShares(amount_, true), out_)
                : _selectExactInExit(out_, amount_).tokenOutAmountOut;
        }
        revert InvalidRoute(address(in_), address(out_));
    }

    function previewJoinDonatedCapital(IERC20 token_, uint256 amount_) external view returns (uint256) {
        if (amount_ == 0 || !_isReserveLive()) return 0;
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 index_;
        uint256 bpt_;
        if (address(token_) == address(this)) { index_ = s_.detfIndex; bpt_ = amount_; }
        else {
            address[] memory accepted_ = _tokensIn(); bool valid_;
            for (uint256 i_; i_ < accepted_.length; ++i_) if (accepted_[i_] == address(token_)) { valid_ = true; break; }
            if (!valid_) return 0;
            (RoutedPoolSelection memory path_,,uint256 quoted_) = _previewRoutedPoolBpt(token_, amount_);
            index_ = path_.depositToStablePool ? s_.stablePoolBptIndex : s_.commonPoolBptIndex; bpt_ = quoted_;
        }
        return DETFBalancerLiquidityQuoteLib._singleAssetJoin(address(_reserveVault()), address(s_.reservePool), index_, bpt_);
    }

}
