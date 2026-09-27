// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    SeMatrix_RebasingAwareFixture
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_RebasingAwareFixture.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice D20: weighted × RebasingAwareERC4626 (COMPATIBLE). Face: an 18-decimal hermetic asset held in
///         custody by the production RebasingAwareERC4626 package (SE shares are 28-decimal: asset 18 +
///         offset 10); the custody SE rejects asset pretransfer, the hook uses the pull route (PRD §5).
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_RebasingAwareERC4626 is UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior {
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_RebasingAwareFixture f = new SeMatrix_RebasingAwareFixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
}
