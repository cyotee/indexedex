// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {ReentrantMockERC20} from "contracts/test/stubs/ReentrantMockERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_AdversarialTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    function test_pretransferred_exchangeIn_withoutFunding_reverts() public {
        _seedThreeLeg(200 ether);
        // No transfer of token0 to hook; pretransferred=true must not drain book.
        vm.prank(user);
        vm.expectRevert();
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            5 ether,
            IERC20(address(token1)),
            0,
            user,
            true,
            block.timestamp + 1 hours
        );
    }

    function test_pretransferred_exchangeOut_withoutFunding_reverts() public {
        _seedThreeLeg(200 ether);
        vm.prank(user);
        vm.expectRevert();
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token0)),
            10 ether,
            IERC20(address(token1)),
            1 ether,
            user,
            true,
            block.timestamp + 1 hours
        );
    }

    function test_pretransferred_exchangeIn_withFunding_works() public {
        _seedThreeLeg(200 ether);
        uint256 amountIn = 3 ether;
        uint256 preview = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(token0)), amountIn, IERC20(address(token1))
        );
        // Fund free balance on hook (beyond book reserves)
        token0.mint(user, amountIn);
        vm.prank(user);
        token0.transfer(hook, amountIn);
        uint256 outBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            amountIn,
            IERC20(address(token1)),
            preview,
            user,
            true,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(token1.balanceOf(user) - outBefore, out);
    }

    function test_nativeCL_beforeAddLiquidity_reverts_LiquidityNotAllowed() public {
        _seedThreeLeg(50 ether);
        ModifyLiquidityParams memory p =
            ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: bytes32(0)});
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeAddLiquidity(address(this), poolKey01, p, "");
    }

    function test_nativeCL_beforeRemoveLiquidity_reverts_LiquidityNotAllowed() public {
        _seedThreeLeg(50 ether);
        ModifyLiquidityParams memory p =
            ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: -1e18, salt: bytes32(0)});
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeRemoveLiquidity(address(this), poolKey01, p, "");
    }

    function test_distinctSE_reject_onDeploy() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.se0 = se0;
        args.se2 = se0;
        vm.expectRevert();
        hookPkg.processArgs(abi.encode(args));
    }

    function test_seShare_not_pool_currency() public view {
        assertTrue(Currency.unwrap(poolKey01.currency0) != se0);
        assertTrue(Currency.unwrap(poolKey01.currency1) != se0);
        assertTrue(Currency.unwrap(poolKey01.currency0) != se1);
    }

    function test_D31a_seInvertMissing_fullTxReverts() public {
        // Real SE + hook; force missing exact-out invert via mockCall on SE (non-SUT failure mode).
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(false, true, false); // buffer token1 only
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        IUniswapV4StandardExchangeOrbitalBufferHook o = IUniswapV4StandardExchangeOrbitalBufferHook(h);

        token0.mint(user, 500 ether);
        token1.mint(user, 500 ether);
        token2.mint(user, 500 ether);
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        o.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();

        // Make SE.previewExchangeOut always revert → ClaimLib.SeInvertUnavailable on exact-out path
        vm.mockCallRevert(
            se1,
            abi.encodeWithSelector(
                IStandardExchangeOut.previewExchangeOut.selector,
                IERC20(se1),
                IERC20(address(token1)),
                uint256(1 ether)
            ),
            abi.encodeWithSignature("Error(string)", "no invert")
        );
        // Broader: any previewExchangeOut on se1 reverts
        vm.mockCallRevert(
            se1,
            bytes4(keccak256("previewExchangeOut(address,address,uint256)")),
            abi.encodeWithSignature("Error(string)", "no invert")
        );

        // Exact-out of buffered token1 requires invert → full tx revert (D31a)
        vm.prank(user);
        vm.expectRevert();
        o.previewSwapExactOut(address(token0), address(token1), 1 ether);
    }

    function test_reentrancy_addLiquidity_duringTransferFrom_reverts() public {
        // Hostile token2 re-enters addLiquidity mid-pull; nonReentrant must abort outer mint.
        ReentrantMockERC20 hostile = new ReentrantMockERC20("HOST", "HOST", 18);
        SimpleMintableERC20 t0 = new SimpleMintableERC20("A", "A");
        SimpleMintableERC20 t1 = new SimpleMintableERC20("B", "B");
        require(
            address(t0) != address(t1) && address(t1) != address(hostile)
                && address(t0) != address(hostile),
            "addr"
        );

        IPoolManager pm2 = IPoolManager(address(new PoolManager(address(this))));
        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        // Reuse existing hookFactory from setUp when possible; deploy fresh package instance
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = IUniswapV4StandardExchangeOrbitalBufferHookPackage
            .PkgArgs({
            poolManager: address(pm2),
            feeOracle: address(indexedexManager),
            token0: address(t0),
            token1: address(t1),
            token2: address(hostile),
            se0: address(0),
            se1: address(0),
            se2: address(0),
            rp0: address(0),
            rp1: address(0),
            rp2: address(0),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        // Need package that posts to pm2 — deploy new package is heavy; use existing hookPkg with new pm
        // Factory package is already deployed; deployHook with pm2
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        IUniswapV4StandardExchangeOrbitalBufferHook o = IUniswapV4StandardExchangeOrbitalBufferHook(h);

        t0.mint(user, 1_000_000 ether);
        t1.mint(user, 1_000_000 ether);
        hostile.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        t0.approve(h, type(uint256).max);
        t1.approve(h, type(uint256).max);
        hostile.approve(h, type(uint256).max);
        o.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();

        uint256 sharesBefore = IERC20(h).balanceOf(user);
        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector,
            uint256(1 ether),
            uint256(1 ether),
            uint256(1 ether),
            user,
            uint256(0),
            block.timestamp + 1 hours,
            bytes("")
        );
        hostile.arm(h, reentry);

        vm.prank(user);
        (bool ok,) = h.call(
            abi.encodeWithSelector(
                IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector,
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
        assertEq(IERC20(h).balanceOf(user), sharesBefore, "no LP minted under reentrancy");
    }
}
