// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IRETH} from "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRETH.sol";
import {IRocketDepositPool} from
    "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRocketDepositPool.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {
    IRocketPoolRETHStandardVault
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";
import {
    RocketPoolRETHStandardExchangeRepo
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeRepo.sol";

/**
 * @title RocketPoolRETHStandardExchangeCommon
 * @notice Shared NAV, dual-surface quotes, soft buffer stake, burn pay ladder.
 * @dev Previews never gate on sleeve / deposit capacity / burn collateral.
 *      Soft stake on WETH→SE (capacity-capped); hard stake on WETH→rETH.
 */
abstract contract RocketPoolRETHStandardExchangeCommon is
    IRocketPoolRETHStandardVault,
    IStandardExchangeErrors
{
    using BetterMath for uint256;
    using SafeERC20 for IERC20;

    /// @dev Rebalance hysteresis: 10% of target liquid.
    uint256 internal constant REBALANCE_BAND_WAD = 0.10e18;

    function rETH() public view virtual override returns (address) {
        return RocketPoolRETHStandardExchangeRepo._rETH();
    }

    function weth() public view virtual override returns (address) {
        return RocketPoolRETHStandardExchangeRepo._weth();
    }

    function depositPool() public view virtual override returns (address) {
        return RocketPoolRETHStandardExchangeRepo._depositPool();
    }

    function liquidReserveEth() public view virtual override returns (uint256) {
        return IERC20(weth()).balanceOf(address(this));
    }

    function lockedReserveEth() public view virtual override returns (uint256) {
        address reth_ = rETH();
        uint256 bal = IERC20(reth_).balanceOf(address(this));
        return IRETH(reth_).getEthValue(bal);
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

    function _decimalOffset() internal view returns (uint8) {
        return ERC4626Repo._decimalOffset();
    }

    function _isSeShare(address token) internal view returns (bool) {
        return token == address(this);
    }

    function _isAsset(address token) internal view returns (bool) {
        return token == weth() || token == rETH();
    }

    function _requireLockedReth(uint256 rethRequested) internal view {
        uint256 available = IERC20(rETH()).balanceOf(address(this));
        if (available < rethRequested) {
            revert InsufficientLockedReserve(rethRequested, available);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                              Rate helpers                               */
    /* ---------------------------------------------------------------------- */

    function _assetToEth(address token, uint256 amount) internal view returns (uint256) {
        if (token == weth()) return amount;
        if (token == rETH()) return IRETH(rETH()).getEthValue(amount);
        revert InvalidRoute(token, token);
    }

    function _creditEthValueOfAsset(address token, uint256 amount) internal view returns (uint256) {
        return _assetToEth(token, amount);
    }

    function _ethToAssetDown(address token, uint256 ethValue) internal view returns (uint256) {
        if (token == weth()) return ethValue;
        if (token == rETH()) return IRETH(rETH()).getRethValue(ethValue);
        revert InvalidRoute(token, token);
    }

    /// @dev Minimum rETH such that getEthValue(reth) >= ethOut (ceil).
    function _rethForEthUp(uint256 ethOut) internal view returns (uint256) {
        if (ethOut == 0) return 0;
        address reth_ = rETH();
        uint256 reth = IRETH(reth_).getRethValue(ethOut);
        if (reth == 0) reth = 1;
        while (IRETH(reth_).getEthValue(reth) < ethOut) {
            unchecked {
                ++reth;
            }
        }
        return reth;
    }

    function _ethToAssetUp(address token, uint256 ethValue) internal view returns (uint256) {
        if (token == weth()) return ethValue;
        if (token == rETH()) return _rethForEthUp(ethValue);
        revert InvalidRoute(token, token);
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

    function _maxDepositAmount() internal view returns (uint256) {
        address pool = depositPool();
        if (pool == address(0)) return 0;
        try IRocketDepositPool(pool).getMaximumDepositAmount() returns (uint256 maxDep) {
            return maxDep;
        } catch {
            return 0;
        }
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

        if (_isSeShare(tokenOut)) {
            if (!_isAsset(tokenIn)) revert InvalidRoute(tokenIn, tokenOut);
            uint256 ethNeeded = _ethForSharesOut(amountOut);
            return _ethToAssetUp(tokenIn, ethNeeded);
        }

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
        address reth_ = rETH();

        // WETH → rETH: rate (ungated); fee dust enforced via minOut on exec
        if (tokenIn == weth_ && tokenOut == reth_) {
            return IRETH(reth_).getRethValue(amountIn);
        }
        // rETH → WETH: inventory eth face
        if (tokenIn == reth_ && tokenOut == weth_) {
            return IRETH(reth_).getEthValue(amountIn);
        }
        revert InvalidRoute(tokenIn, tokenOut);
    }

    function _quoteAssetToAssetExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        address weth_ = weth();
        address reth_ = rETH();

        // Need WETH such that getRethValue(weth) >= amountOut rETH
        if (tokenIn == weth_ && tokenOut == reth_) {
            // eth face for amountOut rETH (ceil via loop)
            uint256 eth = IRETH(reth_).getEthValue(amountOut);
            if (eth == 0) eth = 1;
            while (IRETH(reth_).getRethValue(eth) < amountOut) {
                unchecked {
                    ++eth;
                }
            }
            return eth;
        }
        // Need rETH such that eth face >= amountOut WETH
        if (tokenIn == reth_ && tokenOut == weth_) {
            return _rethForEthUp(amountOut);
        }
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
     * @dev Pay WETH via sleeve → optional rETH.burn → InsufficientLiquidReserve.
     *      Never invents an async exit queue.
     */
    function _payWeth(uint256 amount, address recipient) internal {
        uint256 sleeve = liquidReserveEth();
        if (sleeve < amount) {
            _tryBurnRethForWeth(amount - sleeve);
            sleeve = liquidReserveEth();
        }
        if (sleeve < amount) {
            revert InsufficientLiquidReserve(amount, sleeve);
        }
        IERC20(weth()).safeTransfer(recipient, amount);
    }

    /// @dev Best-effort burn of vault rETH to cover shortfall; failures leave sleeve unchanged.
    function _tryBurnRethForWeth(uint256 shortfallEth) internal {
        if (shortfallEth == 0) return;
        address reth_ = rETH();
        uint256 rethNeeded = _rethForEthUp(shortfallEth);
        uint256 rethBal = IERC20(reth_).balanceOf(address(this));
        if (rethBal == 0) return;
        if (rethNeeded > rethBal) rethNeeded = rethBal;

        uint256 ethBefore = address(this).balance;
        try IRETH(reth_).burn(rethNeeded) {
            uint256 ethGot = address(this).balance - ethBefore;
            if (ethGot > 0) {
                IWETH(payable(weth())).deposit{value: ethGot}();
            }
        } catch {
            // collateral/pause: fall through to InsufficientLiquidReserve
        }
    }

    function _payReth(uint256 amount, address recipient) internal {
        _requireLockedReth(amount);
        IERC20(rETH()).safeTransfer(recipient, amount);
    }

    function _payAsset(address token, uint256 amount, address recipient) internal {
        if (token == weth()) {
            _payWeth(amount, recipient);
            return;
        }
        if (token == rETH()) {
            _payReth(amount, recipient);
            return;
        }
        revert InvalidRoute(address(0), token);
    }

    /// @dev Hard stake: unwrap WETH → deposit pool → mint rETH. Reverts capacity errors.
    function _stakeWethToReth(uint256 wethAmount) internal returns (uint256 rethOut) {
        if (wethAmount == 0) return 0;
        address pool = depositPool();
        address reth_ = rETH();
        uint256 maxDep = _maxDepositAmount();
        if (wethAmount > maxDep) {
            revert InsufficientDepositCapacity(maxDep, wethAmount);
        }
        uint256 beforeBal = IERC20(reth_).balanceOf(address(this));
        IWETH(payable(weth())).withdraw(wethAmount);
        IRocketDepositPool(pool).deposit{value: wethAmount}();
        rethOut = IERC20(reth_).balanceOf(address(this)) - beforeBal;
        if (rethOut == 0) revert Slippage();
    }

    /// @dev Soft stake: capacity-capped; never reverts on capacity 0 (returns 0).
    function _stakeWethToRethSoft(uint256 wethAmount) internal returns (uint256 rethOut) {
        if (wethAmount == 0) return 0;
        uint256 maxDep = _maxDepositAmount();
        if (maxDep == 0) return 0;
        uint256 stakeable = wethAmount > maxDep ? maxDep : wethAmount;
        if (stakeable == 0) return 0;
        // Soft path: catch protocol reverts (disabled deposits mid-flight, min deposit, etc.)
        address pool = depositPool();
        address reth_ = rETH();
        uint256 beforeBal = IERC20(reth_).balanceOf(address(this));
        IWETH(payable(weth())).withdraw(stakeable);
        try IRocketDepositPool(pool).deposit{value: stakeable}() {
            rethOut = IERC20(reth_).balanceOf(address(this)) - beforeBal;
        } catch {
            // Re-wrap ETH back to WETH sleeve so soft path never loses eth face
            IWETH(payable(weth())).deposit{value: stakeable}();
            return 0;
        }
    }

    function _execAssetToAsset(address tokenIn, uint256 amountIn, address tokenOut, address recipient)
        internal
        returns (uint256 produced)
    {
        address weth_ = weth();
        address reth_ = rETH();

        // WETH → rETH hard stake
        if (tokenIn == weth_ && tokenOut == reth_) {
            produced = _stakeWethToReth(amountIn);
            IERC20(reth_).safeTransfer(recipient, produced);
            return produced;
        }

        // rETH → WETH: inventory swap + WETH pay ladder
        if (tokenIn == reth_ && tokenOut == weth_) {
            produced = IRETH(reth_).getEthValue(amountIn);
            _payWeth(produced, recipient);
            return produced;
        }

        revert InvalidRoute(tokenIn, tokenOut);
    }

    function _creditAssetToReserve(address tokenIn, uint256 actualIn) internal returns (uint256 ethValue) {
        if (tokenIn == weth()) {
            return actualIn;
        }
        if (tokenIn == rETH()) {
            return IRETH(rETH()).getEthValue(actualIn);
        }
        revert InvalidRoute(tokenIn, address(this));
    }

    /**
     * @dev After WETH→SE mint: best-effort stake overage toward liquid target (capacity-capped).
     *      PRD D22/D23: never revert SE mint because stakeable == 0.
     *      Deposit fee may socialize eth-value drag (accepted).
     */
    function _bestEffortStakeOverageTowardTarget() internal {
        uint256 liquid = liquidReserveEth();
        if (liquid == 0) return;

        uint256 total = totalReserveEth();
        uint256 pct = targetLiquidReservePercentage();
        uint256 target = (total * pct) / ONE_WAD;

        if (liquid <= target) return;
        uint256 excess = liquid - target;
        _stakeWethToRethSoft(excess);
    }
}
