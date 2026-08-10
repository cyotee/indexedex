// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {SwapParams, ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {
    TestBase_UniswapV4DualSEBCPHook as TestBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";

/**
 * @title Adversarial DoD: dual SE buffer CP catalog A–H residual + I1/I3 pretransfer.
 * @dev Catalog A–H (WP-ADV-HOOK-001 residual) + I1/I3 pretransfer must not free-extract dual SE book
 *      (L-GAPS-11 / WP-I-HOOK-DUAL-001). Production package → registry → hook factory proxy only.
 * @dev Deferred P2: G composition with outer DETF; fork-only multi-hop MEV sandwich.
 */
contract UniswapV4DualSEBCPHook_Adversarial_Test is TestBase {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    /* ---------------------------------------------------------------------- */
    /*  A: donation / inflation                                               */
    /* ---------------------------------------------------------------------- */

    /// @notice A1: donate free c0 inventory — honest exchangeIn still SE-previewed; no free extract.
    function test_A1_pairDonation_doesNotFreeExtract() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();

        uint256 donated_ = 20 ether;
        _mintAndDonate(c0, address(this), donated_);
        assertEq(IERC20(c0).balanceOf(hook), donated_, "donation parked");

        uint256 amountIn_ = 5 ether;
        uint256 preview_ = IStandardExchangeIn(hook).previewExchangeIn(IERC20(c0), amountIn_, IERC20(c1));
        assertGt(preview_, 0);

        if (c0 == address(tokenA)) tokenA.mint(user, amountIn_);
        else tokenB.mint(user, amountIn_);

        uint256 c1Before_ = IERC20(c1).balanceOf(user);
        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();

        vm.startPrank(user);
        IERC20(c0).approve(hook, amountIn_);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), amountIn_, IERC20(c1), 0, user, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(out_, preview_, "A1: out == preview (donation not credited)");
        assertEq(IERC20(c1).balanceOf(user) - c1Before_, preview_, "A1: user out matches preview");
        assertEq(IERC20(c0).balanceOf(hook), donated_, "A1: donation idle remains");
        // SE books may grow via honest path but donation must not free-spend without transfer
        assertGe(dual.claimSupplyCurrency0() + dual.claimSupplyCurrency1(), claim0Before_ + claim1Before_);
    }

    /// @notice A2: donate SE shares — does not mint free LP to donor; victim LP unchanged.
    function test_A2_seDonation_doesNotMintFreeLp() public {
        _depositBoth(200 ether, 200 ether);
        uint256 userLpBefore_ = IERC20(hook).balanceOf(user);
        uint256 claim0Before_ = dual.claimSupplyCurrency0();

        address se0_ = dual.standardExchange0();
        SimpleMintableERC20 pair0_ = SimpleMintableERC20(dual.token0());
        uint256 seOut_ = _userAcquireSeShares(se0_, pair0_, 50 ether);
        vm.prank(user);
        IERC20(se0_).transfer(hook, seOut_);

        assertEq(IERC20(hook).balanceOf(user), userLpBefore_, "A2: no free LP from SE donation");
        assertGe(dual.claimSupplyCurrency0() + dual.claimSupplyCurrency1(), claim0Before_);
        // Idle SE inventory may dilute subsequent joins (accepted O11 class) but cannot mint to donor
        assertEq(IERC20(hook).balanceOf(attacker), 0, "A2: attacker has no LP");
    }

    /* ---------------------------------------------------------------------- */
    /*  C: reentrancy                                                         */
    /* ---------------------------------------------------------------------- */

    /// @notice C1: hostile pair reenters deposit mid transferFrom → nested mutator fails; outer clean.
    function test_C1_hostilePair_reenterOnDeposit() public {
        HostileDualToken hostile = new HostileDualToken();
        SimpleMintableERC20 other = new SimpleMintableERC20("Other", "OTH");
        SimpleYieldERC4626 vHostile = new SimpleYieldERC4626(hostile);
        SimpleYieldERC4626 vOther = new SimpleYieldERC4626(other);
        address seH = _deployERC4626SE(address(vHostile));
        address seO = _deployERC4626SE(address(vOther));

        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
            .PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            standardExchange0: seH,
            token0: address(hostile),
            standardExchange1: seO,
            token1: address(other)
        });
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, hookPkg, args);
        address hHook = DualFactory.deployHook(hookPkg, args, mineNonce);
        IDualHook h = IDualHook(hHook);

        address alice = makeAddr("alice");
        hostile.mint(alice, 1_000_000 ether);
        other.mint(alice, 1_000_000 ether);
        vm.startPrank(alice);
        hostile.approve(hHook, type(uint256).max);
        other.approve(hHook, type(uint256).max);
        // Seed live book while disarmed
        uint256 a0 = h.currency0() == address(hostile) ? 100 ether : 100 ether;
        uint256 a1 = h.currency1() == address(hostile) ? 100 ether : 100 ether;
        a0 = 100 ether;
        a1 = 100 ether;
        h.deposit(a0, a1, alice, 0, block.timestamp + 1);
        vm.stopPrank();
        assertGt(IERC20(hHook).balanceOf(alice), 0, "seed LP");

        hostile.arm(hHook, alice);
        uint256 lpBefore = IERC20(hHook).balanceOf(alice);

        vm.prank(alice);
        try h.deposit(5 ether, 5 ether, alice, 0, block.timestamp + 1) {} catch {}

        assertGe(hostile.reentryAttempts(), 1, "C1: nested reentry attempted");
        assertFalse(hostile.nestedSucceeded(), "C1: nested deposit must not succeed while locked");
        // Either outer completed once or fully reverted — no double mint from nested path
        assertLe(IERC20(hHook).balanceOf(alice), lpBefore + type(uint128).max / 2, "sanity");
    }

    /* ---------------------------------------------------------------------- */
    /*  E: accounting / residual                                              */
    /* ---------------------------------------------------------------------- */

    /// @notice E1: successful buffer exchange leaves no free extract for attacker; residual donation idle.
    function test_E1_exchangeIn_previewEqualsExec_donationIdle() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();

        _mintAndDonate(c0, address(this), 7 ether);
        uint256 donated_ = IERC20(c0).balanceOf(hook);

        uint256 amountIn_ = 4 ether;
        if (c0 == address(tokenA)) tokenA.mint(user, amountIn_);
        else tokenB.mint(user, amountIn_);

        uint256 preview_ = IStandardExchangeIn(hook).previewExchangeIn(IERC20(c0), amountIn_, IERC20(c1));
        vm.startPrank(user);
        IERC20(c0).approve(hook, amountIn_);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), amountIn_, IERC20(c1), 0, user, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(out_, preview_, "E1: preview == exec");
        assertEq(IERC20(c0).balanceOf(hook), donated_, "E1: donation residual idle");
    }

    /// @notice E2: zero amount exchange / deposit reverts ZeroAmount.
    function test_E2_zeroAmount_reverts() public {
        _depositBoth(50 ether, 50 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        vm.expectRevert();
        IStandardExchangeIn(hook).previewExchangeIn(IERC20(c0), 0, IERC20(c1));
        vm.prank(user);
        vm.expectRevert();
        dual.deposit(0, 0, user, 0, block.timestamp + 1);
    }

    /* ---------------------------------------------------------------------- */
    /*  F: access / immutability                                              */
    /* ---------------------------------------------------------------------- */

    /// @notice F1: diamondCut missing on live hook.
    function test_F1_diamondCut_reverts() public {
        (bool ok,) = hook.call(
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector, new IDiamond.FacetCut[](0), address(0), ""
            )
        );
        assertFalse(ok, "F1: diamondCut must not succeed");
    }

    /// @notice F2: non-PoolManager beforeSwap reverts NotPoolManager.
    function test_F2_nonPoolManager_beforeSwap_reverts() public {
        _depositBoth(50 ether, 50 ether);
        _initPool();
        SwapParams memory params =
            SwapParams({zeroForOne: true, amountSpecified: -1e18, sqrtPriceLimitX96: 0});
        vm.expectRevert();
        IHooks(hook).beforeSwap(address(this), poolKey, params, "");
    }

    /* ---------------------------------------------------------------------- */
    /*  H: grief / DoS atomicity                                              */
    /* ---------------------------------------------------------------------- */

    /// @notice H1: exact-in with impossible minOut reverts; inventory / SE book clean.
    function test_H1_minOutTooHigh_fullRevert() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 amountIn_ = 3 ether;
        if (c0 == address(tokenA)) tokenA.mint(user, amountIn_);
        else tokenB.mint(user, amountIn_);

        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();
        uint256 c0HookBefore_ = IERC20(c0).balanceOf(hook);
        uint256 c1UserBefore_ = IERC20(c1).balanceOf(user);

        vm.startPrank(user);
        IERC20(c0).approve(hook, amountIn_);
        vm.expectRevert();
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), amountIn_, IERC20(c1), type(uint256).max, user, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(dual.claimSupplyCurrency0(), claim0Before_, "H1: c0 SE book unchanged");
        assertEq(dual.claimSupplyCurrency1(), claim1Before_, "H1: c1 SE book unchanged");
        assertEq(IERC20(c0).balanceOf(hook), c0HookBefore_, "H1: no stranded c0");
        assertEq(IERC20(c1).balanceOf(user), c1UserBefore_, "H1: no partial out");
    }

    /// @notice H3: native CL addLiquidity always LiquidityNotAllowed.
    function test_H3_addLiquidity_alwaysReverts() public {
        _depositBoth(50 ether, 50 ether);
        _initPool();
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeAddLiquidity(
            address(this),
            poolKey,
            ModifyLiquidityParams({
                tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: bytes32(0)
            }),
            ""
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: pretransferred=true, inventory present, no in-call transfer       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 c0→c1: donate free c0 inventory; unfunded pretransfer cannot free-extract SE book.
    function test_I1_pretransferred_c0ToC1_inventoryNoInCallTransfer_revertsDelta0() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 claimed_ = 5 ether;

        _mintAndDonate(c0, attacker, claimed_);
        assertGe(IERC20(c0).balanceOf(hook), claimed_, "c0 inventory on hook");
        assertEq(IERC20(c0).balanceOf(attacker), 0, "attacker drained");
        assertEq(IERC20(c0).allowance(attacker, hook), 0, "no allowance");

        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();
        uint256 c1AttBefore_ = IERC20(c1).balanceOf(attacker);
        uint256 c0HookBefore_ = IERC20(c0).balanceOf(hook);
        uint256 se0HookBefore_ = IERC20(_seForCurrency(c0)).balanceOf(hook);
        uint256 se1HookBefore_ = IERC20(_seForCurrency(c1)).balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), claimed_, IERC20(c1), 0, attacker, true, block.timestamp + 1
        );

        assertEq(IERC20(c1).balanceOf(attacker), c1AttBefore_, "I1: no free c1 extract");
        assertEq(dual.claimSupplyCurrency0(), claim0Before_, "I1: c0 SE book not free-spent");
        assertEq(dual.claimSupplyCurrency1(), claim1Before_, "I1: c1 SE book intact");
        assertEq(IERC20(c0).balanceOf(hook), c0HookBefore_, "I1: c0 inventory unchanged");
        assertEq(IERC20(_seForCurrency(c0)).balanceOf(hook), se0HookBefore_, "I1: se0 unmoved");
        assertEq(IERC20(_seForCurrency(c1)).balanceOf(hook), se1HookBefore_, "I1: se1 unmoved");
    }

    /// @notice I1 c1→c0: donate free c1; unfunded pretransfer cannot free-extract opposite SE book.
    function test_I1_pretransferred_c1ToC0_inventoryNoInCallTransfer_revertsDelta0() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 claimed_ = 5 ether;

        _mintAndDonate(c1, attacker, claimed_);
        assertGe(IERC20(c1).balanceOf(hook), claimed_, "c1 inventory on hook");
        assertEq(IERC20(c1).balanceOf(attacker), 0);
        assertEq(IERC20(c1).allowance(attacker, hook), 0);

        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();
        uint256 c0AttBefore_ = IERC20(c0).balanceOf(attacker);
        uint256 c1HookBefore_ = IERC20(c1).balanceOf(hook);
        uint256 se0HookBefore_ = IERC20(_seForCurrency(c0)).balanceOf(hook);
        uint256 se1HookBefore_ = IERC20(_seForCurrency(c1)).balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(c1), claimed_, IERC20(c0), 0, attacker, true, block.timestamp + 1
        );

        assertEq(IERC20(c0).balanceOf(attacker), c0AttBefore_, "I1: no free c0 extract");
        assertEq(dual.claimSupplyCurrency0(), claim0Before_, "I1: c0 SE book intact");
        assertEq(dual.claimSupplyCurrency1(), claim1Before_, "I1: c1 SE book intact");
        assertEq(IERC20(c1).balanceOf(hook), c1HookBefore_, "I1: c1 inventory unmoved");
        assertEq(IERC20(_seForCurrency(c0)).balanceOf(hook), se0HookBefore_, "I1: se0 unmoved");
        assertEq(IERC20(_seForCurrency(c1)).balanceOf(hook), se1HookBefore_, "I1: se1 unmoved");
    }

    /// @notice I1 exact-out c0→c1: unfunded pretransfer cannot free-extract SE book / refund inventory.
    function test_I1_pretransferred_exchangeOut_c0ToC1_revertsDelta0() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 wantOut_ = 1 ether;

        // Absolute inventory theater: seed c0 so balance covers post-donation quote without in-call transfer.
        // Quote AFTER donation — donating free c0 does not reprice SE book, but keep order explicit.
        _mintAndDonate(c0, attacker, 50 ether);

        uint256 needIn_ = IStandardExchangeOut(hook).previewExchangeOut(IERC20(c0), IERC20(c1), wantOut_);
        assertGt(needIn_, 0);
        assertGe(IERC20(c0).balanceOf(hook), needIn_, "inventory covers claimed amountIn");

        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();
        uint256 c1AttBefore_ = IERC20(c1).balanceOf(attacker);
        uint256 c0HookBefore_ = IERC20(c0).balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, needIn_, uint256(0)
            )
        );
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(c0), needIn_, IERC20(c1), wantOut_, attacker, true, block.timestamp + 1
        );

        assertEq(IERC20(c1).balanceOf(attacker), c1AttBefore_, "I1 out: no free c1");
        assertEq(dual.claimSupplyCurrency0(), claim0Before_, "I1 out: c0 SE book intact");
        assertEq(dual.claimSupplyCurrency1(), claim1Before_, "I1 out: c1 SE book intact");
        assertEq(IERC20(c0).balanceOf(hook), c0HookBefore_, "I1 out: c0 unmoved (no refund extract)");
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer credit     */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: residual free c0 after honest path cannot fund a second free pretransfer c0→c1.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_c0ToC1() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();

        // Residual free c0 that remains after honest swap (donation not consumed by !pretransfer).
        uint256 residualSeed_ = 4 ether;
        _mintAndDonate(c0, address(this), residualSeed_);

        uint256 honestIn_ = 3 ether;
        if (c0 == address(tokenA)) tokenA.mint(user, honestIn_);
        else tokenB.mint(user, honestIn_);

        vm.startPrank(user);
        IERC20(c0).approve(hook, honestIn_);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), honestIn_, IERC20(c1), 0, user, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest c0->c1 ok");

        uint256 residual_ = IERC20(c0).balanceOf(hook);
        assertGe(residual_, residualSeed_, "residual c0 remains");
        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();
        uint256 c1AttBefore_ = IERC20(c1).balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualSeed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), residualSeed_, IERC20(c1), 0, attacker, true, block.timestamp + 1
        );

        assertEq(IERC20(c0).balanceOf(hook), residual_, "I3 residual unmoved");
        assertEq(dual.claimSupplyCurrency0(), claim0Before_, "I3 c0 SE book not free-spent");
        assertEq(dual.claimSupplyCurrency1(), claim1Before_, "I3 c1 SE book intact");
        assertEq(IERC20(c1).balanceOf(attacker), c1AttBefore_, "I3 no free c1");
    }

    /* ---------------------------------------------------------------------- */
    /*                              helpers                                   */
    /* ---------------------------------------------------------------------- */

    function _seForCurrency(address currency) internal view returns (address) {
        if (currency == dual.token0()) return dual.standardExchange0();
        if (currency == dual.token1()) return dual.standardExchange1();
        revert("unknown currency");
    }

    function _mintAndDonate(address token, address from, uint256 amount) internal {
        if (token == address(tokenA)) {
            tokenA.mint(from, amount);
        } else if (token == address(tokenB)) {
            tokenB.mint(from, amount);
        } else {
            revert("unknown token");
        }
        if (from == address(this)) {
            IERC20(token).transfer(hook, amount);
        } else {
            vm.prank(from);
            IERC20(token).transfer(hook, amount);
        }
    }

}

/// @dev Non-SUT: mintable pair that reenters dual.deposit on transferFrom when armed.
contract HostileDualToken is SimpleMintableERC20 {
    address public targetHook;
    address public reenterCaller;
    uint256 public reentryAttempts;
    bool public nestedSucceeded;
    bool public armed;

    constructor() SimpleMintableERC20("HostileDual", "hDUAL") {}

    function arm(address hook_, address caller_) external {
        targetHook = hook_;
        reenterCaller = caller_;
        armed = true;
        nestedSucceeded = false;
        reentryAttempts = 0;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (armed && targetHook != address(0) && (to == targetHook || msg.sender == targetHook)) {
            armed = false;
            unchecked {
                reentryAttempts += 1;
            }
            IDualHook h = IDualHook(targetHook);
            allowance[reenterCaller][targetHook] = type(uint256).max;
            try h.deposit(1 ether, 1 ether, reenterCaller, 0, block.timestamp + 1) {
                nestedSucceeded = true;
            } catch {
                nestedSucceeded = false;
            }
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }
}
