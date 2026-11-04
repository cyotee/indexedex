// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {PairToken} from "../../../../contracts/pairtoken-baseline/PairToken.sol";
import {PairTokenMath} from "../../../../contracts/pairtoken-baseline/PairTokenMath.sol";
import {IPoolManager, PoolKey} from "../../../../contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol";

contract PairTokenFailureProbe {
    function md(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return PairTokenMath.MD(a, b, c);
    }

    function mu(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return PairTokenMath.MU(a, b, c);
    }
}

contract PairTokenCompilerTest is Test {
    function test_PT_ERROR_compiler_encodings() public {
        PairToken pair = new PairToken();
        _failure(address(pair), abi.encodeCall(pair.transfer, (address(1), 1)),
            abi.encodeWithSignature("Panic(uint256)", 0x11), "checked overflow");
        PoolKey memory key = PoolKey(address(1), address(2), 0, 0, address(0));
        _failure(address(pair), abi.encodeCall(pair.initialize, (IPoolManager(address(3)), key, "", "")),
            abi.encodeWithSignature("Panic(uint256)", 0x12), "initialization division");
        _failure(address(pair), abi.encodeCall(pair.transfer, (address(0), 0)),
            abi.encodeWithSignature("ZeroAddress()"), "custom error");
        key.tickSpacing = 60;
        pair.initialize(IPoolManager(address(3)), key, "", "");
        bytes memory callData = abi.encodeCall(pair.unlockCallback, (abi.encode(uint256(5), bytes(""))));
        vm.prank(address(3));
        (bool ok, bytes memory reason) = address(pair).call(callData);
        assertFalse(ok);
        assertEq(reason, bytes(""));
        emit log_named_bytes("out-of-range enum decode", reason);
        PairTokenFailureProbe probe = new PairTokenFailureProbe();
        _failure(address(probe), abi.encodeCall(probe.md, (1, 1, 0)), bytes(""), "MD zero denominator");
        uint256 maximum = type(uint256).max;
        _failure(address(probe), abi.encodeCall(probe.mu, (maximum - 1, maximum - 1, maximum - 2)),
            bytes(""), "MU upward overflow");
    }

    function _failure(address target, bytes memory data, bytes memory expected, string memory label) internal {
        (bool ok, bytes memory reason) = target.call(data);
        assertFalse(ok, label);
        assertEq(reason, expected, label);
        emit log_named_bytes(label, reason);
    }
}
