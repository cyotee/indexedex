// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage as IPkg} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {IUniswapV4StandardExchangeBalancerQuadStableBufferHook as IHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IUniswapV4HookStagedPairInit as IInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {IUniswapV4BalancerStableLiquidityUnits as IUnits} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4BalancerStableLiquidityUnits.sol";
import {FeeOnTransferERC20} from "contracts/test/stubs/FeeOnTransferERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";

abstract contract BalancerStableTokenCountBase is TestBase {
    IPkg.PkgArgs internal activeArgs;
    SimpleYieldERC4626 internal lastVault;

    function activeCount() internal pure virtual returns (uint256);

    function setUp() public override {
        super.setUp();
        uint256 n = activeCount();
        IPkg.PkgArgs memory a;
        a.poolManager = address(pm);
        a.feeOracle = address(indexedexManager);
        a.baseAmp = 100;
        a.tokens = new address[](n);
        a.standardExchanges = new address[](n);
        a.rateProviders = new address[](n);
        a.tokenDecimals = new uint8[](n);
        a.seDecimals = new uint8[](n);
        for (uint256 i; i < n; ++i) a.tokens[i] = address(new SimpleMintableERC20("Active", "ACT"));
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                if (a.tokens[j] < a.tokens[i]) (a.tokens[i], a.tokens[j]) = (a.tokens[j], a.tokens[i]);
            }
            a.tokenDecimals[i] = 18;
        }
        lastVault = new SimpleYieldERC4626(SimpleMintableERC20(a.tokens[n - 1]));
        a.standardExchanges[n - 1] = _deployERC4626SE(address(lastVault));
        a.seDecimals[n - 1] = 18;
        activeArgs = a;
        _deployHookWithArgs(a);
        _approveActive();
    }

    function _approveActive() internal {
        _setDexFee(0);
        _setUsageFee(0);
        address[] memory ts = quad.tokens();
        for (uint256 i; i < ts.length; ++i) _fundAndApprove(SimpleMintableERC20(ts[i]));
    }

    function _amounts(uint256 value) internal view returns (uint256[] memory a) {
        a = new uint256[](activeCount());
        for (uint256 i; i < a.length; ++i) a[i] = value;
    }

    function test_count_discovery_and_every_pair() public view {
        uint256 n = activeCount();
        assertEq(quad.numTokens(), n);
        assertEq(quad.tokens(), activeArgs.tokens);
        assertEq(IBasicVault(hook).vaultTokens(), activeArgs.tokens);
        assertEq(quad.nativeReserves().length, n);
        assertEq(quad.ratedBalances().length, n);
        assertEq(quad.standardExchange(n - 1), activeArgs.standardExchanges[n - 1]);
        _assertAllDoorsLive();
        assertEq(IDiamondLoupe(hook).facetAddress(IInit.deployPair.selector), address(0));
    }

    function test_count_invalid_indices() public {
        vm.expectRevert(); quad.token(activeCount());
        vm.expectRevert(); quad.nativeReserve(activeCount());
        vm.expectRevert(); quad.ratedBalance(activeCount());
        vm.expectRevert(); quad.standardExchange(activeCount());
    }

    function test_count_bootstrap_and_proportional_round_trip() public {
        uint256 minted = _firstMintEqual(1000 ether);
        assertEq(minted, 1000 ether - 1000);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        uint256[] memory amounts = _amounts(20 ether);
        (uint256 expected, uint256[] memory used) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory spent) = quad.joinProportional(amounts, user, expected, block.timestamp);
        assertEq(shares, expected);
        assertEq(spent, used);
        uint256[] memory quote = quad.previewExitProportional(shares);
        uint256[] memory beforeBalances = _userBalances();
        vm.prank(user);
        assertEq(quad.exitProportional(shares, user, quote, block.timestamp), quote);
        uint256[] memory afterBalances = _userBalances();
        for (uint256 i; i < quote.length; ++i) {
            assertEq(afterBalances[i] - beforeBalances[i], quote[i]);
            assertLe(quote[i], spent[i]);
        }
    }

    function test_count_all_directed_swaps_exact_in_and_out() public {
        _firstMintEqual(2000 ether);
        address[] memory ts = quad.tokens();
        for (uint256 i; i < ts.length; ++i) {
            for (uint256 j; j < ts.length; ++j) {
                if (i == j) continue;
                uint256 beforeIn = IERC20(ts[i]).balanceOf(user);
                uint256 beforeOut = IERC20(ts[j]).balanceOf(user);
                uint256 quote = quad.previewSwapExactIn(ts[i], ts[j], 0.5 ether);
                _swapExactIn(ts[i], ts[j], 0.5 ether);
                assertEq(beforeIn - IERC20(ts[i]).balanceOf(user), 0.5 ether);
                assertEq(IERC20(ts[j]).balanceOf(user) - beforeOut, quote);
                beforeIn = IERC20(ts[i]).balanceOf(user);
                beforeOut = IERC20(ts[j]).balanceOf(user);
                quote = quad.previewSwapExactOut(ts[i], ts[j], 0.25 ether);
                _swapExactOut(ts[i], ts[j], 0.25 ether);
                assertEq(beforeIn - IERC20(ts[i]).balanceOf(user), quote);
                assertEq(IERC20(ts[j]).balanceOf(user) - beforeOut, 0.25 ether);
            }
        }
    }

    function testFuzz_count_swap_round_trip_cannot_extract_value(uint96 amount, uint8 first, uint8 second) public {
        _firstMintEqual(1000 ether);
        _setDexFee(3e14);
        uint256 n = activeCount();
        uint256 i = bound(first, 0, n - 1);
        uint256 j = (i + bound(second, 1, n - 1)) % n;
        uint256 input = bound(amount, 1e9, 20 ether);
        address tokenIn = quad.token(i);
        address tokenOut = quad.token(j);
        uint256[] memory beforeBalances = _userBalances();
        _swapExactIn(tokenIn, tokenOut, input);
        uint256 received = IERC20(tokenOut).balanceOf(user) - beforeBalances[j];
        assertGt(received, 0);
        _swapExactIn(tokenOut, tokenIn, received);
        uint256[] memory afterBalances = _userBalances();
        for (uint256 k; k < n; ++k) {
            if (k == i) assertLe(afterBalances[k], beforeBalances[k], "no profitable round trip");
            else assertEq(afterBalances[k], beforeBalances[k], "no unaccounted currency movement");
        }
    }

    function test_count_shared_book_matches_reference_after_cross_pair_swap() public {
        _firstMintEqual(2000 ether);
        address[] memory ts = quad.tokens();
        _swapExactIn(ts[0], ts[ts.length - 1], 50 ether);
        uint256 j = ts.length > 2 ? 1 : ts.length - 1;
        uint256[] memory balances = quad.ratedBalances();
        uint256 d = StableMath.computeInvariant(quad.getCurrentAmp(), balances);
        uint256 expected = StableMath.computeOutGivenExactIn(quad.getCurrentAmp(), balances, 0, j, 1 ether - quad.dexSwapFee(), d);
        assertEq(quad.previewSwapExactIn(ts[0], ts[j], 1 ether), expected);
    }

    function test_count_accrued_yield_lp_swap_round_trip_cannot_extract_value() public {
        _firstMintEqual(1000 ether);
        _setDexFee(3e14);
        assertEq(quad.dexSwapFee(), 3e14, "use the mainnet rehearsal trading fee");
        uint256 initialLp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        IERC20(hook).transfer(address(0xA11CE), initialLp);
        address raw = quad.token(0);
        address buffered = quad.token(activeCount() - 1);
        _accrueYield(address(lastVault), buffered, 100 ether);
        assertGt(quad.seClaim(activeCount() - 1), 1000 ether, "accrued yield reaches the SE-valued book");
        uint256[] memory beforeBalances = _userBalances();
        uint256[] memory amounts = new uint256[](activeCount());
        amounts[0] = 1 ether;
        vm.prank(user);
        uint256 minted = quad.joinUnbalanced(amounts, user, 0, block.timestamp);
        vm.prank(user);
        quad.withdrawSingle(buffered, minted, user, 0, block.timestamp);
        uint256 received = IERC20(buffered).balanceOf(user) - beforeBalances[activeCount() - 1];
        _swapExactIn(buffered, raw, received);
        assertEq(IERC20(hook).balanceOf(user), 0, "round trip leaves no LP position");
        uint256[] memory afterBalances = _userBalances();
        assertLe(afterBalances[0], beforeBalances[0], "LP and swap use consistent SE value");
        for (uint256 i = 1; i < activeCount(); ++i) assertEq(afterBalances[i], beforeBalances[i]);
    }

    function test_count_unbalanced_and_single_exact_output_liquidity() public {
        _firstMintEqual(1000 ether);
        _setDexFee(0.003 ether);
        uint256[] memory amounts = _amounts(1 ether);
        amounts[amounts.length - 1] = 10 ether;
        uint256 quote = quad.previewJoinUnbalanced(amounts);
        vm.prank(user);
        assertEq(quad.joinUnbalanced(amounts, user, quote, block.timestamp), quote);
        for (uint256 i; i < activeCount(); ++i) {
            _singleExactOutputRoundTrip(quad.token(i));
        }
        _singleExactOutputRoundTrip(quad.standardExchange(activeCount() - 1));
    }

    function _singleExactOutputRoundTrip(address token_) internal {
        uint256 shares = 1 ether;
        uint256 required = quad.previewJoinSingleAssetExactOut(token_, shares);
        if (token_ == quad.standardExchange(activeCount() - 1)) {
            _fundShares(token_, required);
            required = quad.previewJoinSingleAssetExactOut(token_, shares);
        }
        uint256 initial = IERC20(token_).balanceOf(user);
        vm.prank(user);
        assertEq(quad.joinSingleAssetExactOut(token_, shares, user, required, block.timestamp), required);
        assertEq(initial - IERC20(token_).balanceOf(user), required);
        uint256 amountOut = required / 2;
        uint256 burned = quad.previewExitSingleAssetExactTokenOut(token_, amountOut);
        initial = IERC20(token_).balanceOf(user);
        vm.prank(user);
        assertEq(quad.exitSingleAssetExactTokenOut(token_, amountOut, user, burned, block.timestamp), burned);
        assertEq(IERC20(token_).balanceOf(user) - initial, amountOut);
        assertLt(burned, shares);
    }

    function _fundShares(address se, uint256 wanted) internal {
        address pair = quad.token(activeCount() - 1);
        vm.startPrank(user);
        IERC20(pair).approve(se, type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(IERC20(pair), wanted * 2 + 1 ether, IERC20(se), wanted, user, false, block.timestamp);
        IERC20(se).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function test_count_yield_does_not_mint_inventory_growth_fees() public {
        _setUsageFee(0.1 ether);
        _firstMintEqual(1000 ether);
        uint256 k = quad.kLast();
        uint256 inventory = quad.nativeReserve(activeCount() - 1);
        address yieldToken = quad.token(activeCount() - 1);
        _accrueYield(address(lastVault), yieldToken, 100 ether);
        assertEq(quad.nativeReserve(activeCount() - 1), inventory);
        assertGt(quad.seClaim(activeCount() - 1), inventory);
        assertEq(quad.kLast(), k);
        uint256 beforeFees = IERC20(hook).balanceOf(feeRecipient);
        address input = quad.token(0);
        uint256 quoted = quad.previewJoinSingleAssetExactIn(input, 1 ether);
        vm.prank(user);
        assertEq(quad.joinSingleAssetExactIn(input, 1 ether, user, quoted, block.timestamp), quoted);
        assertEq(IERC20(hook).balanceOf(feeRecipient), beforeFees);
    }

    function test_count_last_pair_required_and_finalization_gas() public {
        IPkg.PkgArgs memory a = activeArgs;
        a.baseAmp = 101;
        address staged = _deployBootstrapOnly(a);
        IInit init = IInit(staged);
        for (uint256 i; i < a.tokens.length; ++i) {
            for (uint256 j = i + 1; j < a.tokens.length; ++j) {
                if (i == a.tokens.length - 2 && j == a.tokens.length - 1) continue;
                init.deployPair(a.tokens[i], a.tokens[j]);
                init.deployPair(a.tokens[i], a.tokens[j]);
            }
        }
        vm.expectRevert(IInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();
        init.deployPair(a.tokens[a.tokens.length - 2], a.tokens[a.tokens.length - 1]);
        uint256 beforeGas = gasleft();
        assertTrue(init.finalizeInitialization());
        assertLt(beforeGas - gasleft(), 30_000_000);
        assertEq(IHook(staged).numTokens(), activeCount());
        vm.expectRevert(); init.finalizeInitialization();
    }

    function test_count_rejects_each_array_mismatch() public {
        for (uint256 which; which < 4; ++which) {
            IPkg.PkgArgs memory a = activeArgs;
            if (which == 0) a.standardExchanges = new address[](activeCount() - 1);
            if (which == 1) a.rateProviders = new address[](activeCount() + 1);
            if (which == 2) a.tokenDecimals = new uint8[](activeCount() - 1);
            if (which == 3) a.seDecimals = new uint8[](activeCount() + 1);
            vm.expectRevert(IPkg.ArrayLengthMismatch.selector);
            hookPkg.processArgs(abi.encode(a));
        }
    }

    function test_count_invalid_cardinalities() public {
        uint256[4] memory badCounts = [uint256(0), 1, 6, 32];
        for (uint256 i; i < badCounts.length; ++i) {
            IPkg.PkgArgs memory a = activeArgs;
            a.tokens = new address[](badCounts[i]);
            vm.expectRevert(IPkg.InvalidTokenCount.selector);
            hookPkg.processArgs(abi.encode(a));
        }
    }

    function test_count_amplification_endpoints() public {
        IPkg.PkgArgs memory a = activeArgs;
        a.baseAmp = 1;
        assertEq(hookPkg.processArgs(abi.encode(a)), abi.encode(a));
        a.baseAmp = 50_000;
        _deployHookWithArgs(a);
        _approveActive();
        assertEq(quad.getCurrentAmp(), 50_000_000);
        _firstMintEqual(1000 ether);
        _swapExactIn(a.tokens[0], a.tokens[a.tokens.length - 1], 1 ether);
        a.baseAmp = 50_001;
        vm.expectRevert(IPkg.InvalidAmp.selector); hookPkg.processArgs(abi.encode(a));
    }

    function test_count_flexible_share_bootstrap_prop_exit_and_address_join() public {
        IUnits units = IUnits(hook);
        uint256 n = activeCount();
        bool[] memory flags = new bool[](n);
        flags[n - 1] = true;
        address se = quad.standardExchange(n - 1);
        _fundShares(se, 2000 ether);
        uint256[] memory amounts = _amounts(1000 ether);
        (uint256 expected,) = units.previewJoinProportionalFlexible(amounts, flags);
        vm.prank(user);
        (uint256 minted,) = units.joinProportionalFlexible(amounts, flags, user, expected, block.timestamp);
        assertEq(minted, expected);
        assertEq(quad.seBalance(n - 1), amounts[n - 1]);
        uint256[] memory quote = units.previewExitProportionalFlexible(minted / 10, flags);
        uint256 sharesBefore = IERC20(se).balanceOf(user);
        vm.prank(user);
        assertEq(units.exitProportionalFlexible(minted / 10, user, flags, quote, block.timestamp), quote);
        assertEq(IERC20(se).balanceOf(user) - sharesBefore, quote[n - 1]);
        address[] memory ts = quad.tokens();
        ts[n - 1] = se;
        amounts = _amounts(1 ether);
        amounts[n - 1] = 2 ether;
        expected = units.previewJoinUnbalanced(ts, amounts);
        vm.prank(user);
        assertEq(units.joinUnbalanced(ts, amounts, user, expected, block.timestamp), expected);
        flags[0] = true;
        vm.expectRevert(); units.previewJoinProportionalFlexible(amounts, flags);
        ts[0] = ts[n - 1];
        vm.expectRevert(); units.previewJoinUnbalanced(ts, amounts);
    }

    function test_count_failed_last_transfer_is_atomic() public {
        _firstMintEqual(1000 ether);
        uint256[] memory amounts = _amounts(10 ether);
        uint256[] memory beforeBalances = _userBalances();
        uint256[] memory beforeReserves = quad.nativeReserves();
        uint256 beforeSupply = IERC20(hook).totalSupply();
        vm.startPrank(user);
        IERC20(quad.token(activeCount() - 1)).approve(hook, 0);
        vm.expectRevert(); quad.joinUnbalanced(amounts, user, 0, block.timestamp);
        vm.stopPrank();
        assertEq(_userBalances(), beforeBalances);
        assertEq(quad.nativeReserves(), beforeReserves);
        assertEq(IERC20(hook).totalSupply(), beforeSupply);
    }

    function test_count_funded_pretransfer_and_post_operation_book() public {
        _firstMintEqual(1000 ether);
        IERC20 input = IERC20(quad.token(0));
        IERC20 output = IERC20(quad.token(activeCount() - 1));
        uint256 quote = quad.previewSwapExactIn(address(input), address(output), 1 ether);
        uint256 beforeOut = output.balanceOf(user);
        vm.startPrank(user);
        input.transfer(hook, 1 ether);
        assertEq(IStandardExchangeIn(hook).exchangeIn(input, 1 ether, output, quote, user, true, block.timestamp), quote);
        vm.stopPrank();
        assertEq(output.balanceOf(user) - beforeOut, quote);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, uint256(0)));
        IStandardExchangeIn(hook).exchangeIn(input, 1 ether, output, 0, address(this), true, block.timestamp);
    }

    function test_count_retained_buffered_dust_is_not_new_funding() public {
        _firstMintEqual(1000 ether);
        IERC20 input = IERC20(quad.token(activeCount() - 1));
        IERC20 output = IERC20(quad.token(0));
        SimpleMintableERC20(address(input)).mint(hook, 10);
        _swapExactIn(address(output), address(input), 1 ether);
        assertEq(input.balanceOf(hook), 10);
        assertGt(quad.previewSwapExactIn(address(input), address(output), 10), 0);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 10, 0));
        IStandardExchangeIn(hook).exchangeIn(input, 10, output, 0, address(this), true, block.timestamp);
        uint256 required = quad.previewSwapExactOut(address(input), address(output), 1);
        assertLe(required, 10, "retained balance could otherwise cover exact-out input");
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, required, 0));
        IStandardExchangeOut(hook).exchangeOut(input, required, output, 1, address(this), true, block.timestamp);
        uint256 quote = quad.previewSwapExactIn(address(input), address(output), 1 ether);
        vm.startPrank(user);
        input.transfer(hook, 1 ether);
        assertEq(IStandardExchangeIn(hook).exchangeIn(input, 1 ether, output, quote, user, true, block.timestamp), quote);
        vm.stopPrank();
        assertEq(input.balanceOf(hook), 10, "new funding leaves reserve dust owned by the hook");
    }

    function test_count_raw_donation_prices_live_book_and_becomes_booked() public {
        _firstMintEqual(1000 ether);
        address input = quad.token(0);
        address output = quad.token(activeCount() - 1);
        SimpleMintableERC20(input).mint(hook, 100 ether);
        uint256[] memory balances = quad.ratedBalances();
        uint256 d = StableMath.computeInvariant(quad.getCurrentAmp(), balances);
        uint256 expected = StableMath.computeOutGivenExactIn(quad.getCurrentAmp(), balances, 0, activeCount() - 1, 1 ether - quad.dexSwapFee(), d);
        assertEq(quad.previewSwapExactIn(input, output, 1 ether), expected);
        _swapExactIn(input, output, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, uint256(0)));
        IStandardExchangeIn(hook).exchangeIn(IERC20(input), 1 ether, IERC20(output), 0, address(this), true, block.timestamp);
    }

    function test_count_fee_on_transfer_bootstrap_reverts_atomically() public {
        IPkg.PkgArgs memory a = activeArgs;
        a.tokens[0] = address(new FeeOnTransferERC20("Taxed", "TAX", 100));
        for (uint256 i; i < a.tokens.length; ++i) {
            for (uint256 j = i + 1; j < a.tokens.length; ++j) {
                if (a.tokens[j] < a.tokens[i]) {
                    (a.tokens[i], a.tokens[j]) = (a.tokens[j], a.tokens[i]);
                    (a.standardExchanges[i], a.standardExchanges[j]) = (a.standardExchanges[j], a.standardExchanges[i]);
                    (a.seDecimals[i], a.seDecimals[j]) = (a.seDecimals[j], a.seDecimals[i]);
                }
            }
        }
        _deployHookWithArgs(a);
        _approveActive();
        uint256[] memory beforeBalances = _userBalances();
        uint256[] memory amounts = _amounts(1000 ether);
        vm.prank(user);
        vm.expectRevert(); quad.joinProportional(amounts, user, 0, block.timestamp);
        assertEq(_userBalances(), beforeBalances);
        assertEq(IERC20(hook).totalSupply(), 0);
        for (uint256 i; i < a.tokens.length; ++i) assertEq(quad.nativeReserve(i), 0);
    }

    function test_count_mixed_decimals_and_nonunit_se_rate() public {
        IPkg.PkgArgs memory a = activeArgs;
        uint256 n = activeCount();
        a.tokens = new address[](n);
        a.standardExchanges = new address[](n);
        a.tokenDecimals = new uint8[](n);
        a.seDecimals = new uint8[](n);
        for (uint256 i; i < n; ++i) {
            a.tokens[i] = address(new MintableERC20Decimals("Mixed", "MIX", i == 0 ? 18 : (i % 2 == 0 ? 9 : 6)));
        }
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                if (a.tokens[j] < a.tokens[i]) (a.tokens[i], a.tokens[j]) = (a.tokens[j], a.tokens[i]);
            }
            a.tokenDecimals[i] = MintableERC20Decimals(a.tokens[i]).decimals();
        }
        uint256 bufferedIndex;
        address yieldVault;
        for (uint256 i; i < n; ++i) {
            if (a.tokenDecimals[i] == 18) continue;
            yieldVault = address(new SimpleYieldERC4626(MintableERC20Decimals(a.tokens[i])));
            a.standardExchanges[i] = _deployERC4626SE(yieldVault);
            a.seDecimals[i] = 18;
            bufferedIndex = i;
        }
        RateProviderMock provider = new RateProviderMock();
        provider.mockRate(1 ether);
        a.rateProviders[bufferedIndex] = address(provider);
        _deployHookWithArgs(a);
        _approveActive();
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) amounts[i] = 1000 * 10 ** uint256(a.tokenDecimals[i]);
        vm.prank(user);
        (uint256 minted,) = quad.joinProportional(amounts, user, 0, block.timestamp);
        assertEq(minted, 1000 ether - 1000, "native inventory normalized per active leg");
        _setAccruedNetRate(a, bufferedIndex, yieldVault, provider);
        _assertMixedSwap(a, bufferedIndex);
        uint256 amountOut = 10 ** uint256(a.tokenDecimals[bufferedIndex]);
        uint256 shares = quad.previewExitSingleAssetExactTokenOut(a.tokens[bufferedIndex], amountOut);
        uint256 beforeBalance = IERC20(a.tokens[bufferedIndex]).balanceOf(user);
        vm.prank(user);
        assertEq(quad.exitSingleAssetExactTokenOut(a.tokens[bufferedIndex], amountOut, user, shares, block.timestamp), shares);
        assertEq(IERC20(a.tokens[bufferedIndex]).balanceOf(user) - beforeBalance, amountOut);
    }

    function _setAccruedNetRate(IPkg.PkgArgs memory a, uint256 index, address vault, RateProviderMock provider) private {
        _accrueYield(vault, a.tokens[index], SimpleYieldERC4626(vault).totalAssets() / 10);
        uint256 inventory = quad.nativeReserve(index);
        address se = a.standardExchanges[index];
        // Compose SE -> vault shares -> assets, including the SE's pending yield-fee dilution.
        uint256 vaultShares = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), inventory, IERC20(vault));
        uint256 expectedClaim = SimpleYieldERC4626(vault).previewRedeem(vaultShares);
        uint256 netRate = expectedClaim * 1 ether / inventory;
        assertGt(netRate, 1 ether, "net accrued rate");
        provider.mockRate(netRate);
        assertEq(quad.seClaim(index), expectedClaim, "net vault redemption claim");
        assertEq(quad.ratedBalance(index), inventory * netRate / 1 ether, "rate applied once");
    }

    function _assertMixedSwap(IPkg.PkgArgs memory a, uint256 buffered) internal {
        uint256 other = buffered == 0 ? 1 : 0;
        uint256 output = 10 ** uint256(a.tokenDecimals[other]);
        uint256 required = quad.previewSwapExactOut(a.tokens[buffered], a.tokens[other], output);
        uint256 beforeInput = IERC20(a.tokens[buffered]).balanceOf(user);
        uint256 beforeOutput = IERC20(a.tokens[other]).balanceOf(user);
        _swapExactOut(a.tokens[buffered], a.tokens[other], output);
        assertEq(beforeInput - IERC20(a.tokens[buffered]).balanceOf(user), required);
        assertEq(IERC20(a.tokens[other]).balanceOf(user) - beforeOutput, output);
    }

    function test_count_last_binding_validation_and_salt() public {
        IPkg.PkgArgs memory a = activeArgs;
        bytes32 original = hookPkg.calcSalt(abi.encode(a));
        a.seDecimals[a.tokens.length - 1] = 5;
        vm.expectRevert(IPkg.InvalidDecimals.selector); hookPkg.processArgs(abi.encode(a));
        a = activeArgs;
        a.standardExchanges[a.tokens.length - 1] = address(0xdead);
        vm.expectRevert(IPkg.InvalidSE.selector); hookPkg.processArgs(abi.encode(a));
        a = activeArgs;
        a.tokens[a.tokens.length - 1] = address(type(uint160).max);
        assertTrue(hookPkg.calcSalt(abi.encode(a)) != original);
        vm.expectRevert(IPkg.InvalidSE.selector); hookPkg.processArgs(abi.encode(a));
    }

    function test_count_all_buffered_bootstrap_and_exit() public {
        IPkg.PkgArgs memory a = activeArgs;
        for (uint256 i; i + 1 < a.tokens.length; ++i) {
            a.standardExchanges[i] = _deployERC4626SE(address(new SimpleYieldERC4626(SimpleMintableERC20(a.tokens[i]))));
            a.seDecimals[i] = 18;
        }
        _deployHookWithArgs(a);
        _approveActive();
        uint256 minted = _firstMintEqual(1000 ether);
        uint256[] memory expected = quad.previewExitProportional(minted / 10);
        vm.prank(user);
        assertEq(quad.exitProportional(minted / 10, user, expected, block.timestamp), expected);
        for (uint256 i; i < a.tokens.length; ++i) {
            assertEq(IERC20(a.tokens[i]).allowance(hook, a.standardExchanges[i]), 0);
            assertEq(IERC20(a.standardExchanges[i]).allowance(hook, a.standardExchanges[i]), 0);
        }
    }

    function _accrueYield(address vault, address token, uint256 amount) private {
        SimpleMintableERC20(token).mint(address(this), amount);
        IERC20(token).approve(vault, amount);
        SimpleYieldERC4626(vault).simulateYield(amount);
    }

    function _userBalances() internal view returns (uint256[] memory balances) {
        balances = new uint256[](activeCount());
        for (uint256 i; i < balances.length; ++i) balances[i] = IERC20(quad.token(i)).balanceOf(user);
    }
}

contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_N2 is BalancerStableTokenCountBase {
    function activeCount() internal pure override returns (uint256) { return 2; }
}
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_N3 is BalancerStableTokenCountBase {
    function activeCount() internal pure override returns (uint256) { return 3; }
}
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_N4 is BalancerStableTokenCountBase {
    function activeCount() internal pure override returns (uint256) { return 4; }
}
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_N5 is BalancerStableTokenCountBase {
    function activeCount() internal pure override returns (uint256) { return 5; }
}
