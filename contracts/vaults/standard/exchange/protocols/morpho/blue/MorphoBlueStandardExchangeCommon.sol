// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IMorpho, MarketParams, Position} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoBlueService} from
    "@crane/contracts/protocols/lending/morpho/blue/services/MorphoBlueService.sol";
import {MorphoBlueAwareRepo} from
    "@crane/contracts/protocols/lending/morpho/blue/aware/MorphoBlueAwareRepo.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    MorphoBlueStandardExchangeRepo
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeRepo.sol";

/**
 * @title MorphoBlueStandardExchangeCommon
 * @notice Shared NAV, pull, mint/burn, hard Morpho.supply, and idle-first pay for SE In/Out and IERC4626.
 * @dev Two books: `reserveOfToken(loanToken)` is idle only; `totalAssets` / previews use live NAV.
 */
abstract contract MorphoBlueStandardExchangeCommon {
    using SafeERC20 for IERC20;
    using MorphoBalancesLib for IMorpho;

    error ZeroAmount();
    error ZeroAddress();
    error Slippage();
    error DeadlineExpired();
    error InsufficientDeposit(uint256 required, uint256 actual);

    function _loan() internal view returns (IERC20) {
        return IERC20(MorphoBlueStandardExchangeRepo._marketParams().loanToken);
    }

    function _morpho() internal view returns (IMorpho) {
        return MorphoBlueAwareRepo._morpho();
    }

    function _params() internal view returns (MarketParams memory) {
        return MorphoBlueStandardExchangeRepo._marketParams();
    }

    function _offset() internal view returns (uint8) {
        return ERC4626Repo._decimalOffset();
    }

    function _idle() internal view returns (uint256) {
        return _loan().balanceOf(address(this));
    }

    /// @dev Live NAV = idle loanToken + this vault's expected Morpho supply (accrued).
    function _liveNav() internal view returns (uint256) {
        return _idle() + MorphoBlueService._expectedSupplyAssets(_morpho(), _params(), address(this));
    }

    /// @dev Free Morpho cash usable by this vault: min(our expected supply, market cash).
    function _morphoFreeCash() internal view returns (uint256) {
        IMorpho morpho_ = _morpho();
        MarketParams memory params_ = _params();
        uint256 expectedSupply_ = MorphoBlueService._expectedSupplyAssets(morpho_, params_, address(this));
        uint256 totalSupply_ = morpho_.expectedTotalSupplyAssets(params_);
        uint256 totalBorrow_ = morpho_.expectedTotalBorrowAssets(params_);
        uint256 marketCash_ = totalSupply_ > totalBorrow_ ? totalSupply_ - totalBorrow_ : 0;
        return expectedSupply_ < marketCash_ ? expectedSupply_ : marketCash_;
    }

    function _availableCash() internal view returns (uint256) {
        return _idle() + _morphoFreeCash();
    }

    function _syncNavSnapshot() internal {
        ERC4626Repo._setLastTotalAssets(_liveNav());
    }

    function _syncReserveToBalance() internal {
        IERC20 loan_ = _loan();
        MultiAssetBasicVaultRepo._updateReserve(loan_, loan_.balanceOf(address(this)));
    }

    function _endMoneyRoute() internal {
        _syncReserveToBalance();
        ERC4626Repo._setLastTotalAssets(_liveNav());
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _requireRecipient(address recipient) internal pure {
        if (recipient == address(0)) revert ZeroAddress();
    }

    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _requireLiquidity(uint256 requested) internal view {
        uint256 available_ = _availableCash();
        if (requested > available_) {
            revert IMorphoBlueStandardExchange.InsufficientLiquidity(requested, available_);
        }
    }

    function _sharesFromAssetsDown(uint256 assets, uint256 nav, uint256 supply) internal view returns (uint256) {
        return BetterMath._convertToSharesDown(assets, nav, supply, _offset());
    }

    function _sharesFromAssetsUp(uint256 assets, uint256 nav, uint256 supply) internal view returns (uint256) {
        return BetterMath._convertToSharesUp(assets, nav, supply, _offset());
    }

    function _assetsFromSharesDown(uint256 shares, uint256 nav, uint256 supply) internal view returns (uint256) {
        return BetterMath._convertToAssetsDown(shares, nav, supply, _offset());
    }

    function _assetsFromSharesUp(uint256 shares, uint256 nav, uint256 supply) internal view returns (uint256) {
        return BetterMath._convertToAssetsUp(shares, nav, supply, _offset());
    }

    function _previewWrapExactIn(uint256 amountIn) internal view returns (uint256 sharesOut) {
        return _sharesFromAssetsDown(amountIn, _liveNav(), ERC20Repo._totalSupply());
    }

    function _previewWrapExactOut(uint256 sharesOut) internal view returns (uint256 amountIn) {
        return _assetsFromSharesUp(sharesOut, _liveNav(), ERC20Repo._totalSupply());
    }

    function _previewUnwrapExactIn(uint256 sharesIn) internal view returns (uint256 assetsOut) {
        return _assetsFromSharesDown(sharesIn, _liveNav(), ERC20Repo._totalSupply());
    }

    function _previewUnwrapExactOut(uint256 assetsOut) internal view returns (uint256 sharesIn) {
        return _sharesFromAssetsUp(assetsOut, _liveNav(), ERC20Repo._totalSupply());
    }

    /**
     * @dev Durable reserve-delta pull (BasicVault / ERC4626 SE peer).
     *      `!pretransferred`: credit measured transfer delta only.
     *      `pretransferred`: credit `claimed` iff `claimed <= U` (unbooked surplus).
     */
    function _securePull(IERC20 token, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(token));
        uint256 B0 = token.balanceOf(address(this));

        if (!pretransferred) {
            token.safeTransferFrom(msg.sender, address(this), amountIn);
            uint256 delta = token.balanceOf(address(this)) - B0;
            if (delta == 0) {
                revert InsufficientDeposit(amountIn, 0);
            }
            if (delta < amountIn) {
                return delta;
            }
            if (delta > amountIn) {
                token.safeTransfer(msg.sender, delta - amountIn);
            }
            return amountIn;
        }

        uint256 U = B0 - R;
        if (amountIn > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, U);
        }
        return amountIn;
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

    function _maybeSpendAllowance(address owner, uint256 shares) internal {
        if (msg.sender != owner && owner != address(this)) {
            ERC20Repo._spendAllowance(owner, msg.sender, shares);
        }
    }

    function _burnSeShares(address owner, uint256 burnAmount, bool pretransferred) internal {
        if (pretransferred) {
            ERC20Repo._burn(address(this), burnAmount);
            uint256 leftover = IERC20(address(this)).balanceOf(address(this));
            if (leftover > 0) {
                IERC20(address(this)).safeTransfer(owner, leftover);
            }
        } else {
            ERC20Repo._burn(owner, burnAmount);
        }
    }

    /// @dev Hard Morpho.supply of measured inbound. No try/catch (D26).
    function _supplyInBound(uint256 assets) internal {
        if (assets == 0) return;
        MorphoBlueService._supply(_morpho(), _params(), assets, address(this));
    }

    /// @dev Pay `assets` of loanToken: idle first, then Morpho.withdraw. Full Morpho close uses shares mode.
    function _payLoanToken(uint256 assets, address receiver) internal {
        _requireLiquidity(assets);
        IERC20 loan_ = _loan();
        uint256 idle_ = loan_.balanceOf(address(this));
        uint256 needFromMorpho_ = assets > idle_ ? assets - idle_ : 0;

        if (needFromMorpho_ > 0) {
            IMorpho morpho_ = _morpho();
            MarketParams memory params_ = _params();
            uint256 expected_ = MorphoBlueService._expectedSupplyAssets(morpho_, params_, address(this));
            if (needFromMorpho_ >= expected_) {
                Position memory pos_ = morpho_.position(MorphoBlueStandardExchangeRepo._marketId(), address(this));
                if (pos_.supplyShares > 0) {
                    MorphoBlueService._withdraw(
                        MorphoBlueService.WithdrawParams({
                            morpho: morpho_,
                            marketParams: params_,
                            assets: 0,
                            shares: pos_.supplyShares,
                            onBehalf: address(this),
                            receiver: address(this)
                        })
                    );
                }
            } else {
                MorphoBlueService._withdraw(morpho_, params_, needFromMorpho_, address(this), address(this));
            }
        }

        uint256 have_ = loan_.balanceOf(address(this));
        if (have_ < assets) {
            revert IMorphoBlueStandardExchange.InsufficientLiquidity(assets, have_);
        }
        loan_.safeTransfer(receiver, assets);
    }

    function _execWrapExactIn(
        uint256 amountIn,
        address recipient,
        bool pretransferred,
        uint256 minAmountOut
    ) internal returns (uint256 sharesOut) {
        _syncNavSnapshot();
        uint256 navBefore = ERC4626Repo._lastTotalAssets();
        uint256 supply = ERC20Repo._totalSupply();
        uint256 actualIn = _securePull(_loan(), amountIn, pretransferred);
        sharesOut = _sharesFromAssetsDown(actualIn, navBefore, supply);
        if (sharesOut < minAmountOut) revert Slippage();
        _mintWithUsageFee(recipient, sharesOut);
        _supplyInBound(actualIn);
        _endMoneyRoute();
    }

    function _execWrapExactOut(
        uint256 sharesOut,
        uint256 maxAmountIn,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 amountIn) {
        _syncNavSnapshot();
        uint256 navBefore = ERC4626Repo._lastTotalAssets();
        uint256 supply = ERC20Repo._totalSupply();
        amountIn = _assetsFromSharesUp(sharesOut, navBefore, supply);
        if (amountIn > maxAmountIn) revert Slippage();
        uint256 actualIn = _securePull(_loan(), amountIn, pretransferred);
        if (actualIn < amountIn) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, actualIn);
        }
        _mintWithUsageFee(recipient, sharesOut);
        _supplyInBound(actualIn);
        _endMoneyRoute();
    }

    function _execUnwrapExactIn(
        address shareOwner,
        uint256 sharesIn,
        address recipient,
        bool pretransferred,
        uint256 minAmountOut
    ) internal returns (uint256 assetsOut) {
        _syncNavSnapshot();
        uint256 nav = ERC4626Repo._lastTotalAssets();
        uint256 supply = ERC20Repo._totalSupply();
        assetsOut = _assetsFromSharesDown(sharesIn, nav, supply);
        if (assetsOut < minAmountOut) revert Slippage();
        _requireLiquidity(assetsOut);
        if (!pretransferred) _maybeSpendAllowance(shareOwner, sharesIn);
        _burnSeShares(shareOwner, sharesIn, pretransferred);
        _payLoanToken(assetsOut, recipient);
        _endMoneyRoute();
    }

    function _execUnwrapExactOut(
        address shareOwner,
        uint256 assetsOut,
        uint256 maxAmountIn,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 sharesIn) {
        _syncNavSnapshot();
        uint256 nav = ERC4626Repo._lastTotalAssets();
        uint256 supply = ERC20Repo._totalSupply();
        sharesIn = _sharesFromAssetsUp(assetsOut, nav, supply);
        if (sharesIn > maxAmountIn) revert Slippage();
        _requireLiquidity(assetsOut);
        if (!pretransferred) _maybeSpendAllowance(shareOwner, sharesIn);
        _burnSeShares(shareOwner, sharesIn, pretransferred);
        _payLoanToken(assetsOut, recipient);
        _endMoneyRoute();
    }

    function _revertInvalidRoute(IERC20 tokenIn, IERC20 tokenOut) internal pure {
        revert IStandardExchangeErrors.InvalidRoute(address(tokenIn), address(tokenOut));
    }
}
