// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";
import {IPonsLaunchFactoryV1, IPonsLauncherTokenV1, PonsV1Lib} from "./PonsV1Lib.sol";

/// @title Script_14_PonsLaunchRich
/// @notice Launch pons v1 token RICH on RH fork only (no SE / DETF / market buy).
/// @dev Also writes frontend/packages/protocol/src/addresses/chain/4663/pons-launch.json for the buy page.
contract Script_14_PonsLaunchRich is DeploymentBase {
    string internal constant ARTIFACT_FILE = "14_pons_rich.json";
    string internal constant FRONTEND_DIR = "frontend/packages/protocol/src/addresses/chain/4663";
    string internal constant FRONTEND_LAUNCH_FILE = "pons-launch.json";

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
        _logHeader("Stage 14: pons launch RICH");

        if (_loadExisting()) {
            _exportJson();
            _writeFrontendLaunchJson();
            _logResults();
            return;
        }

        factory = FixtureEconomics.PONS_FACTORY;
        require(factory.code.length > 0, "pons factory missing code at pin");

        IPonsLaunchFactoryV1 pons = IPonsLaunchFactoryV1(factory);
        // RH main tip may close public launches; local Anvil fixture must still launch.
        // Layout on live factory (OZ Ownable2Step + ReentrancyGuard + fee/enabled): launchEnabled @ slot 3.
        if (!pons.launchEnabled()) {
            vm.store(factory, bytes32(uint256(3)), bytes32(uint256(1)));
            require(pons.launchEnabled(), "pons launchEnabled=false (force failed; run deploy_all ensure)");
            _logString("Forced launchEnabled=true via storage slot 3", "(anvil-only)");
        }
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

        // Do not auto-roll past anti-snipe here: launch-only path leaves sale timing to the buy UI.
        // (Full fee-DETF pipeline stage 19 rolls before the scripted market buy.)

        _exportJson();
        _writeFrontendLaunchJson();
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
        if (factory == address(0)) factory = FixtureEconomics.PONS_FACTORY;
        (restrictionsEndBlock,) = _readUintSafe(ARTIFACT_FILE, "restrictionsEndBlock");
        (positionId,) = _readUintSafe(ARTIFACT_FILE, "positionId");
        (uint256 feeU,) = _readUintSafe(ARTIFACT_FILE, "poolFee");
        poolFee = uint24(feeU);
        // Refresh launch metadata from factory when available.
        try IPonsLaunchFactoryV1(factory).getLaunchedToken(rich) returns (IPonsLaunchFactoryV1.LaunchedToken memory L) {
            if (L.exists) {
                isToken0 = L.isToken0;
                if (L.poolFee != 0) poolFee = L.poolFee;
                if (L.restrictionsEndBlock != 0) restrictionsEndBlock = L.restrictionsEndBlock;
                if (L.positionId != 0) positionId = L.positionId;
            }
        } catch {}
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("pons", "rich", rich);
        json = vm.serializeAddress("pons", "token", rich);
        json = vm.serializeAddress("pons", "pool", pool);
        json = vm.serializeAddress("pons", "factory", factory);
        json = vm.serializeAddress("pons", "locker", FixtureEconomics.PONS_LOCKER);
        json = vm.serializeAddress("pons", "weth", RobinhoodCanonicalLib.weth());
        json = vm.serializeAddress("pons", "swapRouter", FixtureEconomics.PONS_V3_SWAP_ROUTER);
        json = vm.serializeUint("pons", "restrictionsEndBlock", restrictionsEndBlock);
        json = vm.serializeUint("pons", "positionId", positionId);
        json = vm.serializeUint("pons", "poolFee", uint256(poolFee));
        json = vm.serializeBool("pons", "isToken0", isToken0);
        json = vm.serializeBytes32("pons", "salt", saltUsed);
        json = vm.serializeUint("pons", "chainId", block.chainid);
        json = vm.serializeString("pons", "name", FixtureEconomics.RICH_NAME);
        json = vm.serializeString("pons", "symbol", FixtureEconomics.RICH_SYMBOL);
        json = vm.serializeString(
            "pons",
            "description",
            "IndexedEx launch token on pons v1 (Uniswap V3 WETH pool from day one)."
        );
        _writeJson(json, ARTIFACT_FILE);
    }

    /// @dev UI buy page source of truth under chain/4663.
    function _writeFrontendLaunchJson() internal {
        vm.createDir(FRONTEND_DIR, true);
        string memory p = "launch";
        string memory out;
        out = vm.serializeUint(p, "chainId", block.chainid);
        out = vm.serializeAddress(p, "token", rich);
        out = vm.serializeAddress(p, "rich", rich);
        out = vm.serializeAddress(p, "pool", pool);
        out = vm.serializeAddress(p, "factory", factory);
        out = vm.serializeAddress(p, "locker", FixtureEconomics.PONS_LOCKER);
        out = vm.serializeAddress(p, "weth", RobinhoodCanonicalLib.weth());
        out = vm.serializeAddress(p, "swapRouter", FixtureEconomics.PONS_V3_SWAP_ROUTER);
        out = vm.serializeUint(p, "restrictionsEndBlock", restrictionsEndBlock);
        out = vm.serializeUint(p, "positionId", positionId);
        out = vm.serializeUint(p, "poolFee", uint256(poolFee == 0 ? 10000 : poolFee));
        out = vm.serializeBool(p, "isToken0", isToken0);
        out = vm.serializeString(p, "name", FixtureEconomics.RICH_NAME);
        out = vm.serializeString(p, "symbol", FixtureEconomics.RICH_SYMBOL);
        out = vm.serializeString(
            p,
            "description",
            "IndexedEx launch token on pons v1 (Uniswap V3 WETH pool from day one)."
        );
        out = vm.serializeString(p, "generation", "v1");
        out = vm.serializeString(p, "networkProfile", _networkProfile());
        vm.writeJson(out, string.concat(FRONTEND_DIR, "/", FRONTEND_LAUNCH_FILE));
        _logString("Frontend launch file:", string.concat(FRONTEND_DIR, "/", FRONTEND_LAUNCH_FILE));
    }

    function _logResults() internal view {
        _logAddress("RICH:", rich);
        _logAddress("Pool:", pool);
        _logUint("restrictionsEndBlock:", restrictionsEndBlock);
        _logComplete("Stage 14");
    }
}
