// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {BalancerV3VaultAwareRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IBasePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBasePool.sol";
import {PoolData, Rounding, TokenType, AddLiquidityParams, AddLiquidityKind, RemoveLiquidityParams, RemoveLiquidityKind} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";
import {PoolDataLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/PoolDataLib.sol";
import {PoolConfigLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/PoolConfigLib.sol";
import {ScalingHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {BalancerV3PoolStandardExchangeRepo as Repo} from "./BalancerV3PoolStandardExchangeRepo.sol";

/// @notice Standard routes at the native Balancer pool-token address.
/// @dev The Vault owns the BPT ledger. All issuance and burns use its actual pool
/// liquidity operations, including the pool's configured hooks and fees.
abstract contract BalancerV3PoolStandardExchangeTarget is NativeStandardYieldTarget, IStandardExchange {
    using BetterSafeERC20 for IERC20;

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

    /// @dev Native single-token liquidity operates on physical unpaired tokens and SE
    /// shares. Buffer depths are virtual: the pool invariant ignores their raw input
    /// delta, and its balance solver does not represent physical buffer withdrawals.
    /// Existing pool swap/reconciliation routes remain separate from BPT issuance.
    function _isVirtualBuffer(address token_) internal view returns (bool) {
        (bool ok_, bytes memory data_) = address(this).staticcall(abi.encodeWithSignature("ttaToken()"));
        if (ok_ && data_.length == 32) return token_ == abi.decode(data_, (address));
        (ok_, data_) = address(this).staticcall(abi.encodeWithSignature("bufferToken()"));
        if (ok_ && data_.length == 32) return token_ == abi.decode(data_, (address));
        (ok_, data_) = address(this).staticcall(abi.encodeWithSignature("pairCount()"));
        if (!ok_ || data_.length != 32) return false;
        uint256 pairs_ = abi.decode(data_, (uint256));
        for (uint256 i_; i_ < pairs_; ++i_) {
            (ok_, data_) = address(this).staticcall(abi.encodeWithSignature("bufferToken(uint256)", i_));
            if (ok_ && data_.length == 32 && token_ == abi.decode(data_, (address))) return true;
        }
        return false;
    }

    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        if (IERC20(address(this)).totalSupply() == 0) return 1e18;
        return _poolVault().getBptRate(address(this));
    }

    function previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_) external view returns (uint256) {
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
        if (prepaid_) revert UnsupportedPoolPretransfer();
        if (block.timestamp > deadline_) revert DeadlineExceeded(deadline_, block.timestamp);
        if (p_.maxInput == 0 || (p_.exactOutput && p_.outputLimit == 0)) revert ZeroSYAmount();
        ReentrancyLockRepo._onlyUnlocked();
        _poolRoute(p_.tokenIn, p_.tokenOut);
        ReentrancyLockRepo._lock();
        uint256 before_ = p_.tokenIn.balanceOf(address(this));
        // Only Pendle's internal-balance redemption calls as the pool itself.
        if (msg.sender == address(this) && address(p_.tokenIn) == address(this)) {
            if (before_ < p_.maxInput) revert PoolLiquidityFundingMismatch(p_.maxInput, before_);
        } else {
            p_.tokenIn.safeTransferFrom(msg.sender, address(this), p_.maxInput);
            uint256 receivedInput_ = p_.tokenIn.balanceOf(address(this)) - before_;
            if (receivedInput_ != p_.maxInput) revert PoolLiquidityFundingMismatch(p_.maxInput, receivedInput_);
        }
        if (address(p_.tokenIn) == address(this)) p_.tokenIn.forceApprove(address(this), p_.maxInput);
        Repo._setPending(keccak256(abi.encode(p_)));
        (paid_, received_) = abi.decode(_poolVault().unlock(abi.encodeCall(this.executePoolLiquidity, (p_))), (uint256, uint256));
        if (Repo._layoutStruct().pendingLiquidity != bytes32(0)) revert UnauthorizedPoolLiquidity();
        if (address(p_.tokenIn) == address(this)) p_.tokenIn.forceApprove(address(this), 0);
        if (paid_ > p_.maxInput) revert MaxAmountExceeded(p_.maxInput, paid_);
        if (received_ < p_.outputLimit) revert MinAmountNotMet(p_.outputLimit, received_);
        if (p_.exactOutput && received_ != p_.outputLimit) revert PoolLiquidityFundingMismatch(p_.outputLimit, received_);
        if (!p_.exactOutput && paid_ != p_.maxInput) revert PoolLiquidityFundingMismatch(p_.maxInput, paid_);
        if (paid_ < p_.maxInput) p_.tokenIn.safeTransfer(msg.sender, p_.maxInput - paid_);
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
            // A nonzero entry selects the single output token even when minOut is zero.
            amounts_[index_] = p_.outputLimit == 0 ? 1 : p_.outputLimit;
            (uint256 bpt_, uint256[] memory output_,) = vault_.removeLiquidity(RemoveLiquidityParams({
                pool: address(this), from: address(this), maxBptAmountIn: p_.maxInput, minAmountsOut: amounts_,
                kind: p_.exactOutput ? RemoveLiquidityKind.SINGLE_TOKEN_EXACT_OUT : RemoveLiquidityKind.SINGLE_TOKEN_EXACT_IN,
                userData: ""
            }));
            paid_ = bpt_; received_ = output_[index_];
            uint256 before_ = p_.tokenOut.balanceOf(p_.recipient);
            vault_.sendTo(p_.tokenOut, p_.recipient, received_);
            uint256 delivered_ = p_.tokenOut.balanceOf(p_.recipient) - before_;
            if (delivered_ != received_) revert PoolLiquidityFundingMismatch(received_, delivered_);
        }
    }

    function _quotePoolData(bool joining_) internal view returns (PoolData memory d_) {
        IVault vault_ = _poolVault();
        d_ = vault_.getPoolData(address(this));
        if (!joining_) return d_;
        (,,uint256[] memory raw_,uint256[] memory lastLive_) = vault_.getPoolTokenInfo(address(this));
        uint256 fee_ = PoolConfigLib.getAggregateYieldFeePercentage(d_.poolConfigBits);
        bool yield_ = fee_ != 0 && !PoolConfigLib.isPoolInRecoveryMode(d_.poolConfigBits);
        for (uint256 i_; i_ < raw_.length; ++i_) {
            PoolDataLib.updateRawAndLiveBalance(d_, i_, raw_[i_], Rounding.ROUND_UP);
            if (yield_ && d_.tokenInfo[i_].paysYieldFees && d_.tokenInfo[i_].tokenType == TokenType.WITH_RATE) {
                uint256 due_ = PoolDataLib._computeYieldFeesDue(d_, lastLive_[i_], i_, fee_);
                if (due_ != 0) PoolDataLib.updateRawAndLiveBalance(d_, i_, raw_[i_] - due_, Rounding.ROUND_UP);
            }
        }
    }

    function _previewPoolLiquidity(bool joining_, bool exactOut_, uint256 index_, uint256 amount_)
        internal view returns (uint256 result_)
    {
        PoolData memory d_ = _quotePoolData(joining_);
        uint256 supply_ = IERC20(address(this)).totalSupply();
        uint256 fee_ = PoolConfigLib.getStaticSwapFeePercentage(d_.poolConfigBits);
        IBasePool pool_ = IBasePool(address(this));
        if (joining_ && !exactOut_) {
            uint256[] memory amounts_ = new uint256[](d_.tokens.length);
            amounts_[index_] = ScalingHelpers.toScaled18ApplyRateRoundDown(amount_, d_.decimalScalingFactors[index_], d_.tokenRates[index_]);
            (result_,) = BasePoolMath.computeAddLiquidityUnbalanced(d_.balancesLiveScaled18, amounts_, supply_, fee_, pool_);
        } else if (joining_) {
            (result_,) = BasePoolMath.computeAddLiquiditySingleTokenExactOut(d_.balancesLiveScaled18, index_, amount_, supply_, fee_, pool_);
            result_ = ScalingHelpers.toRawUndoRateRoundUp(result_, d_.decimalScalingFactors[index_], d_.tokenRates[index_]);
        } else if (!exactOut_) {
            (result_,) = BasePoolMath.computeRemoveLiquiditySingleTokenExactIn(d_.balancesLiveScaled18, index_, amount_, supply_, fee_, pool_);
            result_ = ScalingHelpers.toRawUndoRateRoundDown(result_, d_.decimalScalingFactors[index_], d_.tokenRates[index_]);
        } else {
            uint256 live_ = ScalingHelpers.toScaled18ApplyRateRoundUp(amount_, d_.decimalScalingFactors[index_], d_.tokenRates[index_]);
            (result_,) = BasePoolMath.computeRemoveLiquiditySingleTokenExactOut(d_.balancesLiveScaled18, index_, live_, supply_, fee_, pool_);
        }
    }
}
