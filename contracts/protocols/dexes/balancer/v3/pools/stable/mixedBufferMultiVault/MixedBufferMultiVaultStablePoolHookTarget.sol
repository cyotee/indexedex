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
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";

import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {
    MixedBufferMultiVaultStablePoolRepo as Repo
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolRepo.sol";
import {
    MixedBufferMultiVaultStablePoolCommon
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolCommon.sol";

/**
 * @title MixedBufferMultiVaultStablePoolHookTarget
 * @notice Always-route pre-seat/reconcile with walk-next-vault; StableMath pre-seat quote; unpaired free legs.
 */
abstract contract MixedBufferMultiVaultStablePoolHookTarget is MixedBufferMultiVaultStablePoolCommon, IHooks {
    function _balancerV3Vault() internal view virtual returns (address);
    function _expectedFactory() internal view virtual returns (address);

    function getHookFlags() external pure virtual override returns (HookFlags memory) {
        return HookFlags({
            enableHookAdjustedAmounts: false,
            shouldCallBeforeInitialize: true,
            shouldCallAfterInitialize: true,
            shouldCallComputeDynamicSwapFee: false,
            shouldCallBeforeSwap: true,
            shouldCallAfterSwap: true,
            shouldCallBeforeAddLiquidity: true,
            shouldCallAfterAddLiquidity: true,
            shouldCallBeforeRemoveLiquidity: true,
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

        uint256 bIdx = Repo._bufferIndex();
        if (address(tokenConfig[bIdx].token) != address(Repo._bufferToken())) return false;
        if (tokenConfig[bIdx].tokenType != TokenType.STANDARD) return false;

        uint8 n = Repo._vaultCount();
        for (uint256 i; i < n; ++i) {
            uint256 sIdx = Repo._shareIndex(i);
            if (address(tokenConfig[sIdx].token) != address(Repo._shareToken(i))) return false;
            IRateProvider rp = Repo._vaultShareRateProvider(i);
            if (address(rp) == address(0)) {
                if (tokenConfig[sIdx].tokenType != TokenType.STANDARD) return false;
            } else {
                if (tokenConfig[sIdx].tokenType != TokenType.WITH_RATE) return false;
                if (address(tokenConfig[sIdx].rateProvider) != address(rp)) return false;
            }
        }

        if (lm.disableUnbalancedLiquidity) return false;
        if (!lm.enableAddLiquidityCustom) return false;
        if (!lm.enableRemoveLiquidityCustom) return false;
        if (!lm.enableDonation) return false;
        return true;
    }

    function onBeforeInitialize(uint256[] memory exactAmountsIn, bytes memory)
        external
        virtual
        override
        returns (bool)
    {
        if (msg.sender != _balancerV3Vault()) return false;
        uint8 u = Repo._unpairedCount();
        for (uint256 i; i < u; ++i) {
            if (exactAmountsIn[Repo._unpairedIndex(i)] == 0) {
                revert IMixedBufferMultiVaultStablePool.InitialInvariantTooSmall();
            }
        }
        uint256 virtualInit = exactAmountsIn[Repo._bufferIndex()];
        if (virtualInit == 0) revert IMixedBufferMultiVaultStablePool.InitialInvariantTooSmall();
        Repo._setVirtualBuffer(virtualInit);
        uint8 n = Repo._vaultCount();
        for (uint256 i; i < n; ++i) {
            if (exactAmountsIn[Repo._shareIndex(i)] == 0) {
                revert IMixedBufferMultiVaultStablePool.InitialInvariantTooSmall();
            }
            Repo._setHookShareDelta(i, 0);
        }
        return true;
    }

    function onAfterInitialize(uint256[] memory, uint256, bytes memory) external virtual override returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        // L25: fold init physical buffer into SE vaults (virtual already seeded; no virtual bump).
        _depositPhysicalBuffer(0, address(0), false, 0);
        return true;
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
        } else if (kind == AddLiquidityKind.UNBALANCED || kind == AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT) {
            // Deposit physical buffer into most-needed vault; reconcile bumps virtual once (L21/L22).
            uint256 bufferRaw = amountsInRaw[Repo._bufferIndex()];
            if (bufferRaw > 0) {
                _reconcileBufferIn(bufferRaw, address(0));
            }
        }
        return (true, amountsInRaw);
    }

    function onBeforeRemoveLiquidity(
        address,
        address pool,
        RemoveLiquidityKind kind,
        uint256,
        uint256[] memory minAmountsOutScaled18,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        if (pool != address(this)) return false;
        // L23: disallow single-token remove when the only requested token is the buffer.
        if (kind == RemoveLiquidityKind.SINGLE_TOKEN_EXACT_IN || kind == RemoveLiquidityKind.SINGLE_TOKEN_EXACT_OUT) {
            uint256 bIdx = Repo._bufferIndex();
            bool anyOther;
            for (uint256 i; i < minAmountsOutScaled18.length; ++i) {
                if (i != bIdx && minAmountsOutScaled18[i] > 0) {
                    anyOther = true;
                    break;
                }
            }
            if (!anyOther) revert IMixedBufferMultiVaultStablePool.BufferOnlyRemoveDisallowed();
        }
        return true;
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

    function onBeforeSwap(PoolSwapParams calldata params, address pool) public virtual override returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        if (pool != address(this)) return false;

        (IMixedBufferMultiVaultStablePool.TokenKind kindOut,) = Repo._resolveTokenIndex(params.indexOut);
        if (kindOut != IMixedBufferMultiVaultStablePool.TokenKind.Buffer) {
            return true;
        }
        _preSeatBufferWalk(params, pool);
        return true;
    }

    function onAfterSwap(AfterSwapParams calldata params) public virtual override returns (bool, uint256) {
        if (msg.sender != _balancerV3Vault()) return (false, params.amountCalculatedRaw);
        if (params.pool != address(this)) return (false, params.amountCalculatedRaw);

        (IMixedBufferMultiVaultStablePool.TokenKind kindOut,) = Repo._resolveToken(address(params.tokenOut));
        if (kindOut == IMixedBufferMultiVaultStablePool.TokenKind.Buffer) {
            uint256 actualOut = params.amountOutScaled18;
            Repo._clearPendingPreSeat();
            uint256 vtNow = Repo._virtualBuffer();
            if (actualOut > vtNow) {
                revert IMixedBufferMultiVaultStablePool.VirtualBufferUnderflow(vtNow, actualOut);
            }
            Repo._setVirtualBuffer(vtNow - actualOut);
        }

        (IMixedBufferMultiVaultStablePool.TokenKind kindIn,) = Repo._resolveToken(address(params.tokenIn));
        if (kindIn == IMixedBufferMultiVaultStablePool.TokenKind.Buffer) {
            _reconcileBufferIn(params.amountInScaled18, params.router);
        }
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
        uint256 vtPre = Repo._virtualBuffer();
        Repo._setVirtualBuffer(vtPre + (bptAmountOut * vtPre) / tPre);
        uint8 n = Repo._vaultCount();
        for (uint256 i; i < n; ++i) {
            int256 hPre = Repo._hookShareDelta(i);
            Repo._setHookShareDelta(i, hPre + (int256(bptAmountOut) * hPre) / int256(tPre));
        }
    }

    function _scaleVirtualsOnRemove(uint256 bptAmountIn, uint256 tPre) internal {
        uint256 vtPre = Repo._virtualBuffer();
        uint256 vtSub = (bptAmountIn * vtPre) / tPre;
        Repo._setVirtualBuffer(vtSub >= vtPre ? 0 : vtPre - vtSub);
        uint8 n = Repo._vaultCount();
        for (uint256 i; i < n; ++i) {
            int256 hPre = Repo._hookShareDelta(i);
            Repo._setHookShareDelta(i, hPre - (int256(bptAmountIn) * hPre) / int256(tPre));
        }
    }

    function _quoteBufferOut(PoolSwapParams calldata params, address pool, IVault vault)
        internal
        view
        returns (uint256 yRaw)
    {
        if (params.kind != SwapKind.EXACT_IN) {
            return params.amountGivenScaled18;
        }
        (uint256 currentAmp,) = Repo._getAmplificationParameter();
        uint256[] memory balances = _mathBalances(params.balancesScaled18);
        uint256 invariant = StableMath.computeInvariant(currentAmp, balances);
        uint256 swapFeePercentage = vault.getStaticSwapFeePercentage(pool);
        uint256 feeAmount = Math.mulDiv(params.amountGivenScaled18, swapFeePercentage, 1e18, Math.Rounding.Ceil);
        uint256 amountAfterFee = params.amountGivenScaled18 - feeAmount;
        yRaw = StableMath.computeOutGivenExactIn(
            currentAmp, balances, params.indexIn, params.indexOut, amountAfterFee, invariant
        );
    }

    /// @dev L21: walk most-excess vaults until pre-seat succeeds.
    function _preSeatBufferWalk(PoolSwapParams calldata params, address pool) internal {
        uint256 x = Repo._virtualBuffer();
        if (x == 0) revert IMixedBufferMultiVaultStablePool.PoolBufferSideExhausted();

        uint256 balIn = _mathBalanceAt(params.indexIn, params.balancesScaled18);
        uint256 balOut = _mathBalanceAt(params.indexOut, params.balancesScaled18);
        if (balOut == 0) revert IMixedBufferMultiVaultStablePool.PoolBufferSideExhausted();
        if (balIn == 0) {
            (IMixedBufferMultiVaultStablePool.TokenKind kIn, uint256 pIn) = Repo._resolveTokenIndex(params.indexIn);
            if (kIn == IMixedBufferMultiVaultStablePool.TokenKind.Buffer) {
                revert IMixedBufferMultiVaultStablePool.PoolBufferSideExhausted();
            }
            if (kIn == IMixedBufferMultiVaultStablePool.TokenKind.Share) {
                revert IMixedBufferMultiVaultStablePool.PoolShareSideExhausted(pIn);
            }
            revert IMixedBufferMultiVaultStablePool.PoolUnpairedSideExhausted(pIn);
        }

        IVault vault = IVault(_balancerV3Vault());
        uint256 yBufferRaw = _quoteBufferOut(params, pool, vault);
        if (yBufferRaw > x) {
            revert IMixedBufferMultiVaultStablePool.VirtualBufferUnderflow(x, yBufferRaw);
        }

        uint8[] memory order = _rankRedeem(params.balancesScaled18);
        for (uint256 r; r < order.length; ++r) {
            uint8 vaultIdx = order[r];
            if (_tryPreSeatFromVault(params.router, vaultIdx, yBufferRaw)) {
                return;
            }
        }
        revert IMixedBufferMultiVaultStablePool.AllVaultsExhausted();
    }

    function _tryPreSeatFromVault(address seRouter, uint8 vaultIdx, uint256 yBufferRaw)
        internal
        returns (bool success)
    {
        IStandardExchange seVault = Repo._standardExchangeVault(vaultIdx);
        IERC20 shareTok = Repo._shareToken(vaultIdx);
        uint256 S;
        try seVault.previewExchangeOut(shareTok, Repo._bufferToken(), yBufferRaw) returns (uint256 sPreview) {
            S = sPreview;
        } catch {
            return false;
        }
        if (S == 0) return false;
        uint256 drainAmount = _bv3SharesRemoveOutRaw(S, Repo._shareIndex(vaultIdx));
        try this.__preSeatAttempt(seRouter, vaultIdx, yBufferRaw, drainAmount) {
            return true;
        } catch {
            return false;
        }
    }

    /// @dev External-self call so try/catch can revert without undoing outer state incorrectly.
    function __preSeatAttempt(address seRouter, uint8 vaultIdx, uint256 yBufferRaw, uint256 drainAmount) external {
        require(msg.sender == address(this), "only self");
        _doPreSeat(seRouter, vaultIdx, yBufferRaw, drainAmount);
    }

    function _doPreSeat(address seRouter, uint8 vaultIdx, uint256 yBufferRaw, uint256 drainAmount) internal {
        uint256 sharesConsumed = _preSeatExchangeOut(seRouter, vaultIdx, yBufferRaw, drainAmount);
        _preSeatDonateAndDelta(vaultIdx, yBufferRaw, drainAmount, sharesConsumed);
        Repo._setPendingPreSeat(vaultIdx, drainAmount);
    }

    function _preSeatExchangeOut(address seRouter, uint8 vaultIdx, uint256 yBufferRaw, uint256 drainAmount)
        internal
        returns (uint256 sharesConsumed)
    {
        IVault vault = IVault(_balancerV3Vault());
        IStandardExchange seVault = Repo._standardExchangeVault(vaultIdx);
        IERC20 shareTok = Repo._shareToken(vaultIdx);
        uint256 shareIdx = Repo._shareIndex(vaultIdx);

        vault.sendTo(shareTok, address(this), drainAmount);
        {
            uint256[] memory remAmts = new uint256[](Repo._tokenCount());
            remAmts[shareIdx] = drainAmount;
            vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));
        }

        shareTok.approve(address(seVault), drainAmount);
        _passPrepay(seRouter, address(seVault));
        try seVault.exchangeOut(
            shareTok, drainAmount, Repo._bufferToken(), yBufferRaw, address(vault), false, block.timestamp
        ) returns (
            uint256 sc
        ) {
            sharesConsumed = sc;
        } catch {
            _restorePrepay(seRouter);
            revert IMixedBufferMultiVaultStablePool.PreSeatRedemptionFailed(drainAmount, yBufferRaw);
        }
        _restorePrepay(seRouter);
        if (sharesConsumed == 0) {
            revert IMixedBufferMultiVaultStablePool.PreSeatRedemptionFailed(drainAmount, yBufferRaw);
        }
        vault.settle(Repo._bufferToken(), yBufferRaw);
    }

    function _preSeatDonateAndDelta(uint8 vaultIdx, uint256 yBufferRaw, uint256 drainAmount, uint256 sharesConsumed)
        internal
    {
        IVault vault = IVault(_balancerV3Vault());
        IERC20 shareTok = Repo._shareToken(vaultIdx);
        uint256 shareIdx = Repo._shareIndex(vaultIdx);
        uint256 sharesSurplus = drainAmount - sharesConsumed;
        uint256 surplusDonationRaw = _bv3SharesDonationRaw(sharesSurplus, shareIdx);
        if (sharesSurplus > 0) {
            shareTok.transfer(address(vault), sharesSurplus);
            vault.settle(shareTok, surplusDonationRaw);
        }
        {
            uint256[] memory addAmts = new uint256[](Repo._tokenCount());
            addAmts[Repo._bufferIndex()] = yBufferRaw;
            addAmts[shareIdx] = sharesSurplus;
            vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));
        }
        int256 deltaAdj = int256(drainAmount - surplusDonationRaw);
        Repo._setHookShareDelta(vaultIdx, Repo._hookShareDelta(vaultIdx) - deltaAdj);
    }

    /// @dev L21: deposit swap/LP buffer amount; L25 residual cleared at init via onAfterInitialize.
    function _reconcileBufferIn(uint256 xRaw, address seRouter) internal {
        if (xRaw == 0) return;
        _depositPhysicalBuffer(xRaw, seRouter, true, xRaw);
    }

    function _depositPhysicalBuffer(uint256 amount, address seRouter, bool bumpVirtual, uint256 virtualBump) internal {
        if (amount == 0) {
            // Deposit whatever physical remains (init sweep).
            IVault vault = IVault(_balancerV3Vault());
            (,, uint256[] memory balancesRaw,) = vault.getPoolTokenInfo(address(this));
            amount = balancesRaw[Repo._bufferIndex()];
            if (amount == 0) return;
        }
        uint256[] memory live = IVault(_balancerV3Vault()).getCurrentLiveBalances(address(this));
        uint8[] memory order = _rankDeposit(live);
        for (uint256 r; r < order.length; ++r) {
            if (_tryReconcileToVault(seRouter, order[r], amount, bumpVirtual, virtualBump)) {
                return;
            }
        }
        if (bumpVirtual) revert IMixedBufferMultiVaultStablePool.AllVaultsExhausted();
    }

    function _tryReconcileToVault(
        address seRouter,
        uint8 vaultIdx,
        uint256 physicalRaw,
        bool bumpVirtual,
        uint256 virtualBump
    ) internal returns (bool) {
        try this.__reconcileAttempt(seRouter, vaultIdx, physicalRaw, bumpVirtual, virtualBump) {
            return true;
        } catch {
            return false;
        }
    }

    function __reconcileAttempt(
        address seRouter,
        uint8 vaultIdx,
        uint256 physicalRaw,
        bool bumpVirtual,
        uint256 virtualBump
    ) external {
        require(msg.sender == address(this), "only self");
        _doReconcile(seRouter, vaultIdx, physicalRaw, bumpVirtual, virtualBump);
    }

    function _doReconcile(address seRouter, uint8 vaultIdx, uint256 physicalRaw, bool bumpVirtual, uint256 virtualBump)
        internal
    {
        uint256 minted = _reconcileExchangeIn(seRouter, vaultIdx, physicalRaw);
        _reconcileDonateAndDelta(vaultIdx, physicalRaw, minted, bumpVirtual, virtualBump);
    }

    function _reconcileExchangeIn(address seRouter, uint8 vaultIdx, uint256 xRaw) internal returns (uint256 minted) {
        IVault vault = IVault(_balancerV3Vault());
        IStandardExchange seVault = Repo._standardExchangeVault(vaultIdx);
        IERC20 bufferTok = Repo._bufferToken();
        IERC20 shareTok = Repo._shareToken(vaultIdx);

        vault.sendTo(bufferTok, address(this), xRaw);
        bufferTok.approve(address(seVault), xRaw);
        _passPrepay(seRouter, address(seVault));
        try seVault.exchangeIn(bufferTok, xRaw, shareTok, 0, address(vault), false, block.timestamp) returns (
            uint256 m
        ) {
            minted = m;
        } catch {
            _restorePrepay(seRouter);
            revert IMixedBufferMultiVaultStablePool.PostSwapDepositFailed(xRaw);
        }
        _restorePrepay(seRouter);
        if (minted == 0) revert IMixedBufferMultiVaultStablePool.PostSwapDepositFailed(xRaw);
    }

    function _reconcileDonateAndDelta(
        uint8 vaultIdx,
        uint256 physicalRaw,
        uint256 minted,
        bool bumpVirtual,
        uint256 virtualBump
    ) internal {
        IVault vault = IVault(_balancerV3Vault());
        IERC20 shareTok = Repo._shareToken(vaultIdx);
        uint256 shareIdx = Repo._shareIndex(vaultIdx);
        uint256 bufferIdx = Repo._bufferIndex();
        uint256 donationRaw = _bv3SharesDonationRaw(minted, shareIdx);
        vault.settle(shareTok, donationRaw);
        {
            uint256[] memory addAmts = new uint256[](Repo._tokenCount());
            addAmts[shareIdx] = minted;
            vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));
        }
        {
            uint256[] memory remAmts = new uint256[](Repo._tokenCount());
            remAmts[bufferIdx] = physicalRaw;
            vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));
        }
        if (bumpVirtual && virtualBump > 0) {
            Repo._setVirtualBuffer(Repo._virtualBuffer() + virtualBump);
        }
        Repo._setHookShareDelta(vaultIdx, Repo._hookShareDelta(vaultIdx) + int256(donationRaw));
    }

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
