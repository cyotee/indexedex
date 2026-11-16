// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {
    UniswapV4TwapOracleFactoryService
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapOracleFactoryService.sol";

/// @title Phase_05_Stage_02_UniswapV4TwapOracle
/// @notice CREATE3 TWAP facet + DFPkg + adapter factory, then canonical PoolManager instance.
/// @dev Not a vault. Do not `deployVault` / vault-registry. Instance is `deployOracle(PkgArgs)`.
library Phase_05_Stage_02_UniswapV4TwapOracle {
    using UniswapV4TwapOracleFactoryService for ICreate3FactoryProxy;

    function execute(LaunchState storage s) internal {
        address poolManager = RobinhoodCanonicalLib.poolManager();
        require(poolManager != address(0) && poolManager.code.length > 0, "Phase 05-02: PoolManager pin");

        s.twapOracleFacet = s.create3Factory.deployUniswapV4MultiPoolTwapOracleFacet();
        s.twapOraclePkg =
            s.create3Factory.deployUniswapV4MultiPoolTwapOracleDFPkg(s.twapOracleFacet, s.diamondPackageFactory);
        s.twapAdapterFactory = address(s.create3Factory.deployUniswapV4TwapAdapterFactory());
        s.twapOracle = s.twapOraclePkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: poolManager})
        );
        require(address(s.twapOracle).code.length > 0, "Phase 05-02: twapOracle");
        require(s.twapOracle.poolManager() == poolManager, "Phase 05-02: twapOracle.poolManager");
    }
}
