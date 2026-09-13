// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {AerodromePoolMetadataRepo} from "@crane/contracts/protocols/dexes/aerodrome/v1/aware/AerodromePoolMetadataRepo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {AerodromeUtils} from "@crane/contracts/utils/math/AerodromeUtils.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {AerodromeStandardExchangeRepo} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeRepo.sol";
import {AerodromeStandardExchangeCommon} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol";

/// @notice Sequential volatile-pool quotes, including separately collected LP fees.
abstract contract AerodromeStandardExchangeQuoteTarget is
    AerodromeStandardExchangeCommon, IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote
{
    struct QuoteState {
        address exchange;
        address asset;
        address holder;
        address pool;
        address[2] tokens;
        uint256 holderShares;
        uint256 supply;
        uint256 actualLp;
        uint256 bookedLp;
        uint256 poolSupply;
        uint256 poolHeldLp;
        uint256[2] reserves;
        uint256[2] balances;
        uint256[2] indexes;
        uint256[2] suppliedIndexes;
        uint256[2] claimable;
        uint256[2] excess;
    }

    function quoteState(address asset, address holder) external view returns (bytes memory, uint256) {
        QuoteState memory q;
        q.exchange = address(this);
        q.asset = asset;
        q.holder = holder;
        q.pool = address(ERC4626Repo._reserveAsset());
        IPool pool = IPool(q.pool);
        q.tokens = [pool.token0(), pool.token1()];
        if (asset != q.pool && asset != q.tokens[0] && asset != q.tokens[1]) revert UnsupportedQuoteAsset(asset);
        q.holderShares = IERC20(address(this)).balanceOf(holder);
        q.supply = ERC20Repo._totalSupply();
        q.actualLp = IERC20(q.pool).balanceOf(address(this));
        q.bookedLp = ERC4626Repo._lastTotalAssets();
        q.poolSupply = IERC20(q.pool).totalSupply();
        q.poolHeldLp = IERC20(q.pool).balanceOf(q.pool);
        (q.reserves[0], q.reserves[1],) = pool.getReserves();
        q.balances = [IERC20(q.tokens[0]).balanceOf(q.pool), IERC20(q.tokens[1]).balanceOf(q.pool)];
        q.indexes = [pool.index0(), pool.index1()];
        q.suppliedIndexes = [pool.supplyIndex0(address(this)), pool.supplyIndex1(address(this))];
        q.claimable = [pool.claimable0(address(this)), pool.claimable1(address(this))];
        q.excess = [AerodromeStandardExchangeRepo._excessToken0(), AerodromeStandardExchangeRepo._excessToken1()];
        return (abi.encode(q), _aeroAssets(q, q.holderShares));
    }

    function _readAeroQuote(bytes calldata state) private view returns (QuoteState memory q) {
        q = abi.decode(state, (QuoteState));
        if (q.exchange != address(this) || q.pool != address(ERC4626Repo._reserveAsset())) revert InvalidQuoteState();
        if (q.asset != q.pool && q.asset != q.tokens[0] && q.asset != q.tokens[1]) revert InvalidQuoteState();
    }

    function _aeroFee(QuoteState memory q) private view returns (uint256) {
        return AerodromePoolMetadataRepo._factory().getFee(q.pool, false);
    }

    function quoteAssets(bytes calldata state, uint256 shares) external view returns (uint256) {
        return _aeroAssets(_readAeroQuote(state), shares);
    }

    function quoteShareBalance(bytes calldata state) external view returns (uint256) {
        return _readAeroQuote(state).holderShares;
    }

    function quoteTotalSupply(bytes calldata state) external view returns (uint256) {
        return _readAeroQuote(state).supply;
    }

    /// @dev Preserve the public SE redemption convention: preview a fee compound
    /// and then quote the proportional LP burn and opposing-token sale.
    function _aeroAssets(QuoteState memory original, uint256 shares) private view returns (uint256) {
        QuoteState memory q = abi.decode(abi.encode(original), (QuoteState));
        _aeroCompound(q);
        uint256 lp = BetterMath._convertToAssetsDown(shares, q.actualLp, q.supply, ERC4626Repo._decimalOffset());
        if (q.asset == q.pool) return lp;
        uint256 side = q.asset == q.tokens[0] ? 0 : 1;
        return AerodromeUtils._quoteWithdrawSwapWithFee(
            lp, q.poolSupply, q.reserves[side], q.reserves[1 - side], _aeroFee(q)
        );
    }

    function quoteTransition(bytes calldata state, Operation operation, uint256 amount)
        external view returns (bytes memory, uint256 amountIn, uint256 amountOut, uint256)
    {
        QuoteState memory q = _readAeroQuote(state);
        amountIn = amount;
        if (operation == Operation.ReceiveShares) {
            q.holderShares += amount;
            if (q.holderShares > q.supply) revert InvalidQuoteState();
            amountOut = amount;
        } else if (operation == Operation.DepositExactIn) {
            amountOut = _aeroDeposit(q, q.asset, amount);
            q.holderShares += amountOut;
        } else {
            _aeroCompound(q);
            uint256 side = q.asset == q.tokens[0] ? 0 : 1;
            if (operation == Operation.WithdrawExactOut) {
                uint256 needed = q.asset == q.pool ? amount : _quoteAeroLpToToken(
                    amount, q.poolSupply, q.reserves[side], q.reserves[1 - side], _aeroFee(q)
                );
                amountIn = BetterMath._convertToSharesUp(needed, q.actualLp, q.supply, ERC4626Repo._decimalOffset());
            }
            if (amountIn > q.holderShares) revert InsufficientQuoteShares(amountIn, q.holderShares);
            uint256 lp = BetterMath._convertToAssetsDown(amountIn, q.actualLp, q.supply, ERC4626Repo._decimalOffset());
            q.holderShares -= amountIn;
            q.supply -= amountIn;
            _aeroUpdateForVault(q);
            q.actualLp -= lp;
            amountOut = q.asset == q.pool ? lp : _aeroWithdraw(q, side, lp);
            q.bookedLp = q.actualLp;
            if (operation == Operation.WithdrawExactOut && amountOut < amount) revert InvalidQuoteState();
        }
        return (abi.encode(q), amountIn, amountOut, _aeroAssets(q, q.holderShares));
    }

    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory, uint256 sharesOut, uint256)
    {
        QuoteState memory q = _readAeroQuote(state);
        sharesOut = _aeroDeposit(q, tokenIn, amountIn);
        return (abi.encode(q), sharesOut, _aeroAssets(q, q.holderShares));
    }

    function _aeroDeposit(QuoteState memory q, address tokenIn, uint256 amount) private view returns (uint256 minted) {
        _aeroCompound(q);
        uint256 beforeLp = q.actualLp;
        uint256 received;
        if (tokenIn == q.pool) {
            _aeroUpdateForVault(q);
            q.actualLp += amount;
            received = amount;
        } else {
            if (tokenIn != q.tokens[0] && tokenIn != q.tokens[1]) revert UnsupportedQuoteAsset(tokenIn);
            if (q.actualLp != q.bookedLp) revert InvalidQuoteState();
            received = _aeroZap(q, tokenIn == q.tokens[0] ? 0 : 1, amount);
        }
        minted = BetterMath._convertToSharesDown(received, beforeLp, q.supply, ERC4626Repo._decimalOffset());
        q.supply += minted;
        q.bookedLp = q.actualLp;
    }

    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory, uint256 amountOut, uint256)
    {
        QuoteState memory q = _readAeroQuote(state);
        uint256 side = q.asset == q.tokens[0] ? 0 : 1;
        if (q.asset == q.pool) {
            if (tokenIn != q.tokens[0] && tokenIn != q.tokens[1]) revert UnsupportedQuoteAsset(tokenIn);
            // The router mints directly to the separate recipient. It does not
            // transfer LP through this SE or checkpoint this SE's fee indexes.
            amountOut = _aeroZapTo(q, tokenIn == q.tokens[0] ? 0 : 1, amountIn, false);
        } else if (tokenIn == q.pool) {
            // The pass-through receives LP before forwarding it to the router.
            // Both transfers checkpoint the vault's already-earned LP fees.
            _aeroUpdateForVault(q);
            q.actualLp += amountIn;
            _aeroUpdateForVault(q);
            q.actualLp -= amountIn;
            amountOut = _aeroWithdraw(q, side, amountIn);
        } else if (tokenIn == q.tokens[1 - side]) {
            amountOut = _aeroSwap(q, 1 - side, amountIn);
        } else revert UnsupportedQuoteAsset(tokenIn);
        if (q.actualLp != q.bookedLp) revert InvalidQuoteState();
        return (abi.encode(q), amountOut, _aeroAssets(q, q.holderShares));
    }

    /// @dev Mirror Pool._updateFor before every LP balance mutation.
    function _aeroUpdateForVault(QuoteState memory q) private pure {
        for (uint256 i; i < 2; ++i) {
            q.claimable[i] += Math.mulDiv(q.actualLp, q.indexes[i] - q.suppliedIndexes[i], 1e18);
            q.suppliedIndexes[i] = q.indexes[i];
        }
    }

    function _aeroCompound(QuoteState memory q) private view {
        _aeroUpdateForVault(q);
        uint256 total0 = q.claimable[0] + q.excess[0];
        uint256 total1 = q.claimable[1] + q.excess[1];
        q.claimable[0] = 0;
        q.claimable[1] = 0;
        q.excess[0] = 0;
        q.excess[1] = 0;
        if (total0 == 0 && total1 == 0) return;
        (uint256 proportional0, uint256 proportional1) = _proportionalDeposit(q.reserves[0], q.reserves[1], total0, total1);
        uint256 minted;
        if (proportional0 != 0 && proportional1 != 0) {
            minted = _aeroAddLiquidity(q, 0, proportional0, proportional1);
        }
        uint256[2] memory excess = [total0 - proportional0, total1 - proportional1];
        for (uint256 i; i < 2; ++i) {
            if (excess[i] > DEFAULT_DUST_THRESHOLD) minted += _aeroZap(q, i, excess[i]);
            else q.excess[i] = excess[i];
        }
        if (minted == 0) return;
        uint256 fee = BetterMath._percentageOfWAD(minted, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this)));
        if (fee != 0) {
            _aeroUpdateForVault(q);
            if (address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()) != address(this)) q.actualLp -= fee;
        }
        q.bookedLp = q.actualLp;
    }

    function _aeroSwap(QuoteState memory q, uint256 side, uint256 amount) private view returns (uint256 output) {
        uint256 fee = _aeroFee(q);
        uint256 net = amount - Math.mulDiv(amount, fee, 10_000);
        output = Math.mulDiv(net, q.reserves[1 - side], q.reserves[side] + net);
        if (output == 0 || output >= q.reserves[1 - side]) revert InvalidQuoteState();
        q.balances[side] += amount;
        q.balances[1 - side] -= output;
        for (uint256 i; i < 2; ++i) {
            uint256 expected = q.reserves[i] - (i == side ? 0 : output);
            uint256 gross = q.balances[i] > expected ? q.balances[i] - expected : 0;
            uint256 collected = Math.mulDiv(gross, fee, 10_000);
            q.balances[i] -= collected;
            if (collected != 0) q.indexes[i] += Math.mulDiv(collected, 1e18, q.poolSupply);
        }
        q.reserves[0] = q.balances[0];
        q.reserves[1] = q.balances[1];
    }

    function _aeroZap(QuoteState memory q, uint256 side, uint256 amount) private view returns (uint256) {
        return _aeroZapTo(q, side, amount, true);
    }

    function _aeroZapTo(QuoteState memory q, uint256 side, uint256 amount, bool toVault) private view returns (uint256) {
        uint256 sold = ConstProdUtils._swapDepositSaleAmt(amount, q.reserves[side], _aeroFee(q), 10_000);
        uint256 bought = _aeroSwap(q, side, sold);
        return _aeroAddLiquidityTo(q, side, amount - sold, bought, toVault);
    }

    function _aeroAddLiquidity(QuoteState memory q, uint256 side, uint256 desiredA, uint256 desiredB)
        private pure returns (uint256 minted)
    {
        return _aeroAddLiquidityTo(q, side, desiredA, desiredB, true);
    }

    function _aeroAddLiquidityTo(QuoteState memory q, uint256 side, uint256 desiredA, uint256 desiredB, bool toVault)
        private pure returns (uint256 minted)
    {
        (uint256 a, uint256 b) = _proportionalDeposit(q.reserves[side], q.reserves[1 - side], desiredA, desiredB);
        q.balances[side] += a;
        q.balances[1 - side] += b;
        uint256 amount0 = q.balances[0] - q.reserves[0];
        uint256 amount1 = q.balances[1] - q.reserves[1];
        if (q.poolSupply == 0) {
            minted = Math.sqrt(amount0 * amount1) - 1_000;
            q.poolSupply = 1_000;
        } else {
            minted = Math.min(Math.mulDiv(amount0, q.poolSupply, q.reserves[0]), Math.mulDiv(amount1, q.poolSupply, q.reserves[1]));
        }
        if (minted == 0) revert InvalidQuoteState();
        if (toVault) {
            _aeroUpdateForVault(q);
            q.actualLp += minted;
        }
        q.poolSupply += minted;
        q.reserves[0] = q.balances[0];
        q.reserves[1] = q.balances[1];
    }

    function _aeroWithdraw(QuoteState memory q, uint256 side, uint256 lp) private view returns (uint256 output) {
        uint256 burned = lp + q.poolHeldLp;
        q.poolHeldLp = 0;
        uint256 a = Math.mulDiv(burned, q.balances[side], q.poolSupply);
        uint256 b = Math.mulDiv(burned, q.balances[1 - side], q.poolSupply);
        if (a == 0 || b == 0) revert InvalidQuoteState();
        q.poolSupply -= burned;
        q.balances[side] -= a;
        q.balances[1 - side] -= b;
        q.reserves[0] = q.balances[0];
        q.reserves[1] = q.balances[1];
        output = a + _aeroSwap(q, 1 - side, b);
    }
}
