// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LaunchIo} from "scripts/foundry/anvil_robinhood_testnet/LaunchIo.sol";
import {LaunchState} from "scripts/foundry/anvil_robinhood_testnet/LaunchState.sol";
import {RobinhoodCanonicalLib} from "scripts/foundry/anvil_robinhood_testnet/RobinhoodCanonicalLib.sol";
import {Phase_01_Stage_01_Permit2 as Permit2Lib} from "scripts/foundry/anvil_robinhood_testnet/Phase_01_Stage_01_Permit2.sol";
import {Phase_01_Stage_02_Weth as WethLib} from "scripts/foundry/anvil_robinhood_testnet/Phase_01_Stage_02_Weth.sol";
import {Phase_01_Stage_03_UniswapV4 as UniV4Lib} from "scripts/foundry/anvil_robinhood_testnet/Phase_01_Stage_03_UniswapV4.sol";
import {Phase_01_Stage_04_UniswapV3 as UniV3Lib} from "scripts/foundry/anvil_robinhood_testnet/Phase_01_Stage_04_UniswapV3.sol";
import {Phase_01_Stage_05_MorphoBlue as MorphoLib} from "scripts/foundry/anvil_robinhood_testnet/Phase_01_Stage_05_MorphoBlue.sol";
import {Phase_02_Stage_01_Create3Factory as Create3Lib} from "scripts/foundry/anvil_robinhood_testnet/Phase_02_Stage_01_Create3Factory.sol";
import {Phase_01_Stage_01_Permit2} from "scripts/foundry/anvil_robinhood_testnet/Phase_01_Stage_01_Permit2.s.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";
import {IMorpho} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {FixtureEconomics} from "scripts/foundry/anvil_robinhood_testnet/FixtureEconomics.sol";

/// @dev Bytecode placeholder so skip keys can point at a live address.
contract LaunchSkipDummy {}

