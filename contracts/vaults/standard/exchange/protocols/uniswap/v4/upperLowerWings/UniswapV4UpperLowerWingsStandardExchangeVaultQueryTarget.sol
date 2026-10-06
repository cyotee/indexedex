// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultCommon as Common} from "./UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "./UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultQueryTarget[]
contract UniswapV4UpperLowerWingsStandardExchangeVaultQueryTarget is IUniswapV4UpperLowerWingsStandardExchangeVault {
    function poolManager() public view returns (IPoolManager) { return Repo._layout().manager; }
    function poolKey() public view returns (PoolKey memory) { return Repo._layout().key; }
    function targetToken() public view returns (address) {
        Repo.Storage storage state = Repo._layout();
        return Currency.unwrap(state.target0 ? state.key.currency0 : state.key.currency1);
    }
    function localReserves() public view returns (uint256 amount0, uint256 amount1) {
        Repo.Storage storage state = Repo._layout();
        return (state.local0, state.local1);
    }
    function position(uint8 slot_) public view returns (int24 lower, int24 upper, uint128 liquidity, bytes32 salt) {
        Repo.Position storage owned = Repo._layout().positions[slot_];
        return (owned.lower, owned.upper, owned.liquidity, Repo.salt(slot_));
    }
    function liquidationValue() public view returns (Quote.Result memory) {
        Repo.Storage storage state = Repo._layout();
        if (!state.initialized) revert NotInitialized();
        if (state.busy) revert ReentrantOperation();
        return Quote.quote(Common.quoteRequest());
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultQueryTarget[]
