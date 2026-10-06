// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultCommon as Common} from "./UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultExecutionDelegate[]
/// @notice Authenticated callback facet; settles actual caller deltas once, including accrued fees.
contract UniswapV4UpperLowerWingsStandardExchangeVaultExecutionDelegate is IUnlockCallback, IFacet {
    using SafeERC20 for IERC20;
    using BalanceDeltaLibrary for BalanceDelta;
    error InvalidPositionMutation();
    error InvalidSwap();
    error SettlementMismatch();
    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        Repo.Storage storage state = Repo._layout();
        if (msg.sender != address(state.manager) || !state.busy || state.callbackHash == 0
            || state.callbackHash != keccak256(data_)) revert IUniswapV4UpperLowerWingsStandardExchangeVault.UnauthorizedCallback();
        state.callbackHash = 0;
        Common.Operation[] memory operations = abi.decode(data_, (Common.Operation[]));
        for (uint256 i; i < operations.length; ++i) {
            Common.Operation memory operation = operations[i];
            BalanceDelta delta;
            if (operation.kind == Common.Kind.Modify) delta = _modify(state, operation);
            else {
                if (operation.quantity >= 0) revert InvalidSwap();
                delta = state.manager.swap(state.key,
                    SwapParams(operation.zeroForOne, operation.quantity, operation.priceLimit), "");
            }
            state.local0 = _settle(state, state.key.currency0, state.local0, delta.amount0());
            state.local1 = _settle(state, state.key.currency1, state.local1, delta.amount1());
        }
        return "";
    }
    function _modify(Repo.Storage storage state_, Common.Operation memory operation_) private returns (BalanceDelta delta_) {
        if (operation_.slot >= 3) revert InvalidPositionMutation();
        Repo.Position storage position = state_.positions[operation_.slot];
        if (position.liquidity != 0 && (position.lower != operation_.lower || position.upper != operation_.upper)) {
            revert InvalidPositionMutation();
        }
        int256 next = int256(uint256(position.liquidity)) + operation_.quantity;
        if (next < 0 || uint256(next) > uint256(uint128(type(int128).max))) revert InvalidPositionMutation();
        (delta_,) = state_.manager.modifyLiquidity(state_.key,
            ModifyLiquidityParams(operation_.lower, operation_.upper, operation_.quantity, Repo.salt(operation_.slot)), "");
        position.lower = operation_.lower;
        position.upper = operation_.upper;
        position.liquidity = uint128(uint256(next));
    }
    function _settle(Repo.Storage storage state_, Currency currency_, uint256 local_, int128 delta_) private returns (uint256) {
        if (delta_ < 0) {
            uint256 amount = uint256(-int256(delta_));
            uint256 remaining = local_ - amount;
            state_.manager.sync(currency_);
            IERC20(Currency.unwrap(currency_)).safeTransfer(address(state_.manager), amount);
            if (state_.manager.settle() != amount) revert SettlementMismatch();
            return remaining;
        }
        if (delta_ > 0) {
            uint256 beforeBalance = IERC20(Currency.unwrap(currency_)).balanceOf(address(this));
            state_.manager.take(currency_, address(this), uint128(delta_));
            if (IERC20(Currency.unwrap(currency_)).balanceOf(address(this)) - beforeBalance != uint128(delta_)) {
                revert SettlementMismatch();
            }
            return local_ + uint128(delta_);
        }
        return local_;
    }
    function facetName() public pure returns (string memory) { return type(UniswapV4UpperLowerWingsStandardExchangeVaultExecutionDelegate).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1); ids_[0] = type(IUnlockCallback).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](1); selectors_[0] = IUnlockCallback.unlockCallback.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultExecutionDelegate[]
