// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Phase_02_Stage_01_Create3Factory} from "./Phase_02_Stage_01_Create3Factory.sol";
import {Phase_02_Stage_02_DiamondPackageFactory} from "./Phase_02_Stage_02_DiamondPackageFactory.sol";
import {Phase_02_Stage_03_HookFactory} from "./Phase_02_Stage_03_HookFactory.sol";
import {Phase_03_Stage_01_CommonFacets} from "./Phase_03_Stage_01_CommonFacets.sol";
import {Phase_04_Stage_01_FeeCollectorAndManager} from "./Phase_04_Stage_01_FeeCollectorAndManager.sol";
import {Phase_05_Stage_01_SeRateProviderPkg} from "./Phase_05_Stage_01_SeRateProviderPkg.sol";
import {Phase_05_Stage_02_UniswapV4TwapOracle} from "./Phase_05_Stage_02_UniswapV4TwapOracle.sol";
import {Phase_05_Stage_03_UniswapV4StandardExchangePkg} from "./Phase_05_Stage_03_UniswapV4StandardExchangePkg.sol";
import {Phase_06_Stage_01_BondNftPkg} from "./Phase_06_Stage_01_BondNftPkg.sol";
import {Phase_06_Stage_02_RebasingClaimPkg} from "./Phase_06_Stage_02_RebasingClaimPkg.sol";
import {Phase_06_Stage_03_CpBufferHookPkg} from "./Phase_06_Stage_03_CpBufferHookPkg.sol";
import {Phase_06_Stage_07_CpDetfPkg} from "./Phase_06_Stage_07_CpDetfPkg.sol";

/// @title Script_SimulateArchitecture
/// @notice One Foundry script wrapping architecture library execute() for a 4663 gas quote.
/// @dev No Phase 00. No tokens. No DETF instances. Do not run after a completed staged `all`.
contract Script_SimulateArchitecture is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _logHeader("Simulate architecture: Phases 02-06 (packages)");

        _broadcast();
        Phase_02_Stage_01_Create3Factory.execute(s, owner);
        Phase_02_Stage_02_DiamondPackageFactory.execute(s);
        Phase_02_Stage_03_HookFactory.execute(s);
        Phase_03_Stage_01_CommonFacets.execute(s);
        Phase_04_Stage_01_FeeCollectorAndManager.execute(s, owner);
        Phase_05_Stage_01_SeRateProviderPkg.execute(s);
        Phase_05_Stage_02_UniswapV4TwapOracle.execute(s);
        Phase_05_Stage_03_UniswapV4StandardExchangePkg.execute(s);
        Phase_06_Stage_01_BondNftPkg.execute(s);
        Phase_06_Stage_02_RebasingClaimPkg.execute(s);
        Phase_06_Stage_03_CpBufferHookPkg.execute(s);
        Phase_06_Stage_07_CpDetfPkg.execute(s);
        vm.stopBroadcast();

        _exportArchitecture(s);

        _logAddress("Create3Factory:", address(s.create3Factory));
        _logAddress("IndexedexManager:", address(s.indexedexManager));
        _logAddress("twapOracle:", address(s.twapOracle));
        _logAddress("uniV4SePkg:", address(s.uniV4SePkg));
        _logAddress("cpDetfPkg:", s.cpDetfPkg);
        _logComplete("SimulateArchitecture 02-06");
    }
}
