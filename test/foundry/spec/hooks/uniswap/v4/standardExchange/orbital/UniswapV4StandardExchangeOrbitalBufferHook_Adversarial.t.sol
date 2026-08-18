// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
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
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
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

/**
 * @dev Catalog A–H residual (WP-ADV-HOOK-001) + I1/I3 pretransfer must not free-extract SE book
 *      (L-GAPS-11 / WP-I-HOOK-SEBUF-001). Leftover remains spendable via honest !pretransfer paths.
 *      Deferred P2: G composition, fork MEV.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_AdversarialTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory (R==B), no new unbooked push, pretransferred=true */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 SE-face→raw: no unbooked face (virtual seClaim R); true without push reverts U=0.
    /// @dev Do not donate SE face — free face is intentional unbooked U (L-RSRV-DUST).
    function test_I1_pretransferred_seFaceToRaw_inventoryNoInCallTransfer_revertsDelta0() public {
        _seedThreeLeg(200 ether);
        uint256 claimed_ = 5 ether;
        // token0 is SE-buffered — do not donate face (that would free-credit under virtual R).
        assertEq(token0.balanceOf(attacker), 0, "attacker empty");
        assertEq(token0.allowance(attacker, hook), 0);

        uint256 se0Before_ = IERC20(se0).balanceOf(hook);
        uint256 outAttBefore_ = token1.balanceOf(attacker);
        uint256 faceHookBefore_ = token0.balanceOf(hook);
        uint256 raw1Before_ = orbital.rawReserve(1);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            claimed_,
            IERC20(address(token1)),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(token1.balanceOf(attacker), outAttBefore_, "I1: no free raw extract");
        assertEq(IERC20(se0).balanceOf(hook), se0Before_, "I1: SE book not free-spent");
        assertEq(token0.balanceOf(hook), faceHookBefore_, "I1: face inventory unmoved");
        assertEq(orbital.rawReserve(1), raw1Before_, "I1: raw1 book intact");
    }

    /// @notice I1 raw→raw: booked free raw (post-seed R==B); true without new push reverts U=0.
    /// @dev L-RSRV-DUST: bare donation free-credits until sync — I1 is booked inventory only.
    function test_I1_pretransferred_rawToRaw_inventoryNoInCallTransfer_revertsDelta0() public {
        _seedThreeLeg(200 ether);
        uint256 claimed_ = 5 ether;
        // Seeded free raw is end-synced (booked). Absolute B may cover claimed; U must not.
        assertGe(token1.balanceOf(hook), claimed_, "booked raw inventory present");
        assertEq(token1.balanceOf(attacker), 0, "attacker empty");
        assertEq(token1.allowance(attacker, hook), 0, "no allowance");

        uint256 outAttBefore_ = token2.balanceOf(attacker);
        uint256 raw1Before_ = orbital.rawReserve(1);
        uint256 raw2Before_ = orbital.rawReserve(2);
        uint256 face1Before_ = token1.balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            claimed_,
            IERC20(address(token2)),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(token2.balanceOf(attacker), outAttBefore_, "I1: no free token2 extract");
        assertEq(orbital.rawReserve(1), raw1Before_, "I1: raw1 book intact");
        assertEq(orbital.rawReserve(2), raw2Before_, "I1: raw2 book intact");
        assertEq(token1.balanceOf(hook), face1Before_, "I1: booked raw unmoved");
    }

    /// @notice I1 exact-out: booked free raw (post-seed R==B); true without new push reverts U=0.
    /// @dev Do not bare-donate residual for theater — L-RSRV-DUST free-credits until booked.
    function test_I1_pretransferred_exchangeOut_revertsDelta0() public {
        _seedThreeLeg(200 ether);
        uint256 wantOut_ = 1 ether;

        uint256 needIn_ = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token2)), wantOut_
        );
        assertGt(needIn_, 0);
        assertGe(token1.balanceOf(hook), needIn_, "booked inventory covers claimed amountIn");

        uint256 outAttBefore_ = token2.balanceOf(attacker);
        uint256 face1Before_ = token1.balanceOf(hook);
        uint256 raw2Before_ = orbital.rawReserve(2);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, needIn_, uint256(0)
            )
        );
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            needIn_,
            IERC20(address(token2)),
            wantOut_,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(token2.balanceOf(attacker), outAttBefore_, "I1 out: no free extract");
        assertEq(token1.balanceOf(hook), face1Before_, "I1 out: no free refund extract");
        assertEq(orbital.rawReserve(2), raw2Before_, "I1 out: raw2 book intact");
    }

    /// @notice Unfunded pretransfer (booked inventory / U=0, no new push) reverts with delta 0.
    function test_I1_pretransferred_unfunded_revertsDelta0() public {
        _seedThreeLeg(200 ether);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(5 ether), uint256(0)
            )
        );
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

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer credit     */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest raw→raw, booked state (U=0) cannot fund free pretransfer.
    /// @dev Bare residual donate free-credits until full balanceOf end-sync (production gap vs CP).
    ///      I3 here proves post-honest booked inventory without unbooked residual face.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_rawToRaw() public {
        _seedThreeLeg(200 ether);

        uint256 honestIn_ = 3 ether;
        token1.mint(user, honestIn_);
        vm.startPrank(user);
        token1.approve(hook, honestIn_);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            honestIn_,
            IERC20(address(token2)),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest raw->raw ok");

        // After end-sync R tracks book (reserves), not bare-donated dust.
        uint256 claimed_ = 4 ether;
        assertGe(token1.balanceOf(hook), claimed_, "booked raw inventory present");
        uint256 residual_ = token1.balanceOf(hook);
        uint256 raw2Before_ = orbital.rawReserve(2);
        uint256 outAttBefore_ = token2.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            claimed_,
            IERC20(address(token2)),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(token1.balanceOf(hook), residual_, "I3 residual unmoved");
        assertEq(orbital.rawReserve(2), raw2Before_, "I3 book not free-spent");
        assertEq(token2.balanceOf(attacker), outAttBefore_, "I3 no free extract");
    }

    /// @notice Legacy alias: unfunded exchangeOut reverts (I1 class).
    function test_pretransferred_exchangeOut_withoutFunding_reverts() public {
        _seedThreeLeg(200 ether);
        uint256 need_ = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token0)), IERC20(address(token1)), 1 ether
        );
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, need_, uint256(0)
            )
        );
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token0)),
            type(uint256).max,
            IERC20(address(token1)),
            1 ether,
            user,
            true,
            block.timestamp + 1 hours
        );
    }

    /// @notice H3: native CL addLiquidity always LiquidityNotAllowed.
    function test_H3_nativeCL_beforeAddLiquidity_reverts_LiquidityNotAllowed() public {
        _seedThreeLeg(50 ether);
        ModifyLiquidityParams memory p =
            ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: bytes32(0)});
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeAddLiquidity(address(this), poolKey01, p, "");
    }

    /// @notice H4: native CL removeLiquidity always LiquidityNotAllowed.
    function test_H4_nativeCL_beforeRemoveLiquidity_reverts_LiquidityNotAllowed() public {
        _seedThreeLeg(50 ether);
        ModifyLiquidityParams memory p =
            ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: -1e18, salt: bytes32(0)});
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeRemoveLiquidity(address(this), poolKey01, p, "");
    }

    /// @notice F3: distinct SE binding rejected on deploy.
    function test_F3_distinctSE_reject_onDeploy() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.se0 = se0;
        args.se2 = se0;
        vm.expectRevert();
        hookPkg.processArgs(abi.encode(args));
    }

    /// @notice F2: SE share is never a pool currency.
    function test_F2_seShare_not_pool_currency() public view {
        assertTrue(Currency.unwrap(poolKey01.currency0) != se0);
        assertTrue(Currency.unwrap(poolKey01.currency1) != se0);
        assertTrue(Currency.unwrap(poolKey01.currency0) != se1);
    }

    /// @notice H1: SE invert missing → full tx reverts (D31a).
    function test_H1_seInvertMissing_fullTxReverts() public {
        // Real SE + hook; force missing exact-out invert via mockCall on SE (non-SUT failure mode).
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(false, true, false); // buffer token1 only
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h);
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

    /// @notice C1: hostile token reenters addLiquidity mid transferFrom → outer fails; no LP mint.
    function test_C1_reentrancy_addLiquidity_duringTransferFrom_reverts() public {
        // Hostile token2 re-enters addLiquidity mid-pull; nonReentrant must abort outer mint.
        // Min-SE: bind a real ERC-4626 SE on leg0; reentrancy still targets raw hostile leg pull.
        ReentrantMockERC20 hostile = new ReentrantMockERC20("HOST", "HOST", 18);
        SimpleMintableERC20 t0 = new SimpleMintableERC20("A", "A");
        SimpleMintableERC20 t1 = new SimpleMintableERC20("B", "B");
        require(
            address(t0) != address(t1) && address(t1) != address(hostile)
                && address(t0) != address(hostile),
            "addr"
        );
        SimpleYieldERC4626 v0 = new SimpleYieldERC4626(t0);
        address seLeg0 = _deployERC4626SE(address(v0));

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
            se0: seLeg0,
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
        _ensureProductDoorsAndFinalize(h, address(t0), address(t1), address(hostile));
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
