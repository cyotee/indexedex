// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {
    HookFlags,
    TokenConfig,
    TokenType,
    LiquidityManagement,
    PoolSwapParams,
    SwapKind,
    AfterSwapParams,
    AddLiquidityKind,
    RemoveLiquidityKind,
    AddLiquidityParams,
    RemoveLiquidityParams
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IBalancerV3StandardExchangeRouterPrepay} from
    "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";

import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {MixedLegWeightedBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolRepo.sol";
import {MixedLegWeightedBufferPoolCommon} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolCommon.sol";

/**
 * @title MixedLegWeightedBufferPoolHookTarget
 * @notice IHooks for mixed unpaired + buffered-pair weighted pool. Hook facet on pool diamond.
 */
abstract contract MixedLegWeightedBufferPoolHookTarget is MixedLegWeightedBufferPoolCommon, IHooks {
    function _balancerV3Vault() internal view virtual returns (address);
    function _expectedFactory() internal view virtual returns (address);

    function getHookFlags() external pure virtual override returns (HookFlags memory) {
        return HookFlags({
            enableHookAdjustedAmounts: false,
            shouldCallBeforeInitialize: true,
            shouldCallAfterInitialize: false,
            shouldCallComputeDynamicSwapFee: false,
            shouldCallBeforeSwap: true,
            shouldCallAfterSwap: true,
            shouldCallBeforeAddLiquidity: true,
            shouldCallAfterAddLiquidity: true,
            shouldCallBeforeRemoveLiquidity: false,
            shouldCallAfterRemoveLiquidity: true
        });
    }

    function onRegister(
        address factory,
        address pool,
        TokenConfig[] memory tokenConfig,
        LiquidityManagement calldata lm
    ) external view virtual override returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        if (factory != _expectedFactory()) return false;
        if (pool != address(this)) return false;

        if (tokenConfig.length != Repo._tokenCount()) return false;

        uint8 u = Repo._unpairedCount();
        for (uint256 i; i < u; ++i) {
            uint256 idx = Repo._unpairedIndex(i);
            if (address(tokenConfig[idx].token) != address(Repo._unpairedToken(i))) return false;
            IRateProvider rp = Repo._unpairedRateProvider(i);
            if (address(rp) == address(0)) {
                if (tokenConfig[idx].tokenType != TokenType.STANDARD) return false;
            } else {
                if (tokenConfig[idx].tokenType != TokenType.WITH_RATE) return false;
                if (address(tokenConfig[idx].rateProvider) != address(rp)) return false;
            }
        }

        uint8 p = Repo._pairCount();
        for (uint256 i; i < p; ++i) {
            uint256 bIdx = Repo._bufferIndex(i);
            uint256 sIdx = Repo._shareIndex(i);
            if (address(tokenConfig[bIdx].token) != address(Repo._bufferToken(i))) return false;
            if (address(tokenConfig[sIdx].token) != address(Repo._shareToken(i))) return false;
            if (tokenConfig[bIdx].tokenType != TokenType.STANDARD) return false;
            if (tokenConfig[sIdx].tokenType != TokenType.WITH_RATE) return false;
            if (address(tokenConfig[sIdx].rateProvider) != address(Repo._pairRateProvider(i))) return false;
        }

        if (lm.disableUnbalancedLiquidity) return false;
        if (!lm.enableAddLiquidityCustom) return false;
        if (!lm.enableRemoveLiquidityCustom) return false;
        if (!lm.enableDonation) return false;
        return true;
    }

    /// @inheritdoc IHooks
    /// @dev L25: virtualBuffer[i] = exactAmountsInScaled18[bufferIndex[i]].
    function onBeforeInitialize(uint256[] memory exactAmountsIn, bytes memory)
        external
        virtual
        override
        returns (bool)
    {
        if (msg.sender != _balancerV3Vault()) return false;
        // Unpaired legs: physical seed only (no virtual). Require non-zero seed amount.
        uint8 u = Repo._unpairedCount();
        for (uint256 i; i < u; ++i) {
            if (exactAmountsIn[Repo._unpairedIndex(i)] == 0) {
                revert IMixedLegWeightedBufferPool.InitialInvariantTooSmall();
            }
        }
        // Buffer legs: virtualBuffer[i] = scaled18 seed (same policy as multi-pair L25).
        uint8 p = Repo._pairCount();
        for (uint256 i; i < p; ++i) {
            uint256 virtualInit = exactAmountsIn[Repo._bufferIndex(i)];
            if (virtualInit == 0) revert IMixedLegWeightedBufferPool.InitialInvariantTooSmall();
            Repo._setVirtualBuffer(i, virtualInit);
            Repo._setHookShareDelta(i, 0);
            if (exactAmountsIn[Repo._shareIndex(i)] == 0) {
                revert IMixedLegWeightedBufferPool.InitialInvariantTooSmall();
            }
        }
        return true;
    }

    function onAfterInitialize(uint256[] memory, uint256, bytes memory)
        external
        virtual
        override
        returns (bool)
    {
        return false;
    }

    function onBeforeAddLiquidity(
        address,
        address pool,
        AddLiquidityKind,
        uint256[] memory,
        uint256,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        if (pool != address(this)) return false;
        return true;
    }

    function onAfterAddLiquidity(
        address,
        address pool,
        AddLiquidityKind kind,
        uint256[] memory amountsInScaled18,
        uint256[] memory amountsInRaw,
        uint256 bptAmountOut,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool, uint256[] memory) {
        if (msg.sender != _balancerV3Vault()) return (false, amountsInRaw);
        if (pool != address(this)) return (false, amountsInRaw);

        if (kind == AddLiquidityKind.PROPORTIONAL) {
            uint256 tPost = IERC20(address(this)).totalSupply();
            uint256 tPre = tPost - bptAmountOut;
            if (tPre == 0) return (true, amountsInRaw);
            _scaleVirtualsOnAdd(bptAmountOut, tPre);
        } else if (
            kind == AddLiquidityKind.UNBALANCED || kind == AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT
        ) {
            _growVirtualsOnUnbalanced(amountsInScaled18);
        }
        // DONATION / CUSTOM: no virtual bump (hook-internal reconcile uses DONATION).
        return (true, amountsInRaw);
    }

    function onBeforeRemoveLiquidity(
        address,
        address,
        RemoveLiquidityKind,
        uint256,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool) {
        return false;
    }

    function onAfterRemoveLiquidity(
        address,
        address pool,
        RemoveLiquidityKind,
        uint256 bptAmountIn,
        uint256[] memory,
        uint256[] memory amountsOutRaw,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool, uint256[] memory) {
        if (msg.sender != _balancerV3Vault()) return (false, amountsOutRaw);
        if (pool != address(this)) return (false, amountsOutRaw);
        uint256 tPost = IERC20(address(this)).totalSupply();
        uint256 tPre = tPost + bptAmountIn;
        if (tPre == 0) return (true, amountsOutRaw);

        _scaleVirtualsOnRemove(bptAmountIn, tPre);
        return (true, amountsOutRaw);
    }

    function onBeforeSwap(PoolSwapParams calldata params, address pool)
        public
        virtual
        override
        returns (bool)
    {
        if (msg.sender != _balancerV3Vault()) return false;
        if (pool != address(this)) return false;

        (IMixedLegWeightedBufferPool.TokenKind kindOut, uint256 legOut) =
            Repo._resolveTokenIndex(params.indexOut);
        if (kindOut != IMixedLegWeightedBufferPool.TokenKind.Buffer) {
            // Unpaired or share out: no pre-seat.
            return true;
        }
        _preSeatBuffer(params, pool, legOut);
        return true;
    }

    function onAfterSwap(AfterSwapParams calldata params)
        public
        virtual
        override
        returns (bool, uint256)
    {
        if (msg.sender != _balancerV3Vault()) return (false, params.amountCalculatedRaw);
        if (params.pool != address(this)) return (false, params.amountCalculatedRaw);

        (IMixedLegWeightedBufferPool.TokenKind kindOut, uint256 legOut) =
            Repo._resolveToken(address(params.tokenOut));
        if (kindOut == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
            uint256 actualOut = params.amountOutScaled18;
            Repo._clearPendingPreSeat();
            uint256 vtNow = Repo._virtualBuffer(legOut);
            if (actualOut > vtNow) {
                revert IMixedLegWeightedBufferPool.VirtualBufferUnderflow(vtNow, actualOut);
            }
            Repo._setVirtualBuffer(legOut, vtNow - actualOut);
        }

        (IMixedLegWeightedBufferPool.TokenKind kindIn, uint256 legIn) =
            Repo._resolveToken(address(params.tokenIn));
        if (kindIn == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
            _reconcileBufferIn(params.amountInScaled18, legIn, params.router);
        }
        // Unpaired and share legs: physical balances only (no SE I/O).
        return (true, params.amountCalculatedRaw);
    }

    function onComputeDynamicSwapFeePercentage(PoolSwapParams calldata, address, uint256)
        external
        view
        virtual
        override
        returns (bool, uint256)
    {
        return (false, 0);
    }

    function _scaleVirtualsOnAdd(uint256 bptAmountOut, uint256 tPre) internal {
        uint8 p = Repo._pairCount();
        for (uint256 i; i < p; ++i) {
            uint256 vtPre = Repo._virtualBuffer(i);
            Repo._setVirtualBuffer(i, vtPre + (bptAmountOut * vtPre) / tPre);
            int256 hPre = Repo._hookShareDelta(i);
            Repo._setHookShareDelta(i, hPre + (int256(bptAmountOut) * hPre) / int256(tPre));
        }
    }

    function _growVirtualsOnUnbalanced(uint256[] memory amountsInScaled18) internal {
        uint8 p = Repo._pairCount();
        for (uint256 i; i < p; ++i) {
            uint256 bufferIn = amountsInScaled18[Repo._bufferIndex(i)];
            if (bufferIn > 0) {
                Repo._setVirtualBuffer(i, Repo._virtualBuffer(i) + bufferIn);
            }
        }
    }

    function _scaleVirtualsOnRemove(uint256 bptAmountIn, uint256 tPre) internal {
        uint8 p = Repo._pairCount();
        for (uint256 i; i < p; ++i) {
            uint256 vtPre = Repo._virtualBuffer(i);
            uint256 vtSub = (bptAmountIn * vtPre) / tPre;
            Repo._setVirtualBuffer(i, vtSub >= vtPre ? 0 : vtPre - vtSub);
            int256 hPre = Repo._hookShareDelta(i);
            Repo._setHookShareDelta(i, hPre - (int256(bptAmountIn) * hPre) / int256(tPre));
        }
    }

    /* ----- Internal: pre-seat / reconcile ----- */

    function _quoteBufferOut(
        PoolSwapParams calldata params,
        address pool,
        IVault vault,
        uint256 balIn,
        uint256 balOut,
        uint256 wIn,
        uint256 wOut
    ) internal view returns (uint256 yRaw) {
        if (params.kind != SwapKind.EXACT_IN) {
            return params.amountGivenScaled18;
        }
        uint256 swapFeePercentage = vault.getStaticSwapFeePercentage(pool);
        uint256 feeAmount =
            Math.mulDiv(params.amountGivenScaled18, swapFeePercentage, 1e18, Math.Rounding.Ceil);
        yRaw = WeightedMath.computeOutGivenExactIn(
            balIn, wIn, balOut, wOut, params.amountGivenScaled18 - feeAmount
        );
    }

    function _preSeatBuffer(PoolSwapParams calldata params, address pool, uint256 pairOut) internal {
        uint256 yBufferRaw = _computePreSeatY(params, pool, pairOut);
        uint256 drainAmount = _drainAndRedeemForBuffer(params, pairOut, yBufferRaw);
        _donatePreSeatBuffer(pairOut, yBufferRaw, drainAmount);
        Repo._setPendingPreSeat(uint8(pairOut), drainAmount);
    }

    function _computePreSeatY(PoolSwapParams calldata params, address pool, uint256 pairOut)
        internal
        view
        returns (uint256 yBufferRaw)
    {
        uint256 x = Repo._virtualBuffer(pairOut);
        if (x == 0) revert IMixedLegWeightedBufferPool.PoolBufferSideExhausted(pairOut);

        uint256 balIn = _mathBalanceAt(params.indexIn, params.balancesScaled18);
        uint256 balOut = _mathBalanceAt(params.indexOut, params.balancesScaled18);
        if (balOut == 0) revert IMixedLegWeightedBufferPool.PoolBufferSideExhausted(pairOut);
        if (balIn == 0) {
            (IMixedLegWeightedBufferPool.TokenKind kIn, uint256 pIn) = Repo._resolveTokenIndex(params.indexIn);
            if (kIn == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
                revert IMixedLegWeightedBufferPool.PoolBufferSideExhausted(pIn);
            }
            if (kIn == IMixedLegWeightedBufferPool.TokenKind.Share) {
                revert IMixedLegWeightedBufferPool.PoolShareSideExhausted(pIn);
            }
            revert IMixedLegWeightedBufferPool.PoolUnpairedSideExhausted(pIn);
        }

        IVault vault = IVault(_balancerV3Vault());
        yBufferRaw = _quoteBufferOut(
            params,
            pool,
            vault,
            balIn,
            balOut,
            Repo._weight(params.indexIn),
            Repo._weight(params.indexOut)
        );
        if (yBufferRaw > x) {
            revert IMixedLegWeightedBufferPool.VirtualBufferUnderflow(x, yBufferRaw);
        }
    }

    function _drainAndRedeemForBuffer(PoolSwapParams calldata params, uint256 pairOut, uint256 yBufferRaw)
        internal
        returns (uint256 drainAmount)
    {
        drainAmount = _previewDrainAmount(pairOut, yBufferRaw);
        _customRemoveShares(pairOut, drainAmount);
        uint256 sharesConsumed = _doExchangeOut(params.router, pairOut, drainAmount, yBufferRaw);
        _settleAndDonatePreSeat(pairOut, yBufferRaw, drainAmount, sharesConsumed);
    }

    function _previewDrainAmount(uint256 pairOut, uint256 yBufferRaw) internal view returns (uint256) {
        IStandardExchange seVault = Repo._standardExchangeVault(pairOut);
        uint256 S = seVault.previewExchangeOut(Repo._shareToken(pairOut), Repo._bufferToken(pairOut), yBufferRaw);
        return _bv3SharesRemoveOutRaw(S, Repo._shareIndex(pairOut));
    }

    function _customRemoveShares(uint256 pairOut, uint256 drainAmount) internal {
        IVault vault = IVault(_balancerV3Vault());
        IERC20 shareTok = Repo._shareToken(pairOut);
        uint256 shareIdx = Repo._shareIndex(pairOut);
        vault.sendTo(shareTok, address(this), drainAmount);
        uint256[] memory remAmts = new uint256[](Repo._tokenCount());
        remAmts[shareIdx] = drainAmount;
        vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));
    }

    function _doExchangeOut(address seRouter, uint256 pairOut, uint256 drainAmount, uint256 yBufferRaw)
        internal
        returns (uint256 sharesConsumed)
    {
        IVault vault = IVault(_balancerV3Vault());
        IStandardExchange seVault = Repo._standardExchangeVault(pairOut);
        IERC20 shareTok = Repo._shareToken(pairOut);
        IERC20 bufferTok = Repo._bufferToken(pairOut);
        shareTok.approve(address(seVault), drainAmount);
        _passPrepay(seRouter, address(seVault));
        try seVault.exchangeOut(
            shareTok, drainAmount, bufferTok, yBufferRaw, address(vault), false, block.timestamp
        ) returns (uint256 sc) {
            sharesConsumed = sc;
        } catch {
            _restorePrepay(seRouter);
            revert IMixedLegWeightedBufferPool.PreSeatRedemptionFailed(drainAmount, yBufferRaw);
        }
        _restorePrepay(seRouter);
        if (sharesConsumed == 0) {
            revert IMixedLegWeightedBufferPool.PreSeatRedemptionFailed(drainAmount, yBufferRaw);
        }
        vault.settle(bufferTok, yBufferRaw);
    }

    function _settleAndDonatePreSeat(
        uint256 pairOut,
        uint256 yBufferRaw,
        uint256 drainAmount,
        uint256 sharesConsumed
    ) internal {
        IVault vault = IVault(_balancerV3Vault());
        IERC20 shareTok = Repo._shareToken(pairOut);
        uint256 shareIdx = Repo._shareIndex(pairOut);
        uint256 sharesSurplus = drainAmount - sharesConsumed;
        uint256 surplusDonationRaw = _bv3SharesDonationRaw(sharesSurplus, shareIdx);
        if (sharesSurplus > 0) {
            shareTok.transfer(address(vault), sharesSurplus);
            vault.settle(shareTok, surplusDonationRaw);
        }
        uint256[] memory addAmts = new uint256[](Repo._tokenCount());
        addAmts[Repo._bufferIndex(pairOut)] = yBufferRaw;
        addAmts[shareIdx] = sharesSurplus;
        vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));
        Repo._setHookShareDelta(
            pairOut, Repo._hookShareDelta(pairOut) - int256(drainAmount - surplusDonationRaw)
        );
    }

    function _donatePreSeatBuffer(uint256, uint256, uint256) internal pure {}

    function _passPrepay(address seRouter, address seVault) internal {
        if (seRouter != address(0) && seRouter.code.length > 0) {
            try IBalancerV3StandardExchangeRouterPrepay(seRouter).passPrepayAuth(seVault) {} catch {}
        }
    }

    function _restorePrepay(address seRouter) internal {
        if (seRouter != address(0) && seRouter.code.length > 0) {
            try IBalancerV3StandardExchangeRouterPrepay(seRouter).restorePrepayAuth() {} catch {}
        }
    }

    function _reconcileBufferIn(uint256 xRaw, uint256 pairIn, address seRouter) internal {
        IVault vault = IVault(_balancerV3Vault());
        IStandardExchange seVault = Repo._standardExchangeVault(pairIn);
        IERC20 bufferTok = Repo._bufferToken(pairIn);
        IERC20 shareTok = Repo._shareToken(pairIn);
        uint256 bufferIdx = Repo._bufferIndex(pairIn);
        uint256 shareIdx = Repo._shareIndex(pairIn);

        vault.sendTo(bufferTok, address(this), xRaw);

        bufferTok.approve(address(seVault), xRaw);
        _passPrepay(seRouter, address(seVault));
        uint256 minted;
        try seVault.exchangeIn(bufferTok, xRaw, shareTok, 0, address(vault), false, block.timestamp) returns (
            uint256 m
        ) {
            minted = m;
        } catch {
            _restorePrepay(seRouter);
            revert IMixedLegWeightedBufferPool.PostSwapDepositFailed(xRaw);
        }
        _restorePrepay(seRouter);
        if (minted == 0) revert IMixedLegWeightedBufferPool.PostSwapDepositFailed(xRaw);

        uint256 donationRaw = _bv3SharesDonationRaw(minted, shareIdx);
        vault.settle(shareTok, donationRaw);

        {
            uint256 n = Repo._tokenCount();
            uint256[] memory addAmts = new uint256[](n);
            addAmts[shareIdx] = minted;
            vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));
        }
        {
            uint256 n = Repo._tokenCount();
            uint256[] memory remAmts = new uint256[](n);
            remAmts[bufferIdx] = xRaw;
            vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));
        }

        // amountInScaled18 for STANDARD buffer ≈ raw for 18-decimal tokens (test tokens are 18).
        Repo._setVirtualBuffer(pairIn, Repo._virtualBuffer(pairIn) + xRaw);
        Repo._setHookShareDelta(pairIn, Repo._hookShareDelta(pairIn) + int256(donationRaw));
    }

    function _buildAddLiquidityParams(
        address to_,
        uint256[] memory maxAmountsIn_,
        uint256 minBptAmountOut_,
        AddLiquidityKind kind_
    ) internal view returns (AddLiquidityParams memory) {
        return AddLiquidityParams({
            pool: address(this),
            to: to_,
            maxAmountsIn: maxAmountsIn_,
            minBptAmountOut: minBptAmountOut_,
            kind: kind_,
            userData: ""
        });
    }

    function _buildRemoveLiquidityParams(
        address from_,
        uint256 maxBptAmountIn_,
        uint256[] memory minAmountsOut_,
        RemoveLiquidityKind kind_
    ) internal view returns (RemoveLiquidityParams memory) {
        return RemoveLiquidityParams({
            pool: address(this),
            from: from_,
            maxBptAmountIn: maxBptAmountIn_,
            minAmountsOut: minAmountsOut_,
            kind: kind_,
            userData: ""
        });
    }
}
