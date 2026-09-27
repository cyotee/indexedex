// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {AaveCrossVersionLoopExchangeBase} from "./AaveCrossVersionLoopExchangeBase.sol";
import {CrossVersionLoopExecutor} from "./CrossVersionLoopExecutor.sol";
import {CrossVersionLoopService} from "./CrossVersionLoopService.sol";
import {LoopPositionRepo} from "./LoopPositionRepo.sol";

/// @notice Exact-output withdrawals and native SY reuse the canonical funded standard routes.
contract AaveCrossVersionLoopExchangeOutTarget is
    AaveCrossVersionLoopExchangeBase, IStandardExchangeOut, NativeStandardYieldTarget
{
    using SafeERC20 for IERC20;

    /// @notice Wrap exact-out (mint) under-delivered the requested SE shares. Mirrors the exact-input
    ///         redemption slippage guard; a positive input must mint at least the requested shares.
    error LoopWrapSlippage(uint256 minimumShares, uint256 mintedShares);

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external view returns (uint256 amountIn)
    {
        ReentrancyLockRepo._onlyUnlocked();
        CrossVersionLoopExecutor.Market memory m = _market();
        // Wrap exact-out (mint): tokenA in for exactly `amountOut` SE shares out.
        if (address(tokenIn) == address(m.tokenA) && address(tokenOut) == address(this)) {
            return _underlyingInForShares(m, amountOut);
        }
        if (address(tokenIn) != address(this) || tokenOut != m.tokenA) revert ExchangeOutNotAvailable();
        amountIn = _sharesForAmountOut(m, amountOut);
        _requireFreeableFor(m, amountOut, amountIn, ERC20Repo._totalSupply());
    }

    function exchangeOut(IERC20 tokenIn, uint256 maxAmountIn, IERC20 tokenOut, uint256 amountOut,
        address recipient, bool pretransferred, uint256 deadline)
        external nonReentrant returns (uint256 amountIn)
    {
        _requireExchange(deadline, amountOut, recipient);
        CrossVersionLoopExecutor.Market memory m = _market();
        // Wrap exact-out (mint): tokenA in for exactly `amountOut` SE shares out.
        if (address(tokenIn) == address(m.tokenA) && address(tokenOut) == address(this)) {
            return _mintExactShares(m, maxAmountIn, amountOut, recipient, pretransferred);
        }
        if (address(tokenIn) != address(this) || tokenOut != m.tokenA) revert ExchangeOutNotAvailable();
        amountIn = _sharesForAmountOut(m, amountOut);
        uint256 supplyBefore_ = ERC20Repo._totalSupply();
        _requireFreeableFor(m, amountOut, amountIn, supplyBefore_);
        if (amountIn > maxAmountIn) revert MaxAmountExceeded(maxAmountIn, amountIn);
        _burnWithdrawalShares(amountIn, pretransferred);
        _withdrawAndPay(m, amountOut, recipient, amountIn, supplyBefore_);
    }

    /// @dev Wrap exact-out execution (tokenA -> exactly `shares_` SE shares). Inverse of the exchangeIn
    ///      deposit mint. Pulls exactly the required tokenA (D32: no public pretransfer), routes it through
    ///      the same D61 leverage executor as the deposit path (which clamps each borrow to live V3
    ///      headroom, so the target leverage is never exceeded), asserts the forward mint meets `shares_`,
    ///      then mints exactly `shares_`. Any wei of over-mint stays as booked backing (never over-issued).
    ///      Returns exactly the pulled tokenA so the buffer hook's `spent == amountIn` bound holds.
    function _mintExactShares(
        CrossVersionLoopExecutor.Market memory m, uint256 maxAmountIn, uint256 shares_,
        address recipient, bool pretransferred
    ) private returns (uint256 amountIn) {
        // D32: the loop rejects every public pretransfer; wrap exact-out pulls its exact input.
        if (pretransferred) revert ISecurePullErrors.TransferDeltaInsufficient(shares_, 0);
        amountIn = _underlyingInForShares(m, shares_);
        if (amountIn > maxAmountIn) revert MaxAmountExceeded(maxAmountIn, amountIn);
        IERC20 tokenIn = m.tokenA;
        // NAV + supply BEFORE this caller's principal enters (mirrors the exchangeIn deposit path).
        uint256 nav_ = CrossVersionLoopExecutor.navUsd(m);
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 before_ = tokenIn.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 received_ = tokenIn.balanceOf(address(this)) - before_;
        if (received_ != amountIn) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, received_);
        uint256 minted_ = CrossVersionLoopService.sharesForDeposit(
            nav_, supply_, CrossVersionLoopExecutor.valueUsd(m, tokenIn, amountIn)
        );
        if (supply_ == 0) {
            if (minted_ <= MINIMUM_LIQUIDITY) revert ZeroLoopAmount();
            minted_ -= MINIMUM_LIQUIDITY;
            ERC20Repo._mint(address(1), MINIMUM_LIQUIDITY);
        }
        if (minted_ < shares_) revert LoopWrapSlippage(shares_, minted_);
        // D31: previously retained principal loops first, then this caller's principal.
        if (before_ > 0) CrossVersionLoopExecutor.depositLoopAFirst(m, before_, _loopConfig());
        CrossVersionLoopExecutor.depositLoopAFirst(m, amountIn, _loopConfig());
        ERC20Repo._mint(recipient, shares_);
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](1);
        tokens_[0] = address(LoopPositionRepo._tokenA());
    }

    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }

    /// @dev The existing native position accounting unit is USD at oracle-base precision 8.
    /// The vault identifies that composite position; it is not an ERC20 accounting-asset address.
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 8);
    }

    function exchangeRate() external view override returns (uint256) {
        ReentrancyLockRepo._onlyUnlocked();
        uint256 supply_ = ERC20Repo._totalSupply();
        return supply_ == 0 ? 1e18 : Math.mulDiv(CrossVersionLoopExecutor.navUsd(_market()), 1e18, supply_);
    }
}
