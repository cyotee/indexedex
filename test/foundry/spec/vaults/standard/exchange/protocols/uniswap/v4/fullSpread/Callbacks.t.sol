// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

interface IFullSpreadCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

contract UniswapV4FullSpreadStandardExchangeVault_Callbacks_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    function test_strangerCallbackReverts() public {
        vm.expectRevert(IVault.SettlementMismatch.selector);
        IFullSpreadCallback(address(vault)).unlockCallback("");
    }

    function test_uncommittedPayloadReverts() public {
        bytes memory payload_ = abi.encode(uint8(0), false, uint256(0), int256(0));
        vm.prank(address(pool));
        vm.expectRevert(IVault.SettlementMismatch.selector);
        IFullSpreadCallback(address(vault)).unlockCallback(payload_);
    }
}
