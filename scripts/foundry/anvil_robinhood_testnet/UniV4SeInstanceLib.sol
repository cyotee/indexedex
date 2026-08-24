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
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";

/// @title UniV4SeInstanceLib
/// @notice Required `DTF`/`TTWETH` SE plus the three SEs that feed `TTDOL-Q`.
library UniV4SeInstanceLib {
    function execute(LaunchState storage s, address owner_) internal {
        require(s.ttWETH != address(0) && s.ttWETH.code.length > 0, "Stage_05: TTWETH required");
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());
        address seeder = PoolSeedLib.ensureSeeder(s.create3Factory, pm);
        s.v4Seeder = seeder;
        _topUp(s.ttUSDG, owner_);
        _topUp(s.ttUSDE, owner_);
        _topUp(s.ttWETH, owner_);

        address ttweth = s.ttWETH;
        // TTDOL-Q 3/3: each RP rates shares → the pairToken that SE actually holds.
        (s.seUsdeWeth, s.rpUsdeWeth) =
            _poolSeRp(s, seeder, s.ttUSDE, ttweth, s.ttUSDE, FixtureEconomics.WETH_POOL_SEED);
        (s.seUsdgUsde, s.rpUsdgUsde) =
            _poolSeRp(s, seeder, s.ttUSDG, s.ttUSDE, s.ttUSDG, FixtureEconomics.TT_TT_SEED);
        (s.seUsdgWeth, s.rpUsdgWeth) =
            _poolSeRp(s, seeder, s.ttUSDG, ttweth, ttweth, FixtureEconomics.WETH_POOL_SEED);
        deployTtrichWeth(s, owner_);
    }

    /// @notice Required architecture SE. Resume-safe if an older 05 artifact omitted it.
    function deployTtrichWeth(LaunchState storage s, address owner_) internal {
        require(s.ttRICH != address(0) && s.ttRICH.code.length > 0, "Stage_05: DTF required");
        require(s.ttWETH != address(0) && s.ttWETH.code.length > 0, "Stage_05: TTWETH required");
        if (s.seRichWeth != address(0) && s.seRichWeth.code.length > 0) return;
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());
        address seeder = s.v4Seeder;
        if (seeder == address(0)) {
            seeder = PoolSeedLib.ensureSeeder(s.create3Factory, pm);
            s.v4Seeder = seeder;
        }
        _topUp(s.ttWETH, owner_);
        _topUp(s.ttRICH, owner_);
        (s.seRichWeth, s.rpRichWeth) =
            _poolSeRp(s, seeder, s.ttRICH, s.ttWETH, s.ttRICH, FixtureEconomics.WETH_POOL_SEED);
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
        se = s.uniV4SePkg.deployVault(key, FixtureEconomics.SE_WIDTH_MULTIPLIER);
        rp = address(s.rateProviderPkg.deployRateProvider(IStandardExchange(se), IERC20(pairToken)));
    }

    function _topUp(address token, address owner_) private {
        uint256 have = IERC20(token).balanceOf(owner_);
        if (have < FixtureEconomics.PREMINT) {
            IERC20MintBurn(token).mint(owner_, FixtureEconomics.PREMINT - have);
        }
    }
}
