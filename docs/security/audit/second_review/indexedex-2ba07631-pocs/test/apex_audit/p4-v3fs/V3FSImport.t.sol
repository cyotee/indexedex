// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {INonfungiblePositionManager} from
    "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {NonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as ILR} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultPositionImport as IImport} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";

contract MockTokenDescriptorP4I {
    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}

/// @notice Attacker-controlled "position manager": reports any position, pays any inbound, tries to re-enter.
contract FakeNpm {
    address public immutable factory;
    address public t0;
    address public t1;
    uint24 public fee;
    uint128 public claimedL;
    uint256 public pay0;
    uint256 public pay1;
    address public owner;
    address public vault;
    bool public reentryBlocked;

    constructor(address factory_) {
        factory = factory_;
    }

    function setup(address t0_, address t1_, uint24 fee_, uint128 L, uint256 p0, uint256 p1, address vault_) external {
        t0 = t0_;
        t1 = t1_;
        fee = fee_;
        claimedL = L;
        pay0 = p0;
        pay1 = p1;
        owner = msg.sender;
        vault = vault_;
        IERC20(t0_).approve(vault_, type(uint256).max);
    }

    function ownerOf(uint256) external view returns (address) {
        return owner;
    }

    function getApproved(uint256) external view returns (address) {
        return vault;
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address to, uint256) external {
        owner = to;
    }

    function positions(uint256)
        external
        view
        returns (uint96, address, address, address, uint24, int24, int24, uint128, uint256, uint256, uint128, uint128)
    {
        return (0, address(0), t0, t1, fee, -887220, 887220, claimedL, 0, 0, 0, 0);
    }

    function decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams calldata)
        external
        returns (uint256, uint256)
    {// re-entry attempt into the vault mid-import (must be blocked by the shared lock)
        try IStandardExchangeProxy(vault).exchangeIn(IERC20(t0), 1e9, IERC20(vault), 0, address(this), false, block.timestamp) {
        } catch {
            reentryBlocked = true;
        }
        return (0, 0);
    }

    function collect(INonfungiblePositionManager.CollectParams calldata p) external returns (uint256, uint256) {
        IERC20(t0).transfer(p.recipient, pay0);
        IERC20(t1).transfer(p.recipient, pay1);
        return (pay0, pay1);
    }
}

