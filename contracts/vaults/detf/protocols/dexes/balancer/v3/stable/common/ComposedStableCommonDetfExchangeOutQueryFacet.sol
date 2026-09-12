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
contract ComposedStableCommonDetfExchangeOutQueryFacet is ComposedStableCommonDetfCommon, ReentrancyLockModifiers, IFacet {
    using BetterSafeERC20 for IERC20;
    function previewExchangeOut(IERC20 in_, IERC20 out_, uint256 amount_) public view returns (uint256) {
        IERC20 staking_ = IERC20(address(Repo._layoutStruct().rebasingDetfToken));
        if ((address(in_) == address(this) && address(out_) == address(staking_)) || (in_ == staking_ && address(out_) == address(this))) return amount_;
        if (address(in_) != address(this) && address(in_) != address(staking_)) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        if (!_isFamilyBurnToken(out_)) revert InvalidRoute(address(in_), address(out_));
        _requireReservePoolInitialized();
        return _selectExactOutExit(out_, amount_).detfAmountIn;
    }
    function exchangeOut(IERC20 in_, uint256 maximum_, IERC20 out_, uint256 amount_, address to_, bool prepaid_, uint256 deadline_)
        external nonReentrant returns (uint256 paid_)
    {
        _requireActive(deadline_, amount_);
        if (to_ == address(0)) to_ = msg.sender;
        _updateExpansionMintOnRewards();
        paid_ = previewExchangeOut(in_, out_, amount_);
        if (paid_ > maximum_) revert MaxAmountExceeded(maximum_, paid_);
        _secureTokenTransfer(in_, paid_, prepaid_);
        IERC20 staking_ = IERC20(address(Repo._layoutStruct().rebasingDetfToken));
        if (out_ == staking_) {
            in_.forceApprove(address(staking_), paid_);
            IStakedDETF(address(staking_)).exchangeIn(in_, paid_, out_, amount_, to_, false, deadline_);
            in_.forceApprove(address(staking_), 0);
        } else {
            if (in_ == staking_) IStakedDETF(address(staking_)).exchangeIn(in_, paid_, IERC20(address(this)), paid_, address(this), false, deadline_);
            if (address(out_) == address(this)) out_.safeTransfer(to_, amount_);
            else {
                uint256 used_ = _executeExactOutExit(out_, amount_, paid_, to_, deadline_);
                uint256 refund_ = paid_ - used_;
                if (refund_ != 0) {
                    if (in_ == staking_) {
                        IERC20(address(this)).forceApprove(address(staking_), refund_);
                        IStakedDETF(address(staking_)).exchangeIn(IERC20(address(this)), refund_, staking_, refund_, msg.sender, false, deadline_);
                        IERC20(address(this)).forceApprove(address(staking_), 0);
                    } else IERC20(address(this)).safeTransfer(msg.sender, refund_);
                }
                paid_ = used_;
            }
        }
        _syncAllExpectedHoldReserves();
    }
    function facetName() public pure returns (string memory) { return type(ComposedStableCommonDetfExchangeOutQueryFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory a_) {
        a_ = new bytes4[](1);
        a_[0] = type(IStandardExchangeOut).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory a_) {
        a_ = new bytes4[](2);
        a_[0] = IStandardExchangeOut.previewExchangeOut.selector;
        a_[1] = IStandardExchangeOut.exchangeOut.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
