// SPDX-License-Identifier: BUSL-1.1
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
import {IEETH} from "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IEETH.sol";
import {IEtherFiLiquidityPool} from
    "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IEtherFiLiquidityPool.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {
    IEtherFiWeETHStandardVault
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {
    IEtherFiRedemptionManager
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiRedemptionManager.sol";
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
    uint256 internal constant REBALANCE_BAND_WAD = 0.10e18;
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
        try IEtherFiLiquidityPool(pool).sharesForWithdrawalAmount(eOut) returns (uint256 we) {
            // Guard: if view under-delivers vs floor round-trip, bump.
            if (we == 0) we = 1;
            while (IWeETH(weETH()).getEETHByWeETH(we) < eOut) {
                unchecked {
                    ++we;
                }
            }
            return we;
        } catch {
            uint256 we = IWeETH(weETH()).getWeETHByeETH(eOut);
            if (we == 0) we = 1;
            while (IWeETH(weETH()).getEETHByWeETH(we) < eOut) {
                unchecked {
                    ++we;
                }
            }
            return we;
        }
    }

    /**
     * @dev Minimum eETH such that sharesForAmount(e) / wrap(e) >= weOut (ceil).
     *      Closed form: ceil(weOut * totalPooledEther / totalShares).
     */
    function _eEthForWeEthUp(uint256 weOut) internal view returns (uint256) {
        if (weOut == 0) return 0;
        address pool = liquidityPool();
        uint256 totalPooled = IEtherFiLiquidityPool(pool).getTotalPooledEther();
        uint256 totalShares = IEETH(eETH()).getTotalShares();
        if (totalShares == 0 || totalPooled == 0) {
            // Bootstrap / hermetic empty pool: treat 1:1 then correct via round-trip.
            uint256 e = weOut;
            while (IWeETH(weETH()).getWeETHByeETH(e) < weOut) {
                unchecked {
                    ++e;
                }
            }
            return e;
        }
        uint256 eIn = BetterMath._mulDiv(weOut, totalPooled, totalShares, Math.Rounding.Ceil);
        // Guard against interface/rate drift.
        if (eIn == 0) eIn = 1;
        while (IWeETH(weETH()).getWeETHByeETH(eIn) < weOut) {
            unchecked {
                ++eIn;
            }
        }
        return eIn;
    }

    function _convertEthDeltaToShares(uint256 ethDelta, uint256 totalEthBefore) internal view returns (uint256) {
        return BetterMath._convertToSharesDown(
            ethDelta, totalEthBefore, ERC20Repo._totalSupply(), _decimalOffset()
        );
    }

    function _sharesForEthOut(uint256 ethOut) internal view returns (uint256) {
        return BetterMath._convertToSharesUp(
            ethOut, totalReserveEth(), ERC20Repo._totalSupply(), _decimalOffset()
        );
    }

    function _previewRedeemSharesToEth(uint256 seShares) internal view returns (uint256 ethOut) {
        return BetterMath._convertToAssetsDown(
            seShares, totalReserveEth(), ERC20Repo._totalSupply(), _decimalOffset()
        );
    }

    function _ethForSharesOut(uint256 seShares) internal view returns (uint256 ethIn) {
        return BetterMath._convertToAssetsUp(
            seShares, totalReserveEth(), ERC20Repo._totalSupply(), _decimalOffset()
        );
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
            uint256 ethValue = _creditEthValueOfAsset(tokenIn, amountIn);
            return _convertEthDeltaToShares(ethValue, totalReserveEth());
        }

        if (_isSeShare(tokenIn)) {
            if (!_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethOut = _previewRedeemSharesToEth(amountIn);
            return _ethToAssetDown(tokenOut, ethOut);
        }

        if (!_isAsset(tokenIn) || !_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
        return _quoteAssetToAssetExactIn(tokenIn, amountIn, tokenOut);
    }

    function _quoteExactOut(address tokenIn, address tokenOut, uint256 amountOut)
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
            return _ethToAssetUp(tokenIn, ethNeeded);
        }

        // SE → asset redeem (exact asset out)
        if (_isSeShare(tokenIn)) {
            if (!_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethNeeded = _assetToEth(tokenOut, amountOut);
            return _sharesForEthOut(ethNeeded);
        }

        if (!_isAsset(tokenIn) || !_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
        return _quoteAssetToAssetExactOut(tokenIn, tokenOut, amountOut);
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
        if (tokenIn == we_ && tokenOut == e_) return IWeETH(we_).getEETHByWeETH(amountIn);

        if (tokenIn == weth_ && tokenOut == e_) return amountIn;
        if (tokenIn == weth_ && tokenOut == we_) return IWeETH(we_).getWeETHByeETH(amountIn);

        // Inventory eth-value swap; liquid checked only on exec
        if (tokenIn == e_ && tokenOut == weth_) return amountIn;
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
        if (tokenIn == we_ && tokenOut == e_) return _weEthForEEthUp(amountOut);

        if (tokenIn == weth_ && tokenOut == e_) return amountOut;
        // stake 1:1 then wrap: need eETH face that wraps to >= amountOut weETH
        if (tokenIn == weth_ && tokenOut == we_) return _eEthForWeEthUp(amountOut);

        if (tokenIn == e_ && tokenOut == weth_) return amountOut;
        // inventory swap pays eth face of weETH in; need we such that eth face >= amountOut
        if (tokenIn == we_ && tokenOut == weth_) return _weEthForEEthUp(amountOut);

        revert InvalidRoute(tokenIn, tokenOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Execution helpers                               */
    /* ---------------------------------------------------------------------- */

    function _securePull(IERC20 token, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        uint256 before_ = token.balanceOf(address(this));
        if (!pretransferred) {
            token.safeTransferFrom(msg.sender, address(this), amountIn);
        }
        actualIn = token.balanceOf(address(this)) - before_;
        if (actualIn > amountIn) {
            actualIn = amountIn;
        }
        if (actualIn == 0) {
            revert InsufficientDeposit(amountIn, 0);
        }
        if (pretransferred && actualIn < amountIn) {
            revert InsufficientDeposit(amountIn, actualIn);
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

        // canRedeem takes eETH/ETH face units corresponding to weETH inventory redeemed.
        uint256 eFace = IWeETH(we_).getEETHByWeETH(weNeeded);
        try IEtherFiRedemptionManager(mgr).canRedeem(eFace, ETH_SENTINEL) returns (bool ok) {
            if (!ok) {
                // Retry with bare shortfall if gross exceeds capacity.
                eFace = IWeETH(we_).getEETHByWeETH(IWeETH(we_).getWeETHByeETH(shortfallEth));
                weNeeded = IWeETH(we_).getWeETHByeETH(shortfallEth);
                if (weNeeded > weBal) weNeeded = weBal;
                eFace = IWeETH(we_).getEETHByWeETH(weNeeded);
                try IEtherFiRedemptionManager(mgr).canRedeem(eFace, ETH_SENTINEL) returns (bool ok2) {
                    if (!ok2) return;
                } catch {}
            }
        } catch {
            // Manager without canRedeem or view fail: attempt redeem and catch below.
        }

        uint256 ethBefore = address(this).balance;
        IERC20(we_).forceApprove(mgr, weNeeded);
        try IEtherFiRedemptionManager(mgr).redeemWeEth(weNeeded, address(this), ETH_SENTINEL) {
            uint256 ethGot = address(this).balance - ethBefore;
            if (ethGot > 0) {
                IWETH(payable(weth())).deposit{value: ethGot}();
            }
        } catch {
            // Capacity/pause/blacklist: fall through to InsufficientLiquidReserve on transfer check.
            IERC20(we_).forceApprove(mgr, 0);
        }
    }

    /// @dev Pay weETH or eETH from locked inventory.
    function _payYield(address token, uint256 amount, address recipient) internal {
        address e_ = eETH();
        address we_ = weETH();

        if (token == we_) {
            _requireLockedWe(amount);
            IERC20(we_).safeTransfer(recipient, amount);
            return;
        }
        if (token == e_) {
            // Ceil weETH so floor unwrap still yields >= amount eETH on live rates.
            uint256 weNeeded = _weEthForEEthUp(amount);
            _requireLockedWe(weNeeded);
            uint256 eOut = IWeETH(we_).unwrap(weNeeded);
            if (eOut < amount) revert Slippage();
            IERC20(e_).safeTransfer(recipient, amount);
            // Dust eETH from ceil stays in vault inventory (will be re-wrapped on credit paths).
            return;
        }
        revert InvalidRoute(address(0), token);
    }

    function _payAsset(address token, uint256 amount, address recipient) internal {
        if (token == weth()) {
            _payWeth(amount, recipient);
            return;
        }
        _payYield(token, amount, recipient);
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
            produced = IWeETH(we_).unwrap(amountIn);
            IERC20(e_).safeTransfer(recipient, produced);
            return produced;
        }

        // WETH → eETH (stake)
        if (tokenIn == weth_ && tokenOut == e_) {
            produced = _stakeWethToEEth(amountIn);
            IERC20(e_).safeTransfer(recipient, produced);
            return produced;
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
            IWeETH(we_).wrap(amountIn);
            produced = amountIn;
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
        uint256 liquid = liquidReserveEth();
        if (liquid == 0) return;

        uint256 total = totalReserveEth();
        uint256 pct = targetLiquidReservePercentage();
        uint256 target = (total * pct) / ONE_WAD;

        if (liquid > target) {
            _stakeWethToWeEth(liquid - target);
        }

        // D12c: if still above band, stake further excess
        liquid = liquidReserveEth();
        total = totalReserveEth();
        target = (total * pct) / ONE_WAD;
        uint256 band = (target * REBALANCE_BAND_WAD) / ONE_WAD;
        if (liquid > target + band) {
            _stakeWethToWeEth(liquid - target);
        }
    }
}
