// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4MultiPoolTwapOracleTarget
} from "contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol";

contract UniswapV4MultiPoolTwapOracleFacet is UniswapV4MultiPoolTwapOracleTarget, IFacet {
    bytes4 internal constant UPDATE_ONE_SELECTOR =
        bytes4(keccak256("update((address,address,uint24,int24,address))"));
    bytes4 internal constant UPDATE_MANY_SELECTOR =
        bytes4(keccak256("update((address,address,uint24,int24,address)[])"));

    function facetName() public pure returns (string memory name) {
        return type(UniswapV4MultiPoolTwapOracleFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4MultiPoolTwapOracle).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](11);
        funcs[0] = IUniswapV4MultiPoolTwapOracle.poolManager.selector;
        funcs[1] = IUniswapV4MultiPoolTwapOracle.MAX_ABS_TICK_MOVE.selector;
        funcs[2] = UPDATE_ONE_SELECTOR;
        funcs[3] = UPDATE_MANY_SELECTOR;
        funcs[4] = IUniswapV4MultiPoolTwapOracle.increaseCardinalityNext.selector;
        funcs[5] = IUniswapV4MultiPoolTwapOracle.observe.selector;
        funcs[6] = IUniswapV4MultiPoolTwapOracle.consult.selector;
        funcs[7] = IUniswapV4MultiPoolTwapOracle.getPoolKey.selector;
        funcs[8] = IUniswapV4MultiPoolTwapOracle.getState.selector;
        funcs[9] = IUniswapV4MultiPoolTwapOracle.getObservation.selector;
        funcs[10] = IUniswapV4MultiPoolTwapOracle.writeAge.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
