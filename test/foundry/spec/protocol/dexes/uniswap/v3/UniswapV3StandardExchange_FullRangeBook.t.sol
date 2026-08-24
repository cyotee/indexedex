// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {
    INonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {
    NonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    IUniswapV3StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";
import {
    UniswapV3BoundPoolLockSeCaller
} from "test/foundry/spec/protocol/dexes/uniswap/v3/harness/UniswapV3BoundPoolLockSeCaller.sol";

contract MockTokenDescriptorFr {
    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}

contract UniswapV3StandardExchange_FullRangeBook_Test is TestBase_UniswapV3StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IUniswapV3StandardExchangeLiquidReserve internal liquid;
    IStandardExchangeInMulti internal inMulti;
    UniswapV3BoundPoolLockSeCaller internal lockCaller;
    NonfungiblePositionManager internal npm;

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool, DEFAULT_WIDTH_MULTIPLIER);
        liquid = IUniswapV3StandardExchangeLiquidReserve(address(vault));
        inMulti = IStandardExchangeInMulti(address(vault));
        lockCaller = new UniswapV3BoundPoolLockSeCaller(pool);
        ERC20PermitMintableStub(pool.token0()).mint(address(lockCaller), 100 ether);
        ERC20PermitMintableStub(pool.token1()).mint(address(lockCaller), 100 ether);
        npm = new NonfungiblePositionManager(address(uniswapV3Factory), address(1), address(new MockTokenDescriptorFr()));
    }

    function test_FR1_centerTicksFullRange_noWings() public {
        _dualJoin(10 ether, 10 ether);
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        assertGt(_liquidityAt(minTick, maxTick), 0, "FR1: center L");
        int24 spacing = pool.tickSpacing();
        assertEq(_liquidityAt(-spacing * 10, spacing * 10), 0, "FR1: no tight center");
        assertEq(_liquidityAt(-spacing * 100, -spacing * 10), 0, "FR1: no lower wing");
        assertEq(_liquidityAt(spacing * 10, spacing * 100), 0, "FR1: no upper wing");
    }

    function test_FR2_spotWalk_centerStaysInRange_feesOrTotalsGrow() public {
        _dualJoin(50 ether, 50 ether);
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (uint256 tot0Before, uint256 tot1Before) = _totals();
        uint256 owedBefore = _tokensOwedSum(minTick, maxTick);

        _externalSwapExactIn(pool, true, 20_000 ether);
        (, int24 tickAfter,,,,,) = pool.slot0();
        assertLt(minTick, tickAfter, "FR2: above lower");
        assertLt(tickAfter, maxTick, "FR2: below upper");

        (uint256 tot0After, uint256 tot1After) = _totals();
        uint256 owedAfter = _tokensOwedSum(minTick, maxTick);
        assertTrue(
            owedAfter > owedBefore || tot0After != tot0Before || tot1After != tot1Before, "FR2: fees or totals moved"
        );
    }

    function test_FR3_rebalanceAfterWalk_ticksUnchanged_sleeveDeadband() public {
        test_FR2_spotWalk_centerStaysInRange_feesOrTotalsGrow();
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        assertGt(_liquidityAt(minTick, maxTick), 0, "FR3: had L");
        liquid.rebalanceLiquidReserve();
        assertGt(_liquidityAt(minTick, maxTick), 0, "FR3: still full-range");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_FR4_blockedJoin_thenIdleRebalance_sameFullRangeTicks() public {
        _dualJoin(10 ether, 10 ether);
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        uint256 blockedIn = 5 ether;
        address t0 = _token0();
        ERC20PermitMintableStub(t0).mint(address(lockCaller), blockedIn);
        vm.prank(address(lockCaller));
        IERC20(t0).approve(address(vault), type(uint256).max);
        lockCaller.runExchangeIn(
            address(vault), IERC20(t0), blockedIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(_liquidityAt(minTick, maxTick), 0, "FR4: center still there");
        liquid.rebalanceLiquidReserve();
        assertGt(_liquidityAt(minTick, maxTick), 0, "FR4: rebalance stays full-range");
    }

    function test_FR5_singleTokenFirstMint_thenOtherTokenMintsFullRangeL() public {
        uint256 amountIn = 10 ether;
        ERC20PermitMintableStub(_token0()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        uint256 shares = vault.exchangeIn(
            IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "FR5: shares");
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        uint128 lAfterFirst = _liquidityAt(minTick, maxTick);

        ERC20PermitMintableStub(_token1()).mint(address(this), amountIn);
        IERC20(_token1()).approve(address(vault), amountIn);
        vault.exchangeIn(IERC20(_token1()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline());
        uint128 lAfterSecond = _liquidityAt(minTick, maxTick);
        assertGt(lAfterSecond, lAfterFirst, "FR5: second token mints full-range L");
    }

    function test_FR6_importedNftTicksNotRewritten() public {
        int24 spacing = pool.tickSpacing();
        int24 importedLower = -spacing * 10;
        int24 importedUpper = spacing * 10;
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        assertTrue(importedLower != minTick || importedUpper != maxTick, "FR6: imported != full range");

        IStandardExchangeProxy emptyVault = _deployVault(pool, DEFAULT_WIDTH_MULTIPLIER);
        address token0 = pool.token0();
        address token1 = pool.token1();
        ERC20PermitMintableStub(token0).mint(address(this), 20 ether);
        ERC20PermitMintableStub(token1).mint(address(this), 20 ether);
        IERC20(token0).approve(address(npm), 20 ether);
        IERC20(token1).approve(address(npm), 20 ether);
        (uint256 tokenId,,,) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: FEE_MEDIUM,
                tickLower: importedLower,
                tickUpper: importedUpper,
                amount0Desired: 20 ether,
                amount1Desired: 20 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 1
            })
        );
        IERC721(address(npm)).approve(address(emptyVault), tokenId);
        uint256 shares = IUniswapV3StandardExchangePositionImport(address(emptyVault))
            .importPosition(npm, tokenId, 0, address(this), address(this), _deadline());
        assertGt(shares, 0, "FR6: import minted");

        IUniswapV3StandardExchangeLiquidReserve boundLiq = IUniswapV3StandardExchangeLiquidReserve(address(emptyVault));
        boundLiq.rebalanceLiquidReserve();
        (uint128 importedL,,,,) =
            pool.positions(keccak256(abi.encodePacked(address(emptyVault), importedLower, importedUpper)));
        (uint128 fullL,,,,) = pool.positions(keccak256(abi.encodePacked(address(emptyVault), minTick, maxTick)));
        assertGt(importedL, 0, "FR6: imported ticks hold L");
        assertEq(fullL, 0, "FR6: not rewritten to min/max");
    }

    function _dualJoin(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        ERC20PermitMintableStub(_token0()).mint(address(this), amount0);
        ERC20PermitMintableStub(_token1()).mint(address(this), amount1);
        IERC20(_token0()).approve(address(vault), amount0);
        IERC20(_token1()).approve(address(vault), amount1);
        address[] memory tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = _token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
        shares = inMulti.exchangeInManyToOne(tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline());
    }

    function _fullRangeTicks() internal view returns (int24 minTick, int24 maxTick) {
        int24 spacing = pool.tickSpacing();
        minTick = TickMath.minUsableTick(spacing);
        maxTick = TickMath.maxUsableTick(spacing);
    }

    function _liquidityAt(int24 lo, int24 hi) internal view returns (uint128 liq) {
        (liq,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), lo, hi)));
    }

    function _tokensOwedSum(int24 lo, int24 hi) internal view returns (uint256) {
        (,,, uint128 o0, uint128 o1) = pool.positions(keccak256(abi.encodePacked(address(vault), lo, hi)));
        return uint256(o0) + uint256(o1);
    }

    function _totals() internal view returns (uint256, uint256) {
        (uint256 d0, uint256 d1) = liquid.deployedReserve();
        return (liquid.localReserve(_token0()) + d0, liquid.localReserve(_token1()) + d1);
    }

    function _assertFreeWithinDeadband(uint256 liquidPct) internal view {
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        uint256 free0 = liquid.localReserve(_token0());
        uint256 free1 = liquid.localReserve(_token1());
        uint256 total0 = free0 + dep0;
        uint256 total1 = free1 + dep1;
        if (total0 > 0) {
            uint256 target0 = (total0 * liquidPct) / ONE_WAD;
            uint256 dev0 = free0 > target0 ? free0 - target0 : target0 - free0;
            uint256 tol0 = target0 == 0 ? 1e12 : (target0 * 0.05e18) / ONE_WAD;
            if (tol0 < 1e12) tol0 = 1e12;
            assertLe(dev0, tol0 + total0 / 4 + 1e15, "token0 band");
        }
        if (total1 > 0) {
            uint256 target1 = (total1 * liquidPct) / ONE_WAD;
            uint256 dev1 = free1 > target1 ? free1 - target1 : target1 - free1;
            uint256 tol1 = target1 == 0 ? 1e12 : (target1 * 0.05e18) / ONE_WAD;
            if (tol1 < 1e12) tol1 = 1e12;
            if (target1 > 0) assertLe(dev1, tol1 + total1 / 2 + 1e15, "token1 band");
        }
    }

    function _token0() internal view returns (address) {
        return pool.token0();
    }

    function _token1() internal view returns (address) {
        return pool.token1();
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }
}
