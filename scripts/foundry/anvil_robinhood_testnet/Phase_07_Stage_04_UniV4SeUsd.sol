// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {PoolSeedLib} from "./PoolSeedLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

/// @title Phase_07_Stage_04_UniV4SeUsd
/// @notice Three Uni V4 SEs for TTDOL-Q. No DETF deploy.
library Phase_07_Stage_04_UniV4SeUsd {
    function execute(LaunchState storage s, address owner_) internal {
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());
        address seeder = PoolSeedLib.ensureSeeder(s.create3Factory, pm);
        s.v4Seeder = seeder;
        _topUp(s.ttUSDG, owner_);
        _topUp(s.ttUSDE, owner_);
        _topUp(s.ttWETH, owner_);
        address ttweth = s.ttWETH;
        (s.seUsdeWeth, s.rpUsdeWeth) = _poolSeRp(s, seeder, s.ttUSDE, ttweth, s.ttUSDE, FixtureEconomics.WETH_POOL_SEED);
        (s.seUsdgUsde, s.rpUsdgUsde) = _poolSeRp(s, seeder, s.ttUSDG, s.ttUSDE, s.ttUSDG, FixtureEconomics.TT_TT_SEED);
        (s.seUsdgWeth, s.rpUsdgWeth) = _poolSeRp(s, seeder, s.ttUSDG, ttweth, ttweth, FixtureEconomics.WETH_POOL_SEED);
    }

    function _poolSeRp(
        LaunchState storage s,
        address seeder,
        address tokenA,
        address tokenB,
        address pairToken,
        uint256 seed
    ) private returns (address se, address rp) {
        PoolKey memory key = PoolSeedLib.buildKey(tokenA, tokenB);
        PoolSeedLib.initAndSeed(IPoolManager(RobinhoodCanonicalLib.poolManager()), seeder, key, seed, seed);
        se = s.uniV4SePkg.deployVault(key);
        rp = address(s.rateProviderPkg.deployRateProvider(IStandardExchange(se), IERC20(pairToken)));
    }

    function _topUp(address token, address owner_) private {
        uint256 have = IERC20(token).balanceOf(owner_);
        if (have < FixtureEconomics.PREMINT) {
            IERC20MintBurn(token).mint(owner_, FixtureEconomics.PREMINT - have);
        }
    }
}
