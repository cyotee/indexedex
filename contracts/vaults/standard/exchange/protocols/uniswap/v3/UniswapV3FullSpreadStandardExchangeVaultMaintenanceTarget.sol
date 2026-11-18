// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {OperableRepo} from "@crane/contracts/access/operable/OperableRepo.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from "./UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV3FullSpreadStandardExchangeVaultPlanner.sol";
import {UniswapV3FullSpreadStandardExchangeVaultRepo as Repo} from "./UniswapV3FullSpreadStandardExchangeVaultRepo.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";

contract UniswapV3FullSpreadStandardExchangeVaultMaintenanceTarget is
    UniswapV3FullSpreadStandardExchangeVaultCommon, ReentrancyLockModifiers
{
    using SafeERC20 for IERC20;

    modifier onlyLiveOwner() {
        if (msg.sender != address(StandardVaultRepo._feeOracle().feeTo())) revert IOperable.NotOperator(msg.sender);
        _;
    }

    modifier onlyMaintenanceOperator() {
        if (msg.sender != address(StandardVaultRepo._feeOracle().feeTo())
            && !OperableRepo._isOperator(msg.sender) && !OperableRepo._isFunctionOperator(msg.sig, msg.sender)) {
            revert IOperable.NotOperator(msg.sender);
        }
        _;
    }

    function donate(address token_, uint256 amount_, bool pretransferred_) external nonReentrant onlyMaintenanceOperator {
        if (ERC20Repo._totalSupply() == 0) revert IVault.MinLiquidityNotMet();
        if (token_ != address(this) && token_ != _token0() && token_ != _token1()) revert IVault.TokenNotExchangeable();
        if (pretransferred_) LocalCreditLib.requirePretransferCaller(msg.sender);
        uint256 donate0_;
        uint256 donate1_;
        if (token_ == address(this)) {
            _requireShares(amount_);
            ERC20Repo._burn(msg.sender, amount_);
        } else {
            uint256 index_ = token_ == _token0() ? 0 : 1;
            uint256 available_ = _unbooked(token_, index_);
            if (pretransferred_ && amount_ > available_) {
                if (available_ != 0) IERC20(token_).safeTransfer(msg.sender, available_);
            } else {
                _fund(token_, amount_, index_, pretransferred_);
                if (index_ == 0) donate0_ = amount_;
                else donate1_ = amount_;
            }
        }
        _maintain(donate0_, donate1_, true);
        emit IVault.Donation();
    }

    function compound() external nonReentrant onlyMaintenanceOperator {
        _maintain(0, 0, false);
    }

    function setOperator(address operator_, bool status_) external nonReentrant onlyLiveOwner returns (bool) {
        _requireNotDisabled();
        OperableRepo._setOperatorStatus(operator_, status_);
        return true;
    }

    function setOperatorFor(bytes4 selector_, address operator_, bool status_)
        external nonReentrant onlyLiveOwner returns (bool)
    {
        _requireNotDisabled();
        // The canonical setter checks a stored owner; this product's owner is live feeTo().
        OperableRepo._layoutStruct().isOperatorFor[selector_][operator_] = status_;
        emit IOperable.NewFunctionOperatorStatus(operator_, selector_, status_);
        return true;
    }

    function _maintain(uint256 donate0_, uint256 donate1_, bool donation_) private {
        Planner.PositionRead memory position_ = Planner.readPosition();
        Repo.Storage storage state_ = Repo._layout();
        uint256 eligible0_ = donate0_ + state_.booked[0] + position_.fee0;
        uint256 eligible1_ = donate1_ + state_.booked[1] + position_.fee1;
        // Stray custody by itself cannot make compound eligible or cause an event.
        if (eligible0_ == 0 && eligible1_ == 0) return;
        if (position_.fee0 != 0 || position_.fee1 != 0) _collectFees();
        Planner.Plan memory plan_ = Planner.planMaintenance(donate0_, donate1_, donation_);
        if (plan_.failed) revert IVault.MinLiquidityNotMet();
        state_.reserved[0] += state_.booked[0];
        state_.reserved[1] += state_.booked[1];
        state_.booked[0] = 0;
        state_.booked[1] = 0;
        _add(plan_);
        // Only a qualifying operation books all actual custody, including transfers
        // arriving during its pool/token calls. Nothing is refunded as maintenance dust.
        state_.booked[0] = IERC20(_token0()).balanceOf(address(this));
        state_.booked[1] = IERC20(_token1()).balanceOf(address(this));
        state_.reserved[0] = 0;
        state_.reserved[1] = 0;
        _close();
        if (plan_.emitCompounded) emit IVault.Compounded();
    }
}
