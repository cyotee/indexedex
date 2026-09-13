// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {ComposedStableCommonDetfCommon} from "./ComposedStableCommonDetfCommon.sol";
import {ComposedStableCommonDetfRepo as Repo} from "./ComposedStableCommonDetfRepo.sol";
contract ComposedStableCommonDetfExchangeIn is ComposedStableCommonDetfCommon, ReentrancyLockModifiers, IFacet {
    using BetterSafeERC20 for IERC20;
    function exchangeIn(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address to_, bool prepaid_, uint256 deadline_)
        external nonReentrant returns (uint256 received_)
    {
        _requireActive(deadline_, amount_);
        if (in_ == out_) revert InvalidRoute(address(in_), address(out_));
        if (to_ == address(0)) to_ = msg.sender;
        _updateExpansionMintOnRewards();
        IERC20 staking_ = IERC20(address(Repo._layoutStruct().rebasingDetfToken));
        if (in_ == staking_) {
            _secureTokenTransfer(in_, amount_, prepaid_);
            IStakedDETF(address(staking_)).exchangeIn(staking_, amount_, IERC20(address(this)), amount_, address(this), false, deadline_);
            if (address(out_) == address(this)) { received_ = amount_; out_.safeTransfer(to_, received_); }
            else received_ = _burnHeld(amount_, out_, to_, deadline_);
        } else if (out_ == staking_) {
            uint256 raw_ = address(in_) == address(this) ? _secureTokenTransfer(in_, amount_, prepaid_) : _acquireDetf(in_, amount_, prepaid_, deadline_);
            IERC20(address(this)).forceApprove(address(staking_), raw_);
            received_ = IStakedDETF(address(staking_)).exchangeIn(IERC20(address(this)), raw_, staking_, minimum_, to_, false, deadline_);
            IERC20(address(this)).forceApprove(address(staking_), 0);
        } else if (address(in_) == address(this)) {
            received_ = _burnHeld(_secureTokenTransfer(in_, amount_, prepaid_), out_, to_, deadline_);
        } else if (address(out_) == address(this)) {
            received_ = _acquireDetf(in_, amount_, prepaid_, deadline_); out_.safeTransfer(to_, received_);
        } else revert InvalidRoute(address(in_), address(out_));
        if (received_ < minimum_) revert SlippageExceeded(minimum_, received_);
        _syncAllExpectedHoldReserves();
    }
    function _acquireDetf(IERC20 in_, uint256 amount_, bool prepaid_, uint256 deadline_) internal returns (uint256) {
        _requireReservePoolInitialized();
        bool primary_ = _isMintingAllowed();
        (RoutedPoolSelection memory route_, uint256 bpt_) = _collectRoutedBpt(in_, amount_, prepaid_, deadline_);
        if (!primary_) return _reserveSwap(address(Repo._layoutStruct().reservePool), route_.poolBptToken, IERC20(address(this)), bpt_, 0);
        MintSplit memory split_ = _previewMintSplit(bpt_, route_.depositToStablePool);
        _joinReserve(0, route_.depositToStablePool ? bpt_ : 0, route_.depositToStablePool ? 0 : bpt_, false);
        _mintDetf(address(this), split_.userDetfOut);
        _fundStakingRewards(split_.inventoryDetfOut);
        return split_.userDetfOut;
    }
    function _burnHeld(uint256 amount_, IERC20 out_, address to_, uint256 deadline_) internal returns (uint256 received_) {
        _requireReservePoolInitialized();
        if (!_isFamilyBurnToken(out_)) revert InvalidRoute(address(this), address(out_));
        if (_isBurningAllowed()) {
            uint256 lp_ = _bptForDetfShares(amount_, false);
            if (lp_ == 0) revert ZeroAmount();
            _burnDetf(address(this), amount_);
            (uint256 self_, uint256 stable_, uint256 common_) = _exitReserveProportional(lp_);
            if (self_ != 0) _joinReserve(self_, 0, 0, false);
            return _consolidatePoolBptsToTokenOut(stable_, common_, out_, to_, deadline_);
        }
        ExactInUnwindSelection memory path_ = _selectExactInExit(out_, amount_);
        received_ = _reserveSwap(address(Repo._layoutStruct().reservePool), IERC20(address(this)), path_.poolBptToken, amount_, 0);
        return _deliverExit(path_, received_, out_, to_, deadline_);
    }
    function facetName() public pure returns (string memory) { return type(ComposedStableCommonDetfExchangeIn).name; }
    function facetInterfaces() public pure returns (bytes4[] memory a_) {
        a_ = new bytes4[](1);
        a_[0] = type(IStandardExchangeIn).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory a_) {
        a_ = new bytes4[](2);
        a_[0] = IStandardExchangeIn.exchangeIn.selector;
        a_[1] = this.executeReserveSwap.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
