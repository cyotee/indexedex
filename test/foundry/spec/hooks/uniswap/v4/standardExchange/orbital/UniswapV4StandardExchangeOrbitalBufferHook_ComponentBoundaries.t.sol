// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookMath as OrbitalMath} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook as TestBase} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/// @notice Native rounding and reachable zero-share books on real registry-deployed SEs.
contract UniswapV4StandardExchangeOrbitalBufferHook_ComponentBoundaries is TestBase {
    function test_component_preparationQuantumPreservesSphereDomain() public {
        uint256 radius = 100 ether;
        uint256 l2 = OrbitalMath.recomputeL2(radius, 20 ether, 10 ether, 10 ether);
        vm.expectRevert(OrbitalMath.MathDomain.selector);
        OrbitalMath.sphereExactInOutWad(radius, l2, 20 ether, 10 ether, 10 ether, 1);
        assertEq(OrbitalMath.sphereLiquidityExactInOutWad(radius, l2, 20 ether, 10 ether, 10 ether, 1), 0);
        assertEq(OrbitalMath.sphereLiquidityExactInOutWad(radius, l2, 20 ether, 10 ether, 10 ether, 0), 0);
        assertEq(
            OrbitalMath.sphereLiquidityExactInOutWad(radius, l2, 20 ether, 10 ether, 10 ether, 1 ether),
            OrbitalMath.sphereExactInOutWad(radius, l2, 20 ether, 10 ether, 10 ether, 1 ether)
        );
        vm.expectRevert(OrbitalMath.MathDomain.selector);
        OrbitalMath.sphereLiquidityExactInOutWad(radius, l2, 20 ether, 10 ether, 10 ether, 80 ether);
    }

    function test_component_genesisPairInputConvertsThenRedeemsFivePercent() public {
        uint256 amount = 100 ether;
        (uint256 acquired, uint256 refund) = IStandardExchangeIn(se0).previewExchangeIn(token0, amount, IERC20(se0));
        uint256 supply = IERC20(se0).totalSupply();
        (uint256 quote,,,) = orbital.previewAddLiquidity(amount, amount, amount);
        vm.recordLogs();
        vm.prank(user);
        (uint256 net,,,) = orbital.addLiquidity(amount, amount, amount, user, quote, block.timestamp, "");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 totalMinted;
        uint256 acquiredActual;
        uint256 burnedActual;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != se0 || logs[i].topics.length != 3
                || logs[i].topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
            address from = address(uint160(uint256(logs[i].topics[1])));
            address to = address(uint160(uint256(logs[i].topics[2])));
            uint256 value = abi.decode(logs[i].data, (uint256));
            if (from == address(0)) {
                totalMinted += value;
                if (to == hook) acquiredActual += value;
            }
            if (from == hook && to == address(0)) burnedActual += value;
        }
        uint256 burned = acquired * 5 / 100;
        assertGt(burned, 0);
        assertEq(net, quote);
        assertEq(acquiredActual, acquired, "actual caller acquisition matches its preview");
        assertEq(burnedActual, acquiredActual / 20, "actual five-percent share burn");
        assertEq(IERC20(se0).totalSupply(), supply + totalMinted - burnedActual, "SE protocol fee mint is accounted separately");
        assertEq(orbital.seBalance(0), acquired - burned);
        assertGt(orbital.rawReserve(0), refund, "redemption receipt is real local backing");
        assertEq(token0.balanceOf(hook), orbital.rawReserve(0));
    }

    function _disable(bool disabled) private {
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(se0, disabled);
    }

    function test_component_bootstrapNineteenSharesRejectsBeforeFunding() public {
        _mintSeSharesToUser(se0, token0, 1 ether);
        uint256 beforeShares = IERC20(se0).balanceOf(user);
        uint256 beforePair = token1.balanceOf(user);
        vm.prank(user);
        vm.expectRevert(LiquidityRoute.ZeroLiquidityAmount.selector);
        orbital.depositFlexible(19, true, 2000, false, 2000, false, user, 1, block.timestamp);
        assertEq(IERC20(hook).totalSupply(), 0);
        assertEq(IERC20(se0).balanceOf(user), beforeShares);
        assertEq(token1.balanceOf(user), beforePair);
        assertEq(orbital.rawReserve(0), 0);
    }

    function test_component_bootstrapTwentyAndTwentyOneSharesRoundDown() public {
        // The SE's dilution fee otherwise makes one share worth less than one
        // receipt unit. Exercise the positive boundary with an exact 1:1 SE.
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se0, 0);
        vm.stopPrank();
        _mintSeSharesToUser(se0, token0, 1 ether);
        (uint256 oneShareOutput,) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(se0), 1, token0);
        assertEq(oneShareOutput, 1, "one-share bootstrap burn has a positive real receipt");
        for (uint256 amount = 20; amount <= 21; ++amount) {
            uint256 checkpoint = vm.snapshotState();
            uint256 seSupply = IERC20(se0).totalSupply();
            (uint256 quoted,,,) = orbital.previewDepositFlexible(amount, true, 2000, false, 2000, false);
            vm.prank(user);
            (uint256 net,,,) = orbital.depositFlexible(amount, true, 2000, false, 2000, false, user, quoted, block.timestamp);
            assertEq(net, quoted);
            assertEq(seSupply - IERC20(se0).totalSupply(), 1);
            assertEq(orbital.seBalance(0), amount - 1);
            assertGt(orbital.rawReserve(0), 0);
            assertEq(IERC20(hook).totalSupply(), 4000 + amount - 1, "retained-share seed, no local bonus");
            assertEq(IERC20(hook).balanceOf(address(0)), 1000);
            assertTrue(vm.revertToState(checkpoint));
        }
    }

    function test_component_bootstrapPositiveBurnZeroReceiptRejected() public {
        _mintSeSharesToUser(se0, token0, 1 ether);
        (uint256 output,) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(se0), 1, token0);
        assertEq(output, 0, "underlying dilution rounds the one-share receipt to zero");
        uint256 beforeShares = IERC20(se0).balanceOf(user);
        uint256 beforePair = token1.balanceOf(user);
        uint256 seSupply = IERC20(se0).totalSupply();
        vm.prank(user);
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        orbital.depositFlexible(20, true, 2000, false, 2000, false, user, 0, block.timestamp);
        assertEq(IERC20(se0).balanceOf(user), beforeShares);
        assertEq(token1.balanceOf(user), beforePair);
        assertEq(IERC20(se0).totalSupply(), seSupply);
        assertEq(IERC20(hook).totalSupply(), 0);
        assertEq(orbital.seBalance(0), 0);
        assertEq(orbital.rawReserve(0), 0);
    }

    function test_component_belowFloorRawSeedRollsBack() public {
        uint256 before1 = token1.balanceOf(user);
        vm.prank(user);
        vm.expectRevert(LiquidityRoute.ZeroLiquidityAmount.selector);
        orbital.depositFlexible(0, false, 400, false, 400, false, user, 0, block.timestamp);
        assertEq(token1.balanceOf(user), before1);
        assertEq(IERC20(hook).totalSupply(), 0);
    }

    function test_component_disabledZeroComponentsNeedNoContribution() public {
        uint256 ownedShares = _mintSeSharesToUser(se0, token0, 10 ether);
        _addLiquidity(0, 100 ether, 100 ether);
        assertEq(orbital.seBalance(0), 0);
        assertEq(orbital.rawReserve(0), 0);
        _disable(true);
        uint256 checkpoint = vm.snapshotState();
        (uint256 paidQuote,,,) = orbital.previewAddLiquidity(30 ether, 0, 0);
        assertGt(paidQuote, 0, "disabled input uses local paid sales, not disabled SE minting");
        vm.prank(user);
        (uint256 paid,,,) = orbital.addLiquidity(30 ether, 0, 0, user, paidQuote, block.timestamp, "");
        assertEq(paid, paidQuote);
        assertEq(orbital.seBalance(0), 0);
        assertTrue(vm.revertToState(checkpoint));
        assertEq(orbital.rawReserve(1), 100 ether);
        assertEq(orbital.rawReserve(2), 100 ether);
        (uint256 minted,,,) = _addLiquidity(0, 10 ether, 10 ether);
        assertGt(minted, 0, "zero SE components do not block the two funded raw coordinates");
        assertEq(orbital.seBalance(0), 0);
        assertEq(orbital.rawReserve(0), 0);
        uint256 supply = IERC20(hook).totalSupply();
        (uint256 quote,,,) = orbital.previewDepositFlexible(ownedShares, true, 10 ether, false, 10 ether, false);
        vm.prank(user);
        (uint256 net,,,) = orbital.depositFlexible(
            ownedShares, true, 10 ether, false, 10 ether, false, user, quote, block.timestamp
        );
        assertGt(net, 0, "already-owned shares are not needed when both components are zero");
        assertEq(IERC20(se0).balanceOf(user), ownedShares, "unused shares return to their caller");
        assertEq(orbital.seBalance(0), 0);
        uint256 gross = IERC20(hook).totalSupply() - supply;
        assertGt(gross, 0);
        assertEq(orbital.rawReserve(0), 0, "zero components accept zero");
        _disable(false);
        supply = IERC20(hook).totalSupply();
        (net,,,) = _addLiquidity(1 ether, 1 ether, 1 ether);
        assertGt(net, 0);
        gross = IERC20(hook).totalSupply() - supply;
        assertGt(gross, 0);
        assertEq(orbital.rawReserve(0), 0);
        assertEq(orbital.seBalance(0), 0, "re-enable does not invent a required share component");
    }

    function test_component_shareRequestedExitIncludesAllocatedLocal() public {
        uint256 minted = _seedThreeLeg(100 ether);
        uint256 burn = minted / 7;
        uint256 supply = IERC20(hook).totalSupply();
        uint256 sharesBefore = orbital.seBalance(0);
        uint256 localBefore = orbital.rawReserve(0);
        uint256 sharesOut = burn * sharesBefore / supply;
        uint256 localOut = burn * localBefore / supply;
        (uint256 acquired, uint256 refund) = IStandardExchangeIn(se0).previewExchangeIn(token0, localOut, IERC20(se0));
        assertEq(refund, 0, "real wrapper fully consumes allocated local input");
        uint256 userShares = IERC20(se0).balanceOf(user);
        vm.prank(user);
        (uint256 out,,) = orbital.withdrawFlexible(burn, user, true, false, false, sharesOut + acquired, 0, 0, block.timestamp);
        assertEq(out, sharesOut + acquired);
        assertEq(IERC20(se0).balanceOf(user) - userShares, out);
        assertEq(orbital.seBalance(0), sharesBefore - sharesOut);
        assertEq(orbital.rawReserve(0), localBefore - localOut);
    }

    function test_component_protocolLpWithdrawsItsOrdinaryFraction() public {
        _setUsageFee(2e16);
        _seedThreeLeg(100 ether);
        uint256 burn = IERC20(hook).balanceOf(feeRecipient);
        assertGt(burn, 0);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 local = orbital.rawReserve(0);
        uint256 shares = orbital.seBalance(0);
        uint256 raw = orbital.rawReserve(1);
        uint256 recipientRaw = token1.balanceOf(feeRecipient);
        vm.prank(feeRecipient);
        orbital.removeLiquidity(burn, feeRecipient, 1, 1, 1, block.timestamp);
        assertEq(IERC20(hook).totalSupply(), supply - burn);
        assertEq(IERC20(hook).balanceOf(feeRecipient), 0);
        assertEq(orbital.rawReserve(0), local - burn * local / supply);
        assertEq(orbital.seBalance(0), shares - burn * shares / supply);
        assertEq(token1.balanceOf(feeRecipient) - recipientRaw, burn * raw / supply);
    }

    function test_component_inactiveFeeDoesNotMintAnExtraAllocation() public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, 0);
        vm.stopPrank();
        assertEq(orbital.usageFee(), 0, "resolved fee is inactive, not merely unset");
        uint256 net = _seedThreeLeg(100 ether);
        assertEq(IERC20(hook).totalSupply(), net + 1000);
        assertEq(IERC20(hook).balanceOf(feeRecipient), 0);
    }

    function test_component_integerFeeDustAndCeilOneUnitJoin() public {
        _setUsageFee(1e13);
        vm.prank(user);
        (uint256 seed,,,) = orbital.depositFlexible(0, false, 1000, false, 1001, false, user, 1001, block.timestamp);
        assertEq(seed, 1001);
        assertEq(IERC20(hook).totalSupply(), 2001);
        assertEq(IERC20(hook).balanceOf(feeRecipient), 0, "sub-unit mint fee rounds down");
        (uint256 quote,,,) = orbital.previewAddLiquidity(0, 1, 1);
        assertEq(quote, 1, "minimum of two positive native-component limits");
        vm.prank(user);
        (uint256 net, uint256 used0, uint256 used1, uint256 used2) =
            orbital.addLiquidity(0, 1, 1, user, quote, block.timestamp, "");
        assertEq(net, 1);
        assertEq(used0, 0);
        assertEq(used1, 1);
        assertEq(used2, 1);
        assertEq(orbital.rawReserve(1), 1001);
        assertEq(orbital.rawReserve(2), 1002);
        assertEq(IERC20(hook).totalSupply(), 2002);
        assertEq(IERC20(hook).balanceOf(feeRecipient), 0);
    }
}
