// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    ISignatureTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {
    IAllowanceTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {DeployPermit2} from "@crane/contracts/protocols/utils/permit2/test/utils/DeployPermit2.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {ReentrantMockERC20} from "contracts/test/stubs/ReentrantMockERC20.sol";
import {TestBase_UniswapV4OrbitalSwapHook_Decimals} from
    "contracts/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook_Decimals.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";
import {
    UniswapV4OrbitalSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookMath.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4OrbitalSwapHookPackage
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookPackage.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    UniswapV4OrbitalSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_FactoryService.sol";

/**
 * @title UniswapV4OrbitalSwapHook_Decimals
 * @notice Orbital liquidity+swap+fee+preview+permit2+adversarial+reentrancy on each `B_*` book.
 * @dev pairToken = token0 (construction order). After PoolKey sort, currency0/currency1 may
 *      swap; amounts are `_u0/_u1/_u2` raw units. Hook LP stays 18. Wrappers override `_dec*`.
 */
abstract contract UniswapV4OrbitalSwapHook_Decimals is
    TestBase_UniswapV4OrbitalSwapHook_Decimals,
    DeployPermit2
{
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );
    uint256 internal userPk = 0xA11CE;
    address internal userSigner;

    function setUp() public virtual override {
        super.setUp();
        deployPermit2();
        userSigner = vm.addr(userPk);
        token0.mint(userSigner, _u0(1_000_000));
        token1.mint(userSigner, _u1(1_000_000));
        token2.mint(userSigner, _u2(1_000_000));
        vm.startPrank(userSigner);
        token0.approve(PERMIT2, type(uint256).max);
        token1.approve(PERMIT2, type(uint256).max);
        token2.approve(PERMIT2, type(uint256).max);
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Liquidity                                 */
    /* ---------------------------------------------------------------------- */

    function test_firstMint_setsRadiusAndMinLiquidity() public {
        uint256 a0 = _u0(100);
        uint256 a1 = _u1(100);
        uint256 a2 = _u2(100);
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) = _addLiquidity(a0, a1, a2);

        assertEq(u0, a0);
        assertEq(u1, a1);
        assertEq(u2, a2);
        assertEq(shares, 3 * _wadHuman(100) - Repo.MINIMUM_LIQUIDITY);
        assertEq(IERC20(hook).balanceOf(address(0)), Repo.MINIMUM_LIQUIDITY);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20Metadata(hook).decimals(), 18);

        assertEq(orbital.radius(), _wadHuman(100) * Repo.R_SAFETY_MULTIPLIER);
        assertGt(orbital.lSquared(), 0);
        assertEq(orbital.reserveOf(address(token0)), a0);
        assertEq(orbital.reserveOf(address(token1)), a1);
        assertEq(orbital.reserveOf(address(token2)), a2);
    }

    function test_firstMint_requiresTwoLegs() public {
        vm.prank(user);
        vm.expectRevert();
        orbital.addLiquidity(_u0(100), 0, 0, user, 0, block.timestamp + 1, "");
    }

    function test_previewAdd_bitExact_firstMint() public {
        uint256 a0 = _u0(50);
        uint256 a1 = _u1(50);
        uint256 a2 = _u2(50);
        (uint256 ps, uint256 p0, uint256 p1, uint256 p2) = orbital.previewAddLiquidity(a0, a1, a2);
        (uint256 es, uint256 e0, uint256 e1, uint256 e2) = _addLiquidity(a0, a1, a2);
        assertEq(ps, es);
        assertEq(p0, e0);
        assertEq(p1, e1);
        assertEq(p2, e2);
    }

    function test_fullBook_threeLeg_previewBitExact() public {
        _seedThreeLegHuman(200);
        uint256 a0 = _u0(20);
        uint256 a1 = _u1(20);
        uint256 a2 = _u2(20);
        (uint256 ps, uint256 p0, uint256 p1, uint256 p2) = orbital.previewAddLiquidity(a0, a1, a2);
        (uint256 es, uint256 e0, uint256 e1, uint256 e2) = _addLiquidity(a0, a1, a2);
        assertEq(ps, es);
        assertEq(p0, e0);
        assertEq(p1, e1);
        assertEq(p2, e2);
        assertGt(es, 0);
    }

    function test_fullBook_oneSidedReverts() public {
        _seedThreeLegHuman(200);
        vm.prank(user);
        vm.expectRevert();
        orbital.addLiquidity(_u0(10), 0, 0, user, 0, block.timestamp + 1, "");
    }

    function test_remove_bitExact_andBurnMsgSender() public {
        (uint256 shares,,,) = _addLiquidity(_u0(100), _u1(100), _u2(100));
        uint256 half = shares / 2;
        (uint256 p0, uint256 p1, uint256 p2) = orbital.previewRemoveLiquidity(half);

        uint256 b0 = token0.balanceOf(user);
        vm.prank(user);
        (uint256 a0, uint256 a1, uint256 a2) =
            orbital.removeLiquidity(half, user, 0, 0, 0, block.timestamp + 1);
        assertEq(a0, p0);
        assertEq(a1, p1);
        assertEq(a2, p2);
        assertEq(token0.balanceOf(user) - b0, a0);
        assertEq(IERC20(hook).balanceOf(user), shares - half);
    }

    function test_partial_seedOnly_sphereNav_notSumNav() public {
        _addLiquidity(_u0(100), _u1(100), 0);
        assertEq(orbital.reserveOf(address(token2)), 0);

        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 seed = _u2(50);
        uint256 expected = _sphereNavExpected(supplyBefore, seed, address(token2));
        uint256 r0w = Math.toWad(orbital.reserveOf(address(token0)), _dec0());
        uint256 r1w = Math.toWad(orbital.reserveOf(address(token1)), _dec1());
        uint256 seedW = Math.toWad(seed, _dec2());
        uint256 sumNav = (seedW * supplyBefore) / (r0w + r1w);
        assertTrue(expected != sumNav, "setup: sphere-NAV must differ from sum-NAV");

        (uint256 predShares, uint256 pred0, uint256 pred1, uint256 pred2) =
            orbital.previewAddLiquidity(0, 0, seed);
        assertEq(pred0 + pred1, 0);
        assertEq(pred2, seed);
        assertEq(predShares, expected);

        (uint256 shares,, uint256 u1, uint256 u2) = _addLiquidity(0, 0, seed);
        assertEq(u1, 0);
        assertEq(u2, seed);
        assertEq(shares, expected);
        assertTrue(shares != sumNav, "D72: must not use sum-NAV");
    }

    function _sphereNavExpected(uint256 supplyBefore, uint256 seedRaw, address seedToken)
        internal
        view
        returns (uint256 expected)
    {
        uint256 R = orbital.radius();
        uint256 r0w = Math.toWad(orbital.reserveOf(address(token0)), _dec0());
        uint256 r1w = Math.toWad(orbital.reserveOf(address(token1)), _dec1());
        uint256 r2w = Math.toWad(orbital.reserveOf(address(token2)), _dec2());
        uint8 seedDec = seedToken == address(token0)
            ? _dec0()
            : seedToken == address(token1) ? _dec1() : _dec2();
        uint256 seedW = Math.toWad(seedRaw, seedDec);
        uint256 vBefore = (R - r0w) * r0w + (R - r1w) * r1w + (R - r2w) * r2w;
        uint256 vIn = R * seedW;
        expected = (supplyBefore * vIn) / vBefore;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Swap                                      */
    /* ---------------------------------------------------------------------- */

    function _assertExactIn(address tin, address tout, uint256 amountIn) internal {
        uint256 pred = orbital.previewSwapExactIn(tin, tout, amountIn);
        assertGt(pred, 0);
        uint256 beforeOut = IERC20(tout).balanceOf(user);
        uint256 rOutBefore = orbital.reserveOf(tout);
        _swapExactIn(tin, tout, amountIn);
        uint256 got = IERC20(tout).balanceOf(user) - beforeOut;
        assertEq(got, pred, "preview==exec exact-in");
        assertGt(orbital.reserveOf(tout), 0);
        assertLt(orbital.reserveOf(tout), rOutBefore);
        assertGt(orbital.reserveOf(tin), 0);
    }

    function _amtIn(address tin, uint256 human) internal view returns (uint256) {
        if (tin == address(token0)) return _u0(human);
        if (tin == address(token1)) return _u1(human);
        return _u2(human);
    }

    function test_exactIn_allSixDirections_previewBitExact() public {
        _seedThreeLegHuman(500);
        _setDexFee(0.003e18);
        _assertExactIn(address(token0), address(token1), _amtIn(address(token0), 1));
        _assertExactIn(address(token1), address(token0), _amtIn(address(token1), 1));
        _assertExactIn(address(token1), address(token2), _amtIn(address(token1), 1));
        _assertExactIn(address(token2), address(token1), _amtIn(address(token2), 1));
        _assertExactIn(address(token0), address(token2), _amtIn(address(token0), 1));
        _assertExactIn(address(token2), address(token0), _amtIn(address(token2), 1));
    }

    function test_exactOut_previewBitExact_token0_to_token1() public {
        _seedThreeLegHuman(500);
        _setDexFee(0.003e18);
        uint256 amountOut = _u1(1) / 2;
        uint256 predIn = orbital.previewSwapExactOut(address(token0), address(token1), amountOut);
        assertGt(predIn, 0);

        uint256 beforeOut = token1.balanceOf(user);
        uint256 beforeIn = token0.balanceOf(user);

        PoolKey memory key = _poolKeyFor(address(token0), address(token1));
        address c0 = Currency.unwrap(key.currency0);
        bool zeroForOne = (address(token0) == c0);

        vm.prank(user);
        swapRouter.swapExactOut(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: int256(amountOut),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            predIn + _u0(1),
            ""
        );

        uint256 gotOut = token1.balanceOf(user) - beforeOut;
        uint256 spentIn = beforeIn - token0.balanceOf(user);
        assertEq(gotOut, amountOut);
        assertEq(spentIn, predIn);
    }

    function test_noFullDrain() public {
        _seedThreeLegHuman(500);
        _setDexFee(0.003e18);
        vm.expectRevert();
        orbital.previewSwapExactIn(address(token0), address(token1), _u0(10_000));
    }

    function test_zeroFee_path() public {
        _seedThreeLegHuman(500);
        _setDexFee(0);
        _assertExactIn(address(token0), address(token1), _amtIn(address(token0), 1));
    }

    /* ---------------------------------------------------------------------- */
    /*                              Preview                                   */
    /* ---------------------------------------------------------------------- */

    function test_preview_lp_and_swap_bitExact() public {
        _seedThreeLegHuman(300);
        _setDexFee(0.001e18);

        (uint256 ps, uint256 p0, uint256 p1, uint256 p2) =
            orbital.previewAddLiquidity(_u0(10), _u1(10), _u2(10));
        (uint256 es, uint256 e0, uint256 e1, uint256 e2) = _addLiquidity(_u0(10), _u1(10), _u2(10));
        assertEq(ps, es);
        assertEq(p0, e0);
        assertEq(p1, e1);
        assertEq(p2, e2);

        uint256 predOut = orbital.previewSwapExactIn(address(token0), address(token2), _u0(2));
        uint256 before = token2.balanceOf(user);
        _swapExactIn(address(token0), address(token2), _u0(2));
        assertEq(token2.balanceOf(user) - before, predOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Fees                                      */
    /* ---------------------------------------------------------------------- */

    function test_tradingFee_residualStaysInReserve() public {
        _seedThreeLegHuman(200);
        _setDexFee(0.01e18);
        uint256 r0Before = orbital.reserveOf(address(token0));
        uint256 amountIn = _u0(10);
        _swapExactIn(address(token0), address(token1), amountIn);
        assertEq(orbital.reserveOf(address(token0)), r0Before + amountIn);
    }

    function test_growthFee_mintsToFeeTo_afterSwaps() public {
        _seedThreeLegHuman(200);
        _setUsageFee(0.05e18);
        _addLiquidity(_u0(1), _u1(1), _u2(1));

        for (uint256 i; i < 5; i++) {
            _swapExactIn(address(token0), address(token1), _u0(5));
            _swapExactIn(address(token1), address(token0), _u1(5));
        }

        address ft = orbital.feeTo();
        uint256 feeBalBefore = IERC20(hook).balanceOf(ft);

        _addLiquidity(_u0(2), _u1(2), _u2(2));
        uint256 feeBalAfter = IERC20(hook).balanceOf(ft);
        assertGt(feeBalAfter, feeBalBefore, "protocol growth LP must mint to feeTo");
        assertEq(uint8(orbital.kLastMode()), uint8(IUniswapV4OrbitalSwapHook.KLastMode.FullProduct));
    }

    function test_feeOff_ownerFeeShareZero() public {
        _seedThreeLegHuman(100);
        _setUsageFee(1);
        address ft = orbital.feeTo();
        uint256 before = IERC20(hook).balanceOf(ft);
        _swapExactIn(address(token0), address(token1), _u0(5));
        _addLiquidity(_u0(1), _u1(1), _u2(1));
        assertEq(IERC20(hook).balanceOf(ft), before);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Adversarial                               */
    /* ---------------------------------------------------------------------- */

    function test_A1_donationsIgnored_reserveOfUnchanged() public {
        _seedThreeLegHuman(100);
        uint256 r0 = orbital.reserveOf(address(token0));
        uint256 bal = token0.balanceOf(hook);

        token0.mint(hook, _u0(50));

        assertEq(orbital.reserveOf(address(token0)), r0, "Repo SoT ignores donations");
        assertEq(token0.balanceOf(hook), bal + _u0(50), "physical balance rose");

        (uint256 shares,,,) = orbital.previewAddLiquidity(_u0(10), _u1(10), _u2(10));
        assertGt(shares, 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Permit2                                   */
    /* ---------------------------------------------------------------------- */

    function test_emptyPermit2Data_transferFromPull() public {
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) =
            _addLiquidity(_u0(10), _u1(10), _u2(10));
        assertGt(shares, 0);
        assertEq(u0, _u0(10));
        assertEq(u1, _u1(10));
        assertEq(u2, _u2(10));
        assertEq(token0.balanceOf(hook), _u0(10));
    }

    function test_signatureBatch_threeLeg_firstMint() public {
        uint256 a0 = _u0(20);
        uint256 a1 = _u1(20);
        uint256 a2 = _u2(20);
        ISignatureTransfer.TokenPermissions[] memory permitted =
            new ISignatureTransfer.TokenPermissions[](3);
        permitted[0] = ISignatureTransfer.TokenPermissions({token: address(token0), amount: a0});
        permitted[1] = ISignatureTransfer.TokenPermissions({token: address(token1), amount: a1});
        permitted[2] = ISignatureTransfer.TokenPermissions({token: address(token2), amount: a2});

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permitted, nonce: 0, deadline: block.timestamp + 1 hours
        });

        bytes memory sig = _signBatch(permit, userPk, hook);
        bytes memory permit2Data = abi.encode(uint8(0), permit, sig);

        vm.prank(userSigner);
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) = orbital.addLiquidity(
            a0, a1, a2, userSigner, 0, block.timestamp + 1 hours, permit2Data
        );
        assertGt(shares, 0);
        assertEq(u0, a0);
        assertEq(u1, a1);
        assertEq(u2, a2);
        assertEq(token0.balanceOf(hook), a0);
    }

    function test_signatureBatch_oneLeg_partialSeed() public {
        _seedThreeLegHuman(100);

        uint256 s0 = _u0(25);
        uint256 s1 = _u1(25);
        uint256 s2 = _u2(25);
        ISignatureTransfer.TokenPermissions[] memory permitted =
            new ISignatureTransfer.TokenPermissions[](3);
        permitted[0] = ISignatureTransfer.TokenPermissions({token: address(token0), amount: s0});
        permitted[1] = ISignatureTransfer.TokenPermissions({token: address(token1), amount: s1});
        permitted[2] = ISignatureTransfer.TokenPermissions({token: address(token2), amount: s2});

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permitted, nonce: 1, deadline: block.timestamp + 1 hours
        });
        bytes memory sig = _signBatch(permit, userPk, hook);
        bytes memory permit2Data = abi.encode(uint8(0), permit, sig);

        vm.prank(userSigner);
        (uint256 shares,,,) = orbital.addLiquidity(
            s0, s1, s2, userSigner, 0, block.timestamp + 1 hours, permit2Data
        );
        assertGt(shares, 0);
    }

    function test_allowanceMode_pullsUsedLegs() public {
        uint256 a0 = _u0(15);
        uint256 a1 = _u1(15);
        uint256 a2 = _u2(15);
        vm.startPrank(userSigner);
        IAllowanceTransfer(PERMIT2).approve(
            address(token0), hook, uint160(a0), uint48(block.timestamp + 1 days)
        );
        IAllowanceTransfer(PERMIT2).approve(
            address(token1), hook, uint160(a1), uint48(block.timestamp + 1 days)
        );
        IAllowanceTransfer(PERMIT2).approve(
            address(token2), hook, uint160(a2), uint48(block.timestamp + 1 days)
        );

        bytes memory permit2Data = abi.encode(uint8(1));
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) = orbital.addLiquidity(
            a0, a1, a2, userSigner, 0, block.timestamp + 1 hours, permit2Data
        );
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(u0, a0);
        assertEq(u1, a1);
        assertEq(u2, a2);
    }

    function test_wrongBatchOrder_reverts() public {
        uint256 a0 = _u0(10);
        uint256 a1 = _u1(10);
        uint256 a2 = _u2(10);
        ISignatureTransfer.TokenPermissions[] memory permitted =
            new ISignatureTransfer.TokenPermissions[](3);
        permitted[0] = ISignatureTransfer.TokenPermissions({token: address(token2), amount: a2});
        permitted[1] = ISignatureTransfer.TokenPermissions({token: address(token0), amount: a0});
        permitted[2] = ISignatureTransfer.TokenPermissions({token: address(token1), amount: a1});

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permitted, nonce: 9, deadline: block.timestamp + 1 hours
        });
        bytes memory sig = _signBatch(permit, userPk, hook);
        bytes memory permit2Data = abi.encode(uint8(0), permit, sig);

        vm.prank(userSigner);
        vm.expectRevert();
        orbital.addLiquidity(a0, a1, a2, userSigner, 0, block.timestamp + 1 hours, permit2Data);
    }

    function _signBatch(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        uint256 pk,
        address spender
    ) internal view returns (bytes memory) {
        bytes32 domainSep = IPermit2(PERMIT2).DOMAIN_SEPARATOR();

        bytes32 tokenPermissionsHash;
        {
            bytes32[] memory hashes = new bytes32[](permit.permitted.length);
            for (uint256 i; i < permit.permitted.length; i++) {
                hashes[i] = keccak256(
                    abi.encode(
                        TOKEN_PERMISSIONS_TYPEHASH,
                        permit.permitted[i].token,
                        permit.permitted[i].amount
                    )
                );
            }
            tokenPermissionsHash = keccak256(abi.encodePacked(hashes));
        }

        bytes32 permitHash = keccak256(
            abi.encode(
                PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                tokenPermissionsHash,
                spender,
                permit.nonce,
                permit.deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", domainSep, permitHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Reentrancy                                */
    /* ---------------------------------------------------------------------- */

    function test_reentrancy_addLiquidity_duringTransferFrom_reverts() public {
        MintableERC20Decimals t0 = new MintableERC20Decimals("RT0", "RT0", _dec0());
        MintableERC20Decimals t1 = new MintableERC20Decimals("RT1", "RT1", _dec1());
        ReentrantMockERC20 hostile = new ReentrantMockERC20("HOST", "HOST", _dec2());

        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = IUniswapV4OrbitalSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(t0),
            token1: address(t1),
            token2: address(hostile),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(h);
        init.deployPair(address(t0), address(t1));
        init.deployPair(address(t1), address(hostile));
        init.deployPair(address(t0), address(hostile));
        require(init.finalizeInitialization(), "finalize");
        IUniswapV4OrbitalSwapHook o = IUniswapV4OrbitalSwapHook(h);

        uint256 f0 = _u0(1_000_000);
        uint256 f1 = _u1(1_000_000);
        uint256 f2 = humanRaw(_dec2(), 1_000_000);
        t0.mint(user, f0);
        t1.mint(user, f1);
        hostile.mint(user, f2);
        vm.startPrank(user);
        t0.approve(h, type(uint256).max);
        t1.approve(h, type(uint256).max);
        hostile.approve(h, type(uint256).max);
        vm.stopPrank();

        vm.prank(user);
        o.addLiquidity(_u0(100), _u1(100), humanRaw(_dec2(), 100), user, 0, block.timestamp + 1 hours, "");

        uint256 sharesBefore = IERC20(h).balanceOf(user);
        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4OrbitalSwapHook.addLiquidity.selector,
            _u0(1),
            _u1(1),
            humanRaw(_dec2(), 1),
            user,
            uint256(0),
            block.timestamp + 1 hours,
            bytes("")
        );
        hostile.arm(h, reentry);

        vm.prank(user);
        (bool ok,) = address(o).call(
            abi.encodeWithSelector(
                IUniswapV4OrbitalSwapHook.addLiquidity.selector,
                _u0(10),
                _u1(10),
                humanRaw(_dec2(), 10),
                user,
                uint256(0),
                block.timestamp + 1 hours,
                bytes("")
            )
        );
        assertFalse(ok, "outer addLiquidity must fail under reentrancy");
        assertEq(IERC20(h).balanceOf(user), sharesBefore, "no LP minted when reentrancy blocked mid-pull");
    }

    function humanRaw(uint8 dec, uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(dec));
    }
}
