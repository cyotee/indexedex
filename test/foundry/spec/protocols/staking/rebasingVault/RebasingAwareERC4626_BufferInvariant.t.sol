// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Test} from "forge-std/Test.sol";

import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {
    RebasingAwareERC4626_Component_FactoryService
} from "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

contract RebasingBufferDetfHandler is Test {
    IHook public hook;
    IERC4626 public wrapper;
    RebasingERC20Harness public underlying;
    SimpleMintableERC20 public raw;
    address public actor;
    uint256 public joinOk;
    uint256 public swapOk;
    uint256 public exitOk;
    uint256[6] public attempts;
    uint256[6] public successes;
    uint256[6] public skips;

    constructor(
        IHook hook_,
        IERC4626 wrapper_,
        RebasingERC20Harness underlying_,
        SimpleMintableERC20 raw_,
        address actor_
    ) {
        hook = hook_;
        wrapper = wrapper_;
        underlying = underlying_;
        raw = raw_;
        actor = actor_;
    }

    function wrap(uint256 assets) external {
        attempts[0]++;
        assets = bound(assets, 1e18, 20e18);
        underlying.mint(actor, assets);
        vm.startPrank(actor);
        underlying.approve(address(wrapper), type(uint256).max);
        wrapper.deposit(assets, actor);
        successes[0]++;
        vm.stopPrank();
    }

    function join(uint256 rawAmt, uint256 shareAmt) external {
        attempts[1]++;
        uint256 shares = IERC20(address(wrapper)).balanceOf(actor);
        if (shares < 2e22) {
            skips[1]++;
            return;
        }
        // Successful-route generator stays above the pool's whole-asset/LP quantum.
        // Sub-quantum input rejection is covered by the deterministic regression below.
        shareAmt = bound(shareAmt, 1e22, shares / 2);
        rawAmt = bound(rawAmt, 1 ether, 20 ether);
        raw.mint(actor, rawAmt);
        vm.startPrank(actor);
        raw.approve(address(hook), type(uint256).max);
        IERC20(address(wrapper)).approve(address(hook), type(uint256).max);
        hook.depositWithSeShares(rawAmt, shareAmt, actor, 0, block.timestamp + 1 hours);
        joinOk++;
        successes[1]++;
        vm.stopPrank();
    }

    function swapRawForShares(uint256 amount) external {
        attempts[2]++;
        amount = bound(amount, 1e15, 2 ether);
        if (raw.balanceOf(actor) < amount) {
            raw.mint(actor, amount);
        }
        uint256 pred = IStandardExchangeIn(address(hook))
            .previewExchangeIn(IERC20(address(raw)), amount, IERC20(address(wrapper)));
        if (pred == 0) {
            skips[2]++;
            return;
        }
        vm.startPrank(actor);
        raw.approve(address(hook), type(uint256).max);
        IStandardExchangeIn(address(hook))
            .exchangeIn(
                IERC20(address(raw)), amount, IERC20(address(wrapper)), 0, actor, false, block.timestamp + 1 hours
            );
        swapOk++;
        successes[2]++;
        vm.stopPrank();
    }

    function exit(uint256 lpAmt) external {
        attempts[3]++;
        uint256 lp = IERC20(address(hook)).balanceOf(actor);
        if (lp < 2e10) {
            skips[3]++;
            return;
        }
        lpAmt = bound(lpAmt, 1e10, lp / 2);
        vm.startPrank(actor);
        hook.withdrawSeShares(lpAmt, actor, 0, 0, block.timestamp + 1 hours);
        exitOk++;
        successes[3]++;
        vm.stopPrank();
    }

    function rebase(int256 delta) external {
        attempts[4]++;
        delta = bound(delta, -2e18, 5e18);
        if (delta == 0) {
            skips[4]++;
            return;
        }
        uint256 assets = wrapper.totalAssets();
        if (delta < 0 && uint256(-delta) >= assets) {
            skips[4]++;
            return;
        }
        underlying.rebase(address(wrapper), delta);
        successes[4]++;
    }

    function donateUnderlying(uint256 amount) external {
        attempts[5]++;
        amount = bound(amount, 1, 5e18);
        underlying.mint(address(wrapper), amount);
        successes[5]++;
    }
}

