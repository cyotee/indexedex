// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseNftFixture} from "./harness/FullSpreadReleaseNftFixture.sol";
import {UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller as LockedCaller} from "./harness/UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultPositionImport as Importer} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";

/// @notice Full-range regressions migrated to V3-ACC-02/09/11/12/15/20 and V3-OWN-01.
contract UniswapV3FullSpreadStandardExchangeVault_FullRangeBook_Test is FullSpreadReleaseNftFixture {
    function test_externalDeposit_preservesIncumbentShares_andUsesLiquidityBasis() public {
        uint256 incumbent = _join(1000 ether, 1000 ether);
        for (uint256 i; i < 2; ++i) {
            uint256 supply = vault.totalSupply();
            uint128 liquidity = _liquidity();
            (uint256 issued,) = _mintOne(i == 0 ? token0 : token1, 1 ether, alice);
            assertGt(issued, 0);
            assertEq(issued, uint256(_liquidity() - liquidity) * supply / liquidity);
            assertEq(vault.balanceOf(address(this)), incumbent);
        }
    }
    function test_externalSwap_preservesSupplyAndPositionLiquidity() public {
        _join(1000 ether, 1000 ether);
        uint256 supply = vault.totalSupply();
        uint128 liquidity = _liquidity();
        for (uint256 i; i < 2; ++i) {
            IERC20 input = i == 0 ? token0 : token1;
            IERC20 output = i == 0 ? token1 : token0;
            _fund(input, address(this), 1 ether);
            input.approve(address(vault), 1 ether);
            (uint256 quote,) = vault.previewExchangeIn(input, 1 ether, output);
            (uint256 paid,) = vault.exchangeIn(input, 1 ether, output, quote, alice, false, block.timestamp);
            assertEq(paid, quote);
            assertEq(vault.totalSupply(), supply);
            assertEq(_liquidity(), liquidity);
            _assertReserves();
        }
    }
    function testFuzz_operationSequence_fundedPool(bool side, uint16 unit) public {
        _join(1000 ether, 1000 ether);
        IERC20 input = side ? token1 : token0;
        uint256 amount = bound(unit, 1, 1000) * 1e15;
        (uint256 quote,) = vault.previewExchangeIn(input, amount, IERC20(address(vault)));
        (uint256 issued,) = _mintOne(input, amount, address(this));
        assertEq(issued, quote);
        (uint256 receipt,) = vault.previewExchangeIn(IERC20(address(vault)), issued, input);
        (uint256 paid,) = vault.exchangeIn(IERC20(address(vault)), issued, input, receipt, alice, false, block.timestamp);
        assertEq(paid, receipt);
        assertEq(input.balanceOf(alice), receipt);
        _assertReserves();
    }
    function testFuzz_fundedWithdrawalRounding(uint128 depositSeed, uint128 burnSeed) public {
        uint256 deposit = bound(depositSeed, 1e12, 1_000_000 ether);
        uint256 issued = _join(deposit, deposit);
        uint256 burn = bound(burnSeed, 1, issued);
        uint256 supply = vault.totalSupply();
        uint128 removed = uint128(uint256(_liquidity()) * burn / supply);
        (uint256 a0, uint256 a1) = _principal(removed);
        uint256[] memory paid = _bundleExit(burn);
        assertEq(paid[0], a0);
        assertEq(paid[1], a1);
        assertEq(vault.totalSupply(), supply - burn);
    }
    function testFuzz_unbookedInventoryExit_matchesDisposition(bool side, bool exactOutput) public {
        uint256 shares = _join(100 ether, 100 ether) / 2;
        IERC20 output = side ? token1 : token0;
        _fund(output, address(vault), 7 ether);
        if (exactOutput) {
            assertEq(vault.previewExchangeOut(IERC20(address(vault)), output, 1 ether), 0);
            bytes32 beforeState = _state(address(this));
            vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
            vault.exchangeOut(IERC20(address(vault)), shares, output, 1 ether, alice, false, block.timestamp);
            assertEq(_state(address(this)), beforeState);
        } else {
            (uint256 quote,) = vault.previewExchangeIn(IERC20(address(vault)), shares, output);
            (uint256 paid,) = vault.exchangeIn(IERC20(address(vault)), shares, output, quote, alice, false, block.timestamp);
            assertEq(paid, quote);
            assertEq(output.balanceOf(address(vault)), 7 ether, "stray custody is not redeemed");
        }
    }
    function test_accruedFees_lockedDepositReverts_previewAvailable() public {
        _join(1000 ether, 1000 ether);
        _externalSwapExactIn(pool, true, 1000 ether);
        LockedCaller locked = _locked();
        bytes memory preview = locked.run(address(vault), abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
            (token0, uint256(1 ether), IERC20(address(vault)))));
        (uint256 quote,) = abi.decode(preview, (uint256, uint256));
        assertGt(quote, 0);
        bytes32 beforeState = _state(address(locked));
        vm.expectRevert(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
        locked.run(address(vault), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token0, uint256(1 ether), IERC20(address(vault)), uint256(0), alice, false, block.timestamp)));
        assertEq(_state(address(locked)), beforeState);
    }
    function testFuzz_zapOut_accruedFees_matchQuote(bool side) public {
        uint256 shares = _join(1000 ether, 1000 ether) / 100;
        _externalSwapExactIn(pool, true, 1000 ether);
        IERC20 output = side ? token1 : token0;
        (uint256 quote,) = vault.previewExchangeIn(IERC20(address(vault)), shares, output);
        (uint256 paid,) = vault.exchangeIn(IERC20(address(vault)), shares, output, quote, alice, false, block.timestamp);
        assertGt(quote, 0);
        assertEq(paid, quote);
        assertEq(output.balanceOf(alice), paid);
    }
    function testFuzz_singleDeposit_usesPreAddLiquidity(bool side, uint32 amountSeed, uint32 skewSeed) public {
        _join(1 ether, bound(uint256(skewSeed) * 1e9, 1e15, 1 ether));
        uint256 supply = vault.totalSupply();
        uint128 liquidity = _liquidity();
        uint256 amount = bound(uint256(amountSeed) * 1e9, 1e15, 1 ether);
        (uint256 issued,) = _mintOne(side ? token1 : token0, amount, alice);
        assertGt(issued, 0);
        assertEq(issued, uint256(_liquidity() - liquidity) * supply / liquidity);
    }
    function testFuzz_firstDeposit_preservesEveryUnbookedAsset(bool side, uint32 donatedSeed) public {
        IERC20 donatedToken = side ? token1 : token0;
        uint256 donated = bound(uint256(donatedSeed) * 1e9, 1e15, 1 ether);
        _fund(donatedToken, address(vault), donated);
        uint256 shares = _join(1 ether, 1 ether);
        assertEq(shares + 1000, uint256(_liquidity()));
        assertEq(donatedToken.balanceOf(address(vault)), donated);
        _bundleExit(shares);
        assertEq(donatedToken.balanceOf(address(vault)), donated);
    }
    function testFuzz_singleDeposit_roundTripPreservesIncumbentValue(bool side) public {
        uint256 incumbent = _join(1000 ether, 1000 ether);
        IERC20 input = side ? token1 : token0;
        uint256 beforeInput = input.balanceOf(address(this));
        (uint256 shares, uint256 refund) = _mintOne(input, 1 ether, address(this));
        (uint256 paid,) = vault.exchangeIn(IERC20(address(vault)), shares, input, 1, address(this), false, block.timestamp);
        assertLe(paid + refund, 1 ether);
        assertEq(vault.balanceOf(address(this)), incumbent);
        assertEq(input.balanceOf(address(this)) - beforeInput, paid + refund);
    }
    function testFuzz_zapOut_previewIncludesRemovedLiquidity(bool side, uint16 fraction) public {
        uint256 shares = _join(1000 ether, 1000 ether) * bound(fraction, 1, 9000) / 10_000;
        IERC20 output = side ? token1 : token0;
        (uint256 quote,) = vault.previewExchangeIn(IERC20(address(vault)), shares, output);
        uint256 supply = vault.totalSupply();
        uint128 liquidity = _liquidity();
        (uint256 paid,) = vault.exchangeIn(IERC20(address(vault)), shares, output, quote, alice, false, block.timestamp);
        assertGt(quote, 0);
        assertEq(paid, quote);
        assertEq(_liquidity(), liquidity - uint128(uint256(liquidity) * shares / supply));
    }
    function testFuzz_zapOut_exactOutputUnavailableWithoutBurn(bool side) public {
        _join(1000 ether, 1000 ether);
        IERC20 output = side ? token1 : token0;
        bytes32 beforeState = _state(address(this));
        assertEq(vault.previewExchangeOut(IERC20(address(vault)), output, 1 ether), 0);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        vault.exchangeOut(IERC20(address(vault)), 100 ether, output, 1 ether, alice, false, block.timestamp);
        assertEq(_state(address(this)), beforeState);
    }
    function test_FR1_centerTicksFullRange_noWings() public {
        _join(10 ether, 10 ether);
        assertGt(_liquidity(), 0);
        int24 spacing = pool.tickSpacing();
        (uint128 tight,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), -spacing * 10, spacing * 10)));
        (uint128 lower,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), -spacing * 100, -spacing * 10)));
        (uint128 upper,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), spacing * 10, spacing * 100)));
        assertEq(tight, 0); assertEq(lower, 0); assertEq(upper, 0);
    }
    function test_FR2_spotWalk_centerStaysInRange_feesGrow() public {
        _join(50 ether, 50 ether);
        uint128 liquidity = _liquidity();
        _externalSwapExactIn(pool, true, 20_000 ether);
        (, int24 tick,,,,,) = pool.slot0();
        (int24 lower, int24 upper) = _ticks();
        assertLt(lower, tick); assertLt(tick, upper);
        assertEq(_liquidity(), liquidity);
        (uint256 fees0, uint256 fees1) = _fees();
        assertGt(fees0 + fees1, 0);
        _assertReserves();
    }
    function test_FR3_compoundAfterWalk_keepsFullRangeTicksAndSupply() public {
        _join(50 ether, 50 ether);
        _externalSwapExactIn(pool, true, 20_000 ether);
        _externalSwapExactIn(pool, false, 20_000 ether);
        uint128 liquidity = _liquidity();
        uint256 supply = vault.totalSupply();
        _compound();
        assertGt(_liquidity(), liquidity);
        assertEq(vault.totalSupply(), supply);
        _assertReserves();
    }
    function test_FR4_blockedJoinRollback_thenIdleJoin_sameFullRangeTicks() public {
        _join(10 ether, 10 ether);
        LockedCaller locked = _locked();
        bytes32 beforeState = _state(address(locked));
        vm.expectRevert(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
        locked.run(address(vault), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token0, uint256(5 ether), IERC20(address(vault)), uint256(0), alice, false, block.timestamp)));
        assertEq(_state(address(locked)), beforeState);
        uint128 liquidity = _liquidity();
        _mintOne(token0, 5 ether, alice);
        assertGt(_liquidity(), liquidity);
    }
    function test_FR5_singleAndBothTokenGenesisPathsRemainAvailable() public {
        (uint256 first,) = _mintOne(token0, 10 ether, alice);
        assertGt(first, 0);
        uint256 second = _join(10 ether, 10 ether);
        assertGt(second, 0);
        (uint256 third,) = _mintOne(token0, 10 ether, alice);
        assertGt(third, 0);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.totalSupply(), first + second + third + 1000);
    }
    function test_FR6_importedNftConvertedToFullRange() public {
        (uint256 id,) = _mintNft(NftDeposit(address(this), -600, 600, 20 ether, 20 ether, FEE_MEDIUM));
        _approveNft(id);
        uint256 shares = Importer(address(vault)).importPosition(npm, id, 0, address(this), address(this), block.timestamp);
        assertGt(shares, 0);
        (uint128 narrow,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), int24(-600), int24(600))));
        assertEq(narrow, 0);
        assertEq(vault.totalSupply(), uint256(_liquidity()));
        _assertReserves();
    }
    function _locked() private returns (LockedCaller locked) {
        locked = new LockedCaller(pool);
        _fund(token0, address(locked), 100 ether);
        _fund(token1, address(locked), 100 ether);
    }
}
