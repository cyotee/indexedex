// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IWstETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IWstETH.sol";
import {IStETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IStETH.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {ILidoWstETHStandardVault} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {LidoWstETHStandardExchangeRepo} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeRepo.sol";

/**
 * @title LidoWstETHStandardExchangeCommon
 * @notice Shared NAV, inventory checks, and closed-form route quotes for Lido SE.
 * @dev Share math uses BetterMath virtual offset (ERC-4626-style) to resist donation inflation.
 *      Previews never gate on liquid sleeve; execution does when paying WETH.
 */
abstract contract LidoWstETHStandardExchangeCommon is ILidoWstETHStandardVault, IStandardExchangeErrors {
    using BetterMath for uint256;
    using SafeERC20 for IERC20;

    uint256 internal constant MIN_STETH_WITHDRAWAL = 100;
    uint256 internal constant MAX_STETH_WITHDRAWAL = 1000 ether;
    /// @dev Rebalance hysteresis: 10% of target liquid (band on target).
    uint256 internal constant REBALANCE_BAND_WAD = 0.10e18;
    uint256 internal constant MAX_QUEUE_REQUESTS_PER_REBALANCE = 5;

    /// @notice Deposit tokens received less than requested (or zero when pretransferred without credit).
    error InsufficientDeposit(uint256 requested, uint256 actual);

    function wstETH() public view virtual override returns (address) {
        return LidoWstETHStandardExchangeRepo._wstETH();
    }

    function stETH() public view virtual override returns (address) {
        return LidoWstETHStandardExchangeRepo._stETH();
    }

    function weth() public view virtual override returns (address) {
        return LidoWstETHStandardExchangeRepo._weth();
    }

    function withdrawalQueue() public view virtual override returns (address) {
        return LidoWstETHStandardExchangeRepo._withdrawalQueue();
    }

    function liquidReserveEth() public view virtual override returns (uint256) {
        return IERC20(weth()).balanceOf(address(this));
    }

    function lockedReserveEth() public view virtual override returns (uint256) {
        uint256 wstBal = IERC20(wstETH()).balanceOf(address(this));
        uint256 wstAsEth = IWstETH(wstETH()).getStETHByWstETH(wstBal);
        return wstAsEth + LidoWstETHStandardExchangeRepo._pendingFaceStEthTotal();
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

    function _requireLiquidWeth(uint256 requested) internal view {
        uint256 available = liquidReserveEth();
        if (available < requested) {
            revert InsufficientLiquidReserve(requested, available);
        }
    }

    function _requireLockedWst(uint256 wstRequested) internal view {
        uint256 available = IERC20(wstETH()).balanceOf(address(this));
        if (available < wstRequested) {
            revert InsufficientLockedReserve(wstRequested, available);
        }
    }

    function _decimalOffset() internal view returns (uint8) {
        return ERC4626Repo._decimalOffset();
    }

    function _isSeShare(address token) internal view returns (bool) {
        return token == address(this);
    }

    function _isAsset(address token) internal view returns (bool) {
        return token == weth() || token == stETH() || token == wstETH();
    }

    /// @dev ETH-value of an underlying asset amount (not SE shares).
    function _assetToEth(address token, uint256 amount) internal view returns (uint256) {
        if (token == weth() || token == stETH()) return amount;
        if (token == wstETH()) return IWstETH(wstETH()).getStETHByWstETH(amount);
        revert InvalidRoute(token, token);
    }

    /// @dev Asset amount for an ETH-value (floor). WETH/stETH 1:1; wstETH via Lido rate.
    function _ethToAssetDown(address token, uint256 ethValue) internal view returns (uint256) {
        if (token == weth() || token == stETH()) return ethValue;
        if (token == wstETH()) return IWstETH(wstETH()).getWstETHByStETH(ethValue);
        revert InvalidRoute(token, token);
    }

    /// @dev Convert eth-value delta into SE shares given totalReserveEth *before* the deposit.
    function _convertEthDeltaToShares(uint256 ethDelta, uint256 totalEthBefore) internal view returns (uint256) {
        return BetterMath._convertToSharesDown(
            ethDelta, totalEthBefore, ERC20Repo._totalSupply(), _decimalOffset()
        );
    }

    /// @dev Shares required to withdraw `ethOut` of reserve value (ceil / previewWithdraw).
    function _sharesForEthOut(uint256 ethOut) internal view returns (uint256) {
        return BetterMath._convertToSharesUp(
            ethOut, totalReserveEth(), ERC20Repo._totalSupply(), _decimalOffset()
        );
    }

    /// @dev ETH value redeemed for SE shares (floor / previewRedeem).
    function _previewRedeemSharesToEth(uint256 seShares) internal view returns (uint256 ethOut) {
        return BetterMath._convertToAssetsDown(
            seShares, totalReserveEth(), ERC20Repo._totalSupply(), _decimalOffset()
        );
    }

    /// @dev ETH value required to mint `seShares` (ceil / previewMint). Reserve is pre-deposit.
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

    function _wstEthFromStEth(uint256 stEthAmount) internal view returns (uint256) {
        return IWstETH(wstETH()).getWstETHByStETH(stEthAmount);
    }

    function _stEthFromWstEth(uint256 wstAmount) internal view returns (uint256) {
        return IWstETH(wstETH()).getStETHByWstETH(wstAmount);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Closed-form route quotes                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Exact-in quote: amountOut for fixed amountIn. No liquid-sleeve gate.
     * @dev Supported: assets↔SE, SE↔assets, WETH↔stETH/wstETH, stETH↔wstETH (all 1:1 eth terms / Lido rates).
     */
    function _quoteExactIn(address tokenIn, uint256 amountIn, address tokenOut)
        internal
        view
        returns (uint256 amountOut)
    {
        if (tokenIn == tokenOut) revert InvalidRoute(tokenIn, tokenOut);

        // asset → SE mint
        if (_isSeShare(tokenOut)) {
            if (!_isAsset(tokenIn)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethValue = _assetToEth(tokenIn, amountIn);
            return _convertEthDeltaToShares(ethValue, totalReserveEth());
        }

        // SE → asset redeem
        if (_isSeShare(tokenIn)) {
            if (!_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethOut = _previewRedeemSharesToEth(amountIn);
            return _ethToAssetDown(tokenOut, ethOut);
        }

        // asset → asset (wrap / stake / inventory eth-value swap)
        if (!_isAsset(tokenIn) || !_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
        return _quoteAssetToAssetExactIn(tokenIn, amountIn, tokenOut);
    }

    /**
     * @notice Exact-out quote: amountIn for fixed amountOut. No liquid-sleeve gate.
     */
    function _quoteExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        if (tokenIn == tokenOut) revert InvalidRoute(tokenIn, tokenOut);

        // asset → SE mint (exact shares out)
        if (_isSeShare(tokenOut)) {
            if (!_isAsset(tokenIn)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethNeeded = _ethForSharesOut(amountOut);
            return _ethToAssetDown(tokenIn, ethNeeded);
        }

        // SE → asset redeem (exact asset out)
        if (_isSeShare(tokenIn)) {
            if (!_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethNeeded = _assetToEth(tokenOut, amountOut);
            return _sharesForEthOut(ethNeeded);
        }

        // asset → asset
        if (!_isAsset(tokenIn) || !_isAsset(tokenOut)) revert InvalidRoute(tokenIn, tokenOut);
        return _quoteAssetToAssetExactOut(tokenIn, tokenOut, amountOut);
    }

    function _quoteAssetToAssetExactIn(address tokenIn, uint256 amountIn, address tokenOut)
        internal
        view
        returns (uint256 amountOut)
    {
        address weth_ = weth();
        address st_ = stETH();
        address wst_ = wstETH();

        // stETH ↔ wstETH (Lido wrap/unwrap)
        if (tokenIn == st_ && tokenOut == wst_) return IWstETH(wst_).getWstETHByStETH(amountIn);
        if (tokenIn == wst_ && tokenOut == st_) return IWstETH(wst_).getStETHByWstETH(amountIn);

        // WETH → stETH / wstETH (stake path preview: 1:1 eth then Lido wrap rate)
        if (tokenIn == weth_ && tokenOut == st_) return amountIn;
        if (tokenIn == weth_ && tokenOut == wst_) return IWstETH(wst_).getWstETHByStETH(amountIn);

        // stETH / wstETH → WETH (inventory eth-value swap; liquid checked only on exec)
        if (tokenIn == st_ && tokenOut == weth_) return amountIn;
        if (tokenIn == wst_ && tokenOut == weth_) return IWstETH(wst_).getStETHByWstETH(amountIn);

        revert InvalidRoute(tokenIn, tokenOut);
    }

    function _quoteAssetToAssetExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        address weth_ = weth();
        address st_ = stETH();
        address wst_ = wstETH();

        if (tokenIn == st_ && tokenOut == wst_) {
            // need stETH in such that wrap yields amountOut wst
            return IWstETH(wst_).getStETHByWstETH(amountOut);
        }
        if (tokenIn == wst_ && tokenOut == st_) {
            return IWstETH(wst_).getWstETHByStETH(amountOut);
        }

        if (tokenIn == weth_ && tokenOut == st_) return amountOut;
        if (tokenIn == weth_ && tokenOut == wst_) {
            return IWstETH(wst_).getStETHByWstETH(amountOut);
        }

        if (tokenIn == st_ && tokenOut == weth_) return amountOut;
        if (tokenIn == wst_ && tokenOut == weth_) {
            return IWstETH(wst_).getWstETHByStETH(amountOut);
        }

        revert InvalidRoute(tokenIn, tokenOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Execution helpers                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Securely obtain `amountIn` of `token` for this call.
     *      - !pretransferred: transferFrom and use balance delta (fee-on-transfer safe).
     *      - pretransferred: require a positive balance delta in this call.
     */
    function _securePull(IERC20 token, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        uint256 before = token.balanceOf(address(this));
        if (!pretransferred) {
            token.safeTransferFrom(msg.sender, address(this), amountIn);
        }
        actualIn = token.balanceOf(address(this)) - before;
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

    /// @dev Burn SE shares from msg.sender (exact-in / exact-out redeem).
    function _burnShares(uint256 shares) internal {
        ERC20Repo._burn(msg.sender, shares);
    }

    /// @dev Mint user shares; mint usage-fee shares to feeTo (inflation style).
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

    /// @dev Pay `amount` of asset to recipient from vault inventory (WETH liquid / wst unlock).
    function _payAsset(address token, uint256 amount, address recipient) internal {
        address weth_ = weth();
        address st_ = stETH();
        address wst_ = wstETH();

        if (token == weth_) {
            _requireLiquidWeth(amount);
            IERC20(weth_).safeTransfer(recipient, amount);
            return;
        }
        if (token == wst_) {
            _requireLockedWst(amount);
            IERC20(wst_).safeTransfer(recipient, amount);
            return;
        }
        if (token == st_) {
            // Unlock via wstETH unwrap
            uint256 wstNeeded = IWstETH(wst_).getWstETHByStETH(amount);
            _requireLockedWst(wstNeeded);
            uint256 stOut = IWstETH(wst_).unwrap(wstNeeded);
            if (stOut < amount) revert Slippage();
            IERC20(st_).safeTransfer(recipient, stOut);
            return;
        }
        revert InvalidRoute(address(0), token);
    }

    /**
     * @dev Convert pulled assetIn fully into vault inventory form for eth-value swaps that pay WETH,
     *      or stake WETH into stETH/wstETH for outbound stake routes.
     * @return produced Amount of tokenOut produced (for stake/wrap paths) or eth paid (WETH out).
     */
    function _execAssetToAsset(address tokenIn, uint256 amountIn, address tokenOut, address recipient)
        internal
        returns (uint256 produced)
    {
        address weth_ = weth();
        address st_ = stETH();
        address wst_ = wstETH();

        // stETH → wstETH wrap
        if (tokenIn == st_ && tokenOut == wst_) {
            IERC20(st_).forceApprove(wst_, amountIn);
            produced = IWstETH(wst_).wrap(amountIn);
            IERC20(wst_).safeTransfer(recipient, produced);
            return produced;
        }

        // wstETH → stETH unwrap
        if (tokenIn == wst_ && tokenOut == st_) {
            produced = IWstETH(wst_).unwrap(amountIn);
            IERC20(st_).safeTransfer(recipient, produced);
            return produced;
        }

        // WETH → stETH (stake)
        if (tokenIn == weth_ && tokenOut == st_) {
            produced = _stakeWethToStEth(amountIn);
            IERC20(st_).safeTransfer(recipient, produced);
            return produced;
        }

        // WETH → wstETH (stake + wrap)
        if (tokenIn == weth_ && tokenOut == wst_) {
            uint256 stGot = _stakeWethToStEth(amountIn);
            IERC20(st_).forceApprove(wst_, stGot);
            produced = IWstETH(wst_).wrap(stGot);
            IERC20(wst_).safeTransfer(recipient, produced);
            return produced;
        }

        // stETH → WETH: keep st as locked (wrap) and pay liquid
        if (tokenIn == st_ && tokenOut == weth_) {
            IERC20(st_).forceApprove(wst_, amountIn);
            IWstETH(wst_).wrap(amountIn);
            produced = amountIn; // eth face
            _requireLiquidWeth(produced);
            IERC20(weth_).safeTransfer(recipient, produced);
            return produced;
        }

        // wstETH → WETH: keep wst locked and pay liquid
        if (tokenIn == wst_ && tokenOut == weth_) {
            produced = IWstETH(wst_).getStETHByWstETH(amountIn);
            _requireLiquidWeth(produced);
            IERC20(weth_).safeTransfer(recipient, produced);
            return produced;
        }

        revert InvalidRoute(tokenIn, tokenOut);
    }

    function _stakeWethToStEth(uint256 wethAmount) internal returns (uint256 stOut) {
        address weth_ = weth();
        address st_ = stETH();
        uint256 stBefore = IERC20(st_).balanceOf(address(this));
        IWETH(payable(weth_)).withdraw(wethAmount);
        IStETH(st_).submit{value: wethAmount}(address(0));
        stOut = IERC20(st_).balanceOf(address(this)) - stBefore;
        if (stOut == 0) revert Slippage();
    }

    /**
     * @dev After pull, normalize deposit into vault inventory and return eth-value credited.
     *      WETH stays liquid; stETH is wrapped to wstETH; wstETH stays locked.
     */
    function _creditAssetToReserve(address tokenIn, uint256 actualIn) internal returns (uint256 ethValue) {
        if (tokenIn == weth()) {
            return actualIn;
        }
        if (tokenIn == stETH()) {
            IERC20(stETH()).forceApprove(wstETH(), actualIn);
            uint256 wstOut = IWstETH(wstETH()).wrap(actualIn);
            return _stEthFromWstEth(wstOut);
        }
        if (tokenIn == wstETH()) {
            return _stEthFromWstEth(actualIn);
        }
        revert InvalidRoute(tokenIn, address(this));
    }
}
