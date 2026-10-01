// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadPonsFamilyHookTransitionPlanner as Planner} from "./UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol";
import {UniswapV4FullSpreadPonsFamilyHookQuoteService as Quotes} from "./UniswapV4FullSpreadPonsFamilyHookQuoteService.sol";


import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {UniswapV4FullSpreadPonsFamilyHookPositionRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookPositionRepo.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookOutBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutBase.sol";

/// @notice CREATE3 delegate for heavy Out zap-out only (no rebalance / direct swap).
contract UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate is UniswapV4FullSpreadPonsFamilyHookOutBase {
    address private immutable SELF = address(this);

    function executeZapOutWithdrawal(address tokenOut, uint256 maximum, uint256 amountOut, address recipient, bool pretransferred)
        external returns (uint256 shares)
    {
        if (address(this) == SELF) revert AccountingMismatch();
        if (amountOut == 0) revert UniswapV4Exchange_ZeroAmount();
        Types.Snapshot memory state = _snapshot(0, 0);
        Types.Placement memory placement;
        (shares, placement) = _linearExitPlan(state, tokenOut == _token0(), amountOut);
        if (shares > maximum) revert UniswapV4ExchangeOut_InsufficientInput();
        uint256 delivered;
        if (pretransferred) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            delivered = _pretransferCredit(IERC20(address(this)), maximum);
            _requireDelivered(shares, delivered);
        }
        _commitExecutionPlan(keccak256(abi.encode(state, shares, amountOut, placement)),
            tokenOut == _token0() ? amountOut : 0, tokenOut == _token1() ? amountOut : 0);
        if (state.idle) {
            _collectManagedFeesIfIdle();
            _burnCenterLiquidityForShares(shares, state.book.supply);
        }
        uint256 balance = _localBalance(tokenOut);
        if (balance < amountOut) revert UniswapV4Exchange_InsufficientLocalReserve(tokenOut, amountOut, balance);
        ERC20Repo._burn(pretransferred ? address(this) : msg.sender, shares);
        if (pretransferred) _refundUnusedShares(delivered, shares, msg.sender);
        _transferCurrency(tokenOut, recipient, amountOut);
        if (state.idle) {
            _commitExecutionPlan(keccak256(abi.encode(placement)), 0, 0);
            _executePlacement(placement);
            _verifyState(placement.afterState);
        }
        _syncVaultReserves();
    }
}