/// @title LaunchSkipPinTest
/// @notice Drives shipped skip / FORCE / pin-fail / rehearsal / CREATE3-not-pinned paths.
contract LaunchSkipPinTest is Test {
    SkipHarness internal harness;
    string internal outDir;

    function setUp() public {
        vm.chainId(46630);
        outDir = string.concat(vm.projectRoot(), "/out/.launch_skip_pin");
        vm.createDir(outDir, true);
        vm.setEnv("OUT_DIR_OVERRIDE", outDir);
        // Shell uses FORCE=1. Zero so skip is live unless a test sets FORCE=1.
        vm.setEnv("FORCE", "0");
        harness = new SkipHarness();
        harness.loadConfig();
    }

    function test_skip_when_catalog_keys_have_code_rewrites_json() public {
        LaunchSkipDummy dummy = new LaunchSkipDummy();
        harness.writeAddrJson("phase01_stage01_permit2.json", "permit2", address(dummy));

        vm.etch(RobinhoodCanonicalLib.permit2(), bytes(""));
        vm.setEnv("FORCE", "0");
        harness.loadConfig();

        (bool forceOn, bool live, bool skip) = harness.skipDebug();
        assertFalse(forceOn, "FORCE must be off");
        assertTrue(live, "skip key has code");
        assertTrue(skip, "shipped skip helper");

        Phase_01_Stage_01_Permit2 script = new Phase_01_Stage_01_Permit2();
        script.run();

        address written = harness.readAddr("phase01_stage01_permit2.json", "permit2");
        assertEq(written, address(dummy), "skip still rewrites JSON");
        assertEq(RobinhoodCanonicalLib.permit2().code.length, 0, "did not deploy Permit2");
    }

    function test_force_reruns_instead_of_skip() public {
        LaunchSkipDummy dummy = new LaunchSkipDummy();
        harness.writeAddrJson("phase01_stage01_permit2.json", "permit2", address(dummy));
        vm.etch(RobinhoodCanonicalLib.permit2(), bytes(""));

        vm.setEnv("FORCE", "1");
        harness.loadConfig();
        assertTrue(harness.forceFlag(), "FORCE=1 must be on");
        assertFalse(harness.skipPermit2(), "FORCE disables skip");
        vm.expectRevert(bytes("Phase 01-01: Permit2 pin has no code"));
        harness.pinPermit2();
    }

    function test_permit2_pin_reverts_without_code() public {
        vm.etch(RobinhoodCanonicalLib.permit2(), bytes(""));
        vm.expectRevert(bytes("Phase 01-01: Permit2 pin has no code"));
        harness.pinPermit2();
    }

    function test_weth_pin_reverts_without_code() public {
        vm.etch(RobinhoodCanonicalLib.weth(), bytes(""));
        vm.expectRevert(bytes("Phase 01-02: WETH pin has no code"));
        harness.pinWeth();
    }

    function test_v4_pin_reverts_without_pool_manager() public {
        vm.etch(RobinhoodCanonicalLib.poolManager(), bytes(""));
        vm.expectRevert(bytes("Phase 01-03: PoolManager pin has no code"));
        harness.pinV4();
    }

    function test_univ3_rehearsal_deploys_live_factory() public {
        (address factory, bool local_) = UniV3Lib.execute();
        assertTrue(factory != address(0) && factory.code.length > 0, "rehearsal factory");
        if (ROBINHOOD_TESTNET.UNISWAP_V3_FACTORY == address(0)
                || ROBINHOOD_TESTNET.UNISWAP_V3_FACTORY.code.length == 0) {
            assertTrue(local_, "v3Local");
            assertTrue(factory != ROBINHOOD_TESTNET.UNISWAP_V3_FACTORY);
        }
        harness.exportV3(factory, local_);
        address written = harness.readAddr("phase01_stage04_uniswap_v3.json", "v3Factory");
        assertEq(written, factory);
        assertTrue(written.code.length > 0);
    }

    function test_morpho_rehearsal_writes_live_not_main_create2() public {
        address owner_ = address(harness);
        harness.runMorpho(owner_);
        address morpho = harness.morpho();
        assertTrue(morpho != address(0) && morpho.code.length > 0, "rehearsal Morpho");
        if (ROBINHOOD_TESTNET.MORPHO.code.length == 0) {
            assertTrue(morpho != ROBINHOOD_TESTNET.MORPHO, "must not write code-less main CREATE2");
        }
        harness.exportMorpho();
        address written = harness.readAddr("phase01_stage05_morpho_blue.json", "morpho");
        assertEq(written, morpho);
        string memory raw = vm.readFile(string.concat(outDir, "/phase01_stage05_morpho_blue.json"));
        assertTrue(!_contains(raw, _toHexLower(ROBINHOOD_TESTNET.MORPHO_VAULT_V2_FACTORY))
                || ROBINHOOD_TESTNET.MORPHO_VAULT_V2_FACTORY.code.length > 0);
        assertTrue(IMorpho(morpho).isIrmEnabled(harness.morphoIrm()));
        assertTrue(IMorpho(morpho).isLltvEnabled(FixtureEconomics.MORPHO_LLTV));
    }

    function test_create3_is_new_not_network_constants_pin() public {
        address factory = harness.runCreate3(address(harness));
        assertTrue(factory != address(0) && factory.code.length > 0, "CREATE3 deployed");
        harness.exportCreate3();
        address written = harness.readAddr("phase02_stage01_create3_factory.json", "create3Factory");
        assertEq(written, factory);
        assertTrue(written != ROBINHOOD_TESTNET.PERMIT2);
        assertTrue(written != ROBINHOOD_TESTNET.UNISWAP_V4_POOL_MANAGER);
        assertTrue(written != ROBINHOOD_TESTNET.MORPHO);
    }

    function _contains(string memory hay, string memory needle) private pure returns (bool) {
        bytes memory h = bytes(hay);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return false;
        for (uint256 i; i <= h.length - n.length; ++i) {
            bool ok = true;
            for (uint256 j; j < n.length; ++j) {
                if (h[i + j] != n[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }

    function _toHexLower(address addr) private pure returns (string memory) {
        bytes20 data = bytes20(addr);
        bytes16 hex_ = "0123456789abcdef";
        bytes memory out = new bytes(42);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i; i < 20; ++i) {
            out[2 + i * 2] = hex_[uint8(data[i] >> 4)];
            out[3 + i * 2] = hex_[uint8(data[i] & 0x0f)];
        }
        return string(out);
    }
}

contract SkipHarness is LaunchIo {
    LaunchState internal s;

    function loadConfig() external {
        _loadConfig();
    }

    function pinPermit2() external view returns (address) {
        return Permit2Lib.execute();
    }

    function pinWeth() external view returns (address) {
        return WethLib.execute();
    }

    function pinV4() external view returns (UniV4Lib.Pins memory) {
        return UniV4Lib.execute();
    }

    function shouldSkip(string memory file, string[] memory keys) external view returns (bool) {
        return _shouldSkipStage(file, keys);
    }

    function skipPermit2() external view returns (bool) {
        return _shouldSkipStage(FILE_01_01, "permit2");
    }

    function executePermit2Stage() external returns (address) {
        if (_shouldSkipStage(FILE_01_01, "permit2")) {
            return _loadAddr(FILE_01_01, "permit2");
        }
        return Permit2Lib.execute();
    }

    function skipDebug() external view returns (bool forceOn, bool live, bool skip) {
        forceOn = _force();
        live = _artifactHasLiveCode(FILE_01_01, "permit2");
        skip = _shouldSkipStage(FILE_01_01, "permit2");
    }

    function forceFlag() external view returns (bool) {
        return _force();
    }

    function liveCode(string memory file, string memory key) external view returns (bool) {
        return _artifactHasLiveCode(file, key);
    }

    function writeAddrJson(string memory file, string memory key, address addr) external {
        string memory json = vm.serializeAddress("t", key, addr);
        _writeJson(json, file);
    }

    function readAddr(string memory file, string memory key) external view returns (address) {
        return _readAddress(file, key);
    }

    function runMorpho(address owner_) external {
        MorphoLib.execute(s, owner_);
    }

    function morpho() external view returns (address) {
        return s.morpho;
    }

    function morphoIrm() external view returns (address) {
        return s.morphoIrm;
    }

    function exportMorpho() external {
        string memory json;
        json = vm.serializeAddress("p0105", "morpho", s.morpho);
        json = vm.serializeAddress("p0105", "morphoIrm", s.morphoIrm);
        json = vm.serializeAddress("p0105", "morphoOracle", s.morphoOracle);
        json = vm.serializeBool("p0105", "morphoLocal", s.morphoLocal);
        _writeJson(json, FILE_01_05);
    }

    function exportV3(address factory, bool local_) external {
        string memory json;
        json = vm.serializeAddress("p0104", "v3Factory", factory);
        json = vm.serializeBool("p0104", "v3Local", local_);
        _writeJson(json, FILE_01_04);
    }

    function runCreate3(address owner_) external returns (address) {
        Create3Lib.execute(s, owner_);
        return address(s.create3Factory);
    }

    function exportCreate3() external {
        _exportCreate3(s);
    }
}
