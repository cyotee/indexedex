// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";
import {UniswapV3StandardExchangeInQueryTarget} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInQueryTarget.sol";
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

contract UniswapV3StandardExchange_FullRangeBook_Test is TestBase_UniswapV3StandardExchange, TransitionQuoteAssertions {
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
        vault = _deployVault(pool);
        liquid = IUniswapV3StandardExchangeLiquidReserve(address(vault));
        inMulti = IStandardExchangeInMulti(address(vault));
        lockCaller = new UniswapV3BoundPoolLockSeCaller(pool);
        ERC20PermitMintableStub(pool.token0()).mint(address(lockCaller), 100 ether);
        ERC20PermitMintableStub(pool.token1()).mint(address(lockCaller), 100 ether);
        npm = new NonfungiblePositionManager(address(uniswapV3Factory), address(1), address(new MockTokenDescriptorFr()));
    }

    function _assertProjectedState(bytes memory actual, bytes memory projected) internal pure override {
        UniswapV3StandardExchangeInQueryTarget.InventoryQuote memory q =
            abi.decode(projected, (UniswapV3StandardExchangeInQueryTarget.InventoryQuote));
        q.liquidityDelta = 0; // A fresh snapshot uses the now-current tick storage as its anchor.
        assertEq(actual, abi.encode(q), "projected inventory and pool state match execution");
    }

    function test_externalDepositTransition_preservesFundedHolderBook() public {
        _dualJoin(10_000_000 ether, 10_000_000 ether);
        for (uint256 i; i < 2; ++i) {
            IERC20 input = IERC20(i == 0 ? _token0() : _token1());
            IERC20 asset = IERC20(i == 0 ? _token1() : _token0());
            ERC20PermitMintableStub(address(input)).mint(address(this), 1_000 ether);
            _assertExternalDepositQuote(address(vault), input, asset, 1_000 ether, address(this));
        }
    }

    function test_externalSwapTransition_preservesFundedHolderBook() public {
        _dualJoin(10_000_000 ether, 10_000_000 ether);
        for (uint256 i; i < 2; ++i) {
            IERC20 input = IERC20(i == 0 ? _token0() : _token1());
            IERC20 asset = IERC20(i == 0 ? _token1() : _token0());
            ERC20PermitMintableStub(address(input)).mint(address(this), 1_000 ether);
            _assertExternalExchangeQuote(address(vault), input, asset, 1_000 ether);
        }
    }

    function testFuzz_transitionSequence_fundedPool(bool token1_, uint16 unit_) public {
        _dualJoin(10_000_000 ether, 10_000_000 ether);
        IERC20 asset = IERC20(token1_ ? _token1() : _token0());
        uint256 unit = bound(unit_, 1, 1000) * 1 ether;
        ERC20PermitMintableStub(address(asset)).mint(address(this), 100 * unit);
        _assertQuoteSequence(address(vault), asset, address(this), unit);
    }

    function testFuzz_fundedSleeveWithdrawalRounding(uint128 deposit_, uint128 wanted_) public {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), 1e18);
        uint256 deposit = bound(deposit_, 1_000_000, 1_000_000 ether);
        uint256 issued = _dualJoin(deposit, deposit);
        IERC20 asset = IERC20(_token0());
        uint256 donation = deposit / 3 + 1;
        ERC20PermitMintableStub(address(asset)).mint(address(vault), donation);
        uint256 reserve = deposit + donation;
        uint256 wanted = bound(wanted_, 1, reserve);
        uint256 expected = (wanted * issued + reserve - 1) / reserve;
        IERC20(address(vault)).transfer(address(lockCaller), issued);
        vm.prank(address(lockCaller)); IERC20(address(vault)).approve(address(vault), issued);
        uint256 beforeAssets = asset.balanceOf(address(this));
        uint256 charged = lockCaller.runExchangeOut(
            address(vault), IERC20(address(vault)), expected, asset, wanted, address(this), false, _deadline()
        );
        assertEq(charged, expected, "independent ceiling over a funded two-token book");
        assertEq(asset.balanceOf(address(this)) - beforeAssets, wanted);
        assertEq(IERC20(address(vault)).totalSupply(), issued - charged);
    }

    function testFuzz_freeInventoryExit_matchesQuote(bool token1_, bool exactOutput_) public {
        uint256 shares = _dualJoin(1_000_000_000, 1_000_000_000);
        IERC20 asset = IERC20(token1_ ? _token1() : _token0());
        IERC20 share = IERC20(address(vault));
        share.approve(address(vault), shares);
        uint256 balanceBefore = asset.balanceOf(address(this));
        if (exactOutput_) {
            uint256 wanted = 250_000_000;
            uint256 quoted = vault.previewExchangeOut(share, asset, wanted);
            uint256 charged = vault.exchangeOut(share, quoted, asset, wanted, address(this), false, _deadline());
            assertEq(charged, quoted);
            assertGe(asset.balanceOf(address(this)) - balanceBefore, wanted);
        } else {
            uint256 quoted = vault.previewExchangeIn(share, shares / 2, asset);
            uint256 received = vault.exchangeIn(share, shares / 2, asset, quoted, address(this), false, _deadline());
            assertEq(received, quoted);
            assertEq(asset.balanceOf(address(this)) - balanceBefore, quoted);
        }
    }

    function test_accruedFees_blockedDepositMatchesIdlePreview() public {
        _dualJoin(10_000_000 ether, 10_000_000 ether);
        _externalSwapExactIn(pool, true, 1000 ether);
        IERC20 asset = IERC20(_token0());
        uint256 quoted = vault.previewExchangeIn(asset, 1 ether, IERC20(address(vault)));
        ERC20PermitMintableStub(address(asset)).mint(address(lockCaller), 1 ether);
        vm.prank(address(lockCaller));
        asset.approve(address(vault), 1 ether);
        uint256 received = lockCaller.runExchangeIn(
            address(vault), asset, 1 ether, IERC20(address(vault)), quoted, address(this), false, _deadline()
        );
        assertEq(received, quoted, "pending fees stay in the share price while the pool is locked");
    }

    function testFuzz_zapOut_accruedFees_matchQuote(bool token1_) public {
        uint256 supply = _dualJoin(10_000_000 ether, 10_000_000 ether);
        _externalSwapExactIn(pool, true, 1000 ether);
        IERC20 asset = IERC20(token1_ ? _token1() : _token0());
        uint256 burned = supply / 10_000;
        uint256 quoted = vault.previewExchangeIn(IERC20(address(vault)), burned, asset);
        IERC20(address(vault)).approve(address(vault), burned);
        uint256 beforeBalance = asset.balanceOf(address(this));
        uint256 received = vault.exchangeIn(
            IERC20(address(vault)), burned, asset, quoted, address(this), false, _deadline()
        );
        assertEq(received, quoted, "withdrawal receives its share of accrued fees");
        assertEq(asset.balanceOf(address(this)) - beforeBalance, received);
    }

    function testFuzz_singleDeposit_preservesInvariantPerShare(bool token1_, uint32 amount_, uint32 skew_) public {
        _dualJoin(1_000_000_000, bound(skew_, 1_000_000, 1_000_000_000));
        uint256 amount = bound(amount_, 1_000_000, 1_000_000_000);
        (uint256 x, uint256 y) = _totals();
        uint256 supply = IERC20(address(vault)).totalSupply();
        IERC20 asset = IERC20(token1_ ? _token1() : _token0());
        address depositor = makeAddr("invariant depositor");
        ERC20PermitMintableStub(address(asset)).mint(depositor, amount);
        uint256 quote = vault.previewExchangeIn(asset, amount, IERC20(address(vault)));
        assertGt(quote, 0);
        vm.startPrank(depositor);
        asset.approve(address(vault), amount);
        uint256 minted = vault.exchangeIn(asset, amount, IERC20(address(vault)), quote, depositor, false, _deadline());
        vm.stopPrank();
        assertEq(minted, quote);
        uint256 afterSupply = supply + minted;
        uint256 afterX = x + (token1_ ? 0 : amount);
        uint256 afterY = y + (token1_ ? amount : 0);
        assertLe(afterSupply * afterSupply * x * y, supply * supply * afterX * afterY);
    }

    function testFuzz_firstDeposit_preservesEveryDonatedAsset(bool token1_, uint32 donated_) public {
        uint256 donated = bound(donated_, 1_000_000, 1_000_000_000);
        ERC20PermitMintableStub(token1_ ? _token1() : _token0()).mint(address(vault), donated);
        uint256 minted = _dualJoin(1_000_000, 10_000_000);
        uint256 supply = IERC20(address(vault)).totalSupply();
        assertLt(minted, supply);
        assertLe(minted * (1_000_000 + (token1_ ? 0 : donated)), 1_000_000 * supply);
        assertLe(minted * (10_000_000 + (token1_ ? donated : 0)), 10_000_000 * supply);
    }

    function testFuzz_singleDeposit_roundTripPreservesIncumbentValue(bool token1_) public {
        _dualJoin(10_000_000 ether, 10_000_000 ether);
        address depositor_ = makeAddr("single deposit round trip");
        IERC20 asset_ = IERC20(token1_ ? _token1() : _token0());
        uint256 amount_ = 1 ether;
        ERC20PermitMintableStub(address(asset_)).mint(depositor_, amount_);
        vm.startPrank(depositor_);
        asset_.approve(address(vault), amount_);
        uint256 shares_ = vault.exchangeIn(asset_, amount_, IERC20(address(vault)), 1, depositor_, false, _deadline());
        IERC20(address(vault)).approve(address(vault), shares_);
        uint256 received_ = vault.exchangeIn(IERC20(address(vault)), shares_, asset_, 1, depositor_, false, _deadline());
        vm.stopPrank();
        assertLe(received_, amount_, "a deposit and immediate withdrawal cannot consume incumbent value");
        assertEq(asset_.balanceOf(depositor_), received_);
    }

    function testFuzz_zapOut_previewIncludesRemovedLiquidity(bool token1_, uint16 fraction_) public {
        uint256 shares_ = _dualJoin(10_000_000 ether, 10_000_000 ether);
        uint256 burned_ = shares_ * bound(fraction_, 1, 9000) / 10_000;
        IERC20 asset_ = IERC20(token1_ ? _token1() : _token0());
        uint256 expected_ = vault.previewExchangeIn(IERC20(address(vault)), burned_, asset_);
        assertGt(expected_, 0);
        uint256 before_ = asset_.balanceOf(address(this));
        IERC20(address(vault)).approve(address(vault), burned_);
        uint256 received_ = vault.exchangeIn(
            IERC20(address(vault)), burned_, asset_, expected_, address(this), false, _deadline()
        );
        assertEq(received_, expected_, "withdrawal quote matches execution after pool liquidity removal");
        assertEq(asset_.balanceOf(address(this)) - before_, received_);
    }

    function testFuzz_zapOut_exactOutputChargesQuotedShares(bool token1_) public {
        _dualJoin(10_000_000 ether, 10_000_000 ether);
        IERC20 asset_ = IERC20(token1_ ? _token1() : _token0());
        uint256 wanted_ = 1000 ether;
        uint256 expected_ = vault.previewExchangeOut(IERC20(address(vault)), asset_, wanted_);
        uint256 sharesBefore_ = IERC20(address(vault)).balanceOf(address(this));
        assertGt(expected_, 0);
        assertLe(expected_, sharesBefore_);
        IERC20(address(vault)).approve(address(vault), expected_);
        uint256 before_ = asset_.balanceOf(address(this));
        uint256 charged_ = vault.exchangeOut(
            IERC20(address(vault)), expected_, asset_, wanted_, address(this), false, _deadline()
        );
        assertEq(charged_, expected_);
        assertEq(IERC20(address(vault)).balanceOf(address(this)), sharesBefore_ - charged_);
        assertGe(asset_.balanceOf(address(this)) - before_, wanted_);
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

    function test_FR5_bothTokensActivateThenSingleTokenDepositsRemainAvailable() public {
        uint256 amount = 10 ether;
        IERC20 input = IERC20(_token0());
        ERC20PermitMintableStub(address(input)).mint(address(this), amount);
        input.approve(address(vault), amount);
        assertEq(vault.previewExchangeIn(input, amount, IERC20(address(vault))), 0);
        uint256 balance = input.balanceOf(address(this));
        vm.expectRevert(bytes4(keccak256("UniswapV3Exchange_ZeroAmount()")));
        vault.exchangeIn(input, amount, IERC20(address(vault)), 0, address(this), false, _deadline());
        assertEq(input.balanceOf(address(this)), balance, "failed activation keeps payment");
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        assertEq(input.balanceOf(address(vault)), 0);
        uint256 issued = _dualJoin(amount, amount);
        assertGt(issued, 0);
        (int24 lower, int24 upper) = _fullRangeTicks();
        assertGt(_liquidityAt(lower, upper), 0, "dual activation creates full-range liquidity");
        input.approve(address(vault), amount);
        uint256 quote = vault.previewExchangeIn(input, amount, IERC20(address(vault)));
        assertGt(quote, 0);
        assertEq(vault.exchangeIn(input, amount, IERC20(address(vault)), quote, address(this), false, _deadline()), quote);
    }

    function test_FR6_importedNftConvertedToFullRange() public {
        int24 spacing = pool.tickSpacing();
        int24 importedLower = -spacing * 10;
        int24 importedUpper = spacing * 10;
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        assertTrue(importedLower != minTick || importedUpper != maxTick, "FR6: imported != full range");

        IStandardExchangeProxy emptyVault = _deployVault(pool);
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
        assertEq(importedL, 0, "FR6: imported narrow range fully removed");
        assertGt(fullL, 0, "FR6: conversion deploys maximum usable range");
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
