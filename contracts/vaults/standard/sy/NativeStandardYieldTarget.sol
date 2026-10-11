// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

/// @notice Pendle entrypoints at an existing static SE share address.
/// @dev Every money operation executes the installed standard route, including its lock,
///      custody, fees and received-asset checks. The SY adapter never mints a second share.
///      Family adapters provide directional discovery and proportional accounting metadata.
abstract contract NativeStandardYieldTarget {
    error InvalidSYToken(address token);
    error InvalidSYReceiver();
    error ZeroSYAmount();
    error UnsupportedNativePayment();
    error SYMinimumNotMet(uint256 minimum, uint256 received);

    function deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_)
        external payable returns (uint256 shares_)
    {
        if (msg.value != 0) revert UnsupportedNativePayment();
        if (receiver_ == address(0)) revert InvalidSYReceiver();
        if (amount_ == 0) revert ZeroSYAmount();
        if (!isValidTokenIn(tokenIn_)) revert InvalidSYToken(tokenIn_);
        shares_ = _standardRoute(
            IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, false
        );
        if (shares_ == 0) revert ZeroSYAmount();
        emit IStandardizedYield.Deposit(msg.sender, receiver_, tokenIn_, amount_, shares_);
    }

    function redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool internalBalance_)
        external returns (uint256 amount_)
    {
        if (receiver_ == address(0)) revert InvalidSYReceiver();
        if (shares_ == 0) revert ZeroSYAmount();
        if (!isValidTokenOut(tokenOut_)) revert InvalidSYToken(tokenOut_);
        if (internalBalance_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            _requireVaultHeldShares(shares_);
            amount_ = _redeemVaultHeld(receiver_, shares_, tokenOut_, minimum_);
        } else {
            amount_ = _standardRoute(
                IERC20(address(this)), shares_, IERC20(tokenOut_), minimum_, receiver_, false
            );
        }
        if (amount_ < minimum_) revert SYMinimumNotMet(minimum_, amount_);
        emit IStandardizedYield.Redeem(msg.sender, receiver_, tokenOut_, shares_, amount_);
    }

    /// @dev Normal calls retain the original payer by delegatecalling the proxy's fixed SE
    ///      selector. Vault-held exits name the holder in the family's internal settlement.
    function _standardRoute(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_)
        internal virtual returns (uint256 received_)
    {
        if (internal_) {
            _requireVaultHeldShares(amount_);
            received_ = _redeemVaultHeld(receiver_, amount_, address(out_), minimum_);
            if (received_ < minimum_) revert SYMinimumNotMet(minimum_, received_);
            return received_;
        }
        bytes memory data_ = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (in_, amount_, out_, minimum_, receiver_, false, block.timestamp)
        );
        (bool ok_, bytes memory result_) = address(this).delegatecall(data_);
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        received_ = abi.decode(result_, (uint256));
        if (received_ < minimum_) revert SYMinimumNotMet(minimum_, received_);
    }

    function _requireVaultHeldShares(uint256 shares_) internal view {
        uint256 held_ = IERC20(address(this)).balanceOf(address(this));
        if (held_ < shares_) revert ISecurePullErrors.TransferDeltaInsufficient(shares_, held_);
    }

    /// @dev Unsupported legacy adapters fail closed until their family supplies settlement.
    function _redeemVaultHeld(address, uint256, address tokenOut_, uint256)
        internal virtual returns (uint256)
    {
        revert InvalidSYToken(tokenOut_);
    }

    function previewDeposit(address tokenIn_, uint256 amount_) external view returns (uint256) {
        if (!isValidTokenIn(tokenIn_)) return 0;
        return IStandardExchangeIn(address(this)).previewExchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)));
    }

    function previewRedeem(address tokenOut_, uint256 shares_) external view returns (uint256) {
        if (!isValidTokenOut(tokenOut_)) return 0;
        return IStandardExchangeIn(address(this)).previewExchangeIn(IERC20(address(this)), shares_, IERC20(tokenOut_));
    }

    function getTokensIn() public view virtual returns (address[] memory);
    function getTokensOut() public view virtual returns (address[] memory);
    function yieldToken() external view virtual returns (address);
    function assetInfo() external view virtual returns (IStandardizedYield.AssetType, address, uint8);
    function exchangeRate() external view virtual returns (uint256);

    function isValidTokenIn(address token_) public view returns (bool) { return _contains(getTokensIn(), token_); }
    function isValidTokenOut(address token_) public view returns (bool) { return _contains(getTokensOut(), token_); }

    function _contains(address[] memory tokens_, address token_) internal pure returns (bool) {
        for (uint256 i_; i_ < tokens_.length; ++i_) if (tokens_[i_] == token_) return true;
        return false;
    }

    // Families with separately distributed rewards override these methods using their
    // existing reward ledger. Compounded-only families expose no second claim.
    function getRewardTokens() external view virtual returns (address[] memory) { return new address[](0); }
    function accruedRewards(address) external view virtual returns (uint256[] memory) { return new uint256[](0); }
    function rewardIndexesCurrent() external virtual returns (uint256[] memory) { return new uint256[](0); }
    function rewardIndexesStored() external view virtual returns (uint256[] memory) { return new uint256[](0); }
    function claimRewards(address user_) external virtual returns (uint256[] memory amounts_) {
        amounts_ = new uint256[](0);
        emit IStandardizedYield.ClaimRewards(user_, new address[](0), amounts_);
    }
}
