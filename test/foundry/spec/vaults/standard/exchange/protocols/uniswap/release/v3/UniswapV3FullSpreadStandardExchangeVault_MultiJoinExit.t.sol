// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseFixture} from "./harness/FullSpreadReleaseFixture.sol";
import {UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller as LockedCaller} from "./harness/UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeBundleIn as BundleIn, IStandardExchangeBundleOut as BundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";

/// @notice MJ/ME regressions now exercise V3-ACC-07/13 bundle exact-input semantics.
contract UniswapV3FullSpreadStandardExchangeVault_MultiJoinExit_Test is FullSpreadReleaseFixture {
    LockedCaller internal lockCaller;
    function setUp() public override {
        super.setUp();
        lockCaller = new LockedCaller(pool);
        _fund(token0, address(lockCaller), 100 ether);
        _fund(token1, address(lockCaller), 100 ether);
    }
    function test_MJ1_lengthNotTwo_reverts() public {
        uint256[] memory one = new uint256[](1);
        vm.expectRevert(BundleIn.AmountsLengthMismatch.selector);
        BundleIn(address(vault)).exchangeBundleInForSingleOut(one, address(vault), 0, alice, false, block.timestamp);
    }
    function test_MJ2_idleProportionalJoin_fullRangeLiquidity_noSleeve() public {
        uint256 shares = _join(10 ether, 10 ether);
        assertEq(vault.totalSupply(), shares + 1000);
        assertEq(vault.totalSupply(), uint256(_liquidity()));
        assertEq(token0.balanceOf(address(vault)), 0);
        assertEq(token1.balanceOf(address(vault)), 0);
    }
    function test_MJ3_unbalancedJoin_refundsSurplus_noSwap() public {
        (uint160 price,,,,,,) = pool.slot0();
        (uint256 quote, uint256[] memory refunds) = BundleIn(address(vault)).previewExchangeBundleInForSingleOut(_amounts(10 ether, 1 ether), address(vault));
        uint256 before0 = token0.balanceOf(address(this));
        uint256 before1 = token1.balanceOf(address(this));
        uint256 issued = _join(10 ether, 1 ether);
        (uint160 afterPrice,,,,,,) = pool.slot0();
        assertEq(afterPrice, price);
        assertEq(issued, quote);
        assertEq(token0.balanceOf(address(this)) - before0, refunds[0]);
        assertEq(token1.balanceOf(address(this)) - before1, refunds[1]);
        assertGt(refunds[0], 0);
        assertEq(token0.balanceOf(address(vault)), 0);
    }
    function test_MJ4_blockedJoin_reverts_withoutLocalMint() public {
        bytes32 beforeState = _state(address(lockCaller));
        vm.expectRevert(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
        lockCaller.run(address(vault), abi.encodeCall(BundleIn.exchangeBundleInForSingleOut,
            (_amounts(5 ether, 5 ether), address(vault), uint256(0), alice, false, block.timestamp)));
        assertEq(_state(address(lockCaller)), beforeState);
    }
    function test_MJ5_pretransferredTrue_noDelivery_noFreeMint() public {
        _join(4 ether, 4 ether);
        bytes32 beforeState = _state(alice);
        vm.prank(alice);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        BundleIn(address(vault)).exchangeBundleInForSingleOut(_amounts(2 ether, 2 ether), address(vault), 0, alice, true, block.timestamp);
        assertEq(_state(alice), beforeState);
    }
    function test_MJ7_previewJoin_matchesIdle_andRemainsAvailableWhileLocked() public {
        (uint256 quote,) = BundleIn(address(vault)).previewExchangeBundleInForSingleOut(_amounts(3 ether, 3 ether), address(vault));
        assertEq(_join(3 ether, 3 ether), quote);
        bytes memory result = lockCaller.run(address(vault), abi.encodeCall(BundleIn.previewExchangeBundleInForSingleOut,
            (_amounts(2 ether, 2 ether), address(vault))));
        (uint256 lockedQuote, uint256[] memory refunds) = abi.decode(result, (uint256, uint256[]));
        assertGt(lockedQuote, 0);
        assertEq(refunds.length, 2);
    }
    // The new input has no token-order argument; retain MJ8's route-validation intent.
    function test_MJ8_nonShareOutput_reverts() public {
        vm.expectRevert(BundleIn.ExchangeBundleInForSingleOutNotAvailable.selector);
        BundleIn(address(vault)).exchangeBundleInForSingleOut(_amounts(1 ether, 1 ether), address(token0), 0, alice, false, block.timestamp);
    }
    function test_ME1_lengthNotTwo_reverts() public {
        _join(10 ether, 10 ether);
        address[] memory one = new address[](1);
        one[0] = address(token0);
        vm.expectRevert(BundleOut.TokenAmountsLengthMismatch.selector);
        BundleOut(address(vault)).exchangeBundleOut(address(vault), 1, one, _amounts(0, 0), alice, false, block.timestamp);
    }
    function test_ME2_idleProportionalExit_paysBoth() public {
        uint256 shares = _join(10 ether, 10 ether) / 5;
        (uint256 expected0, uint256 expected1) = _claim(shares);
        uint256 supply = vault.totalSupply();
        uint256[] memory paid = _bundleExit(shares);
        assertEq(paid[0], expected0);
        assertEq(paid[1], expected1);
        assertEq(vault.totalSupply(), supply - shares);
    }
    // Requested outputs became independent minima, not an equal-share-burn constraint.
    function test_ME3_unmetMinimum_reverts_noSend() public {
        uint256 shares = _join(10 ether, 10 ether) / 5;
        (uint256[] memory quote,) = BundleOut(address(vault)).previewExchangeBundleOut(address(vault), shares, _tokens());
        bytes32 beforeState = _state(address(this));
        vm.expectRevert(abi.encodeWithSelector(BundleIn.MinAmountNotMetAt.selector, 1, quote[1] + 1, quote[1]));
        BundleOut(address(vault)).exchangeBundleOut(address(vault), shares, _tokens(), _amounts(0, quote[1] + 1), address(this), false, block.timestamp);
        assertEq(_state(address(this)), beforeState);
    }
    function test_ME4_blockedExit_revertsForSmallAndLargeClaims() public {
        uint256 shares = _join(20 ether, 20 ether);
        vault.transfer(address(lockCaller), shares);
        for (uint256 i; i < 2; ++i) {
            uint256 amount = i == 0 ? shares / 100 : shares / 2;
            bytes32 beforeState = _state(address(lockCaller));
            vm.expectRevert(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
            lockCaller.run(address(vault), abi.encodeCall(BundleOut.exchangeBundleOut,
                (address(vault), amount, _tokens(), _amounts(0, 0), alice, true, block.timestamp)));
            assertEq(_state(address(lockCaller)), beforeState);
        }
    }
    function test_ME5_exactSharesAboveCallerBalance_reverts() public {
        uint256 shares = _join(10 ether, 10 ether);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), shares, shares + 1));
        BundleOut(address(vault)).exchangeBundleOut(address(vault), shares + 1, _tokens(), _amounts(0, 0), alice, false, block.timestamp);
    }
    function test_ME6_previewExitAmountsMatchExec() public {
        uint256 shares = _join(10 ether, 10 ether) / 20;
        (uint256[] memory quote, uint256 refundQuote) = BundleOut(address(vault)).previewExchangeBundleOut(address(vault), shares, _tokens());
        uint256[] memory paid = _bundleExit(shares);
        assertEq(paid, quote);
        assertEq(refundQuote, 0);
    }
    // ME7 now proves an exact burn, with no reinterpretation as a maximum.
    function test_ME7_declaredSharesBurnExactly_andParkedSharesRemain() public {
        uint256 shares = _join(10 ether, 10 ether);
        uint256 parked = shares / 10;
        vault.transfer(address(vault), parked);
        uint256 beforeShares = vault.balanceOf(address(this));
        uint256 burn = shares / 5;
        (uint256[] memory paid, uint256 refund) = BundleOut(address(vault)).exchangeBundleOut(
            address(vault), burn, _tokens(), _amounts(0, 0), address(this), true, block.timestamp);
        assertEq(paid.length, 2);
        assertEq(refund, 0);
        assertEq(vault.balanceOf(address(this)), beforeShares - burn);
        assertEq(vault.balanceOf(address(vault)), parked);
    }
    function test_ME8_D24_fees_bookBeforeJoin_andPayOnceOnExit() public {
        _join(50 ether, 50 ether);
        _externalSwapExactIn(pool, true, 50_000 ether);
        _externalSwapExactIn(pool, false, 50_000 ether);
        (uint256 fees0, uint256 fees1) = _fees();
        assertGt(fees0 + fees1, 0);
        uint128 liquidity = _liquidity();
        uint256 supply = vault.totalSupply();
        (uint256 quote,) = BundleIn(address(vault)).previewExchangeBundleInForSingleOut(_amounts(2 ether, 2 ether), address(vault));
        assertEq(_join(2 ether, 2 ether), quote);
        assertEq(quote, uint256(_liquidity() - liquidity) * supply / liquidity);
        assertEq(token0.balanceOf(address(vault)), fees0);
        assertEq(token1.balanceOf(address(vault)), fees1);
        _externalSwapExactIn(pool, true, 50_000 ether);
        _externalSwapExactIn(pool, false, 50_000 ether);
        uint256 burn = vault.balanceOf(address(this)) / 20;
        (uint256 expected0, uint256 expected1) = _claim(burn);
        uint256[] memory paid = _bundleExit(burn);
        assertEq(paid[0], expected0);
        assertEq(paid[1], expected1);
        _assertReserves();
    }
    function test_A0_fixedFloor_firstMinterCannotRedeemStrayCustody() public {
        _fund(token0, address(vault), 5 ether);
        _fund(token1, address(vault), 5 ether);
        uint256 shares = _join(10 ether, 10 ether);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.balanceOf(address(0xdead)), 0);
        assertEq(vault.totalSupply(), shares + 1000);
        _bundleExit(shares);
        assertEq(token0.balanceOf(address(vault)), 5 ether);
        assertEq(token1.balanceOf(address(vault)), 5 ether);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.totalSupply(), 1000);
    }
    function _claim(uint256 shares) private view returns (uint256 a0, uint256 a1) {
        uint256 supply = vault.totalSupply();
        (a0, a1) = _principal(uint128(uint256(_liquidity()) * shares / supply));
        (uint256 fees0, uint256 fees1) = _fees();
        a0 += fees0 * shares / supply + token0.balanceOf(address(vault)) * shares / supply;
        a1 += fees1 * shares / supply + token1.balanceOf(address(vault)) * shares / supply;
    }
}
