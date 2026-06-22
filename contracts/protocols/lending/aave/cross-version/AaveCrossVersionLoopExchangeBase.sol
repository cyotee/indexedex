// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {IHub} from "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IHub.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

import {AaveV36PoolAwareRepo} from "contracts/protocols/lending/aave/cross-version/AaveV36PoolAwareRepo.sol";
import {AaveV4SpokeAwareRepo} from "contracts/protocols/lending/aave/cross-version/AaveV4SpokeAwareRepo.sol";
import {LoopPositionRepo} from "contracts/protocols/lending/aave/cross-version/LoopPositionRepo.sol";
import {CrossVersionLoopExecutor} from "contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol";

/**
 * @title AaveCrossVersionLoopExchangeBase
 * @author cyotee doge <doge.cyotee>
 * @notice Shared storage wiring + market builder for the cross-version loop exchange facets (In/Out).
 *         Both facets operate on the same diamond storage (AwareRepos, LoopPositionRepo, ERC20 share).
 */
abstract contract AaveCrossVersionLoopExchangeBase {
    uint256 internal constant MINIMUM_LIQUIDITY = 1000; // permanent first-deposit lock (decision 21)

    struct InitArgs {
        IPool v36Pool;
        IPoolAddressesProvider v36AddressesProvider;
        IAaveOracle v36Oracle;
        ISpoke v4Spoke;
        IHub v4Hub;
        IAaveOracleV4 v4Oracle;
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 v4AssetIdA;
        uint256 v4ReserveIdA;
        uint256 v4AssetIdB;
        uint256 v4ReserveIdB;
        string shareName;
        string shareSymbol;
    }

    /// @dev Initializes the vault's AwareRepos, pair, and share token. In production this is invoked
    ///      from the Package `initAccount`; exposed here for standalone wiring/tests.
    function initCrossVersionLoop(InitArgs memory a) public {
        AaveV36PoolAwareRepo._initialize(a.v36Pool, a.v36AddressesProvider, a.v36Oracle);
        AaveV4SpokeAwareRepo._initialize(a.v4Spoke, a.v4Hub, a.v4Oracle);
        AaveV4SpokeAwareRepo._setTokenIds(address(a.tokenA), a.v4AssetIdA, a.v4ReserveIdA);
        AaveV4SpokeAwareRepo._setTokenIds(address(a.tokenB), a.v4AssetIdB, a.v4ReserveIdB);
        LoopPositionRepo._initialize(a.tokenA, a.tokenB);
        ERC20Repo._initialize(a.shareName, a.shareSymbol, 18);
    }

    function _market() internal view returns (CrossVersionLoopExecutor.Market memory) {
        IERC20 tokenA = LoopPositionRepo._tokenA();
        IERC20 tokenB = LoopPositionRepo._tokenB();
        return CrossVersionLoopExecutor.Market({
            v36Pool: AaveV36PoolAwareRepo._pool(),
            v36Oracle: AaveV36PoolAwareRepo._oracle(),
            v4Spoke: AaveV4SpokeAwareRepo._spoke(),
            v4Hub: AaveV4SpokeAwareRepo._hub(),
            tokenA: tokenA,
            tokenB: tokenB,
            v4ReserveIdA: AaveV4SpokeAwareRepo._reserveIdOf(address(tokenA)),
            v4ReserveIdB: AaveV4SpokeAwareRepo._reserveIdOf(address(tokenB))
        });
    }

    function _loopConfig() internal pure returns (CrossVersionLoopExecutor.LoopConfig memory) {
        return CrossVersionLoopExecutor.LoopConfig({ltvBps: 70_00, safetyBps: 90_00, maxIterations: 10});
    }
}
