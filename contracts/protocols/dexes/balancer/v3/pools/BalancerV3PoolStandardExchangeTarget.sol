// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {StandardExchangeInExecutionBase} from "contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {BalancerV3VaultAwareRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {BalancerV3PoolRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3PoolRepo.sol";
import {PoolData, Rounding, AddLiquidityParams, AddLiquidityKind, RemoveLiquidityParams, RemoveLiquidityKind} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";
import {PoolConfigLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/PoolConfigLib.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {ScalingHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {BalancerV3PoolStandardExchangeRepo as Repo} from "./BalancerV3PoolStandardExchangeRepo.sol";
import {BalancerV3PoolLiquidationLib as Liquidation} from "./BalancerV3PoolLiquidationLib.sol";
import {BalancerV3NativePoolQuoteBase, BalancerV3NativePoolQuoteLib} from "./BalancerV3NativePoolQuoteBase.sol";

/// @notice Standard routes at the native Balancer pool-token address.
/// @dev The Vault owns the BPT ledger. All issuance and burns use its actual pool
/// liquidity operations, including the pool's configured hooks and fees.
abstract contract BalancerV3PoolStandardExchangeTarget is StandardExchangeInExecutionBase, NativeStandardYieldTarget, BalancerV3NativePoolQuoteBase, IStandardExchange {
    using BetterSafeERC20 for IERC20;
    using FixedPoint for uint256;

    error UnauthorizedPoolLiquidity();
    error PoolLiquidityFundingMismatch(uint256 expected, uint256 actual);
    error UnsupportedPoolPretransfer();

    struct LiquidityRequest {
        IERC20 tokenIn;
        IERC20 tokenOut;
        uint256 maxInput;
        uint256 outputLimit;
        address recipient;
        bool exactOutput;
    }

    function _poolVault() internal view returns (IVault) {
        return IVault(address(BalancerV3VaultAwareRepo._balancerV3Vault()));
    }

    function _vaultHeldShares() internal view override returns (uint256) {
        return _poolVault().balanceOf(address(this), address(this));
    }

    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override returns (uint256 received_)
    {
        (, received_) = _executePoolLiquidityFrom(
            LiquidityRequest(IERC20(address(this)), IERC20(tokenOut_), shares_, minimum_, receiver_, false),
            false, block.timestamp, address(this)
        );
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        IERC20[] memory poolTokens_ = _poolVault().getPoolTokens(address(this));
        tokens_ = new address[](poolTokens_.length);
        uint256 count_;
        for (uint256 i_; i_ < poolTokens_.length; ++i_) {
            address token_ = address(poolTokens_[i_]);
            if (!_isVirtualBuffer(token_)) tokens_[count_++] = token_;
        }
        assembly ("memory-safe") { mstore(tokens_, count_) }
    }

    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }

    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        if (_poolVault().totalSupply(address(this)) == 0) return 1e18;
        return _poolVault().getBptRate(address(this));
    }

    function previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_) external view returns (uint256) {
        return _previewExchangeIn(in_, amount_, out_);
    }

    function _previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_) internal view override returns (uint256) {
        (bool joining_, uint256 index_) = _poolRoute(in_, out_);
        if (amount_ == 0) return 0;
        return _previewPoolLiquidity(joining_, false, index_, amount_);
    }
    function previewExchangeOut(IERC20 in_, IERC20 out_, uint256 amount_) external view returns (uint256) {
        (bool joining_, uint256 index_) = _poolRoute(in_, out_);
        if (amount_ == 0) return 0;
        return _previewPoolLiquidity(joining_, true, index_, amount_);
    }

    function exchangeIn(IERC20 in_, uint256 amount_, IERC20 out_, uint256 min_, address to_, bool prepaid_, uint256 deadline_)
        external returns (uint256 received_)
    {
        return _exchangeIn(in_, amount_, out_, min_, to_, prepaid_, deadline_);
    }

    function _exchangeIn(IERC20 in_, uint256 amount_, IERC20 out_, uint256 min_, address to_, bool prepaid_, uint256 deadline_)
        internal override returns (uint256 received_)
    {
        (, received_) = _executePoolLiquidity(
            LiquidityRequest(in_, out_, amount_, min_, to_ == address(0) ? msg.sender : to_, false), prepaid_, deadline_
        );
    }
    function exchangeOut(IERC20 in_, uint256 max_, IERC20 out_, uint256 amount_, address to_, bool prepaid_, uint256 deadline_)
        external returns (uint256 paid_)
    {
        (paid_,) = _executePoolLiquidity(
            LiquidityRequest(in_, out_, max_, amount_, to_ == address(0) ? msg.sender : to_, true), prepaid_, deadline_
        );
    }

    function _poolRoute(IERC20 in_, IERC20 out_) internal view returns (bool joining_, uint256 index_) {
        address token_;
        if (address(out_) == address(this) && isValidTokenIn(address(in_))) { joining_ = true; token_ = address(in_); }
        else if (address(in_) == address(this) && isValidTokenOut(address(out_))) token_ = address(out_);
        else revert InvalidRoute(address(in_), address(out_));
        IERC20[] memory tokens_ = _poolVault().getPoolTokens(address(this));
        for (uint256 i_; i_ < tokens_.length; ++i_) if (address(tokens_[i_]) == token_) return (joining_, i_);
        revert InvalidRoute(address(in_), address(out_));
    }

    function _executePoolLiquidity(LiquidityRequest memory p_, bool prepaid_, uint256 deadline_)
        internal returns (uint256 paid_, uint256 received_)
    {
        return _executePoolLiquidityFrom(p_, prepaid_, deadline_, msg.sender);
    }

    function _executePoolLiquidityFrom(LiquidityRequest memory p_, bool prepaid_, uint256 deadline_, address holder_)
        internal returns (uint256 paid_, uint256 received_)
    {
        if (prepaid_) revert UnsupportedPoolPretransfer();
        if (block.timestamp > deadline_) revert DeadlineExceeded(deadline_, block.timestamp);
        if (p_.maxInput == 0 || (p_.exactOutput && p_.outputLimit == 0)) revert ZeroSYAmount();
        ReentrancyLockRepo._onlyUnlocked();
        (bool joining_, uint256 index_) = _poolRoute(p_.tokenIn, p_.tokenOut);
        if (p_.exactOutput) {
            uint256 used_ = _previewPoolLiquidity(joining_, true, index_, p_.outputLimit);
            if (used_ > p_.maxInput) revert MaxAmountExceeded(p_.maxInput, used_);
            p_.maxInput = used_;
        }
        if (joining_ && !p_.exactOutput && _previewPoolLiquidity(true, false, index_, p_.maxInput) == 0) {
            revert MinAmountNotMet(1, 0);
        }
        ReentrancyLockRepo._lock();
        uint256 before_ = joining_ ? p_.tokenIn.balanceOf(address(this)) : _vaultHeldShares();
        if (holder_ == address(this) && address(p_.tokenIn) == address(this)) {
            if (before_ < p_.maxInput) revert PoolLiquidityFundingMismatch(p_.maxInput, before_);
        } else {
            if (joining_) p_.tokenIn.safeTransferFrom(holder_, address(this), p_.maxInput);
            else _poolVault().transferFrom(address(this), holder_, address(this), p_.maxInput);
            uint256 receivedInput_ = (joining_ ? p_.tokenIn.balanceOf(address(this)) : _vaultHeldShares()) - before_;
            if (receivedInput_ != p_.maxInput) revert PoolLiquidityFundingMismatch(p_.maxInput, receivedInput_);
        }
        if (!joining_) _poolVault().approve(address(this), address(this), p_.maxInput);
        Repo._setPending(keccak256(abi.encode(p_)));
        (paid_, received_) = abi.decode(_poolVault().unlock(abi.encodeCall(this.executePoolLiquidity, (p_))), (uint256, uint256));
        if (Repo._layoutStruct().pendingLiquidity != bytes32(0)) revert UnauthorizedPoolLiquidity();
        if (!joining_) _poolVault().approve(address(this), address(this), 0);
        if (paid_ > p_.maxInput) revert MaxAmountExceeded(p_.maxInput, paid_);
        if (received_ < p_.outputLimit) revert MinAmountNotMet(p_.outputLimit, received_);
        if (p_.exactOutput && received_ != p_.outputLimit) revert PoolLiquidityFundingMismatch(p_.outputLimit, received_);
        if (!p_.exactOutput && paid_ != p_.maxInput) revert PoolLiquidityFundingMismatch(p_.maxInput, paid_);
        ReentrancyLockRepo._unlock();
    }

    /// @notice Authenticated Vault callback; not an alternate public deposit route.
    function executePoolLiquidity(LiquidityRequest calldata p_) external returns (uint256 paid_, uint256 received_) {
        IVault vault_ = _poolVault();
        if (msg.sender != address(vault_) || !ReentrancyLockRepo._isLocked()
            || Repo._layoutStruct().pendingLiquidity != keccak256(abi.encode(p_))) revert UnauthorizedPoolLiquidity();
        Repo._setPending(bytes32(0));
        (bool joining_, uint256 index_) = _poolRoute(p_.tokenIn, p_.tokenOut);
        uint256[] memory amounts_ = new uint256[](vault_.getPoolTokens(address(this)).length);
        if (joining_) {
            amounts_[index_] = p_.maxInput;
            (uint256[] memory used_, uint256 bpt_,) = vault_.addLiquidity(AddLiquidityParams({
                pool: address(this), to: p_.recipient, maxAmountsIn: amounts_, minBptAmountOut: p_.outputLimit,
                kind: p_.exactOutput ? AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT : AddLiquidityKind.UNBALANCED, userData: ""
            }));
            paid_ = used_[index_]; received_ = bpt_;
            p_.tokenIn.safeTransfer(address(vault_), paid_);
            uint256 settled_ = vault_.settle(p_.tokenIn, paid_);
            if (settled_ != paid_) revert PoolLiquidityFundingMismatch(paid_, settled_);
        } else {
            (paid_, received_) = _executeLiquidation(vault_, index_, p_);
            uint256 before_ = p_.tokenOut.balanceOf(p_.recipient);
            vault_.sendTo(p_.tokenOut, p_.recipient, received_);
            uint256 delivered_ = p_.tokenOut.balanceOf(p_.recipient) - before_;
            if (delivered_ != received_) revert PoolLiquidityFundingMismatch(received_, delivered_);
        }
    }

    function _executeLiquidation(IVault vault_, uint256 index_, LiquidityRequest calldata p_)
        private returns (uint256 paid_, uint256 received_)
    {
        Liquidation.PoolQuoteState memory q_ = _nativeSnapshot(vault_, index_, false);
        (,,, Liquidation.Step[] memory steps_) = Liquidation._liquidate(
            q_, p_.exactOutput ? p_.outputLimit : p_.maxInput, p_.exactOutput, _nativeQuoteMath, _nativeAfterLiquidity
        );
        uint256[] memory amounts_ = new uint256[](q_.balancesRaw.length);
        for (uint256 i_; i_ < steps_.length; ++i_) {
            Liquidation.Step memory step_ = steps_[i_];
            // A nonzero amount identifies the selected token for the native Vault route.
            amounts_[index_] = step_.assets == 0 ? 1 : step_.assets;
            (uint256 bpt_, uint256[] memory output_,) = vault_.removeLiquidity(RemoveLiquidityParams({
                pool: address(this), from: address(this), maxBptAmountIn: step_.bpt, minAmountsOut: amounts_,
                kind: step_.exactOut ? RemoveLiquidityKind.SINGLE_TOKEN_EXACT_OUT : RemoveLiquidityKind.SINGLE_TOKEN_EXACT_IN,
                userData: ""
            }));
            if (bpt_ != step_.bpt) revert PoolLiquidityFundingMismatch(step_.bpt, bpt_);
            if (output_[index_] != step_.assets) revert PoolLiquidityFundingMismatch(step_.assets, output_[index_]);
            paid_ += bpt_;
            received_ += output_[index_];
        }
    }

    function _previewPoolLiquidity(bool joining_, bool exactOut_, uint256 index_, uint256 amount_)
        internal view returns (uint256 result_)
    {
        Liquidation.PoolQuoteState memory q_ = _nativeSnapshot(_poolVault(), index_, joining_);
        if (!joining_) {
            (, uint256 bpt_, uint256 assets_,) = Liquidation._liquidate(q_, amount_, exactOut_, _nativeQuoteMath, _nativeAfterLiquidity);
            return exactOut_ ? bpt_ : assets_;
        }
        PoolData memory d_ = BalancerV3NativePoolQuoteLib.joinData(_poolVault());
        uint256 supply_ = q_.supply;
        uint256 fee_ = PoolConfigLib.getStaticSwapFeePercentage(d_.poolConfigBits);
        if (!exactOut_) {
            uint256[] memory amounts_ = new uint256[](d_.tokens.length);
            amounts_[index_] = ScalingHelpers.toScaled18ApplyRateRoundDown(amount_, d_.decimalScalingFactors[index_], d_.tokenRates[index_]);
            result_ = _previewUnbalancedBpt(d_.balancesLiveScaled18, amounts_, supply_, fee_, q_);
        } else {
            uint256 newSupply_ = supply_ + amount_;
            uint256 ratio_ = newSupply_.divUp(supply_);
            _checkNativeMaximumRatio(ratio_);
            uint256 next_ = _nativeBalance(q_, d_.balancesLiveScaled18, ratio_);
            uint256 taxable_ = next_ - newSupply_ * d_.balancesLiveScaled18[index_] / supply_;
            uint256 swapFee_ = taxable_.divUp(fee_.complement()) - taxable_;
            result_ = next_ - d_.balancesLiveScaled18[index_] + swapFee_;
            result_ = ScalingHelpers.toRawUndoRateRoundUp(result_, d_.decimalScalingFactors[index_], d_.tokenRates[index_]);
        }
    }

    /// @dev Mirrors the pinned BasePoolMath unbalanced-add rounding, except that
    /// a non-increasing invariant quotes zero instead of panicking. Execution
    /// rejects this minimum before custody changes and still uses the Vault math.
    function _previewUnbalancedBpt(
        uint256[] memory balances_, uint256[] memory amounts_, uint256 supply_, uint256 fee_, Liquidation.PoolQuoteState memory q_
    ) private view returns (uint256) {
        uint256[] memory next_ = new uint256[](balances_.length);
        for (uint256 i_; i_ < balances_.length; ++i_) {
            next_[i_] = balances_[i_] + amounts_[i_] - 1;
        }
        uint256 invariant_ = _nativeInvariant(q_, balances_, Rounding.ROUND_UP);
        uint256 ratio_ = _nativeInvariant(q_, next_, Rounding.ROUND_DOWN).divDown(invariant_);
        _checkNativeMaximumRatio(ratio_);
        for (uint256 i_; i_ < balances_.length; ++i_) {
            uint256 proportional_ = ratio_.mulDown(balances_[i_]);
            if (next_[i_] > proportional_) next_[i_] -= (next_[i_] - proportional_).mulUp(fee_);
        }
        uint256 after_ = _nativeInvariant(q_, next_, Rounding.ROUND_DOWN);
        if (after_ <= invariant_) return 0;
        return supply_ * (after_ - invariant_) / invariant_;
    }

    function _checkNativeMaximumRatio(uint256 ratio_) private view {
        uint256 maximum_ = BalancerV3PoolRepo._maximumInvariantRatio();
        if (ratio_ > maximum_) revert BasePoolMath.InvariantRatioAboveMax(ratio_, maximum_);
    }
}
