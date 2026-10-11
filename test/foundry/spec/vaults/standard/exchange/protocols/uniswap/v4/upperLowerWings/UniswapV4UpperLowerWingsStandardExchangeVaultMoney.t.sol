// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from "./reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultMoneyTest[]
/// @notice Production proxy money routes: target-only activation, custody, no-zap allocation and terminal exits.
contract UniswapV4UpperLowerWingsStandardExchangeVaultMoneyTest is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    Actor internal trader;
    function setUp() public override {
        super.setUp();
        trader = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pool, address(this)), keccak256("Money.trader")));
        token0.mint(address(this), 1e25); token1.mint(address(this), 1e25);
        token0.mint(address(trader), 1e25); token1.mint(address(trader), 1e25);
        token0.approve(address(wings0), type(uint256).max); token1.approve(address(wings1), type(uint256).max);
    }
    function test_outsidePoolTradeDoesNotRefreshVaultBook() public {
        _bootstrap(wings0);
        (bytes memory state,) = IStandardExchangeTransitionQuote(address(wings0)).quoteState(address(token0), address(0));
        assertGt(state.length, 0, "wings vault still quotes a snapshot");
        uint256 book0 = IBasicVault(address(wings0)).reserveOfToken(address(token0));
        uint256 book1 = IBasicVault(address(wings0)).reserveOfToken(address(token1));
        uint256 supply = IERC20(address(wings0)).totalSupply();
        trader.swapTo(key, false, 1e18, TickMath.getSqrtPriceAtTick(200));
        assertEq(IBasicVault(address(wings0)).reserveOfToken(address(token0)), book0, "outside trade leaves token0 book unchanged");
        assertEq(IBasicVault(address(wings0)).reserveOfToken(address(token1)), book1, "outside trade leaves token1 book unchanged");
        assertEq(IERC20(address(wings0)).totalSupply(), supply, "outside trade mints no shares");
        uint256 preview = IStandardExchangeIn(address(wings0)).previewExchangeIn(token0, 1e12, IERC20(address(wings0)));
        uint256 minted = IStandardExchangeIn(address(wings0)).exchangeIn(token0, 1e12, IERC20(address(wings0)), preview, address(this), false, block.timestamp);
        assertEq(minted, preview, "later deposit credits only the funded input");
    }

    function test_targetOnlyBootstrapBothOrientations() public {
        _bootstrap(wings0); _bootstrap(wings1);
    }
    function _bootstrap(IUniswapV4UpperLowerWingsStandardExchangeVault vault_) internal {
        IERC20 target = IERC20(vault_.targetToken());
        IStandardExchangeIn exchange = IStandardExchangeIn(address(vault_));
        assertEq(exchange.previewExchangeIn(target, 1e12, IERC20(address(vault_))), 1e12);
        uint256 shares = exchange.exchangeIn(target, 1e12, IERC20(address(vault_)), 1e12, address(this), false, block.timestamp);
        assertEq(shares, 1e12);
        assertEq(IERC20(address(vault_)).totalSupply(), 1e12);
        (,, uint128 core,) = vault_.position(0); assertEq(core, 0, "bootstrap core empty");
        uint8 slot = address(target) == address(token0) ? 1 : 2;
        (,, uint128 wing,) = vault_.position(slot); assertGt(wing, 0);
        (uint256 local0, uint256 local1) = vault_.localReserves();
        assertGe(slot == 1 ? local0 : local1, 1);
        assertEq(token0.balanceOf(address(vault_)), local0);
        assertEq(token1.balanceOf(address(vault_)), local1);
    }
    function test_firstDepositorReceivesDonationsAndTerminalRelease() public {
        token0.transfer(address(wings0), 1000);
        uint256 shares = _deposit(wings0, 1e12, false);
        assertEq(shares, 1e12);
        uint256 quote = IStandardExchangeIn(address(wings0)).previewExchangeIn(IERC20(address(wings0)), shares, token0);
        assertGt(quote, 1e12, "donation benefits first depositor");
        uint256 beforeBalance = token0.balanceOf(address(this));
        uint256 assets = IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), shares, token0, quote, address(this), false, block.timestamp);
        assertEq(assets, quote); assertEq(token0.balanceOf(address(this)), beforeBalance + quote);
        assertEq(IERC20(address(wings0)).totalSupply(), 0);
        for (uint8 i; i < 3; ++i) { (,, uint128 liquidity,) = wings0.position(i); assertEq(liquidity, 0); }
    }
    function testFuzz_depositPreviewAndPartialRedemption(uint64 amountSeed_, bool target0_) public {
        IUniswapV4UpperLowerWingsStandardExchangeVault vault = target0_ ? wings0 : wings1;
        IERC20 target = IERC20(vault.targetToken());
        _deposit(vault, 1e12, false);
        uint256 amount = bound(amountSeed_, 100, 1e15);
        uint256 quote = IStandardExchangeIn(address(vault)).previewExchangeIn(target, amount, IERC20(address(vault)));
        assertEq(_deposit(vault, amount, false), quote);
        uint256 supply = IERC20(address(vault)).totalSupply();
        uint256 shares = supply / 4;
        uint256 redemption = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(vault)), shares, target);
        uint256 paid = IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(vault)), shares, target, redemption, address(this), false, block.timestamp);
        assertEq(paid, redemption);
        (uint256 local0, uint256 local1) = vault.localReserves();
        assertGe(target0_ ? local0 : local1, 1);
        assertEq(IERC20(address(vault)).totalSupply(), supply - shares);
    }
    function test_pretransferCannotConsumeBookedBackingOrReplay() public {
        _deposit(wings0, 1e12, false);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 100, 0));
        _deposit(wings0, 100, true);
        token0.transfer(address(wings0), 100);
        _deposit(wings0, 100, true);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 100, 0));
        _deposit(wings0, 100, true);
    }
    function test_oneNativeUnitBootstrapFloorAndFullExit() public {
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0);
        assertEq(_deposit(wings0, 1, false), 1);
        (uint256 local0,) = wings0.localReserves(); assertEq(local0, 1);
        assertEq(IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), 1, token0, 1, address(this), false, block.timestamp), 1);
        assertEq(IERC20(address(wings0)).totalSupply(), 0);
    }
    function test_pendingDepositExcludedFromConvertedWingHarvest() public {
        _deposit(wings0, 1e12, false);
        trader.swapTo(key, false, 1e20, TickMath.getSqrtPriceAtTick(120));
        uint256 quote = IStandardExchangeIn(address(wings0)).previewExchangeIn(token0, 1e10, IERC20(address(wings0)));
        assertEq(_deposit(wings0, 1e10, false), quote);
        (,, uint128 core,) = wings0.position(0); assertGt(core, 0);
        (uint256 local0, uint256 local1) = wings0.localReserves();
        assertEq(local0, token0.balanceOf(address(wings0))); assertEq(local1, token1.balanceOf(address(wings0)));
    }
    function test_alreadyUnlockedDepositDefersConvertedWingHarvest() public {
        _deposit(wings0, 1e12, false);
        trader.swapTo(key, false, 1e20, TickMath.getSqrtPriceAtTick(120));
        (int24 lower, int24 upper, uint128 liquidity,) = wings0.position(1);
        trader.approveToken(token0, address(wings0));
        trader.callWhileUnlocked(key, address(wings0), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token0, 1e10, IERC20(address(wings0)), 0, address(trader), false, block.timestamp)));
        (int24 afterLower, int24 afterUpper, uint128 afterLiquidity,) = wings0.position(1);
        assertEq(afterLower, lower); assertEq(afterUpper, upper); assertEq(afterLiquidity, liquidity);
        (,, uint128 core,) = wings0.position(0); assertEq(core, 0);
    }
    function test_alreadyUnlockedExitUsesSleeveOnly() public {
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(1e18);
        _deposit(wings0, 1e12, false);
        IERC20(address(wings0)).transfer(address(trader), 1e9);
        (,, uint128 liquidity,) = wings0.position(1);
        bytes memory returned = trader.callWhileUnlocked(key, address(wings0), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(wings0)), 1e9, token0, 0, address(this), false, block.timestamp)));
        assertGt(abi.decode(returned, (uint256)), 0);
        (,, uint128 afterLiquidity,) = wings0.position(1); assertEq(afterLiquidity, liquidity);
    }
    function test_alreadyUnlockedUncoveredExitRollsBack() public {
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0);
        _deposit(wings0, 1e12, false);
        IERC20(address(wings0)).transfer(address(trader), 1e9);
        uint256 balance = IERC20(address(wings0)).balanceOf(address(trader));
        vm.expectPartialRevert(IUniswapV4UpperLowerWingsStandardExchangeVault.InsufficientLocalTarget.selector);
        trader.callWhileUnlocked(key, address(wings0), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(wings0)), 1e9, token0, 0, address(this), false, block.timestamp)));
        assertEq(IERC20(address(wings0)).balanceOf(address(trader)), balance);
    }
    function test_zeroValueWitnessNowRetainsFloorAndResidualIncentive() public {
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0);
        uint256 shares = _deposit(wings0, 1000000, false);
        token1.mint(address(trader), 1e30);
        trader.swapTo(key, false, 1e30, TickMath.getSqrtPriceAtTick(887221));
        assertEq(wings0.liquidationValue().value, 1, "local floor survives full wing conversion");
        uint256 paid = IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), shares, token0, 1, address(this), false, block.timestamp);
        assertEq(paid, 1); assertEq(IERC20(address(wings0)).totalSupply(), 0);
        uint256 residual = token1.balanceOf(address(wings0)); assertGt(residual, 0);
        uint256 newShares = _deposit(wings0, 1000000, false);
        assertEq(IERC20(address(wings0)).balanceOf(address(this)), newShares);
        assertGt(wings0.liquidationValue().unsold, 0, "residual included in subsequent physical book");
    }
    function test_eoaCannotClaimPretransferredTokens() public {
        token0.transfer(address(wings0), 1000);
        vm.prank(makeAddr("untrustedEOA"));
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        _deposit(wings0, 1000, true);
    }
    function test_fullSharedBoundaryRetainsExcessLocally() public {
        uint128 maximum = Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing);
        token0.mint(address(trader), 1e40); token1.mint(address(trader), 1e40);
        trader.modify(key, -887220, 887220, int256(uint256(maximum)), bytes32(0));
        assertEq(_deposit(wings0, 1e12, false), 1e12);
        (,, uint128 wing,) = wings0.position(1); assertEq(wing, 0);
        (uint256 local0,) = wings0.localReserves(); assertEq(local0, 1e12);
        trader.modify(key, -887220, 887220, -1, bytes32(0));
        _deposit(wings0, 1e12, false);
        (,, wing,) = wings0.position(1); assertEq(wing, 1, "only available shared capacity is used");
        (local0,) = wings0.localReserves(); assertEq(local0, 2e12 - 1);
    }
    function test_opposingRouteRejectedWithoutCustodyChange() public {
        uint256 beforeBalance = token1.balanceOf(address(this));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(token1), address(wings0)));
        IStandardExchangeIn(address(wings0)).exchangeIn(token1, 1000, IERC20(address(wings0)), 0, address(this), false, block.timestamp);
        assertEq(token1.balanceOf(address(this)), beforeBalance);
    }
    function _deposit(IUniswapV4UpperLowerWingsStandardExchangeVault vault_, uint256 assets_, bool pushed_) internal returns (uint256) {
        return IStandardExchangeIn(address(vault_)).exchangeIn(IERC20(address(vault_) == address(wings0) ? address(token0) : address(token1)), assets_, IERC20(address(vault_)), 0, address(this), pushed_, block.timestamp);
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultMoneyTest[]