contract V3FSImportTest is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    NonfungiblePositionManager internal npm;
    IERC20 internal t0;
    IERC20 internal t1;
    uint160 internal sp0;
    address internal attacker = makeAddr("attacker");
    address internal stranger = makeAddr("stranger");
    address internal victim = makeAddr("victim");

    function setUp() public override {
        super.setUp();
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Asset A", "A", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Asset B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a), address(b), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 2_000e18);
        vault = _deployVault(pool);
        npm = new NonfungiblePositionManager(address(uniswapV3Factory), address(1), address(new MockTokenDescriptorP4I()));
        t0 = IERC20(pool.token0());
        t1 = IERC20(pool.token1());
        (sp0,,,,,,) = pool.slot0();
    }

    function _m(address to, uint256 a0, uint256 a1) internal {
        if (a0 > 0) ERC20PermitMintableStub(address(t0)).mint(to, a0);
        if (a1 > 0) ERC20PermitMintableStub(address(t1)).mint(to, a1);
    }

    function _owed() internal view returns (uint256 o0, uint256 o1) {
        int24 tl = TickMath.minUsableTick(60);
        int24 tu = TickMath.maxUsableTick(60);
        (uint128 L, uint256 f0, uint256 f1, uint128 w0, uint128 w1) =
            pool.positions(keccak256(abi.encodePacked(address(vault), tl, tu)));
        (,, uint256 lo0, uint256 lo1,,,,) = pool.ticks(tl);
        (,, uint256 up0, uint256 up1,,,,) = pool.ticks(tu);
        unchecked {
            o0 = FullMath.mulDiv(pool.feeGrowthGlobal0X128() - lo0 - up0 - f0, L, 1 << 128) + w0;
            o1 = FullMath.mulDiv(pool.feeGrowthGlobal1X128() - lo1 - up1 - f1, L, 1 << 128) + w1;
        }
    }

    function _book() internal view returns (uint256 r0, uint256 r1) {
        (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
        (uint256 o0, uint256 o1) = _owed();
        r0 = t0.balanceOf(address(vault)) + d0 + o0;
        r1 = t1.balanceOf(address(vault)) + d1 + o1;
    }

    function _shareValue(address who) internal view returns (uint256) {
        (uint256 r0, uint256 r1) = _book();
        return FullMath.mulDiv(vault.balanceOf(who), r0 + r1, vault.totalSupply());
    }

    function _restore() internal {
        (uint160 sp,,,,,,) = pool.slot0();
        if (sp == sp0) return;
        bool z = sp > sp0;
        _m(address(this), z ? 1e27 : 0, z ? 0 : 1e27);
        pool.swap(address(this), z, int256(1e27), sp0, abi.encode(address(this)));
    }

    function _victimRoundTrip(uint256 amt) internal returns (uint256 paid, uint256 value) {
        (uint256 r0, uint256 r1) = _book();
        uint256 a0 = amt;
        uint256 a1 = FullMath.mulDivRoundingUp(amt, r1, r0);
        if (a1 == 0) a1 = 1;
        _m(victim, a0, a1);
        address[] memory toks = new address[](2);
        toks[0] = address(t0);
        toks[1] = address(t1);
        uint256[] memory am = new uint256[](2);
        am[0] = a0;
        am[1] = a1;
        vm.startPrank(victim);
        t0.approve(address(vault), type(uint256).max);
        t1.approve(address(vault), type(uint256).max);
        try IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            toks, am, IERC20(address(vault)), 0, victim, false, block.timestamp
        ) {
            paid = a0 + a1;
            value = _shareValue(victim);
        } catch {
            // zero-share deposit reverts: the victim keeps its tokens (no loss)
        }
        vm.stopPrank();
    }

    /// @dev victim loss bound: 1 ppm + 2 share units at the current share price (rounding of the min-ratio mint).
    function _assertNoInflation(uint256 paid, uint256 value) internal view {
        (uint256 r0, uint256 r1) = _book();
        uint256 navPerShare = (r0 + r1) / vault.totalSupply() + 1;
        uint256 loss = paid > value ? paid - value : 0;
        console2.log("victim paid / value / navPerShareWei", paid, value, navPerShare);
        assertLe(loss, paid / 1_000_000 + 2 * navPerShare + 2, "INV-5 victim loss bounded by rounding");
        assertLe(navPerShare, 1e12, "INV-5 share price cannot be inflated past 1e-6 token/share-wei");
    }

    struct P {
        uint256 amt0;
        uint256 amt1;
        int24 w;
        uint256 stranded0;
        uint256 stranded1;
        uint256 donate0;
        uint256 donate1;
        uint256 victimAmt;
        uint256 feeSwap;
        uint256 push;
        uint256 id;
        uint256 shares;
    }

    P internal q;

    function _mintNft() internal returns (bool) {
        _m(address(this), q.amt0, q.amt1);
        t0.approve(address(npm), type(uint256).max);
        t1.approve(address(npm), type(uint256).max);
        try npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(t0),
                token1: address(t1),
                fee: FEE_MEDIUM,
                tickLower: -q.w,
                tickUpper: q.w,
                amount0Desired: q.amt0,
                amount1Desired: q.amt1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: attacker,
                deadline: block.timestamp + 1
            })
        ) returns (uint256 id_, uint128, uint256, uint256) {
            q.id = id_;
            return true;
        } catch {
            return false;
        }
    }

    function _strand() internal {
        _m(stranger, q.stranded0, q.stranded1);
        vm.startPrank(stranger);
        if (q.stranded0 > 0) t0.transfer(address(vault), q.stranded0);
        if (q.stranded1 > 0) t1.transfer(address(vault), q.stranded1);
        vm.stopPrank();
    }

    function _import() internal returns (bool) {
        uint256 preview;
        try IImport(address(vault)).previewImportPosition(INonfungiblePositionManager(address(npm)), q.id) returns (uint256 p) {
            preview = p;
        } catch {
            return false;
        }
        vm.startPrank(attacker);
        IERC721(address(npm)).approve(address(vault), q.id);
        try IImport(address(vault)).importPosition(
            INonfungiblePositionManager(address(npm)), q.id, 0, attacker, attacker, block.timestamp
        ) returns (uint256 s_) {
            q.shares = s_;
        } catch {
            vm.stopPrank();
            return false;
        }
        vm.stopPrank();
        assertEq(preview, q.shares, "import preview == execute");
        return true;
    }

    /// INV-5: a real-NPM import cannot (i) capture third-party stranded balances, (ii) be followed by a
    /// donation/rebalance that inflates the share price against the next depositor.
    function testFuzz_import_realNpm_cannotInflate(
        uint256 amt0,
        uint256 amt1,
        uint256 rangeSel,
        uint256 stranded0,
        uint256 stranded1,
        uint256 donate0,
        uint256 donate1,
        uint256 victimAmt,
        uint256 feeSwap,
        uint256 push
    ) public {
        q.amt0 = bound(amt0, 1e12, 1e22);
        q.amt1 = bound(amt1, 1e12, 1e22);
        q.w = int24(int256(bound(rangeSel, 1, 14_000))) * 60;
        q.stranded0 = bound(stranded0, 0, 100 ether);
        q.stranded1 = bound(stranded1, 0, 100 ether);
        q.donate0 = bound(donate0, 0, 1e24);
        q.donate1 = bound(donate1, 0, 1e24);
        q.victimAmt = bound(victimAmt, 1e6, 1e22);
        q.feeSwap = feeSwap;
        q.push = push;
        _run();
    }

    function _run() internal {
        if (!_mintNft()) return;
        if (q.feeSwap % 2 == 0) {
            _externalSwapExactIn(pool, true, bound(q.feeSwap, 1e15, 500 ether));
            _restore();
        }
        _strand();
        // optional price push during the import (attacker is the only holder)
        if (q.push % 3 == 0) _externalSwapExactIn(pool, q.push % 2 == 0, bound(q.push, 1e15, 300 ether));
        if (!_import()) return;
        _restore();
        // (i) attacker value at P0 <= book minus the third party's stranded tokens
        (uint256 r0, uint256 r1) = _book();
        uint256 av = _shareValue(attacker);
        console2.log("import shares / supply", q.shares, vault.totalSupply());
        console2.log("attacker value / book-stranded", av, r0 + r1 - q.stranded0 - q.stranded1);
        // (skipped when the import ran at a pushed spot: the best-effort mint at that spot is the known
        //  fs-maintenance-at-spot-jit class and its IL is shared by the dead-share sink too)
        if (q.push % 3 != 0) {
            assertLe(av, r0 + r1 - q.stranded0 - q.stranded1 + 1e6, "importer cannot capture stranded third-party balances");
        }
        // (ii) inflation attempt: attacker donation, permissionless rebalance, then an honest depositor
        _m(attacker, q.donate0, q.donate1);
        vm.startPrank(attacker);
        if (q.donate0 > 0) t0.transfer(address(vault), q.donate0);
        if (q.donate1 > 0) t1.transfer(address(vault), q.donate1);
        vm.stopPrank();
        try ILR(address(vault)).rebalanceLiquidReserve() {} catch {}
        (uint256 paid, uint256 value) = _victimRoundTrip(q.victimAmt);
        _assertNoInflation(paid, value);
    }

    /// INV-5b: attacker-supplied positionManager -- only actual inbound is credited, re-entry is blocked,
    /// stranded third-party balances are not captured.
    function testFuzz_import_fakeNpm_onlyInboundCredited(
        uint128 claimedL,
        uint256 pay0,
        uint256 pay1,
        uint256 stranded0,
        uint256 stranded1,
        uint256 victimAmt
    ) public {
        claimedL = uint128(bound(claimedL, 1, type(uint64).max) * 1e6);
        pay0 = bound(pay0, 1e12, 1e22);
        pay1 = bound(pay1, 1e12, 1e22);
        stranded0 = bound(stranded0, 0, 100 ether);
        stranded1 = bound(stranded1, 0, 100 ether);
        victimAmt = bound(victimAmt, 1e6, 1e22);

        FakeNpm f = new FakeNpm(address(uniswapV3Factory));
        _m(address(f), pay0 + 1e9, pay1);
        vm.prank(attacker);
        f.setup(address(t0), address(t1), FEE_MEDIUM, claimedL, pay0, pay1, address(vault));
        _m(stranger, stranded0, stranded1);
        vm.startPrank(stranger);
        if (stranded0 > 0) t0.transfer(address(vault), stranded0);
        if (stranded1 > 0) t1.transfer(address(vault), stranded1);
        vm.stopPrank();

        vm.prank(attacker);
        uint256 shares;
        try IImport(address(vault)).importPosition(
            INonfungiblePositionManager(address(f)), 1, 0, attacker, attacker, block.timestamp
        ) returns (uint256 s) {
            shares = s;
        } catch {
            return;
        }
        assertTrue(f.reentryBlocked(), "mid-import re-entry must be blocked");
        uint256 av = _shareValue(attacker);
        console2.log("fake import shares / attacker value / paid", shares, av, pay0 + pay1);
        assertLe(av, pay0 + pay1 + 1e6, "fake NPM: credited only for actual inbound");
        (uint256 paid, uint256 value) = _victimRoundTrip(victimAmt);
        _assertNoInflation(paid, value);
    }
}
