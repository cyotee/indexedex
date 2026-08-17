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

/// @title Stage_05_LeafPoolsAndSEs
/// @notice Five fixture Uni V4 pools + SEs + RPs (PRD §2.5).
library Stage_05_LeafPoolsAndSEs {
    function execute(LaunchState storage s, address owner_) internal {
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());
        address seeder = PoolSeedLib.ensureSeeder(s.create3Factory, pm);
        s.v4Seeder = seeder;
        _topUp(s.ttUSDG, owner_);
        _topUp(s.ttUSDE, owner_);
        _topUp(s.ttNVDA, owner_);
        _topUp(s.ttMSFT, owner_);
        _topUp(s.ttAAPL, owner_);
        _topUp(s.ttGOOGL, owner_);
        _topUp(s.ttAMZN, owner_);
        _topUp(s.ttMETA, owner_);
        _topUp(s.ttTSLA, owner_);
        _topUp(s.ttSMH, owner_);
        _topUp(s.ttSPY, owner_);
        _topUp(s.ttVTI, owner_);
        _topUp(s.ttQQQ, owner_);
        PoolSeedLib.wrapWeth(owner_, 5_000 ether);

        address weth = RobinhoodCanonicalLib.weth();
        (s.seNvdaUsdg, s.rpNvdaUsdg) = _poolSeRp(s, seeder, s.ttNVDA, s.ttUSDG, s.ttNVDA, FixtureEconomics.TT_TT_SEED);
        (s.seSpyUsdg, s.rpSpyUsdg) = _poolSeRp(s, seeder, s.ttSPY, s.ttUSDG, s.ttSPY, FixtureEconomics.TT_TT_SEED);
        // TTDOL-Q 3/3: each RP rates shares → the pairToken that SE actually holds.
        (s.seUsdeWeth, s.rpUsdeWeth) =
            _poolSeRp(s, seeder, s.ttUSDE, weth, s.ttUSDE, FixtureEconomics.WETH_POOL_SEED);
        (s.seUsdgUsde, s.rpUsdgUsde) =
            _poolSeRp(s, seeder, s.ttUSDG, s.ttUSDE, s.ttUSDG, FixtureEconomics.TT_TT_SEED);
        (s.seUsdgWeth, s.rpUsdgWeth) =
            _poolSeRp(s, seeder, s.ttUSDG, weth, weth, FixtureEconomics.WETH_POOL_SEED);
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
