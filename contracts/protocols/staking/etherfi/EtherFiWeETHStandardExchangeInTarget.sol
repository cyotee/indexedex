// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {EtherFiWeETHStandardExchangeRepo} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeRepo.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {
    EtherFiWeETHStandardExchangeCommon
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol";

/**
 * @title EtherFiWeETHStandardExchangeInTarget
 * @notice Exact-in Standard Exchange surface for ether.fi weETH SE.
 * @dev No exchangeInEth / native ETH entry. Previews never gate on sleeve/redeem.
 */
contract EtherFiWeETHStandardExchangeInTarget is
    EtherFiWeETHStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeIn,
    IStandardExchangeTransitionQuote,
    IStandardExchangeExternalQuote
{
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        return _quoteExactIn(address(tokenIn), amountIn, address(tokenOut));
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        address in_ = address(tokenIn);
        address out_ = address(tokenOut);

        // SE redeem exact-in: burn shares, pay asset
        if (_isSeShare(in_)) {
            if (!_isAsset(out_)) revert InvalidRoute(in_, out_);
            amountOut = _quoteExactIn(in_, amountIn, out_);
            if (amountOut < minAmountOut) revert Slippage();
            _burnShares(amountIn);
            _payAsset(out_, amountOut, recipient);
            return amountOut;
        }

        // asset → SE mint exact-in
        if (_isSeShare(out_)) {
            if (!_isAsset(in_)) revert InvalidRoute(in_, out_);
            uint256 totalBefore = totalReserveEth();
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            uint256 ethValue = _creditAssetToReserve(in_, actualIn);
            amountOut = _convertEthDeltaToShares(ethValue, totalBefore);
            if (amountOut < minAmountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            // D12b: WETH→SE split sleeve to target %
            if (in_ == weth()) {
                _splitWethSleeveAfterSeMint();
            }
            return amountOut;
        }

        // asset → asset exact-in
        if (_isAsset(in_) && _isAsset(out_)) {
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            amountOut = _execAssetToAsset(in_, actualIn, out_, recipient);
            if (amountOut < minAmountOut) revert Slippage();
            return amountOut;
        }

        revert InvalidRoute(in_, out_);
    }
    /// @dev Project the actual global eETH share ratio, liquid sleeve, wrapped
    /// inventory and pending queue face separately. Idle eETH is not reserve NAV.
    struct EtherFiQuoteState {
        address exchange;
        address asset;
        address holder;
        uint256 holderShares;
        uint256 supply;
        uint256 liquid;
        uint256 wrapped;
        uint256 pending;
        uint256 idleEShares;
        uint256 pooledEth;
        uint256 eShares;
        uint256 poolLiquid;
        uint256 redeemUnits;
        uint16 exitFee;
        uint16 treasurySplit;
        uint16 lowWatermark;
    }

    function _efWord(address target, bytes memory callData) private view returns (uint256 value) {
        (bool ok, bytes memory result) = target.staticcall(callData);
        if (!ok || result.length != 32) revert InvalidQuoteState();
        value = abi.decode(result, (uint256));
    }

    function quoteState(address asset, address holder) external view returns (bytes memory, uint256) {
        if (asset != weth() && asset != weETH()) revert UnsupportedQuoteAsset(asset);
        EtherFiQuoteState memory q;
        q.exchange = address(this);
        q.asset = asset;
        q.holder = holder;
        q.holderShares = IERC20(address(this)).balanceOf(holder);
        q.supply = ERC20Repo._totalSupply();
        q.liquid = liquidReserveEth();
        q.wrapped = IERC20(weETH()).balanceOf(address(this));
        q.pending = EtherFiWeETHStandardExchangeRepo._pendingFaceEthTotal();
        q.idleEShares = _efWord(eETH(), abi.encodeWithSignature("shares(address)", address(this)));
        q.pooledEth = _efWord(liquidityPool(), abi.encodeWithSignature("getTotalPooledEther()"));
        q.eShares = _efWord(eETH(), abi.encodeWithSignature("totalShares()"));
        q.poolLiquid = _efWord(liquidityPool(), abi.encodeWithSignature("totalValueInLp()"));
        if (redemptionManager() != address(0)) _efSnapshotRedemption(q);
        return (abi.encode(q), _efAssets(q, q.holderShares));
    }

    function _efSnapshotRedemption(EtherFiQuoteState memory q) private view {
        (bool ok, bytes memory data) = redemptionManager().staticcall(
            abi.encodeWithSignature("tokenToRedemptionInfo(address)", ETH_SENTINEL)
        );
        if (!ok || data.length != 7 * 32) revert InvalidQuoteState();
        uint256[7] memory words = abi.decode(data, (uint256[7]));
        // Bucket units are 1e12 wei, not wei. Refill once at this timestamp;
        // sequential transitions consume this projected balance without refill.
        uint256 refilled = words[1] + (block.timestamp - words[2]) * words[3];
        q.redeemUnits = Math.min(words[0], refilled);
        q.treasurySplit = uint16(words[4]);
        q.exitFee = uint16(words[5]);
        q.lowWatermark = uint16(words[6]);
        if (q.exitFee > 10_000 || q.treasurySplit > 10_000) revert InvalidQuoteState();
    }

    function _readEtherFiQuote(bytes calldata state) private view returns (EtherFiQuoteState memory q) {
        q = abi.decode(state, (EtherFiQuoteState));
        if (q.exchange != address(this) || (q.asset != weth() && q.asset != weETH())) revert InvalidQuoteState();
    }

    function _efPooled(EtherFiQuoteState memory q, uint256 shares) private pure returns (uint256) {
        return q.eShares == 0 ? 0 : Math.mulDiv(shares, q.pooledEth, q.eShares);
    }

    function _efShares(EtherFiQuoteState memory q, uint256 assets) private pure returns (uint256) {
        return q.pooledEth == 0 ? 0 : Math.mulDiv(assets, q.eShares, q.pooledEth);
    }

    function _efNav(EtherFiQuoteState memory q) private pure returns (uint256) {
        return q.liquid + _efPooled(q, q.wrapped) + q.pending;
    }

    function _efAssets(EtherFiQuoteState memory q, uint256 shares) private view returns (uint256) {
        uint256 face = BetterMath._convertToAssetsDown(shares, _efNav(q), q.supply, _decimalOffset());
        return q.asset == weth() ? face : _efShares(q, face);
    }

    function quoteAssets(bytes calldata state, uint256 shares) external view returns (uint256) {
        return _efAssets(_readEtherFiQuote(state), shares);
    }

    function quoteShareBalance(bytes calldata state) external view returns (uint256) {
        return _readEtherFiQuote(state).holderShares;
    }

    function quoteTotalSupply(bytes calldata state) external view returns (uint256) {
        return _readEtherFiQuote(state).supply;
    }

    function _efReceiveAndWrap(EtherFiQuoteState memory q, uint256 amount)
        private pure returns (uint256 received, uint256 wrapped)
    {
        uint256 beforeBalance = _efPooled(q, q.idleEShares);
        q.idleEShares += _efShares(q, amount);
        received = Math.min(amount, _efPooled(q, q.idleEShares) - beforeBalance);
        wrapped = _efShares(q, received);
        q.idleEShares -= wrapped;
    }

    function _efStake(EtherFiQuoteState memory q, uint256 amount) private pure returns (uint256 wrapped) {
        if (amount == 0) return 0;
        uint256 beforeBalance = _efPooled(q, q.idleEShares);
        uint256 minted = q.pooledEth == 0 ? amount : _efShares(q, amount);
        q.pooledEth += amount;
        q.poolLiquid += amount;
        q.eShares += minted;
        q.idleEShares += minted;
        uint256 received = _efPooled(q, q.idleEShares) - beforeBalance;
        if (received == 0) revert Slippage();
        wrapped = _efShares(q, received);
        if (wrapped == 0) revert Slippage();
        q.idleEShares -= wrapped;
        q.liquid -= amount;
    }

    function _efSplitSleeve(EtherFiQuoteState memory q) private view {
        uint256 percent = targetLiquidReservePercentage();
        uint256 target = Math.mulDiv(_efNav(q), percent, 1e18);
        if (q.liquid > target) q.wrapped += _efStake(q, q.liquid - target);
        target = Math.mulDiv(_efNav(q), percent, 1e18);
        if (q.liquid > target + Math.mulDiv(target, REBALANCE_BAND_WAD, 1e18)) {
            q.wrapped += _efStake(q, q.liquid - target);
        }
    }

    function _efDeposit(EtherFiQuoteState memory q, address token, uint256 amount, bool toHolder)
        private view returns (uint256 minted)
    {
        if (amount == 0) return 0;
        uint256 beforeNav = _efNav(q);
        uint256 credited;
        if (token == weth()) {
            q.liquid += amount;
            credited = amount;
        } else if (token == weETH()) {
            q.wrapped += amount;
            credited = _efPooled(q, amount);
        } else if (token == eETH()) {
            (, uint256 wrapped) = _efReceiveAndWrap(q, amount);
            q.wrapped += wrapped;
            credited = _efPooled(q, wrapped);
        } else revert UnsupportedQuoteAsset(token);
        minted = BetterMath._convertToSharesDown(credited, beforeNav, q.supply, _decimalOffset());
        q.supply += minted;
        if (toHolder) q.holderShares += minted;
        address beneficiary = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (beneficiary != address(0)) {
            uint256 fee = BetterMath._percentageOfWAD(minted, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this)));
            q.supply += fee;
            if (q.holder == beneficiary) q.holderShares += fee;
        }
        if (token == weth()) _efSplitSleeve(q);
    }

    function _efCanRedeem(EtherFiQuoteState memory q, uint256 face) private pure returns (bool) {
        uint256 low = Math.mulDiv(q.pooledEth, q.lowWatermark, 10_000);
        return face < uint256(type(uint64).max) * 1e12 && q.poolLiquid >= low
            && face <= q.poolLiquid - low && Math.ceilDiv(face, 1e12) <= q.redeemUnits;
    }

    function _efRedeemShortfall(EtherFiQuoteState memory q, uint256 shortfall) private view {
        if (redemptionManager() == address(0) || q.wrapped == 0) return;
        uint256 gross = shortfall + Math.max(Math.mulDiv(shortfall, 500, 10_000), 1);
        uint256 wrapped = Math.min(Math.max(_efShares(q, gross), 1), q.wrapped);
        uint256 face = _efPooled(q, wrapped);
        if (!_efCanRedeem(q, face)) {
            wrapped = Math.min(_efShares(q, shortfall), q.wrapped);
            face = _efPooled(q, wrapped);
            if (!_efCanRedeem(q, face)) return;
        }
        // Match _calcRedemption, including both floors before the receiver
        // amount. The manager's previewRedeem has different dust rounding.
        uint256 shares = _efShares(q, face);
        uint256 received = _efPooled(q, Math.mulDiv(shares, 10_000 - q.exitFee, 10_000));
        if (received == 0) return;
        uint256 burned = Math.mulDiv(received, q.eShares, q.pooledEth, Math.Rounding.Ceil);
        uint256 treasuryShares = Math.mulDiv(shares - burned, q.treasurySplit, 10_000);
        address treasury = address(uint160(_efWord(redemptionManager(), abi.encodeWithSignature("treasury()"))));
        if (treasury == address(this)) q.idleEShares += _efShares(q, _efPooled(q, treasuryShares));
        q.wrapped -= wrapped;
        q.liquid += received;
        q.redeemUnits -= Math.ceilDiv(face, 1e12);
        q.pooledEth -= received;
        q.poolLiquid -= received;
        q.eShares -= shares - treasuryShares;
    }

    function _efPay(EtherFiQuoteState memory q, uint256 amount) private view {
        if (q.asset == weth()) {
            if (q.liquid < amount) _efRedeemShortfall(q, amount - q.liquid);
            if (q.liquid < amount) revert InsufficientLiquidReserve(amount, q.liquid);
            q.liquid -= amount;
        } else {
            if (q.wrapped < amount) revert InsufficientLockedReserve(amount, q.wrapped);
            q.wrapped -= amount;
        }
    }

    function quoteTransition(bytes calldata state, Operation operation, uint256 amount)
        external view returns (bytes memory, uint256 amountIn, uint256 amountOut, uint256)
    {
        EtherFiQuoteState memory q = _readEtherFiQuote(state);
        amountIn = amount;
        if (operation == Operation.ReceiveShares) {
            q.holderShares += amount;
            if (q.holderShares > q.supply) revert InvalidQuoteState();
            amountOut = amount;
        } else if (operation == Operation.DepositExactIn) {
            amountOut = _efDeposit(q, q.asset, amount, true);
        } else {
            if (operation == Operation.WithdrawExactOut) {
                uint256 face = q.asset == weth() ? amount : _efPooled(q, amount);
                amountIn = BetterMath._convertToSharesUp(face, _efNav(q), q.supply, _decimalOffset());
                amountOut = amount;
            } else amountOut = _efAssets(q, amount);
            if (amountIn > q.holderShares) revert InsufficientQuoteShares(amountIn, q.holderShares);
            q.holderShares -= amountIn;
            q.supply -= amountIn;
            _efPay(q, amountOut);
        }
        return (abi.encode(q), amountIn, amountOut, _efAssets(q, q.holderShares));
    }

    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amount)
        external view returns (bytes memory, uint256 minted, uint256)
    {
        EtherFiQuoteState memory q = _readEtherFiQuote(state);
        minted = _efDeposit(q, tokenIn, amount, false);
        return (abi.encode(q), minted, _efAssets(q, q.holderShares));
    }

    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amount)
        external view returns (bytes memory, uint256 amountOut, uint256)
    {
        EtherFiQuoteState memory q = _readEtherFiQuote(state);
        if (q.asset == weth()) {
            if (tokenIn == weETH()) {
                q.wrapped += amount;
                amountOut = _efPooled(q, amount);
            } else if (tokenIn == eETH()) {
                (uint256 received, uint256 wrapped) = _efReceiveAndWrap(q, amount);
                q.wrapped += wrapped;
                amountOut = received;
            } else revert UnsupportedQuoteAsset(tokenIn);
            _efPay(q, amountOut);
        } else if (tokenIn == weth()) {
            q.liquid += amount;
            amountOut = _efStake(q, amount);
        } else if (tokenIn == eETH()) {
            (, amountOut) = _efReceiveAndWrap(q, amount);
        } else revert UnsupportedQuoteAsset(tokenIn);
        return (abi.encode(q), amountOut, _efAssets(q, q.holderShares));
    }

}
