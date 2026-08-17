// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {PoolSeedLib} from "./PoolSeedLib.sol";
import {RichnessLib} from "./RichnessLib.sol";
import {Stage_04_Tokens} from "./Stage_04_Tokens.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    UniswapV4DetfHookPremineLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookPremineLib.sol";
import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";

/// @title Stage_08_FeeSink
/// @notice TTRICH + TTRICH/WETH SE + TTRICH-S first-bond + D47. No fee push.
/// @dev Premine TTRICH-S *before* `startBroadcast`. Infra (token/pool/SE) must exist first.
library Stage_08_FeeSink {
    function deployTtrichInfra(LaunchState storage s, address owner_, address uiWallet_) internal {
        Stage_04_Tokens.deployAndMintTtrich(s, owner_, uiWallet_);
        address weth = RobinhoodCanonicalLib.weth();
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());
        address seeder = s.v4Seeder;
        if (seeder == address(0)) {
            seeder = PoolSeedLib.ensureSeeder(s.create3Factory, pm);
            s.v4Seeder = seeder;
        }
        PoolSeedLib.wrapWeth(owner_, IERC20(weth).balanceOf(owner_) + FixtureEconomics.WETH_POOL_SEED + FixtureEconomics.TTRICH_FIRST_BOND);
        PoolKey memory key = PoolSeedLib.buildKey(s.ttRICH, weth);
        PoolSeedLib.initAndSeed(pm, seeder, key, FixtureEconomics.WETH_POOL_SEED, FixtureEconomics.WETH_POOL_SEED);
        s.seRichWeth = s.uniV4SePkg.deployVault(key, FixtureEconomics.SE_WIDTH_MULTIPLIER);
        s.rpRichWeth = address(s.rateProviderPkg.deployRateProvider(IStandardExchange(s.seRichWeth), IERC20(s.ttRICH)));
    }

    function premineRichS(LaunchState storage s) internal view returns (address predicted, uint256 nonce) {
        return UniswapV4DetfHookPremineLib.premineCp(
            s.diamondPackageFactory,
            s.hookFactory,
            IUniswapV4SingleStandardExchangeDETDFPkg(s.cpDetfPkg),
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage(s.cpHookPkg),
            _richSArgs(s),
            RobinhoodCanonicalLib.poolManager(),
            address(s.indexedexManager)
        );
    }

    function deployRichS(LaunchState storage s, address owner_, uint256 nonce) internal {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = _richSArgs(s);
        address predicted = s.diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(s.cpDetfPkg), abi.encode(args, uint256(0))
        );
        s.ttRichS = IUniswapV4SingleStandardExchangeDETDFPkg(s.cpDetfPkg).deployVault(args, nonce);
        require(s.ttRichS == predicted, "detf != predicted");
        address weth = RobinhoodCanonicalLib.weth();
        RichnessLib.firstBondCp(s.ttRichS, IERC20(weth), FixtureEconomics.TTRICH_FIRST_BOND, owner_);
        RichnessLib.enrichCp(s.ttRichS, weth, owner_);
    }

    function _richSArgs(LaunchState storage s)
        private
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
    {
        args.name = "Test DETF RICH Single";
        args.symbol = "TTRICH-S";
        args.standardExchangeVault = IStandardExchangeProxy(s.seRichWeth);
        args.standardExchangeVaultShare = IERC20(address(0));
        args.pairToken = IERC20(RobinhoodCanonicalLib.weth());
        args.creationPairPerDetfWad = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.mintThreshold = FixtureEconomics.MINT_THRESHOLD;
        args.burnThreshold = FixtureEconomics.BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = FixtureEconomics.EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = FixtureEconomics.EXPANSION_R;
        args.expansionMaxCatchUpEpochs = FixtureEconomics.EXPANSION_CATCHUP;
    }
}
