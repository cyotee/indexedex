// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenV2.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {AaveV3StataStandardExchangeCommon} from "./AaveV3StataStandardExchangeCommon.sol";

/// @notice Exact-input Stata, underlying and aToken routes, including redemption of existing SE shares.
contract AaveV3StataStandardExchangeInTarget is AaveV3StataStandardExchangeCommon, ReentrancyLockModifiers, IStandardExchangeIn, IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote {
    using SafeERC20 for IERC20;
    error InvalidStataRoute(address tokenIn, address tokenOut);
    error InvalidStataPayment();
    error StataSlippage(uint256 minimum, uint256 received);

    function _stata() internal view returns (IStataTokenV2) {
        return IStataTokenV2(IAaveV3StataStandardVault(address(this)).stataToken());
    }

    function _isStataAsset(IStataTokenV2 stata_, address token_) internal view returns (bool) {
        return token_ == address(stata_) || token_ == stata_.asset() || token_ == stata_.aToken();
    }

    function previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_) external view returns (uint256) {
        return _previewStataExactIn(in_, amount_, out_);
    }

    function _previewStataExactIn(IERC20 in_, uint256 amount_, IERC20 out_) internal view returns (uint256) {
        IStataTokenV2 stata_ = _stata();
        if (address(in_) == address(out_)) revert InvalidStataRoute(address(in_), address(out_));
        if (address(in_) == address(this)) {
            if (!_isStataAsset(stata_, address(out_))) revert InvalidStataRoute(address(in_), address(out_));
            uint256 claim_ = _convertSharesToStata(amount_);
            return address(out_) == address(stata_) ? claim_ : stata_.previewRedeem(claim_);
        }
        if (!_isStataAsset(stata_, address(in_))) revert InvalidStataRoute(address(in_), address(out_));
        if (address(out_) == address(this)) {
            uint256 delta_ = address(in_) == address(stata_) ? amount_ : stata_.previewDeposit(amount_);
            return _convertStataDeltaToShares(delta_, IERC20(address(stata_)).balanceOf(address(this)));
        }
        if (address(out_) == address(stata_)) return stata_.previewDeposit(amount_);
        if (address(in_) == address(stata_) && _isStataAsset(stata_, address(out_))) return stata_.previewRedeem(amount_);
        if (address(in_) == stata_.asset() && address(out_) == stata_.aToken()) return amount_;
        revert InvalidStataRoute(address(in_), address(out_));
    }

    function exchangeIn(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address to_, bool prepaid_, uint256 deadline_)
        external nonReentrant returns (uint256 received_)
    {
        if (amount_ == 0 || to_ == address(0) || block.timestamp > deadline_) revert InvalidStataPayment();
        uint256 quote_ = _previewStataExactIn(in_, amount_, out_);
        if (quote_ < minimum_) revert StataSlippage(minimum_, quote_);
        IStataTokenV2 stata_ = _stata();
        if (address(in_) == address(this)) {
            uint256 claim_ = _convertSharesToStata(amount_);
            _secureSelfBurn(msg.sender, amount_, prepaid_);
            received_ = _deliverStata(stata_, claim_, out_, to_);
        } else {
            uint256 before_ = IERC20(address(stata_)).balanceOf(address(this));
            uint256 actual_ = _secureTokenTransfer(in_, amount_, prepaid_);
            if (address(out_) == address(this)) {
                uint256 delta_ = address(in_) == address(stata_) ? actual_ : _depositIntoStata(stata_, in_, actual_, address(this));
                received_ = _convertStataDeltaToShares(delta_, before_);
                _mintSharesWithUsageFee(to_, received_);
            } else if (address(in_) == address(stata_)) {
                received_ = _deliverStata(stata_, actual_, out_, to_);
            } else if (address(out_) == address(stata_)) {
                received_ = _depositIntoStata(stata_, in_, actual_, to_);
            } else {
                in_.forceApprove(address(stata_.POOL()), actual_);
                stata_.POOL().supply(stata_.asset(), actual_, to_, 0);
                in_.forceApprove(address(stata_.POOL()), 0);
                received_ = actual_;
            }
        }
        if (received_ < minimum_) revert StataSlippage(minimum_, received_);
        _collectAndForwardRewards();
        _syncAllExpectedHoldReserves();
    }

    function _depositIntoStata(IStataTokenV2 stata_, IERC20 in_, uint256 amount_, address to_) internal returns (uint256 received_) {
        in_.forceApprove(address(stata_), amount_);
        received_ = address(in_) == stata_.aToken() ? stata_.depositATokens(amount_, to_) : stata_.deposit(amount_, to_);
        in_.forceApprove(address(stata_), 0);
    }

    function _deliverStata(IStataTokenV2 stata_, uint256 shares_, IERC20 out_, address to_) internal returns (uint256) {
        if (address(out_) == address(stata_)) { out_.safeTransfer(to_, shares_); return shares_; }
        if (address(out_) == stata_.aToken()) return stata_.redeemATokens(shares_, to_, address(this));
        return stata_.redeem(shares_, to_, address(this));
    }

    /// @dev Stata conversions use the current normalized income, which is fixed
    /// across same-transaction supply/withdraw operations. Keep actual receipt
    /// inventory separate from the SE supply and the buffered holder's shares.
    struct StataQuoteState {
        address exchange;
        address asset;
        address holder;
        uint256 holderShares;
        uint256 supply;
        uint256 stataShares;
    }

    function quoteState(address asset, address holder) external view returns (bytes memory, uint256) {
        IStataTokenV2 stata = _stata();
        if (!_isStataAsset(stata, asset)) revert UnsupportedQuoteAsset(asset);
        StataQuoteState memory q = StataQuoteState(
            address(this), asset, holder, IERC20(address(this)).balanceOf(holder),
            ERC20Repo._totalSupply(), stata.balanceOf(address(this))
        );
        return (abi.encode(q), _stataQuoteAssets(q, q.holderShares));
    }

    function _readStataQuote(bytes calldata state) private view returns (StataQuoteState memory q) {
        q = abi.decode(state, (StataQuoteState));
        if (q.exchange != address(this) || !_isStataAsset(_stata(), q.asset)) revert InvalidQuoteState();
    }

    function quoteAssets(bytes calldata state, uint256 shares) external view returns (uint256) {
        return _stataQuoteAssets(_readStataQuote(state), shares);
    }

    function quoteShareBalance(bytes calldata state) external view returns (uint256) {
        return _readStataQuote(state).holderShares;
    }

    function quoteTotalSupply(bytes calldata state) external view returns (uint256) {
        return _readStataQuote(state).supply;
    }

    function _stataQuoteAssets(StataQuoteState memory q, uint256 shares) private view returns (uint256) {
        uint256 receipt = q.supply == 0 ? 0 : Math.mulDiv(shares, q.stataShares, q.supply);
        return q.asset == address(_stata()) ? receipt : _stata().previewRedeem(receipt);
    }

    function _stataQuoteDeposit(StataQuoteState memory q, address token, uint256 amount, bool toHolder)
        private view returns (uint256 minted)
    {
        IStataTokenV2 stata = _stata();
        if (!_isStataAsset(stata, token)) revert UnsupportedQuoteAsset(token);
        uint256 added = token == address(stata) ? amount : stata.previewDeposit(amount);
        minted = q.supply == 0 || q.stataShares == 0 ? added : Math.mulDiv(added, q.supply, q.stataShares);
        q.stataShares += added;
        q.supply += minted;
        if (toHolder) q.holderShares += minted;
        address feeTo = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (feeTo != address(0)) {
            uint256 fee = Math.mulDiv(minted, _getCurrentUsageFee(), 1e18);
            q.supply += fee;
            if (q.holder == feeTo) q.holderShares += fee;
        }
    }

    function quoteTransition(bytes calldata state, Operation operation, uint256 amount)
        external view returns (bytes memory, uint256 amountIn, uint256 amountOut, uint256)
    {
        StataQuoteState memory q = _readStataQuote(state);
        amountIn = amount;
        if (operation == Operation.ReceiveShares) {
            q.holderShares += amount;
            if (q.holderShares > q.supply) revert InvalidQuoteState();
            amountOut = amount;
        } else if (operation == Operation.DepositExactIn) {
            amountOut = _stataQuoteDeposit(q, q.asset, amount, true);
        } else {
            uint256 receipt;
            if (operation == Operation.WithdrawExactOut) {
                receipt = q.asset == address(_stata()) ? amount : _stata().previewWithdraw(amount);
                amountIn = Math.mulDiv(receipt, q.supply, q.stataShares, Math.Rounding.Ceil);
                amountOut = amount;
            } else {
                receipt = q.supply == 0 ? 0 : Math.mulDiv(amount, q.stataShares, q.supply);
                amountOut = q.asset == address(_stata()) ? receipt : _stata().previewRedeem(receipt);
            }
            if (amountIn > q.holderShares) revert InsufficientQuoteShares(amountIn, q.holderShares);
            q.holderShares -= amountIn;
            q.supply -= amountIn;
            q.stataShares -= receipt;
        }
        return (abi.encode(q), amountIn, amountOut, _stataQuoteAssets(q, q.holderShares));
    }

    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amount)
        external view returns (bytes memory, uint256 minted, uint256)
    {
        StataQuoteState memory q = _readStataQuote(state);
        minted = _stataQuoteDeposit(q, tokenIn, amount, false);
        return (abi.encode(q), minted, _stataQuoteAssets(q, q.holderShares));
    }

    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amount)
        external view returns (bytes memory, uint256 amountOut, uint256)
    {
        StataQuoteState memory q = _readStataQuote(state);
        if (tokenIn == address(this)) revert UnsupportedQuoteAsset(tokenIn);
        amountOut = _previewStataExactIn(IERC20(tokenIn), amount, IERC20(q.asset));
        // Direct protocol conversions pay the separate recipient without minting
        // SE shares or consuming the SE's pre-existing Stata reserve.
        return (abi.encode(q), amountOut, _stataQuoteAssets(q, q.holderShares));
    }
}
