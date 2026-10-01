// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4FullSpreadPonsFamilyHookEquivalentInterfacesTest} from "./EquivalentInterfaces.t.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookNativeSettlementTest[]
contract UniswapV4FullSpreadPonsFamilyHookNativeSettlementTest is UniswapV4FullSpreadPonsFamilyHookEquivalentInterfacesTest {
    function _native() internal pure override returns (bool) { return true; }

    function test_nativeRejectedDomainUsesWethFace() public {
        _bootstrap();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(token0), address(token1)));
        vault.previewExchangeOut(token0, token1, 1e15);
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookNativeSettlementTest[]
