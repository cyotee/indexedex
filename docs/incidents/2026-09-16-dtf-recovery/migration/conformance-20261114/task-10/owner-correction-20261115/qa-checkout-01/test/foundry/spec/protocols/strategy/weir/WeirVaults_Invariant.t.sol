// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";

contract WeirHandler is TestBase_WeirVaults {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;

    address[3] public users;
    PoolKey public key;
    PoolId public id;
    uint256 public deposits;
    uint256 public transfers;

    constructor() {
        setUp();
        users[0] = address(0xA11CE);
        users[1] = address(0xB0B);
        users[2] = address(0xCAFE);
        (key, id) = initF0();
        for (uint256 i; i < users.length; i++) {
            fund(users[i], tokenA, 4 * (K + 2), address(weir));
            fund(users[i], tokenB, 4 * (K + 2), address(weir));
        }
    }

    function deposit(uint256 userSeed) external {
        address user = users[userSeed % users.length];
        vm.prank(user);
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: 0,
                recipient: user,
                deadline: deadline(),
                hookData: ""
            })
        );
        deposits++;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 shares) external {
        address from = users[fromSeed % users.length];
        address to = users[toSeed % users.length];
        uint256 balance = weir.sharesOf(id, from);
        if (balance == 0 || from == to) return;
        vm.prank(from);
        weir.transferShares(id, to, (shares % balance) + 1 > balance ? balance : (shares % balance) + 1);
        transfers++;
    }

    function assertConsistent() external view {
        WeirVaults.Vault memory vault = weir.vault(id);
        if (!vault.exists) return;
        (uint128 position,,) =
            poolManager.getPositionInfo(id, address(weir), vault.tickLower, vault.tickUpper, bytes32(0));
        assertEq(position, vault.liquidity);
        assertFalse(poolManager.isUnlocked());
        uint256 assigned;
        for (uint256 i; i < users.length; i++) {
            assigned += weir.sharesOf(id, users[i]);
        }
        assertEq(assigned, vault.totalShares - 1000);
        assertEq(vault.idle0, 0);
        assertEq(vault.idle1, 0);
        assertEq(tokenA.balanceOf(address(weir)), 0);
        assertEq(tokenB.balanceOf(address(weir)), 0);
    }
}

contract WeirVaults_InvariantTest is TestBase_WeirVaults {
    WeirHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new WeirHandler();
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = WeirHandler.deposit.selector;
        selectors[1] = WeirHandler.transfer.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_AC63_supportedDomain() public view {
        handler.assertConsistent();
    }
}
