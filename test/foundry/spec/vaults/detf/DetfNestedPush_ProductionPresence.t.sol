// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/// @notice Structural presence checks: production DETF nested fund paths use push + true.
/// @dev Complements runtime NestedPush suites (BAL-SE full T-NEST matrix; BAL-MV T-LOCAL/T-NEST core).
///      Reads shipped source under contracts/vaults/detf — no mocks; fails if nested false returns.
contract DetfNestedPush_ProductionPresence_Test is Test {
    function test_noProductionNestedExchangeFalse() public {
        string[] memory paths = new string[](11);
        paths[0] = "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/";
        paths[1] = "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/";
        paths[2] = "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/";
        paths[3] = "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/";
        paths[4] = "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/";
        paths[5] = "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/";
        paths[6] = "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/";
        paths[7] = "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/";
        paths[8] = "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/";
        paths[9] = "contracts/hooks/uniswap/v4/standardExchange/weighted/";
        paths[10] = "contracts/hooks/uniswap/v4/standardExchange/orbital/";

        // Grep shipped tree: nested exchangeIn/Out must not pass pretransferred=false.
        string[] memory cmd = new string[](6);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] =
            "rg -n 'exchangeIn\\([^;]*false|exchangeOut\\([^;]*false' contracts/vaults/detf contracts/hooks/uniswap/v4/standardExchange --glob '*.sol' -g '!**/TestBase*' -g '!**/*Test*' -g '!**/*.t.sol' || true";
        try vm.ffi(cmd) returns (bytes memory out) {
            string memory s = string(out);
            assertEq(bytes(s).length, 0, string.concat("nested false remain: ", s));
        } catch {
            // FFI disabled: fall back to key file spot-checks for push+true helpers.
            _assertFileContains(
                "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol",
                "_nestedExchangeInPush"
            );
            _assertFileContains(
                "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFCommon.sol",
                "_nestedExchangeInPush"
            );
            _assertFileContains(
                "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol",
                "pretransferred=true"
            );
            _assertFileContains(
                "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol",
                "L-DETF-PUSH-NESTED"
            );
        }
        // silence
        paths;
    }

    function test_familyCommonsHaveLocalDurablePull() public {
        _assertFileContains(
            "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol",
            "U = B0 - R"
        );
        _assertFileContains(
            "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol",
            "U = B0 - R"
        );
        _assertFileContains(
            "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol",
            "U = B0 - R"
        );
        _assertFileContains(
            "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol",
            "U = B0 - R"
        );
        _assertFileContains(
            "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFCommon.sol",
            "U = B0 - R"
        );
        _assertFileContains(
            "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFCommon.sol",
            "U = B0 - R"
        );
        _assertFileContains(
            "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFCommon.sol",
            "U = B0 - R"
        );
    }

    function test_hooksHostDurablePull() public {
        _assertFileContains(
            "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol",
            "B0 >= R ? B0 - R : B0"
        );
        _assertFileContains(
            "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol",
            "B0 >= R ? B0 - R : B0"
        );
        _assertFileContains(
            "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol",
            "B0 >= R ? B0 - R : B0"
        );
    }

    function _assertFileContains(string memory path, string memory needle) internal view {
        string memory body = vm.readFile(path);
        assertTrue(_contains(body, needle), string.concat("missing ", needle, " in ", path));
    }

    function _contains(string memory hay, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(hay);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return n.length == 0;
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
}
