// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {ReentrantMockERC20} from "contracts/test/stubs/ReentrantMockERC20.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4OrbitalSwapHookFactory
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookFactory.sol";
import {
    UniswapV4OrbitalSwapHook_FactoryService as OrbitalFactoryService
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_FactoryService.sol";
import {
    UniswapV4OrbitalSwapHookCommon
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookCommon.sol";

/**
 * @title UniswapV4OrbitalSwapHook_Reentrancy_Test
 * @notice Hostile ERC-20 re-enters addLiquidity during transferFrom; global lock reverts Reentrancy.
 */
contract UniswapV4OrbitalSwapHook_Reentrancy_Test is IndexedexTest {
    SimpleMintableERC20 internal token0;
    SimpleMintableERC20 internal token1;
    ReentrantMockERC20 internal hostile;
    IUniswapV4OrbitalSwapHook internal orbital;
    address internal hook;
    address internal user = address(0xBEEF);

    function setUp() public override {
        IndexedexTest.setUp();

        token0 = new SimpleMintableERC20("T0", "T0");
        token1 = new SimpleMintableERC20("T1", "T1");
        hostile = new ReentrantMockERC20("HOST", "HOST", 18);

        IPoolManager pm = IPoolManager(address(new PoolManager(address(this))));
        IUniswapV4OrbitalSwapHookFactory factory = IUniswapV4OrbitalSwapHookFactory(
            OrbitalFactoryService.deployFactory(pm)
        );
        (bytes32 salt,) = OrbitalFactoryService.mineSalt(address(factory), address(this));
        (hook,,,) = factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(token0),
            address(token1),
            address(hostile),
            salt,
            0,
            0
        );
        orbital = IUniswapV4OrbitalSwapHook(hook);

        token0.mint(user, 1_000_000 ether);
        token1.mint(user, 1_000_000 ether);
        hostile.mint(user, 1_000_000 ether);

        vm.startPrank(user);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        hostile.approve(hook, type(uint256).max);
        vm.stopPrank();

        // Live book so subsequent add pulls hostile (token2)
        vm.prank(user);
        orbital.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
    }

    function test_reentrancy_addLiquidity_duringTransferFrom_reverts() public {
        uint256 sharesBefore = IERC20(hook).balanceOf(user);

        // Re-enter addLiquidity while lock is held during hostile transferFrom pull.
        // SafeERC20 surfaces the nested Reentrancy as TransferFromFailed — prove:
        // (1) outer call reverts, (2) no double-mint of LP to user.
        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4OrbitalSwapHook.addLiquidity.selector,
            uint256(1 ether),
            uint256(1 ether),
            uint256(1 ether),
            user,
            uint256(0),
            block.timestamp + 1 hours,
            bytes("")
        );
        hostile.arm(hook, reentry);

        vm.prank(user);
        (bool ok,) = address(orbital).call(
            abi.encodeWithSelector(
                IUniswapV4OrbitalSwapHook.addLiquidity.selector,
                uint256(10 ether),
                uint256(10 ether),
                uint256(10 ether),
                user,
                uint256(0),
                block.timestamp + 1 hours,
                bytes("")
            )
        );
        assertFalse(ok, "outer addLiquidity must fail under reentrancy");
        assertEq(
            IERC20(hook).balanceOf(user),
            sharesBefore,
            "no LP minted when reentrancy blocked mid-pull"
        );
    }
}
