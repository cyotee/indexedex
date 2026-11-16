// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";

interface IUniswapV4MultiPoolTwapOracleDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet twapOracleFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        address poolManager;
    }

    event OracleDeployed(address instance, address poolManager);

    function deployOracle(PkgArgs calldata args) external returns (IUniswapV4MultiPoolTwapOracle oracle);
}
