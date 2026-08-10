// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";
import {IPonsLaunchFactoryV1, IPonsLauncherTokenV1, PonsV1Lib} from "./PonsV1Lib.sol";

/// @title Script_04_PonsLaunchRich
/// @notice Launch pons v1 token RICH on RH fork; persist pool + launch metadata.
contract Script_04_PonsLaunchRich is DeploymentBase {
    string internal constant ARTIFACT_FILE = "04_pons_rich.json";

    address private rich;
    address private pool;
    address private factory;
    uint256 private restrictionsEndBlock;
    uint256 private positionId;
    bool private isToken0;
    uint24 private poolFee;
    bytes32 private saltUsed;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _logHeader("Stage 04: pons launch RICH");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        factory = FixtureEconomics.PONS_FACTORY;
        require(factory.code.length > 0, "pons factory missing code at pin");

        IPonsLaunchFactoryV1 pons = IPonsLaunchFactoryV1(factory);
        require(pons.launchEnabled(), "pons launchEnabled=false");
        uint256 fee = pons.launchFee();

        // Unique salt so re-runs after purge do not collide with prior CREATE2.
        saltUsed = keccak256(abi.encodePacked("IndexedExFeeDetfRICH", deployer, block.number, block.timestamp));

        IPonsLaunchFactoryV1.TokenParams memory params = PonsV1Lib.richParams(deployer);

        vm.startBroadcast();
        // Pay launch fee only; initial buy is stage 10. Creator-only buy restriction is launch block.
        rich = pons.launchToken{value: fee}(params, 0, 0, saltUsed);
        vm.stopBroadcast();

        require(rich != address(0) && rich.code.length > 0, "RICH token deploy failed");

        IPonsLaunchFactoryV1.LaunchedToken memory launched = pons.getLaunchedToken(rich);
        require(launched.exists, "getLaunchedToken.exists=false");
        pool = IPonsLauncherTokenV1(rich).liquidityPool();
        if (pool == address(0)) {
            // Fallback: pool is not always on token if ABI differs; LaunchedToken does not include pool.
            // Decode would require receipt; re-read liquidityPool after a mine.
            pool = IPonsLauncherTokenV1(rich).liquidityPool();
        }
        require(pool != address(0) && pool.code.length > 0, "RICH pool missing");

        restrictionsEndBlock = launched.restrictionsEndBlock;
        positionId = launched.positionId;
        isToken0 = launched.isToken0;
        poolFee = launched.poolFee;

        // Advance past launch protection window so stage 10 can buy as #0 without anti-snipe.
        if (block.number <= restrictionsEndBlock) {
            vm.roll(restrictionsEndBlock + 1);
        }

        _exportJson();
        _logResults();
    }

    function _loadExisting() internal returns (bool) {
        if (_force()) return false;
        (address r, bool okR) = _readAddressSafe(ARTIFACT_FILE, "rich");
        (address p, bool okP) = _readAddressSafe(ARTIFACT_FILE, "pool");
        if (!okR || !okP || r.code.length == 0 || p.code.length == 0) return false;
        rich = r;
        pool = p;
        (factory,) = _readAddressSafe(ARTIFACT_FILE, "factory");
        (restrictionsEndBlock,) = _readUintSafe(ARTIFACT_FILE, "restrictionsEndBlock");
        (positionId,) = _readUintSafe(ARTIFACT_FILE, "positionId");
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("pons", "rich", rich);
        json = vm.serializeAddress("pons", "pool", pool);
        json = vm.serializeAddress("pons", "factory", factory);
        json = vm.serializeAddress("pons", "locker", FixtureEconomics.PONS_LOCKER);
        json = vm.serializeAddress("pons", "weth", RobinhoodCanonicalLib.weth());
        json = vm.serializeUint("pons", "restrictionsEndBlock", restrictionsEndBlock);
        json = vm.serializeUint("pons", "positionId", positionId);
        json = vm.serializeUint("pons", "poolFee", uint256(poolFee));
        json = vm.serializeBool("pons", "isToken0", isToken0);
        json = vm.serializeBytes32("pons", "salt", saltUsed);
        json = vm.serializeUint("pons", "chainId", block.chainid);
        json = vm.serializeString("pons", "symbol", FixtureEconomics.RICH_SYMBOL);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("RICH:", rich);
        _logAddress("Pool:", pool);
        _logUint("restrictionsEndBlock:", restrictionsEndBlock);
        _logComplete("Stage 04");
    }
}
