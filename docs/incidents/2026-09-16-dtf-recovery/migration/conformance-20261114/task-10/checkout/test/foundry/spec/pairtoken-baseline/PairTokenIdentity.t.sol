// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";
import {PairToken} from "../../../../contracts/pairtoken-baseline/PairToken.sol";
import {IPoolManager, PoolKey} from "../../../../contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol";

contract PairTokenIdentityTest is Test {
    PairToken internal pair;

    function setUp() public {
        pair = new PairToken();
    }

    function test_PT_AC_01() public {
        assertEq(pair.name(), "");
        assertEq(pair.symbol(), "");
        assertFalse(pair.initialized());
        assertEq(pair.factory(), address(0));
        assertEq(address(pair.poolManager()), address(0));
        assertEq(pair.poolId(), bytes32(0));
        assertEq(pair.tickLower(), 0);
        assertEq(pair.tickUpper(), 0);
        assertEq(pair.totalSupply(), 0);
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.allowance(address(this), address(this)), 0);
        PoolKey memory key = pair.poolKey();
        assertEq(abi.encode(key), abi.encode(address(0), address(0), uint24(0), int24(0), address(0)));
        assertEq(pair.token0(), address(0));
        assertEq(pair.token1(), address(0));
        (uint256 a, uint256 b) = pair.previewRedeem(0);
        assertEq(a | b, 0);
        assertTrue(pair.approve(address(0), 0));
        assertTrue(pair.transfer(address(this), 0));
        assertTrue(pair.transferFrom(address(0), address(this), 0));
        vm.deal(address(this), 1);
        vm.recordLogs();
        (bool ok,) = address(pair).call{value: 1}("");
        assertTrue(ok);
        assertEq(address(pair).balance, 1);
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_PT_AC_02() public {
        PoolKey memory key = PoolKey(address(0x10), address(0x20), 3000, 60, address(0x30));
        vm.recordLogs();
        vm.prank(address(0xA));
        pair.initialize(IPoolManager(address(0xB)), key, "Pair", "PAIR");
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(pair.factory(), address(0xA));
        assertEq(address(pair.poolManager()), address(0xB));
        assertEq(abi.encode(pair.poolKey()), abi.encode(key));
        assertEq(pair.poolId(), keccak256(abi.encode(address(0x10), address(0x20), uint24(3000), int24(60), address(0x30))));
        assertEq(pair.tickLower(), -887220);
        assertEq(pair.tickUpper(), 887220);
        assertEq(pair.name(), "Pair");
        assertEq(pair.symbol(), "PAIR");
        assertEq(pair.totalSupply(), 0);
        assertTrue(pair.initialized());
    }

    function test_PT_AC_03() public {
        PoolKey memory key = PoolKey(address(1), address(2), 0, 60, address(0));
        vm.expectRevert(PairToken.ZeroAddress.selector);
        pair.initialize(IPoolManager(address(0)), key, "x", "y");
        assertFalse(pair.initialized());
        key.tickSpacing = 0;
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x12));
        pair.initialize(IPoolManager(address(1)), key, "x", "y");
        assertFalse(pair.initialized());
        assertEq(pair.factory(), address(0));
        assertEq(pair.name(), "");
        key.tickSpacing = 60;
        pair.initialize(IPoolManager(address(1)), key, "x", "y");
        vm.expectRevert(PairToken.AlreadyInitialized.selector);
        pair.initialize(IPoolManager(address(0)), key, "changed", "changed");
        assertEq(pair.name(), "x");
    }

    function test_PT_AC_04() public {
        PoolKey memory key = PoolKey(address(9), address(1), type(uint24).max, -60, address(0xBAD));
        pair.initialize(IPoolManager(address(0x1234)), key, "", "");
        assertEq(abi.encode(pair.poolKey()), abi.encode(key));
        assertEq(pair.tickLower(), -887220);
        assertEq(pair.tickUpper(), 887220);
        PairToken equal = new PairToken();
        key.currency1 = key.currency0;
        equal.initialize(IPoolManager(address(0x1234)), key, "", "");
        assertTrue(equal.initialized());
        (bool ok,) = address(equal).staticcall(abi.encodeCall(equal.positionLiquidity, ()));
        assertFalse(ok);
    }

    function test_PT_CONST_01() public view {
        assertEq(pair.decimals(), 18);
        assertEq(pair.BPS(), 10000);
        assertEq(pair.DEAD_SHARES(), 1000);
        assertEq(pair.RETENTION_BPS(), 10);
        assertEq(pair.DUST(), 1000);
        assertEq(pair.DEAD(), address(0xdead));
    }

    function test_PT_GET_all() public {
        PoolKey memory key = PoolKey(address(9), address(10), 500, 60, address(11));
        pair.initialize(IPoolManager(address(12)), key, "Name", "SYM");
        vm.startStateDiffRecording();
        assertEq(pair.name(), "Name");
        assertEq(pair.symbol(), "SYM");
        assertEq(pair.decimals(), 18);
        assertEq(pair.totalSupply(), 0);
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.allowance(address(this), address(2)), 0);
        assertEq(pair.BPS(), 10000);
        assertEq(pair.DEAD_SHARES(), 1000);
        assertEq(pair.RETENTION_BPS(), 10);
        assertEq(pair.DUST(), 1000);
        assertEq(pair.DEAD(), address(0xdead));
        assertEq(pair.factory(), address(this));
        assertEq(address(pair.poolManager()), address(12));
        assertEq(pair.poolId(), keccak256(abi.encode(key)));
        assertEq(pair.tickLower(), -887220);
        assertEq(pair.tickUpper(), 887220);
        assertTrue(pair.initialized());
        Vm.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        uint256 getters;
        for (uint256 i; i < accesses.length; ++i) {
            if (accesses[i].accessor == address(this) && accesses[i].account == address(pair)) {
                assertEq(uint256(accesses[i].kind), uint256(VmSafe.AccountAccessKind.StaticCall));
                ++getters;
            }
            assertFalse(accesses[i].account == address(12), "getter called manager");
        }
        assertEq(getters, 17);
    }

    function test_PT_INIT_negative_spacing() public {
        PoolKey memory key = PoolKey(address(1), address(2), 0, -60, address(0));
        pair.initialize(IPoolManager(address(3)), key, "", "");
        assertEq(pair.tickLower(), -887220);
        assertEq(pair.tickUpper(), 887220);
    }

    function test_PT_API_mutability() public {
        _compiledABI();
    }

    function test_PT_ERROR_selectors() public {
        _compiledABI();
    }

    // Public v4-core v4.0.0, commit e50237c43811bd9b526eff40f26772152a42daba.
    // Only the seven consumed selectors are compared, not whole-manager behavior.
    function test_PT_DEPENDS_manager_selectors() public pure {
        assertEq(IPoolManager.unlock.selector, bytes4(0x48c89491));
        assertEq(IPoolManager.modifyLiquidity.selector, bytes4(0x5a6bcfda));
        assertEq(IPoolManager.swap.selector, bytes4(0xf3cd914c));
        assertEq(IPoolManager.sync.selector, bytes4(0xa5841194));
        assertEq(IPoolManager.settle.selector, bytes4(0x11da60b4));
        assertEq(IPoolManager.take.selector, bytes4(0x0b0d9c09));
        assertEq(IPoolManager.extsload.selector, bytes4(0x1e2eaeaf));
    }

    function _compiledABI() internal {
        string[] memory command = new string[](2);
        command[0] = "python3";
        command[1] = "test/foundry/spec/pairtoken-baseline/check-abi.py";
        assertTrue(abi.decode(vm.ffi(command), (bool)));
    }

    function test_PT_ERROR_precedence() public {
        vm.deal(address(this), 10);
        vm.expectRevert(PairToken.ZeroAddress.selector);
        pair.deposit{value: 1}(0, 0, 0, address(0));
        vm.expectRevert(PairToken.ZeroAddress.selector);
        pair.zapDeposit{value: 1}(address(9), 0, 0, address(0));
        vm.expectRevert(PairToken.BadToken.selector);
        pair.zapDeposit{value: 1}(address(9), 0, 0, address(this));
        vm.expectRevert(PairToken.ZeroAddress.selector);
        pair.redeem(0, 0, 0, address(0));
        vm.expectRevert(PairToken.ZeroAddress.selector);
        pair.redeemZap(0, address(9), 0, address(0));
        vm.expectRevert(PairToken.BadToken.selector);
        pair.redeemZap(0, address(9), 0, address(this));
        vm.expectRevert(PairToken.ZeroAddress.selector);
        pair.transfer(address(0), 1);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        pair.transferFrom(address(this), address(0), 1);
        vm.expectRevert(PairToken.NotPoolManager.selector);
        pair.unlockCallback(hex"ff");
    }

    function test_PT_AC_58() public {
        _absent();
    }

    function test_PT_ABSENT_surface() public {
        _absent();
    }

    function _absent() internal {
        string[18] memory signatures = [
            "getRate()", "claimFees()", "mint(address,uint256)", "burn(uint256)",
            "rescue(address,address,uint256)", "sweep(address)", "pause()", "unpause()",
            "setManager(address)", "setFactory(address)", "rebalance()", "setRange(int24,int24)",
            "asset()", "convertToShares(uint256)", "convertToAssets(uint256)",
            "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
            "redeemTarget(uint256,uint256,address)", "redeem(uint256,address,address)"
        ];
        for (uint256 i; i < signatures.length; ++i) {
            (bool ok, bytes memory reason) =
                address(pair).call(abi.encodePacked(bytes4(keccak256(bytes(signatures[i]))), new bytes(224)));
            assertFalse(ok, signatures[i]);
            assertEq(reason.length, 0);
        }
    }
}
