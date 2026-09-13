// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRocketStorage} from "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRocketStorage.sol";
import {IRETH} from "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRETH.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {RocketPoolRETHStandardExchangeRepo} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeRepo.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {
    RocketPoolRETHStandardExchangeCommon
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol";

/**
 * @title RocketPoolRETHStandardExchangeInTarget
 * @notice Exact-in Standard Exchange surface for Rocket Pool rETH SE.
 * @dev No exchangeInEth / native ETH entry. Previews never gate on sleeve/capacity/burn.
 */
contract RocketPoolRETHStandardExchangeInTarget is
    RocketPoolRETHStandardExchangeCommon,
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
            // D22: best-effort soft stake overage toward liquid target
            if (in_ == weth()) {
                _bestEffortStakeOverageTowardTarget();
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
    /// @dev Validator assignment subtracts equal ETH from deposit-pool balance
    /// and queue capacity. Their signed difference therefore projects both
    /// collateral and deposit headroom without replaying individual validators.
    struct RocketQuoteState {
        address exchange;
        address asset;
        address holder;
        uint256 holderShares;
        uint256 supply;
        uint256 liquid;
        uint256 locked;
        uint256 rethCollateral;
        int256 poolNet;
        int256 capacityUsed;
        uint256 capacityLimit;
        uint256 minimumDeposit;
        uint256 depositFee;
        uint256 collateralTarget;
        bool depositEnabled;
        bool canTransferReth;
    }

    function _rpWord(address target, bytes memory data) private view returns (uint256) {
        (bool ok, bytes memory result) = target.staticcall(data);
        if (!ok || result.length != 32) revert InvalidQuoteState();
        return abi.decode(result, (uint256));
    }

    function _rpAddress(string memory name_) private view returns (address) {
        return IRocketStorage(RocketPoolRETHStandardExchangeRepo._rocketStorage()).getAddress(
            keccak256(abi.encodePacked("contract.address", name_))
        );
    }

    function _rpCapacityReadable(address pool) private view returns (bool) {
        (bool ok, bytes memory result) = pool.staticcall(abi.encodeWithSignature("getMaximumDepositAmount()"));
        return ok && result.length == 32;
    }

    function _rpSigned(uint256 value) private pure returns (int256) {
        if (value > uint256(type(int256).max)) revert InvalidQuoteState();
        return int256(value);
    }

    function quoteState(address asset, address holder) external view returns (bytes memory, uint256) {
        if (!_isAsset(asset)) revert UnsupportedQuoteAsset(asset);
        RocketQuoteState memory q;
        q.exchange = address(this);
        q.asset = asset;
        q.holder = holder;
        q.holderShares = IERC20(address(this)).balanceOf(holder);
        q.supply = ERC20Repo._totalSupply();
        q.liquid = liquidReserveEth();
        q.locked = IERC20(rETH()).balanceOf(address(this));
        q.rethCollateral = rETH().balance;
        _rpSnapshotProtocol(q);
        return (abi.encode(q), _rpAssets(q, q.holderShares));
    }

    function _rpSnapshotProtocol(RocketQuoteState memory q) private view {
        address settings = _rpAddress("rocketDAOProtocolSettingsDeposit");
        // rETH burns always use the current registered deposit pool. An older
        // configured deposit pool can no longer stake, but its vault may still
        // redeem against the current protocol collateral.
        address pool = _rpAddress("rocketDepositPool");
        uint256 version_ = _rpWord(pool, abi.encodeWithSignature("version()"));
        if (version_ != 3 && version_ != 4) revert InvalidQuoteState();
        uint256 balance = _rpWord(pool, abi.encodeWithSignature("getBalance()"));
        uint256 queue = _rpWord(_rpAddress("rocketMinipoolQueue"), abi.encodeWithSignature("getEffectiveCapacity()"));
        IRocketStorage registry = IRocketStorage(RocketPoolRETHStandardExchangeRepo._rocketStorage());
        if (version_ == 4) {
            queue += registry.getUint(keccak256("deposit.pool.requested.total"));
            uint256 rate = _rpWord(_rpAddress("rocketDAOProtocolSettingsNetwork"), abi.encodeWithSignature("getTargetRethCollateralRate()"));
            uint256 ethTotal = _rpWord(_rpAddress("rocketNetworkBalances"), abi.encodeWithSignature("getTotalETHBalance()"));
            q.collateralTarget = Math.mulDiv(ethTotal, rate, 1e18);
        }
        q.poolNet = _rpSigned(balance) - _rpSigned(queue);
        bool assigns = _rpWord(settings, abi.encodeWithSignature("getAssignDepositsEnabled()")) != 0;
        q.capacityUsed = assigns ? q.poolNet : _rpSigned(balance);
        q.capacityLimit = _rpWord(settings, abi.encodeWithSignature("getMaximumDepositPoolSize()"));
        q.minimumDeposit = _rpWord(settings, abi.encodeWithSignature("getMinimumDeposit()"));
        q.depositFee = _rpWord(settings, abi.encodeWithSignature("getDepositFee()"));
        q.depositEnabled = depositPool() == pool
            && _rpWord(settings, abi.encodeWithSignature("getDepositEnabled()")) != 0
            && _rpCapacityReadable(pool);
        uint256 lastDeposit = registry.getUint(keccak256(abi.encodePacked("user.deposit.block", address(this))));
        uint256 delay_ = registry.getUint(keccak256(abi.encodePacked(keccak256("dao.protocol.setting.network"), "network.reth.deposit.delay")));
        q.canTransferReth = lastDeposit == 0 || (block.number > lastDeposit && block.number - lastDeposit > delay_);
    }

    function _rpRead(bytes calldata state) private view returns (RocketQuoteState memory q) {
        q = abi.decode(state, (RocketQuoteState));
        if (q.exchange != address(this) || !_isAsset(q.asset)) revert InvalidQuoteState();
    }

    function _rpNav(RocketQuoteState memory q) private view returns (uint256) {
        return q.liquid + IRETH(rETH()).getEthValue(q.locked);
    }

    function _rpAssets(RocketQuoteState memory q, uint256 shares) private view returns (uint256) {
        uint256 face = BetterMath._convertToAssetsDown(shares, _rpNav(q), q.supply, _decimalOffset());
        return _ethToAssetDown(q.asset, face);
    }

    function quoteAssets(bytes calldata state, uint256 shares) external view returns (uint256) {
        return _rpAssets(_rpRead(state), shares);
    }

    function quoteShareBalance(bytes calldata state) external view returns (uint256) {
        return _rpRead(state).holderShares;
    }

    function quoteTotalSupply(bytes calldata state) external view returns (uint256) {
        return _rpRead(state).supply;
    }

    function _rpCapacity(RocketQuoteState memory q) private pure returns (uint256) {
        if (!q.depositEnabled) return 0;
        if (q.capacityUsed < 0) return q.capacityLimit + uint256(-q.capacityUsed);
        uint256 used = uint256(q.capacityUsed);
        return q.capacityLimit > used ? q.capacityLimit - used : 0;
    }

    function _rpStake(RocketQuoteState memory q, uint256 amount, bool soft)
        private view returns (uint256 minted)
    {
        if (amount == 0) return 0;
        uint256 capacity = _rpCapacity(q);
        if (soft) amount = Math.min(amount, capacity);
        else if (amount > capacity) revert InsufficientDepositCapacity(capacity, amount);
        if (amount == 0) return 0;
        if (!q.depositEnabled || amount < q.minimumDeposit || q.depositFee > 1e18) {
            if (soft) return 0;
            revert InvalidQuoteState();
        }
        uint256 fee = Math.mulDiv(amount, q.depositFee, 1e18);
        minted = IRETH(rETH()).getRethValue(amount - fee);
        if (minted == 0) {
            if (soft) return 0;
            revert Slippage();
        }
        q.liquid -= amount;
        uint256 directCollateral = q.collateralTarget > q.rethCollateral
            ? Math.min(amount, q.collateralTarget - q.rethCollateral) : 0;
        q.rethCollateral += directCollateral;
        q.poolNet += _rpSigned(amount - directCollateral);
        q.capacityUsed += _rpSigned(amount - directCollateral);
    }

    function _rpDeposit(RocketQuoteState memory q, address token, uint256 amount, bool toHolder)
        private view returns (uint256 minted)
    {
        if (!_isAsset(token)) revert UnsupportedQuoteAsset(token);
        if (amount == 0) return 0;
        uint256 beforeNav = _rpNav(q);
        uint256 credited = _assetToEth(token, amount);
        if (token == weth()) q.liquid += amount;
        else q.locked += amount;
        minted = BetterMath._convertToSharesDown(credited, beforeNav, q.supply, _decimalOffset());
        q.supply += minted;
        if (toHolder) q.holderShares += minted;
        address beneficiary = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (beneficiary != address(0)) {
            uint256 fee = BetterMath._percentageOfWAD(minted, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this)));
            q.supply += fee;
            if (q.holder == beneficiary) q.holderShares += fee;
        }
        if (token == weth()) {
            uint256 target = Math.mulDiv(_rpNav(q), targetLiquidReservePercentage(), 1e18);
            if (q.liquid > target) q.locked += _rpStake(q, q.liquid - target, true);
        }
    }

    function _rpPay(RocketQuoteState memory q, uint256 amount) private view {
        if (q.asset == rETH()) {
            if (amount > q.locked) revert InsufficientLockedReserve(amount, q.locked);
            if (!q.canTransferReth) revert InvalidQuoteState();
            q.locked -= amount;
            return;
        }
        if (q.liquid < amount && q.locked != 0 && q.canTransferReth) {
            uint256 burn = Math.min(_rethForEthUp(amount - q.liquid), q.locked);
            uint256 received = IRETH(rETH()).getEthValue(burn);
            uint256 poolCollateral = q.poolNet > 0 ? uint256(q.poolNet) : 0;
            if (received <= q.rethCollateral + poolCollateral) {
                uint256 fromReth = Math.min(received, q.rethCollateral);
                q.rethCollateral -= fromReth;
                q.poolNet -= _rpSigned(received - fromReth);
                q.capacityUsed -= _rpSigned(received - fromReth);
                q.locked -= burn;
                q.liquid += received;
            }
        }
        if (q.liquid < amount) revert InsufficientLiquidReserve(amount, q.liquid);
        q.liquid -= amount;
    }

    function quoteTransition(bytes calldata state, Operation operation, uint256 amount)
        external view returns (bytes memory, uint256 amountIn, uint256 amountOut, uint256)
    {
        RocketQuoteState memory q = _rpRead(state);
        amountIn = amount;
        if (operation == Operation.ReceiveShares) {
            q.holderShares += amount;
            if (q.holderShares > q.supply) revert InvalidQuoteState();
            amountOut = amount;
        } else if (operation == Operation.DepositExactIn) {
            amountOut = _rpDeposit(q, q.asset, amount, true);
        } else {
            if (operation == Operation.WithdrawExactOut) {
                amountIn = BetterMath._convertToSharesUp(_assetToEth(q.asset, amount), _rpNav(q), q.supply, _decimalOffset());
                amountOut = amount;
            } else amountOut = _rpAssets(q, amount);
            if (amountIn > q.holderShares) revert InsufficientQuoteShares(amountIn, q.holderShares);
            q.holderShares -= amountIn;
            q.supply -= amountIn;
            _rpPay(q, amountOut);
        }
        return (abi.encode(q), amountIn, amountOut, _rpAssets(q, q.holderShares));
    }

    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amount)
        external view returns (bytes memory, uint256 minted, uint256)
    {
        RocketQuoteState memory q = _rpRead(state);
        minted = _rpDeposit(q, tokenIn, amount, false);
        return (abi.encode(q), minted, _rpAssets(q, q.holderShares));
    }

    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amount)
        external view returns (bytes memory, uint256 amountOut, uint256)
    {
        RocketQuoteState memory q = _rpRead(state);
        if (q.asset == weth() && tokenIn == rETH()) {
            q.locked += amount;
            amountOut = IRETH(rETH()).getEthValue(amount);
            _rpPay(q, amountOut);
        } else if (q.asset == rETH() && tokenIn == weth()) {
            q.liquid += amount;
            amountOut = _rpStake(q, amount, false);
            if (!q.canTransferReth) revert InvalidQuoteState();
        } else revert UnsupportedQuoteAsset(tokenIn);
        return (abi.encode(q), amountOut, _rpAssets(q, q.holderShares));
    }

}