contract RebasingAwareERC4626_BufferInvariant is TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IERC4626 internal wrapper;
    RebasingERC20Harness internal underlying;
    IHook internal wrapperHook;
    RebasingBufferDetfHandler internal handler;

    function setUp() public override {
        TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.setUp();
        _deployWrapper();
        underlying.mint(user, 400e18);
        vm.startPrank(user);
        underlying.approve(address(wrapper), type(uint256).max);
        wrapper.deposit(200e18, user);
        vm.stopPrank();
        _deployWrapperHook();
        rawToken.mint(user, 200 ether);
        vm.startPrank(user);
        rawToken.approve(address(wrapperHook), type(uint256).max);
        IERC20(address(wrapper)).approve(address(wrapperHook), type(uint256).max);
        wrapperHook.depositWithSeShares(
            40 ether, IERC20(address(wrapper)).balanceOf(user) / 2, user, 0, block.timestamp + 1 hours
        );
        vm.stopPrank();
        handler = new RebasingBufferDetfHandler(wrapperHook, wrapper, underlying, rawToken, user);
        handler.wrap(2e18);
        handler.join(1e18, 1e28);
        handler.swapRawForShares(1e16);
        handler.exit(1e12);
        handler.rebase(-1e18);
        handler.donateUnderlying(1e18);
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = handler.wrap.selector;
        selectors[1] = handler.join.selector;
        selectors[2] = handler.swapRawForShares.selector;
        selectors[3] = handler.exit.selector;
        selectors[4] = handler.rebase.selector;
        selectors[5] = handler.donateUnderlying.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function afterInvariant() public view {
        for (uint256 i; i < 6; ++i) {
            assertGt(handler.successes(i), 0);
        }
        assertGt(handler.joinOk(), 0);
        assertGt(handler.swapOk(), 0);
        assertGt(handler.exitOk(), 0);
    }

    /// @notice Seed 1 shrank a failed success-generator join to 5,803 share units.
    function test_REG_subQuantumJoinRevertsAtomically() public {
        uint256 rawBefore = rawToken.balanceOf(user);
        uint256 sharesBefore = wrapper.balanceOf(user);
        uint256 lpBefore = IERC20(address(wrapperHook)).totalSupply();
        vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
        vm.prank(user);
        wrapperHook.depositWithSeShares(1e18, 5803, user, 0, block.timestamp);
        assertEq(rawToken.balanceOf(user), rawBefore);
        assertEq(wrapper.balanceOf(user), sharesBefore);
        assertEq(IERC20(address(wrapperHook)).totalSupply(), lpBefore);
    }

    function invariant_INV12_wrapperFeeTypeRemainsZero() public view {
        assertEq(IStandardVault(address(wrapper)).vaultFeeTypeIds(), bytes32(0));
        assertEq(IStandardVault(address(wrapperHook)).vaultFeeTypeIds(), bytes32(0));
    }

    function invariant_wrapperBackingEqualsHeldAsset() public view {
        assertEq(wrapper.totalAssets(), underlying.balanceOf(address(wrapper)));
    }

    function invariant_hookPairCustodyIsWrapperShares() public view {
        uint256 lp = IERC20(address(wrapperHook)).totalSupply();
        if (lp <= 1000) return;
        uint256 hookShares = IERC20(address(wrapper)).balanceOf(address(wrapperHook));
        uint256 hookRaw = rawToken.balanceOf(address(wrapperHook));
        assertGt(hookShares, 1);
        assertGt(hookRaw, 1);
        uint256 known = IERC20(address(wrapper)).balanceOf(user) + hookShares
            + IERC20(address(wrapper)).balanceOf(address(handler));
        assertEq(known, IERC20(address(wrapper)).totalSupply());
    }

    function invariant_identitySeEqualsPair() public view {
        assertEq(wrapperHook.standardExchangeOf(address(wrapper)), address(wrapper));
        assertEq(wrapper.asset(), address(underlying));
        assertTrue(address(wrapper) != address(underlying));
    }

    function _deployWrapper() internal {
        IFacet erc4626F = create3Factory.deployRebasingAwareERC4626Facet();
        IFacet seF = create3Factory.deployRebasingAwareStandardExchangeFacet();
        IFacet syF = create3Factory.deployRebasingAwareStandardYieldFacet();
        IFacet metaF = create3Factory.deployRebasingAwareVaultMetadataFacet();
        IFacet quoteF = create3Factory.deployRebasingAwareStandardExchangeQuoteFacet();
        vm.prank(owner);
        IRebasingAwareERC4626DFPkg wpkg = RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
            indexedexManager,
            IRebasingAwareERC4626DFPkg.PkgInit({
                erc20Facet: erc20Facet,
                rebasingAwareErc4626Facet: erc4626F,
                diamondFactory: diamondPackageFactory,
                standardExchangeFacet: seF,
                standardYieldFacet: syF,
                vaultMetadataFacet: metaF,
                transitionQuoteFacet: quoteF,
                vaultRegistry: IVaultRegistryDeployment(address(indexedexManager))
            })
        );
        underlying = new RebasingERC20Harness("Rebase", "RBS", 18);
        wrapper = wpkg.deployVault(IERC20Metadata(address(underlying)), 10, bytes32(uint256(88)));
    }

    function _deployWrapperHook() internal {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchange = address(wrapper);
        args.pairToken = address(wrapper);
        args.pairTokenDecimals = IERC20Metadata(address(wrapper)).decimals();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address wHook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(wHook, address(rawToken), address(wrapper));
        wrapperHook = IHook(wHook);
    }
}
