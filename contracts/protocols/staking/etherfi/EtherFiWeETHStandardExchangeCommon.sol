// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IWeETH} from "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IWeETH.sol";
import {IeETH as NativeEETH} from "@crane/contracts/external/etherfi/core/interfaces/IeETH.sol";
import {
    IEtherFiLiquidityPool
} from "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IEtherFiLiquidityPool.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    IEtherFiWeETHStandardVault
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {IEtherFiRedemptionManager} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiRedemptionManager.sol";
import {
    EtherFiWeETHStandardExchangeRepo
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeRepo.sol";

/**
 * @title EtherFiWeETHStandardExchangeCommon
 * @notice Shared NAV, inventory checks, closed-form quotes, WETH pay ladder, and stake helpers.
 * @dev Share math uses BetterMath virtual offset (ERC-4626-style). Previews never gate on sleeve/redeem.
 */
abstract contract EtherFiWeETHStandardExchangeCommon is IEtherFiWeETHStandardVault, IStandardExchangeErrors {
    using BetterMath for uint256;
    using SafeERC20 for IERC20;

    /// @dev ether.fi RedemptionManager native ETH sentinel.
    address internal constant ETH_SENTINEL = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 internal constant MIN_EETH_WITHDRAWAL = 100;
    uint256 internal constant MAX_EETH_WITHDRAWAL = 1000 ether;
    /// @dev Rebalance hysteresis: 10% of target liquid (band on target).
    uint256 internal constant REBALANCE_BAND_WAD = 0.1e18;
    uint256 internal constant MAX_QUEUE_REQUESTS_PER_REBALANCE = 5;

    /// @notice Deposit tokens received less than requested (or zero when pretransferred without credit).
    error InsufficientDeposit(uint256 requested, uint256 actual);

    function weETH() public view virtual override returns (address) {
        return EtherFiWeETHStandardExchangeRepo._weETH();
    }

    function eETH() public view virtual override returns (address) {
        return EtherFiWeETHStandardExchangeRepo._eETH();
    }

    function weth() public view virtual override returns (address) {
        return EtherFiWeETHStandardExchangeRepo._weth();
    }

    function liquidityPool() public view virtual override returns (address) {
        return EtherFiWeETHStandardExchangeRepo._liquidityPool();
    }

    function withdrawRequestNFT() public view virtual override returns (address) {
        return EtherFiWeETHStandardExchangeRepo._withdrawRequestNFT();
    }

    function redemptionManager() public view virtual override returns (address) {
        return EtherFiWeETHStandardExchangeRepo._redemptionManager();
    }

    function liquidReserveEth() public view virtual override returns (uint256) {
        return IERC20(weth()).balanceOf(address(this));
    }

    function lockedReserveEth() public view virtual override returns (uint256) {
        uint256 weBal = IERC20(weETH()).balanceOf(address(this));
        uint256 weAsEth = IWeETH(weETH()).getEETHByWeETH(weBal);
        return weAsEth + EtherFiWeETHStandardExchangeRepo._pendingFaceEthTotal();
    }

    function totalReserveEth() public view virtual override returns (uint256) {
        return liquidReserveEth() + lockedReserveEth();
    }

    function actualLiquidReservePercentage() public view virtual override returns (uint256) {
        uint256 total = totalReserveEth();
        if (total == 0) return 0;
        return (liquidReserveEth() * ONE_WAD) / total;
    }

    function targetLiquidReservePercentage() public view virtual override returns (uint256) {
        return VaultFeeOracleQueryAwareRepo._feeOracle().liquidReservePercentageOfVault(address(this));
    }

    function _requireLockedWe(uint256 weRequested) internal view {
        uint256 available = IERC20(weETH()).balanceOf(address(this));
        if (available < weRequested) {
            revert InsufficientLockedReserve(weRequested, available);
        }
    }

    function _decimalOffset() internal view returns (uint8) {
        return ERC4626Repo._decimalOffset();
    }

    function _isSeShare(address token) internal view returns (bool) {
        return token == address(this);
    }

    function _isAsset(address token) internal view returns (bool) {
        return token == weth() || token == eETH() || token == weETH();
    }

    /// @dev ETH-value of an underlying asset amount for *inventory eth face* (not SE mint credit).
    ///      eETH is 1:1 face; weETH via floor amountForShare. Do not use for eETH→SE mint quotes.
    function _assetToEth(address token, uint256 amount) internal view returns (uint256) {
        if (token == weth() || token == eETH()) return amount;
        if (token == weETH()) return IWeETH(weETH()).getEETHByWeETH(amount);
        revert InvalidRoute(token, token);
    }

    /**
     * @dev ETH value actually credited to NAV by `_creditAssetToReserve` for `amount` of `token`.
     *      WETH: face. weETH: amountForShare. eETH: wrap then amountForShare (double floor — live rates lose dust).
     */
    function _creditEthValueOfAsset(address token, uint256 amount) internal view returns (uint256) {
        if (token == weth()) return amount;
        if (token == weETH()) return IWeETH(weETH()).getEETHByWeETH(amount);
        if (token == eETH()) {
            // Matches _creditAssetToReserve: wrap(e) then getEETHByWeETH(weOut)
            uint256 weOut = IWeETH(weETH()).getWeETHByeETH(amount);
            return IWeETH(weETH()).getEETHByWeETH(weOut);
        }
        revert InvalidRoute(token, token);
    }

    /// @dev Asset amount for an ETH-value (floor) — exact-in outs / SE redeem quotes.
    function _ethToAssetDown(address token, uint256 ethValue) internal view returns (uint256) {
        if (token == weth() || token == eETH()) return ethValue;
        if (token == weETH()) return IWeETH(weETH()).getWeETHByeETH(ethValue);
        revert InvalidRoute(token, token);
    }

    /**
     * @dev Minimum asset amount such that `_creditEthValueOfAsset(token, amount) >= ethValue`.
     *      Used for asset→SE exact-out amountIn so mint after credit still hits amountOut.
     */
    function _ethToAssetUp(address token, uint256 ethValue) internal view returns (uint256) {
        if (token == weth()) return ethValue;
        if (token == weETH()) return _weEthForEEthUp(ethValue);
        if (token == eETH()) {
            // Need wrap+amountForShare(e) >= ethValue: ceil we for eth, then ceil e for that we.
            uint256 weNeeded = _weEthForEEthUp(ethValue);
            return _eEthForWeEthUp(weNeeded);
        }
        revert InvalidRoute(token, token);
    }

    /**
     * @dev Minimum weETH such that amountForShare(we) >= eOut (ceil).
     *      Uses LiquidityPool.sharesForWithdrawalAmount when available.
     */
    function _weEthForEEthUp(uint256 eOut) internal view returns (uint256) {
        if (eOut == 0) return 0;
        address pool = liquidityPool();
        // Protocol-favoring ceil share amount for withdrawing `eOut` face.
        uint256 we = IEtherFiLiquidityPool(pool).sharesForWithdrawalAmount(eOut);
        if (we == 0) we = 1;
        while (IWeETH(weETH()).getEETHByWeETH(we) < eOut) {
            unchecked {
                ++we;
            }
        }
        return we;
    }

    /// @dev Native nominal transfers move floor shares; existing native shares affect the balance delta.
    function _eReceivedAt(uint256 heldShares, uint256 amount) internal view returns (uint256) {
        IEtherFiLiquidityPool pool = IEtherFiLiquidityPool(liquidityPool());
        return pool.amountForShare(heldShares + pool.sharesForAmount(amount)) - pool.amountForShare(heldShares);
    }

    function _eInputForReceivedAt(uint256 heldShares, uint256 received) internal view returns (uint256 amount) {
        if (received == 0) return 0;
        IEtherFiLiquidityPool pool = IEtherFiLiquidityPool(liquidityPool());
        uint256 targetBalance = pool.amountForShare(heldShares) + received;
        uint256 targetShares = pool.sharesForAmount(targetBalance);
        if (pool.amountForShare(targetShares) < targetBalance) ++targetShares;
        uint256 movedShares = targetShares - heldShares;
        amount = pool.amountForShare(movedShares);
        if (pool.sharesForAmount(amount) < movedShares) ++amount;
    }

    /// @dev Canonical native share totals supplied by eETH and its liquidity pool.
    function _nativeShareRate() internal view returns (uint256 pooled, uint256 supply) {
        return (IEtherFiLiquidityPool(liquidityPool()).getTotalPooledEther(), NativeEETH(eETH()).totalShares());
    }

    function _ePullInput(uint256 received) internal view returns (uint256) {
        return _eInputForReceivedAt(NativeEETH(eETH()).shares(address(this)), received);
    }

    function _eEthForWeEthUp(uint256 wrappedAmount) internal view returns (uint256 amount) {
        IWeETH wrapped = IWeETH(weETH());
        amount = wrapped.getEETHByWeETH(wrappedAmount);
        if (wrapped.getWeETHByeETH(amount) < wrappedAmount) ++amount;
    }

    /// @dev Public previews have no recipient. An empty recipient is the
    /// conservative native-transfer floor; execution measures its actual delta.
    function _quoteUnwrapToE(uint256 wrappedAmount) internal view returns (uint256) {
        uint256 received = _eReceivedAt(NativeEETH(eETH()).shares(address(this)), _eEthFromWeEth(wrappedAmount));
        return _eReceivedAt(0, received);
    }

    function _wrappedForEDeliveryUp(uint256 delivered) internal view returns (uint256 wrappedAmount) {
        uint256 transferable = _eInputForReceivedAt(0, delivered);
        uint256 unwrapNominal = _ePullInput(transferable);
        IWeETH wrapped = IWeETH(weETH());
        wrappedAmount = wrapped.getWeETHByeETH(unwrapNominal);
        if (wrapped.getEETHByWeETH(wrappedAmount) < unwrapNominal) ++wrappedAmount;
    }

    function _transferE(uint256 amount, address recipient) internal returns (uint256 delivered) {
        IERC20 native_ = IERC20(eETH());
        uint256 beforeBalance = native_.balanceOf(recipient);
        native_.safeTransfer(recipient, amount);
        delivered = native_.balanceOf(recipient) - beforeBalance;
    }

    function _unwrapAndPayE(uint256 wrappedAmount, address recipient) internal returns (uint256 delivered) {
        _requireLockedWe(wrappedAmount);
        IERC20 native_ = IERC20(eETH());
        uint256 beforeBalance = native_.balanceOf(address(this));
        IWeETH(weETH()).unwrap(wrappedAmount);
        delivered = _transferE(native_.balanceOf(address(this)) - beforeBalance, recipient);
    }

    /// @dev Deposit changes the global ratio when the minted native shares round
    /// down. Model that change before the next wrap or eETH transfer.
    function _quoteStakeOut(uint256 ethAmount, bool wrappedOutput) internal view returns (uint256) {
        NativeEETH native_ = NativeEETH(eETH());
        (uint256 pooled, uint256 supply) = _nativeShareRate();
        uint256 minted = supply == 0 ? ethAmount : Math.mulDiv(ethAmount, supply, pooled);
        uint256 held = native_.shares(address(this));
        uint256 beforeBalance = supply == 0 ? held : Math.mulDiv(held, pooled, supply);
        supply += minted;
        pooled += ethAmount;
        if (supply == 0) return 0;
        uint256 received = Math.mulDiv(held + minted, pooled, supply) - beforeBalance;
        uint256 transferredShares = Math.mulDiv(received, supply, pooled);
        return wrappedOutput ? transferredShares : Math.mulDiv(transferredShares, pooled, supply);
    }

    function _ethForStakeOut(uint256 output, bool wrappedOutput) internal view returns (uint256 amount) {
        if (output == 0) return 0;
        amount = wrappedOutput ? _eEthForWeEthUp(output) : output;
        if (_quoteStakeOut(amount, wrappedOutput) >= output) return amount;
        (uint256 pooled, uint256 supply) = _nativeShareRate();
        // Deposit cannot reduce the share rate. One pooled-unit rounding loss
        // costs at most ceil(supply / pooled) shares at the pre-deposit ratio.
        uint256 neededShares = wrappedOutput ? output : Math.mulDiv(output, supply, pooled, Math.Rounding.Ceil);
        neededShares += Math.ceilDiv(supply, pooled);
        return Math.mulDiv(neededShares, pooled, supply, Math.Rounding.Ceil);
    }

    function _convertEthDeltaToShares(uint256 ethDelta, uint256 totalEthBefore) internal view returns (uint256) {
        return BetterMath._convertToSharesDown(ethDelta, totalEthBefore, ERC20Repo._totalSupply(), _decimalOffset());
    }

    function _sharesForEthOut(uint256 ethOut) internal view returns (uint256) {
        return BetterMath._convertToSharesUp(ethOut, totalReserveEth(), ERC20Repo._totalSupply(), _decimalOffset());
    }

    function _previewRedeemSharesToEth(uint256 seShares) internal view returns (uint256 ethOut) {
        return BetterMath._convertToAssetsDown(seShares, totalReserveEth(), ERC20Repo._totalSupply(), _decimalOffset());
    }

    function _ethForSharesOut(uint256 seShares) internal view returns (uint256 ethIn) {
        return _ethForSharesOut(seShares, totalReserveEth());
    }

    function _ethForSharesOut(uint256 seShares, uint256 reserveBefore) internal view returns (uint256 ethIn) {
        return BetterMath._convertToAssetsUp(seShares, reserveBefore, ERC20Repo._totalSupply(), _decimalOffset());
    }

    /// @dev Remove only this route's authenticated local credit from live NAV. Bare
    /// underlying receipts (stETH/eETH) are not NAV until wrapped, so are not subtracted.
    /// Difference-of-valuations preserves the wrapped asset's native rounding.
    function _reserveBeforePretransfer(address token, uint256 credit) internal view returns (uint256 reserveBefore) {
        reserveBefore = totalReserveEth();
        if (credit == 0) return reserveBefore;
        if (token == weth()) return reserveBefore - credit;
        if (token == weETH()) {
            uint256 held = IERC20(token).balanceOf(address(this));
            return reserveBefore - (_assetToEth(token, held) - _assetToEth(token, held - credit));
        }
    }

    function _quoteMintAtReserve(address token, uint256 shares, uint256 reserveBefore) internal view returns (uint256) {
        return _ethToAssetUp(token, _ethForSharesOut(shares, reserveBefore));
    }

    function _targetLiquidEth() internal view returns (uint256) {
        uint256 total = totalReserveEth();
        uint256 pct = targetLiquidReservePercentage();
        return (total * pct) / ONE_WAD;
    }

    function _weEthFromEEth(uint256 eEthAmount) internal view returns (uint256) {
        return IWeETH(weETH()).getWeETHByeETH(eEthAmount);
    }

    function _eEthFromWeEth(uint256 weAmount) internal view returns (uint256) {
        return IWeETH(weETH()).getEETHByWeETH(weAmount);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Closed-form route quotes                        */
    /* ---------------------------------------------------------------------- */

    function _quoteExactIn(address tokenIn, uint256 amountIn, address tokenOut)
        internal
        view
        returns (uint256 amountOut)
    {
        if (tokenIn == tokenOut) revert InvalidRoute(tokenIn, tokenOut);
        if (tokenIn == address(0) || tokenOut == address(0)) revert InvalidRoute(tokenIn, tokenOut);

        // asset → SE mint: quote using post-credit eth value (eETH wrap double-floor matches exec)
        if (_isSeShare(tokenOut)) {
            if (!_isAsset(tokenIn)) revert InvalidRoute(tokenIn, tokenOut);
            if (tokenIn == eETH()) amountIn = _eReceivedAt(NativeEETH(eETH()).shares(address(this)), amountIn);
            uint256 ethValue = _creditEthValueOfAsset(tokenIn, amountIn);
            return _convertEthDeltaToShares(ethValue, totalReserveEth());
        }

        if (_isSeShare(tokenIn)) {
            if (!_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethOut = _previewRedeemSharesToEth(amountIn);
            if (tokenOut == eETH()) return _quoteUnwrapToE(_weEthFromEEth(ethOut));
            return _ethToAssetDown(tokenOut, ethOut);
        }

        if (!_isAsset(tokenIn) || !_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
        if (tokenIn == eETH()) amountIn = _eReceivedAt(NativeEETH(eETH()).shares(address(this)), amountIn);
        return _quoteAssetToAssetExactIn(tokenIn, amountIn, tokenOut);
    }

    /// @dev Public previews quote a nominal pull. Prepaid execution starts with already delivered credit.
    function _quoteExactOut(address tokenIn, address tokenOut, uint256 amountOut) internal view returns (uint256) {
        return _quoteExactOut(tokenIn, tokenOut, amountOut, false);
    }

    function _quoteExactOut(address tokenIn, address tokenOut, uint256 amountOut, bool pretransferred)
        internal
        view
        returns (uint256 amountIn)
    {
        if (tokenIn == tokenOut) revert InvalidRoute(tokenIn, tokenOut);
        if (tokenIn == address(0) || tokenOut == address(0)) revert InvalidRoute(tokenIn, tokenOut);

        // asset → SE mint (exact shares out): amountIn must cover ethNeeded after floor convert
        if (_isSeShare(tokenOut)) {
            if (!_isAsset(tokenIn)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethNeeded = _ethForSharesOut(amountOut);
            amountIn = _ethToAssetUp(tokenIn, ethNeeded);
            return tokenIn == eETH() && !pretransferred ? _ePullInput(amountIn) : amountIn;
        }

        // SE → asset redeem (exact asset out)
        if (_isSeShare(tokenIn)) {
            if (!_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethNeeded = tokenOut == eETH()
                ? _eEthFromWeEth(_wrappedForEDeliveryUp(amountOut))
                : _assetToEth(tokenOut, amountOut);
            return _sharesForEthOut(ethNeeded);
        }

        if (!_isAsset(tokenIn) || !_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
        amountIn = _quoteAssetToAssetExactOut(tokenIn, tokenOut, amountOut);
        return tokenIn == eETH() && !pretransferred ? _ePullInput(amountIn) : amountIn;
    }

    function _quoteAssetToAssetExactIn(address tokenIn, uint256 amountIn, address tokenOut)
        internal
        view
        returns (uint256 amountOut)
    {
        address weth_ = weth();
        address e_ = eETH();
        address we_ = weETH();

        if (tokenIn == e_ && tokenOut == we_) return IWeETH(we_).getWeETHByeETH(amountIn);
        if (tokenIn == we_ && tokenOut == e_) return _quoteUnwrapToE(amountIn);

        if (tokenIn == weth_ && tokenOut == e_) return _quoteStakeOut(amountIn, false);
        if (tokenIn == weth_ && tokenOut == we_) return _quoteStakeOut(amountIn, true);

        // Inventory eth-value swap; liquid checked only on exec
        if (tokenIn == e_ && tokenOut == weth_) return _creditEthValueOfAsset(e_, amountIn);
        if (tokenIn == we_ && tokenOut == weth_) return IWeETH(we_).getEETHByWeETH(amountIn);

        revert InvalidRoute(tokenIn, tokenOut);
    }

    function _quoteAssetToAssetExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        address weth_ = weth();
        address e_ = eETH();
        address we_ = weETH();

        // Ceil inputs so floor wrap/unwrap still meets amountOut on live rates.
        if (tokenIn == e_ && tokenOut == we_) return _eEthForWeEthUp(amountOut);
        if (tokenIn == we_ && tokenOut == e_) return _wrappedForEDeliveryUp(amountOut);

        if (tokenIn == weth_ && tokenOut == e_) return _ethForStakeOut(amountOut, false);
        // stake 1:1 then wrap: need eETH face that wraps to >= amountOut weETH
        if (tokenIn == weth_ && tokenOut == we_) return _ethForStakeOut(amountOut, true);

        if (tokenIn == e_ && tokenOut == weth_) return _ethToAssetUp(e_, amountOut);
        // inventory swap pays eth face of weETH in; need we such that eth face >= amountOut
        if (tokenIn == we_ && tokenOut == weth_) return _weEthForEEthUp(amountOut);

        revert InvalidRoute(tokenIn, tokenOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Execution helpers                               */
    /* ---------------------------------------------------------------------- */

    function _bookedReserve(IERC20 token) internal view returns (uint256) {
        return MultiAssetBasicVaultRepo._reserveOfToken(address(token));
    }

    function _pretransferCredit(IERC20 token, uint256 maximum) internal view returns (uint256) {
        return
            LocalCreditLib.budget(
                LocalCreditLib.available(token.balanceOf(address(this)), _bookedReserve(token)), maximum
            );
    }

    function _refundExactOutCredit(IERC20 token, uint256 credit, uint256 used, bool pretransferred) internal {
        if (!pretransferred) return;
        if (used > credit) revert ISecurePullErrors.TransferDeltaInsufficient(used, credit);
        if (credit > used) {
            uint256 unusedU = LocalCreditLib.available(token.balanceOf(address(this)), _bookedReserve(token));
            uint256 refund = credit - used;
            if (refund > unusedU) refund = unusedU;
            if (refund > 0) token.safeTransfer(msg.sender, refund);
        }
    }

    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
    }

    /// @dev D40/D30: four staticcalls. Non-32-byte or failed replies revert with returned bytes.
    function _staticcallWord(address target, bytes memory data) internal view returns (bytes memory result) {
        bool ok;
        (ok, result) = target.staticcall(data);
        if (!ok || result.length != 32) {
            assembly ("memory-safe") {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @dev Capacity is open unless paused, timed-paused, or this vault is blacklisted.
    function _etherFiStakeOpen() internal view returns (bool) {
        address pool = liquidityPool();
        if (abi.decode(_staticcallWord(pool, abi.encodeWithSignature("paused()")), (bool))) return false;
        if (abi.decode(_staticcallWord(pool, abi.encodeWithSignature("pausedUntil()")), (uint256)) >= block.timestamp) {
            return false;
        }
        address bl = abi.decode(_staticcallWord(pool, abi.encodeWithSignature("blacklister()")), (address));
        uint256 until_ = abi.decode(
            _staticcallWord(bl, abi.encodeWithSignature("blacklistedUntil(address)", address(this))), (uint256)
        );
        if (until_ > block.timestamp) return false;
        return true;
    }

    function _securePull(IERC20 token, uint256 amountIn, bool pretransferred) internal returns (uint256 actualIn) {
        if (pretransferred) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            uint256 avail = LocalCreditLib.available(token.balanceOf(address(this)), _bookedReserve(token));
            if (amountIn > avail) {
                revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, avail);
            }
            return amountIn;
        }
        if (address(token) == eETH()) return _pullNativeE(amountIn);
        uint256 before_ = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 delta = token.balanceOf(address(this)) - before_;
        if (delta != amountIn) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, delta);
        }
        return amountIn;
    }

    function _pullNativeE(uint256 amountIn) private returns (uint256 received) {
        NativeEETH native_ = NativeEETH(eETH());
        uint256 beforeShares = native_.shares(address(this));
        uint256 expectedShares = IEtherFiLiquidityPool(liquidityPool()).sharesForAmount(amountIn);
        uint256 expectedReceived = _eReceivedAt(beforeShares, amountIn);
        uint256 beforeBalance = native_.balanceOf(address(this));
        IERC20(address(native_)).safeTransferFrom(msg.sender, address(this), amountIn);
        received = native_.balanceOf(address(this)) - beforeBalance;
        if (native_.shares(address(this)) != beforeShares + expectedShares || received != expectedReceived) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, received);
        }
    }

    function _burnShares(uint256 shares) internal {
        ERC20Repo._burn(msg.sender, shares);
    }

    function _mintWithUsageFee(address recipient, uint256 userShares) internal {
        ERC20Repo._mint(recipient, userShares);
        uint256 feePct = VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this));
        if (feePct == 0) return;
        uint256 feeShares = BetterMath._percentageOfWAD(userShares, feePct);
        if (feeShares == 0) return;
        address feeTo_ = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (feeTo_ == address(0)) return;
        ERC20Repo._mint(feeTo_, feeShares);
    }

    /**
     * @dev Pay WETH via sleeve → optional instant redeem → InsufficientLiquidReserve.
     *      Never queues async withdraw on this path.
     */
    function _payWeth(uint256 amount, address recipient) internal {
        uint256 sleeve = liquidReserveEth();
        if (sleeve < amount) {
            _tryInstantRedeemForShortfall(amount - sleeve);
            sleeve = liquidReserveEth();
        }
        if (sleeve < amount) {
            revert InsufficientLiquidReserve(amount, sleeve);
        }
        IERC20(weth()).safeTransfer(recipient, amount);
    }

    /// @dev Best-effort redeem of vault weETH to cover shortfall; failures leave sleeve unchanged.
    ///      Grosses up for exit fee (up to ~5%) so net ETH after fee can satisfy shortfall.
    function _tryInstantRedeemForShortfall(uint256 shortfallEth) internal {
        address mgr = redemptionManager();
        if (mgr == address(0) || shortfallEth == 0) return;

        address we_ = weETH();
        // Gross up for exit fee + rate dust so net ETH can cover shortfall.
        uint256 grossEth = shortfallEth + (shortfallEth * 500) / 10_000; // +5% headroom
        if (grossEth <= shortfallEth) {
            grossEth = shortfallEth + 1;
        }
        uint256 weNeeded = IWeETH(we_).getWeETHByeETH(grossEth);
        if (weNeeded == 0) weNeeded = 1;
        uint256 weBal = IERC20(we_).balanceOf(address(this));
        if (weBal == 0) return;
        if (weNeeded > weBal) weNeeded = weBal;

        uint256 ethBefore = address(this).balance;
        IERC20(we_).forceApprove(mgr, weNeeded);
        IEtherFiRedemptionManager(mgr).redeemWeEth(weNeeded, address(this), ETH_SENTINEL);
        uint256 ethGot = address(this).balance - ethBefore;
        if (ethGot > 0) {
            IWETH(payable(weth())).deposit{value: ethGot}();
        }
    }

    /// @dev Pay weETH or eETH from locked inventory.
    function _payYield(address token, uint256 amount, address recipient) internal returns (uint256 delivered) {
        if (token == weETH()) {
            _requireLockedWe(amount);
            IERC20(weETH()).safeTransfer(recipient, amount);
            return amount;
        }
        if (token == eETH()) {
            delivered = _unwrapAndPayE(_wrappedForEDeliveryUp(amount), recipient);
            if (delivered < amount) revert Slippage();
            return delivered;
        }
        revert InvalidRoute(address(0), token);
    }

    function _payAsset(address token, uint256 amount, address recipient) internal returns (uint256) {
        if (token == weth()) {
            _payWeth(amount, recipient);
            return amount;
        }
        return _payYield(token, amount, recipient);
    }

    function _execAssetToAsset(address tokenIn, uint256 amountIn, address tokenOut, address recipient)
        internal
        returns (uint256 produced)
    {
        address weth_ = weth();
        address e_ = eETH();
        address we_ = weETH();

        // eETH → weETH wrap
        if (tokenIn == e_ && tokenOut == we_) {
            IERC20(e_).forceApprove(we_, amountIn);
            produced = IWeETH(we_).wrap(amountIn);
            IERC20(we_).safeTransfer(recipient, produced);
            return produced;
        }

        // weETH → eETH unwrap
        if (tokenIn == we_ && tokenOut == e_) {
            return _unwrapAndPayE(amountIn, recipient);
        }

        // WETH → eETH (stake)
        if (tokenIn == weth_ && tokenOut == e_) {
            return _transferE(_stakeWethToEEth(amountIn), recipient);
        }

        // WETH → weETH (stake + wrap)
        if (tokenIn == weth_ && tokenOut == we_) {
            produced = _stakeWethToWeEth(amountIn);
            IERC20(we_).safeTransfer(recipient, produced);
            return produced;
        }

        // eETH → WETH: keep e as locked (wrap) and pay liquid via ladder
        if (tokenIn == e_ && tokenOut == weth_) {
            IERC20(e_).forceApprove(we_, amountIn);
            produced = _eEthFromWeEth(IWeETH(we_).wrap(amountIn));
            _payWeth(produced, recipient);
            return produced;
        }

        // weETH → WETH: keep we locked and pay liquid via ladder
        if (tokenIn == we_ && tokenOut == weth_) {
            produced = IWeETH(we_).getEETHByWeETH(amountIn);
            _payWeth(produced, recipient);
            return produced;
        }

        revert InvalidRoute(tokenIn, tokenOut);
    }

    function _stakeWethToEEth(uint256 wethAmount) internal returns (uint256 eOut) {
        address weth_ = weth();
        address e_ = eETH();
        address pool = liquidityPool();
        uint256 eBefore = IERC20(e_).balanceOf(address(this));
        IWETH(payable(weth_)).withdraw(wethAmount);
        IEtherFiLiquidityPool(pool).deposit{value: wethAmount}();
        eOut = IERC20(e_).balanceOf(address(this)) - eBefore;
        if (eOut == 0) revert Slippage();
    }

    function _stakeWethToWeEth(uint256 wethAmount) internal returns (uint256 weOut) {
        if (wethAmount == 0) return 0;
        uint256 eGot = _stakeWethToEEth(wethAmount);
        address we_ = weETH();
        address e_ = eETH();
        IERC20(e_).forceApprove(we_, eGot);
        weOut = IWeETH(we_).wrap(eGot);
        if (weOut == 0) revert Slippage();
    }

    /**
     * @dev After pull, normalize deposit into vault inventory and return eth-value credited.
     *      WETH stays liquid; eETH is wrapped to weETH; weETH stays locked.
     */
    function _creditAssetToReserve(address tokenIn, uint256 actualIn) internal returns (uint256 ethValue) {
        if (tokenIn == weth()) {
            return actualIn;
        }
        if (tokenIn == eETH()) {
            IERC20(eETH()).forceApprove(weETH(), actualIn);
            uint256 weOut = IWeETH(weETH()).wrap(actualIn);
            return _eEthFromWeEth(weOut);
        }
        if (tokenIn == weETH()) {
            return _eEthFromWeEth(actualIn);
        }
        revert InvalidRoute(tokenIn, address(this));
    }

    /**
     * @dev D12b/D12c: after WETH→SE mint, leave sleeve at target liquid %; stake overage same tx.
     *      Never queues on mint path.
     */
    function _splitWethSleeveAfterSeMint() internal {
        if (!_etherFiStakeOpen()) return;
        uint256 liquid = liquidReserveEth();
        if (liquid == 0) return;
        uint256 pct = targetLiquidReservePercentage();
        uint256 target = (totalReserveEth() * pct) / ONE_WAD;
        if (liquid <= target) return;
        uint256 eligible = liquid - target;
        uint256 booked = _bookedReserve(IERC20(weth()));
        uint256 fromBooked = eligible < booked ? eligible : booked;
        if (fromBooked > 0) {
            _stakeWethToWeEth(fromBooked);
        }
        liquid = liquidReserveEth();
        target = (totalReserveEth() * pct) / ONE_WAD;
        if (liquid <= target) return;
        _stakeWethToWeEth(liquid - target);
    }
}
