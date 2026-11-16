// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {OperableRepo} from "@crane/contracts/access/operable/OperableRepo.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {UniswapV4ProtocolAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareRepo.sol";
import {UniswapV4SinglePositionAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol";
import {UniswapV4FullSpreadStandardExchangeVaultTypes as Types} from "./UniswapV4FullSpreadStandardExchangeVaultTypes.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo as Repo} from "./UniswapV4FullSpreadStandardExchangeVaultRepo.sol";
import {UniswapV4FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV4FullSpreadStandardExchangeVaultPlanner.sol";
import {UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation as Prep} from "./UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol";
import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IStandardExchangeBundleIn} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

library UniswapV4FullSpreadStandardExchangeVaultExecution {
    using BetterSafeERC20 for IERC20;

    function onCallback(bytes calldata data_) external returns (bytes memory) {
        if (msg.sender != address(UniswapV4ProtocolAwareRepo._poolManager())) revert IVault.SettlementMismatch();
        if (!Repo._layoutStruct().guardHeld) revert IVault.SettlementMismatch();
        Prep.consume(data_);
        (uint8 kind_, bool zeroForOne_, uint256 amountIn_, int256 liquidityDelta_) =
            abi.decode(data_, (uint8, bool, uint256, int256));
        (uint256 fee0_, uint256 fee1_) =
            Prep.run(Types.Action(Types.ActionKind(kind_), zeroForOne_, amountIn_, liquidityDelta_));
        Prep.settle();
        return abi.encode(fee0_, fee1_);
    }

    function exchangeIn(
        address tokenIn_,
        uint256 amountIn_,
        address tokenOut_,
        uint256 minOut_,
        address recipient_,
        bool pretransferred_
    ) internal returns (uint256 amountOut_, uint256 amountRefunded_) {
        _open(true, pretransferred_);
        (address face0_, address face1_) = _faces();
        if (tokenIn_ == address(this)) {
            _requireShares(amountIn_);
        } else if (pretransferred_ && amountIn_ > _unbooked(tokenIn_, tokenIn_ == face0_ ? 0 : 1)) {
            if (tokenOut_ == address(this) && ERC20Repo._totalSupply() == 0) revert IVault.MinLiquidityNotMet();
            amountRefunded_ = _refundUnbooked(tokenIn_, tokenIn_ == face0_ ? 0 : 1);
            _close();
            if (minOut_ != 0) revert IStandardExchangeErrors.AmountOutNotMet(minOut_, 0);
            return (0, amountRefunded_);
        } else {
            _fundOne(tokenIn_, amountIn_, pretransferred_, tokenIn_ == face0_ ? 0 : 1);
        }
        Types.Plan memory plan_ = Planner.planIn(tokenIn_, amountIn_, tokenOut_);
        if (plan_.kind == Types.Kind.Unsupported) revert IVault.TokenNotExchangeable();
        if (plan_.kind == Types.Kind.OneTokenExit && plan_.failed) {
            revert IStandardExchangeErrors.AmountOutNotMet(minOut_, 0);
        }
        if (plan_.failed) revert IVault.MinLiquidityNotMet();
        if (plan_.kind != Types.Kind.OneTokenExit && plan_.amountOut < minOut_) {
            revert IStandardExchangeErrors.AmountOutNotMet(minOut_, plan_.amountOut);
        }
        uint256 wantedBefore_;
        if (plan_.kind == Types.Kind.OneTokenExit) wantedBefore_ = IERC20(tokenOut_).balanceOf(address(this));
        _run(plan_);
        if (plan_.kind == Types.Kind.OneSidedMint) {
            _mint(plan_, recipient_);
            _pay(tokenIn_, msg.sender, plan_.amountRefunded);
        } else if (plan_.kind == Types.Kind.PassThrough) {
            _pay(tokenOut_, recipient_, plan_.amountOut);
            _pay(tokenIn_, msg.sender, plan_.amountRefunded);
        } else {
            uint256 grown_ = IERC20(tokenOut_).balanceOf(address(this)) - wantedBefore_;
            uint256 feeRemainder_ = tokenOut_ == face0_ ? plan_.feeRemainder0 : plan_.feeRemainder1;
            uint256 bookedClaim_ = tokenOut_ == face0_ ? plan_.bookedClaim0 : plan_.bookedClaim1;
            if (grown_ < feeRemainder_) revert IStandardExchangeErrors.AmountOutNotMet(minOut_, 0);
            uint256 receipt_ = grown_ - feeRemainder_ + bookedClaim_;
            if (receipt_ < minOut_) revert IStandardExchangeErrors.AmountOutNotMet(minOut_, receipt_);
            plan_.amountOut = receipt_;
            ERC20Repo._burn(msg.sender, plan_.sharesBurned);
            _pay(tokenOut_, recipient_, receipt_);
            _bookExit(plan_);
        }
        amountOut_ = plan_.amountOut;
        amountRefunded_ = plan_.amountRefunded;
        _close();
    }

    function bundleIn(uint256 amount0_, uint256 amount1_, uint256 minOut_, address recipient_, bool pretransferred_)
        internal
        returns (uint256 amountOut_, uint256 refund0_, uint256 refund1_)
    {
        _open(false, pretransferred_);
        (address face0_, address face1_) = _faces();
        if (pretransferred_) {
            if (amount0_ > _unbooked(face0_, 0) || amount1_ > _unbooked(face1_, 1)) revert();
            if (amount0_ != 0) Repo._setReserved(0, amount0_);
            if (amount1_ != 0) Repo._setReserved(1, amount1_);
        } else {
            _pull(face0_, amount0_, 0);
            _pull(face1_, amount1_, 1);
        }
        Types.Plan memory plan_ = Planner.planBundleIn(amount0_, amount1_);
        if (plan_.failed) revert IVault.MinLiquidityNotMet();
        if (plan_.amountOut < minOut_) revert IStandardExchangeBundleIn.MinAmountNotMetAt(0, minOut_, plan_.amountOut);
        _run(plan_);
        _mint(plan_, recipient_);
        _pay(face0_, msg.sender, plan_.refund0);
        _pay(face1_, msg.sender, plan_.refund1);
        emit IVault.PairDeposited(msg.sender);
        amountOut_ = plan_.amountOut;
        refund0_ = plan_.refund0;
        refund1_ = plan_.refund1;
        _close();
    }

    function bundleOut(
        uint256 shares_,
        address recipient_,
        uint256 min0_,
        uint256 min1_,
        uint256 index0_,
        uint256 index1_
    ) internal returns (uint256 out0_, uint256 out1_) {
        _open(false, false);
        _requireShares(shares_);
        Types.Plan memory plan_ = Planner.planBundleOut(shares_);
        if (plan_.out0 < min0_) revert IStandardExchangeBundleIn.MinAmountNotMetAt(index0_, min0_, plan_.out0);
        if (plan_.out1 < min1_) revert IStandardExchangeBundleIn.MinAmountNotMetAt(index1_, min1_, plan_.out1);
        _run(plan_);
        ERC20Repo._burn(msg.sender, shares_);
        (address face0_, address face1_) = _faces();
        _pay(face0_, recipient_, plan_.out0);
        _pay(face1_, recipient_, plan_.out1);
        _bookExit(plan_);
        emit IVault.PairRedeemed(msg.sender);
        out0_ = plan_.out0;
        out1_ = plan_.out1;
        _close();
    }

    function maintain(address token_, uint256 amount_, bool pretransferred_, bool donation_) internal {
        if (donation_ && ERC20Repo._totalSupply() == 0) revert();
        _open(false, false);
        (address face0_, address face1_) = _faces();
        uint256 donate0_;
        uint256 donate1_;
        if (donation_ && token_ == address(this)) {
            _requireShares(amount_);
            ERC20Repo._burn(msg.sender, amount_);
        } else if (donation_ && amount_ != 0) {
            uint256 index_ = token_ == face0_ ? 0 : 1;
            if (pretransferred_ && amount_ > _unbooked(token_, index_)) {
                _refundUnbooked(token_, index_);
            } else {
                if (!pretransferred_) _pull(token_, amount_, index_);
                else Repo._setReserved(index_, amount_);
                if (index_ == 0) donate0_ = amount_;
                else donate1_ = amount_;
            }
        }
        Types.Plan memory plan_ = Planner.planMaintenance(donate0_, donate1_, donation_);
        if (plan_.failed) revert IVault.MinLiquidityNotMet();
        _run(plan_);
        if (plan_.actionCount != 0 || donate0_ != 0 || donate1_ != 0) {
            Repo._setBooked(0, IERC20(face0_).balanceOf(address(this)));
            Repo._setBooked(1, IERC20(face1_).balanceOf(address(this)));
        }
        if (donation_) emit IVault.Donation();
        if (plan_.emitCompounded) emit IVault.Compounded();
        _close();
    }

    function appoint(address operator_, bool status_) internal {
        OperableRepo._setOperatorStatus(operator_, status_);
    }

    function appointFor(bytes4 func_, address operator_, bool status_) internal {
        OperableRepo._layoutStruct().isOperatorFor[func_][operator_] = status_;
        emit IOperable.NewFunctionOperatorStatus(operator_, func_, status_);
    }

    function _open(bool exchangeIn_, bool pretransferred_) private {
        IPoolManager manager_ = UniswapV4ProtocolAwareRepo._poolManager();
        bool unlocked_ = TransientStateLibrary.isUnlocked(manager_);
        if (!exchangeIn_ && unlocked_) revert IVault.ManagerAlreadyUnlocked();
        if (Repo._layoutStruct().guardHeld) revert IVault.ReentrantOperation();
        if (unlocked_) {
            Repo.Storage storage state_ = Repo._layoutStruct();
            if (!state_.initialized || state_.callbackHash != bytes32(0) || state_.reserved[0] != 0 || state_.reserved[1] != 0
                || !Prep.ownDeltasZero()) revert();
            if (pretransferred_ || msg.sender.code.length == 0) revert IVault.InvalidUnlockedContext();
        }
        Repo._layoutStruct().guardHeld = true;
    }

    function _close() private {
        Repo._setReserved(0, 0);
        Repo._setReserved(1, 0);
        Repo._layoutStruct().guardHeld = false;
        if (Repo._layoutStruct().callbackHash != bytes32(0)) revert IVault.SettlementMismatch();
    }

    function _run(Types.Plan memory plan_) private {
        IPoolManager manager_ = UniswapV4ProtocolAwareRepo._poolManager();
        bool unlocked_ = TransientStateLibrary.isUnlocked(manager_);
        for (uint256 i_; i_ < plan_.actionCount; ++i_) {
            Types.Action memory action_ = plan_.actions[i_];
            (uint256 fee0_, uint256 fee1_) = unlocked_ ? _direct(action_) : _locked(manager_, action_);
            if (action_.kind == Types.ActionKind.Modify && action_.liquidityDelta > 0) {
                if (fee0_ != 0) Repo._setBooked(0, Repo._booked(0) + fee0_);
                if (fee1_ != 0) Repo._setBooked(1, Repo._booked(1) + fee1_);
            }
            if (!unlocked_ && TransientStateLibrary.isUnlocked(manager_)) revert IVault.SettlementMismatch();
        }
    }

    function _locked(IPoolManager manager_, Types.Action memory action_) private returns (uint256, uint256) {
        bytes memory payload_ = Prep.payload(action_);
        Prep.commit(payload_);
        return abi.decode(manager_.unlock(payload_), (uint256, uint256));
    }

    function _direct(Types.Action memory action_) private returns (uint256 fee0_, uint256 fee1_) {
        (fee0_, fee1_) = Prep.run(action_);
        Prep.settle();
    }

    function _mint(Types.Plan memory plan_, address recipient_) private {
        if (plan_.mintFloor) ERC20Repo._mint(address(0), Types.MIN_SHARES);
        if (plan_.feeShares != 0) {
            ERC20Repo._mint(address(IVaultFeeOracleQuery(address(StandardVaultRepo._feeOracle())).feeTo()), plan_.feeShares);
        }
        if (plan_.netShares != 0) ERC20Repo._mint(recipient_, plan_.netShares);
    }

    function _bookExit(Types.Plan memory plan_) private {
        Repo._setBooked(0, Repo._booked(0) - plan_.bookedClaim0 + plan_.feeRemainder0);
        Repo._setBooked(1, Repo._booked(1) - plan_.bookedClaim1 + plan_.feeRemainder1);
    }

    function _fundOne(address token_, uint256 amount_, bool pretransferred_, uint256 index_) private {
        if (pretransferred_) {
            Repo._setReserved(index_, amount_);
            return;
        }
        _pull(token_, amount_, index_);
    }

    function _pull(address token_, uint256 amount_, uint256 index_) private {
        if (amount_ == 0) return;
        IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);
        Repo._setReserved(index_, Repo._reserved(index_) + amount_);
    }

    function _refundUnbooked(address token_, uint256 index_) private returns (uint256 amount_) {
        amount_ = _unbooked(token_, index_);
        _pay(token_, msg.sender, amount_);
    }

    function _pay(address token_, address to_, uint256 amount_) private {
        if (amount_ == 0) return;
        IERC20(token_).safeTransfer(to_, amount_);
    }

    function _requireShares(uint256 amount_) private view {
        uint256 balance_ = ERC20Repo._balanceOf(msg.sender);
        if (balance_ < amount_) revert IERC20Errors.ERC20InsufficientBalance(msg.sender, balance_, amount_);
    }

    function _unbooked(address token_, uint256 index_) private view returns (uint256) {
        return IERC20(token_).balanceOf(address(this)) - Repo._booked(index_) - Repo._reserved(index_);
    }

    function _faces() private view returns (address face0_, address face1_) {
        PoolKey memory key_ = UniswapV4SinglePositionAwareRepo._poolKey();
        address weth_ = address(WETHAwareRepo._weth());
        face0_ = Currency.unwrap(key_.currency0);
        if (face0_ == address(0)) face0_ = weth_;
        face1_ = Currency.unwrap(key_.currency1);
        if (face1_ == address(0)) face1_ = weth_;
    }
}
