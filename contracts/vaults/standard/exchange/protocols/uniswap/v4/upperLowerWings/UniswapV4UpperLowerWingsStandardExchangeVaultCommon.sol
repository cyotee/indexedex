// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "./UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultCommon[]
/// @notice Shared bounded dispatch. Only an active vault operation may authorize its manager callback.
library UniswapV4UpperLowerWingsStandardExchangeVaultCommon {
    using TransientStateLibrary for IPoolManager;
    enum Kind { Modify, Swap }
    struct Operation {
        Kind kind;
        uint8 slot;
        int24 lower;
        int24 upper;
        int256 quantity;
        bool zeroForOne;
        uint160 priceLimit;
    }
    function quoteRequest() internal view returns (Quote.Request memory request_) {
        Repo.Storage storage state = Repo._layout();
        request_.manager = state.manager;
        request_.key = state.key;
        request_.owner = address(this);
        request_.target0 = state.target0;
        request_.local0 = state.local0;
        request_.local1 = state.local1;
        request_.stepLimit = 512;
        for (uint256 i; i < 3; ++i) {
            Repo.Position storage owned = state.positions[i];
            if (owned.liquidity == 0) continue;
            request_.positions[request_.count++] = Quote.Position(owned.lower, owned.upper, Repo.salt(i));
        }
    }
    error MutationBudgetExceeded();
    error ManagerAlreadyUnlocked();
    function execute(Operation[] memory operations_) internal {
        Repo.Storage storage state = Repo._layout();
        if (!state.busy || state.callbackHash != 0) revert IUniswapV4UpperLowerWingsStandardExchangeVault.UnauthorizedCallback();
        if (state.manager.isUnlocked()) revert ManagerAlreadyUnlocked();
        if (operations_.length == 0 || operations_.length > 8 || uint256(state.mutations) + operations_.length > 16) {
            revert MutationBudgetExceeded();
        }
        state.mutations += uint8(operations_.length);
        bytes memory data = abi.encode(operations_);
        state.callbackHash = keccak256(data);
        state.manager.unlock(data);
        if (state.callbackHash != 0) revert IUniswapV4UpperLowerWingsStandardExchangeVault.UnauthorizedCallback();
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultCommon[]
