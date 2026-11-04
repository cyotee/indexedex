// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

contract WeirVaults_SurfaceTest is TestBase_WeirVaults {
    using PoolIdLibrary for PoolKey;
    function test_AC05_validDeploy() public view {
        assertEq(weir.perfFeeBps(), 500);
        assertEq(weir.MAX_PERF_FEE_BPS(), 1000);
        assertEq(weir.MIN_SHARES(), 1000);
        assertFalse(weir.paused());
        assertEq(weir.vaultCount(), 0);
        assertEq(weir.owner(), owner);
        assertEq(weir.treasury(), treasury);
        assertEq(address(weir.poolManager()), address(poolManager));
    }

    function test_AC05_zeroTreasury() public {
        vm.expectRevert(WeirVaults.ZeroAddress.selector);
        new WeirVaults(poolManager, address(0), owner);
    }

    function test_AC05_zeroOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new WeirVaults(poolManager, treasury, address(0));
    }

    function test_AC05_zeroManager() public {
        WeirVaults zero = new WeirVaults(IPoolManager(address(0)), treasury, owner);
        assertEq(address(zero.poolManager()), address(0));
    }

    function test_AC06_twoKeysSharedCurrency() public {
        (PoolKey memory first, PoolId firstId) = initF0();
        PoolKey memory second = ercKey(address(tokenA), address(tokenC), 0, 1, IHooks(address(0)));
        PoolId secondId = initHookless(second, f0Sqrt());
        vm.expectEmit(true, false, false, true, address(weir));
        emit WeirVaults.VaultCreated(firstId, first);
        weir.createVault(first);
        weir.createVault(second);
        assertEq(weir.vaultCount(), 2);
        assertEq(PoolId.unwrap(weir.allVaults(0)), PoolId.unwrap(firstId));
        assertEq(PoolId.unwrap(weir.allVaults(1)), PoolId.unwrap(secondId));
        assertTrue(weir.vault(firstId).exists);
        assertTrue(weir.vault(secondId).exists);
        assertEq(weir.vault(firstId).liquidity, 0);
        assertEq(weir.vault(secondId).totalShares, 0);
    }

    function test_AC07_duplicate() public {
        (PoolKey memory key, PoolId id) = initF0();
        weir.createVault(key);
        vm.expectRevert(WeirVaults.VaultExists.selector);
        weir.createVault(key);
        assertEq(weir.vaultCount(), 1);
        assertEq(PoolId.unwrap(weir.allVaults(0)), PoolId.unwrap(id));
    }

    function test_AC07_uninitialized() public {
        PoolKey memory missing = ercKey(address(tokenB), address(tokenC), 0, 1, IHooks(address(0)));
        vm.expectRevert(WeirVaults.PoolNotInitialized.selector);
        weir.createVault(missing);
        assertEq(weir.vaultCount(), 0);
    }

    function test_AC07_arrayOob() public {
        (PoolKey memory key,) = initF0();
        weir.createVault(key);
        uint256 count = weir.vaultCount();
        vm.expectRevert(bytes(""));
        weir.allVaults(count);
    }

    function test_AC08_unknownAndEmptyCreated() public {
        PoolKey memory key = f0Key();
        PoolId unknown = key.toId();
        WeirVaults.Vault memory empty = weir.vault(unknown);
        assertFalse(empty.exists);
        (uint256 q0, uint256 q1) = weir.previewRedeem(unknown, 1);
        assertEq(q0, 0);
        assertEq(q1, 0);
        assertEq(weir.sharesOf(unknown, address(this)), 0);
        (, PoolId id) = initF0();
        weir.createVault(key);
        WeirVaults.Vault memory created = weir.vault(id);
        assertTrue(created.exists);
        assertEq(created.liquidity, 0);
        (q0, q1) = weir.previewRedeem(id, 1);
        assertEq(q0, 0);
        assertEq(q1, 0);
    }

    function test_AC20_pauseBeforeDeadlineAndRecipient() public {
        (PoolKey memory key,) = initF0();
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenB, K + 2, address(weir));
        vm.prank(owner);
        weir.pause();
        vm.warp(block.timestamp + 2 hours);
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: 0,
                recipient: address(0),
                deadline: block.timestamp - 1,
                hookData: ""
            })
        );
        assertEq(tokenA.balanceOf(payer), K + 2);
    }

    function test_AC62_receive() public {
        uint256 beforeShares = weir.vaultCount();
        (bool ok,) = address(weir).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(weir.vaultCount(), beforeShares);
        assertEq(address(weir).balance, 1 ether);
    }
}
