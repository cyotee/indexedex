// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    IBalancerV3StandardExchangeRouterPermit2Witness
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPermit2Witness.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

contract BalancerV3StandardExchangeRouter_Permit2WitnessFacet_Test is TestBase_BalancerV3StandardExchangeRouter {
    function test_permit2WitnessFacet_returnsExpectedWitnessTypeString() public view {
        string memory witnessTypeString =
            IBalancerV3StandardExchangeRouterPermit2Witness(address(seRouter)).WITNESS_TYPE_STRING();

        assertEq(
            witnessTypeString,
            string.concat(
                "Witness witness)",
                "TokenPermissions(address token,uint256 amount)",
                "Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)"
            )
        );
    }

    function test_permit2WitnessFacet_returnsExpectedWitnessTypehash() public view {
        bytes32 witnessTypehash =
            IBalancerV3StandardExchangeRouterPermit2Witness(address(seRouter)).WITNESS_TYPEHASH();

        assertEq(
            witnessTypehash,
            keccak256(
                "Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)"
            )
        );
    }
}
