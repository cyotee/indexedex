// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {TestBase_UniswapV4DualSEBCPHook} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

/**
 * @title UniswapV4DualSEBCPHook_Core_Test
 * @notice Hermetic DoD: package deploy, registry, salt/flags, deposit, withdraw, zap, fees.
 */
contract UniswapV4DualSEBCPHook_Core_Test is TestBase_UniswapV4DualSEBCPHook {
    function test_interfaceMetadataDoesNotAdvertiseMissingReserveProjections() public view {
        assertFalse(IERC165(hook).supportsInterface(type(IDetfReserveQuote).interfaceId),
            "partial legacy views do not implement the complete reserve interface");
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertEq(loupe.facetAddress(IDetfReserveQuote.previewSwapAfterExchange.selector), address(0));
        assertEq(loupe.facetAddress(IDetfReserveQuote.previewJoinAfterDeposit.selector), address(0));
        assertEq(loupe.facetAddress(IDetfReserveQuote.previewBondAfterDeposit.selector), address(0));
        assertNotEq(loupe.facetAddress(IDetfReserveQuote.previewSynthetic.selector), address(0));
        assertNotEq(loupe.facetAddress(IDetfReserveQuote.previewBurnToToken.selector), address(0));
    }

    function test_binding_memberPairAndImplicitOwnShareRoundTrip() public {
        address se_ = seA;
        address pair_ = address(tokenA);
        address[] memory members_ = IBasicVault(se_).vaultTokens();
        bool found_;
        for (uint256 i_; i_ < members_.length; ++i_) {
            assertTrue(members_[i_] != se_, "own share omitted from members");
            if (members_[i_] == pair_) found_ = true;
        }
        assertTrue(found_, "configured pair is a member");
        uint256 input_ = IERC20(pair_).balanceOf(user) / 100;
        assertGt(input_, 0);
        uint256 sharesBefore_ = IERC20(se_).balanceOf(user);
        vm.startPrank(user);
        IERC20(pair_).approve(se_, input_);
        (uint256 minted_, uint256 refund_) = IStandardExchangeIn(se_).exchangeIn(
            IERC20(pair_), input_, IERC20(se_), 1, user, false, block.timestamp
        );
        assertGt(minted_, 0);
        assertLe(refund_, input_);
        assertEq(IERC20(se_).balanceOf(user), sharesBefore_ + minted_);
        IERC20(se_).approve(se_, minted_);
        uint256 pairBefore_ = IERC20(pair_).balanceOf(user);
        (uint256 paid_, uint256 sharesRefunded_) = IStandardExchangeIn(se_).exchangeIn(
            IERC20(se_), minted_, IERC20(pair_), 1, user, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(paid_, 0);
        assertEq(sharesRefunded_, 0);
        assertEq(IERC20(se_).balanceOf(user), sharesBefore_);
        assertEq(IERC20(pair_).balanceOf(user), pairBefore_ + paid_);
    }

    function test_D1_deployFlagsAndViews() public view {
        uint160 flags = DualFactory.requiredFlags();
        assertEq(uint160(hook) & Create2Lib.FLAG_MASK, flags & Create2Lib.FLAG_MASK);
        assertEq(hookPkg.requiredHookFlags(), flags);
        assertEq(dual.poolManager(), address(pm));
        assertEq(dual.feeOracle(), address(indexedexManager));
        assertEq(dual.permit2(), 0x000000000022D473030F116dDEE9F6B43aC78BA3);
        assertEq(dual.tradingFeePercent(), 300);
        assertEq(dual.tradingFeeDenominator(), 100_000);
        IERC20Metadata meta = IERC20Metadata(hook);
        assertEq(meta.decimals(), 18);
        assertTrue(bytes(meta.symbol()).length > 0);
        // LP prefix DSEBCP-
        assertEq(bytes(meta.symbol())[0], bytes1("D"));
        assertEq(dual.standardExchange0(), seA);
        assertEq(dual.token0(), address(tokenA));
        assertTrue(hookPkg.isExpectedInstance(hook, ""));
    }

    function test_D2_idempotentRedeploySameAddress() public {
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, hookPkg, args);
        address again = DualFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(again, hook);
    }

    function test_D2b_swappedLegOrder_sameAddress() public {
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory swapped = IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
            .PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            standardExchange0: seB,
            token0: address(tokenB),
            standardExchange1: seA,
            token1: address(tokenA),
            rateProvider0: RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, seB, address(tokenB)), // D60
            rateProvider1: RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, seA, address(tokenA)) // D60
        });
        // Same economic binding → same package salt
        assertEq(hookPkg.calcSalt(abi.encode(swapped)), hookPkg.calcSalt(abi.encode(_defaultPkgArgs())));
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, hookPkg, swapped);
        address again = DualFactory.deployHook(hookPkg, swapped, mineNonce);
        assertEq(again, hook);
    }

    function test_D3_vaultRegistered() public view {
        _assertVaultRegistered();
        // Registry discovery: deployHookVault must register the diamond as a vault.
        assertTrue(
            IVaultRegistryVaultQuery(address(indexedexManager)).isVault(hook), "registry isVault"
        );
        address[] memory tokens = IBasicVault(hook).vaultTokens();
        assertEq(tokens.length, 2);
        // pool-order pair tokens
        assertTrue(
            (tokens[0] == address(tokenA) && tokens[1] == address(tokenB))
                || (tokens[0] == address(tokenB) && tokens[1] == address(tokenA))
        );
        IStandardVault(hook).vaultConfig();
    }

    function test_D4_secondPoolInit_reverts() public {
        _initPool();
        vm.expectRevert(abi.encodeWithSignature("WrappedError(address,bytes4,bytes,bytes)", hook, bytes4(keccak256("beforeInitialize(address,(address,address,uint24,int24,address),uint160)")), abi.encodeWithSignature("AlreadyInitialized()"), abi.encodeWithSignature("HookCallFailed()")));
        pm.initialize(poolKey, SQRT_PRICE_1_1);
    }

    function test_P1_firstDeposit_mintsLpAndMinLiquidity() public {
        uint256 lp = _depositBoth(100 ether, 100 ether);
        assertGt(lp, 0);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000); // MINIMUM_LIQUIDITY
        assertGt(dual.claimSupplyCurrency0(), 0);
        assertGt(dual.claimSupplyCurrency1(), 0);
    }

    function test_D36_restingFace_notPaidToJoiner() public {
        _depositBoth(100 ether, 100 ether);
        address donor = address(0xD0D0);
        tokenA.mint(donor, 500 ether);
        vm.prank(donor);
        tokenA.transfer(hook, 500 ether);
        uint256 userA = tokenA.balanceOf(user);
        _depositBoth(1 ether, 1 ether);
        assertLt(tokenA.balanceOf(user), userA, "D36: joiner does not collect resting face");
    }

    function test_P3_subsequentDeposit_previewEqualsExecution() public {
        _depositBoth(100 ether, 100 ether);
        uint256 a0 = _amountForCurrency(dual.currency0(), 50 ether, 50 ether);
        uint256 a1 = _amountForCurrency(dual.currency1(), 50 ether, 50 ether);
        (uint256 predLp, uint256 predU0, uint256 predU1) = dual.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) = dual.deposit(a0, a1, user, 0, block.timestamp + 1);
        assertApproxEqAbs(lp, predLp, DUST);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
    }

    function test_P5_deadline_reverts() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        dual.deposit(1 ether, 1 ether, user, 0, block.timestamp - 1);
    }

    function test_W1_withdraw_unwrapBoth() public {
        uint256 lp = _depositBoth(100 ether, 100 ether);
        uint256 bal0Before = IERC20(dual.currency0()).balanceOf(user);
        uint256 bal1Before = IERC20(dual.currency1()).balanceOf(user);
        (uint256 pred0, uint256 pred1) = dual.previewWithdraw(lp / 2);
        vm.prank(user);
        (uint256 a0, uint256 a1) = dual.withdraw(lp / 2, user, 0, 0, block.timestamp + 1);
        assertApproxEqAbs(a0, pred0, DUST);
        assertApproxEqAbs(a1, pred1, DUST);
        assertEq(IERC20(dual.currency0()).balanceOf(user) - bal0Before, a0);
        assertEq(IERC20(dual.currency1()).balanceOf(user) - bal1Before, a1);
    }

    function test_Z3_depositSingle_emptyBook_reverts() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("NotZapEligible()"));
        dual.depositSingle(address(tokenA), 10 ether, user, 0, block.timestamp + 1);
    }

    function test_Z1_depositSingle_paidSwap_previewEqualsExecution() public {
        _depositBoth(200 ether, 200 ether);
        uint256 pred = dual.previewDepositSingle(address(tokenA), 20 ether);
        (uint256 swapAmt, uint256 otherOut, uint256 kept) =
            dual.previewZapSplit(address(tokenA), 20 ether);
        assertGt(pred, 0);
        assertGt(swapAmt, 0, "caller pays the cross-leg swap");
        assertGt(otherOut, 0);
        assertEq(kept + swapAmt, 20 ether);

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 lp = dual.depositSingle(address(tokenA), 20 ether, user, pred, block.timestamp + 1);
        assertEq(lp, pred);
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, lp);
    }

    function test_Z4_depositSingle_afterFullExit_reverts() public {
        uint256 lp = _depositBoth(100 ether, 100 ether);
        vm.prank(user);
        dual.withdraw(lp, user, 0, 0, block.timestamp + 1);
        address treasury = dual.feeTo();
        uint256 protocolLp = IERC20(hook).balanceOf(treasury);
        if (treasury != address(0) && protocolLp != 0) {
            vm.prank(treasury);
            dual.withdraw(protocolLp, user, 0, 0, block.timestamp + 1);
        }
        assertEq(IERC20(hook).totalSupply(), 1000);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("NotZapEligible()"));
        dual.depositSingle(address(tokenA), 10 ether, user, 0, block.timestamp + 1);
        _depositBoth(50 ether, 50 ether);
        assertGt(IERC20(hook).totalSupply(), 1000);
    }

    function test_F2_protocolFee_mintsToFeeTo() public {
        _enableProtocolFee(0.05e18);
        _depositBoth(100 ether, 100 ether);
        address feeTo_ = dual.feeTo();
        uint256 feeBefore = IERC20(hook).balanceOf(feeTo_);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);
        tokenA.approve(address(vaultA), 10 ether);
        tokenB.approve(address(vaultB), 10 ether);
        vaultA.simulateYield(10 ether);
        vaultB.simulateYield(10 ether);
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "yield does not mint LP");
        assertEq(IERC20(hook).balanceOf(feeTo_), feeBefore, "yield is not the fee basis");
        uint256 net = _depositBoth(10 ether, 10 ether);
        uint256 gross = IERC20(hook).totalSupply() - supplyBefore;
        uint256 fee = IERC20(hook).balanceOf(feeTo_) - feeBefore;
        assertEq(fee, gross * 0.05e18 / 1e18);
        assertEq(net + fee, gross, "fee split, not an extra mint");
        assertEq(dual.kLast(), 0, "retired growth checkpoint remains reserved");
    }

    function test_E1_requiredSurface() public view {
        dual.feeOracle();
        dual.dexSwapFee();
        dual.feeTo();
        dual.kLast();
        dual.tradingFeePercent();
        dual.tradingFeeDenominator();
        dual.claimSupply0();
        dual.claimSupply1();
        dual.claimSupplyCurrency0();
        dual.claimSupplyCurrency1();
        dual.currency0();
        dual.currency1();
        IERC20Metadata(hook).name();
        IERC20Metadata(hook).symbol();
        IERC20(hook).totalSupply();
    }

    function test_A1_amountOrder_poolCurrencies() public {
        address c0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        assertEq(dual.currency0(), c0);
        uint256 sharesA = _userAcquireSeShares(seA, tokenA, 40 ether);
        uint256 sharesB = _userAcquireSeShares(seB, tokenB, 60 ether);
        uint256 a0 = dual.currency0() == address(tokenA) ? sharesA : sharesB;
        uint256 a1 = dual.currency1() == address(tokenA) ? sharesA : sharesB;
        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) = dual.depositFlexible(a0, true, a1, true, user, 1, block.timestamp + 1);
        assertGt(lp, 0);
        assertEq(u0, a0);
        assertEq(u1, a1);
        assertEq(IERC20(seA).balanceOf(hook), sharesA - sharesA / 20);
        assertEq(IERC20(seB).balanceOf(hook), sharesB - sharesB / 20);
    }

    function test_SE_previewEqualsExecution_bufferRoute() public {
        tokenA.mint(address(this), 100 ether);
        tokenA.approve(seA, type(uint256).max);
        uint256 amountIn = 10 ether;(uint256 pred,) = IStandardExchangeIn(seA).previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(seA)
        );(uint256 got,) = IStandardExchangeIn(seA).exchangeIn(IERC20(address(tokenA)),
            amountIn,
            IERC20(seA),
            pred,
            address(this),
            false,
            block.timestamp
        );
        assertEq(got, pred);
    }

    function test_thinIsExpectedInstance_codeAndFlagsOnly() public {
        // Thin gate: any address with correct flag bits and code would pass; empty fails.
        assertFalse(hookPkg.isExpectedInstance(address(0xBEEF), ""));
        assertTrue(hookPkg.isExpectedInstance(hook, abi.encode(_defaultPkgArgs())));
        // Different (wrong) binding args still true if flags match — not deep binding gate.
        assertTrue(hookPkg.isExpectedInstance(hook, abi.encode(uint256(0xdead))));
    }

    /* ------------------------------- D60 rated reserves ------------------------------- */

    /// @notice D60: every buffered leg (token != SE) must carry a rate provider.
    function test_D60_processArgs_bufferedLegWithoutRateProvider_reverts() public {
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.rateProvider0 = address(0);
        vm.expectRevert(IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.RateProviderRequired.selector);
        hookPkg.processArgs(abi.encode(args));
        args = _defaultPkgArgs();
        args.rateProvider1 = address(0);
        vm.expectRevert(IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.RateProviderRequired.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    /// @notice D60: getters expose the configured providers in pool order and by token / SE.
    function test_D60_rateProviderGetters() public {
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        assertTrue(args.rateProvider0 != address(0) && args.rateProvider1 != address(0), "fixture providers");
        assertEq(dual.rateProvider(address(tokenA)), args.rateProvider0, "by token A");
        assertEq(dual.rateProvider(seA), args.rateProvider0, "by SE A");
        assertEq(dual.rateProvider(address(tokenB)), args.rateProvider1, "by token B");
        assertEq(dual.rateProvider(seB), args.rateProvider1, "by SE B");
        assertEq(dual.rateProvider(address(0xDEAD)), address(0), "unknown token");
        address[] memory rps = dual.rateProviders();
        assertEq(rps.length, 2, "pool order length");
        assertEq(rps[0], dual.currency0() == address(tokenA) ? args.rateProvider0 : args.rateProvider1, "slot 0");
        assertEq(rps[1], dual.currency1() == address(tokenB) ? args.rateProvider1 : args.rateProvider0, "slot 1");
    }

    /// @notice D60: each leg's swap reserve is SE shares held x that leg's provider rate.
    function test_D60_swapReservesAreSharesTimesRate() public {
        _initPool();
        _depositBoth(100 ether, 100 ether);
        tokenA.mint(address(this), 13 ether);
        tokenA.approve(address(vaultA), 13 ether);
        vaultA.simulateYield(13 ether);
        uint256 rateA = IRateProvider(dual.rateProvider(seA)).getRate();
        uint256 rateB = IRateProvider(dual.rateProvider(seB)).getRate();
        assertGt(rateA, 1e18, "yield raised rate A");
        assertEq(dual.claimSupply0(), tokenA.balanceOf(hook) + IERC20(seA).balanceOf(hook) * rateA / 1e18, "reserve A = local + shares x rate");
        assertEq(dual.claimSupply1(), tokenB.balanceOf(hook) + IERC20(seB).balanceOf(hook) * rateB / 1e18, "reserve B = local + shares x rate");
    }
}
